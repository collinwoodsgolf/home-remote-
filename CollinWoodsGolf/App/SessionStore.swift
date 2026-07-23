import Foundation
import Observation

/// App-wide session: who is signed in and the shared backend handle.
@Observable
final class SessionStore {
    enum Phase: Equatable {
        case loading
        case signedOut
        case signedIn
    }

    let backend: BackendService = makeBackendService()

    private(set) var phase: Phase = .loading
    private(set) var client: Client?

    var membership: MembershipTier { client?.membership ?? .nonMember }

    func restore() async {
        do {
            if let client = try await backend.restoreSession() {
                self.client = client
                phase = .signedIn
                return
            }
        } catch {
            // fall through to sign-in on any restore failure
        }
        phase = .signedOut
    }

    func didSignIn(_ client: Client) {
        self.client = client
        phase = .signedIn
    }

    func update(client: Client) {
        self.client = client
    }

    func signOut() async {
        await backend.signOut()
        client = nil
        phase = .signedOut
    }
}
