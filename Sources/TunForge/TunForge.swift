//
//  TunForge.swift
//  TunForge
//
//  Swift-friendly typealiases and protocol extensions for Objective-C APIs
//

import Foundation
import TunForgeCore

// MARK: - Type Aliases

/// Swift-friendly typealias for the IP stack singleton.
public typealias TSIPStack = TFIPStack

/// Swift-friendly typealias for TCP socket connections.
public typealias TSTCPSocket = TFTCPSocket

// MARK: - TSIPStackDelegate Extension

/// Swift extension providing default no-op implementations for optional delegate methods.
public extension TSIPStackDelegate {
    func didAcceptTCPSocket(_: TFTCPSocket) {
        // Default no-op implementation
    }
}

// MARK: - TSTCPSocketDelegate Extension

/// Swift extension providing default no-op implementations for optional delegate methods.
public extension TSTCPSocketDelegate {
    func socketDidShutdownRead(_: TFTCPSocket) {
        // Default no-op
    }

    func socketDidReset(_: TFTCPSocket) {
        // Default no-op
    }

    func socketDidAbort(_: TFTCPSocket) {
        // Default no-op
    }

    func socketDidClose(_: TFTCPSocket) {
        // Default no-op
    }

    func socket(_: TFTCPSocket, didReadData _: Data) {
        // Default no-op
    }

    func socket(_: TFTCPSocket, didWriteDataOfLength _: UInt) {
        // Default no-op
    }
}
