import SwiftUI

/// Life stage and gender labels for a photo; unknown values are left out.
struct TraitChips: View {
    var lifeStage: LifeStage?
    var gender: Gender?
    var caption: String?

    private var labels: [String] {
        [
            lifeStage.flatMap { $0 == .unknown ? nil : $0.title },
            gender.flatMap { $0 == .unknown ? nil : $0.title },
            caption?.trimmingCharacters(in: .whitespaces),
        ].compactMap { $0 }.filter { !$0.isEmpty }
    }

    var isEmpty: Bool { labels.isEmpty }

    var body: some View {
        if !labels.isEmpty {
            HStack(spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: .capsule)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

extension View {
    func traitChips(lifeStage: LifeStage?, gender: Gender?, caption: String? = nil) -> some View {
        overlay(alignment: .bottomLeading) {
            TraitChips(lifeStage: lifeStage, gender: gender, caption: caption)
                .padding(8)
        }
    }
}

extension SpeciesImage {
    var lifeStageValue: LifeStage? { lifeStage.flatMap(LifeStage.init(rawValue:)) }
    /// `NOT_APPLICABLE` maps to nil.
    var genderValue: Gender? { gender.flatMap(Gender.init(rawValue:)) }
}

extension BirdLog {
    /// "Adult · Female", or nil when both are unknown.
    var traitsSummary: String? {
        let parts = [lifeStage == .unknown ? nil : lifeStage.title, gender == .unknown ? nil : gender.title].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
