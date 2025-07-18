import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct FirestoreRecord: Codable, Identifiable {
    @DocumentID var id: String?
    let timestamp: Date
    let photographer: String
    let cardNumber: String
    let school: String
    let status: String
    let uploadedFromJasonsHouse: String?
    let uploadedFromAndysHouse: String?
    let organizationID: String
    let userId: String // User ID for Firebase Auth
}

struct DropdownRecord: Codable, Identifiable {
    @DocumentID var id: String?
    let type: String
    let value: String
    let organizationID: String?
}

class FirestoreManager: ObservableObject {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    
    // Observable properties to track loading states
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    
    // MARK: - Save Record
    func saveRecord(timestamp: Date,
                    photographer: String,
                    cardNumber: String,
                    school: String,
                    status: String,
                    uploadedFromJasonsHouse: String,
                    uploadedFromAndysHouse: String,
                    organizationID: String,
                    userId: String,
                    completion: @escaping (Result<String, Error>) -> Void) {
        
        let record = FirestoreRecord(timestamp: timestamp,
                                     photographer: photographer,
                                     cardNumber: cardNumber,
                                     school: school,
                                     status: status,
                                     uploadedFromJasonsHouse: uploadedFromJasonsHouse.isEmpty ? nil : uploadedFromJasonsHouse,
                                     uploadedFromAndysHouse: uploadedFromAndysHouse.isEmpty ? nil : uploadedFromAndysHouse,
                                     organizationID: organizationID,
                                     userId: userId)
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            isLoading = true
            loadingMessage = "Saving record..."
            
            // Create a dictionary with only the fields expected by Firestore rules
            let documentData: [String: Any] = [
                "cardNumber": record.cardNumber,
                "school": record.school,
                "status": record.status,
                "photographer": record.photographer,
                "userId": record.userId,
                "organizationID": record.organizationID,
                "timestamp": Timestamp(date: record.timestamp)
            ]
            
            // Note: uploadedFromJasonsHouse, uploadedFromAndysHouse fields 
            // are stored in the record but not sent to Firestore due to strict field validation in security rules
            
            print("🔍 DEBUG: SD Card record data being sent to Firebase:")
            for (key, value) in documentData {
                print("   \(key): \(value) (type: \(type(of: value)))")
            }
            
            db.collection("records").addDocument(data: documentData) { error in
                self.isLoading = false
                if let error = error {
                    let nsError = error as NSError
                    print("❌ Error saving SD card record:")
                    print("   Error code: \(nsError.code)")
                    print("   Error domain: \(nsError.domain)")
                    print("   Error description: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    // Cache the new record
                    var cachedRecords = OfflineDataManager.shared.getCachedRecords() ?? []
                    cachedRecords.append(record)
                    OfflineDataManager.shared.cacheRecords(records: cachedRecords)
                    
                    completion(.success("Record saved successfully"))
                }
            }
        } else {
            // Handle offline saving
            OfflineDataManager.shared.addOfflineRecord(record: record)
            completion(.success("Record saved offline. Will sync when connection is restored."))
        }
    }
    
