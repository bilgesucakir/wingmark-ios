import CoreLocation
import MapKit
import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D?
    @State private var isMoving = false
    @State private var placeName: String?
    @State private var locating = false
    @State private var locationError: String?
    @State private var locationIssue: PermissionIssue?
    @State private var locateFailed = false
    private let hasInitial: Bool

    init(initial: CLLocationCoordinate2D?, onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onPick = onPick
        hasInitial = initial != nil
        _center = State(initialValue: initial)
        _position = State(initialValue: initial.map {
            .region(MKCoordinateRegion(center: $0, latitudinalMeters: 800, longitudinalMeters: 800))
        } ?? .automatic)
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapControls {
                MapCompass()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.region.center
                isMoving = true
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                center = context.region.center
                isMoving = false
            }
            .overlay { CenterPin(isLifted: isMoving).allowsHitTesting(false) }
            .safeAreaInset(edge: .bottom) { bottomCard }
            .permissionAlert($locationIssue)
            .alert("Couldn't find your location", isPresented: $locateFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Move the map to the spot, or try again.")
            }
            .navigationTitle("Sighting Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .task {
                await LocationService.requestAccessIfNeeded()
                if !hasInitial { await locate() }
            }
            .task(id: roundedCenter) { await lookUpPlaceName() }
        }
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    if locating {
                        Label("Finding your location…", systemImage: "location")
                            .foregroundStyle(.secondary)
                    } else if let locationError {
                        Text(locationError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(placeName ?? String(localized: "Move the map to place the pin", bundle: .app))
                            .font(.headline)
                            .lineLimit(2)
                        if let center {
                            Text(center.formattedCoordinates)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button {
                    Task { await locate() }
                } label: {
                    Image(systemName: "location.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(locating)
                .accessibilityLabel(Text("Use Current Location"))
            }
            Button {
                if let center { onPick(center) }
                dismiss()
            } label: {
                Text("Use This Location").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(center == nil || isMoving)
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var roundedCenter: String? {
        guard !isMoving, let center else { return nil }
        return String(format: "%.4f,%.4f", center.latitude, center.longitude)
    }

    private func locate() async {
        locating = true
        locationError = nil
        defer { locating = false }
        do throws(LocationError) {
            let location = try await LocationService.currentLocation()
            withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .default) {
                position = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
            }
            center = location.coordinate
        } catch {
            if error == .denied {
                let restricted = CLLocationManager().authorizationStatus == .restricted
                locationIssue = PermissionIssue(kind: .location, state: restricted ? .restricted : .notAllowed)
            } else {
                locateFailed = true
            }
            locationError = error == .denied
                ? String(localized: "Location access is off. Allow it in Settings or move the map to the spot.", bundle: .app)
                : String(localized: "Couldn't find your location. Move the map to the spot.", bundle: .app)
        }
    }

    private func lookUpPlaceName() async {
        guard let center, !isMoving else { return }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        placeName = await LocationService.placeName(for: center)
    }
}

struct CenterPin: View {
    let isLifted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.25))
                .frame(width: isLifted ? 14 : 10, height: 5)
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(.tint)
                        .frame(width: 44, height: 44)
                    Image(systemName: "bird.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Rectangle()
                    .fill(.tint)
                    .frame(width: 3, height: 14)
            }
            .offset(y: isLifted ? -38 : -29)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isLifted)
        .accessibilityHidden(true)
    }
}

extension CLLocationCoordinate2D {
    var formattedCoordinates: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}
