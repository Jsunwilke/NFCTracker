import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var email: String = ""
    @State private var password: String = ""
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Sign In")
                    .font(.largeTitle)
                    .padding(.top, 40)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: signIn) {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                
                
                Spacer()
            }
            .navigationTitle("Sign In")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func signIn() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }
        
        isSigningIn = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isSigningIn = false
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
            
            guard let user = result?.user else {
                alertMessage = "User not found."
                showAlert = true
                return
            }
            
            sessionManager.fetchUser(uid: user.uid) { fetchedUser in
                if let fetchedUser = fetchedUser {
                    sessionManager.user = fetchedUser
                } else {
                    alertMessage = "Failed to fetch user profile."
                    showAlert = true
                }
            }
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView().environmentObject(SessionManager())
    }
}

