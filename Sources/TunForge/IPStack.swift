import Foundation
import Tun2Socks

/// Direct type alias to ObjC LWIPStack
/// IPStack is the public name for the ObjC implementation
public typealias IPStack = LWIPStack

/// Delegate for IP stack events (bridged to ObjC TSIPStackDelegate)
public typealias IPStackDelegate = TSIPStackDelegate

/// Provide a default empty implementation so conformers can implement it optionally
public extension TSIPStackDelegate {
    func didAcceptTCPSocket(_ socket: TCPSocket) {}
}
