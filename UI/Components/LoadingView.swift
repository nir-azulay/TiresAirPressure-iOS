import SwiftUI

/// A reusable loading view component with customizable appearance
struct LoadingView: View {
    let message: String
    let showBackground: Bool

    init(message: String = "Loading...", showBackground: Bool = true) {
        self.message = message
        self.showBackground = showBackground
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message.localized)
                .font(.headline)
                .foregroundColor(showBackground ? .white : .primary)
        }
        .padding(32)
        .background(backgroundView)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if showBackground {
            Color.black.opacity(0.8)
        } else {
            Color.clear
        }
    }
}

/// A full-screen loading overlay
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            LoadingView(message: message)
                        }
                }
            }
    }
}

extension View {
    /// Add a loading overlay to any view
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

#if DEBUG
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingView()
                .previewDisplayName("Default Loading")

            LoadingView(message: "Connecting to device...", showBackground: false)
                .previewDisplayName("Custom Message")

            VStack {
                Text("Sample Content")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue)
            .loadingOverlay(isLoading: true, message: "Saving settings...")
            .previewDisplayName("Loading Overlay")
        }
    }
}
#endif