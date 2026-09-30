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
                    SpeciesImageCarousel(images: images)
                        .listRowInsets(EdgeInsets())
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
                fact("Size", species.sizeDescription, convertLengths: true)
                fact("Conservation Status", species.conservationStatus)
                fact("Native Range", species.nativeRange)
            }

            soundsSection
            sightingsSection
        }
        .navigationTitle(species.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .task(id: diary.revision) { await loadMySightings() }
        .onDisappear { player.stop() }
    }

    @ViewBuilder
    private func fact(_ title: LocalizedStringKey, _ text: LocalizedText?, convertLengths: Bool = false) -> some View {
        if let raw = text?.resolved() {
            let value = convertLengths ? session.unitPreference.convertingLengths(in: raw) : raw
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

    var body: some View {
        TabView {
            ForEach(images) { image in
                RemoteImage(path: image.imageUrl)
                    .traitChips(lifeStage: image.lifeStageValue, gender: image.genderValue, caption: image.caption)
                    .clipped()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
        .frame(height: 260)
    }
}

private struct RecordingRow: View {
    let recording: SpeciesRecording
    let player: RecordingPlayer

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
                HStack(spacing: 8) {
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

@Observable
final class RecordingPlayer {
    private(set) var currentId: String?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var failed = false

    private var player: AVPlayer?
    private var observers: [NSObjectProtocol] = []
    private var statusObservation: NSKeyValueObservation?

    func toggle(_ recording: SpeciesRecording) {
        if currentId == recording.id, let player {
            if isPlaying { player.pause() } else { player.play() }
            isPlaying.toggle()
            return
        }
        play(recording)
    }

    func stop() {
        player?.pause()
        player = nil
        currentId = nil
        isPlaying = false
        isBuffering = false
        statusObservation = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    private func play(_ recording: SpeciesRecording) {
        stop()
        guard let url = URL(string: recording.recordingUrl) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        currentId = recording.id
        failed = false
        isBuffering = true
        isPlaying = true

        statusObservation = item.observe(\.status) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor in
                guard let self, self.player === player else { return }
                self.isBuffering = false
                if status == .failed {
                    self.failed = true
                    self.isPlaying = false
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
        player.play()
    }
}
