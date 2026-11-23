import Foundation
import WatchConnectivity

/// 아이폰 쪽 WatchConnectivity: 설정·운동 목록을 워치로 보내고, 워치에서 기록한 세트를 받는다.
final class WatchSync: NSObject, WCSessionDelegate {
    @MainActor static let shared = WatchSync()
    @MainActor private weak var store: WorkoutStore?
    @MainActor private var lastEnglish = hometsIsEnglish
    @MainActor private var lastSort = UserDefaults.standard.string(forKey: "homets.sort") ?? "default"
    @MainActor private var observer: NSObjectProtocol?

    @MainActor func start(store: WorkoutStore) {
        self.store = store
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let sort = UserDefaults.standard.string(forKey: "homets.sort") ?? "default"
                    guard self.lastEnglish != hometsIsEnglish || self.lastSort != sort else { return }
                    self.lastEnglish = hometsIsEnglish; self.lastSort = sort
                    self.push()
                }
            }
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    @MainActor func push() {
        guard let store, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(store.watchPayload()) else { return }
        try? session.updateApplicationContext([WatchKey.payload: data])
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.push() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.push() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { receive(applicationContext) }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { receive(message) }
    private nonisolated func receive(_ info: [String: Any]) {
        guard let data = info[WatchKey.state] as? Data, let state = try? JSONDecoder().decode(WatchState.self, from: data) else { return }
        Task { @MainActor in
            for item in state.sets { self.store?.ingestWatch(item) }
            for item in state.deletes { self.store?.ingestWatchDelete(item) }
            for item in state.planned { self.store?.ingestWatchPlanned(item) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let decoder = JSONDecoder()
        if let data = userInfo[WatchKey.set] as? Data, let message = try? decoder.decode(WatchSetMessage.self, from: data) {
            Task { @MainActor in self.store?.ingestWatch(message) }
        } else if let data = userInfo[WatchKey.delete] as? Data, let message = try? decoder.decode(WatchDeleteMessage.self, from: data) {
            Task { @MainActor in self.store?.ingestWatchDelete(message) }
        } else if let data = userInfo[WatchKey.planned] as? Data, let message = try? decoder.decode(WatchPlannedMessage.self, from: data) {
            Task { @MainActor in self.store?.ingestWatchPlanned(message) }
        }
    }
}
