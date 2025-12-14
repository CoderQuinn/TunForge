//
//  TCPSocket.m
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//
//

#import "TCPSocket.h"
// C bridge logging functions (exported from Swift `TunForgeLogger`)
extern void TFLogInfo(const char *msg);
extern void TFLogDebug(const char *msg);
extern void TFLogError(const char *msg);
extern void TFLogWarning(const char *msg);
extern void TFLogVerbose(const char *msg);
#import "TCPSocketStats.h"
#import "TCPSocketStatsReport.h"
#import <QuartzCore/QuartzCore.h>

@interface TCPSocket ()

@property (nonatomic, assign) struct tcp_pcb *pcb;

@property (nonatomic, assign) NSUInteger identity;

@property (nonatomic, weak) id<TCPSocketDelegate> delegate;

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, assign, getter=isSentClosedSignal) BOOL sentClosedSignal;

@property (nonatomic, assign, getter=isValid) BOOL valid;

@property (nonatomic, assign, getter=isConnected) BOOL connected;

@property (nonatomic, strong) TCPSocketStats *stats;

// Snapshot report generated on demand (copy of stats)
- (TCPSocketStatsReport *)makeStatsReport;

@end

@implementation TCPSocket

static NSMutableDictionary<NSNumber *, TCPSocket *> *_socketDict;
static dispatch_queue_t _socketDictQueue;

+ (void)setSocketDict:(NSMutableDictionary<NSNumber *,TCPSocket *> *)socketDict
{
    if (socketDict != _socketDict)
    {
        _socketDict = socketDict;
    }
}

+ (NSMutableDictionary<NSNumber *,TCPSocket *> *)socketDict
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _socketDict = [NSMutableDictionary dictionaryWithCapacity:1024];
        _socketDictQueue = dispatch_queue_create("tun2socks.tcp.socketDict.queue", DISPATCH_QUEUE_CONCURRENT);
    });
    return _socketDict;
}

+ (TCPSocket *)socketForIdentity:(NSUInteger)identity
{
    __block TCPSocket *result = nil;
    dispatch_sync(_socketDictQueue, ^{
        result = [_socketDict objectForKey:@(identity)];
    });
    return result;
}

+ (NSInteger)uniqueKey
{
    UInt32 randomKey = arc4random();
    while ([self socketForIdentity:randomKey] != nil)
    {
        randomKey = arc4random();
    }
    return (NSInteger)randomKey;
}

+ (NSArray<TCPSocketStatsReport *> *)allSocketStatsReports
{
    __block NSArray<TCPSocket *> *sockets = nil;
    dispatch_sync(_socketDictQueue, ^{
        sockets = [_socketDict allValues];
    });
    if (sockets.count == 0) {
        return @[];
    }
    NSMutableArray<TCPSocketStatsReport *> *reports = [NSMutableArray arrayWithCapacity:sockets.count];
    for (TCPSocket *socket in sockets) {
        TCPSocketStatsReport *report = [socket makeStatsReport];
        if (report) {
            [reports addObject:report];
        }
    }
    return [reports copy];
}

- (void)setDelegate:(id<TCPSocketDelegate>)delegate
{
    if (delegate != _delegate)
    {
        _delegate = delegate;
    }
}

- (BOOL)isValid
{
    return self.pcb != nil;
}

- (BOOL)isConnected
{
    return [self isValid] && (self.pcb->state != CLOSED);
}

- (instancetype)initWithTCPPcb:(struct tcp_pcb*)pcb queue:(dispatch_queue_t)queue
{
    if (self = [super init])
    {
        if (pcb == NULL || queue == NULL) {
            NSLog(@"[TCPSocket] Init with NULL pcb or queue");
            return nil;
        }
        
        _pcb = pcb;
        _queue = queue;
        
        _sourcePort = pcb->remote_port;
        struct in_addr sourceIP = {pcb->remote_ip.addr};
        _sourceAddress = sourceIP;
        
        _destinationPort = pcb->local_port;
        struct in_addr destinationIP = {pcb->local_ip.addr};
        _destinationAddress = destinationIP;

        _stats = [[TCPSocketStats alloc] init];
        
        _identity = [[self class] uniqueKey];
        // Register in socket dictionary via queue for thread-safety
        dispatch_barrier_async(_socketDictQueue, ^{
            _socketDict[@(_identity)] = self;
        });
        
        [self setupTCPPCB];
    }
    return self;
}

