//
//  TunForgeSwiftSurfaceTests.swift
//  TunForgeTests — XCTest coverage for the Swift facade (see docs/TESTING.md)
//

import XCTest
@testable import TunForge
import TunForgeCore

final class TunForgeSwiftSurfaceTests: XCTestCase {

    func testTerminationReasonDescriptions() {
        XCTAssertEqual(TFTCPConnectionTerminationReason.none.description, "none")
        XCTAssertEqual(TFTCPConnectionTerminationReason.close.description, "close")
        XCTAssertEqual(TFTCPConnectionTerminationReason.reset.description, "reset")
        XCTAssertEqual(TFTCPConnectionTerminationReason.abort.description, "abort")
        XCTAssertEqual(TFTCPConnectionTerminationReason.destroyed.description, "destroyed")
    }

    func testSwiftTypealiasesResolve() {
        // Compile-time / metatype wiring for the public Swift surface.
        XCTAssertTrue(TFIPStackSwift.self == TFIPStack.self)
        XCTAssertTrue(TFTCPConnectionSwift.self == TFTCPConnection.self)
        XCTAssertTrue(TFTCPConnectionInfoSwift.self == TFTCPConnectionInfo.self)
        XCTAssertTrue(
            TFTCPConnectionTerminationReasonSwift.self == TFTCPConnectionTerminationReason.self
        )
    }
}
