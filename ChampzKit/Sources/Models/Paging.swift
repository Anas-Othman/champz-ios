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
}

extension PageResult: Equatable where Item: Equatable {}

/// Django REST Framework's page envelope: `{"count", "next", "previous", "results"}`.
/// A bad row is dropped and reported rather than failing the page.
public struct PaginatedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    @DefaultZero public var count: Int
    @DefaultEmpty public var next: String
    @LossyArray public var results: [Item]

    public func pageResult(for page: Page) -> PageResult<Item> {
        PageResult(items: results, next: next.isEmpty ? nil : page.next, total: count)
    }
}