- (TCPSocketStatsReport *)makeStatsReport
{
    TCPSocketStatsReport *report = [[TCPSocketStatsReport alloc] init];
    report.identity = self.identity;
    report.sourcePort = self.sourcePort;
    report.destinationPort = self.destinationPort;
    report.sourceAddressValue = self.sourceAddress.s_addr;
    report.destinationAddressValue = self.destinationAddress.s_addr;
    report.bytesRead = self.stats.bytesRead;
    report.bytesWritten = self.stats.bytesWritten;
    report.packetsRead = self.stats.packetsRead;
    report.packetsWritten = self.stats.packetsWritten;
    report.errors = self.stats.errors;
    report.connectionTime = self.stats.connectionTime;
    report.lastActivityTime = self.stats.lastActivityTime;
    report.readThroughput = [self.stats readThroughputBytesPerSec];
    report.writeThroughput = [self.stats writeThroughputBytesPerSec];
    report.idleDuration = [self.stats idleDuration];
    return report;
}

- (void)setupTCPPCB
{
    if (self.pcb == NULL) {
        TFLogError("[TCPSocket] setupTCPPCB called with NULL pcb");
        return;
    }
    
    // Store identity value directly (not pointer) - safe across object lifetime
    tcp_arg(self.pcb, (void *)(uintptr_t)self.identity);
    tcp_recv(self.pcb, tcp_recv_callback);
    tcp_sent(self.pcb, tcp_sent_callback);
    tcp_err(self.pcb, tcp_err_callback);
}

- (void)errorOccurred:(err_t)error
{
    [self invalidate];
    
    switch (error)
    {
        case ERR_RST:
        {
            {
                char buf[128];
                snprintf(buf, sizeof(buf), "[TCPSocket %lu] Connection reset by peer", (unsigned long)self.identity);
                TFLogWarning(buf);
            }
            self.stats.errors++;
            if (self.delegate != nil && [self.delegate respondsToSelector:@selector(socketDidReset:)])
            {
                [self.delegate socketDidReset:self];
            }
            break;
        }
        case ERR_ABRT:
        {
            {
                char buf[128];
                snprintf(buf, sizeof(buf), "[TCPSocket %lu] Connection aborted", (unsigned long)self.identity);
                TFLogError(buf);
            }
            self.stats.errors++;
            if (self.delegate != nil && [self.delegate respondsToSelector:@selector(socketDidAbort:)])
            {
                [self.delegate socketDidAbort:self];
            }
            break;
        }
        case ERR_CLSD:
        {
            {
                char buf[128];
                snprintf(buf, sizeof(buf), "[TCPSocket %lu] Connection closed", (unsigned long)self.identity);
                TFLogInfo(buf);
            }
            if(self.delegate && [self.delegate respondsToSelector:@selector(socketDidClose:)]) {
                [self.delegate socketDidClose:self];
            }
            break;
        }
        default:
        {
            {
                char buf[128];
                snprintf(buf, sizeof(buf), "[TCPSocket %lu] Error occurred: %d", (unsigned long)self.identity, error);
                TFLogError(buf);
            }
            self.stats.errors++;
            break;
        }
    }
}

- (void)invalidate
{
    self.pcb = NULL;
    
    dispatch_barrier_async(_socketDictQueue, ^{
        [_socketDict removeObjectForKey:@(self.identity)];
    });
}

- (void)sendDataOfLength:(NSUInteger)length
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(socket:didWriteDataOfLength:)])
    {
        [self.delegate socket:self didWriteDataOfLength:length];
    }
}

