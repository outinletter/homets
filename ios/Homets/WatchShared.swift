import Foundation

/// 아이폰 앱과 워치 앱이 함께 쓰는 동기화 모델 (두 타깃에 모두 포함).
struct WatchHint: Codable, Equatable {
    var weight: Double?
    var target: Int
}

struct WatchPayload: Codable, Equatable {
    var english = false
    var exercises: [Exercise] = []
    var restSeconds = 60
    var defaultSets = 3
    var dayKey = ""
    var today: [String: [LoggedSet]] = [:]
    var hints: [String: WatchHint] = [:]

    static var standalone: WatchPayload {
        WatchPayload(exercises: Array(Exercise.builtIn.filter { $0.tracking != .cardio }.prefix(7)))
    }
}

struct WatchSetMessage: Codable, Equatable {
    var exerciseID: String
    var dayKey: String
    var set: LoggedSet
}

enum WatchKey {
    static let payload = "payload"
    static let set = "set"
}
