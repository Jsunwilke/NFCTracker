import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct JobBoxRecord: Codable, Identifiable {
    @DocumentID var id: String?
    let timestamp: Date
    let photographer: String
    let boxNumber: String
    let school: String
    let schoolId: String? // New field to store school document ID
    let status: String
    let organizationID: String
    let userId: String // User ID for Firebase Auth
    let shiftUid: String? // New field to store the selected shift UID
    
    // Custom initializer for defensive coding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle DocumentID separately
        _id = try container.decodeIfPresent(DocumentID<String>.self, forKey: CodingKeys.id) ?? DocumentID(wrappedValue: nil)
        
        // Timestamp handling with fallback
        if let firebaseTimestamp = try? container.decode(Timestamp.self, forKey: .timestamp) {
            timestamp = firebaseTimestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else if let stringDate = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: stringDate) ?? Date()
        } else {
            print("⚠️ JobBoxRecord: Using current date as fallback for timestamp")
            timestamp = Date()
        }
        
        // String fields with fallbacks
        photographer = try container.decodeIfPresent(String.self, forKey: .photographer) ?? ""
        boxNumber = try container.decodeIfPresent(String.self, forKey: .boxNumber) ?? ""
        school = try container.decodeIfPresent(String.self, forKey: .school) ?? ""
        schoolId = try container.decodeIfPresent(String.self, forKey: .schoolId)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        organizationID = try container.decodeIfPresent(String.self, forKey: .organizationID) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        shiftUid = try container.decodeIfPresent(String.self, forKey: .shiftUid)
        
        print("✅ JobBoxRecord decoded successfully: ID \(id ?? "nil"), box \(boxNumber), photographer \(photographer), userId \(userId)")
    }
    
    // Standard initializer for creating new records
    init(id: String? = nil, timestamp: Date, photographer: String, boxNumber: String, school: String, schoolId: String? = nil, status: String, organizationID: String, userId: String, shiftUid: String? = nil) {
        self._id = DocumentID(wrappedValue: id)
        self.timestamp = timestamp
        self.photographer = photographer
        self.boxNumber = boxNumber
        self.school = school
        self.schoolId = schoolId
        self.status = status
        self.organizationID = organizationID
        self.userId = userId
        self.shiftUid = shiftUid
    }
    
    // Coding keys
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, photographer, boxNumber, school, schoolId, status, organizationID, userId, shiftUid
    }
}