- (void)writeData:(NSData *)data
{
    if (![self isValid]) {
        char buf[160];
        snprintf(buf, sizeof(buf), "[TCPSocket %lu] Cannot write data: socket invalid", (unsigned long)self.identity);
        TFLogError(buf);
        return;
    }
    
    if (data == nil || data.length == 0) {
        return;
    }
    
    if (data.length > UINT16_MAX) {
        char buf[200];
        snprintf(buf, sizeof(buf), "[TCPSocket %lu] Data too large: %lu bytes (max %d)", 
                 (unsigned long)self.identity, (unsigned long)data.length, UINT16_MAX);
        TFLogWarning(buf);
        [self close];
        return;
    }
    
    const void *dataptr = [data bytes];
    UInt16 length = (UInt16)data.length;
    
    err_t error = tcp_write(self.pcb, dataptr, length, TCP_WRITE_FLAG_COPY);
    if (error != ERR_OK)
    {
        char buf[160];
        snprintf(buf, sizeof(buf), "[TCPSocket %lu] tcp_write failed: %d", (unsigned long)self.identity, error);
        TFLogError(buf);
        self.stats.errors++;
        [self close];
        return;
    }

    self.stats.bytesWritten += length;
    self.stats.packetsWritten++;
    self.stats.lastActivityTime = CACurrentMediaTime();

    error = tcp_output(self.pcb);
    if (error != ERR_OK) {
        char buf[160];
        snprintf(buf, sizeof(buf), "[TCPSocket %lu] tcp_output failed: %d", (unsigned long)self.identity, error);
        TFLogError(buf);
        self.stats.errors++;
    }
}

- (void)receivedBuf:(struct pbuf *)pbuf
{
    // NOTE: caller transfers ownership; we free exactly once here
    if (pbuf == NULL)
    {
        // NULL pbuf indicates connection closed by remote
        {
            char buf[200];
            snprintf(buf, sizeof(buf), "[TCPSocket %lu] Received NULL pbuf - connection closed remotely", (unsigned long)self.identity);
            TFLogInfo(buf);
        }
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(socketDidCloseLocally:)])
        {
            [self.delegate socketDidCloseLocally:self];
        }
    }
    else
    {
        uint16_t totalLength = pbuf->tot_len;
        NSMutableData *packetData = [NSMutableData dataWithLength:totalLength];
        if (packetData == nil) {
            {
                char buf[200];
                snprintf(buf, sizeof(buf), "[TCPSocket %lu] Failed to allocate data for %d bytes", 
                         (unsigned long)self.identity, totalLength);
                TFLogError(buf);
            }
            pbuf_free(pbuf);
            return;
        }
        
        void *dataptr = [packetData mutableBytes];
        pbuf_copy_partial(pbuf, dataptr, totalLength, 0);
        
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(socket:didReadData:)])
        {
            [self.delegate socket:self didReadData:packetData];
        }
        
        if ([self isValid])
        {
            tcp_recved(self.pcb, totalLength);
        }

        self.stats.bytesRead += totalLength;
        self.stats.packetsRead++;
        self.stats.lastActivityTime = CACurrentMediaTime();
        
        // Always free pbuf after processing
        pbuf_free(pbuf);
    }
}

- (void)close
{
    if (![self isValid]) {
        char buf[160];
        snprintf(buf, sizeof(buf), "[TCPSocket %lu] Close called on invalid socket", (unsigned long)self.identity);
        TFLogWarning(buf);
        return;
    }
    
    tcp_arg(self.pcb, NULL);
    tcp_recv(self.pcb, NULL);
    tcp_sent(self.pcb, NULL);
    tcp_err(self.pcb, NULL);
    
    err_t error = tcp_close(self.pcb);
    if (error != ERR_OK) {
        char buf[200];
        snprintf(buf, sizeof(buf), "[TCPSocket %lu] tcp_close failed: %d, aborting instead", 
                 (unsigned long)self.identity, error);
        TFLogError(buf);
        self.stats.errors++;
        tcp_abort(self.pcb);
    }
    
    [self invalidate];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(socketDidClose:)])
    {
        [self.delegate socketDidClose:self];
    }
}

- (void)reset
{
    if (![self isValid]) return;
    
    tcp_arg(self.pcb, NULL);
    tcp_recv(self.pcb, NULL);
    tcp_sent(self.pcb, NULL);
    tcp_err(self.pcb, NULL);
    
    tcp_abort(self.pcb);
    [self invalidate];
    
    if (nil != self.delegate && [self.delegate respondsToSelector:@selector(socketDidClose:)])
    {
        [self.delegate socketDidClose:self];
    }
}

/** Function prototype for tcp receive callback functions. Called when data has
 * been received.
 *
 * @param arg Additional argument to pass to the callback function (@see tcp_arg())
 * @param tpcb The connection pcb which received data
 * @param p The received data (or NULL when the connection has been closed!)
 * @param err An error code if there has been an error receiving
 *            Only return ERR_ABRT if you have called tcp_abort from within the
 *            callback function!
 */
