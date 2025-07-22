import SwiftUI

struct SessionSelectionView: View {
    let schoolId: String
    var onSelectSession: (Session) -> Void
    var onCancel: () -> Void
    
    @StateObject private var sessionsManager = SessionsManager.shared
    @EnvironmentObject var sessionManager: SessionManager
    @State private var searchText = ""
    
    // Filtered sessions based on school ID and search text
    private var filteredSessions: [Session] {
        let schoolSessions = schoolId.isEmpty 
            ? sessionsManager.sessions 
            : sessionsManager.sessions(forSchoolId: schoolId)
        
        if searchText.isEmpty {
            return schoolSessions
        } else {
            return schoolSessions.filter { session in
                session.schoolName.localizedCaseInsensitiveContains(searchText) ||
                session.photographerNames.localizedCaseInsensitiveContains(searchText) ||
                session.date.contains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if sessionsManager.isLoading {
                    ProgressView("Loading sessions...")
                        .padding()
                } else if filteredSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No upcoming sessions found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if !schoolId.isEmpty {
                            Text("for this school")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredSessions) { session in
                        SessionRowView(session: session) {
                            onSelectSession(session)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .searchable(text: $searchText, prompt: "Search sessions")
                }
            }
            .navigationTitle("Select Session")
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                }
            )
            .onAppear {
                // Load sessions if not already loaded
                if let orgID = sessionManager.user?.organizationID {
                    sessionsManager.loadSessions(organizationID: orgID)
                }
            }
        }
    }
}

struct SessionRowView: View {
    let session: Session
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // School name and date
                HStack {
                    Text(session.schoolName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(SessionsManager.shared.formatSessionDate(session))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Time and session type
                HStack {
                    Text("\(session.startTime) - \(session.endTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let sessionType = session.sessionType {
                        Text("• \(sessionType)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Photographers
                if !session.photographers.isEmpty {
                    Text("Photographers: \(session.photographerNames)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Notes if available
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview Provider
struct SessionSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionSelectionView(
            schoolId: "sampleSchoolId",
            onSelectSession: { _ in },
            onCancel: { }
        ).environmentObject(SessionManager())
    }
}