extension FirestoreManager {
    // MARK: - Save Job Box Record
    func saveJobBoxRecord(timestamp: Date,
                        photographer: String,
                        boxNumber: String,
                        school: String,
                        schoolId: String? = nil,
                        status: String,
                        organizationID: String,
                        userId: String,
                        shiftUid: String? = nil, // Added optional parameter
                        completion: @escaping (Result<String, Error>) -> Void) {
        
        let record = JobBoxRecord(id: nil,
                                 timestamp: timestamp,
                                 photographer: photographer,
                                 boxNumber: boxNumber,
                                 school: school,
                                 schoolId: schoolId,
                                 status: status,
                                 organizationID: organizationID,
                                 userId: userId,
                                 shiftUid: shiftUid) // Include the shiftUid
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            isLoading = true
            loadingMessage = "Saving job box record..."
            
            // Debug: Print current auth info
            if let currentUser = Auth.auth().currentUser {
                print("🔍 DEBUG: Current Firebase Auth UID: \(currentUser.uid)")
                print("🔍 DEBUG: Record userId being sent: \(record.userId)")
                print("🔍 DEBUG: Are they equal? \(currentUser.uid == record.userId)")
                
                // Verify user document exists
                debugVerifyUserDocument(userId: currentUser.uid) { exists in
                    if !exists {
                        print("❌ DEBUG: User document verification failed!")
                    }
                }
            } else {
                print("❌ DEBUG: No authenticated user found!")
            }
            
            // Create a dictionary with all fields for Firestore
            var documentData: [String: Any] = [
                "boxNumber": record.boxNumber,
                "school": record.school,
                "status": record.status,
                "photographer": record.photographer,
                "userId": record.userId,
                "organizationID": record.organizationID,
                "timestamp": Timestamp(date: record.timestamp)
            ]
            
            // Add optional fields if present
            if let schoolId = record.schoolId {
                documentData["schoolId"] = schoolId
            }
            if let shiftUid = record.shiftUid {
                documentData["shiftUid"] = shiftUid
            }
            
            // Debug: Print the exact data being sent
            print("🔍 DEBUG: Data being sent to Firebase:")
            for (key, value) in documentData {
                print("   \(key): \(value) (type: \(type(of: value)))")
            }
            
            
            let firestore = Firestore.firestore()
            var jobBoxRef: DocumentReference?
            jobBoxRef = firestore.collection("jobBoxes").addDocument(data: documentData) { error in
                self.isLoading = false
                if let error = error {
                    let nsError = error as NSError
                    print("❌ Error saving job box:")
                    print("   Error code: \(nsError.code)")
                    print("   Error domain: \(nsError.domain)")
                    print("   Error description: \(error.localizedDescription)")
                    print("   Full error: \(error)")
                    
                    // Check if it's a permission error
                    if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7 {
                        print("❌ This is a permission-denied error!")
                    }
                    
                    completion(.failure(error))
                } else {
                    // Cache the new record
                    var cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? ?? []
                    cachedRecords.append(record)
                    OfflineDataManager.shared.cacheData(data: cachedRecords, forKey: "cachedJobBoxRecords")
                    
                    // Update the session to mark it as assigned
                    if let shiftUid = record.shiftUid,
                       let jobBoxId = jobBoxRef?.documentID {
                        firestore.collection("sessions").document(shiftUid).updateData([
                            "hasJobBoxAssigned": true,
                            "jobBoxRecordId": jobBoxId
                        ]) { updateError in
                            if let updateError = updateError {
                                print("⚠️ Warning: Failed to update session assignment status: \(updateError)")
                                // Still consider the job box save successful
                            } else {
                                print("✅ Successfully updated session \(shiftUid) with job box assignment")
                            }
                        }
                    }
                    
                    completion(.success("Job box record saved successfully"))
                }
            }
        } else {
            // Handle offline saving
            OfflineDataManager.shared.addOfflineJobBoxRecord(record: record)
            completion(.success("Job box record saved offline. Will sync when connection is restored."))
        }
    }
    
    // MARK: - Fetch Job Box Records
    func fetchJobBoxRecords(field: String,
                          value: String,
                          organizationID: String,
                          completion: @escaping (Result<[JobBoxRecord], Error>) -> Void) {
        
        isLoading = true
        loadingMessage = "Loading job box records..."
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            let firestore = Firestore.firestore()
            var query: Query = firestore.collection("jobBoxes").whereField("organizationID", isEqualTo: organizationID)
            if field.lowercased() != "all" {
                query = query.whereField(field, isEqualTo: value)
            }
            
            query.getDocuments { snapshot, error in
                self.isLoading = false
                
                if let error = error {
                    // Try to get cached data if there's an error
                    if let cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? {
                        let filteredRecords = self.filterCachedJobBoxRecords(
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
                        let records = try snapshot.documents.compactMap { document -> JobBoxRecord? in
                            do {
                                return try document.data(as: JobBoxRecord.self)
                            } catch {
                                print("❌ Failed to decode JobBoxRecord from document \(document.documentID)")
                                print("❌ Error: \(error)")
                                print("❌ Document data: \(document.data())")
                                
                                // Log specific field issues
                                let data = document.data()
                                print("❌ Field check:")
                                print("   - timestamp: \(data["timestamp"] ?? "MISSING") (type: \(type(of: data["timestamp"])))")
                                print("   - photographer: \(data["photographer"] ?? "MISSING") (type: \(type(of: data["photographer"])))")
                                print("   - boxNumber: \(data["boxNumber"] ?? "MISSING") (type: \(type(of: data["boxNumber"])))")
                                print("   - school: \(data["school"] ?? "MISSING") (type: \(type(of: data["school"])))")
                                print("   - status: \(data["status"] ?? "MISSING") (type: \(type(of: data["status"])))")
                                print("   - organizationID: \(data["organizationID"] ?? "MISSING") (type: \(type(of: data["organizationID"])))")
                                print("   - userId: \(data["userId"] ?? "MISSING") (type: \(type(of: data["userId"])))")
                                print("   - shiftUid: \(data["shiftUid"] ?? "MISSING") (type: \(type(of: data["shiftUid"])))")
                                
                                return nil
                            }
                        }
                        
                        print("✅ Successfully decoded \(records.count) JobBoxRecord(s) out of \(snapshot.documents.count) document(s)")
                        
                        // Cache records for offline use
                        OfflineDataManager.shared.cacheData(data: records, forKey: "cachedJobBoxRecords")
                        
                        completion(.success(records))
                    } catch {
                        print("❌ Unexpected error in JobBoxRecord decoding: \(error)")
                        // Try to get cached data if there's an error
                        if let cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? {
                            let filteredRecords = self.filterCachedJobBoxRecords(
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
            
            if let cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? {
                let filteredRecords = filterCachedJobBoxRecords(
                    records: cachedRecords,
                    field: field,
                    value: value,
                    organizationID: organizationID
                )
                completion(.success(filteredRecords))
            } else {
                let error = NSError(domain: "com.iconikstudio.sdtracker", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "No cached job box data available while offline"
                ])
                completion(.failure(error))
            }
        }
    }
    
    // Helper method to filter cached job box records
    private func filterCachedJobBoxRecords(records: [JobBoxRecord],
                                         field: String,
                                         value: String,
                                         organizationID: String) -> [JobBoxRecord] {
        let orgRecords = records.filter { $0.organizationID == organizationID }
        
        if field.lowercased() == "all" {
            return orgRecords
        } else {
            return orgRecords.filter { record in
                switch field.lowercased() {
                case "boxnumber":
                    return record.boxNumber == value
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
    
    // MARK: - Delete Job Box Record
    func deleteJobBoxRecord(recordID: String, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        loadingMessage = "Deleting job box record..."
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            let firestore = Firestore.firestore()
            firestore.collection("jobBoxes").document(recordID).delete { error in
                self.isLoading = false
                
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Update cached records
                    if var cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? {
                        cachedRecords.removeAll { $0.id == recordID }
                        OfflineDataManager.shared.cacheData(data: cachedRecords, forKey: "cachedJobBoxRecords")
                    }
                    
                    completion(.success("Job box record deleted successfully"))
                }
            }
        } else {
            // Queue delete operation for when we're back online
            self.isLoading = false
            
            OfflineDataManager.shared.addPendingOperation(
                type: .delete,
                collectionPath: "jobBoxes",
                data: [:],
                id: recordID
            )
            
            // Update local cache
            if var cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? {
                cachedRecords.removeAll { $0.id == recordID }
                OfflineDataManager.shared.cacheData(data: cachedRecords, forKey: "cachedJobBoxRecords")
            }
            
            completion(.success("Job box record queued for deletion. Will sync when connection is restored."))
        }
    }
    
    // MARK: - Get Highest Box Number
    func getHighestBoxNumber(organizationID: String, completion: @escaping (Result<Int, Error>) -> Void) {
        isLoading = true
        loadingMessage = "Finding highest box number..."
        
        if OfflineDataManager.shared.isOnline {
            let firestore = Firestore.firestore()
            firestore.collection("jobBoxes")
              .whereField("organizationID", isEqualTo: organizationID)
              .getDocuments { snapshot, error in
                  self.isLoading = false
                  
                  if let error = error {
                      completion(.failure(error))
                      return
                  }
                  
                  guard let snapshot = snapshot else {
                      let error = NSError(domain: "com.iconikstudio.sdtracker", code: 0, userInfo: [
                          NSLocalizedDescriptionKey: "Failed to retrieve job box records"
                      ])
                      completion(.failure(error))
                      return
                  }
                  
                  let boxNumbers = snapshot.documents.compactMap { doc -> Int? in
                      guard let data = try? doc.data(as: JobBoxRecord.self) else { return nil }
                      return Int(data.boxNumber)
                  }
                  
                  let highestNumber = boxNumbers.max() ?? 3000
                  completion(.success(highestNumber))
              }
        } else {
            // Offline mode - check cached data
            if let cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? {
                let orgRecords = cachedRecords.filter { $0.organizationID == organizationID }
                let boxNumbers = orgRecords.compactMap { Int($0.boxNumber) }
                let highestNumber = boxNumbers.max() ?? 3000
                completion(.success(highestNumber))
            } else {
                // If no cached data, suggest starting at 3001
                completion(.success(3000))
            }
        }
    }
    
    // MARK: - Debug Function to Verify User Document
    func debugVerifyUserDocument(userId: String, completion: @escaping (Bool) -> Void) {
        let firestore = Firestore.firestore()
        firestore.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ DEBUG: Error fetching user document: \(error)")
                completion(false)
            } else if let snapshot = snapshot, snapshot.exists {
                if let data = snapshot.data() {
                    print("✅ DEBUG: User document exists!")
                    print("   organizationID: \(data["organizationID"] ?? "MISSING")")
                    print("   firstName: \(data["firstName"] ?? "MISSING")")
                    print("   email: \(data["email"] ?? "MISSING")")
                    completion(true)
                } else {
                    print("❌ DEBUG: User document exists but has no data")
                    completion(false)
                }
            } else {
                print("❌ DEBUG: User document does NOT exist for userId: \(userId)")
                completion(false)
            }
        }
    }
    
    // MARK: - Debug Function to Print Raw Firebase Document Structure
    func debugPrintJobBoxDocuments(organizationID: String) {
        print("🔍 DEBUG: Fetching raw JobBox documents for organization: \(organizationID)")
        
        let firestore = Firestore.firestore()
        firestore.collection("jobBoxes")
            .whereField("organizationID", isEqualTo: organizationID)
            .limit(to: 3) // Only fetch first 3 documents for debugging
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ DEBUG: Error fetching raw documents: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ DEBUG: No snapshot returned")
                    return
                }
                
                print("🔍 DEBUG: Found \(snapshot.documents.count) documents")
                
                for (index, document) in snapshot.documents.enumerated() {
                    print("\n📄 DEBUG Document \(index + 1) (ID: \(document.documentID)):")
                    let data = document.data()
                    
                    for (key, value) in data {
                        print("   \(key): \(value) (Type: \(type(of: value)))")
                    }
                    
                    // Special handling for timestamp field
                    if let timestamp = data["timestamp"] {
                        if let firebaseTimestamp = timestamp as? Timestamp {
                            print("   📅 Timestamp as Date: \(firebaseTimestamp.dateValue())")
                        }
                    }
                }
                
                print("\n🔍 DEBUG: Raw document structure analysis complete")
            }
    }
}

// Extension to OfflineDataManager
extension OfflineDataManager {
    // Add a new job box record when offline
    func addOfflineJobBoxRecord(record: JobBoxRecord) {
        // Add to local cache
        var cachedRecords = getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? ?? []
        cachedRecords.append(record)
        cacheData(data: cachedRecords, forKey: "cachedJobBoxRecords")
        
        // Create pending operation with all fields for Firestore
        var recordData: [String: Any] = [
            "boxNumber": record.boxNumber,
            "school": record.school,
            "status": record.status,
            "photographer": record.photographer,
            "userId": record.userId,
            "organizationID": record.organizationID,
            "timestamp": record.timestamp
        ]
        
        // Add optional fields if available
        if let schoolId = record.schoolId {
            recordData["schoolId"] = schoolId
        }
        if let shiftUid = record.shiftUid {
            recordData["shiftUid"] = shiftUid
        }
        
        
        addPendingOperation(
            type: .add,
            collectionPath: "jobBoxes",
            data: recordData
        )
    }
}
