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
        WatchPayload(english: !(Locale.preferredLanguages.first?.hasPrefix("ko") ?? false), exercises: Array(Exercise.builtIn.filter { $0.tracking != .cardio }.prefix(7)))
    }
}

extension Exercise {
    /// 기본 운동의 영어 이름(아이폰·워치 공용).
    static let englishNames: [String: String] = [
        "treadmill": "Treadmill", "shoulderpress": "Shoulder Press", "latpulldown": "Lat Pulldown", "reardelt": "Rear Delt Machine",
        "legextension": "Seated Leg Extension", "legcurl": "Leg Curl", "legpress": "Leg Press", "armcurl": "Arm Curl Machine",
        "pushup": "Push-ups", "squat": "Squats", "lunge": "Lunges", "plank": "Plank", "bodyinversion": "Body Inversion", "burpee": "Burpees",
        "mountain": "Mountain Climbers", "dip": "Triceps Dips", "legraise": "Leg Raises", "crunch": "Crunches",
        "bridge": "Glute Bridge", "jumpjack": "Jumping Jacks", "inchworm": "Inchworms", "benchpress": "Bench Press",
        "dumbbellrow": "Dumbbell Row", "deadlift": "Deadlift", "lateralraise": "Lateral Raises", "calfraise": "Calf Raises"
    ]
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
