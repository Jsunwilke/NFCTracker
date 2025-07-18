import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var records: [FirestoreRecord] = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedTimeFrame: TimeFrame = .all
    
    // For status distribution
    @State private var statusCounts: [StatusCount] = []
    @State private var totalCards: Int = 0
    
    // For time tracking
    @State private var averageTimes: [StatusTime] = []
    
    enum TimeFrame: String, CaseIterable, Identifiable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var id: String { self.rawValue }
    }
    
    struct StatusCount: Identifiable {
        let id = UUID()
        let status: String
        let count: Int
        let percentage: Double
        
        var formattedPercentage: String {
            return String(format: "%.1f%%", percentage)
        }
    }
    
    struct StatusTime: Identifiable {
        let id = UUID()
        let status: String
        let averageHours: Double
        
        var formattedTime: String {
            if averageHours < 24 {
                return String(format: "%.1f hours", averageHours)
            } else {
                let days = averageHours / 24
                return String(format: "%.1f days", days)
            }
        }
    }
    
    // Status colors (matching RecordBubbleView)
    func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "job box":
            return Color.orange
        case "camera":
            return Color.green
        case "envelope":
            return Color.yellow
        case "uploaded":
            return Color.blue
        case "cleared":
            return Color.gray
        default:
            return Color(.systemGray4)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time frame selector
                    HStack {
                        Text("Time Frame:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Picker("Time Frame", selection: $selectedTimeFrame) {
                            ForEach(TimeFrame.allCases) { timeFrame in
                                Text(timeFrame.rawValue).tag(timeFrame)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedTimeFrame) { _ in
                            loadData()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Card status distribution
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Status Distribution")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        if statusCounts.isEmpty {
                            Text("No data available")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity)
                        } else {
                            // Pie Chart
                            ZStack {
                                // Background Card
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 4)
                                
                                VStack {
                                    Text("Total Cards: \(totalCards)")
                                        .font(.headline)
                                        .padding(.top, 8)
                                    
                                    if #available(iOS 16.0, *) {
                                        Chart(statusCounts) { statusCount in
                                            SectorMark(
                                                angle: .value("Count", statusCount.count),
                                                innerRadius: .ratio(0.5),
                                                angularInset: 1.5
                                            )
                                            .cornerRadius(5)
                                            .foregroundStyle(statusColor(statusCount.status))
                                            .annotation(position: .overlay) {
                                                Text("\(statusCount.count)")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.bold)
                                            }
                                        }
                                        .frame(height: 250)
                                    } else {
                                        // Fallback for iOS 15
                                        Text("Chart requires iOS 16+")
                                            .foregroundColor(.gray)
                                        
                                        // Simple bar representation
                                        VStack(spacing: 8) {
                                            ForEach(statusCounts) { item in
                                                HStack {
                                                    Text(item.status)
                                                        .font(.subheadline)
                                                        .frame(width: 80, alignment: .leading)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(statusColor(item.status))
                                                        .frame(width: CGFloat(item.count) / CGFloat(totalCards) * 200, height: 20)
                                                    
                                                    Text("\(item.count) (\(item.formattedPercentage))")
                                                        .font(.subheadline)
                                                }
                                            }
                                        }
                                        .frame(height: 250)
                                        .padding()
                                    }
                                    
                                    // Legend
                                    VStack(alignment: .leading) {
                                        ForEach(statusCounts) { item in
                                            HStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(statusColor(item.status))
                                                    .frame(width: 20, height: 20)
                                                
                                                Text(item.status)
                                                    .font(.subheadline)
                                                
                                                Spacer()
                                                
                                                Text("\(item.count) (\(item.formattedPercentage))")
                                                    .font(.subheadline)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom)
                                }
                                .padding(8)
                            }
                            .chartAccessibility(
                                label: "Card Status Distribution",
                                summary: "Total of \(totalCards) cards with \(statusCounts.map { $0.status }.joined(separator: ", ")) statuses",
                                items: statusCounts,
                                nameKeyPath: \.status,
                                valueKeyPath: \.formattedPercentage
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Average Time in Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average Time in Status")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        if averageTimes.isEmpty {
                            Text("No data available")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity)
                        } else {
                            // Bar Chart
                            ZStack {
                                // Background Card
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 4)
                                
                                VStack {
                                    if #available(iOS 16.0, *) {
                                        Chart(averageTimes) { statusTime in
                                            BarMark(
                                                x: .value("Status", statusTime.status),
                                                y: .value("Hours", statusTime.averageHours)
                                            )
                                            .foregroundStyle(statusColor(statusTime.status))
                                            .annotation(position: .top) {
                                                Text(statusTime.formattedTime)
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .chartYAxis {
                                            AxisMarks(position: .leading)
                                        }
                                        .frame(height: 250)
                                    } else {
                                        // Fallback for iOS 15
                                        Text("Chart requires iOS 16+")
                                            .foregroundColor(.gray)
                                        
                                        // Simple bar representation
                                        let maxHours = averageTimes.map { $0.averageHours }.max() ?? 1
                                        
                                        VStack(spacing: 8) {
                                            ForEach(averageTimes) { item in
                                                HStack {
                                                    Text(item.status)
                                                        .font(.subheadline)
                                                        .frame(width: 80, alignment: .leading)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(statusColor(item.status))
                                                        .frame(width: CGFloat(item.averageHours) / CGFloat(maxHours) * 200, height: 20)
                                                    
                                                    Text(item.formattedTime)
                                                        .font(.subheadline)
                                                }
                                            }
                                        }
                                        .frame(height: 250)
                                        .padding()
                                    }
                                    
                                    // Table View
                                    VStack(alignment: .leading) {
                                        ForEach(averageTimes) { item in
                                            HStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(statusColor(item.status))
                                                    .frame(width: 20, height: 20)
                                                
                                                Text(item.status)
                                                    .font(.subheadline)
                                                
                                                Spacer()
                                                
                                                Text(item.formattedTime)
                                                    .font(.subheadline)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom)
                                }
                                .padding(8)
                            }
                            .chartAccessibility(
                                label: "Average Time in Status",
                                summary: "Showing average time spent in each status",
                                items: averageTimes,
                                nameKeyPath: \.status,
                                valueKeyPath: \.formattedTime
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Card Activity Chart (Simple line chart of scans per day)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Activity")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ZStack {
                            // Background Card
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 4)
                            
                            if records.isEmpty {
                                Text("No data available")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                VStack {
                                    Text("Activity Overview")
                                        .font(.headline)
                                        .padding(.top, 8)
                                    
                                    if #available(iOS 16.0, *) {
                                        let activityData = getActivityData()
                                        
                                        Chart(activityData) { dataPoint in
                                            LineMark(
                                                x: .value("Date", dataPoint.date),
                                                y: .value("Count", dataPoint.count)
                                            )
                                            .foregroundStyle(Color.blue)
                                            
                                            PointMark(
                                                x: .value("Date", dataPoint.date),
                                                y: .value("Count", dataPoint.count)
                                            )
                                            .foregroundStyle(Color.blue)
                                        }
                                        .chartYScale(domain: 0...max(5, (activityData.map { $0.count }.max() ?? 0) + 1))
                                        .chartXAxis {
                                            AxisMarks(values: .automatic(desiredCount: 5))
                                        }
                                        .frame(height: 200)
                                    } else {
                                        Text("Activity chart requires iOS 16+")
                                            .foregroundColor(.gray)
                                            .padding()
                                    }
                                    
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Total Scans")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text("\(records.count)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .leading) {
                                            Text("Unique Cards")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text("\(Set(records.map { $0.cardNumber }).count)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .leading) {
                                            Text("Most Active Status")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            if let mostActiveStatus = statusCounts.max(by: { $0.count < $1.count })?.status {
                                                Text(mostActiveStatus)
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                            } else {
                                                Text("None")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                            }
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistics")
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 43/255, green: 62/255, blue: 80/255),
                        Color(red: 25/255, green: 38/255, blue: 55/255)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onAppear {
                loadData()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func loadData() {
        guard let orgID = sessionManager.user?.organizationID else {
            alertMessage = "User organization not found"
            showAlert = true
            return
        }
        
        isLoading = true
        FirestoreManager.shared.fetchRecords(field: "all", value: "", organizationID: orgID) { result in
            isLoading = false
            
            switch result {
            case .success(let fetchedRecords):
                self.records = fetchedRecords
                
                // Filter by timeframe
                let filteredRecords = filterRecordsByTimeFrame(fetchedRecords)
                
                // Calculate status distribution
                calculateStatusDistribution(filteredRecords)
                
                // Calculate average time in status
                calculateAverageTimeInStatus(fetchedRecords)
                
            case .failure(let error):
                alertMessage = "Error loading data: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    func filterRecordsByTimeFrame(_ records: [FirestoreRecord]) -> [FirestoreRecord] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeFrame {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            return records.filter { calendar.isDate($0.timestamp, inSameDayAs: startOfDay) }
            
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return records.filter { $0.timestamp >= startOfWeek }
            
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            return records.filter { $0.timestamp >= startOfMonth }
            
        case .all:
            return records
        }
    }
    
    func calculateStatusDistribution(_ records: [FirestoreRecord]) {
        // Group records by card number
        let cardGroups = Dictionary(grouping: records, by: { $0.cardNumber })
        
        // Get the latest status for each card
        var latestRecords: [FirestoreRecord] = []
        for (_, cardRecords) in cardGroups {
            if let latestRecord = cardRecords.sorted(by: { $0.timestamp > $1.timestamp }).first {
                latestRecords.append(latestRecord)
            }
        }
        
        // Count by status
        let statusGroups = Dictionary(grouping: latestRecords, by: { $0.status.lowercased() })
        let counts = statusGroups.mapValues { $0.count }
        
        totalCards = latestRecords.count
        
        // Create the status counts array
        statusCounts = counts.map { status, count in
            let percentage = totalCards > 0 ? (Double(count) / Double(totalCards) * 100.0) : 0
            return StatusCount(status: status.capitalized, count: count, percentage: percentage)
        }.sorted { $0.count > $1.count }
    }
    
    func calculateAverageTimeInStatus(_ records: [FirestoreRecord]) {
        // Group records by card number
        let cardGroups = Dictionary(grouping: records, by: { $0.cardNumber })
        
        // Track time spent in each status
        var statusDurations: [String: [TimeInterval]] = [:]
        
        for (_, cardRecords) in cardGroups {
            // Sort by timestamp (oldest first)
            let sortedRecords = cardRecords.sorted(by: { $0.timestamp < $1.timestamp })
            
            // Process transitions
            for i in 0..<sortedRecords.count-1 {
                let currentRecord = sortedRecords[i]
                let nextRecord = sortedRecords[i+1]
                
                let duration = nextRecord.timestamp.timeIntervalSince(currentRecord.timestamp)
                let status = currentRecord.status.lowercased()
                
                if duration > 0 {
                    if statusDurations[status] == nil {
                        statusDurations[status] = []
                    }
                    statusDurations[status]?.append(duration)
                }
            }
            
            // For the last record, calculate time from then to now (if it's recent enough)
            if let lastRecord = sortedRecords.last {
                let now = Date()
                let duration = now.timeIntervalSince(lastRecord.timestamp)
                let status = lastRecord.status.lowercased()
                
                // Only include if it's less than 30 days to avoid skewing data
                if duration > 0 && duration < (30 * 24 * 60 * 60) {
                    if statusDurations[status] == nil {
                        statusDurations[status] = []
                    }
                    statusDurations[status]?.append(duration)
                }
            }
        }
        
        // Calculate averages
        averageTimes = statusDurations.compactMap { status, durations in
            guard !durations.isEmpty else { return nil }
            let totalSeconds = durations.reduce(0, +)
            let averageSeconds = totalSeconds / Double(durations.count)
            let averageHours = averageSeconds / 3600.0 // Convert to hours
            
            return StatusTime(status: status.capitalized, averageHours: averageHours)
        }.sorted { $0.averageHours > $1.averageHours }
    }
    
    // For activity chart
    struct ActivityData: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }
    
    func getActivityData() -> [ActivityData] {
        let calendar = Calendar.current
        let now = Date()
        
        // Determine date range based on timeframe
        var startDate: Date
        var dateComponents: Calendar.Component
        
        switch selectedTimeFrame {
        case .day:
            // For day view, show hourly data
            startDate = calendar.startOfDay(for: now)
            dateComponents = .hour
        case .week:
            // For week view, show daily data
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            dateComponents = .day
        case .month:
            // For month view, show daily data
            startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
            dateComponents = .day
        case .all:
            // For all time view, show monthly data for the last year
            startDate = calendar.date(byAdding: .month, value: -11, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
            dateComponents = .month
        }
        
        // Group records by the appropriate date component
        var dateCounts: [Date: Int] = [:]
        
        for record in records {
            if record.timestamp >= startDate {
                var dateValue: Date
                
                switch dateComponents {
                case .hour:
                    let components = calendar.dateComponents([.year, .month, .day, .hour], from: record.timestamp)
                    dateValue = calendar.date(from: components)!
                case .day:
                    dateValue = calendar.startOfDay(for: record.timestamp)
                case .month:
                    let components = calendar.dateComponents([.year, .month], from: record.timestamp)
                    dateValue = calendar.date(from: components)!
                default:
                    dateValue = record.timestamp
                }
                
                dateCounts[dateValue, default: 0] += 1
            }
        }
        
        // Generate complete date range
        var result: [ActivityData] = []
        var current = startDate
        
        while current <= now {
            let count = dateCounts[current, default: 0]
            result.append(ActivityData(date: current, count: count))
            
            // Move to next interval
            switch dateComponents {
            case .hour:
                current = calendar.date(byAdding: .hour, value: 1, to: current)!
            case .day:
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            case .month:
                current = calendar.date(byAdding: .month, value: 1, to: current)!
            default:
                break
            }
        }
        
        return result
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView().environmentObject(SessionManager())
    }
}