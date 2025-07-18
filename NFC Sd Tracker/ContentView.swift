import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .scan
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showWriteNFC = false
    @State private var showManualEntry = false
    @State private var showAddSchool = false
    
    // Use the shared state manager for cross-view communication
    @StateObject private var sharedState = SharedStateManager.shared

    enum Tab {
        case scan, search, stats
    }
    
    init() {
        // Configure the appearance of the tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(red: 43/255, green: 62/255, blue: 80/255, opacity: 1.0))
        UITabBar.appearance().unselectedItemTintColor = .white
        UITabBar.appearance().tintColor = .blue
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(red: 43/255, green: 62/255, blue: 80/255, alpha: 1.0)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                ScanView()
                    .tabItem {
                        Image("scanIcon")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                        Text("Scan")
                    }
                    .tag(Tab.scan)
                    .accessibilityLabel("Scan Tab")
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(Tab.search)
                    .accessibilityLabel("Search Tab")
                
                StatisticsView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Stats")
                    }
                    .tag(Tab.stats)
                    .accessibilityLabel("Statistics Tab")
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("IconikSDHeader")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                        .accessibilityLabel("Iconik SD Tracker Logo")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Display the user's first name.
                    if let firstName = sessionManager.user?.firstName {
                        Text(firstName)
                            .foregroundColor(.white)
                            .font(.headline)
                            .accessibilityLabel("Signed in as \(firstName)")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sign Out") {
                            sessionManager.signOut()
                        }
                        .accessibilityLabel("Sign Out Button")
                        
                        Button("Write to NFC") {
                            showWriteNFC = true
                        }
                        .accessibilityLabel("Write to NFC Button")
                        
                        // Option to add schools.
                        Button("Manage Schools") {
                            showAddSchool = true
                        }
                        .accessibilityLabel("Manage Schools Button")
                        
                        Button("Manual Entry") {
                            showManualEntry = true
                        }
                        .accessibilityLabel("Manual Entry Button")
                    } label: {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(.white)
                            .accessibilityLabel("Menu")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showWriteNFC) {
            WriteNFCView()
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView()
        }
        .sheet(isPresented: $showAddSchool) {
            AddSchoolView()
                .environmentObject(sessionManager)
        }
        // Add onChange listeners to watch for tab changes from the SharedStateManager
        .onChange(of: sharedState.activeTab) { newTab in
            selectedTab = newTab
        }
        // Watch for changes to the selectedTab and update the SharedStateManager
        .onChange(of: selectedTab) { newTab in
            sharedState.activeTab = newTab
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(SessionManager())
    }
}
