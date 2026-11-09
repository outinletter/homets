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
    var setOverrides: [String: Int] = [:]
    private var restDeadline: Date?
    private var systemAlarmID: UUID?
    private var restSoundPlayer: AVAudioPlayer?
    func plannedSets(_ id: String) -> Int { setOverrides[id] ?? defaultSets }
    func changeSets(_ delta: Int, id: String? = nil) {
        if let id { setOverrides[id] = min(10, max(1, max(today.sets[id]?.count ?? 0, plannedSets(id) + delta))) }
        else { defaultSets = min(10, max(1, defaultSets + delta)); UserDefaults.standard.set(defaultSets, forKey: "homets.sets"); setOverrides = [:] }
    }

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.storageKey), let decoded = try? JSONDecoder().decode(StoredData.self, from: raw) { data = decoded }
        else { data = StoredData() }
        UIApplication.shared.isIdleTimerDisabled = data.settings.keepAwake
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
    func previousBest(for exercise: Exercise) -> Int? {
        sortedDays.dropFirst(sortedDays.first?.id == dateKey() ? 1 : 0).flatMap { $0.sets[exercise.id] ?? [] }.map(\.value).max()
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
        startRest(seconds: data.settings.defaultRestSeconds)
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
                    self.cancelSystemAlarm()
                    self.playRestSound()
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
    private func save() { if let encoded = try? JSONEncoder().encode(data) { UserDefaults.standard.set(encoded, forKey: Self.storageKey) } }
    private func dateKey(_ date: Date = .now) -> String { let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    private func scheduleNotification(after seconds: Int) {
        guard data.settings.timerSound else { return }
        scheduleLocalNotification(after: seconds)
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            restSoundPlayer = try AVAudioPlayer(contentsOf: url)
            restSoundPlayer?.volume = 1.0
            restSoundPlayer?.play()
        } catch { print("Rest sound playback failed: \(error)") }
    }
}
