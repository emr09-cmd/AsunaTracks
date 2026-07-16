import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchLinkManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var pairingCode = UUID().uuidString
    @Published var username = UserDefaults.standard.string(forKey: "watchUsername") ?? ""
    func activate() { guard WCSession.isSupported() else { return }; WCSession.default.delegate = self; WCSession.default.activate() }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) { Task { @MainActor in if let name = userInfo["username"] as? String { username = name; UserDefaults.standard.set(name, forKey: "watchUsername") } } }
}
