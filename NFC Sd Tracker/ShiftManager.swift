import Foundation
import Combine

class ShiftManager: ObservableObject {
    static let shared = ShiftManager()
    
    @Published var shifts: [Shift] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    
    private let calendarUrl = "https://calendar.getsling.com/564097/18fffd515e88999522da2876933d36a9d9d83a7eeca9c07cd58890a8/Sling_Calendar_all.ics"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load cached shifts on initialization
        loadCachedShifts()
    }
    
    func loadShifts(forceRefresh: Bool = false) {
        // If we have cached shifts and aren't forcing a refresh, just use those
        if !shifts.isEmpty && !forceRefresh {
            return
        }
        
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
                    let events = ICSParser.parseICS(from: icsString)
                    
                    // Convert ICS events to our Shift model
                    self.shifts = events.compactMap { event in
                        guard !event.schoolName.isEmpty else { return nil }
                        
                        return Shift(
                            id: event.id,
                            summary: event.summary,
                            schoolName: event.schoolName,
                            startDate: event.startDate,
                            endDate: event.endDate
                        )
                    }
                    
                    // Cache the shifts
                    self.cacheShifts()
                    
                    print("Loaded \(self.shifts.count) shifts")
                } else {
                    self.lastError = "Failed to decode calendar data"
                }
            })
            .store(in: &cancellables)
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
        } catch {
            print("Error caching shifts: \(error)")
        }
    }
    
    // Load cached shifts from UserDefaults
    private func loadCachedShifts() {
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