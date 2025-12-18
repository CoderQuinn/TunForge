import Foundation
import Tun2Socks

/// Direct type alias to ObjC LWIPStack
/// IPStack is the public name for the ObjC implementation
public typealias IPStack = LWIPStack

/// Delegate for IP stack events
public protocol IPStackDelegate: AnyObject {
    /// Called when a TCP socket is accepted
    func stack(_ stack: IPStack, didAcceptTCPSocket socket: TCPSocket)
}

extension IPStackDelegate {
    public func stack(_ stack: IPStack, didAcceptTCPSocket socket: TCPSocket) {}
/// Delegate for IP stack events (bridged to ObjC TSIPStackDelegate)
public typealias IPStackDelegate = TSIPStackDelegate

/// Provide a default empty implementation so conformers can implement it optionally
public extension TSIPStackDelegate {
    func didAcceptTCPSocket(_ socket: TCPSocket) {}
}
