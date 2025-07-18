import SwiftUI

struct SearchView: View {
    @State private var searchField = "cardNumber"
    @State private var searchValue = ""
    @State private var searchResults: [FirestoreRecord] = []
    @State private var jobBoxSearchResults: [JobBoxRecord] = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isJobBoxMode = false
    
    // For schools (still from dropdownData if desired)
    @State private var dropdownRecords: [DropdownRecord] = []
    
    // For photographers (from `users`)
    @State private var photographerNames: [String] = []
    
    @State private var statusSearchPerformed = false
    @State private var recordToDelete: FirestoreRecord? = nil
    @State private var jobBoxRecordToDelete: JobBoxRecord? = nil
    @State private var showDeleteConfirmation = false
    
    // For custom confirmation dialog
    @State private var showConfirmationDialog = false
    @State private var confirmationConfig = AlertConfiguration(
        title: "",
        message: "",
        primaryButtonTitle: "",
        secondaryButtonTitle: nil,
        isDestructive: false,
        primaryAction: {},
        secondaryAction: nil
    )
    
    // Flag to track whether we've checked for a selected status from charts view
    @State private var hasCheckedForStatus = false
    
    // Use the shared state manager for cross-view communication
    @StateObject private var sharedState = SharedStateManager.shared
    
    // For network status indicator
    @ObservedObject private var offlineManager = OfflineDataManager.shared
    
    let localStatuses = ["Job Box", "Camera", "Envelope", "Uploaded", "Cleared", "Camera Bag", "Personal"]
    let jobBoxStatuses = ["Packed", "Picked Up", "Left Job", "Turned In"]
    
