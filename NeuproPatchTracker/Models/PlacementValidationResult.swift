import Foundation

enum PlacementValidationReason: Equatable, Sendable {
    case outsideApprovedRegion
    case recentlyUsedLocation(daysAgo: Int)
    case regionUsedYesterday(regionName: String)

    var code: String {
        switch self {
        case .outsideApprovedRegion: return "outside_approved_region"
        case .recentlyUsedLocation: return "recently_used_location"
        case .regionUsedYesterday: return "region_used_yesterday"
        }
    }

    var title: String {
        switch self {
        case .outsideApprovedRegion: return "Not a placement area"
        case .recentlyUsedLocation: return "Recently used spot"
        case .regionUsedYesterday: return "Choose another area"
        }
    }

    var message: String {
        switch self {
        case .outsideApprovedRegion:
            return "Tap one of the highlighted areas to place your patch."
        case .recentlyUsedLocation:
            return "You recently used this spot. Choose another location."
        case .regionUsedYesterday:
            return "You used this area yesterday. Choose a different area today."
        }
    }
}

enum PlacementRecommendation: Equatable, Sendable {
    case alternateSide(preferred: BodySide)

    var code: String {
        switch self {
        case .alternateSide: return "alternate_side"
        }
    }

    var title: String { "Rotation suggestion" }

    var message: String {
        switch self {
        case .alternateSide:
            return "Consider using the opposite side from yesterday to help rotate your patch locations."
        }
    }
}

struct PlacementValidationResult: Equatable, Sendable {
    let blockingReasons: [PlacementValidationReason]
    let recommendations: [PlacementRecommendation]

    var isValid: Bool { blockingReasons.isEmpty }

    static let valid = PlacementValidationResult(blockingReasons: [], recommendations: [])
    static let outsideApprovedRegion = PlacementValidationResult(
        blockingReasons: [.outsideApprovedRegion], recommendations: [])
}
