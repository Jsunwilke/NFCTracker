import SwiftUI
import Foundation
import FirebaseFirestore

struct AddSchoolView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var schoolName: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add a New School")) {
                    TextField("Enter school name", text: $schoolName)
                        .autocapitalization(.words)
                    Button("Add School") {
                        addSchool()
                    }
                }
            }
            .navigationTitle("Add School")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func addSchool() {
        let trimmedName = schoolName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            alertMessage = "Please enter a valid school name."
            showAlert = true
            return
        }
        guard let orgID = sessionManager.user?.organizationID, !orgID.isEmpty else {
            alertMessage = "Organization ID not found."
            showAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let newSchoolData: [String: Any] = [
            "value": trimmedName,
            "organizationID": orgID
        ]
        
        db.collection("schools").addDocument(data: newSchoolData) { error in
            if let error = error {
                alertMessage = "Error adding school: \(error.localizedDescription)"
            } else {
                alertMessage = "School added successfully!"
                schoolName = ""
            }
            showAlert = true
        }
    }
}

struct AddSchoolView_Previews: PreviewProvider {
    static var previews: some View {
        AddSchoolView().environmentObject(SessionManager())
    }
}

