import SwiftUI
import Charts

struct PhotographerJobBoxMetrics: View {
    let photographerLeftJobTimes: [PhotographerLeftJobTime]
    
    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 4)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Average Time Job Boxes in 'Left Job'")
                    .font(.headline)
                    .padding(.top, 12)
                
                if photographerLeftJobTimes.isEmpty {
                    Text("No job box data available")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    if #available(iOS 16.0, *) {
                        // Bar Chart for iOS 16+
                        Chart(photographerLeftJobTimes) { item in
                            BarMark(
                                x: .value("Hours", max(0.1, item.averageHours)), // Ensure non-zero value for visibility
                                y: .value("Photographer", item.photographerName)
                            )
                            .foregroundStyle(Color.orange.gradient)
                            .annotation(position: .trailing) {
                                Text(formatDuration(hours: item.averageHours))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let name = value.as(String.self) {
                                        Text(name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    } else {
                        // Fallback for iOS 15 and below
                        let maxHours = max(1.0, photographerLeftJobTimes.map { $0.averageHours }.max() ?? 1)
                        
                        VStack(spacing: 10) {
                            ForEach(photographerLeftJobTimes) { item in
                                HStack {
                                    Text(item.photographerName)
                                        .font(.subheadline)
                                        .frame(width: 80, alignment: .leading)
                                        .lineLimit(1)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange)
                                        .frame(width: max(20, CGFloat(item.averageHours) / CGFloat(maxHours) * 200), height: 20)
                                    
                                    Text(formatDuration(hours: item.averageHours))
                                        .font(.subheadline)
                                }
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.subheadline.bold())
                            .padding(.horizontal)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading) {
                            ForEach(photographerLeftJobTimes) { item in
                                HStack {
                                    Text(item.photographerName)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    if item.currentBoxes > 0 {
                                        Text("\(item.currentBoxes) \(item.currentBoxes == 1 ? "box" : "boxes") currently in 'Left Job'")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("No boxes currently in 'Left Job'")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatDuration(hours: item.averageHours))
                                        .font(.subheadline.bold())
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal)
                                .background(item.currentBoxes > 0 ? Color.orange.opacity(0.1) : Color.clear)
                                .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 350)
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

struct PhotographerLeftJobTime: Identifiable {
    let id = UUID()
    let photographerName: String
    let averageHours: Double
    let totalHours: Double
    let transitionCount: Int
    let currentBoxes: Int
    
    // Computed property for average if needed
    var averageTimeFormatted: String {
        if averageHours < 24 {
            return String(format: "%.1f hours", averageHours)
        } else {
            return String(format: "%.1f days", averageHours / 24)
        }
    }
}
