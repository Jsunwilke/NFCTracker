import SwiftUI

struct ShiftSelectionView: View {
    let schoolName: String
    let onSelectShift: (Shift) -> Void
    let onCancel: () -> Void
    
    @ObservedObject private var shiftManager = ShiftManager.shared
    @State private var searchText: String = ""
    
    var filteredShifts: [Shift] {
        if searchText.isEmpty {
            return shiftManager.getShiftsForSchool(schoolName)
        } else {
            return shiftManager.getShiftsForSchool(schoolName).filter { shift in
                let dateString = shiftManager.formatShiftDate(shift)
                return dateString.lowercased().contains(searchText.lowercased())
            }
        }
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
                        
                        if shiftManager.shifts.isEmpty {
                            Button("Load All Shifts") {
                                shiftManager.loadShifts(forceRefresh: true)
                            }
                            .padding()
                        }
                    }
                } else {
                    // Search bar
                    TextField("Search by date", text: $searchText)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    // Shifts list
                    List {
                        ForEach(filteredShifts) { shift in
                            Button(action: {
                                onSelectShift(shift)
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
                }
            }
            .navigationTitle("Select a Shift")
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                }
            )
            .onAppear {
                // Load shifts when the view appears
                shiftManager.loadShifts()
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