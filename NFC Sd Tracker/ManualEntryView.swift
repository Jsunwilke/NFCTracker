import SwiftUI

// Sub-view for entry type selection
struct EntryTypeSection: View {
    @Binding var isJobBoxMode: Bool
    @Binding var cardNumber: String
    @Binding var selectedStatus: String
    @Binding var lastRecord: FirestoreRecord?
    @Binding var lastJobBoxRecord: JobBoxRecord?
    
    var body: some View {
        Section {
            Picker("Entry Type", selection: $isJobBoxMode) {
                Text("SD Card").tag(false)
                Text("Job Box").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: isJobBoxMode) { newValue in
                // Reset form when switching modes
                cardNumber = ""
                selectedStatus = newValue ? "Packed" : ""
                lastRecord = nil
                lastJobBoxRecord = nil
            }
        }
    }
}

// Sub-view for card/box number input
struct NumberInputSection: View {
    @Binding var cardNumber: String
    @Binding var selectedSchool: String
    @Binding var selectedStatus: String
    @Binding var localPhotographer: String
    let isJobBoxMode: Bool
    let photographerNames: [String]
    let onNumberComplete: (String) -> Void
    
    var body: some View {
        Section(header: Text(isJobBoxMode ? "Job Box Information" : "Card Information")) {
            TextField(isJobBoxMode ? "Enter 4-digit Box Number (3001+)" : "Enter 4-digit Card Number", text: $cardNumber)
                .keyboardType(.numberPad)
                .onChange(of: cardNumber) { newValue in
                    if newValue.count == 4, Int(newValue) != nil {
                        onNumberComplete(newValue)
                    } else {
                        selectedSchool = ""
                        selectedStatus = isJobBoxMode ? "" : ""
                    }
                }
            
            // Include photographer for job boxes
            if isJobBoxMode {
                Picker("Photographer", selection: $localPhotographer) {
                    ForEach(photographerNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }
        }
    }
}

// Sub-view for photographer selection
struct PhotographerSection: View {
    @Binding var localPhotographer: String
    let photographerNames: [String]
    
    var body: some View {
        Section(header: Text("Photographer")) {
            Picker("Photographer", selection: $localPhotographer) {
                ForEach(photographerNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        }
    }
}

// Sub-view for additional information section
struct AdditionalInfoSection: View {
    @Binding var selectedSchool: String
    @Binding var selectedStatus: String
    @Binding var uploadedFromJasonsHouse: Bool
    @Binding var uploadedFromAndysHouse: Bool
    let selectedSession: Session?
    
    let isJobBoxMode: Bool
    let dropdownRecords: [DropdownRecord]
    let localStatuses: [String]
    let jobBoxStatuses: [String]
    let sessionManager: SessionManager
    
    var body: some View {
        Section(header: Text("Additional Information")) {
            // School
            Picker("School", selection: $selectedSchool) {
                ForEach(dropdownRecords.sorted { $0.value < $1.value }) { record in
                    Text(record.value).tag(record.value)
                }
            }
            .disabled(isJobBoxMode && selectedSession != nil) // Disable if session selected for job box
            
            // Status
            StatusPicker(
                selectedStatus: $selectedStatus,
                selectedSchool: $selectedSchool,
                isJobBoxMode: isJobBoxMode,
                localStatuses: localStatuses,
                jobBoxStatuses: jobBoxStatuses,
                sessionManager: sessionManager
            )
            
            // Conditional toggles for SD Card
            if !isJobBoxMode && selectedStatus.lowercased() == "uploaded",
               sessionManager.user?.organizationID.lowercased() == "iconikstudio" {
                UploadToggles(
                    uploadedFromJasonsHouse: $uploadedFromJasonsHouse,
                    uploadedFromAndysHouse: $uploadedFromAndysHouse
                )
            }
        }
    }
}

// Sub-view for status picker
struct StatusPicker: View {
    @Binding var selectedStatus: String
    @Binding var selectedSchool: String
    let isJobBoxMode: Bool
    let localStatuses: [String]
    let jobBoxStatuses: [String]
    let sessionManager: SessionManager
    
    var body: some View {
        Picker("Status", selection: $selectedStatus) {
            if isJobBoxMode {
                ForEach(jobBoxStatuses, id: \.self) { status in
                    Text(status).tag(status)
                }
            } else {
                ForEach(localStatuses, id: \.self) { status in
                    Text(status).tag(status)
                }
            }
        }
        .onChange(of: selectedStatus) { newVal in
            if !isJobBoxMode && newVal.lowercased() == "cleared" {
                selectedSchool = "Iconik"
            } else if isJobBoxMode && newVal.lowercased() == "turned in" {
                selectedSchool = "Iconik"
            }
            
            // If changing to Packed status, preload the session data
            if isJobBoxMode && newVal.lowercased() == "packed" {
                if let orgID = sessionManager.user?.organizationID {
                    SessionsManager.shared.loadSessions(organizationID: orgID, forceRefresh: true)
                }
            }
        }
    }
}

// Sub-view for upload toggles
struct UploadToggles: View {
    @Binding var uploadedFromJasonsHouse: Bool
    @Binding var uploadedFromAndysHouse: Bool
    
    var body: some View {
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

// Sub-view for session selection button
struct SessionSelectionButton: View {
    @Binding var selectedSession: Session?
    @Binding var showSessionSelection: Bool
    let sessionManager: SessionManager
    
    var body: some View {
        Button(action: {
            // Force refresh sessions before showing the selection view
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
}

struct ManualEntryView: View {
    @State private var cardNumber: String = ""
    @State private var selectedSchool: String = ""
    @State private var selectedStatus: String = ""
    @State private var isJobBoxMode: Bool = false // Toggle between SD Card and Job Box
    
    let localStatuses: [String] = ["Job Box", "Camera", "Envelope", "Uploaded", "Cleared", "Camera Bag", "Personal"]
    let jobBoxStatuses = ["Packed", "Picked Up", "Left Job", "Turned In"]
    
    @State private var dropdownRecords: [DropdownRecord] = []
    @State private var photographerNames: [String] = []
    
    @State private var localPhotographer: String = ""
    @State private var uploadedFromJasonsHouse: Bool = false
    @State private var uploadedFromAndysHouse: Bool = false
    
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var lastRecord: FirestoreRecord? = nil
    @State private var lastJobBoxRecord: JobBoxRecord? = nil
    
    // For shift selection
    @State private var selectedSession: Session? = nil
    @State private var showSessionSelection = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        NavigationView {
            Form {
                // Entry type selection
                EntryTypeSection(
                    isJobBoxMode: $isJobBoxMode,
                    cardNumber: $cardNumber,
                    selectedStatus: $selectedStatus,
                    lastRecord: $lastRecord,
                    lastJobBoxRecord: $lastJobBoxRecord
                )
                
                // Number input section (includes photographer for job boxes)
                NumberInputSection(
                    cardNumber: $cardNumber,
                    selectedSchool: $selectedSchool,
                    selectedStatus: $selectedStatus,
                    localPhotographer: $localPhotographer,
                    isJobBoxMode: isJobBoxMode,
                    photographerNames: photographerNames,
                    onNumberComplete: { newValue in
                        if isJobBoxMode {
                            fetchLastJobBoxRecord(for: newValue)
                        } else {
                            fetchLastRecord(for: newValue)
                        }
                    }
                )
                
                // Photographer section (only for SD cards)
                if !isJobBoxMode {
                    PhotographerSection(
                        localPhotographer: $localPhotographer,
                        photographerNames: photographerNames
                    )
                }
                
                if cardNumber.count == 4, Int(cardNumber) != nil {
                    // Session selection for Job Box - prominently displayed
                    if isJobBoxMode {
                        Section(header: Text("Session Assignment")) {
                            SessionSelectionButton(
                                selectedSession: $selectedSession,
                                showSessionSelection: $showSessionSelection,
                                sessionManager: sessionManager
                            )
                        }
                    }
                    // Additional information section
                    AdditionalInfoSection(
                        selectedSchool: $selectedSchool,
                        selectedStatus: $selectedStatus,
                        uploadedFromJasonsHouse: $uploadedFromJasonsHouse,
                        uploadedFromAndysHouse: $uploadedFromAndysHouse,
                        selectedSession: selectedSession,
                        isJobBoxMode: isJobBoxMode,
                        dropdownRecords: dropdownRecords,
                        localStatuses: localStatuses,
                        jobBoxStatuses: jobBoxStatuses,
                        sessionManager: sessionManager
                    )
                } else {
                    Section {
                        Text("Enter a valid 4-digit \(isJobBoxMode ? "box" : "card") number to load additional information.")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle(isJobBoxMode ? "Manual Job Box Entry" : "Manual SD Card Entry")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Submit") {
                    guard !isSubmitting else { return }
                    
                    guard cardNumber.count == 4, Int(cardNumber) != nil else {
                        alertMessage = "Please enter a valid 4-digit \(isJobBoxMode ? "box" : "card") number."
                        showAlert = true
                        return
                    }
                    
                    // Validate for session selection for new job boxes
                    if isJobBoxMode && selectedSession == nil && lastJobBoxRecord == nil {
                        alertMessage = "Please select a session for this job box"
                        showAlert = true
                        return
                    }
                    
                    isSubmitting = true
                    
                    if isJobBoxMode {
                        // Submit job box
                        let schoolId = selectedSession?.schoolId ?? dropdownRecords.first { $0.value == selectedSchool }?.id
                        submitJobBoxData(boxNumber: cardNumber,
                                         schoolId: schoolId,
                                         shiftUid: selectedSession?.id)
                    } else {
                        // Submit SD card
                        let jasonValue = uploadedFromJasonsHouse ? "Yes" : ""
                        let andyValue = uploadedFromAndysHouse ? "Yes" : ""
                        
                        submitSDCardData(
                            cardNumber: cardNumber,
                            jasonValue: jasonValue,
                            andyValue: andyValue
                        )
                    }
                }
                .disabled(isSubmitting)
            )
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK"), action: {
                          if alertMessage == "Scan saved" {
                              dismiss()
                          } else {
                              isSubmitting = false
                          }
                      }))
            }
            .sheet(isPresented: $showSessionSelection) {
                AvailableSessionSelectionView(
                    onSelectSession: { session in
                        selectedSession = session
                        // Auto-populate school and status when session is selected
                        selectedSchool = session.schoolName
                        // Find and set the school ID
                        if let schoolRecord = dropdownRecords.first(where: { $0.value == session.schoolName }) {
                            // Note: We don't have a selectedSchoolId binding here, but it will be set
                            // when submitting through the school name lookup
                        }
                        selectedStatus = "Packed"
                        showSessionSelection = false
                    },
                    onCancel: {
                        showSessionSelection = false
                    }
                )
            }
            .onAppear {
                localPhotographer = sessionManager.user?.firstName ?? ""
                
                // Photographers from `users` (cached + live)
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
                
                // Schools from `dropdownData` (cached + live)
                if let data = UserDefaults.standard.data(forKey: "dropdownRecords"),
                   let cachedDropdowns = try? JSONDecoder().decode([DropdownRecord].self, from: data) {
                    self.dropdownRecords = cachedDropdowns
                }
                if let orgID = sessionManager.user?.organizationID {
                    FirestoreManager.shared.listenForSchoolsData(forOrgID: orgID) { records in
                        DispatchQueue.main.async {
                            self.dropdownRecords = records
                        }
                    }
                }
                
                // If we're starting in JobBox mode, preload shifts
                if isJobBoxMode && selectedStatus.lowercased() == "packed" {
                    if let orgID = sessionManager.user?.organizationID {
                        SessionsManager.shared.loadSessions(organizationID: orgID)
                    }
                }
            }
            .onChange(of: isJobBoxMode) { newValue in
                // If switching to job box mode, preload shifts
                if newValue && selectedStatus.lowercased() == "packed" {
                    if let orgID = sessionManager.user?.organizationID {
                        SessionsManager.shared.loadSessions(organizationID: orgID, forceRefresh: true)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func fetchLastRecord(for cardNumber: String) {
        guard let orgID = sessionManager.user?.organizationID else { return }
        FirestoreManager.shared.fetchRecords(field: "cardNumber", value: cardNumber, organizationID: orgID) { result in
            switch result {
            case .success(let records):
                let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                self.lastRecord = sortedRecords.first
                updateSDCardDefaults()
            case .failure(let error):
                print("Error fetching record for card \(cardNumber): \(error.localizedDescription)")
            }
        }
    }
    
    func fetchLastJobBoxRecord(for boxNumber: String) {
        guard let orgID = sessionManager.user?.organizationID else { return }
        FirestoreManager.shared.fetchJobBoxRecords(field: "boxNumber", value: boxNumber, organizationID: orgID) { result in
            switch result {
            case .success(let records):
                let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                self.lastJobBoxRecord = sortedRecords.first
                updateJobBoxDefaults()
            case .failure(let error):
                print("Error fetching job box record for box \(boxNumber): \(error.localizedDescription)")
            }
        }
    }
    
    private func updateSDCardDefaults() {
        if let last = lastRecord {
            // If last record was "cleared," default to "Iconik"
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
            selectedSchool = ""
            selectedStatus = ""
        }
    }
    
    private func updateJobBoxDefaults() {
        if let last = lastJobBoxRecord {
            // Set school from last record
            selectedSchool = last.school
            
            // If last status was "Turned In", default school to "Iconik"
            if last.status.lowercased() == "turned in" {
                selectedSchool = "Iconik"
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
            
            // If there's a shiftUid and we're not in Packed status, try to load the session information
            if selectedStatus.lowercased() != "packed", let sessionId = last.shiftUid {
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
            
            // If we're in packed status, force refresh the sessions
            if selectedStatus.lowercased() == "packed" {
                if let orgID = sessionManager.user?.organizationID {
                    SessionsManager.shared.loadSessions(organizationID: orgID, forceRefresh: true)
                }
            }
        } else {
            // If no last record exists, ensure a sensible default
            if selectedSchool.isEmpty {
                if let firstSchool = dropdownRecords.sorted(by: { $0.value < $1.value }).first?.value {
                    selectedSchool = firstSchool
                }
            }
            selectedStatus = "Packed" // Default for new job box
            
            // For a new job box, force refresh sessions
            if let orgID = sessionManager.user?.organizationID {
                SessionsManager.shared.loadSessions(organizationID: orgID, forceRefresh: true)
            }
        }
    }
    
    func submitSDCardData(
        cardNumber: String,
        jasonValue: String,
        andyValue: String,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        let timestamp = Date()
        guard let orgID = sessionManager.user?.organizationID else {
            isSubmitting = false
            alertMessage = "User organization not found."
            showAlert = true
            completion(false)
            return
        }
        
        FirestoreManager.shared.saveRecord(
            timestamp: timestamp,
            photographer: localPhotographer,
            cardNumber: cardNumber,
            school: selectedSchool,
            status: selectedStatus,
            uploadedFromJasonsHouse: jasonValue,
            uploadedFromAndysHouse: andyValue,
            organizationID: orgID,
            userId: sessionManager.user?.id ?? ""
        ) { result in
            switch result {
            case .success:
                alertMessage = "SD Card record saved"
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
                completion(true)
                
            case .failure(let error):
                alertMessage = "Failed to save record: \(error.localizedDescription)"
                showAlert = true
                isSubmitting = false
                completion(false)
            }
        }
    }
    
    func submitJobBoxData(
        boxNumber: String,
        schoolId: String? = nil,
        shiftUid: String? = nil,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        let timestamp = Date()
        guard let orgID = sessionManager.user?.organizationID else {
            isSubmitting = false
            alertMessage = "User organization not found."
            showAlert = true
            completion(false)
            return
        }
        
        // If this is not a "Packed" status and we have a lastJobBoxRecord with a shiftUid,
        // use that shiftUid to maintain the connection to the shift
        let effectiveShiftUid = shiftUid ?? (selectedStatus.lowercased() != "packed" ? lastJobBoxRecord?.shiftUid : nil)
        
        FirestoreManager.shared.saveJobBoxRecord(
            timestamp: timestamp,
            photographer: localPhotographer,
            boxNumber: boxNumber,
            school: selectedSchool,
            schoolId: schoolId,
            status: selectedStatus,
            organizationID: orgID,
            userId: sessionManager.user?.id ?? "",
            shiftUid: effectiveShiftUid // Pass the effective shiftUid
        ) { result in
            switch result {
            case .success:
                alertMessage = "Job Box record saved"
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
                completion(true)
                
            case .failure(let error):
                alertMessage = "Failed to save job box record: \(error.localizedDescription)"
                showAlert = true
                isSubmitting = false
                completion(false)
            }
        }
    }
}
