import Foundation
import FirebaseFirestore
import Combine

class OfflineDataManager: ObservableObject {
    static let shared = OfflineDataManager()
    
    // Published properties to track connectivity and sync status
    @Published var isOnline: Bool = true
    @Published var syncPending: Bool = false
    @Published var syncInProgress: Bool = false
    @Published var lastSyncTime: Date?
    
    // Queue for pending operations
    private var pendingOperations: [PendingOperation] = []
    
    private init() {
        // Load any pending operations from UserDefaults
        loadPendingOperations()
        
        // Start monitoring network connectivity
        startMonitoringConnectivity()
    }
    
    // MARK: - Network Monitoring
    
    private func startMonitoringConnectivity() {
        // Use NetworkMonitor to check connectivity status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectivityStatusChanged),
            name: NSNotification.Name("ConnectivityStatusChanged"),
            object: nil
        )
        
        // Initial check
        isOnline = NetworkMonitor.shared.isConnected
        
        // If we're online and have pending operations, try to sync
        if isOnline && syncPending {
            syncPendingOperations()
        }
    }
    
    @objc private func connectivityStatusChanged(notification: Notification) {
        if let isOnline = notification.userInfo?["isOnline"] as? Bool {
            self.isOnline = isOnline
            
            // If we're back online and have pending operations, try to sync
            if isOnline && syncPending {
                syncPendingOperations()
            }
        }
    }
    
    // MARK: - Offline Operations
    
    struct PendingOperation: Codable {
        enum OperationType: String, Codable {
            case add
            case update
            case delete
        }
        
        let id: String
        let type: OperationType
        let collectionPath: String
        let data: [String: String] // Simplified for storage
        let timestamp: Date
    }
    
    func addPendingOperation(type: PendingOperation.OperationType,
                             collectionPath: String,
                             data: [String: Any],
                             id: String? = nil) {
        // Convert complex data types to strings for storage
        let storableData = data.mapValues { value -> String in
            if let valueAsString = value as? String {
                return valueAsString
            } else {
                return "\(value)"
            }
        }
        
        // Create a unique ID if none provided
        let operationID = id ?? UUID().uuidString
        
        // Create and store the pending operation
        let operation = PendingOperation(
            id: operationID,
            type: type,
            collectionPath: collectionPath,
            data: storableData,
            timestamp: Date()
        )
        
        pendingOperations.append(operation)
        syncPending = true
        
        // Save to UserDefaults
        savePendingOperations()
        
        // Try to sync if we're online
        if isOnline {
            syncPendingOperations()
        }
    }
    
    private func savePendingOperations() {
        if let encoded = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(encoded, forKey: "pendingFirestoreOperations")
        }
    }
    
    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: "pendingFirestoreOperations"),
           let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) {
            pendingOperations = operations
            syncPending = !operations.isEmpty
        }
    }
    
    // MARK: - Sync Operations
    
    func syncPendingOperations() {
        guard isOnline && syncPending && !syncInProgress && !pendingOperations.isEmpty else {
            return
        }
        
        syncInProgress = true
        
        // Process operations in order (first in, first out)
        var completedOperationIndices: [Int] = []
        let db = Firestore.firestore()
        
        let dispatchGroup = DispatchGroup()
        
        for (index, operation) in pendingOperations.enumerated() {
            dispatchGroup.enter()
            
            // Convert string data back to appropriate types when possible
            let firestoreData: [String: Any] = operation.data.mapValues { stringValue in
                // Try to convert back to numeric types if possible
                if let intValue = Int(stringValue) {
                    return intValue
                } else if let doubleValue = Double(stringValue) {
                    return doubleValue
                } else if stringValue.lowercased() == "true" {
                    return true
                } else if stringValue.lowercased() == "false" {
                    return false
                } else {
                    return stringValue
                }
            }
            
            switch operation.type {
            case .add:
                let docRef = db.collection(operation.collectionPath).document()
                docRef.setData(firestoreData) { error in
                    if error == nil {
                        completedOperationIndices.append(index)
                    } else {
                        print("Error syncing add operation: \(error?.localizedDescription ?? "")")
                    }
                    dispatchGroup.leave()
                }
                
            case .update:
                db.collection(operation.collectionPath).document(operation.id).updateData(firestoreData) { error in
                    if error == nil {
                        completedOperationIndices.append(index)
                    } else {
                        print("Error syncing update operation: \(error?.localizedDescription ?? "")")
                    }
                    dispatchGroup.leave()
                }
                
            case .delete:
                db.collection(operation.collectionPath).document(operation.id).delete { error in
                    if error == nil {
                        completedOperationIndices.append(index)
                    } else {
                        print("Error syncing delete operation: \(error?.localizedDescription ?? "")")
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // Remove completed operations (in reverse order to not affect indices)
            for index in completedOperationIndices.sorted(by: >) {
                self.pendingOperations.remove(at: index)
            }
            
            // Update status
            self.syncPending = !self.pendingOperations.isEmpty
            self.syncInProgress = false
            self.lastSyncTime = Date()
            
            // Save updated pending operations
            self.savePendingOperations()
        }
    }
    
    // MARK: - Local Cache
    
    // Generic method to cache data
    func cacheData<T: Encodable>(data: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    // Generic method to retrieve cached data
    func getCachedData<T: Decodable>(forKey key: String) -> T? {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        return nil
    }
    
    // MARK: - SD Card Specific Methods
    
    // Cache records for offline use
    func cacheRecords(records: [FirestoreRecord]) {
        cacheData(data: records, forKey: "cachedRecords")
    }
    
    // Get cached records
    func getCachedRecords() -> [FirestoreRecord]? {
        return getCachedData(forKey: "cachedRecords")
    }
    
    // Add a new record when offline
    func addOfflineRecord(record: FirestoreRecord) {
        // Add to local cache
        var cachedRecords = getCachedRecords() ?? []
        cachedRecords.append(record)
        cacheData(data: cachedRecords, forKey: "cachedRecords")
        
        // Create pending operation with only the fields expected by Firestore rules
        var recordData: [String: Any] = [
            "cardNumber": record.cardNumber,
            "school": record.school,
            "status": record.status,
            "userId": record.userId,
            "organizationID": record.organizationID,
            "timestamp": record.timestamp
        ]
        
        // Note: photographer, uploadedFromJasonsHouse, uploadedFromAndysHouse fields 
        // are stored in the record but not sent to Firestore due to strict field validation in security rules
        
        addPendingOperation(
            type: .add,
            collectionPath: "records",
            data: recordData
        )
    }
    
    // MARK: - Job Box Specific Methods
    
    // These methods are now implemented as extensions in JobBoxFirestoreModel.swift
    // No job box specific methods should be included here to avoid duplicate declarations
}
