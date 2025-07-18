import Foundation
import Combine

class ShiftManager: ObservableObject {
    static let shared = ShiftManager()
    
    @Published var shifts: [Shift] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    @Published var lastRefreshTime: Date? = nil
    
    private let calendarUrl = "https://calendar.getsling.com/564097/18fffd515e88999522da2876933d36a9d9d83a7eeca9c07cd58890a8/Sling_Calendar_all.ics"
    private var cancellables = Set<AnyCancellable>()
    
    // Time interval for forced refresh (10 minutes)
    private let refreshInterval: TimeInterval = 600
    
    private init() {
        // Load cached shifts on initialization
        loadCachedShifts()
    }
    
    // Generate a custom UID based on school name and DATE ONLY (no time)
    private func generateCustomUID(schoolName: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd" // Date only, no time
        let dateString = dateFormatter.string(from: date)
        
        // Normalize school name (remove spaces, lowercase)
        let normalizedSchool = schoolName.lowercased().replacingOccurrences(of: " ", with: "_")
        
        // Create the custom UID
        return "shift_\(normalizedSchool)_\(dateString)"
    }
    
    func loadShifts(forceRefresh: Bool = false) {
        // Check if we need to refresh
        let shouldRefresh = forceRefresh || shifts.isEmpty || needsRefresh()
        
        // If we don't need to refresh, return immediately
        if !shouldRefresh {
            print("Using cached shifts - no refresh needed")
            return
        }
        
        print("DEBUG: ShiftManager loading shifts with forceRefresh=\(forceRefresh)")
        isLoading = true
        lastError = nil
        
        guard let url = URL(string: calendarUrl) else {
            lastError = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.lastError = "Failed to load calendar: \(error.localizedDescription)"
                    print("Error loading calendar: \(error)")
                }
            }, receiveValue: { [weak self] data in
                guard let self = self else { return }
                
                if let icsString = String(data: data, encoding: .utf8) {
                    print("DEBUG: Successfully downloaded ICS data")
                    let events = ICSParser.parseICS(from: icsString)
                    
                    // Create a new array to hold our processed shifts
                    var newShifts: [Shift] = []
                    
                    // Group events by school name and date only
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd" // Date only, no time
                    
                    let groupedEvents = Dictionary(grouping: events) { event -> String in
                        guard let date = event.startDate else { return "unknown" }
                        let dateStr = dateFormatter.string(from: date)
                        return "\(event.schoolName)_\(dateStr)"
                    }
                    
                    // Process each group
                    for (_, group) in groupedEvents {
                        guard let firstEvent = group.first,
                              let startDate = firstEvent.startDate,
                              !firstEvent.schoolName.isEmpty else { continue }
                        
                        // Generate custom UID based on school and date only
                        let customUID = generateCustomUID(schoolName: firstEvent.schoolName, date: startDate)
                        
                        // Combine photographer names
                        let photographers = group.map { $0.employeeName }.joined(separator: ", ")
                        
                        // Update the summary to include all photographers
                        var summaryComponents = firstEvent.summary.components(separatedBy: " - ")
                        if summaryComponents.count > 0 {
                            summaryComponents[0] = photographers
                        }
                        let combinedSummary = summaryComponents.joined(separator: " - ")
                        
                        // Create a new Shift with our custom UID
                        let shift = Shift(
                            id: customUID,
                            summary: combinedSummary,
                            schoolName: firstEvent.schoolName,
                            startDate: firstEvent.startDate,
                            endDate: firstEvent.endDate
                        )
                        
                        newShifts.append(shift)
                    }
                    
                    // Replace the shifts array with our new properly-ID'd shifts
                    self.shifts = newShifts
                    
                    // Update last refresh time
                    self.lastRefreshTime = Date()
                    
                    // Cache the shifts
                    self.cacheShifts()
                    
                    print("Loaded \(self.shifts.count) unique shifts")
                } else {
                    self.lastError = "Failed to decode calendar data"
                }
            })
            .store(in: &cancellables)
    }
    
    // Check if we need a refresh based on time elapsed
    private func needsRefresh() -> Bool {
        guard let lastRefresh = lastRefreshTime else {
            // If we've never refreshed, we need a refresh
            return true
        }
        
        // If more than the refresh interval has passed, refresh
        return Date().timeIntervalSince(lastRefresh) > refreshInterval
    }
    
    func getShiftsForSchool(_ schoolName: String) -> [Shift] {
        return shifts.filter { shift in
            shift.schoolName.lowercased().contains(schoolName.lowercased())
        }.sorted { first, second in
            // Sort by date (most recent first)
            guard let firstDate = first.startDate, let secondDate = second.startDate else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    // Format a shift date for display
    func formatShiftDate(_ shift: Shift) -> String {
        guard let date = shift.startDate else {
            return "Unknown date"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return formatter.string(from: date)
    }
    
    // Cache shifts to UserDefaults
    private func cacheShifts() {
        do {
            let data = try JSONEncoder().encode(shifts)
            UserDefaults.standard.set(data, forKey: "cachedShifts")
            
            // Also cache the refresh timestamp
            if let lastRefresh = lastRefreshTime {
                UserDefaults.standard.set(lastRefresh.timeIntervalSince1970, forKey: "shiftLastRefreshTime")
            }
        } catch {
            print("Error caching shifts: \(error)")
        }
    }
    
    // Load cached shifts from UserDefaults
    private func loadCachedShifts() {
        // Load last refresh time
        if let timeInterval = UserDefaults.standard.object(forKey: "shiftLastRefreshTime") as? TimeInterval {
            lastRefreshTime = Date(timeIntervalSince1970: timeInterval)
        }
        
        // Load cached shifts
        if let data = UserDefaults.standard.data(forKey: "cachedShifts") {
            do {
                shifts = try JSONDecoder().decode([Shift].self, from: data)
                print("Loaded \(shifts.count) cached shifts")
            } catch {
                print("Error loading cached shifts: \(error)")
            }
        }
    }
}
