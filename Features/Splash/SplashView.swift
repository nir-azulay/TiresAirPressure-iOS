import SwiftUI

struct SplashView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var isActive: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("LaunchImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack {
                Spacer()

                if bleManager.connectionState == .scanning || bleManager.connectionState == .connecting {
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                            .scaleEffect(1.4)

                        Text(L("connecting", comment: "Connecting"))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.primary.opacity(0.6), lineWidth: 1)
                    )
                    .cornerRadius(14)
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isActive = false
                }
            }
        }
    }
}
