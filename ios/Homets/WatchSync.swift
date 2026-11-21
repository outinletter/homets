import Foundation
import WatchConnectivity

/// 아이폰 쪽 WatchConnectivity: 설정·운동 목록을 워치로 보내고, 워치에서 기록한 세트를 받는다.
final class WatchSync: NSObject, WCSessionDelegate {
    @MainActor static let shared = WatchSync()
    @MainActor private weak var store: WorkoutStore?

    @MainActor func start(store: WorkoutStore) {
        self.store = store
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

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchKey.set] as? Data,
              let message = try? JSONDecoder().decode(WatchSetMessage.self, from: data) else { return }
        Task { @MainActor in self.store?.ingestWatch(message) }
    }
}
