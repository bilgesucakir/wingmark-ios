import Foundation
import Observation

@Observable
final class SpeciesSearch {
    private(set) var results: [Species] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    private(set) var error: APIError?
    private(set) var hasLoaded = false

    var query = "" {
        didSet { if query != oldValue { scheduleReload(debounce: true) } }
    }

    var sort = SpeciesSort.commonAscending {
        didSet { if sort != oldValue { scheduleReload(debounce: false) } }
    }

    private let client: APIClient
    private var page = 0
    private var generation = 0
    private var reloadTask: Task<Void, Never>?

    init(client: APIClient) {
        self.client = client
    }

    func loadIfNeeded() async {
        if !hasLoaded { await reload() }
    }

    func reload() async {
        generation += 1
        page = 0
        hasMore = true
        results = []
        error = nil
        isLoading = false
        await loadMore()
    }

    func loadMoreIfNeeded(after species: Species) async {
        guard species.id == results.last?.id else { return }
        await loadMore()
    }

    private func scheduleReload(debounce: Bool) {
        reloadTask?.cancel()
        reloadTask = Task {
            if debounce { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        let generation = generation
        isLoading = true
        defer { if generation == self.generation { isLoading = false } }
        do throws(APIError) {
            let result = try await client.send(SpeciesAPI.list(
                search: query, page: page, sort: sort, language: AppLanguage.current.resolvedCode
            ))
            guard generation == self.generation else { return }
            let known = Set(results.map(\.id))
            results.append(contentsOf: result.content.filter { !known.contains($0.id) })
            hasMore = result.hasMore
            page += 1
            error = nil
            hasLoaded = true
        } catch {
            guard generation == self.generation, !error.isCancellation else { return }
            self.error = error
        }
    }
}
