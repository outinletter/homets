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
    private var planned: [String: WatchPlanned] = [:]
    private var deleted: Set<UUID> = []
    private var deleteMessages: [WatchDeleteMessage] = []
    var restRemaining: Int?
    private var restDeadline: Date?
    private var restTask: Task<Void, Never>?
    private static let payloadKey = "watch.payload"
    private static let pendingKey = "watch.pending"
    private static let plannedKey = "watch.planned"
    private static let restID = "homets-watch-rest"

    override init() {
        let defaults = UserDefaults.standard
        if ProcessInfo.processInfo.arguments.contains("-uitest") {
            defaults.removeObject(forKey: Self.payloadKey)
            defaults.removeObject(forKey: Self.pendingKey)
            defaults.removeObject(forKey: Self.plannedKey)
        }
        payload = defaults.data(forKey: Self.payloadKey).flatMap { try? JSONDecoder().decode(WatchPayload.self, from: $0) } ?? .standalone
        pending = defaults.data(forKey: Self.pendingKey).flatMap { try? JSONDecoder().decode([WatchSetMessage].self, from: $0) } ?? []
        if let raw = defaults.data(forKey: Self.plannedKey), let saved = try? JSONDecoder().decode(PlannedSaved.self, from: raw), saved.day == Self.today() { planned = saved.items }
        super.init()
    }
    private struct PlannedSaved: Codable { var day: String; var items: [String: WatchPlanned] }
    private static func today() -> String {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: .now)
    }
    private func savePlanned() {
        if let data = try? JSONEncoder().encode(PlannedSaved(day: dayKey, items: planned)) { UserDefaults.standard.set(data, forKey: Self.plannedKey) }
    }

    var english: Bool { payload.english }
    func text(_ korean: String, _ english: String) -> String { payload.english ? english : korean }
    var exercises: [Exercise] { payload.exercises }
    func name(_ exercise: Exercise) -> String { payload.english ? (Exercise.englishNames[exercise.id] ?? exercise.name) : exercise.name }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    var dayKey: String { Self.dayFormatter.string(from: .now) }
    private var startOfToday: Date { Calendar.current.startOfDay(for: .now) }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        guard !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: 기록

    func sets(for exercise: Exercise) -> [LoggedSet] {
        guard payload.dayKey == dayKey else { return pendingSets(for: exercise).filter { !deleted.contains($0.id) } }
        var items = payload.today[exercise.id] ?? []
        for set in pendingSets(for: exercise) where !items.contains(where: { $0.id == set.id }) { items.append(set) }
        return items.filter { !deleted.contains($0.id) }.sorted { $0.date < $1.date }
    }
    private func pendingSets(for exercise: Exercise) -> [LoggedSet] {
        pending.filter { $0.exerciseID == exercise.id && $0.dayKey == dayKey }.map(\.set)
    }
    func plannedSets(_ exercise: Exercise) -> Int {
        if let item = planned[exercise.id], item.at >= startOfToday, item.at > (payload.defaultSetsAt ?? .distantPast) { return item.count }
        return payload.defaultSets
    }
    func changePlannedSets(_ delta: Int, for exercise: Exercise) {
        let count = min(10, max(max(1, sets(for: exercise).count), plannedSets(exercise) + delta))
        guard count != plannedSets(exercise) else { return }
        let item = WatchPlanned(count: count, at: .now)
        planned[exercise.id] = item
        savePlanned()
        scheduleSync()
    }
    var defaultSetCount: Int { payload.defaultSets }
    /// 삭제 버튼 동작: 계획 세트 수가 기본값(그리고 완료한 세트 수)보다 크면 먼저 계획 세트를 하나씩 줄이고,
    /// 더 줄일 수 없으면 가장 최근에 기록한 세트부터 지운다. 예) 1/7 → 1/6 → … → 1/3 → 0/3, 3/3 → 2/3 → 1/3.
    func removeSet(for exercise: Exercise) {
        guard restRemaining == nil else { return }
        let floor = max(payload.defaultSets, sets(for: exercise).count)
        if plannedSets(exercise) > floor { changePlannedSets(-1, for: exercise); WKInterfaceDevice.current().play(.click) }
        else { undoLastSet(for: exercise) }
    }
    /// 가장 최근에 기록한 세트를 지운다. 누를 때마다 그 다음으로 최근 세트가 지워진다(아이폰에도 전달).
    func undoLastSet(for exercise: Exercise) {
        guard restRemaining == nil, let last = sets(for: exercise).last else { return }
        deleted.insert(last.id)
        pending.removeAll { $0.set.id == last.id }
        if let data = try? JSONEncoder().encode(pending) { UserDefaults.standard.set(data, forKey: Self.pendingKey) }
        let message = WatchDeleteMessage(exerciseID: exercise.id, dayKey: dayKey, setID: last.id)
        deleteMessages.append(message)
        send(WatchKey.delete, message)
        syncState()
        WKInterfaceDevice.current().play(.click)
    }
    /// 아직 아이폰이 확인하지 않은 변경을 전체 상태로 다시 보낸다. 여러 번 보내도 안전하다.
    func syncState() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let today = dayKey
        let state = WatchState(
            sets: pending,
            deletes: deleteMessages.filter { $0.dayKey == today },
            planned: planned.filter { $0.value.at >= startOfToday }.map { WatchPlannedMessage(exerciseID: $0.key, dayKey: today, planned: $0.value) })
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? WCSession.default.updateApplicationContext([WatchKey.state: data])
        if WCSession.default.isReachable { WCSession.default.sendMessage([WatchKey.state: data], replyHandler: nil, errorHandler: nil) }
    }
    /// 크라운을 돌리는 동안 값이 계속 바뀌므로 잠시 모아서 한 번만 보낸다.
    private var syncTask: Task<Void, Never>?
    private func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.syncState()
        }
    }
    private func send<T: Encodable>(_ key: String, _ message: T) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, let data = try? JSONEncoder().encode(message) else { return }
        WCSession.default.transferUserInfo([key: data])
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
        send(WatchKey.set, message)
        syncState()
        WKInterfaceDevice.current().play(.success)
        // 계획한 마지막 세트만 휴식 없이 끝낸다. 추가로 기록하는 세트(계획 초과)는 다음 세트가 이어지므로 휴식한다.
        if sets(for: exercise).count != plannedSets(exercise) { startRest(seconds: payload.restSeconds) }
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
        guard !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        let body = text("휴식이 끝났습니다. 다음 세트를 시작하세요.", "Rest is over. Start your next set.")
        let id = Self.restID
        let center = UNUserNotificationCenter.current()
        // 권한이 승인된 경우에만 예약한다(미승인 상태에서 예약을 시도하지 않는다).
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "HOMETS"
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: id, content: content,
                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false))
            center.add(request)
        }
    }

    // MARK: WatchConnectivity

    private func apply(_ data: Data) {
        guard let received = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        payload = received
        UserDefaults.standard.set(data, forKey: Self.payloadKey)
        let known = Set(received.today.values.flatMap { $0 }.map(\.id))
        let acked = Set(received.acked ?? [])
        // 아이폰이 확인한 세트만 지운다. 확인되지 않은 지난 기록은 다음 연결 때 다시 보내되, 3일이 지나면 버린다.
        let cutoff = Self.dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now)
        pending.removeAll { known.contains($0.set.id) || acked.contains($0.set.id) || $0.dayKey < cutoff }
        deleted = deleted.filter { known.contains($0) }
        deleteMessages.removeAll { !known.contains($0.setID) || $0.dayKey != dayKey }
        for (id, item) in received.overrides ?? [:] where item.at >= startOfToday && item.at > (planned[id]?.at ?? .distantPast) { planned[id] = item }
        savePlanned()
        if let encoded = try? JSONEncoder().encode(pending) { UserDefaults.standard.set(encoded, forKey: Self.pendingKey) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext[WatchKey.payload] as? Data
        Task { @MainActor in
            if let data { self.apply(data) }
            self.syncState()
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.syncState() }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchKey.payload] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
}
