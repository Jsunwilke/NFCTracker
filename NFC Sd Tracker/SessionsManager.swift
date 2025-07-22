import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

class SessionsManager: ObservableObject {
    static let shared = SessionsManager()
    
    @Published var sessions: [Session] = []
    @Published var availableSessions: [Session] = [] // Sessions not assigned to job boxes
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var assignedSessionIds: Set<String> = []
    
    private init() {
        // Load cached sessions on initialization
        loadCachedSessions()
    }
    
    deinit {
        listener?.remove()
    }
    
    // Load sessions from Firestore
    func loadSessions(organizationID: String, forceRefresh: Bool = false) {
        // If we're already loading, don't start another load
        guard !isLoading else { return }
        
        // Use cached data if available and not forcing refresh
        if !forceRefresh && !sessions.isEmpty {
            print("Using cached sessions - no refresh needed")
            return
        }
        
        print("DEBUG: SessionsManager loading sessions for org: \(organizationID)")
        isLoading = true
        lastError = nil
        
        // Remove existing listener if any
        listener?.remove()
        
        // Create a query for sessions from the organization
        let query = db.collection("sessions")
            .whereField("organizationID", isEqualTo: organizationID)
            .whereField("status", isEqualTo: "scheduled") // Only get scheduled sessions
        
        // Set up real-time listener
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.lastError = "Failed to load sessions: \(error.localizedDescription)"
                    print("Error loading sessions: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    self.lastError = "No session data received"
                    return
                }
                
                do {
                    let fetchedSessions = try snapshot.documents.compactMap { document -> Session? in
                        let session = try document.data(as: Session.self)
                        // Only include upcoming sessions
                        return session.isUpcoming ? session : nil
                    }
                    
                    // Sort sessions by date and start time
                    self.sessions = fetchedSessions.sorted { (s1, s2) in
                        if s1.date != s2.date {
                            return s1.date < s2.date
                        }
                        return s1.startTime < s2.startTime
                    }
                    
                    print("DEBUG: Loaded \(self.sessions.count) upcoming sessions")
                    
                    // Cache the sessions
                    self.cacheSessions()
                    
                } catch {
                    self.lastError = "Failed to parse sessions: \(error.localizedDescription)"
                    print("Error parsing sessions: \(error)")
                }
                
                // After loading sessions, also load assigned session IDs
                self.loadAssignedSessionIds(organizationID: organizationID)
            }
        }
    }
    
    // Load assigned session IDs from job boxes
    func loadAssignedSessionIds(organizationID: String) {
        // Query all job boxes with status "Packed" that have a shiftUid
        db.collection("jobBoxes")
            .whereField("organizationID", isEqualTo: organizationID)
            .whereField("status", isEqualTo: "Packed")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error loading assigned sessions: \(error)")
                    return
                }
                
                // Extract all shiftUids from packed job boxes
                var assignedIds = Set<String>()
                snapshot?.documents.forEach { document in
                    if let shiftUid = document.data()["shiftUid"] as? String {
                        assignedIds.insert(shiftUid)
                    }
                }
                
                DispatchQueue.main.async {
                    self.assignedSessionIds = assignedIds
                    print("DEBUG: Found \(assignedIds.count) assigned sessions")
                    
                    // Update available sessions
                    self.updateAvailableSessions()
                }
            }
    }
    
    // Update available sessions (within 2 weeks and not assigned)
    private func updateAvailableSessions() {
        availableSessions = sessions.filter { session in
            // Must be within 2 weeks
            guard session.isWithinTwoWeeks else { return false }
            
            // Must not be assigned to a job box
            if let sessionId = session.id {
                return !assignedSessionIds.contains(sessionId)
            }
            
            return true
        }
        
        print("DEBUG: \(availableSessions.count) available sessions out of \(sessions.count) total")
    }
    
    // Get sessions for a specific school by ID
    func sessions(forSchoolId schoolId: String) -> [Session] {
        return sessions.filter { $0.schoolId == schoolId }
    }
    
    // Get sessions for a specific school by name (kept for backward compatibility)
    func sessions(forSchool schoolName: String) -> [Session] {
        return sessions.filter { $0.schoolName.lowercased() == schoolName.lowercased() }
    }
    
    // Get session by ID
    func session(withId id: String) -> Session? {
        return sessions.first { $0.id == id }
    }
    
    // Format session date for display
    func formatSessionDate(_ session: Session) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let sessionDate = dateFormatter.date(from: session.date) {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            return dateFormatter.string(from: sessionDate)
        }
        
        return session.date
    }
    
    // Cache sessions locally
    private func cacheSessions() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "cachedSessions")
        }
    }
    
    // Load cached sessions
    private func loadCachedSessions() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "cachedSessions"),
           let cached = try? decoder.decode([Session].self, from: data) {
            // Filter to only show upcoming sessions
            self.sessions = cached.filter { $0.isUpcoming }
            print("Loaded \(self.sessions.count) cached sessions")
        }
    }
    
    // Stop listening to updates
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}