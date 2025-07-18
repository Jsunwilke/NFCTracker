import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MapKit

struct SignUpView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.presentationMode) var presentationMode
    
    // User input fields
    @State private var organizationID: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var homeAddress: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var errorMessage: String = ""
    @State private var isSigningUp: Bool = false
    
    // For address suggestions
    @StateObject private var addressCompleter = AddressCompleter()
    
    // Geocoder for validating the home address
    private let geocoder = CLGeocoder()
    
    // Validation rules
    private let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
    
    // Form validity check
    private var isFormValid: Bool {
        return !organizationID.isEmpty &&
               !firstName.isEmpty &&
               !lastName.isEmpty &&
               !homeAddress.isEmpty &&
               email.range(of: emailRegex, options: .regularExpression) != nil &&
               password.count >= 6 &&
               password == confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Sign Up")
                        .font(.largeTitle)
                        .padding(.top, 40)
                    
                    ValidationTextField(
                        text: $organizationID,
                        title: "Organization ID",
                        placeholder: "Enter your organization ID",
                        keyboardType: .default,
                        autocapitalization: .none,
                        validationRule: { !$0.isEmpty },
                        errorMessage: "Organization ID is required"
                    )
                    
                    ValidationTextField(
                        text: $firstName,
                        title: "First Name",
                        placeholder: "Enter your first name",
                        validationRule: { !$0.isEmpty },
                        errorMessage: "First name is required"
                    )
                    
                    ValidationTextField(
                        text: $lastName,
                        title: "Last Name",
                        placeholder: "Enter your last name",
                        validationRule: { !$0.isEmpty },
                        errorMessage: "Last name is required"
                    )
                    
                    // Home Address Field with suggestions
                    ValidationTextField(
                        text: $homeAddress,
                        title: "Home Address",
                        placeholder: "Enter your home address",
                        validationRule: { !$0.isEmpty },
                        errorMessage: "Home address is required"
                    )
                    .onChange(of: homeAddress) { newValue in
                        addressCompleter.queryFragment = newValue
                    }
                    
                    if !addressCompleter.suggestions.isEmpty {
                        VStack(alignment: .leading) {
                            ForEach(addressCompleter.suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    homeAddress = suggestion.title + ", " + suggestion.subtitle
                                    addressCompleter.suggestions = []
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(suggestion.title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                    
                    ValidationTextField(
                        text: $email,
                        title: "Email",
                        placeholder: "Enter your email",
                        keyboardType: .emailAddress,
                        contentType: .emailAddress,
                        autocapitalization: .none,
                        validationRule: { $0.range(of: emailRegex, options: .regularExpression) != nil },
                        errorMessage: "Please enter a valid email address"
                    )
                    
                    ValidationTextField(
                        text: $password,
                        title: "Password",
                        placeholder: "Create a password",
                        contentType: .newPassword,
                        isSecure: true,
                        autocapitalization: .none,
                        validationRule: { $0.count >= 6 },
                        errorMessage: "Password must be at least 6 characters"
                    )
                    
                    ValidationTextField(
                        text: $confirmPassword,
                        title: "Confirm Password",
                        placeholder: "Confirm your password",
                        contentType: .newPassword,
                        isSecure: true,
                        autocapitalization: .none,
                        validationRule: { $0 == password },
                        errorMessage: "Passwords don't match"
                    )
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: validateAndSignUp) {
                        if isSigningUp {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.5))
                                .cornerRadius(10)
                        } else {
                            Text("Sign Up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isFormValid ? Color.green : Color.gray)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(!isFormValid || isSigningUp)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func validateAndSignUp() {
        errorMessage = ""
        
        // Validate the home address using geocoder
        isSigningUp = true
        geocoder.geocodeAddressString(homeAddress) { placemarks, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isSigningUp = false
                    self.errorMessage = "Address not recognized: \(error.localizedDescription)"
                }
                return
            }
            if let _ = placemarks?.first {
                // Proceed with sign-up after address is validated
                signUpUser()
            } else {
                DispatchQueue.main.async {
                    self.isSigningUp = false
                    self.errorMessage = "Address not recognized. Please check it."
                }
            }
        }
    }
    
    private func signUpUser() {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            DispatchQueue.main.async {
                self.isSigningUp = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let user = authResult?.user else { return }
            let db = Firestore.firestore()
            
            let userData: [String: Any] = [
                "organizationID": organizationID,
                "firstName": firstName,
                "lastName": lastName,
                "homeAddress": homeAddress,
                "email": email
            ]
            
            db.collection("users").document(user.uid).setData(userData) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    // Update the session manager with the new user
                    let newUser = AppUser(id: user.uid,
                                          organizationID: organizationID,
                                          firstName: firstName,
                                          lastName: lastName,
                                          email: email)
                    DispatchQueue.main.async {
                        self.sessionManager.user = newUser
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
