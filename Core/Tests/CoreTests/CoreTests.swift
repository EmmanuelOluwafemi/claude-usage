import Testing
@testable import Core

@Test func coreVersionIsSet() {
    #expect(CoreVersion.value == "0.0.1")
}
