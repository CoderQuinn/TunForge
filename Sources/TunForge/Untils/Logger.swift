import CocoaLumberjackSwift
import Foundation

public enum TunForgeLogger: Sendable {
    private static let setupQueue = DispatchQueue(label: "com.tunforge.logger.setup")
    private nonisolated(unsafe) static var isSetup = false

    private static func setup() {
        setupQueue.sync {
            guard !isSetup else { return }

            // TTY logger for console (Xcode / Terminal)
            guard let consolLogger = DDTTYLogger.sharedInstance else {
                return
            }
            consolLogger.logFormatter = TunForgeLogFormatter()
            DDLog.add(consolLogger)

            // File logger
            let fileLogger = DDFileLogger()
            fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
            fileLogger.logFileManager.maximumNumberOfLogFiles = 7
            DDLog.add(fileLogger)

            isSetup = true
            DDLogInfo("TunForge Logger initialized")
        }
    }

    public static func info(_ msg: String) {
        setup()
        DDLogInfo(msg)
    }

    public static func debug(_ msg: String) {
        setup()
        DDLogDebug(msg)
    }

    public static func error(_ msg: String) {
        setup()
        DDLogError(msg)
    }

    public static func warning(_ msg: String) {
        setup()
        DDLogWarn(msg)
    }

    public static func verbose(_ msg: String) {
        setup()
        DDLogVerbose(msg)
    }
}
