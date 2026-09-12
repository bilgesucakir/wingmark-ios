import SwiftUI

/// Feather glyph (custom template asset) with a small plus badge — the "Add to Diary" tab icon.
struct AddToDiaryTabIcon: View {
    var body: some View {
        Label {
            Text("Diary")
        } icon: {
            Image("FeatherIcon")
                .renderingMode(.template)
        }
    }
}
