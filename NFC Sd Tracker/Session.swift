import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Photographer: Codable {
    let email: String
    let id: String
    let name: String
}

struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    let createdAt: Date
    let date: String // Format: "2025-07-24"
    let endTime: String // Format: "16:00"
    let notes: String?
    let organizationID: String
    let photographers: [Photographer]
    let schoolId: String
    let schoolName: String
    let sessionType: String? // e.g., "underclass"
    let sport: String?
    let startTime: String // Format: "07:00"
    let status: String // e.g., "scheduled"
    let updatedAt: Date?
    
    // Computed property to get formatted date and time
    var formattedDateTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let sessionDate = dateFormatter.date(from: date) {
            dateFormatter.dateStyle = .medium
            let dateString = dateFormatter.string(from: sessionDate)
            return "\(dateString) \(startTime) - \(endTime)"
        }
        return "\(date) \(startTime) - \(endTime)"
    }
    
    // Computed property to get photographer names
    var photographerNames: String {
        photographers.map { $0.name }.joined(separator: ", ")
    }
    
    // Helper to check if session is upcoming
    var isUpcoming: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let sessionDate = dateFormatter.date(from: date) else { return false }
        
        // Compare dates without time
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessionDay = calendar.startOfDay(for: sessionDate)
        
        return sessionDay >= today
    }
    
    // Helper to check if session is within next 2 weeks
    var isWithinTwoWeeks: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let sessionDate = dateFormatter.date(from: date) else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let twoWeeksFromNow = calendar.date(byAdding: .day, value: 14, to: today)!
        let sessionDay = calendar.startOfDay(for: sessionDate)
        
        return sessionDay >= today && sessionDay <= twoWeeksFromNow
    }
}