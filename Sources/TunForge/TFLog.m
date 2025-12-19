#import "TFLog.h"
#import <os/log.h>
#import <dispatch/dispatch.h>

static os_log_t TFLogSubsystem(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.tunforge", "core");
    });
    return log;
}

void TFLogInfo(const char *msg) {
    os_log_with_type(TFLogSubsystem(), OS_LOG_TYPE_INFO, "%{public}s", msg ?: "");
}

void TFLogDebug(const char *msg) {
    os_log_with_type(TFLogSubsystem(), OS_LOG_TYPE_DEBUG, "%{public}s", msg ?: "");
}

void TFLogError(const char *msg) {
    os_log_with_type(TFLogSubsystem(), OS_LOG_TYPE_ERROR, "%{public}s", msg ?: "");
}

void TFLogWarning(const char *msg) {
    os_log_with_type(TFLogSubsystem(), OS_LOG_TYPE_DEFAULT, "%{public}s", msg ?: "");
}

void TFLogVerbose(const char *msg) {
    os_log_with_type(TFLogSubsystem(), OS_LOG_TYPE_DEBUG, "%{public}s", msg ?: "");
}
