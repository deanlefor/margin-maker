import Foundation
import CoreGraphics

public enum HorizontalAnchor: Int, CaseIterable, Sendable {
    case left, center, right

    public var label: String { ["Left", "Center", "Right"][rawValue] }
}

public enum VerticalAnchor: Int, CaseIterable, Sendable {
    case top, middle, bottom

    public var label: String { ["Top", "Middle", "Bottom"][rawValue] }
}

public struct PageLayout: Equatable, Sendable {
    public static let letter = CGSize(width: 612, height: 792)
    public var scalePercent: Int
    public var horizontal: HorizontalAnchor
    public var vertical: VerticalAnchor

    public init(scalePercent: Int = 75, horizontal: HorizontalAnchor = .center,
                vertical: VerticalAnchor = .middle) {
        self.scalePercent = scalePercent
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// PDF coordinates have their origin at the bottom left. Size is the visible,
    /// rotated crop box; 100% is always the largest proportional fit on Letter.
    public func placement(for visibleSize: CGSize) throws -> CGRect {
        guard (50...100).contains(scalePercent) else { throw PDFError.invalidScale }
        guard visibleSize.width.isFinite, visibleSize.height.isFinite,
              visibleSize.width > 0, visibleSize.height > 0 else {
            throw PDFError.invalidPage
        }
        let factor = min(Self.letter.width / visibleSize.width,
                         Self.letter.height / visibleSize.height) * Double(scalePercent) / 100
        let size = CGSize(width: visibleSize.width * factor, height: visibleSize.height * factor)
        let x = (Self.letter.width - size.width) * Double(horizontal.rawValue) / 2
        let y = (Self.letter.height - size.height) * Double(2 - vertical.rawValue) / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

public enum EditScope: String, CaseIterable, Sendable {
    case allPages = "All pages"
    case currentPage = "This page"
}

/// Additional clockwise rotation of the entire reading, before fitting on Letter.
/// The source PDF's own page rotation is preserved and composed with this value.
public enum DocumentRotation: Int, CaseIterable, Sendable {
    case original = 0
    case clockwise90 = 90
    case clockwise180 = 180
    case clockwise270 = 270

    public var nextClockwise: Self {
        Self(rawValue: (rawValue + 90) % 360)!
    }

    public func rotatedSize(for size: CGSize) -> CGSize {
        rawValue % 180 == 0 ? size : CGSize(width: size.height, height: size.width)
    }
}

/// A small value model shared by the interface and regression tests.
public struct DocumentLayout: Sendable {
    public private(set) var pages: [PageLayout]
    public private(set) var pageIndex = 0
    public private(set) var rotation: DocumentRotation = .original
    public var scope: EditScope = .allPages
    public var current: PageLayout { pages[pageIndex] }
    public var hasCustomPages: Bool { pages.contains { $0 != pages[0] } }

    public init(pageCount: Int) throws {
        guard pageCount > 0 else { throw PDFError.noPages }
        pages = Array(repeating: PageLayout(), count: pageCount)
    }

    public mutating func selectPage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        pageIndex = index
    }

    public mutating func apply(_ layout: PageLayout) {
        if scope == .allPages {
            pages = Array(repeating: layout, count: pages.count)
        } else {
            pages[pageIndex] = layout
        }
    }

    /// Rotation always affects the whole reading, independent of the layout scope.
    public mutating func rotateClockwise() {
        rotation = rotation.nextClockwise
    }
}
