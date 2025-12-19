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
public typealias TSIPStack = LWIPStack

/// Swift-friendly typealias for TCP socket connections.
public typealias TSTCPSocket = LWTCPSocket

// MARK: - TSIPStackDelegate Extension

/// Swift extension providing default no-op implementations for optional delegate methods.
public extension TSIPStackDelegate {
    func didAcceptTCPSocket(_ socket: LWTCPSocket) {
        // Default no-op implementation
    }
}

// MARK: - TSTCPSocketDelegate Extension

/// Swift extension providing default no-op implementations for optional delegate methods.
public extension TSTCPSocketDelegate {
    func socketDidShutdownRead(_ socket: LWTCPSocket) {
        // Default no-op
    }
    
    func socketDidReset(_ socket: LWTCPSocket) {
        // Default no-op
    }
    
    func socketDidAbort(_ socket: LWTCPSocket) {
        // Default no-op
    }
    
    func socketDidClose(_ socket: LWTCPSocket) {
        // Default no-op
    }
    
    func socket(_ socket: LWTCPSocket, didReadData data: Data) {
        // Default no-op
    }
    
    func socket(_ socket: LWTCPSocket, didWriteDataOfLength length: UInt) {
        // Default no-op
    }
}
