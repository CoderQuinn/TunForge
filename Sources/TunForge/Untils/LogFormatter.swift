//
//  LogFormatter.swift
//  TunForge
//
//  Created by MagicianQuinn on 2025/12/10.
//

import CocoaLumberjackSwift

class TunForgeLogFormatter: NSObject, DDLogFormatter {
    private let dateFormatter: DateFormatter

    override init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }

    func format(message logMessage: DDLogMessage) -> String? {
        let timestamp = dateFormatter.string(from: logMessage.timestamp)
        var logLevel: String
        switch logMessage.flag {
        case .error: logLevel = "🔴[E]"
        case .warning: logLevel = "🟠[W]"
        case .info: logLevel = "🔵[I]"
        case .debug: logLevel = "🟢[D]"
        case .verbose: logLevel = "⚪[V]"
        default: logLevel = "[?]"
        }
        return "\(timestamp) [Thread:\(logMessage.threadID)] \(logLevel) \(logMessage.message)"
    }
}
