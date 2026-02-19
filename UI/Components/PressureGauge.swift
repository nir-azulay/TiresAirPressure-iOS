import SwiftUI

struct PressureGauge: View {
    let currentPressure: Double
    let targetPressure: Double?
    let maxPressure: Double
    let minPressure: Double

    private let lineWidth: CGFloat = 16
    private let innerLineWidth: CGFloat = 8

    init(
        currentPressure: Double,
        targetPressure: Double? = nil,
        maxPressure: Double = 40.0,
        minPressure: Double = 0.0
    ) {
        self.currentPressure = currentPressure
        self.targetPressure = targetPressure
        self.maxPressure = maxPressure
        self.minPressure = minPressure
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)

            if let target = targetPressure {
                Circle()
                    .trim(from: 0, to: targetProgress)
                    .stroke(
                        AppColors.primaryLight,
                        style: StrokeStyle(lineWidth: innerLineWidth, lineCap: .round)
                    )
                    .padding(4)
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .trim(from: 0, to: currentProgress)
                .stroke(
                    AppColors.primary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: currentPressure)

            VStack(spacing: 4) {
                Text(String(format: "%.1f", currentPressure))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("PSI")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))

                if let target = targetPressure {
                    Text("Target: \(String(format: "%.1f", target))")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    private var currentProgress: CGFloat {
        let normalized = (currentPressure - minPressure) / (maxPressure - minPressure)
        return CGFloat(max(0, min(1, normalized)))
    }

    private var targetProgress: CGFloat {
        guard let target = targetPressure else { return 0 }
        let normalized = (target - minPressure) / (maxPressure - minPressure)
        return CGFloat(max(0, min(1, normalized)))
    }
}

#if DEBUG
struct PressureGauge_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PressureGauge(currentPressure: 28.5, targetPressure: 32.0)
                .frame(width: 200, height: 200)
        }
    }
}
#endif
