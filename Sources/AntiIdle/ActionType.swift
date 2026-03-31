import Foundation
import CoreGraphics

// MARK: - Action Type

enum ActionType: String, CaseIterable, Identifiable {
    case mouseJitter     = "mouseJitter"
    case visibleMovement = "visibleMovement"
    case keepAliveClick  = "keepAliveClick"
    case burstClick      = "burstClick"
    case dragGesture     = "dragGesture"
    case scrollDrag      = "scrollDrag"
    case shiftKeypress   = "shiftKeypress"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mouseJitter:     return "Mouse Jitter"
        case .visibleMovement: return "Visible Movement"
        case .keepAliveClick:  return "Keep-Alive Clicks"
        case .burstClick:      return "Burst Clicks"
        case .dragGesture:     return "Drag Gesture"
        case .scrollDrag:      return "Scroll Drag"
        case .shiftKeypress:   return "Shift Keypress"
        }
    }

    var defaultConfig: ActionConfig {
        switch self {
        case .mouseJitter:     return ActionConfig(enabled: true, eventsPerMinute: 1)
        case .shiftKeypress:   return ActionConfig(enabled: true, eventsPerMinute: 1)
        case .visibleMovement: return ActionConfig(enabled: false, eventsPerMinute: 0, movementRadius: .medium)
        case .burstClick:      return ActionConfig(enabled: false, eventsPerMinute: 0, burstClickCount: 100)
        default:               return ActionConfig(enabled: false, eventsPerMinute: 0)
        }
    }

    var rateOptions: [Int] {
        switch self {
        case .burstClick:  return [1, 2, 3, 5]
        case .dragGesture, .scrollDrag: return [1, 2, 3, 5, 10]
        default: return [1, 2, 3, 5, 10, 15, 20, 30, 60]
        }
    }
}

// MARK: - Action Config

struct ActionConfig: Codable, Equatable {
    var enabled: Bool
    var eventsPerMinute: Int
    var movementRadius: MovementRadius?
    var burstClickCount: Int?
}

// MARK: - Movement Radius

enum MovementRadius: String, Codable, CaseIterable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"

    var displayName: String {
        switch self {
        case .small:  return "Small (50-100px)"
        case .medium: return "Medium (100-300px)"
        case .large:  return "Large (300-600px)"
        }
    }

    var range: ClosedRange<CGFloat> {
        switch self {
        case .small:  return 50...100
        case .medium: return 100...300
        case .large:  return 300...600
        }
    }
}
