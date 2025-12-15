import Foundation

@_cdecl("TFLogInfo")
public func TFLogInfo(_ cmsg: UnsafePointer<CChar>) {
    let msg = String(cString: cmsg)
    TFLogger.info(msg)
}

@_cdecl("TFLogDebug")
public func TFLogDebug(_ cmsg: UnsafePointer<CChar>) {
    let msg = String(cString: cmsg)
    TFLogger.debug(msg)
}

@_cdecl("TFLogError")
public func TFLogError(_ cmsg: UnsafePointer<CChar>) {
    let msg = String(cString: cmsg)
    TFLogger.error(msg)
}

@_cdecl("TFLogWarning")
public func TFLogWarning(_ cmsg: UnsafePointer<CChar>) {
    let msg = String(cString: cmsg)
    TFLogger.warning(msg)
}

@_cdecl("TFLogVerbose")
public func TFLogVerbose(_ cmsg: UnsafePointer<CChar>) {
    let msg = String(cString: cmsg)
    TFLogger.verbose(msg)
}
