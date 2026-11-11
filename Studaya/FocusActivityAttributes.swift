import ActivityKit
import Foundation

struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var resting: Bool
        var end: Date
        var restEnd: Date
        var pausedSeconds: Int
        var paused: Bool
        var isFreeFocus: Bool? = nil
    }
    var runID: String
}
