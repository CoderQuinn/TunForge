import Foundation
import Tun2Socks

/// Direct type alias to ObjC LWTCPSocket
/// TCPSocket is the public name for the ObjC implementation
public typealias TCPSocket = LWTCPSocket

/// Delegate for TCP socket events
public protocol TCPSocketDelegate: AnyObject {
    /// Called when read is shut down
    func socketDidShutdownRead(_ socket: TCPSocket)
    
    /// Called when reset
    func socketDidReset(_ socket: TCPSocket)
    
    /// Called when aborted
    func socketDidAbort(_ socket: TCPSocket)
    
    /// Called when closed
    func socketDidClose(_ socket: TCPSocket)
    
    /// Called when data is read
    func socket(_ socket: TCPSocket, didReadData data: Data)
    
    /// Called when data is written
    func socket(_ socket: TCPSocket, didWriteDataOfLength length: Int)
    func socket(_ socket: TCPSocket, didWriteDataOfLength length: UInt)
}

extension TCPSocketDelegate {
    public func socketDidShutdownRead(_ socket: TCPSocket) {}
    public func socketDidReset(_ socket: TCPSocket) {}
    public func socketDidAbort(_ socket: TCPSocket) {}
    public func socketDidClose(_ socket: TCPSocket) {}
    public func socket(_ socket: TCPSocket, didReadData data: Data) {}
    public func socket(_ socket: TCPSocket, didWriteDataOfLength length: Int) {}
    public func socket(_ socket: TCPSocket, didWriteDataOfLength length: UInt) {}
}
