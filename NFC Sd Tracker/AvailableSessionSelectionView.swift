import SwiftUI

struct AvailableSessionSelectionView: View {
    var onSelectSession: (Session) -> Void
    var onCancel: () -> Void
    
    @StateObject private var sessionsManager = SessionsManager.shared
    @EnvironmentObject var sessionManager: SessionManager
    @State private var searchText = ""
    
    // Filtered sessions based on search text
    private var filteredSessions: [Session] {
        if searchText.isEmpty {
            return sessionsManager.availableSessions
        } else {
            return sessionsManager.availableSessions.filter { session in
                session.schoolName.localizedCaseInsensitiveContains(searchText) ||
                session.photographerNames.localizedCaseInsensitiveContains(searchText) ||
                session.date.contains(searchText) ||
                (session.sessionType?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if sessionsManager.isLoading {
                    ProgressView("Loading available sessions...")
                        .padding()
                } else if filteredSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(sessionsManager.availableSessions.isEmpty 
                             ? "No available sessions in the next 2 weeks" 
                             : "No sessions match your search")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if !sessionsManager.availableSessions.isEmpty {
                            Text("Try adjusting your search terms")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available sessions for the next 2 weeks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        List(filteredSessions) { session in
                            AvailableSessionRowView(session: session) {
                                onSelectSession(session)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .searchable(text: $searchText, prompt: "Search sessions")
                    }
                }
            }
            .navigationTitle("Select Session")
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                }
            )
            .onAppear {
                // Force refresh to ensure we have the latest available sessions
                if let orgID = sessionManager.user?.organizationID {
                    sessionsManager.loadSessions(organizationID: orgID, forceRefresh: true)
                }
            }
        }
    }
}

struct AvailableSessionRowView: View {
    let session: Session
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // School name and date
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.schoolName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let sessionType = session.sessionType {
                            Text(sessionType.capitalized)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SessionsManager.shared.formatSessionDate(session))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("\(session.startTime) - \(session.endTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Photographers
                if !session.photographers.isEmpty {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(session.photographerNames)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Notes if available
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview Provider
struct AvailableSessionSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        AvailableSessionSelectionView(
            onSelectSession: { _ in },
            onCancel: { }
        ).environmentObject(SessionManager())
    }
}