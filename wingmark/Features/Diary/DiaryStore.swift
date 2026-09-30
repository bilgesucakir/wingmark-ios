import Foundation
import Observation

@Observable
final class DiaryStore {
    private(set) var logs: [BirdLog] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var loadError: APIError?
    /// Bumped after every create/update/delete so other tabs (map, badges) know to refresh.
    private(set) var revision = 0

    var filter = DiaryFilter() {
        didSet { if filter != oldValue { Task { await load() } } }
    }

    private let session: AuthSession
    private var loadGeneration = 0
    /// Every log seen by any screen (diary, map), so detail/edit work outside the current filter.
    private var known: [UUID: BirdLog] = [:]

    init(session: AuthSession) {
        self.session = session
    }

    func log(id: UUID) -> BirdLog? {
        logs.first { $0.id == id } ?? known[id]
    }

    func remember(_ logs: some Sequence<BirdLog>) {
        for log in logs { known[log.id] = log }
    }

    func load() async {
        guard let userId = session.userId else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }
        do throws(APIError) {
            let result = try await session.client.send(BirdLogAPI.userLogs(userId: userId, filter: filter))
            guard generation == loadGeneration else { return }
            logs = result
            remember(result)
            loadError = nil
            hasLoaded = true
        } catch {
            guard generation == loadGeneration, !error.isCancellation else { return }
            loadError = error
        }
    }

    /// Uploads a new photo first if there is one, then creates or updates the log.
    func save(_ input: BirdLogInput, editing existing: BirdLog?, newPhoto: ProcessedPhoto?) async throws(APIError) -> BirdLog {
        var input = input
        if let newPhoto {
            input.photoUrl = try await session.client.send(UploadAPI.photo(jpeg: newPhoto.jpeg)).url
        }
        let saved: BirdLog
        if let existing {
            saved = try await session.client.send(BirdLogAPI.update(id: existing.id, input))
        } else {
            saved = try await session.client.send(BirdLogAPI.create(input))
        }
        upsert(saved)
        revision += 1
        return saved
    }

    func delete(_ log: BirdLog) async throws(APIError) {
        do throws(APIError) {
            _ = try await session.client.send(BirdLogAPI.delete(id: log.id))
        } catch where error.code == .notFound {
            // Already gone on the server; drop it locally too.
        }
        logs.removeAll { $0.id == log.id }
        known[log.id] = nil
        revision += 1
    }

    func refresh(_ id: UUID) async {
        do throws(APIError) {
            upsert(try await session.client.send(BirdLogAPI.log(id: id)))
        } catch where error.code == .notFound {
            logs.removeAll { $0.id == id }
            known[id] = nil
        } catch {}
    }

    private func upsert(_ log: BirdLog) {
        known[log.id] = log
        logs.removeAll { $0.id == log.id }
        guard matchesFilter(log) else { return }
        logs.append(log)
        logs.sort { filter.newestFirst ? $0.observedAt > $1.observedAt : $0.observedAt < $1.observedAt }
    }

    private func matchesFilter(_ log: BirdLog) -> Bool {
        switch filter.identification {
        case .any: break
        case .identified: if log.speciesId == nil { return false }
        case .unidentified: if log.speciesId != nil { return false }
        }
        if let gender = filter.gender, log.gender != gender { return false }
        if let lifeStage = filter.lifeStage, log.lifeStage != lifeStage { return false }
        return true
    }
}
