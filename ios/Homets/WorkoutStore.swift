import Observation
import UIKit
import SwiftUI
import AlarmKit
import ActivityKit
import AVFoundation
@preconcurrency import UserNotifications

@available(iOS 26.0, *)
private struct RestAlarmMetadata: AlarmMetadata {}

@MainActor @Observable
final class WorkoutStore {
    private(set) var data: StoredData
    var restRemaining: Int?
    var activeTimedExerciseID: String?
    private var restTask: Task<Void, Never>?
    private static let storageKey = "homets_native_v1"
    var defaultSets = UserDefaults.standard.integer(forKey: "homets.sets") == 0 ? 3 : UserDefaults.standard.integer(forKey: "homets.sets")
    private struct PlannedState: Codable { var day: String; var overrides: [String: WatchPlanned]; var defaultSetsAt: Date }
    private static let plannedKey = "homets.planned.v1"
    private static let ackedKey = "homets.watch.acked"
    /// 운동별 세트 수(오늘 한정). 워치에서 바꾼 값과 시각 기준으로 합친다.
    private(set) var plannedOverrides: [String: WatchPlanned] = [:]
    private(set) var defaultSetsAt = Date.distantPast
    private var ackedWatchIDs: [UUID] = []
    private var restDeadline: Date?
    private var systemAlarmID: UUID?
    private var restSoundPlayer: AVAudioPlayer?
    var watchAcked: [UUID] { ackedWatchIDs }
    func plannedSets(_ id: String) -> Int {
        if let item = plannedOverrides[id], item.at > defaultSetsAt, item.at >= Calendar.current.startOfDay(for: .now) { return item.count }
        return defaultSets
    }
    func changeSets(_ delta: Int, id: String? = nil) {
        if let id {
            let count = min(10, max(1, max(today.sets[id]?.count ?? 0, plannedSets(id) + delta)))
            plannedOverrides[id] = WatchPlanned(count: count, at: .now)
        } else {
            defaultSets = min(10, max(1, defaultSets + delta)); UserDefaults.standard.set(defaultSets, forKey: "homets.sets")
            plannedOverrides = [:]; defaultSetsAt = .now
        }
        savePlanned(); WatchSync.shared.push()
    }
    private func savePlanned() {
        let state = PlannedState(day: dateKey(), overrides: plannedOverrides, defaultSetsAt: defaultSetsAt)
        if let encoded = try? JSONEncoder().encode(state) { UserDefaults.standard.set(encoded, forKey: Self.plannedKey) }
    }
    private func loadPlanned() {
        if let raw = UserDefaults.standard.data(forKey: Self.plannedKey), let state = try? JSONDecoder().decode(PlannedState.self, from: raw), state.day == dateKey() {
            plannedOverrides = state.overrides; defaultSetsAt = state.defaultSetsAt
        }
        if let raw = UserDefaults.standard.data(forKey: Self.ackedKey), let ids = try? JSONDecoder().decode([UUID].self, from: raw) { ackedWatchIDs = ids }
    }
    private func ack(_ id: UUID) {
        guard !ackedWatchIDs.contains(id) else { return }
        ackedWatchIDs.append(id)
        if ackedWatchIDs.count > 300 { ackedWatchIDs.removeFirst(ackedWatchIDs.count - 300) }
        if let encoded = try? JSONEncoder().encode(ackedWatchIDs) { UserDefaults.standard.set(encoded, forKey: Self.ackedKey) }
    }

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.storageKey), let decoded = try? JSONDecoder().decode(StoredData.self, from: raw) { data = decoded }
        else { data = StoredData() }
        UIApplication.shared.isIdleTimerDisabled = data.settings.keepAwake
        loadPlanned()
    }
    var exercises: [Exercise] { Exercise.builtIn + data.customExercises }
    var activeExercises: [Exercise] { data.settings.activeExerciseIDs.compactMap { id in exercises.first { $0.id == id } } }
    var sortedDays: [WorkoutDay] { data.days.values.filter { $0.sets.values.contains { !$0.isEmpty } }.sorted { $0.id > $1.id } }
    var today: WorkoutDay { data.days[dateKey()] ?? WorkoutDay(id: dateKey()) }
    func loggedSets(for exercise: Exercise, day: WorkoutDay? = nil) -> [LoggedSet] { (day ?? today).sets[exercise.id] ?? [] }
    func suggestedTarget(for exercise: Exercise) -> Int {
        let recent = sortedDays.flatMap { $0.sets[exercise.id] ?? [] }.sorted { $0.date > $1.date }.prefix(3)
        guard !recent.isEmpty else { return exercise.defaultTarget }
        return max(1, Int(round(Double(recent.reduce(0) { $0 + $1.value }) / Double(recent.count))))
    }
    func recentWeights(for exercise: Exercise) -> [Double] {
        sortedDays.flatMap { $0.sets[exercise.id] ?? [] }.sorted { $0.date > $1.date }.compactMap(\.weight).prefix(3).map { $0 }
    }
    func suggestedWeight(for exercise: Exercise) -> Double? {
        let weights = recentWeights(for: exercise)
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }
    func previousBest(for exercise: Exercise) -> Int? {
        sortedDays.dropFirst(sortedDays.first?.id == dateKey() ? 1 : 0).flatMap { $0.sets[exercise.id] ?? [] }.map(\.value).max()
    }
    func reorderExercises(from: IndexSet, to: Int) {
        let ids = activeExercises.map(\.id)
        guard ids.count == data.settings.activeExerciseIDs.count else { return }
        var reordered = ids; reordered.move(fromOffsets: from, toOffset: to)
        data.settings.activeExerciseIDs = reordered; save()
    }
    @discardableResult func moveExercise(_ source: String, before target: String) -> Bool {
        guard source != target, let from = data.settings.activeExerciseIDs.firstIndex(of: source), let to = data.settings.activeExerciseIDs.firstIndex(of: target) else { return false }
        let item = data.settings.activeExerciseIDs.remove(at: from)
        let destination = data.settings.activeExerciseIDs.firstIndex(of: target) ?? to
        data.settings.activeExerciseIDs.insert(item, at: destination)
        save(); return true
    }

    func log(_ value: Int, for exercise: Exercise, weight: Double? = nil, distance: Double? = nil, duration: Double? = nil) {
        guard restRemaining == nil, activeTimedExerciseID == nil else { return }
        var day = today; day.sets[exercise.id, default: []].append(LoggedSet(value: value, weight: weight, distanceKm: distance, durationSeconds: duration)); data.days[day.id] = day
        save()
        if day.sets[exercise.id, default: []].count != plannedSets(exercise.id) {
            startRest(seconds: data.settings.defaultRestSeconds)
        }
    }
    func beginTimedExercise(_ exercise: Exercise) -> Bool {
        guard restRemaining == nil, activeTimedExerciseID == nil else { return false }
        activeTimedExerciseID = exercise.id
        return true
    }
    func finishTimedExercise(_ value: Int, for exercise: Exercise) {
        guard activeTimedExerciseID == exercise.id else { return }
        activeTimedExerciseID = nil
        log(value, for: exercise)
    }
    func updateSet(at index: Int, value: Int, for exercise: Exercise, weight: Double? = nil, distance: Double? = nil, duration: Double? = nil) {
        var day = today; guard var items = day.sets[exercise.id], items.indices.contains(index) else { return }
        items[index] = LoggedSet(value: value, date: items[index].date, weight: weight, distanceKm: distance, durationSeconds: duration)
        day.sets[exercise.id] = items
        data.days[day.id] = day; save()
    }
    func removeSet(at index: Int, for exercise: Exercise) {
        var day = today; guard day.sets[exercise.id]?.indices.contains(index) == true else { return }
        day.sets[exercise.id]?.remove(at: index); data.days[day.id] = day; stopRest(); save()
    }
    func resetToday(for exercise: Exercise) {
        var day = today; day.sets[exercise.id] = []; data.days[day.id] = day; stopRest(); save()
    }
    func cancelLastSet(for exercise: Exercise) {
        var day = today; guard day.sets[exercise.id]?.popLast() != nil else { return }
        data.days[day.id] = day; stopRest(); save()
    }
    func startRest(seconds: Int) {
        stopRest(); restRemaining = max(1, seconds); restDeadline = Date.now.addingTimeInterval(Double(max(1, seconds))); scheduleNotification(after: restRemaining!)
        restTask = Task { [weak self] in
            while let self, let remaining = self.restRemaining, remaining > 0 {
                try? await Task.sleep(for: .seconds(1)); guard !Task.isCancelled else { return }
                let seconds = max(0, Int(ceil(self.restDeadline?.timeIntervalSinceNow ?? 0)))
                self.restRemaining = seconds == 0 ? nil : seconds
                if seconds == 0, self.data.settings.timerSound {
                    if self.systemAlarmID != nil {
                        // 시스템 알람이 울리는 중: 앱이 켜져 있으면 잠깐 울린 뒤 멈춘다.
                        Task { [weak self] in try? await Task.sleep(for: .seconds(3)); self?.cancelSystemAlarm() }
                    } else {
                        self.playRestSound()
                    }
                }
            }
        }
    }
    func adjustRest(_ delta: Int) { guard let value = restRemaining else { return }; startRest(seconds: max(1, value + delta)) }
    func stopRest() { restTask?.cancel(); restTask = nil; restRemaining = nil; cancelSystemAlarm(); UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["homets-rest"]) }
    func scheduleExerciseTimerNotification(after seconds: Int, exerciseName: String) {
        guard data.settings.timerSound else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "HOMETS"
            content.body = hometsIsEnglish ? "\(exerciseName) timer is complete." : "\(exerciseName) 시간이 끝났습니다."
            content.sound = UNNotificationSound(named: .init("timer-double-beep.wav"))
            content.interruptionLevel = .timeSensitive
            let request = UNNotificationRequest(identifier: "homets-exercise-timer", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false))
            center.removePendingNotificationRequests(withIdentifiers: ["homets-exercise-timer"])
            center.add(request)
        }
    }
    func apply(settings: AppSettings) { data.settings = settings; UIApplication.shared.isIdleTimerDisabled = settings.keepAwake; save() }
    func replace(with restored: StoredData) {
        stopRest(); data = restored
        UIApplication.shared.isIdleTimerDisabled = restored.settings.keepAwake
        save()
    }
    func addExercise(name: String, tracking: Exercise.Tracking) {
        let item = Exercise(id: "custom_\(UUID().uuidString.lowercased())", name: name, group: "사용자 운동", tracking: tracking, defaultTarget: tracking == .seconds ? 30 : 12)
        data.customExercises.append(item); save()
    }
    private func save() {
        if let encoded = try? JSONEncoder().encode(data) { UserDefaults.standard.set(encoded, forKey: Self.storageKey) }
        WatchSync.shared.push()
    }
    func watchPayload() -> WatchPayload {
        var list = activeExercises.filter { $0.tracking != .cardio }
        let sortMode = UserDefaults.standard.string(forKey: "homets.sort") ?? "default"
        // 아이폰 운동 목록의 정렬 설정을 워치에도 그대로 적용한다(완료 운동을 아래로 보내는 기본 정렬은 워치가 실시간으로 처리).
        switch sortMode {
        case "name": list.sort { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }
        case "group": list.sort { ($0.localizedGroup, $0.localizedName) < ($1.localizedGroup, $1.localizedName) }
        default: break
        }
        var hints: [String: WatchHint] = [:]
        for exercise in list { hints[exercise.id] = WatchHint(weight: suggestedWeight(for: exercise), target: suggestedTarget(for: exercise)) }
        return WatchPayload(english: hometsIsEnglish, exercises: list, restSeconds: data.settings.defaultRestSeconds,
                            defaultSets: defaultSets, dayKey: dateKey(), today: today.sets, hints: hints, sortMode: sortMode,
                            overrides: plannedOverrides, defaultSetsAt: defaultSetsAt, acked: ackedWatchIDs)
    }
    func ingestWatch(_ message: WatchSetMessage) {
        var day = data.days[message.dayKey] ?? WorkoutDay(id: message.dayKey)
        var items = day.sets[message.exerciseID, default: []]
        // 이미 처리한 세트(삭제된 것 포함)는 다시 추가하지 않는다.
        guard !ackedWatchIDs.contains(message.set.id), !items.contains(where: { $0.id == message.set.id }) else { return }
        ack(message.set.id)
        items.append(message.set); items.sort { $0.date < $1.date }
        day.sets[message.exerciseID] = items; data.days[message.dayKey] = day
        save()
    }
    func ingestWatchDelete(_ message: WatchDeleteMessage) {
        ack(message.setID)
        guard var day = data.days[message.dayKey], var items = day.sets[message.exerciseID], let index = items.firstIndex(where: { $0.id == message.setID }) else { save(); return }
        items.remove(at: index); day.sets[message.exerciseID] = items; data.days[message.dayKey] = day
        save()
    }
    func ingestWatchPlanned(_ message: WatchPlannedMessage) {
        guard message.dayKey == dateKey() else { return }
        if let current = plannedOverrides[message.exerciseID], current.at >= message.planned.at { return }
        let floor = max(1, today.sets[message.exerciseID]?.count ?? 0)
        plannedOverrides[message.exerciseID] = WatchPlanned(count: min(10, max(floor, message.planned.count)), at: message.planned.at)
        savePlanned(); WatchSync.shared.push()
    }
    private func dateKey(_ date: Date = .now) -> String { let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    private func scheduleNotification(after seconds: Int) {
        guard data.settings.timerSound else { return }
        // 잠금 화면에서도 아이폰에서 소리가 나도록 시스템 알람을 쓴다. 알림은 잠금 상태에서 워치로만 전달되는 경우가 있다.
        if #available(iOS 26.0, *) { scheduleSystemAlarm(after: seconds) } else { scheduleLocalNotification(after: seconds) }
    }
    private func scheduleLocalNotification(after seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "HOMETS"
            content.body = UserDefaults.standard.string(forKey: "homets.language") == "en" ? "Rest is over. Start your next set." : "휴식이 끝났습니다. 다음 세트를 시작하세요."
            content.sound = UNNotificationSound(named: .init("timer-double-beep.wav"))
            content.interruptionLevel = .timeSensitive
            let request = UNNotificationRequest(identifier: "homets-rest", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false))
            center.removePendingNotificationRequests(withIdentifiers: ["homets-rest"])
            center.add(request)
        }
    }
    @available(iOS 26.0, *)
    private func scheduleSystemAlarm(after seconds: Int) {
        cancelSystemAlarm()
        let id = UUID(); systemAlarmID = id
        let deadline = Date.now.addingTimeInterval(TimeInterval(max(1, seconds)))
        Task { [weak self] in
            guard let self else { return }
            do {
                let manager = AlarmManager.shared
                let state = manager.authorizationState == .notDetermined ? try await manager.requestAuthorization() : manager.authorizationState
                guard state == .authorized, self.systemAlarmID == id, self.restRemaining != nil else {
                    if self.systemAlarmID == id { self.scheduleLocalNotification(after: seconds) }
                    return
                }
                let title: LocalizedStringResource = hometsIsEnglish ? "Rest complete" : "휴식 완료"
                let alert: AlarmPresentation.Alert
                if #available(iOS 26.1, *) {
                    alert = AlarmPresentation.Alert(title: title)
                } else {
                    let stop = AlarmButton(text: hometsIsEnglish ? "Dismiss" : "종료", textColor: .white, systemImageName: "stop.circle")
                    alert = AlarmPresentation.Alert(title: title, stopButton: stop)
                }
                let presentation = AlarmPresentation(alert: alert)
                let attributes = AlarmAttributes<RestAlarmMetadata>(presentation: presentation, metadata: RestAlarmMetadata(), tintColor: HometsStyle.blue)
                let configuration = AlarmManager.AlarmConfiguration<RestAlarmMetadata>.alarm(schedule: .fixed(deadline), attributes: attributes, sound: .named("timer-double-beep.wav"))
                _ = try await manager.schedule(id: id, configuration: configuration)
            } catch {
                if self.systemAlarmID == id { self.scheduleLocalNotification(after: seconds) }
            }
        }
    }
    private func cancelSystemAlarm() {
        if #available(iOS 26.0, *), let id = systemAlarmID { try? AlarmManager.shared.cancel(id: id) }
        systemAlarmID = nil
    }
    private func playRestSound() {
        guard let url = Bundle.main.url(forResource: "timer-double-beep", withExtension: "wav") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            restSoundPlayer = player
            player.play()
            // 재생이 끝나면 세션을 해제해 다른 앱(YouTube 등)의 볼륨을 원래대로 복원한다.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(player.duration + 0.3))
                guard self?.restSoundPlayer === player, !player.isPlaying else { return }
                self?.restSoundPlayer = nil
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch { print("Rest sound playback failed: \(error)") }
    }
}
