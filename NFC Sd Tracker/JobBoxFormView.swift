import SwiftUI

struct JobBoxFormView: View {
    let boxNumber: String
    @Binding var selectedSchool: String
    @Binding var selectedStatus: String
    let lastRecord: JobBoxRecord?
    
    var onSubmit: (String, String?, @escaping (Bool) -> Void) -> Void // Updated to include shiftUid
    var onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var localPhotographer: String = ""
    @State private var selectedShift: Shift? = nil
    
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showShiftSelection = false
    
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
                    // If "Turned In" is picked, default the school to "Iconik"
                    .onChange(of: selectedStatus) { newVal in
                        if newVal.lowercased() == "turned in" {
                            selectedSchool = "Iconik"
                        }
                    }
                    
                    // Status Picker - Job Box specific
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(jobBoxStatuses, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    .onChange(of: selectedStatus) { newStatus in
                        // If changing to Packed status and no shift is selected, pre-load shifts
                        if newStatus.lowercased() == "packed" && selectedShift == nil {
                            // Force a refresh of shifts
                            ShiftManager.shared.loadShifts(forceRefresh: true)
                        }
                    }
                    
                    // Show shift selection if status is "Packed"
                    if selectedStatus.lowercased() == "packed" {
                        Button(action: {
                            // Force a refresh of shifts before showing the selection view
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
            }
            .navigationTitle("Job Box Info")
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                    dismiss()
                },
                trailing: Button("Submit") {
                    guard !isSubmitting else { return }
                    
                    // Validate to ensure a shift is selected if status is "Packed"
                    if selectedStatus.lowercased() == "packed" && selectedShift == nil {
                        alertMessage = "Please select a shift for this job"
                        showAlert = true
                        return
                    }
                    
                    isSubmitting = true
                    
                    // For non-"Packed" statuses, we need to use either the selectedShift or the shiftUid from lastRecord
                    let effectiveShiftId = selectedStatus.lowercased() == "packed"
                        ? selectedShift?.id
                        : (selectedShift?.id ?? lastRecord?.shiftUid)
                    
                    onSubmit(localPhotographer, effectiveShiftId) { success in
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
                
                // Check if we need to pre-load shifts data
                if selectedStatus.lowercased() == "packed" {
                    ShiftManager.shared.loadShifts()
                }
                
                // If there's a lastRecord with a shiftUid and we're not in Packed status,
                // try to load the shift information
                if selectedStatus.lowercased() != "packed",
                   let shiftUid = lastRecord?.shiftUid {
                    // Make sure shifts are loaded
                    if ShiftManager.shared.shifts.isEmpty {
                        ShiftManager.shared.loadShifts()
                    }
                    
                    // Find the shift that matches the UID
                    if let matchingShift = ShiftManager.shared.shifts.first(where: { $0.id == shiftUid }) {
                        selectedShift = matchingShift
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
        }
    }
    
    private func updateDefaults() {
        if let last = lastRecord {
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
        } else {
            // If no last record exists, and no school has been selected, set the default to the first available school.
            if selectedSchool.isEmpty {
                if let firstSchool = dropdownRecords.sorted(by: { $0.value < $1.value }).first?.value {
                    selectedSchool = firstSchool
                }
            }
            // Set default status to "Packed" for new job boxes
            if selectedStatus.isEmpty {
                selectedStatus = "Packed"
            }
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
            onSubmit: { _, _, completion in
                completion(true)
            },
            onCancel: {}
        ).environmentObject(SessionManager())
    }
}
