//
//  TunForge.swift
//  TunForge
//
//  Swift-friendly typealiases and protocol extensions for Objective-C APIs
//

import Foundation
import TunForgeCore

// Swift-friendly surface over TunForgeCore.
public typealias TFIPStackSwift = TFIPStack
public typealias TFTCPConnectionSwift = TFTCPConnection
public typealias TFTCPConnectionInfoSwift = TFTCPConnectionInfo
public typealias TFTCPConnectionTerminationReasonSwift = TFTCPConnectionTerminationReason

public extension TFIPStack {
    /// Shared global stack (TunForge is singletons by design).
    static var shared: TFIPStack { TFIPStack.default() }

    /// Set outbound handler with Swift-native types.
    func setOutboundHandler(_ handler: @escaping (_ packets: [Data], _ families: [Int32]) -> Void) {
        outboundHandler = { packets, families in
            let swiftPackets: [Data] = packets
            let swiftFamilies: [Int32] = families.compactMap { $0.int32Value }
            handler(swiftPackets, swiftFamilies)
        }
    }
}

public extension TFTCPConnectionTerminationReason {
    /// Human-readable reason for logging/telemetry.
    var description: String {
        switch self {
        case .none: return "none"
        case .close: return "close"
        case .reset: return "reset"
        case .abort: return "abort"
        case .destroyed: return "destroyed"
        @unknown default: return "unknown"
        }
    }
}
