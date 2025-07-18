import SwiftUI
import Combine

// Create a dedicated class to manage shared state between views
class SharedStateManager: ObservableObject {
    static let shared = SharedStateManager()
    
    // Published property that will trigger view updates
    @Published var selectedStatusFromChart: String?
    @Published var shouldNavigateToSearch: Bool = false
    
    // The tab that should be selected
    @Published var activeTab: ContentView.Tab = .scan
    
    private init() {}
    
    // Set the status and trigger navigation
    func setStatusAndNavigate(status: String) {
        selectedStatusFromChart = status
        shouldNavigateToSearch = true
        activeTab = .search
    }
    
    // Reset after navigation is complete
    func resetAfterNavigation() {
        shouldNavigateToSearch = false
        // Keep the selectedStatus until it's consumed
    }
    
    // Consume the selected status (call this after using the value)
    func consumeSelectedStatus() -> String? {
        let status = selectedStatusFromChart
        selectedStatusFromChart = nil
        return status
    }
}
