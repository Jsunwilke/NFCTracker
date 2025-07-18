//
//  Shift.swift
//  NFC Sd Tracker
//
//  Created by administrator on 5/6/25.
//


import Foundation

/// A simplified model for shifts, extracted from the ICS events
struct Shift: Identifiable, Equatable, Codable {
    let id: String // This is the UID from the ICS event
    let summary: String
    let schoolName: String
    let startDate: Date?
    let endDate: Date?
    
    // Implement Equatable
    static func == (lhs: Shift, rhs: Shift) -> Bool {
        return lhs.id == rhs.id
    }
}