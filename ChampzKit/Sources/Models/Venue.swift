import Foundation

/// `GET /api/v1/venues/` and `/venues/{id}/` — a venue whose courts can be booked.
public struct Venue: Decodable, Hashable, Sendable, Identifiable {
    public let id: VenueID
    @DefaultEmpty public var name: String
    @DefaultEmpty public var location: String
    @LenientDecimal public var latitude: Decimal?
    @LenientDecimal public var longitude: Decimal?
    /// Only when the list was asked with the player's position.
    public var distanceKm: Double?
    @DefaultEmpty public var surfaceType: String
    @DefaultZero public var noOfCourts: Int
    @DefaultEmpty public var contactNumber: String
    @DefaultEmpty public var description: String
    @DefaultEmpty public var equipmentLabel: String
    @DefaultEmpty public var parkingLabel: String
    @DefaultEmpty public var imageUrl: String
    @LossyArray public var images: [String]
    @LossyArray public var courts: [Court]

    /// Every picture, the primary one first.
    public var gallery: [String] {
        let all = images.isEmpty ? [imageUrl] : images
        return all.filter { !$0.isEmpty }
    }

    /// "Starts from": the cheapest 60-minute rate across its courts (current app's card).
    public var startingPrice: Money? {
        let prices = courts.flatMap(\.slots).compactMap(\.lowestPrice)
        return prices.min().map { Money($0, currency: Money.defaultCurrency) }
    }

    public var coordinate: (latitude: Double, longitude: Double)? {
        guard let latitude, let longitude else { return nil }
        return (Double(truncating: latitude as NSNumber), Double(truncating: longitude as NSNumber))
    }
}

public struct Court: Decodable, Hashable, Sendable, Identifiable {
    public let id: CourtID
    @DefaultEmpty public var name: String
    /// "Indoor", "Grass", "Synthetic"…
    @DefaultEmpty public var courtType: String
    @LossyArray public var slots: [CourtSlot]
}

public struct CourtSlot: Decodable, Hashable, Sendable {
    /// The 60-minute rate for this window.
    @LenientDecimal public var lowestPrice: Decimal?
}

/// `GET /venues/{id}/availability/?date=` — the 30-minute grid for one day.
public struct AvailabilityGrid: Decodable, Hashable, Sendable {
    public struct Buckets: Decodable, Hashable, Sendable {
        @LossyArray public var availableSlots: [SlotStart]
        @LossyArray public var bookedSlots: [SlotStart]
    }

    @DefaultFalse public var isHoliday: Bool
    public var slots: Buckets?

    /// Every start in time order, free or not.
    public var starts: [SlotStart] {
        let free = (slots?.availableSlots ?? []).map { start in
            var copy = start
            copy.isBooked = false
            return copy
        }
        let taken = (slots?.bookedSlots ?? []).map { start in
            var copy = start
            copy.isBooked = true
            return copy
        }
        return (free + taken).sorted { $0.start < $1.start }
    }
}

/// One start on the grid: "18:00", and which durations can be booked from it.
public struct SlotStart: Decodable, Hashable, Sendable, Identifiable {
    /// "HH:MM", venue local time.
    @DefaultEmpty public var start: String
    @DefaultEmpty public var end: String
    @LossyArray public var availableDurations: [Int]
    public var isBooked = false

    public var id: String {
        start
    }

    private enum CodingKeys: String, CodingKey {
        case start, end, availableDurations
    }

    /// "06:00 pm".
    public var label: String {
        TimeOfDay.label(start)
    }
}

/// `GET /venues/{id}/availability/?date&start&duration` — the courts free for that exact window, priced.
public struct CourtsForWindow: Decodable, Hashable, Sendable {
    @DefaultFalse public var isHoliday: Bool
    @LossyArray public var courts: [PricedCourt]
}

public struct PricedCourt: Decodable, Hashable, Sendable, Identifiable {
    public let id: CourtID
    @DefaultEmpty public var name: String
    @DefaultEmpty public var courtType: String
    /// The server's price for this court, start and duration.
    @StrictDecimal public var price: Decimal

    public var priceMoney: Money {
        Money(price, currency: Money.defaultCurrency)
    }
}

public struct VenueDurations: Decodable, Hashable, Sendable {
    @LossyArray public var durations: [Int]
}

/// "HH:MM[:SS]" helpers for venue-local times.
public enum TimeOfDay {
    /// Minutes since midnight; nil when unreadable.
    public static func minutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// "18:00" → "06:00 pm".
    public static func label(_ text: String) -> String {
        guard let total = minutes(text) else { return text }
        return label(minutes: total)
    }

    public static func label(minutes total: Int) -> String {
        let hour = (total / 60) % 24
        let minute = total % 60
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%02d:%02d %@", twelve, minute, hour < 12 ? "am" : "pm")
    }
}
