//
//  IPStackProtocol.swift
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/13.
//

import Foundation

/// Type alias for the outbound data closure
/// - Parameters:
///   - packets: Array of data packets to send
///   - lengths: Array of corresponding packet lengths
public typealias OutboundHandler = ([Data], [Int]) -> Void

/// Abstract IP stack protocol
public protocol IPStackProtocol: AnyObject {
    /// Process an inbound packet
    /// - Parameters:
    ///   - packet: The incoming data packet
    ///   - version: IP version (4 or 6), or other
    /// - Returns: `true` if the packet was successfully handled, otherwise `false`
    func inBound(packet: Data, version: Int) -> Bool

    /// Closure for sending outbound data, provided by external code
    var outboundHandler: OutboundHandler? { get set }

    /// Start the IP stack
    func start()

    /// Stop the IP stack
    func stop()
}

extension IPStackProtocol {
    func stop() {}
}
