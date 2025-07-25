import SwiftUI

struct JobBoxBubbleView: View {
    let record: JobBoxRecord
    
    @ViewBuilder
    private var bubbleBackground: some View {
        switch record.status.lowercased() {
        case "packed":
            Color.blue.opacity(0.4)
        case "picked up":
            Color.green.opacity(0.4)
        case "left job":
            Color.orange.opacity(0.4)
        case "turned in":
            Color.gray.opacity(0.4)
        default:
            Color(.systemGray6).opacity(0.4)
        }
    }
    
    private var statusIconName: String? {
        switch record.status.lowercased() {
        case "packed":    return "Job Box"
        case "picked up": return "Job Box"
        case "left job":  return "Job Box"
        case "turned in": return "Job Box"
        default:          return nil
        }
    }
    
    private func friendlyDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Find the associated session if there's a shiftUid (now sessionId)
    private var associatedSession: Session? {
        guard let sessionId = record.shiftUid else { return nil }
        return SessionsManager.shared.session(withId: sessionId)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Job Box Number: \(record.boxNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Photographer: \(record.photographer)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("School: \(record.school)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("Status: \(record.status)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                // Display associated session info if available
                if let session = associatedSession {
                    Text("Session: \(SessionsManager.shared.formatSessionDate(session))")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("Time: \(session.startTime) - \(session.endTime)")
                        .font(.caption)
                        .foregroundColor(.white)
                } else if record.shiftUid != nil {
                    Text("Session: ID \(record.shiftUid!.prefix(8))...")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                Text("Timestamp: \(friendlyDateString(from: record.timestamp))")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bubbleBackground)
            .cornerRadius(10)
            .shadow(color: Color.black, radius: 6, x: 1, y: 4)
            .padding(.horizontal)
            .padding(.vertical, -3)
            
            if let iconName = statusIconName {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .padding(.top, 10)
                    .padding(.trailing, 25)
            }
        }
        .onAppear {
            // Make sure sessions are loaded if we have a session ID
            if record.shiftUid != nil && SessionsManager.shared.sessions.isEmpty {
                // We need the organization ID to load sessions
                // This should be provided from a parent view or environment
                // For now, we'll rely on sessions being already loaded
            }
        }
    }
}
