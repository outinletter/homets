import Foundation
import Observation
import SwiftUI
import WatchConnectivity
import WatchKit
@preconcurrency import UserNotifications

/// 워치 앱 상태: 아이폰에서 받은 운동 목록·설정, 오늘 기록, 휴식 타이머.
@MainActor @Observable
final class WatchStore: NSObject, WCSessionDelegate {
    private(set) var payload: WatchPayload
    private var pending: [WatchSetMessage]
    private var setOverrides: [String: Int] = [:]
    var restRemaining: Int?
    private var restDeadline: Date?
    private var restTask: Task<Void, Never>?
    private static let payloadKey = "watch.payload"
    private static let pendingKey = "watch.pending"
    private static let restID = "homets-watch-rest"

    override init() {
        let defaults = UserDefaults.standard
        payload = defaults.data(forKey: Self.payloadKey).flatMap { try? JSONDecoder().decode(WatchPayload.self, from: $0) } ?? .standalone
        pending = defaults.data(forKey: Self.pendingKey).flatMap { try? JSONDecoder().decode([WatchSetMessage].self, from: $0) } ?? []
        super.init()
    }

    var english: Bool { payload.english }
    func text(_ korean: String, _ english: String) -> String { payload.english ? english : korean }
    var exercises: [Exercise] { payload.exercises }

    var dayKey: String {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: .now)
    }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        guard !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: 기록

    func sets(for exercise: Exercise) -> [LoggedSet] {
        guard payload.dayKey == dayKey else { return pendingSets(for: exercise) }
        var items = payload.today[exercise.id] ?? []
        for set in pendingSets(for: exercise) where !items.contains(where: { $0.id == set.id }) { items.append(set) }
        return items.sorted { $0.date < $1.date }
    }
    private func pendingSets(for exercise: Exercise) -> [LoggedSet] {
        pending.filter { $0.exerciseID == exercise.id && $0.dayKey == dayKey }.map(\.set)
    }
    func plannedSets(_ exercise: Exercise) -> Int { setOverrides[exercise.id] ?? payload.defaultSets }
    func changePlannedSets(_ delta: Int, for exercise: Exercise) {
        setOverrides[exercise.id] = min(10, max(max(1, sets(for: exercise).count), plannedSets(exercise) + delta))
    }
    func defaultWeight(for exercise: Exercise) -> Double? { payload.hints[exercise.id]?.weight }
    func defaultReps(for exercise: Exercise) -> Int { payload.hints[exercise.id]?.target ?? exercise.defaultTarget }
    func supportsWeight(_ exercise: Exercise) -> Bool { exercise.tracking == .repetitions && exercise.id != "pushup" }

    func log(_ value: Int, weight: Double?, for exercise: Exercise) {
        guard restRemaining == nil else { return }
        let set = LoggedSet(value: value, weight: (weight ?? 0) > 0 ? weight : nil)
        let message = WatchSetMessage(exerciseID: exercise.id, dayKey: dayKey, set: set)
        pending.append(message)
        if let data = try? JSONEncoder().encode(pending) { UserDefaults.standard.set(data, forKey: Self.pendingKey) }
        if WCSession.default.activationState == .activated, let data = try? JSONEncoder().encode(message) {
            WCSession.default.transferUserInfo([WatchKey.set: data])
        }
        WKInterfaceDevice.current().play(.success)
        if sets(for: exercise).count < plannedSets(exercise) { startRest(seconds: payload.restSeconds) }
    }

    // MARK: 휴식 타이머

    func startRest(seconds: Int) {
        stopRest()
        let length = max(1, seconds)
        restRemaining = length
        restDeadline = Date.now.addingTimeInterval(Double(length))
        scheduleNotification(after: length)
        restTask = Task { [weak self] in
            while let self, self.restRemaining != nil {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                let left = max(0, Int(ceil(self.restDeadline?.timeIntervalSinceNow ?? 0)))
                if left == 0 {
                    self.restRemaining = nil; self.restDeadline = nil
                    WKInterfaceDevice.current().play(.notification)
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.restID])
                } else if left != self.restRemaining { self.restRemaining = left }
            }
        }
    }
    func adjustRest(_ delta: Int) { if let value = restRemaining { startRest(seconds: max(1, value + delta)) } }
    func stopRest() {
        restTask?.cancel(); restTask = nil; restRemaining = nil; restDeadline = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.restID])
    }
    private func scheduleNotification(after seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "HOMETS"
        content.body = text("휴식이 끝났습니다. 다음 세트를 시작하세요.", "Rest is over. Start your next set.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: Self.restID, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: WatchConnectivity

    private func apply(_ data: Data) {
        guard let received = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        payload = received
        UserDefaults.standard.set(data, forKey: Self.payloadKey)
        let known = Set(received.today.values.flatMap { $0 }.map(\.id))
        pending.removeAll { known.contains($0.set.id) || $0.dayKey != dayKey }
        if let encoded = try? JSONEncoder().encode(pending) { UserDefaults.standard.set(encoded, forKey: Self.pendingKey) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard let data = session.receivedApplicationContext[WatchKey.payload] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchKey.payload] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
}
