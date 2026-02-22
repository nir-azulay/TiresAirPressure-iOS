import SwiftUI

struct SplashView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var isActive: Bool
    @State private var logoOpacity: Double = 1
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Image("LaunchImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.7)

            RadialGradient(
                colors: [
                    AppColors.background.opacity(0.2),
                    AppColors.background.opacity(0.5)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 48) {
                Text(L("app_name", comment: ""))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)

                if bleManager.connectionState == .scanning || bleManager.connectionState == .connecting {
                    VStack(spacing: 24) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                            .scaleEffect(1.5)

                        Text(L("connecting", comment: "Connecting"))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.6).delay(0.2)) {
                titleOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isActive = false
                }
            }
        }
    }
}
