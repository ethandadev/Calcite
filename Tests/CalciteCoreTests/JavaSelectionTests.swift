import XCTest
@testable import CalciteCore

final class JavaSelectionTests: XCTestCase {
    private let j8 = JavaRuntime(major: 8, path: "/jre8")
    private let j17 = JavaRuntime(major: 17, path: "/jre17")
    private let j21 = JavaRuntime(major: 21, path: "/jre21")
    private let j25 = JavaRuntime(major: 25, path: "/jre25")

    private func meta(_ id: String, java: Int?) -> VersionMetadata {
        VersionMetadata(id: id, javaVersion: java.map { .init(component: nil, majorVersion: $0) })
    }

    func testUsesJSONMajorVersion() throws {
        XCTAssertEqual(try JavaSelector.select(for: meta("26.3", java: 25), from: [j17, j21, j25]), j25)
    }

    /// The original bug: only Java 17 installed, game needs 25. Must NOT return 17.
    func testNeverFallsBackToOlderJava() {
        XCTAssertThrowsError(try JavaSelector.select(for: meta("26.3", java: 25), from: [j17])) { error in
            XCTAssertEqual(error as? JavaSelectionError, .missingRuntime(required: 25, installed: [17]))
        }
    }

    func testPrefersLowestNewerRuntime() throws {
        XCTAssertEqual(try JavaSelector.select(for: meta("1.18", java: 17), from: [j25, j21]), j21)
    }

    func testDecodesMojangJSON() throws {
        let json = #"{"id":"26.3","javaVersion":{"component":"java-runtime-epsilon","majorVersion":25}}"#
        let v = try JSONDecoder().decode(VersionMetadata.self, from: Data(json.utf8))
        XCTAssertEqual(JavaSelector.requiredMajor(for: v), 25)
    }

    func testLegacyTableWhenFieldMissing() {
        XCTAssertEqual(LegacyJavaTable.requiredMajor(forVersionID: "1.16.5"), 8)
        XCTAssertEqual(LegacyJavaTable.requiredMajor(forVersionID: "1.17.1"), 16)
        XCTAssertEqual(LegacyJavaTable.requiredMajor(forVersionID: "1.20.4"), 17)
        XCTAssertEqual(LegacyJavaTable.requiredMajor(forVersionID: "1.20.5"), 21)
        XCTAssertEqual(LegacyJavaTable.requiredMajor(forVersionID: "1.21.4"), 21)
        XCTAssertEqual(LegacyJavaTable.requiredMajor(forVersionID: "26.1"), 25)
    }
}