    // MARK: - Fetch Records
    func fetchRecords(field: String,
                      value: String,
                      organizationID: String,
                      completion: @escaping (Result<[FirestoreRecord], Error>) -> Void) {
        
        isLoading = true
        loadingMessage = "Loading records..."
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            var query: Query = db.collection("records").whereField("organizationID", isEqualTo: organizationID)
            if field.lowercased() != "all" {
                query = query.whereField(field, isEqualTo: value)
            }
            
            query.getDocuments { snapshot, error in
                self.isLoading = false
                
                if let error = error {
                    // Try to get cached data if there's an error
                    if let cachedRecords = OfflineDataManager.shared.getCachedRecords() {
                        let filteredRecords = self.filterCachedRecords(
                            records: cachedRecords,
                            field: field,
                            value: value,
                            organizationID: organizationID
                        )
                        completion(.success(filteredRecords))
                    } else {
                        completion(.failure(error))
                    }
                } else if let snapshot = snapshot {
                    do {
                        let records = try snapshot.documents.compactMap { try $0.data(as: FirestoreRecord.self) }
                        
                        // Cache records for offline use
                        OfflineDataManager.shared.cacheRecords(records: records)
                        
                        completion(.success(records))
                    } catch {
                        // Try to get cached data if there's an error
                        if let cachedRecords = OfflineDataManager.shared.getCachedRecords() {
                            let filteredRecords = self.filterCachedRecords(
                                records: cachedRecords,
                                field: field,
                                value: value,
                                organizationID: organizationID
                            )
                            completion(.success(filteredRecords))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
            }
        } else {
            // Offline mode - use cached data
            self.isLoading = false
            
            if let cachedRecords = OfflineDataManager.shared.getCachedRecords() {
                let filteredRecords = filterCachedRecords(
                    records: cachedRecords,
                    field: field,
                    value: value,
                    organizationID: organizationID
                )
                completion(.success(filteredRecords))
            } else {
                let error = NSError(domain: "com.iconikstudio.sdtracker", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "No cached data available while offline"
                ])
                completion(.failure(error))
            }
        }
    }
    
    // Helper method to filter cached records
    private func filterCachedRecords(records: [FirestoreRecord],
                                     field: String,
                                     value: String,
                                     organizationID: String) -> [FirestoreRecord] {
        let orgRecords = records.filter { $0.organizationID == organizationID }
        
        if field.lowercased() == "all" {
            return orgRecords
        } else {
            return orgRecords.filter { record in
                switch field.lowercased() {
                case "cardnumber":
                    return record.cardNumber == value
                case "photographer":
                    return record.photographer == value
                case "school":
                    return record.school == value
                case "status":
                    return record.status.lowercased() == value.lowercased()
                default:
                    return false
                }
            }
        }
    }
    
    // MARK: - Fetch Schools Data (One-Time)
    func fetchSchoolsData(forOrgID orgID: String,
                          completion: @escaping (Result<[DropdownRecord], Error>) -> Void) {
        
        isLoading = true
        loadingMessage = "Loading schools data..."
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            db.collection("schools")
              .whereField("organizationID", isEqualTo: orgID)
              .getDocuments { snapshot, error in
                self.isLoading = false
                
                if let error = error {
                    print("Error in fetchSchoolsData: \(error.localizedDescription)")
                    
                    // Try to get cached schools data
                    if let cachedData = OfflineDataManager.shared.getCachedData(forKey: "schools") as [DropdownRecord]? {
                        let filtered = cachedData.filter { $0.organizationID == orgID }
                        completion(.success(filtered))
                    } else {
                        completion(.failure(error))
                    }
                } else if let snapshot = snapshot {
                    do {
                        let records = try snapshot.documents.compactMap { try $0.data(as: DropdownRecord.self) }
                        
                        // Cache schools records
                        OfflineDataManager.shared.cacheData(data: records, forKey: "schools")
                        
                        completion(.success(records))
                    } catch {
                        print("Error decoding schools documents: \(error.localizedDescription)")
                        
                        // Try to get cached schools data
                        if let cachedData = OfflineDataManager.shared.getCachedData(forKey: "schools") as [DropdownRecord]? {
                            let filtered = cachedData.filter { $0.organizationID == orgID }
                            completion(.success(filtered))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
              }
        } else {
            // Offline mode - use cached data
            self.isLoading = false
            
            if let cachedData = OfflineDataManager.shared.getCachedData(forKey: "schools") as [DropdownRecord]? {
                let filtered = cachedData.filter { $0.organizationID == orgID }
                completion(.success(filtered))
            } else {
                let error = NSError(domain: "com.iconikstudio.sdtracker", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "No cached schools data available while offline"
                ])
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Listen for Schools Data with Local Fallback Update
    func listenForSchoolsData(forOrgID orgID: String,
                              completion: @escaping ([DropdownRecord]) -> Void) {
        
        // First check for cached data and deliver it immediately
        if let cachedData = OfflineDataManager.shared.getCachedData(forKey: "schools") as [DropdownRecord]? {
            let filtered = cachedData.filter { $0.organizationID == orgID }
            completion(filtered)
        }
        
        // If we're online, set up the listener
        if OfflineDataManager.shared.isOnline {
            db.collection("schools")
              .whereField("organizationID", isEqualTo: orgID)
              .addSnapshotListener { snapshot, error in
                  if let snapshot = snapshot {
                      do {
                          let records = try snapshot.documents.compactMap { try $0.data(as: DropdownRecord.self) }
                          
                          // Save to cache
                          OfflineDataManager.shared.cacheData(data: records, forKey: "schools")
                          
                          completion(records)
                      } catch {
                          print("Error decoding schools data: \(error.localizedDescription)")
                          completion([])
                      }
                  } else if let error = error {
                      print("Error listening to schools data: \(error.localizedDescription)")
                      completion([])
                  }
              }
        }
    }
    
    // MARK: - Listen for Photographers from the `users` collection
    func listenForPhotographers(inOrgID orgID: String,
                                completion: @escaping ([String]) -> Void) {
        
        // First check for cached data and deliver it immediately
        if let cachedNames = OfflineDataManager.shared.getCachedData(forKey: "photographerNames") as [String]? {
            completion(cachedNames)
        }
        
        // If we're online, set up the listener
        if OfflineDataManager.shared.isOnline {
            db.collection("users")
              .whereField("organizationID", isEqualTo: orgID)
              .addSnapshotListener { snapshot, error in
                  guard let snapshot = snapshot else {
                      print("Error listening for users: \(error?.localizedDescription ?? "Unknown error")")
                      completion([])
                      return
                  }
                  
                  // Extract the 'firstName' from each user doc
                  let firstNames = snapshot.documents.compactMap { $0.data()["firstName"] as? String }
                  
                  // Save to cache
                  OfflineDataManager.shared.cacheData(data: firstNames, forKey: "photographerNames")
                  
                  completion(firstNames.sorted())
              }
        }
    }
    
    // MARK: - Delete Record
    func deleteRecord(recordID: String, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        loadingMessage = "Deleting record..."
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            db.collection("records").document(recordID).delete { error in
                self.isLoading = false
                
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Update cached records
                    if var cachedRecords = OfflineDataManager.shared.getCachedRecords() {
                        cachedRecords.removeAll { $0.id == recordID }
                        OfflineDataManager.shared.cacheRecords(records: cachedRecords)
                    }
                    
                    completion(.success("Record deleted successfully"))
                }
            }
        } else {
            // Queue delete operation for when we're back online
            self.isLoading = false
            
            OfflineDataManager.shared.addPendingOperation(
                type: .delete,
                collectionPath: "records",
                data: [:],
                id: recordID
            )
            
            // Update local cache
            if var cachedRecords = OfflineDataManager.shared.getCachedRecords() {
                cachedRecords.removeAll { $0.id == recordID }
                OfflineDataManager.shared.cacheRecords(records: cachedRecords)
            }
            
            completion(.success("Record queued for deletion. Will sync when connection is restored."))
        }
    }
    
    // MARK: - Add School
    func addSchool(schoolName: String,
                   organizationID: String,
                   completion: @escaping (Result<String, Error>) -> Void) {
        
        isLoading = true
        loadingMessage = "Adding school..."
        
        let newSchoolData: [String: Any] = [
            "value": schoolName,
            "organizationID": organizationID
        ]
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            db.collection("schools").addDocument(data: newSchoolData) { error in
                self.isLoading = false
                
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Update local cache
                    if var cachedDropdowns = OfflineDataManager.shared.getCachedData(forKey: "schools") as [DropdownRecord]? {
                        let newRecord = DropdownRecord(
                            id: UUID().uuidString, // Temporary ID
                            type: "school",
                            value: schoolName,
                            organizationID: organizationID
                        )
                        cachedDropdowns.append(newRecord)
                        OfflineDataManager.shared.cacheData(data: cachedDropdowns, forKey: "schools")
                    }
                    
                    completion(.success("School added successfully!"))
                }
            }
        } else {
            // Queue add operation for when we're back online
            self.isLoading = false
            
            OfflineDataManager.shared.addPendingOperation(
                type: .add,
                collectionPath: "schools",
                data: newSchoolData
            )
            
            // Update local cache
            if var cachedDropdowns = OfflineDataManager.shared.getCachedData(forKey: "schools") as [DropdownRecord]? {
                let newRecord = DropdownRecord(
                    id: UUID().uuidString, // Temporary ID
                    type: "school",
                    value: schoolName,
                    organizationID: organizationID
                )
                cachedDropdowns.append(newRecord)
                OfflineDataManager.shared.cacheData(data: cachedDropdowns, forKey: "schools")
            }
            
            completion(.success("School added offline. Will sync when connection is restored."))
        }
    }
}
