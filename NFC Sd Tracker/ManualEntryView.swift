import SwiftUI

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
    @State private var selectedShift: Shift? = nil
    @State private var showShiftSelection = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        NavigationView {
            Form {
                // Toggle between SD Card and Job Box mode
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
                
                Section(header: Text(isJobBoxMode ? "Box Information" : "Card Information")) {
                    TextField(isJobBoxMode ? "Enter 4-digit Box Number (3001+)" : "Enter 4-digit Card Number", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .onChange(of: cardNumber) { newValue in
                            if newValue.count == 4, Int(newValue) != nil {
                                if isJobBoxMode {
                                    fetchLastJobBoxRecord(for: newValue)
                                } else {
                                    fetchLastRecord(for: newValue)
                                }
                            } else {
                                selectedSchool = ""
                                selectedStatus = isJobBoxMode ? "Packed" : ""
                            }
                        }
                }
                
                Section(header: Text("Photographer")) {
                    Picker("Photographer", selection: $localPhotographer) {
                        ForEach(photographerNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
                
                if cardNumber.count == 4, Int(cardNumber) != nil {
                    Section(header: Text("Additional Information")) {
                        // School
                        Picker("School", selection: $selectedSchool) {
                            ForEach(dropdownRecords.sorted { $0.value < $1.value }) { record in
                                Text(record.value).tag(record.value)
                            }
                        }
                        
                        // Status - show different options based on mode
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
                        // Status-specific actions
                        .onChange(of: selectedStatus) { newVal in
                            if !isJobBoxMode && newVal.lowercased() == "cleared" {
                                selectedSchool = "Iconik"
                            } else if isJobBoxMode && newVal.lowercased() == "turned in" {
                                selectedSchool = "Iconik"
                            }
                            
                            // If changing to Packed status, preload the shift data
                            if isJobBoxMode && newVal.lowercased() == "packed" {
                                ShiftManager.shared.loadShifts(forceRefresh: true)
                            }
                        }
                        
                        // For SD Card: Show toggles if status is "uploaded"
                        if !isJobBoxMode && selectedStatus.lowercased() == "uploaded",
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
                        
                        // For Job Box: Show shift selection if status is "Packed"
                        if isJobBoxMode && selectedStatus.lowercased() == "packed" {
                            Button(action: {
                                // Force refresh shifts before showing the selection view
                                ShiftManager.shared.loadShifts(forceRefresh: true)
                                showShiftSelection = true
                            }) {
                                HStack {
                                    Text("Select Shift")
                                    
                                    Spacer()
                                    
                                    if let shift = selectedShift {
                                        VStack(alignment: .trailing) {
                                            Text(shift.schoolName)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Text(ShiftManager.shared.formatShiftDate(shift))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("None Selected")
                                            .foregroundColor(.gray)
                                            .font(.subheadline)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                            }
                        }
                    }
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
                    
                    // Validate for shift selection if Job Box in "Packed" status
                    if isJobBoxMode && selectedStatus.lowercased() == "packed" && selectedShift == nil {
                        alertMessage = "Please select a shift for this job"
                        showAlert = true
                        return
                    }
                    
                    isSubmitting = true
                    
                    if isJobBoxMode {
                        // Submit job box
                        submitJobBoxData(boxNumber: cardNumber,
                                         shiftUid: selectedShift?.id)
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
            .sheet(isPresented: $showShiftSelection) {
                ShiftSelectionView(
                    schoolName: selectedSchool,
                    onSelectShift: { shift in
                        selectedShift = shift
                        showShiftSelection = false
                    },
                    onCancel: {
                        showShiftSelection = false
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
                    ShiftManager.shared.loadShifts()
                }
            }
            .onChange(of: isJobBoxMode) { newValue in
                // If switching to job box mode, preload shifts
                if newValue && selectedStatus.lowercased() == "packed" {
                    ShiftManager.shared.loadShifts(forceRefresh: true)
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
            
            // If there's a shiftUid and we're not in Packed status, try to load the shift information
            if selectedStatus.lowercased() != "packed", let shiftUid = last.shiftUid {
                // Make sure shifts are loaded
                if ShiftManager.shared.shifts.isEmpty {
                    ShiftManager.shared.loadShifts()
                }
                
                // Find the shift that matches the UID
                if let matchingShift = ShiftManager.shared.shifts.first(where: { $0.id == shiftUid }) {
                    selectedShift = matchingShift
                }
            }
            
            // If we're in packed status, force refresh the shifts
            if selectedStatus.lowercased() == "packed" {
                ShiftManager.shared.loadShifts(forceRefresh: true)
            }
        } else {
            // If no last record exists, ensure a sensible default
            if selectedSchool.isEmpty {
                if let firstSchool = dropdownRecords.sorted(by: { $0.value < $1.value }).first?.value {
                    selectedSchool = firstSchool
                }
            }
            selectedStatus = "Packed" // Default for new job box
            
            // For a new job box, force refresh shifts
            ShiftManager.shared.loadShifts(forceRefresh: true)
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
