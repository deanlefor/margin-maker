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
    /// rotated crop box; 100% is the largest proportional fit on the chosen canvas.
    public func placement(for visibleSize: CGSize, orientation: PageOrientation = .portrait) throws -> CGRect {
        guard (50...100).contains(scalePercent) else { throw PDFError.invalidScale }
        guard visibleSize.width.isFinite, visibleSize.height.isFinite,
              visibleSize.width > 0, visibleSize.height > 0 else {
            throw PDFError.invalidPage
        }
        let canvas = orientation.pageSize
        let factor = min(canvas.width / visibleSize.width,
                         canvas.height / visibleSize.height) * Double(scalePercent) / 100
        let size = CGSize(width: visibleSize.width * factor, height: visibleSize.height * factor)
        let x = (canvas.width - size.width) * Double(horizontal.rawValue) / 2
        let y = (canvas.height - size.height) * Double(2 - vertical.rawValue) / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

public enum EditScope: String, CaseIterable, Sendable {
    case allPages = "All pages"
    case currentPage = "This page"
}

/// Output canvas orientation, independent of the imported reading's orientation.
public enum PageOrientation: String, CaseIterable, Sendable {
    case portrait = "Portrait"
    case landscape = "Landscape"

    public var pageSize: CGSize {
        switch self {
        case .portrait: PageLayout.letter
        case .landscape: CGSize(width: 792, height: 612)
        }
    }
}

/// A small value model shared by the interface and regression tests.
public struct DocumentLayout: Sendable {
    public private(set) var pages: [PageLayout]
    public private(set) var pageIndex = 0
    public private(set) var orientation: PageOrientation = .portrait
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

    /// Canvas orientation applies to every page without changing individual layouts.
    public mutating func setOrientation(_ orientation: PageOrientation) {
        self.orientation = orientation
    }
}
