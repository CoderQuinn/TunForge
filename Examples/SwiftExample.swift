import TunForge
import Foundation

// Example demonstrating Swift-friendly typealiases and protocol extensions

class MyIPStackDelegate: TSIPStackDelegate {
    // Only need to implement required methods
    // didAcceptTCPSocket has a default no-op implementation
}

class MyTCPSocketDelegate: TSTCPSocketDelegate {
    // All delegate methods are optional with default implementations
    
    func socket(_ socket: LWTCPSocket, didReadData data: Data) {
        print("Received \(data.count) bytes")
    }
    
    func socketDidClose(_ socket: LWTCPSocket) {
        print("Socket closed")
    }
}

func example() {
    // Using Swift-friendly typealiases
    let config = LWIPStackConfig()
    let stack: TSIPStack = LWIPStack.defaultIPStack(with: config)
    
    // Delegates work with default implementations
    let delegate = MyIPStackDelegate()
    stack.delegate = delegate
}
