//
//  JobBoxRecord.swift
//  NFC Sd Tracker
//
//  Created by administrator on 5/5/25.
//


import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct JobBoxRecord: Codable, Identifiable {
    @DocumentID var id: String?
    let timestamp: Date
    let photographer: String
    let boxNumber: String
    let school: String
    let status: String
    let organizationID: String
}

extension FirestoreManager {
    // MARK: - Save Job Box Record
    func saveJobBoxRecord(timestamp: Date,
                        photographer: String,
                        boxNumber: String,
                        school: String,
                        status: String,
                        organizationID: String,
                        completion: @escaping (Result<String, Error>) -> Void) {
        
        let record = JobBoxRecord(timestamp: timestamp,
                                 photographer: photographer,
                                 boxNumber: boxNumber,
                                 school: school,
                                 status: status,
                                 organizationID: organizationID)
        
        // Check if we're online
        if OfflineDataManager.shared.isOnline {
            isLoading = true
            loadingMessage = "Saving job box record..."
            
            do {
                _ = try db.collection("jobBoxes").addDocument(from: record) { error in
                    self.isLoading = false
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        // Cache the new record
                        var cachedRecords = OfflineDataManager.shared.getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? ?? []
                        cachedRecords.append(record)
                        OfflineDataManager.shared.cacheData(data: cachedRecords, forKey: "cachedJobBoxRecords")
                        
                        completion(.success("Job box record saved successfully"))
                    }
                }
            } catch {
                self.isLoading = false
                completion(.failure(error))
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
            var query: Query = db.collection("jobBoxes").whereField("organizationID", isEqualTo: organizationID)
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
                        let records = try snapshot.documents.compactMap { try $0.data(as: JobBoxRecord.self) }
                        
                        // Cache records for offline use
                        OfflineDataManager.shared.cacheData(data: records, forKey: "cachedJobBoxRecords")
                        
                        completion(.success(records))
                    } catch {
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
            db.collection("jobBoxes").document(recordID).delete { error in
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
            db.collection("jobBoxes")
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
}

// Extension to OfflineDataManager
extension OfflineDataManager {
    // Add a new job box record when offline
    func addOfflineJobBoxRecord(record: JobBoxRecord) {
        // Add to local cache
        var cachedRecords = getCachedData(forKey: "cachedJobBoxRecords") as [JobBoxRecord]? ?? []
        cachedRecords.append(record)
        cacheData(data: cachedRecords, forKey: "cachedJobBoxRecords")
        
        // Create pending operation
        let recordData: [String: Any] = [
            "timestamp": record.timestamp,
            "photographer": record.photographer,
            "boxNumber": record.boxNumber,
            "school": record.school,
            "status": record.status,
            "organizationID": record.organizationID
        ]
        
        addPendingOperation(
            type: .add,
            collectionPath: "jobBoxes",
            data: recordData
        )
    }
}