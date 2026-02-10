import SwiftUI

struct ChartView: View {
    let data: [(label: String, value: Double)]
    let maxValue: Double
    let type: ConsumptionType
    
    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width / CGFloat(data.count) - 4
            let maxBarHeight = geometry.size.height - 40
            
            VStack(alignment: .leading, spacing: 10) {
                // Grafik çubukları
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 5) {
                            // Çubuk
                            Rectangle()
                                .fill(barColor(for: item.value))
                                .frame(
                                    width: barWidth,
                                    height: CGFloat(item.value / maxValue) * maxBarHeight
                                )
                                .cornerRadius(4)
                            
                            // Etiket
                            Text(item.label)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .frame(width: barWidth)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
                .frame(height: maxBarHeight)
                
                // Eksen etiketleri
                HStack {
                    Text("0")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(maxValue, specifier: "%.1f") \(type.unit)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func barColor(for value: Double) -> Color {
        let percentage = value / maxValue
        
        switch type {
        case .water:
            return Color.blue.opacity(0.5 + Double(percentage) * 0.5)
        case .electricity:
            return Color.yellow.opacity(0.5 + Double(percentage) * 0.5)
        case .cost:
            return Color.green.opacity(0.5 + Double(percentage) * 0.5)
        }
    }
}
