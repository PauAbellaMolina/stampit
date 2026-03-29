import SwiftUI

struct StampThumbnailView: View {
    let stamp: StampItem
    @EnvironmentObject var stampStore: StampStore

    @State private var isHovering = false
    @State private var showCopied = false

    var body: some View {
        Group {
            if let image = stampStore.loadImage(for: stamp) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isHovering ? Color.accentColor : Color.clear, lineWidth: 2)
                        )

                    if stamp.isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                            .padding(4)
                    }

                    if showCopied {
                        Text("Copied")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.75)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .onHover { hovering in
                    isHovering = hovering
                }
                .onTapGesture {
                    stampStore.copyToClipboard(stamp)
                    withAnimation(.easeIn(duration: 0.1)) {
                        showCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showCopied = false
                        }
                    }
                }
                .contextMenu {
                    Button(stamp.isStarred ? "Unstar" : "Star") {
                        stampStore.toggleStar(stamp)
                    }
                }
                .help("Click to copy · Right-click to star")
            }
        }
    }
}
