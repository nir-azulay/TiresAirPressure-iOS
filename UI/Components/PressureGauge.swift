import SwiftUI

/// A circular pressure gauge view that displays current and target pressure
struct PressureGauge: View {
    let currentPressure: Double
    let targetPressure: Double?
    let maxPressure: Double
    let minPressure: Double

    private let lineWidth: CGFloat = 12
    private let gaugeSize: CGFloat = 200

    init(
        currentPressure: Double,
        targetPressure: Double? = nil,
        maxPressure: Double = 80.0,
        minPressure: Double = 0.0
    ) {
        self.currentPressure = currentPressure
        self.targetPressure = targetPressure
        self.maxPressure = maxPressure
        self.minPressure = minPressure
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
                .frame(width: gaugeSize, height: gaugeSize)

            // Target pressure arc (if available)
            if let target = targetPressure {
                Circle()
                    .trim(from: 0, to: targetPressureProgress)
                    .stroke(Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: gaugeSize, height: gaugeSize)
                    .rotationEffect(.degrees(-90))
            }

            // Current pressure arc
            Circle()
                .trim(from: 0, to: currentPressureProgress)
                .stroke(currentPressureColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: gaugeSize, height: gaugeSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: currentPressure)

            // Center content
            VStack(spacing: 8) {
                Text(String(format: "%.1f", currentPressure))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("PSI")
                    .font(.headline)
                    .foregroundColor(.secondary)

                if let target = targetPressure {
                    Text("Target: \(String(format: "%.1f", target))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Target indicator (if available)
            if let target = targetPressure {
                targetIndicator
                    .rotationEffect(.degrees(targetPressureAngle))
            }
        }
    }

    // MARK: - Computed Properties

    private var currentPressureProgress: CGFloat {
        let normalized = (currentPressure - minPressure) / (maxPressure - minPressure)
        return CGFloat(max(0, min(1, normalized)))
    }

    private var targetPressureProgress: CGFloat {
        guard let target = targetPressure else { return 0 }
        let normalized = (target - minPressure) / (maxPressure - minPressure)
        return CGFloat(max(0, min(1, normalized)))
    }

    private var targetPressureAngle: Double {
        return 360 * Double(targetPressureProgress) - 90
    }

    private var currentPressureColor: Color {
        guard let target = targetPressure else { return .blue }

        let difference = abs(currentPressure - target)
        if difference <= 1.0 {
            return .green
        } else if difference <= 3.0 {
            return .orange
        } else {
            return .red
        }
    }

    private var targetIndicator: some View {
        Rectangle()
            .fill(Color.orange)
            .frame(width: 3, height: lineWidth + 8)
            .offset(y: -gaugeSize/2 - 4)
    }
}

/// A compact horizontal pressure bar
struct PressureBar: View {
    let currentPressure: Double
    let targetPressure: Double?
    let maxPressure: Double
    let minPressure: Double

    private let barHeight: CGFloat = 20

    init(
        currentPressure: Double,
        targetPressure: Double? = nil,
        maxPressure: Double = 80.0,
        minPressure: Double = 0.0
    ) {
        self.currentPressure = currentPressure
        self.targetPressure = targetPressure
        self.maxPressure = maxPressure
        self.minPressure = minPressure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current: \(String(format: "%.1f", currentPressure)) PSI")
                    .font(.headline)
                Spacer()
                if let target = targetPressure {
                    Text("Target: \(String(format: "%.1f", target)) PSI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: barHeight)
                        .cornerRadius(barHeight / 2)

                    // Current pressure fill
                    Rectangle()
                        .fill(currentPressureColor)
                        .frame(width: geometry.size.width * currentPressureProgress, height: barHeight)
                        .cornerRadius(barHeight / 2)
                        .animation(.easeInOut(duration: 0.5), value: currentPressure)

                    // Target indicator
                    if let _ = targetPressure {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 3, height: barHeight + 8)
                            .cornerRadius(1.5)
                            .offset(x: geometry.size.width * targetPressureProgress - 1.5, y: 0)
                    }
                }
            }
            .frame(height: barHeight)
        }
    }

    // MARK: - Computed Properties

    private var currentPressureProgress: CGFloat {
        let normalized = (currentPressure - minPressure) / (maxPressure - minPressure)
        return CGFloat(max(0, min(1, normalized)))
    }

    private var targetPressureProgress: CGFloat {
        guard let target = targetPressure else { return 0 }
        let normalized = (target - minPressure) / (maxPressure - minPressure)
        return CGFloat(max(0, min(1, normalized)))
    }

    private var currentPressureColor: Color {
        guard let target = targetPressure else { return .blue }

        let difference = abs(currentPressure - target)
        if difference <= 1.0 {
            return .green
        } else if difference <= 3.0 {
            return .orange
        } else {
            return .red
        }
    }
}

#if DEBUG
struct PressureGauge_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PressureGauge(currentPressure: 28.5, targetPressure: 32.0)
                .previewDisplayName("Gauge with Target")
                .padding()

            PressureGauge(currentPressure: 32.0)
                .previewDisplayName("Gauge without Target")
                .padding()

            VStack(spacing: 20) {
                PressureBar(currentPressure: 28.5, targetPressure: 32.0)
                PressureBar(currentPressure: 32.0, targetPressure: 30.0)
                PressureBar(currentPressure: 35.0)
            }
            .padding()
            .previewDisplayName("Pressure Bars")
        }
    }
}
#endif