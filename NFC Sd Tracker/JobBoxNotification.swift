import SwiftUI

struct JobBoxNotification: View {
    let jobBoxes: [(JobBoxRecord, TimeInterval)]
    
    var body: some View {
        if !jobBoxes.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text("Attention: Job Boxes Left on Job")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 2)
                
                ForEach(jobBoxes.indices, id: \.self) { index in
                    let item = jobBoxes[index]
                    let record = item.0
                    let hours = item.1 / 3600
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(record.boxNumber)")
                                .fontWeight(.semibold)
                            
                            Text(record.school)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        Text(formatDuration(hours: hours))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(hours > 24 ? Color.red.opacity(0.6) : Color.orange.opacity(0.6))
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.4))
            )
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Job Boxes Left on Job Alert")
        }
    }
    
    private func formatDuration(hours: Double) -> String {
        if hours < 24 {
            return String(format: "%.1f hours", hours)
        } else {
            let days = hours / 24
            if days < 2 {
                return String(format: "%.1f day", days)
            } else {
                return String(format: "%.1f days", days)
            }
        }
    }
}

