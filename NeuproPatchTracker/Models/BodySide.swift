import Foundation

enum BodySide: String, Codable, CaseIterable, Sendable {
    case left
    case right

    var opposite: BodySide {
        switch self {
        case .left: return .right
        case .right: return .left
        }
    }

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}
