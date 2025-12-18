import Foundation

@objc public final class TFLogger: NSObject {
    @objc public static func info(_ msg: String) { TunForgeLogger.info(msg) }
    @objc public static func debug(_ msg: String) { TunForgeLogger.debug(msg) }
    @objc public static func error(_ msg: String) { TunForgeLogger.error(msg) }
    @objc public static func warning(_ msg: String) { TunForgeLogger.warning(msg) }
    @objc public static func verbose(_ msg: String) { TunForgeLogger.verbose(msg) }
}
