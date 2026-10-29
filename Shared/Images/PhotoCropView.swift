import SwiftUI

/// Crop with a free frame: drag the corners or edges to resize it, drag inside to move it.
struct PhotoCropView: View {
    let image: UIImage
    let onDone: (CGRect) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rect: CGRect
    @State private var drag: (handle: CropHandle, start: CGRect)?

    init(image: UIImage, initial: CGRect = CropGeometry.full, onDone: @escaping (CGRect) -> Void) {
        self.image = image
        self.onDone = onDone
        _rect = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let size = fittedSize(in: proxy.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                    CropFrame(rect: rect, size: size)
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture(in: size))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Crop area"))
                .accessibilityAction(named: Text("Trim left")) { trim(.left, by: 0.05) }
                .accessibilityAction(named: Text("Trim right")) { trim(.right, by: -0.05) }
                .accessibilityAction(named: Text("Trim top")) { trim(.top, by: 0.05) }
                .accessibilityAction(named: Text("Trim bottom")) { trim(.bottom, by: -0.05) }
            }
            .padding(16)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Reset") { rect = CropGeometry.full }
                        .disabled(CropGeometry.isFull(rect))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(rect)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func fittedSize(in available: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0, available.width > 0, available.height > 0 else { return .zero }
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if drag == nil {
                    let frame = CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
                    guard let handle = CropGeometry.hitTest(value.startLocation, rect: frame) else { return }
                    drag = (handle, rect)
                }
                guard let drag, size.width > 0, size.height > 0 else { return }
                let delta = CGSize(width: value.translation.width / size.width, height: value.translation.height / size.height)
                rect = CropGeometry.drag(drag.handle, from: drag.start, by: delta)
            }
            .onEnded { _ in drag = nil }
    }

    /// For VoiceOver and Switch Control, which can't drag the frame.
    private func trim(_ handle: CropHandle, by amount: CGFloat) {
        let delta = (handle == .left || handle == .right) ? CGSize(width: amount, height: 0) : CGSize(width: 0, height: amount)
        rect = CropGeometry.drag(handle, from: rect, by: delta)
    }
}

/// The dimmed outside, the frame, a thirds grid and the grab handles.
private struct CropFrame: View {
    let rect: CGRect
    let size: CGSize

    private var frame: CGRect {
        CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
    }

    var body: some View {
        ZStack {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRect(frame)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            Path { path in
                for fraction in [1.0 / 3, 2.0 / 3] {
                    path.move(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.minY))
                    path.addLine(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY))
                    path.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * fraction))
                    path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * fraction))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)

            Path { path in path.addRect(frame) }
                .stroke(Color.white, lineWidth: 1)

            Path { path in
                let length: CGFloat = min(24, frame.width / 2, frame.height / 2)
                for (corner, dx, dy) in [
                    (CGPoint(x: frame.minX, y: frame.minY), 1.0, 1.0), (CGPoint(x: frame.maxX, y: frame.minY), -1.0, 1.0),
                    (CGPoint(x: frame.minX, y: frame.maxY), 1.0, -1.0), (CGPoint(x: frame.maxX, y: frame.maxY), -1.0, -1.0),
                ] {
                    path.move(to: CGPoint(x: corner.x + dx * length, y: corner.y))
                    path.addLine(to: corner)
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * length))
                }
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .square, lineJoin: .miter))

            ForEach([CGPoint(x: frame.midX, y: frame.minY), CGPoint(x: frame.midX, y: frame.maxY)], id: \.y) { point in
                Capsule().fill(.white).frame(width: 28, height: 4).position(point)
            }
            ForEach([CGPoint(x: frame.minX, y: frame.midY), CGPoint(x: frame.maxX, y: frame.midY)], id: \.x) { point in
                Capsule().fill(.white).frame(width: 4, height: 28).position(point)
            }
        }
        .allowsHitTesting(false)
    }
}
