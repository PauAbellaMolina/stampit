import SwiftUI

struct StampMenuView: View {
    @EnvironmentObject var captureManager: CaptureManager
    @EnvironmentObject var stampStore: StampStore

    var dismissAction: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                dismissAction?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    captureManager.startCapture()
                }
            }) {
                HStack(spacing: 8) {
                    Label("New Stamp", systemImage: "plus.viewfinder")
                    Text("|")
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Or use ⌘⇧2")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            if stampStore.stamps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "seal")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No stamps yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 80)
            } else {
                Divider()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(stampStore.stamps) { stamp in
                            StampThumbnailView(stamp: stamp)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
