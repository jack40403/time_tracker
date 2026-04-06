import Foundation
import ActivityKit

// This must match the keys used in Flutter's _syncToLiveActivity()
struct TimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var category: String
        var startTime: Double? // millisecondsSinceEpoch
        var isRunning: Bool
        var elapsed: Int
    }

    // Static data (dynamic part is in ContentState)
    var name: String
}
