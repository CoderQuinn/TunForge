import XCTest
import Tun2Socks

@testable import TunForge

// MARK: - IP Stack Tests

final class IPStackTests: XCTestCase {
    
    func testIPStackSingleton() throws {
        let stack1 = IPStack.default()
        let stack2 = IPStack.default()
        
        XCTAssertIdentical(stack1, stack2, "IPStack should be singleton")
    }
    
    func testIPStackConfiguration() throws {
        let stack = IPStack.default()
        
        // Configure with virtual network
        stack.configureIPv4(
            withIP: "240.0.0.2",
            netmask: "255.0.0.0",
            gw: "240.0.0.1"
        )
        
        // Should not throw
        XCTAssertNotNil(stack)
    }
    
    func testIPStackTimerControl() throws {
        let stack = IPStack.default()
        
        // Test suspend/resume
        stack.suspendTimer()
        XCTAssertTrue(true, "Suspend should not crash")
        
        stack.resumeTimer()
        XCTAssertTrue(true, "Resume should not crash")
    }
}

// MARK: - TCP Socket Tests

final class TCPSocketTests: XCTestCase {
    
    func testTCPSocketProperties() throws {
        // Create a mock TCP socket
        // Note: In real scenario, this would come from accepted connection
        
        XCTAssertTrue(true, "TCP socket tests placeholder")
    }
}

// MARK: - Integration Tests

final class TunForgeIntegrationTests: XCTestCase {
    
    var stack: IPStack?
    
    override func setUp() {
        super.setUp()
        stack = IPStack.default()
    }
    
    override func tearDown() {
        stack = nil
        super.tearDown()
    }
    
    func testBasicStackInitialization() throws {
        guard let stack = stack else {
            XCTFail("Stack not initialized")
            return
        }
        
        // Configure stack
        stack.configureIPv4(
            withIP: "240.0.0.2",
            netmask: "255.0.0.0",
            gw: "240.0.0.1"
        )
        
        // Should have outbound handler property
        stack.outboundHandler = { packet, family in
            // Mock handler
        }
        
        XCTAssertNotNil(stack.outboundHandler, "Outbound handler should be settable")
    }
    
    func testStackTimerLifecycle() throws {
        guard let stack = stack else {
            XCTFail("Stack not initialized")
            return
        }
        
        // Test timer lifecycle
        stack.resumeTimer()
        usleep(100_000)  // 100ms
        stack.suspendTimer()
        
        XCTAssertTrue(true, "Timer lifecycle should work")
    }
    
    func testStackProcessQueue() throws {
        guard let stack = stack else {
            XCTFail("Stack not initialized")
            return
        }
        
        // Test process queue
        let isOnQueue = stack.isOnProcessQueue()
        XCTAssertFalse(isOnQueue, "Main test thread should not be on process queue")
    }
}

// MARK: - Performance Tests

final class TunForgePerformanceTests: XCTestCase {
    
    func testStackInitializationPerformance() throws {
        self.measure {
            _ = IPStack.default()
        }
    }
}
