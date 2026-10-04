import MapKit
import SwiftUI
import TipKit

struct SightingsMapView: View {
    @Environment(MapStore.self) private var store
    @Environment(DiaryStore.self) private var diary

    @State private var path: [DiaryRoute] = []
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selected: BirdLog?
    // Ordered, so only one tip shows at a time: add a sighting first, then filters.
    @State private var tips = TipGroup(.ordered) {
        AddSightingTip()
        MapFiltersTip()
    }
    @State private var isLocating = false
    @State private var showLocationDenied = false
    @Environment(\.openURL) private var openURL

    private var clusters: [MapCluster] {
        guard let region = store.region else { return [] }
        return MapCluster.make(from: Array(store.logs.values), region: region)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Map(position: $position) {
                UserAnnotation()
                ForEach(clusters) { cluster in
                    Annotation("", coordinate: cluster.coordinate, anchor: .center) {
                        if cluster.logs.count == 1, let log = cluster.logs.first {
                            SightingPin(log: log, isSelected: selected?.id == log.id)
                                .onTapGesture { selected = log }
                                .accessibilityAction { selected = log }
                        } else {
                            ClusterPin(count: cluster.logs.count)
                                .onTapGesture { zoom(into: cluster) }
                                .accessibilityAction { zoom(into: cluster) }
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                store.regionDidChange(context.region)
            }
            .safeAreaInset(edge: .top) { overlayHeader }
            .overlay(alignment: .topTrailing) {
                Button(action: locate) {
                    Group {
                        if isLocating {
                            ProgressView()
                        } else {
                            Image(systemName: "location.fill")
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text("Show My Location"))
                .padding(.trailing, 16)
                .padding(.top, 64)
            }
            .alert("Location access is off", isPresented: $showLocationDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow Wingmark to use your location in Settings to see where you are on the map.")
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    AddSightingTip().invalidate(reason: .actionPerformed)
                    path.append(.add)
                } label: {
                    Label("Add Sighting", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .popoverTip(tips.currentTip as? AddSightingTip, arrowEdge: .bottom)
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selected) { log in
                SightingSummarySheet(log: log) {
                    selected = nil
                    path.append(.detail(log.id))
                }
                .presentationDetents([.height(220), .medium])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sightingDestinations(path: $path)
            .onChange(of: diary.revision) { store.reset() }
            .onAppear { store.reload() }
        }
    }

    private var overlayHeader: some View {
        VStack(spacing: 8) {
            MapFilterChips()
                .popoverTip(tips.currentTip as? MapFiltersTip, arrowEdge: .top)
                .onChange(of: store.filter.isActive) { _, isActive in
                    if isActive { MapFiltersTip().invalidate(reason: .actionPerformed) }
                }
            if store.isTruncated {
                Label("Zoom in to see all sightings", systemImage: "plus.magnifyingglass")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect()
            } else if let error = store.loadError {
                Button {
                    store.reload()
                } label: {
                    Label(error.userMessage, systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .glassEffect()
            }
        }
        .padding(.top, 4)
    }

    private func locate() {
        isLocating = true
        Task {
            defer { isLocating = false }
            do throws(LocationError) {
                let location = try await LocationService.currentLocation()
                withAnimation {
                    position = .region(MKCoordinateRegion(
                        center: location.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000
                    ))
                }
            } catch {
                if error == .denied { showLocationDenied = true }
            }
        }
    }

    private func zoom(into cluster: MapCluster) {
        let lats = cluster.logs.map(\.latitude)
        let lngs = cluster.logs.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLng = lngs.min(), let maxLng = lngs.max() else { return }
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.003),
            longitudeDelta: max((maxLng - minLng) * 1.6, 0.003)
        )
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        withAnimation { position = .region(MKCoordinateRegion(center: center, span: span)) }
    }
}

private struct MapFilterChips: View {
    @Environment(MapStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer {
                HStack(spacing: 8) {
                    chip(title: store.filter.identification == .any
                         ? String(localized: "Identification", bundle: .app) : store.filter.identification.title,
                         isActive: store.filter.identification != .any) {
                        Picker("Identification", selection: $store.filter.identification) {
                            ForEach(DiaryFilter.Identification.allCases) { Text($0.title).tag($0) }
                        }
                    }
                    chip(title: store.filter.gender?.title ?? String(localized: "Gender", bundle: .app),
                         isActive: store.filter.gender != nil) {
                        Picker("Gender", selection: $store.filter.gender) {
                            Text("Any Gender").tag(Gender?.none)
                            ForEach(Gender.allCases) { Text($0.title).tag(Gender?.some($0)) }
                        }
                    }
                    chip(title: store.filter.lifeStage?.title ?? String(localized: "Life Stage", bundle: .app),
                         isActive: store.filter.lifeStage != nil) {
                        Picker("Life Stage", selection: $store.filter.lifeStage) {
                            Text("Any Life Stage").tag(LifeStage?.none)
                            ForEach(LifeStage.allCases) { Text($0.title).tag(LifeStage?.some($0)) }
                        }
                    }
                    if store.filter.isActive {
                        Button("Clear", systemImage: "xmark") { store.filter = DiaryFilter() }
                            .labelStyle(.iconOnly)
                            .padding(8)
                            .glassEffect(.regular.interactive())
                            .accessibilityLabel(Text("Clear Filters"))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func chip(title: String, isActive: Bool, @ViewBuilder content: () -> some View) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(isActive ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .glassEffect(.regular.interactive())
    }
}

private struct SightingPin: View {
    let log: BirdLog
    let isSelected: Bool

    var body: some View {
        let size: CGFloat = isSelected ? 54 : 40
        RemoteImage(path: log.photoUrl)
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay { Circle().strokeBorder(.white, lineWidth: 2.5) }
            .overlay { if isSelected { Circle().strokeBorder(.tint, lineWidth: 2) } }
            .shadow(radius: 3, y: 1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.circle)
            .animation(.snappy, value: isSelected)
            .accessibilityElement()
            .accessibilityLabel(Text("\(log.displayName), seen \(log.observedAt, format: .dateTime.day().month())"))
            .accessibilityAddTraits(.isButton)
    }
}

private struct ClusterPin: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(minWidth: 40, minHeight: 40)
            .padding(.horizontal, 4)
            .background(Circle().fill(.tint))
            .overlay { Circle().strokeBorder(.white, lineWidth: 2.5) }
            .shadow(radius: 3, y: 1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.circle)
            .accessibilityLabel(Text("\(count) sightings"))
            .accessibilityHint(Text("Zooms in to show them"))
            .accessibilityAddTraits(.isButton)
    }
}

private struct SightingSummarySheet: View {
    let log: BirdLog
    let onShowDetails: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RemoteImage(path: log.photoUrl)
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(log.displayName)
                    .font(.headline)
                Text(log.observedAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let traits = log.traitsSummary {
                    Text(traits)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let place = log.locationName, !place.isEmpty {
                    Text(place)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let meters = UserLocation.shared.distance(to: log) {
                    Label(UnitPreference.device.distanceAway(meters: meters), systemImage: "location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("View Details", action: onShowDetails)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
