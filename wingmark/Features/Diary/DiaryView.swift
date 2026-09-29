import SwiftUI

enum DiaryRoute: Hashable {
    case detail(UUID)
    case add
    case edit(UUID)
}

struct DiaryView: View {
    @Environment(DiaryStore.self) private var store
    @State private var path: [DiaryRoute] = []
    @State private var pendingDelete: BirdLog?
    @State private var deleteError: String?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Diary")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { filterMenu }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add Sighting", systemImage: "plus") { path.append(.add) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .navigationDestination(for: DiaryRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        SightingDetailView(logId: id, path: $path)
                    case .add:
                        SightingFormView(editing: nil) { _ in path.removeLast() }
                    case .edit(let id):
                        SightingFormView(editing: store.log(id: id)) { _ in path.removeLast() }
                    }
                }
                .refreshable { await store.load() }
                .task { if !store.hasLoaded { await store.load() } }
                .confirmationDialog(
                    "Delete this sighting?", isPresented: .init(
                        get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
                    ), titleVisibility: .visible, presenting: pendingDelete
                ) { log in
                    Button("Delete", role: .destructive) { delete(log) }
                } message: { _ in
                    Text("This can't be undone.")
                }
                .alert("Couldn't delete", isPresented: .init(
                    get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(deleteError ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.logs.isEmpty {
            if !store.hasLoaded, let error = store.loadError {
                ContentUnavailableView {
                    Label("Couldn't load your diary", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.userMessage)
                } actions: {
                    Button("Try Again") { Task { await store.load() } }
                }
            } else if !store.hasLoaded {
                ProgressView()
            } else if store.filter.isActive {
                ContentUnavailableView {
                    Label("No matching sightings", systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button("Clear Filters") { store.filter = DiaryFilter(newestFirst: store.filter.newestFirst) }
                }
            } else {
                ContentUnavailableView {
                    Label("No sightings yet", systemImage: "bird")
                } description: {
                    Text("Log your first bird to start your diary.")
                } actions: {
                    Button("Add Sighting") { path.append(.add) }
                        .buttonStyle(.borderedProminent)
                }
            }
        } else {
            List(store.logs) { log in
                NavigationLink(value: DiaryRoute.detail(log.id)) {
                    SightingRow(log: log)
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = log }
                }
            }
            .listStyle(.plain)
        }
    }

    private var filterMenu: some View {
        @Bindable var store = store
        return Menu {
            Picker("Sort", selection: $store.filter.newestFirst) {
                Text("Newest First").tag(true)
                Text("Oldest First").tag(false)
            }
            Picker("Identification", selection: $store.filter.identification) {
                ForEach(DiaryFilter.Identification.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Gender", selection: $store.filter.gender) {
                Text("Any Gender").tag(Gender?.none)
                ForEach(Gender.allCases) { Text($0.title).tag(Gender?.some($0)) }
            }
            .pickerStyle(.menu)
            Picker("Life Stage", selection: $store.filter.lifeStage) {
                Text("Any Life Stage").tag(LifeStage?.none)
                ForEach(LifeStage.allCases) { Text($0.title).tag(LifeStage?.some($0)) }
            }
            .pickerStyle(.menu)
            if store.filter.isActive {
                Button("Clear Filters", role: .destructive) {
                    store.filter = DiaryFilter(newestFirst: store.filter.newestFirst)
                }
            }
        } label: {
            Label("Filter", systemImage: store.filter.isActive
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private func delete(_ log: BirdLog) {
        Task {
            do throws(APIError) {
                try await store.delete(log)
            } catch {
                deleteError = error.userMessage
            }
        }
    }
}

struct SightingRow: View {
    let log: BirdLog

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(path: log.photoUrl)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(log.displayName)
                    .font(.headline)
                    .foregroundStyle(log.speciesId == nil && log.customName == nil ? .secondary : .primary)
                Text(log.observedAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let place = log.locationName, !place.isEmpty {
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
