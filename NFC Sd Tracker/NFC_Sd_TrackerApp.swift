import SwiftUI
import Firebase

@main
struct NFCSdTrackerApp: App {
    @StateObject var sessionManager = SessionManager()
    
    // Initialize accessibility coordinator
    @StateObject var accessibilityCoordinator = AccessibilityCoordinator.shared
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Firestore for offline capability
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true  // Enable offline persistence
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited  // Allow unlimited cache size
        Firestore.firestore().settings = settings
        
        // Start network monitoring
        NetworkMonitor.shared.startMonitoring()
        
        // Register for accessibility notifications
        registerForAccessibilityNotifications()
        
        // Configure appearance
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(sessionManager)
                .environmentObject(accessibilityCoordinator)
                .onAppear {
                    // Ensure the offline data manager is initialized
                    _ = OfflineDataManager.shared
                }
        }
    }
    
    private func registerForAccessibilityNotifications() {
        // Already handled by AccessibilityCoordinator
    }
    
    private func configureAppearance() {
        // Configure UITabBar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(red: 43/255, green: 62/255, blue: 80/255, alpha: 1)
        UITabBar.appearance().unselectedItemTintColor = .white
        UITabBar.appearance().tintColor = .systemBlue
        UITabBar.appearance().standardAppearance = tabBarAppearance
        
        // Configure iOS 15+ specific appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            
            // Configure navigation bar for iOS 15+
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = UIColor(red: 43/255, green: 62/255, blue: 80/255, alpha: 1)
            navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            
            UINavigationBar.appearance().standardAppearance = navBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
            UINavigationBar.appearance().compactAppearance = navBarAppearance
        }
        
        // Configure UITextField appearance
        UITextField.appearance().tintColor = .systemBlue
    }
}