    let searchFields = [
        "cardNumber": "Card/Box #",
        "photographer": "Photographer",
        "school": "School",
        "status": "Status"
    ]
    
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        ZStack {
            Color(red: 43/255, green: 62/255, blue: 80/255)
                .ignoresSafeArea()
            
            VStack {
                // Network status indicator
                if !offlineManager.isOnline {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        Text("Offline Mode")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        if offlineManager.syncPending {
                            Text("• Sync Pending")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                        }
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Offline Mode \(offlineManager.syncPending ? "with sync pending" : "")")
                }
                
                // Toggle between SD Cards and Job Boxes
                Picker("Search Type", selection: $isJobBoxMode) {
                    Text("SD Cards").tag(false)
                    Text("Job Boxes").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: isJobBoxMode) { _ in
                    // Clear results when switching modes
                    searchResults = []
                    jobBoxSearchResults = []
                    if searchValue.isNotEmpty {
                        // Re-run search if there's a value
                        performSearch()
                    }
                }
                
                Picker("Search Field", selection: $searchField) {
                    ForEach(searchFields.keys.sorted(), id: \.self) { key in
                        Text(searchFields[key]!)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: searchField) { _ in
                    // Don't clear values if we're processing status from stats
                    if !sharedState.shouldNavigateToSearch {
                        searchValue = ""
                        statusSearchPerformed = false
                        searchResults = []
                        jobBoxSearchResults = []
                    }
                }
                .accessibilityLabel("Search filter type")
                
                if searchField == "cardNumber" {
                    TextField(isJobBoxMode ? "Enter Box Number" : "Enter Card Number", text: $searchValue)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .accessibilityLabel(isJobBoxMode ? "Box number search field" : "Card number search field")
                } else if searchField == "photographer" {
                    DropdownSearchField(
                        placeholder: "Select Photographer",
                        selectedText: searchValue,
                        options: photographerNames,
                        onSelect: { selected in
                            searchValue = selected
                        }
                    )
                    .accessibilityLabel("Photographer selection")
                } else if searchField == "school" {
                    DropdownSearchField(
                        placeholder: "Select School",
                        selectedText: searchValue,
                        options: dropdownRecords
                            .map { $0.value }
                            .sorted(),
                        onSelect: { selected in
                            searchValue = selected
                        }
                    )
                    .accessibilityLabel("School selection")
                } else if searchField == "status" {
                    DropdownSearchField(
                        placeholder: "Select Status",
                        selectedText: searchValue,
                        options: isJobBoxMode ? jobBoxStatuses : localStatuses,
                        onSelect: { selected in
                            searchValue = selected
                        }
                    )
                    .accessibilityLabel("Status selection")
                }
                
                Button(action: performSearch) {
                    if FirestoreManager.shared.isLoading {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text(FirestoreManager.shared.loadingMessage)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                    } else {
                        Text("Search")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
                .accessibilityButton(label: "Search", hint: "Search for records")
                
                if searchField == "status" && statusSearchPerformed {
                    if isJobBoxMode {
                        Text("\(jobBoxSearchResults.count) \(jobBoxSearchResults.count == 1 ? "job box" : "job boxes") in \(searchValue) status")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .accessibilityLabel("\(jobBoxSearchResults.count) \(jobBoxSearchResults.count == 1 ? "job box" : "job boxes") in \(searchValue) status")
                    } else {
                        Text("\(searchResults.count) \(searchResults.count == 1 ? "card" : "cards") in \(searchValue) status")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .accessibilityLabel("\(searchResults.count) \(searchResults.count == 1 ? "card" : "cards") in \(searchValue) status")
                    }
                }
                
                // List of results with pull-to-refresh support.
                List {
                    if isJobBoxMode {
                        ForEach(jobBoxSearchResults) { record in
                            JobBoxBubbleView(record: record)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        jobBoxRecordToDelete = record
                                        confirmDeleteJobBoxRecord(record)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .accessibilityLabel("Delete job box record")
                                }
                        }
                    } else {
                        ForEach(searchResults) { record in
                            RecordBubbleView(record: record)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        recordToDelete = record
                                        confirmDeleteRecord(record)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .accessibilityLabel("Delete record")
                                }
                        }
                    }
                }
                // Refreshable modifier triggers a refresh when pulling down.
                .refreshable {
                    if searchValue.isEmpty {
                        fetchInitialData()
                    } else {
                        performSearch()
                    }
                }
                .listStyle(PlainListStyle())
            }
            
            // Custom confirmation dialog
            ConfirmationDialogView(isPresented: $showConfirmationDialog, config: confirmationConfig)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Info"),
                  message: Text(alertMessage),
                  dismissButton: .default(Text("OK")))
        }
        .onAppear {
            // Always fetch data on appear
            fetchInitialData()
            
            // Check for status from stats view
            if !hasCheckedForStatus {
                hasCheckedForStatus = true
            }
        }
        .onChange(of: sharedState.selectedStatusFromChart) { newStatus in
            if let status = newStatus, sharedState.shouldNavigateToSearch {
                // Process the status
                processSelectedStatus(status)
                // Reset navigation flag
                sharedState.resetAfterNavigation()
            }
        }
    }
    
    func processSelectedStatus(_ status: String) {
        // Determine if this is a job box status or SD card status
        let isJobBoxStatus = jobBoxStatuses.contains { $0.lowercased() == status.lowercased() }
        
        // Set search mode accordingly
        isJobBoxMode = isJobBoxStatus
        
        // Set search field to status
        searchField = "status"
        
        // Set search value
        searchValue = status
        
        // Trigger search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            performSearch()
        }
    }
    
    func fetchInitialData() {
        guard let orgID = sessionManager.user?.organizationID else { return }
        
        // Load cached photographer names.
        if let data = UserDefaults.standard.data(forKey: "photographerNames"),
           let cachedNames = try? JSONDecoder().decode([String].self, from: data) {
            self.photographerNames = cachedNames
        }
        FirestoreManager.shared.listenForPhotographers(inOrgID: orgID) { names in
            self.photographerNames = names
        }
        
        // Load cached dropdown data for schools.
        if let data = UserDefaults.standard.data(forKey: "dropdownRecords"),
           let cachedDropdowns = try? JSONDecoder().decode([DropdownRecord].self, from: data) {
            self.dropdownRecords = cachedDropdowns
        }
        FirestoreManager.shared.listenForSchoolsData(forOrgID: orgID) { records in
            self.dropdownRecords = records
        }
        
        // Fetch the most recent 50 records, depending on mode
        if isJobBoxMode {
            fetchInitialJobBoxRecords(orgID: orgID)
        } else {
            fetchInitialSDCardRecords(orgID: orgID)
        }
    }
    
    func fetchInitialSDCardRecords(orgID: String) {
        FirestoreManager.shared.fetchRecords(field: "all", value: "", organizationID: orgID) { result in
            switch result {
            case .success(let records):
                let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                self.searchResults = Array(sortedRecords.prefix(50))
                
                // Check if there's a status to display after data is loaded
                if let status = sharedState.selectedStatusFromChart, sharedState.shouldNavigateToSearch {
                    processSelectedStatus(status)
                    sharedState.resetAfterNavigation()
                }
            case .failure(let error):
                alertMessage = "Error fetching records: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    func fetchInitialJobBoxRecords(orgID: String) {
        FirestoreManager.shared.fetchJobBoxRecords(field: "all", value: "", organizationID: orgID) { result in
            switch result {
            case .success(let records):
                let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                self.jobBoxSearchResults = Array(sortedRecords.prefix(50))
                
                // Check if there's a status to display after data is loaded
                if let status = sharedState.selectedStatusFromChart, sharedState.shouldNavigateToSearch {
                    processSelectedStatus(status)
                    sharedState.resetAfterNavigation()
                }
            case .failure(let error):
                alertMessage = "Error fetching job box records: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    func performSearch() {
        UIApplication.shared.endEditing()
        
        guard !searchValue.isEmpty,
              let orgID = sessionManager.user?.organizationID else {
            alertMessage = "Please enter/select a value to search."
            showAlert = true
            return
        }
        
        if isJobBoxMode {
            performJobBoxSearch(orgID: orgID)
        } else {
            performSDCardSearch(orgID: orgID)
        }
    }
    
    func performSDCardSearch(orgID: String) {
        if searchField.lowercased() == "status" {
            statusSearchPerformed = true
            FirestoreManager.shared.fetchRecords(field: "all", value: "", organizationID: orgID) { result in
                switch result {
                case .success(let records):
                    let latestRecordsDict = Dictionary(grouping: records, by: { $0.cardNumber })
                        .compactMapValues { recs in
                            recs.sorted { $0.timestamp > $1.timestamp }.first
                        }
                    let filteredRecords = latestRecordsDict.values.filter {
                        $0.status.lowercased() == searchValue.lowercased()
                    }
                    let sortedRecords = filteredRecords.sorted { $0.timestamp > $1.timestamp }
                    searchResults = sortedRecords
                    if sortedRecords.isEmpty {
                        alertMessage = "No records found."
                        showAlert = true
                    }
                case .failure(let error):
                    alertMessage = "Error fetching records: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        } else {
            FirestoreManager.shared.fetchRecords(field: searchField, value: searchValue, organizationID: orgID) { result in
                switch result {
                case .success(let records):
                    let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                    searchResults = sortedRecords
                    if sortedRecords.isEmpty {
                        alertMessage = "No records found."
                        showAlert = true
                    }
                case .failure(let error):
                    alertMessage = "Error fetching records: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    func performJobBoxSearch(orgID: String) {
        let fieldToSearch = searchField == "cardNumber" ? "boxNumber" : searchField
        
        // Debug: Print raw document structure when there's an error
        FirestoreManager.shared.debugPrintJobBoxDocuments(organizationID: orgID)
        
        if fieldToSearch.lowercased() == "status" {
            statusSearchPerformed = true
            FirestoreManager.shared.fetchJobBoxRecords(field: "all", value: "", organizationID: orgID) { result in
                switch result {
                case .success(let records):
                    let latestRecordsDict = Dictionary(grouping: records, by: { $0.boxNumber })
                        .compactMapValues { recs in
                            recs.sorted { $0.timestamp > $1.timestamp }.first
                        }
                    let filteredRecords = latestRecordsDict.values.filter {
                        $0.status.lowercased() == searchValue.lowercased()
                    }
                    let sortedRecords = filteredRecords.sorted { $0.timestamp > $1.timestamp }
                    jobBoxSearchResults = sortedRecords
                    if sortedRecords.isEmpty {
                        alertMessage = "No job box records found."
                        showAlert = true
                    }
                case .failure(let error):
                    print("❌ SearchView JobBox fetch error: \(error)")
                    if error.localizedDescription.contains("couldn't be read because it isn't in the correct format") {
                        alertMessage = "Error fetching job box records: Data format mismatch. Please check the console logs for detailed field information."
                    } else {
                        alertMessage = "Error fetching job box records: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
            }
        } else {
            FirestoreManager.shared.fetchJobBoxRecords(field: fieldToSearch, value: searchValue, organizationID: orgID) { result in
                switch result {
                case .success(let records):
                    let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                    jobBoxSearchResults = sortedRecords
                    if sortedRecords.isEmpty {
                        alertMessage = "No job box records found."
                        showAlert = true
                    }
                case .failure(let error):
                    print("❌ SearchView JobBox fetch error: \(error)")
                    if error.localizedDescription.contains("couldn't be read because it isn't in the correct format") {
                        alertMessage = "Error fetching job box records: Data format mismatch. Please check the console logs for detailed field information."
                    } else {
                        alertMessage = "Error fetching job box records: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
            }
        }
    }
    
    // Function to show confirmation dialog for SD card record
    func confirmDeleteRecord(_ record: FirestoreRecord) {
        confirmationConfig = AlertConfiguration(
            title: "Confirm Deletion",
            message: "Are you sure you want to delete the record for card #\(record.cardNumber)? This action cannot be undone.",
            primaryButtonTitle: "Delete",
            secondaryButtonTitle: "Cancel",
            isDestructive: true,
            primaryAction: {
                if let recordID = record.id {
                    deleteRecord(recordID: recordID)
                }
            },
            secondaryAction: {
                // Cancel action, do nothing
            }
        )
        
        showConfirmationDialog = true
    }
    
    // Function to show confirmation dialog for job box record
    func confirmDeleteJobBoxRecord(_ record: JobBoxRecord) {
        confirmationConfig = AlertConfiguration(
            title: "Confirm Deletion",
            message: "Are you sure you want to delete the record for job box #\(record.boxNumber)? This action cannot be undone.",
            primaryButtonTitle: "Delete",
            secondaryButtonTitle: "Cancel",
            isDestructive: true,
            primaryAction: {
                if let recordID = record.id {
                    deleteJobBoxRecord(recordID: recordID)
                }
            },
            secondaryAction: {
                // Cancel action, do nothing
            }
        )
        
        showConfirmationDialog = true
    }
    
    func deleteRecord(recordID: String) {
        FirestoreManager.shared.deleteRecord(recordID: recordID) { result in
            switch result {
            case .success(let message):
                alertMessage = message
                if let index = searchResults.firstIndex(where: { $0.id == recordID }) {
                    searchResults.remove(at: index)
                }
            case .failure(let error):
                alertMessage = "Failed to delete record: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
    
    func deleteJobBoxRecord(recordID: String) {
        FirestoreManager.shared.deleteJobBoxRecord(recordID: recordID) { result in
            switch result {
            case .success(let message):
                alertMessage = message
                if let index = jobBoxSearchResults.firstIndex(where: { $0.id == recordID }) {
                    jobBoxSearchResults.remove(at: index)
                }
            case .failure(let error):
                alertMessage = "Failed to delete job box record: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
}

// Helper extension to check if a string is empty
extension String {
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}
