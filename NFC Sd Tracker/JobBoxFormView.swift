import SwiftUI

struct JobBoxFormView: View {
    let boxNumber: String
    @Binding var selectedSchool: String
    @Binding var selectedStatus: String
    let lastRecord: JobBoxRecord?
    
    var onSubmit: (String, String?, String?, @escaping (Bool) -> Void) -> Void // photographer, schoolId, sessionId
    var onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var localPhotographer: String = ""
    @State private var selectedSession: Session? = nil
    @State private var selectedSchoolId: String? = nil
    
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSessionSelection = false
    
    // For photographers & schools
    @State private var photographerNames: [String] = []
    @State private var dropdownRecords: [DropdownRecord] = []
    
    // Job box specific statuses
    let jobBoxStatuses = ["Packed", "Picked Up", "Left Job", "Turned In"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Job Box Information")) {
                    Text("Box Number: \(boxNumber)")
                    
                    // Photographer Picker (data from users) - Now at the top
                    Picker("Photographer", selection: $localPhotographer) {
                        ForEach(photographerNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
                
                // Session selection prominently displayed
                Section(header: Text("Session Assignment")) {
                    Button(action: {
                        // Force a refresh of sessions before showing the selection view
                        if let orgID = sessionManager.user?.organizationID {
                            SessionsManager.shared.loadSessions(organizationID: orgID, forceRefresh: true)
                        }
                        showSessionSelection = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select Session")
                                    .font(.headline)
                                
                                if selectedSession == nil {
                                    Text("Choose from available sessions in the next 2 weeks")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if let session = selectedSession {
                                VStack(alignment: .trailing) {
                                    Text(session.schoolName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Text(SessionsManager.shared.formatSessionDate(session))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(selectedSession == nil ? .blue : .primary)
                }
                
                Section(header: Text("Additional Information")) {
                    // School Picker (data from dropdownData) - Auto-filled from session
                    Picker("School", selection: $selectedSchool) {
                        ForEach(dropdownRecords.sorted { $0.value < $1.value }) { record in
                            Text(record.value).tag(record.value)
                        }
                    }
                    .onChange(of: selectedSchool) { newSchool in
                        // Find and set the school ID when school name changes
                        selectedSchoolId = dropdownRecords.first { $0.value == newSchool }?.id
                    }
                    .disabled(selectedSession != nil) // Disable if session selected
                    
                    // Status Picker - Job Box specific
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(jobBoxStatuses, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    .onChange(of: selectedStatus) { newVal in
                        if newVal.lowercased() == "turned in" {
                            selectedSchool = "Iconik"
                            selectedSchoolId = dropdownRecords.first { $0.value == "Iconik" }?.id
                        }
                    }
                }
            }
            .navigationTitle("Job Box Info")
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                    dismiss()
                },
                trailing: Button("Submit") {
                    guard !isSubmitting else { return }
                    
                    // Validate to ensure a session is selected for new job boxes
                    if selectedSession == nil && lastRecord == nil {
                        alertMessage = "Please select a session for this job box"
                        showAlert = true
                        return
                    }
                    
                    isSubmitting = true
                    
                    // Use the selected session ID or maintain the existing one from lastRecord
                    let effectiveSessionId = selectedSession?.id ?? lastRecord?.shiftUid
                    
                    onSubmit(localPhotographer, selectedSchoolId, effectiveSessionId) { success in
                        if success {
                            alertMessage = "Job box scan saved"
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
                
                // Check if we need to pre-load sessions data
                if selectedStatus.lowercased() == "packed" {
                    if let orgID = sessionManager.user?.organizationID {
                        SessionsManager.shared.loadSessions(organizationID: orgID)
                    }
                }
                
                // If there's a lastRecord with a shiftUid and we're not in Packed status,
                // try to load the session information
                if selectedStatus.lowercased() != "packed",
                   let sessionId = lastRecord?.shiftUid {
                    // Make sure sessions are loaded
                    if SessionsManager.shared.sessions.isEmpty,
                       let orgID = sessionManager.user?.organizationID {
                        SessionsManager.shared.loadSessions(organizationID: orgID)
                    }
                    
                    // Find the session that matches the ID
                    if let matchingSession = SessionsManager.shared.session(withId: sessionId) {
                        selectedSession = matchingSession
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                if alertMessage == "Job box scan saved" {
                    return Alert(title: Text(""), message: Text(alertMessage))
                } else {
                    return Alert(title: Text(""), message: Text(alertMessage), dismissButton: .default(Text("OK"), action: {
                        isSubmitting = false
                    }))
                }
            }
            .sheet(isPresented: $showSessionSelection) {
                AvailableSessionSelectionView(
                    onSelectSession: { session in
                        selectedSession = session
                        // Auto-populate school and status when session is selected
                        selectedSchool = session.schoolName
                        selectedSchoolId = session.schoolId
                        selectedStatus = "Packed"
                        showSessionSelection = false
                    },
                    onCancel: {
                        showSessionSelection = false
                    }
                )
            }
        }
    }
    
    private func updateDefaults() {
        if let last = lastRecord {
            // Set school from last record
            selectedSchool = last.school
            selectedSchoolId = last.schoolId
            
            // If last status was "Turned In", default school to "Iconik"
            if last.status.lowercased() == "turned in" {
                selectedSchool = "Iconik"
                selectedSchoolId = dropdownRecords.first { $0.value == "Iconik" }?.id
            }
            
            // Calculate next status in the cycle
            let currentStatus = last.status.lowercased()
            if let index = jobBoxStatuses.firstIndex(where: { $0.lowercased() == currentStatus }) {
                let nextIndex = (index + 1) % jobBoxStatuses.count
                selectedStatus = jobBoxStatuses[nextIndex]
            } else {
                // Default to first status if current status not found
                selectedStatus = jobBoxStatuses.first ?? ""
            }
        } else {
            // For new job boxes, don't pre-select a school - let it be selected via session
            selectedSchool = ""
            selectedSchoolId = nil
            
            // Default status will be set to "Packed" when session is selected
            selectedStatus = ""
        }
    }
}

// Preview Provider
struct JobBoxFormView_Previews: PreviewProvider {
    static var previews: some View {
        JobBoxFormView(
            boxNumber: "3001",
            selectedSchool: .constant("Sample School"),
            selectedStatus: .constant("Packed"),
            lastRecord: nil,
            onSubmit: { _, _, _, completion in
                completion(true)
            },
            onCancel: {}
        ).environmentObject(SessionManager())
    }
}
