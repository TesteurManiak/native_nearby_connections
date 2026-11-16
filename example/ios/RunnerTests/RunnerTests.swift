import XCTest

@testable import native_nearby_connections

// Nearby needs real radios; behaviour is covered by the Dart tests and on-device runs.
class RunnerTests: XCTestCase {
  func testPluginClassIsLinked() {
    XCTAssertNotNil(NativeNearbyConnectionsPlugin.self)
  }
}
