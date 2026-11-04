import Testing

// Numeric and throwing checks shared by the PDF regression cases.
private func location(_ file: StaticString, _ line: UInt) -> SourceLocation {
    SourceLocation(fileID: "MarginMakerCoreTests/\(String(describing: file).split(separator: "/").last!)",
                   filePath: String(describing: file), line: Int(line), column: 1)
}

func unwrap<T>(_ value: T?) throws -> T { try #require(value) }

func expectEqual<T: Equatable>(_ actual: T, _ expected: T,
                               file: StaticString = #filePath, line: UInt = #line) {
    #expect(actual == expected, sourceLocation: location(file, line))
}

func expectEqual<T: BinaryFloatingPoint>(_ actual: T, _ expected: T, accuracy: T,
                                        file: StaticString = #filePath, line: UInt = #line) {
    #expect(abs(actual - expected) <= accuracy + 0.000001, "\(actual) != \(expected) ± \(accuracy)",
            sourceLocation: location(file, line))
}

func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    #expect(value, sourceLocation: location(file, line))
}

func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    #expect(!value, sourceLocation: location(file, line))
}

func expectAtLeast<T: Comparable>(_ actual: T, _ minimum: T,
                                 file: StaticString = #filePath, line: UInt = #line) {
    #expect(actual >= minimum, sourceLocation: location(file, line))
}

func expectAtMost<T: Comparable>(_ actual: T, _ maximum: T,
                                file: StaticString = #filePath, line: UInt = #line) {
    #expect(actual <= maximum, sourceLocation: location(file, line))
}

func expectThrows<T>(_ expression: @autoclosure () throws -> T,
                     file: StaticString = #filePath, line: UInt = #line,
                     check: (any Error) -> Void = { _ in }) {
    do {
        _ = try expression()
        Issue.record("Expected an error", sourceLocation: location(file, line))
    } catch { check(error) }
}
