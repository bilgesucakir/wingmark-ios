import AVFoundation
import SwiftUI

struct SpeciesDetailView: View {
    @Environment(AuthSession.self) private var session
    @Environment(DiaryStore.self) private var diary

    @State private var species: Species
    @State private var recordings: [SpeciesRecording] = []
    @State private var recordingsState = LoadState.loading
    @State private var mySightings: [BirdLog] = []
    @State private var player = RecordingPlayer()
    @State private var shownImageId: UUID?

    private enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    init(species: Species) {
        _species = State(initialValue: species)
    }

    var body: some View {
        List {
            if let images = species.images, !images.isEmpty {
                Section {
                    SpeciesImageCarousel(images: images, speciesName: species.name, selection: $shownImageId)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    if let image = images.first(where: { $0.id == shownImageId }) ?? images.first {
                        PhotoCredit(image: image)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(species.name).font(.title2.bold())
                    if let scientific = species.scientificName {
                        Text(scientific).italic().foregroundStyle(.secondary)
                    }
                }
                if let family = species.family { LabeledContent("Family", value: family) }
                if let order = species.order { LabeledContent("Order", value: order) }
            }

            if let description = species.description?.resolved() {
                Section("About") { Text(description) }
            }

            Section {
                fact("Habitat", species.habitat)
                fact("Diet", species.diet)
                fact("Lifespan", species.lifespan)
                fact("Size", species.sizeDescription, convertUnits: true)
                fact("Conservation Status", species.conservationStatus)
                fact("Native Range", species.nativeRange)
            }

            soundsSection
            if session.userId != nil { sightingsSection }
        }
        .navigationTitle(species.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .task(id: diary.revision) { await loadMySightings() }
        .onDisappear { player.stop() }
    }

    @ViewBuilder
    private func fact(_ title: LocalizedStringKey, _ text: LocalizedText?, convertUnits: Bool = false) -> some View {
        if let raw = text?.resolved() {
            let value = convertUnits ? UnitPreference.device.convertingMeasurements(in: raw) : raw
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value)
            }
        }
    }

    @ViewBuilder
    private var soundsSection: some View {
        Section("Sounds") {
            switch recordingsState {
            case .loading:
                HStack { ProgressView(); Text("Loading sounds…") }
            case .failed(let message):
                Label(message, systemImage: "speaker.slash")
                    .foregroundStyle(.secondary)
            case .loaded where recordings.isEmpty:
                Text("No recordings available.").foregroundStyle(.secondary)
            case .loaded:
                ForEach(recordings) { recording in
                    RecordingRow(recording: recording, player: player)
                }
            }
        }
    }

    @ViewBuilder
    private var sightingsSection: some View {
        Section("Your Sightings") {
            if mySightings.isEmpty {
                Text("You haven't logged this species yet.").foregroundStyle(.secondary)
            } else {
                ForEach(mySightings) { log in
                    NavigationLink(value: DiaryRoute.detail(log.id)) {
                        SightingRow(log: log)
                    }
                }
            }
        }
    }

    private func load() async {
        if let fresh = try? await session.client.send(SpeciesAPI.species(id: species.id)) {
            species = fresh
        }
        await loadRecordings()
        await loadMySightings()
    }

    private func loadRecordings() async {
        recordingsState = .loading
        do throws(APIError) {
            recordings = try await session.client.send(SpeciesAPI.sounds(id: species.id))
            recordingsState = .loaded
        } catch {
            guard !error.isCancellation else { return }
            recordingsState = .failed(error.code == .externalServiceError
                ? String(localized: "Bird sounds are unavailable right now.", bundle: .app)
                : error.userMessage)
        }
    }

    private func loadMySightings() async {
        guard let userId = session.userId,
              let logs = try? await session.client.send(BirdLogAPI.userLogs(userId: userId, filter: DiaryFilter()))
        else { return }
        diary.remember(logs)
        mySightings = logs.filter { $0.speciesId == species.id }
    }
}

private struct SpeciesImageCarousel: View {
    let images: [SpeciesImage]
    let speciesName: String
    @Binding var selection: UUID?

    @State private var viewing: ViewerPhoto?

