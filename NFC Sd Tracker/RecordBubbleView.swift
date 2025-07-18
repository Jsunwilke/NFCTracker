import SwiftUI

struct RecordBubbleView: View {
    let record: FirestoreRecord
    
    @ViewBuilder
    private var bubbleBackground: some View {
        switch record.status.lowercased() {
        case "job box":
            Color.orange.opacity(0.4)
        case "camera":
            Color.green.opacity(0.4)
        case "envelope":
            Color.yellow.opacity(0.4)
        case "uploaded":
            if let jason = record.uploadedFromJasonsHouse, jason.lowercased() == "yes" {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .center,
                    endPoint: .bottomTrailing
                )
            } else if let andy = record.uploadedFromAndysHouse, andy.lowercased() == "yes" {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.green]),
                    startPoint: .center,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.blue.opacity(1)
            }
        case "cleared":
            Color.gray.opacity(0.4)
        default:
            Color(.systemGray6).opacity(0.4)
        }
    }
    
    private var statusIconName: String? {
        switch record.status.lowercased() {
        case "job box":    return "Job Box"
        case "camera":     return "Camera"
        case "envelope":   return "Envelope"
        case "uploaded":   return "Uploaded"
        case "cleared":    return "Trash Can"
        default:           return nil
        }
    }
    
    private func friendlyDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Number: \(record.cardNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Photographer: \(record.photographer)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("School: \(record.school)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("Status: \(record.status)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                if let jason = record.uploadedFromJasonsHouse, jason.lowercased() == "yes" {
                    Text("Uploaded from Jason's house")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(Color.red))
                }
                if let andy = record.uploadedFromAndysHouse, andy.lowercased() == "yes" {
                    Text("Uploaded from Andy's house")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(Color.green))
                }
                
                Text("Timestamp: \(friendlyDateString(from: record.timestamp))")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bubbleBackground)
            .cornerRadius(10)
            .shadow(color: Color.black, radius: 6, x: 1, y: 4)
            .padding(.horizontal)
            .padding(.vertical, -3)
            
            if let iconName = statusIconName {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .padding(.top, 10)
                    .padding(.trailing, 25)
            }
        }
    }
}
