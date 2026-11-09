import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    enum Tracking: String, Codable, CaseIterable { case repetitions, seconds, cardio }
    let id: String
    var name: String
    var group: String
    var tracking: Tracking
    var defaultTarget: Int

    static let builtIn: [Exercise] = [
        .init(id: "treadmill", name: "트레드밀", group: "유산소", tracking: .cardio, defaultTarget: 1),
        .init(id: "shoulderpress", name: "숄더 프레스", group: "운동기구", tracking: .repetitions, defaultTarget: 10),
        .init(id: "latpulldown", name: "랫 풀다운", group: "운동기구", tracking: .repetitions, defaultTarget: 12),
        .init(id: "reardelt", name: "리어 델트 머신", group: "운동기구", tracking: .repetitions, defaultTarget: 15),
        .init(id: "legextension", name: "시티드 레그 익스텐션", group: "운동기구", tracking: .repetitions, defaultTarget: 12),
        .init(id: "legcurl", name: "레그 컬", group: "운동기구", tracking: .repetitions, defaultTarget: 12),
        .init(id: "legpress", name: "레그 프레스", group: "운동기구", tracking: .repetitions, defaultTarget: 10),
        .init(id: "armcurl", name: "암 컬 머신", group: "운동기구", tracking: .repetitions, defaultTarget: 12),
        .init(id: "pushup", name: "푸시업", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 10),
        .init(id: "squat", name: "스쿼트", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 15),
        .init(id: "lunge", name: "런지", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 12),
        .init(id: "plank", name: "플랭크", group: "맨몸 운동", tracking: .seconds, defaultTarget: 30),
        .init(id: "bodyinversion", name: "바디 인버전", group: "맨몸 운동", tracking: .seconds, defaultTarget: 60),
        .init(id: "burpee", name: "버피", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 8),
        .init(id: "mountain", name: "마운틴 클라이머", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 20),
        .init(id: "dip", name: "트라이셉스 딥스", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 8),
        .init(id: "legraise", name: "레그 레이즈", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 12),
        .init(id: "crunch", name: "크런치", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 15),
        .init(id: "bridge", name: "글루트 브리지", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 15),
        .init(id: "jumpjack", name: "점핑 잭", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 30),
        .init(id: "inchworm", name: "인치웜", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 8),
        .init(id: "benchpress", name: "벤치 프레스", group: "프리웨이트", tracking: .repetitions, defaultTarget: 10),
        .init(id: "dumbbellrow", name: "덤벨 로우", group: "프리웨이트", tracking: .repetitions, defaultTarget: 12),
        .init(id: "deadlift", name: "데드리프트", group: "프리웨이트", tracking: .repetitions, defaultTarget: 8),
        .init(id: "lateralraise", name: "레터럴 레이즈", group: "프리웨이트", tracking: .repetitions, defaultTarget: 15),
        .init(id: "calfraise", name: "카프 레이즈", group: "맨몸 운동", tracking: .repetitions, defaultTarget: 15)
    ]
}

struct LoggedSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var value: Int
    var date = Date()
    var weight: Double?
    var distanceKm: Double?
    var durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case id, value, reps, date, loggedAt, weight, distanceKm, durationSeconds, done
    }

    init(id: UUID = UUID(), value: Int, date: Date = Date(), weight: Double? = nil, distanceKm: Double? = nil, durationSeconds: Double? = nil) {
        self.id = id
        self.value = value
        self.date = date
        self.weight = weight
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        if let val = try? container.decode(Int.self, forKey: .value) {
            self.value = val
        } else if let reps = try? container.decode(Int.self, forKey: .reps) {
            self.value = reps
        } else {
            self.value = 0
        }
        if let d = try? container.decode(Date.self, forKey: .date) {
            self.date = d
        } else if let loggedAt = try? container.decode(Double.self, forKey: .loggedAt) {
            self.date = Date(timeIntervalSince1970: loggedAt / 1000.0)
        } else {
            self.date = Date()
        }
        self.weight = try? container.decodeIfPresent(Double.self, forKey: .weight)
        self.distanceKm = try? container.decodeIfPresent(Double.self, forKey: .distanceKm)
        self.durationSeconds = try? container.decodeIfPresent(Double.self, forKey: .durationSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(value, forKey: .value)
        try container.encode(value, forKey: .reps)
        try container.encode(true, forKey: .done)
        try container.encode(date, forKey: .date)
        try container.encode(date.timeIntervalSince1970 * 1000.0, forKey: .loggedAt)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(distanceKm, forKey: .distanceKm)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
    }
}

struct WorkoutDay: Identifiable, Codable, Hashable { var id: String; var sets: [String: [LoggedSet]] = [:] }

struct AppSettings: Codable, Equatable {
    var activeExerciseIDs = Array(Exercise.builtIn.filter { $0.tracking != .cardio }.prefix(7).map(\.id))
    var defaultRestSeconds = 60
    var timerSound = true
    var keepAwake = false
    var repHaptics = true
    var sets = 3

    enum CodingKeys: String, CodingKey {
        case activeExerciseIDs, active, defaultRestSeconds, restTime, timerSound, keepAwake, repHaptics, sets
    }

    init(activeExerciseIDs: [String] = Array(Exercise.builtIn.filter { $0.tracking != .cardio }.prefix(7).map(\.id)), defaultRestSeconds: Int = 60, timerSound: Bool = true, keepAwake: Bool = false, repHaptics: Bool = true, sets: Int = 3) {
        self.activeExerciseIDs = activeExerciseIDs
        self.defaultRestSeconds = defaultRestSeconds
        self.timerSound = timerSound
        self.keepAwake = keepAwake
        self.repHaptics = repHaptics
        self.sets = sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? container.decode([String].self, forKey: .activeExerciseIDs) {
            self.activeExerciseIDs = list
        } else if let list = try? container.decode([String].self, forKey: .active) {
            self.activeExerciseIDs = list
        } else {
            self.activeExerciseIDs = Array(Exercise.builtIn.filter { $0.tracking != .cardio }.prefix(7).map(\.id))
        }
        if let rest = try? container.decode(Int.self, forKey: .defaultRestSeconds) {
            self.defaultRestSeconds = rest
        } else if let rest = try? container.decode(Int.self, forKey: .restTime) {
            self.defaultRestSeconds = rest
        } else {
            self.defaultRestSeconds = 60
        }
        self.timerSound = (try? container.decode(Bool.self, forKey: .timerSound)) ?? true
        self.keepAwake = (try? container.decode(Bool.self, forKey: .keepAwake)) ?? false
        self.repHaptics = (try? container.decode(Bool.self, forKey: .repHaptics)) ?? true
        self.sets = (try? container.decode(Int.self, forKey: .sets)) ?? 3
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeExerciseIDs, forKey: .activeExerciseIDs)
        try container.encode(activeExerciseIDs, forKey: .active)
        try container.encode(defaultRestSeconds, forKey: .defaultRestSeconds)
        try container.encode(defaultRestSeconds, forKey: .restTime)
        try container.encode(timerSound, forKey: .timerSound)
        try container.encode(keepAwake, forKey: .keepAwake)
        try container.encode(repHaptics, forKey: .repHaptics)
        try container.encode(sets, forKey: .sets)
    }
}

struct StoredData: Codable { var settings = AppSettings(); var customExercises: [Exercise] = []; var days: [String: WorkoutDay] = [:] }
