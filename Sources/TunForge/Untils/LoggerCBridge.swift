import Foundation

@_cdecl("TFLogInfo")
public func TFLogInfo(_ cstr: UnsafePointer<CChar>) {
    TunForgeLogger.info(String(cString: cstr))
}

@_cdecl("TFLogDebug")
public func TFLogDebug(_ cstr: UnsafePointer<CChar>) {
    TunForgeLogger.debug(String(cString: cstr))
}

@_cdecl("TFLogError")
public func TFLogError(_ cstr: UnsafePointer<CChar>) {
    TunForgeLogger.error(String(cString: cstr))
}

@_cdecl("TFLogWarning")
public func TFLogWarning(_ cstr: UnsafePointer<CChar>) {
    TunForgeLogger.warning(String(cString: cstr))
}

@_cdecl("TFLogVerbose")
public func TFLogVerbose(_ cstr: UnsafePointer<CChar>) {
    TunForgeLogger.verbose(String(cString: cstr))
}
