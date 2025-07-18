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
                        Text("Box #\(record.boxNumber)")
                            .fontWeight(.semibold)
                        
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

struct JobBoxNotification_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            
            JobBoxNotification(
                jobBoxes: [
                    (JobBoxRecord(id: "1", timestamp: Date().addingTimeInterval(-60000), photographer: "John", boxNumber: "3001", school: "Sample School", status: "Left Job", organizationID: "sample"), 60000),
                    (JobBoxRecord(id: "2", timestamp: Date().addingTimeInterval(-200000), photographer: "Jane", boxNumber: "3002", school: "Sample School", status: "Left Job", organizationID: "sample"), 200000)
                ]
            )
        }
    }
}