import SwiftUI

struct ShiftSelectionView: View {
    let schoolName: String
    let onSelectShift: (Shift) -> Void
    let onCancel: () -> Void
    
    @ObservedObject private var shiftManager = ShiftManager.shared
    @State private var searchText: String = ""
    @State private var hasRequestedRefresh: Bool = false
    
    // Add a computed property that ensures we only display unique shifts
    var filteredShifts: [Shift] {
        // First, get all shifts for the school
        let schoolShifts = shiftManager.getShiftsForSchool(schoolName)
        
        // Then, filter by search text if needed
        let searchFiltered = searchText.isEmpty ? schoolShifts : schoolShifts.filter { shift in
            let dateString = shiftManager.formatShiftDate(shift)
            return dateString.lowercased().contains(searchText.lowercased())
        }
        
        // Ensure uniqueness by key (school name + date)
        var uniqueShifts: [Shift] = []
        var seenKeys: Set<String> = []
        
        for shift in searchFiltered {
            guard let date = shift.startDate else { continue }
            
            // Create a key from school and date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let dateString = dateFormatter.string(from: date)
            let normalizedSchool = shift.schoolName.lowercased().replacingOccurrences(of: " ", with: "_")
            let key = "shift_\(normalizedSchool)_\(dateString)"
            
            // Only add this shift if we haven't seen this key before
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                uniqueShifts.append(shift)
            }
        }
        
        return uniqueShifts
    }
    
    // Function to generate custom ID for a shift
    private func generateCustomID(for shift: Shift) -> String {
        guard let date = shift.startDate else {
            return "shift_unknown_date"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd" // Date only, no time
        let dateString = dateFormatter.string(from: date)
        
        // Normalize school name (remove spaces, lowercase)
        let normalizedSchool = shift.schoolName.lowercased().replacingOccurrences(of: " ", with: "_")
        
        // Create the custom UID
        return "shift_\(normalizedSchool)_\(dateString)"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if shiftManager.isLoading {
                    ProgressView("Loading shifts...")
                        .padding()
                } else if let error = shiftManager.lastError {
                    VStack {
                        Text("Error loading shifts")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding()
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Retry") {
                            shiftManager.loadShifts(forceRefresh: true)
                        }
                        .padding()
                    }
                } else if filteredShifts.isEmpty {
                    VStack {
                        Text("No shifts found for \(schoolName)")
                            .font(.headline)
                            .padding()
                        
                        Button("Refresh Shifts") {
                            shiftManager.loadShifts(forceRefresh: true)
                        }
                        .padding()
                    }
                } else {
                    // Search bar
                    TextField("Search by date", text: $searchText)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    // Refresh button
                    Button("Refresh Shifts") {
                        shiftManager.loadShifts(forceRefresh: true)
                    }
                    .padding(.horizontal)
                    
                    // Shifts list - now using our deduplicated list
                    List {
                        ForEach(filteredShifts) { shift in
                            Button(action: {
                                // Create a copy of the shift with our custom ID
                                let customID = generateCustomID(for: shift)
                                
                                // Create a new shift with the custom ID
                                let customShift = Shift(
                                    id: customID,
                                    summary: shift.summary,
                                    schoolName: shift.schoolName,
                                    startDate: shift.startDate,
                                    endDate: shift.endDate
                                )
                                
                                // Pass the shift with custom ID to the callback
                                onSelectShift(customShift)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shift.schoolName)
                                        .font(.headline)
                                    
                                    Text(shiftManager.formatShiftDate(shift))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        // Pull to refresh will force a reload of the shifts
                        shiftManager.loadShifts(forceRefresh: true)
                    }
                }
            }
            .navigationTitle("Select a Shift")
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                }
            )
            .onAppear {
                // Load shifts when the view appears, but force a refresh
                // This ensures we always get the most recent ICS data when selecting a shift
                if !hasRequestedRefresh {
                    hasRequestedRefresh = true
                    shiftManager.loadShifts(forceRefresh: true)
                }
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct ShiftSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ShiftSelectionView(
            schoolName: "Sample School",
            onSelectShift: { _ in },
            onCancel: { }
        )
    }
}
