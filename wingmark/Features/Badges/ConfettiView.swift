import SwiftUI

/// A short burst of falling confetti for a new badge. Drawn once per piece from a fixed seed, so it needs no state.
struct ConfettiView: View {
    private struct Piece {
        let x: Double, delay: Double, speed: Double, size: Double, spin: Double, sway: Double, color: Color
    }

    private static let duration = 3.6

    private let pieces: [Piece] = {
        var generator = SeededGenerator(seed: 7)
        let colors: [Color] = [.pink, .yellow, .cyan, .orange, .green, .purple, .mint]
        return (0..<70).map { _ in
            Piece(
                x: .random(in: 0...1, using: &generator), delay: .random(in: 0...0.7, using: &generator),
                speed: .random(in: 0.55...1, using: &generator), size: .random(in: 6...11, using: &generator),
                spin: .random(in: 2...7, using: &generator), sway: .random(in: 12...34, using: &generator),
                color: colors.randomElement(using: &generator)!
            )
        }
    }()

    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let progress = t * piece.speed / Self.duration * 1.6
                    guard progress < 1.1 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.x * 20) * piece.sway
                    let y = -20 + progress * (size.height + 40)
                    var layer = context
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(t * piece.spin))
                    layer.opacity = max(0, min(1, (1.1 - progress) * 4))
                    layer.fill(
                        Path(CGRect(x: -piece.size / 2, y: -piece.size / 3, width: piece.size, height: piece.size * 0.66)),
                        with: .color(piece.color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { start = .now }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
