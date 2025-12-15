import CocoaLumberjackSwift
import Foundation

import Cocoa
import CocoaLumberjackSwift

public enum TunForgeLogger {

    // MARK: - Logger Setup (lazy, thread-safe)
    private static let setupLogger: Void = {
        // Console logger (TTY)
        if let consoleLogger = DDTTYLogger.sharedInstance {
            consoleLogger.logFormatter = TunForgeLogFormatter()
            DDLog.add(consoleLogger)
        }

        // File logger
        let fileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24  // 24h
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)

        DDLogInfo("🔹 TunForge Logger initialized")
    }()

    // MARK: - Ensure logger setup
    @inline(__always)
    private static func ensureSetup() {
        _ = setupLogger
    }

    // MARK: - Public Logging APIs

    /// Info level log
    public static func info(_ msg: String) {
        ensureSetup()
        DDLogInfo(msg)
    }

    /// Debug level log
    public static func debug(_ msg: String) {
        ensureSetup()
        DDLogDebug(msg)
    }

    /// Error level log
    public static func error(_ msg: String) {
        ensureSetup()
        DDLogError(msg)
    }

    /// Warning level log
    public static func warning(_ msg: String) {
        ensureSetup()
        DDLogWarn(msg)
    }

    /// Verbose level log
    public static func verbose(_ msg: String) {
        ensureSetup()
        DDLogVerbose(msg)
    }
}
