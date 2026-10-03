import Foundation

/// A page request. The API is 1-based.
public struct Page: Hashable, Sendable {
    public let number: Int
    public let size: Int

    public init(number: Int = 1, size: Int = 20) {
        self.number = number
        self.size = size
    }

    public var next: Page {
        Page(number: number + 1, size: size)
    }

    public static let first = Page()
}

/// One page of results plus where to go next. `next` is nil on the last page.
public struct PageResult<Item: Sendable>: Sendable {
    public let items: [Item]
    public let next: Page?
    public let total: Int

    public init(items: [Item], next: Page?, total: Int) {
        self.items = items
        self.next = next
        self.total = total
    }

    public func map<T: Sendable>(_ transform: (Item) -> T) -> PageResult<T> {
        PageResult<T>(items: items.map(transform), next: next, total: total)
    }
}

extension PageResult: Equatable where Item: Equatable {}
