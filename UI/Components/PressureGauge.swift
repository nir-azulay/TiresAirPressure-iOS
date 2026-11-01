import SwiftUI

struct PressureGauge: View {
    let currentPressure: Double
    let targetPressure: Double?
    let maxPressure: Double
    let minPressure: Double

    private let lineWidth: CGFloat = 14
    private let innerLineWidth: CGFloat = 6

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
            // Outer 270° tick marks
            ForEach(0..<21, id: \.self) { tick in
                let isMajor = tick % 5 == 0
                Rectangle()
                    .fill(Double(tick) / 20.0 <= Double(currentProgress) ? AppColors.primary : Color.white.opacity(isMajor ? 0.35 : 0.15))
                    .frame(width: isMajor ? 2.5 : 1.5, height: isMajor ? 8 : 5)
                    .offset(y: -64)
                    .rotationEffect(.degrees(-135 + Double(tick) * 13.5))
            }

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))

            if targetPressure != nil {
                Circle()
                    .trim(from: 0, to: targetProgress * 0.75)
                    .stroke(
                        AppColors.primaryLight.opacity(0.45),
                        style: StrokeStyle(lineWidth: innerLineWidth, lineCap: .round)
                    )
                    .padding(10)
                    .rotationEffect(.degrees(135))
            }

            Circle()
                .trim(from: 0, to: currentProgress * 0.75)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [AppColors.inflateBlue, AppColors.primary]),
                        center: .center,
                        startAngle: .degrees(135),
                        endAngle: .degrees(405)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: AppColors.primary.opacity(0.5), radius: 6)
                .animation(.easeInOut(duration: 0.5), value: currentPressure)

            VStack(spacing: 4) {
                Text(String(format: "%.1f", currentPressure))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("PSI")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.primaryLight)

                if let target = targetPressure {
                    Text("Target: \(String(format: "%.1f", target))")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
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
