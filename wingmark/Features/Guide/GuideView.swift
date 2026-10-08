import SwiftUI

struct GuideView: View {
    @Environment(AuthSession.self) private var session
    @State private var search: SpeciesSearch?
    @State private var path: [DiaryRoute] = []
    /// Set when the Guide is shown before sign-in, in a sheet that needs a way out.
    var onClose: (() -> Void)?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let search {
                    GuideList(search: search)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Guide")
            .sightingDestinations(path: $path)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", role: .close, action: onClose)
                    }
                }
            }
        }
        .onAppear { if search == nil { search = SpeciesSearch(client: session.client) } }
    }
}

/// The Guide for someone who isn't signed in: species, photos and sounds are public. It has no diary of its own.
struct GuestGuideView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var diary: DiaryStore?

    var body: some View {
        Group {
            if let diary {
                GuideView(onClose: { dismiss() })
                    .environment(diary)
            }
        }
        .onAppear { if diary == nil { diary = DiaryStore(session: session) } }
    }
}

private struct GuideList: View {
    @Bindable var search: SpeciesSearch

    var body: some View {
        List {
            ForEach(search.results) { species in
                NavigationLink(value: DiaryRoute.species(species)) {
                    SpeciesRow(species: species)
                }
                .task { await search.loadMoreIfNeeded(after: species) }
            }
            if search.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.plain)
        .overlay {
            if search.results.isEmpty && !search.isLoading {
                if let error = search.error {
                    ContentUnavailableView {
                        Label("Couldn't load species", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error.userMessage)
                    } actions: {
                        Button("Try Again") { Task { await search.reload() } }
                    }
                } else if search.hasLoaded {
                    ContentUnavailableView.search(text: search.query)
                }
            }
        }
        .searchable(text: $search.query, prompt: Text("Search species"))
        .toolbar {
            Menu {
                Picker("Sort", selection: $search.sort) {
                    ForEach(SpeciesSort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        .refreshable { await search.reload() }
        .task { await search.loadIfNeeded() }
    }
}

struct SpeciesRow: View {
    let species: Species

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(path: species.images?.first.map { $0.thumbnailUrl ?? $0.imageUrl })
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(species.name)
                    .font(.headline)
                if let scientific = species.scientificName {
                    Text(scientific)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
