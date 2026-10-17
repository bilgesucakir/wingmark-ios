# Wingmark

Log the birds you see on a map, learn what they are, and collect badges along the way.

Wingmark is an iPhone app for bird watchers. Drop a pin where you saw a bird, add a photo and a few details, and your sightings build up into a diary and a map of your own. A built-in guide helps you work out what you saw. It is available in English and Turkish.

<!--
Screenshots: edit this file on GitHub, drag each image in, and copy the link GitHub inserts.
Then paste the links into this template (two rows of four) and delete this comment.

<p align="center">
  <img src="LINK-map" width="23%" alt="The map with sighting photos as pins">
  <img src="LINK-guide" width="23%" alt="A species page in the guide">
  <img src="LINK-diary" width="23%" alt="The sightings diary">
  <img src="LINK-badges" width="23%" alt="Badges and progress">
</p>
<p align="center">
  <img src="LINK-map-sheet" width="23%" alt="Sightings that share a spot on the map">
  <img src="LINK-new-sighting" width="23%" alt="Logging a new sighting">
  <img src="LINK-widgets" width="23%" alt="Home Screen widgets">
  <img src="LINK-bird-of-the-day" width="23%" alt="The Bird of the day widget">
</p>
-->

## What it does

- **Map:** every sighting is a pin with your photo. Pins that share a spot group together, and you can filter by identification, gender and life stage.
- **Log a sighting:** take or pick a photo, choose the species (or say you don't know it yet), mark it as a guess or a confident ID, and set the place with your current location or by moving the pin.
- **Diary:** your sightings as a list, newest first, with filters.
- **Guide:** species pages with photos and credits, family and order, where the bird lives, and recordings of its calls from xeno-canto.
- **Badges:** 29 badges in bronze, silver and gold that track what you have logged.
- **Widgets:** Bird of the day, your latest sighting, and badge progress on the Home Screen.
- **Yours to keep:** download all your data as a JSON file, or delete your account from inside the app.
- **Made for iOS 26:** Liquid Glass, dark mode, Dynamic Type, VoiceOver, English and Turkish.

## Under the hood

| | |
|---|---|
| Language and UI | Swift 6, SwiftUI |
| Platform | iPhone, iOS 26.5 and later |
| Frameworks | MapKit, WidgetKit, CoreLocation, PhotosUI |
| Backend | [wingmark-backend](https://github.com/bilgesucakir/wingmark-backend), a Java service that holds accounts, sightings, badges and the species catalog |
| Tests | Swift Testing, in `wingmarkTests` |

The app has no third-party dependencies. It talks to the backend over HTTPS and keeps its tokens in the Keychain.

```
wingmark/            the app
  App/               entry point, root view, language and appearance
  Core/              networking, auth, models, images, location, widgets sync
  Features/          Map, Diary, Guide, Badges, Profile, Home
  Resources/         assets, string catalog (English and Turkish), privacy manifest
wingmarkWidgets/     the widget extension
Shared/              code shared by the app and the widgets
wingmarkTests/       unit tests
```

## Run it

1. Open `wingmark.xcodeproj` in Xcode 26 or later.
2. In *Signing & Capabilities*, choose your own team for the `wingmark` and `wingmarkWidgets` targets.
3. Pick an iPhone or a simulator and press Run.

The backend address is the `WINGMARK_API_BASE_URL` build setting. It points at the hosted service by default, so the app works as soon as it runs. To use a local backend, change it there.

To run the tests, press Cmd+U, or:

```
xcodebuild test -project wingmark.xcodeproj -scheme wingmark \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## More

- Website, privacy policy and support: [wingmarkapp.com](https://wingmarkapp.com)
- Backend and API reference: [wingmark-backend](https://github.com/bilgesucakir/wingmark-backend)

## Credits

Species photos come from Wikimedia Commons and are credited on each species page. Bird recordings come from [xeno-canto](https://xeno-canto.org) and keep their recordists' names and licenses.
