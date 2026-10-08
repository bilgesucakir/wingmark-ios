import SwiftUI

struct ViewerPhoto: Identifiable {
    let path: String
    var id: String { path }
}

/// The full photo on black, with a close button. Presented with `fullScreenCover(item:)`.
struct PhotoViewer: View {
    let photo: ViewerPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RemoteImage(path: photo.path, contentMode: .fit)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Close"))
            .padding(16)
        }
        .preferredColorScheme(.dark)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismiss() }
    }
}
