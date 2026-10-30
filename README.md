<h1><img src="https://github.com/user-attachments/assets/5a4ede9a-e023-4959-b334-c39053ebf70c" width="60" height="60" 
      align="absmiddle">&nbsp;Wingmark</h1>


<p>
  <a href="https://apps.apple.com/us/app/wingmark/id6820532421"><img src="assets/app-store-badge.png" width="160" alt="Download on the App Store"></a>
</p>

Log the birds you see on a map, learn what they are, and collect badges along the way.

Wingmark is an iPhone app for bird watchers. Drop a pin where you saw a bird, add a photo and a few details, and your sightings build up into a diary and a map of your own. A built-in guide helps you work out what you saw. It is available in English and Turkish.

<p align="center">
  <img src="https://github.com/user-attachments/assets/a3f61dcc-7f4e-44ac-8553-52be0ffd0eca" width="23%" alt="The map with sighting photos as pins">
  <img src="https://github.com/user-attachments/assets/dcd85f30-1f5e-495c-99a0-d3f6603c5783" width="23%" alt="A species page in the guide">
  <img src="https://github.com/user-attachments/assets/84fbcb16-e760-404d-9061-4c8cbbebb90e" width="23%" alt="The sightings diary">
  <img src="https://github.com/user-attachments/assets/45f8044c-0658-421d-a8a5-ad3b271fd63d" width="23%" alt="Badges and progress">
</p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/aab89082-1be7-4895-9611-a3b5ad8d637b" width="23%" alt="Sightings that share a spot on the map">
  <img src="https://github.com/user-attachments/assets/4084f115-472e-4ed1-8caa-eb715d7a4819" width="23%" alt="Logging a new sighting">
  <img src="https://github.com/user-attachments/assets/97a36866-6dbf-4830-9b0c-3ceb1d74e47e" width="23%" alt="Home Screen widgets">
  <img src="https://github.com/user-attachments/assets/a558d54b-72db-40e0-accd-85e5bd30cf73" width="23%" alt="The Bird of the day widget">
</p>

## What it does

- **Map:** every sighting is a pin with your photo. Pins that share a spot group together, and you can filter by identification, gender and life stage.
- **Log a sighting:** take or pick a photo and crop it to any shape, choose the species (or say you don't know it yet), mark it as a guess or a confident ID, and set the place with your current location or by moving the pin.
- **Diary:** your sightings as a list, newest first, with filters.
- **Guide:** species pages with photos and credits, family and order, where the bird lives, and recordings of its calls from xeno-canto.
- **Badges:** 29 badges in bronze, silver and gold that track what you have logged.
- **Share a sighting:** the Share button on a sighting with a photo builds a card with your photo, the name, the date and the details, and opens the share sheet. No location is on the card.
- **Log from Photos:** pick a photo in Photos (or any app), tap Share and choose Wingmark. The crop screen opens first, then a small window with the same fields as the app's form saves it to your diary right away. The date and place come from the photo when it has them.
- **App icon:** choose a different Home Screen icon in Settings.
- **Profile:** tap your favorite species to open its page.
- **Rate Wingmark:** Apple's rating prompt after your 10th sighting, and a Rate Wingmark row in Settings.
- **Widgets:** Bird of the day, your latest sighting, and badge progress on the Home Screen, and Bird of the day on the Lock Screen.
- **Yours to keep:** download all your data as a JSON file, or delete your account from inside the app.
- **Made for iOS 26:** Liquid Glass, dark mode, Dynamic Type, VoiceOver, English and Turkish.

## Under the hood

| Area | Details |
|---|---|
| Language and UI | Swift 6, SwiftUI |
| Platform | iPhone, iOS 26.5 and later |
| Frameworks | MapKit, WidgetKit, CoreLocation, PhotosUI, StoreKit |
| Backend | [wingmark-backend](https://github.com/bilgesucakir/wingmark-backend), a Java service that holds accounts, sightings, badges and the species catalog |
| Tests | Swift Testing, in `wingmarkTests` |

The app has no third-party dependencies. It talks to the backend over HTTPS and keeps its login in the Keychain, in a group the Share Extension can read too.

```
wingmark/            the app
  App/               entry point, root view, appearance
  Core/              auth session, images, icons, sharing, rating prompt, widgets sync
  Features/          Map, Diary, Guide, Badges, Profile, Home
  Resources/         assets, string catalog (English and Turkish), privacy manifest
wingmarkWidgets/     the widget extension
wingmarkShare/       the Share Extension ("Log in Wingmark" from Photos)
Shared/              code shared by the app and the extensions: networking, models,
                     login storage, photo processing, location, permissions
wingmarkTests/       unit tests
```

## More

- Website, privacy policy and support: [wingmarkapp.com](https://wingmarkapp.com)
- Backend and API reference: [wingmark-backend](https://github.com/bilgesucakir/wingmark-backend)

## Credits

Species photos come from Wikimedia Commons and are credited on each species page. Bird recordings come from [xeno-canto](https://xeno-canto.org) and keep their recordists' names and licenses.
