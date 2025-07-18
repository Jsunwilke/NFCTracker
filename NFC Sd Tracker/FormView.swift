import SwiftUI

struct FormView: View {
    let cardNumber: String
    @Binding var selectedSchool: String
    @Binding var selectedStatus: String
    let localStatuses: [String]
    let lastRecord: FirestoreRecord?
    
    var onSubmit: (String, String, String, String, @escaping (Bool) -> Void) -> Void
    var onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var uploadedFromJasonsHouse: Bool = false
    @State private var uploadedFromAndysHouse: Bool = false
    @State private var localPhotographer: String = ""
    
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // For photographers & schools
    @State private var photographerNames: [String] = []
    @State private var dropdownRecords: [DropdownRecord] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card Information")) {
                    Text("Card Number: \(cardNumber)")
                }
                
                Section(header: Text("Additional Information")) {
                    // Photographer Picker (data from users)
                    Picker("Photographer", selection: $localPhotographer) {
                        ForEach(photographerNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    
                    // School Picker (data from dropdownData)
                    Picker("School", selection: $selectedSchool) {
                        ForEach(dropdownRecords.sorted { $0.value < $1.value }) { record in
                            Text(record.value).tag(record.value)
                        }
                    }
                    
                    // Status Picker
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(localStatuses, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    // If "Cleared" is picked, default the school to "Iconik"
                    .onChange(of: selectedStatus) { newVal in
                        if newVal.lowercased() == "cleared" {
                            selectedSchool = "Iconik"
                        }
                    }
                    
                    // Conditionally show toggles if status is "uploaded"
                    if selectedStatus.lowercased() == "uploaded",
                       sessionManager.user?.organizationID.lowercased() == "iconikstudio" {
                        Toggle("Uploaded from Jason's house", isOn: $uploadedFromJasonsHouse)
                            .onChange(of: uploadedFromJasonsHouse) { newValue in
                                if newValue { uploadedFromAndysHouse = false }
                            }
                        
                        Toggle("Uploaded from Andy's house", isOn: $uploadedFromAndysHouse)
                            .onChange(of: uploadedFromAndysHouse) { newValue in
                                if newValue { uploadedFromJasonsHouse = false }
                            }
                    }
                }
            }
            .navigationTitle("Enter Info")
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                    dismiss()
                },
                trailing: Button("Submit") {
                    guard !isSubmitting else { return }
                    isSubmitting = true
                    let jasonValue = uploadedFromJasonsHouse ? "Yes" : ""
                    let andyValue = uploadedFromAndysHouse ? "Yes" : ""
                    
                    onSubmit(cardNumber, localPhotographer, jasonValue, andyValue) { success in
                        if success {
                            alertMessage = "Scan saved"
                            showAlert = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showAlert = false
                                dismiss()
                            }
                        } else {
                            if alertMessage.isEmpty {
                                alertMessage = "Submission failed. Please try again."
                            }
                            showAlert = true
                            isSubmitting = false
                        }
                    }
                }
            )
            .onAppear {
                // Set default photographer from session
                localPhotographer = sessionManager.user?.firstName ?? ""
                updateDefaults()
                
                // Load photographers from cached data and listen for live updates
                if let data = UserDefaults.standard.data(forKey: "photographerNames"),
                   let cachedNames = try? JSONDecoder().decode([String].self, from: data) {
                    self.photographerNames = cachedNames
                }
                if let orgID = sessionManager.user?.organizationID {
                    FirestoreManager.shared.listenForPhotographers(inOrgID: orgID) { names in
                        DispatchQueue.main.async {
                            self.photographerNames = names
                        }
                    }
                }
                
                // Load schools from cached data and listen for live updates
                if let data = UserDefaults.standard.data(forKey: "dropdownRecords"),
                   let cachedDropdowns = try? JSONDecoder().decode([DropdownRecord].self, from: data) {
                    self.dropdownRecords = cachedDropdowns
                }
                if let orgID = sessionManager.user?.organizationID {
                    FirestoreManager.shared.listenForSchoolsData(forOrgID: orgID) { records in
                        DispatchQueue.main.async {
                            self.dropdownRecords = records
                            // Ensure a default school is selected if none exists.
                            if selectedSchool.isEmpty {
                                if let firstSchool = dropdownRecords.sorted(by: { $0.value < $1.value }).first?.value {
                                    selectedSchool = firstSchool
                                }
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                if alertMessage == "Scan saved" {
                    return Alert(title: Text(""), message: Text(alertMessage))
                } else {
                    return Alert(title: Text(""), message: Text(alertMessage), dismissButton: .default(Text("OK"), action: {
                        isSubmitting = false
                    }))
                }
            }
        }
    }
    
    private func updateDefaults() {
        if let last = lastRecord {
            // If the last record was "cleared", default the school to "Iconik"
            if last.status.lowercased() == "cleared" {
                selectedSchool = "Iconik"
            } else {
                selectedSchool = last.school
            }
            
            let lastStatus = last.status.lowercased()
            if lastStatus == "camera bag" {
                selectedStatus = "Camera"
                return
            }
            if lastStatus == "personal" {
                selectedStatus = "Cleared"
                return
            }
            
            let defaultStatuses = localStatuses.filter {
                let s = $0.lowercased()
                return s != "camera bag" && s != "personal"
            }
            if let index = defaultStatuses.firstIndex(where: { $0.lowercased() == lastStatus }) {
                let nextIndex = (index + 1) % defaultStatuses.count
                selectedStatus = defaultStatuses[nextIndex]
            } else {
                selectedStatus = defaultStatuses.first ?? ""
            }
        } else {
            // If no last record exists, and no school has been selected, set the default to the first available school.
            if selectedSchool.isEmpty {
                if let firstSchool = dropdownRecords.sorted(by: { $0.value < $1.value }).first?.value {
                    selectedSchool = firstSchool
                }
            }
        }
    }
}

