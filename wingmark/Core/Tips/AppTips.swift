import SwiftUI
import TipKit

// Strings go through `bundle: .app` so tips follow the in-app language, like the rest of the code-built text.

struct AddSightingTip: Tip {
    var title: Text { Text(String(localized: "Log a sighting", bundle: .app)) }
    var message: Text? { Text(String(localized: "Tap + to add a bird you've seen. A photo can fill in the place and time.", bundle: .app)) }
    var image: Image? { Image(systemName: "plus.circle") }
}

struct MapFiltersTip: Tip {
    var title: Text { Text(String(localized: "Filter your map", bundle: .app)) }
    var message: Text? { Text(String(localized: "Narrow the pins by identification, gender or life stage.", bundle: .app)) }
    var image: Image? { Image(systemName: "line.3.horizontal.decrease.circle") }
}

struct PhotoPrefillTip: Tip {
    var title: Text { Text(String(localized: "Start with a photo", bundle: .app)) }
    var message: Text? { Text(String(localized: "If the photo has a location and date, they fill in where and when you saw the bird.", bundle: .app)) }
    var image: Image? { Image(systemName: "photo.on.rectangle") }
}
