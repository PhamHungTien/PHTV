import Foundation

final class PHTVInputSessionStore {
    private var sessions: [ObjectIdentifier: PHTVInputSession] = [:]

    func session(for sender: Any?) -> PHTVInputSession {
        guard let object = sender as AnyObject? else {
            return PHTVInputSession()
        }

        let key = ObjectIdentifier(object)
        if let session = sessions[key] {
            return session
        }

        let session = PHTVInputSession()
        sessions[key] = session
        return session
    }
}