static err_t tcp_recv_callback(void *arg, struct tcp_pcb *tpcb,
                               struct pbuf *p, err_t err)
{
    if (err != ERR_OK) {
        char buf[160];
        snprintf(buf, sizeof(buf), "[TCPSocket] tcp_recv_callback received error: %d", err);
        TFLogError(buf);
        // errors counted in per-socket instance when available
        if (p != NULL) {
            pbuf_free(p);
        }
        return err;
    }
    
    if (arg == NULL) {
        TFLogError("[TCPSocket] tcp_recv_callback received NULL arg");
        if (p != NULL) {
            pbuf_free(p);
        }
        tcp_abort(tpcb);
        return ERR_ABRT;
    }
    
    // Extract identity value from arg
    NSUInteger identity = (NSUInteger)(uintptr_t)arg;
    TCPSocket *socket = [TCPSocket socketForIdentity:identity];
    
    if (socket == nil)
    {
        char buf[200];
        snprintf(buf, sizeof(buf), "[TCPSocket] Socket not found for identity %lu, aborting", (unsigned long)identity);
        TFLogError(buf);
        if (p != NULL) {
            pbuf_free(p);
        }
        tcp_abort(tpcb);
        return ERR_ABRT;
    }
    
    // CRITICAL: lwIP callbacks are NOT on processQueue by default!
    // Must dispatch to socket's queue to serialize with other lwIP operations
    dispatch_async(socket.queue, ^{
        [socket receivedBuf:p];
    });
    return ERR_OK;
}

/** Function prototype for tcp sent callback functions. Called when sent data has
 * been acknowledged by the remote side. Use it to free corresponding resources.
 * This also means that the pcb has now space available to send new data.
 *
 * @param arg Additional argument to pass to the callback function (@see tcp_arg())
 * @param tpcb The connection pcb for which data has been acknowledged
 * @param len The amount of bytes acknowledged
 * @return ERR_OK: try to send some data by calling tcp_output
 *            Only return ERR_ABRT if you have called tcp_abort from within the
 *            callback function!
 */
static err_t tcp_sent_callback(void *arg, struct tcp_pcb *tpcb,
                               u16_t len)
{
    if (arg == NULL) {
        TFLogError("[TCPSocket] tcp_sent_callback received NULL arg");
        tcp_abort(tpcb);
        return ERR_ABRT;
    }
    
    // Extract identity value from arg
    NSUInteger identity = (NSUInteger)(uintptr_t)arg;
    TCPSocket *socket = [TCPSocket socketForIdentity:identity];
    
    if (socket == nil)
    {
        char buf[200];
        snprintf(buf, sizeof(buf), "[TCPSocket] Socket not found for identity %lu, aborting", (unsigned long)identity);
        TFLogError(buf);
        tcp_abort(tpcb);
        return ERR_ABRT;
    }

    // CRITICAL: Dispatch to socket's queue to serialize with lwIP operations
    dispatch_async(socket.queue, ^{
        [socket sendDataOfLength:len];
    });
    return ERR_OK;
}

/** Function prototype for tcp error callback functions. Called when the pcb
 * receives a RST or is unexpectedly closed for any other reason.
 *
 * @note The corresponding pcb is already freed when this callback is called!
                                    [self setupTCPPCB];
 * @param arg Additional argument to pass to the callback function (@see tcp_arg())
 * @param err Error code to indicate why the pcb has been closed
 *            ERR_ABRT: aborted through tcp_abort or by a TCP timer
 *            ERR_RST: the connection was reset by the remote host
 */
static void tcp_err_callback(void *arg, err_t err)
{
    if (arg == NULL) {
        char buf[200];
        snprintf(buf, sizeof(buf), "[TCPSocket] tcp_err_callback received NULL arg with error: %d", err);
        TFLogError(buf);
        return;
    }
    
    // Extract identity value from arg
    NSUInteger identity = (NSUInteger)(uintptr_t)arg;
    TCPSocket *socket = [TCPSocket socketForIdentity:identity];
    
    if (socket != nil)
    {
        [socket errorOccurred:err];
    } else {
        char buf[220];
        snprintf(buf, sizeof(buf), "[TCPSocket] Socket not found for identity %lu in error callback", (unsigned long)identity);
        TFLogError(buf);
    }
}

@end
