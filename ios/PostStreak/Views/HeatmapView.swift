import SwiftUI

struct HeatmapView: View {
    let days: [DayCount]
    private let rows = Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 3) {
                ForEach(paddedDays.indices, id: \.self) { index in
                    if let day = paddedDays[index] {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: day.count))
                            .frame(width: 11, height: 11)
                            .accessibilityLabel("\(day.date): \(day.count) posts")
                    } else {
                        Color.clear.frame(width: 11, height: 11)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var paddedDays: [DayCount?] {
        guard let first = days.first,
              let date = Self.dateFormatter.date(from: first.date) else { return days.map(Optional.some) }
        let weekday = Calendar(identifier: .iso8601).component(.weekday, from: date)
        let mondayOffset = (weekday + 5) % 7
        return Array(repeating: nil, count: mondayOffset) + days.map(Optional.some)
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: Color.secondary.opacity(0.16)
        case 1: Color.green.opacity(0.35)
        case 2: Color.green.opacity(0.6)
        case 3: Color.green.opacity(0.8)
        default: Color.green
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

