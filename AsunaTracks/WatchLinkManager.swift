import Foundation
import Combine
#if os(iOS)
import WatchConnectivity

@MainActor
final class WatchLinkManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchLinkManager()
    @Published private(set) var isReachable = false

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func linkExternalDevice() {
        activate()
        guard let token = KeychainVault.readToken() else { return }
        let payload: [String: Any] = [
            "kind": "account",
            "token": token,
            "username": UserDefaults.standard.string(forKey: "authUsername") ?? "",
            "avatarURL": UserDefaults.standard.string(forKey: "authAvatarURL") ?? ""
        ]
        WCSession.default.transferUserInfo(payload)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { isReachable = session.isReachable }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in isReachable = session.isReachable } }
}
#endif
