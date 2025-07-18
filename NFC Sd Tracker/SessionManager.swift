import Foundation
import FirebaseAuth
import FirebaseFirestore

struct AppUser: Identifiable {
    let id: String
    let organizationID: String
    let firstName: String
    let lastName: String
    let email: String
}

class SessionManager: ObservableObject {
    @Published var user: AppUser?
    private var db = Firestore.firestore()
    
    init() {
        // If there's a current user, fetch their profile
        if let currentUser = Auth.auth().currentUser {
            fetchUser(uid: currentUser.uid) { [weak self] appUser in
                self?.user = appUser
            }
        }
        
        // Listen for sign-in/sign-out changes
        Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            if let firebaseUser = firebaseUser {
                self.fetchUser(uid: firebaseUser.uid) { appUser in
                    self.user = appUser
                }
            } else {
                self.user = nil
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func fetchUser(uid: String, completion: @escaping (AppUser?) -> Void) {
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data(), error == nil {
                let orgID = data["organizationID"] as? String ?? ""
                let firstName = data["firstName"] as? String ?? ""
                let lastName = data["lastName"] as? String ?? ""
                let email = data["email"] as? String ?? ""
                
                let user = AppUser(id: uid,
                                   organizationID: orgID,
                                   firstName: firstName,
                                   lastName: lastName,
                                   email: email)
                
                DispatchQueue.main.async {
                    completion(user)
                }
            } else {
                print("Error fetching user: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