    var body: some View {
        TabView(selection: $selection) {
            ForEach(images) { image in
                // The photo fills this fixed-size frame and is cropped to it, so the chips sit inside the visible corner.
                Color.clear
                    .overlay { RemoteImage(path: image.imageUrl) }
                    .clipped()
                    .traitChips(lifeStage: image.lifeStageValue, gender: image.genderValue, caption: image.caption)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Photo of \(speciesName)"))
                    .accessibilityAddTraits([.isImage, .isButton])
                    .onTapGesture { viewing = ViewerPhoto(path: image.imageUrl) }
                    .tag(Optional(image.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
        .frame(height: 260)
        .fullScreenCover(item: $viewing) { PhotoViewer(photo: $0) }
    }
}

private struct RecordingRow: View {
    let recording: SpeciesRecording
    let player: RecordingPlayer

    @Environment(\.dynamicTypeSize) private var typeSize

    private var isCurrent: Bool { player.currentId == recording.id }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.toggle(recording)
            } label: {
                Group {
                    if isCurrent && player.isBuffering {
                        ProgressView()
                    } else {
                        Image(systemName: isCurrent && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel(Text(isCurrent && player.isPlaying ? "Pause" : "Play"))

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.type?.capitalized ?? String(localized: "Recording", bundle: .app))
                    .font(.headline)
                if let recordist = recording.recordist {
                    Text("Recorded by \(recordist)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                let details = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 8))
                details {
                    if let quality = recording.quality {
                        Text("Quality \(quality)")
                    }
                    if let license = recording.licenseUrl.flatMap(URL.init(string:)) {
                        Link("License", destination: license)
                    }
                    Text("xeno-canto")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        if isCurrent, player.failed {
            FieldError(message: String(localized: "Couldn't play this recording.", bundle: .app))
        }
    }
}

/// Creative Commons licenses require crediting the photographer, so licensed photos always show this line.
private struct PhotoCredit: View {
    let image: SpeciesImage

    var body: some View {
        if let credit = image.creditText {
            if let url = image.sourceUrl.flatMap(URL.init(string:)) {
                Link(destination: url) {
                    Text("Photo: \(credit)")
                }
                .font(.caption2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Photo: \(credit)")
                    .font(.caption2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@Observable
final class RecordingPlayer {
    private(set) var currentId: String?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var failed = false

    private var player: AVPlayer?
    private var observers: [NSObjectProtocol] = []
    private var statusObservation: NSKeyValueObservation?
    private var download: Task<Void, Never>?

    func toggle(_ recording: SpeciesRecording) {
        if currentId == recording.id, let player {
            if isPlaying { player.pause() } else { player.play() }
            isPlaying.toggle()
            return
        }
        play(recording)
    }

    func stop() {
        download?.cancel()
        download = nil
        tearDownPlayer()
        currentId = nil
        isPlaying = false
        isBuffering = false
    }

    private func play(_ recording: SpeciesRecording) {
        stop()
        guard let url = URL(string: recording.recordingUrl) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        currentId = recording.id
        failed = false
        isBuffering = true
        isPlaying = true
        start(url, recordingId: recording.id, canFallBack: true)
    }

    private func start(_ url: URL, recordingId: String, canFallBack: Bool) {
        tearDownPlayer()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        statusObservation = item.observe(\.status) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor in
                guard let self, self.player === player else { return }
                switch status {
                case .readyToPlay:
                    self.isBuffering = false
                case .failed where canFallBack:
                    self.playDownloaded(from: url, recordingId: recordingId)
                case .failed:
                    self.fail()
                default:
                    break
                }
            }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.player?.seek(to: .zero)
            }
        })
        if isPlaying { player.play() }
    }

    /// Xeno-canto ignores byte-range requests, which AVPlayer needs to stream WAV files (MP3 streams fine).
    private func playDownloaded(from url: URL, recordingId: String) {
        download = Task {
            do {
                let file = try await Self.cachedFile(for: url, recordingId: recordingId)
                guard !Task.isCancelled, currentId == recordingId else { return }
                start(file, recordingId: recordingId, canFallBack: false)
            } catch {
                guard !Task.isCancelled, currentId == recordingId else { return }
                fail()
            }
        }
    }

    private func fail() {
        isBuffering = false
        isPlaying = false
        failed = true
    }

    private func tearDownPlayer() {
        player?.pause()
        player = nil
        statusObservation = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    private static func cachedFile(for url: URL, recordingId: String) async throws -> URL {
        let directory = URL.cachesDirectory.appending(path: "recordings", directoryHint: .isDirectory)
        let fileManager = FileManager.default
        if let cached = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first(where: { $0.deletingPathExtension().lastPathComponent == recordingId }) {
            return cached
        }
        let (temporary, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        // AVPlayer picks the decoder from the file extension, which only the Content-Disposition name carries.
        let ext = response.suggestedFilename.map { ($0 as NSString).pathExtension }.flatMap { $0.isEmpty ? nil : $0 } ?? "wav"
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "\(recordingId).\(ext)")
        try? fileManager.removeItem(at: file)
        try fileManager.moveItem(at: temporary, to: file)
        return file
    }
}
