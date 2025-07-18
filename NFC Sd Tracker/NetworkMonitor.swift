import Foundation
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "NetworkMonitorQueue")
    private(set) var isConnected = true
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            
            DispatchQueue.main.async {
                self?.isConnected = isConnected
                // Post notification for other components
                NotificationCenter.default.post(
                    name: NSNotification.Name("ConnectivityStatusChanged"),
                    object: nil,
                    userInfo: ["isOnline": isConnected]
                )
            }
        }
        
        // Start monitoring on a background queue
        networkMonitor.start(queue: workerQueue)
    }
    
    func stopMonitoring() {
        networkMonitor.cancel()
    }
}