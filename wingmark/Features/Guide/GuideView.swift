import SwiftUI

struct GuideView: View {
    @Environment(AuthSession.self) private var session
    @Environment(AppRouter.self) private var router
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
        .onAppear { if search == nil { search = SpeciesSearch(client: session.client, canFilterBySeen: session.userId != nil) } }
        .onChange(of: router.pending, initial: true) { openPendingSpecies() }
    }

    /// Opens the species a widget pointed at.
    private func openPendingSpecies() {
        guard session.pendingConsents.isEmpty, case .species(let id)? = router.pending else { return }
        router.pending = nil
        Task {
            if let species = try? await session.client.send(SpeciesAPI.species(id: id)) {
                path = [.species(species)]
            }
        }
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
                    if search.query.isEmpty && search.filter.isActive {
                        ContentUnavailableView {
                            Label("No species match these filters", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text("Try choosing All in one of the filters.")
                        }
                    } else {
                        ContentUnavailableView.search(text: search.query)
                    }
                }
            }
        }

        .searchable(text: $search.query, prompt: Text("Search species"))
        .toolbar {
            GuideFilterMenu(search: search)
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

/// One filter button, like on the Badges page: its icon is filled while a filter is on. Seen, Order and Family each have
/// an All choice to remove that filter. Picking an order narrows the families, because the server answers with the families of that order.
private struct GuideFilterMenu: View {
    @Bindable var search: SpeciesSearch

    private var orderSelection: Binding<String?> {
        Binding(get: { search.filter.order }, set: { newValue in
            guard newValue != search.filter.order else { return }
            search.filter.order = newValue
            search.filter.family = nil
        })
    }

    private var familySelection: Binding<String?> {
        Binding(get: { search.filter.family }, set: { search.filter.family = $0 })
    }

    var body: some View {
        Menu {
            if search.canFilterBySeen {
                Picker("Seen", selection: $search.filter.seen) {
                    ForEach(SeenFilter.allCases) { Text($0.title).tag($0) }
                }
            }
            Menu("Order") {
                Picker("Order", selection: orderSelection) {
                    Text("All Orders").tag(String?.none)
                    ForEach(search.facets.orders.filter { $0.count > 0 || $0.value == search.filter.order }) { order in
                        Text("\(order.name) (\(order.count))").tag(Optional(order.value))
                    }
                }
            }
            Menu("Family") {
                Picker("Family", selection: familySelection) {
                    Text("All Families").tag(String?.none)
                    ForEach(search.facets.families.filter { $0.count > 0 || $0.value == search.filter.family }) { family in
                        Text("\(family.name) (\(family.count))").tag(Optional(family.value))
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: search.filter.isActive
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
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
