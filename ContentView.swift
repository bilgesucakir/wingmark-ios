//
//  ContentView.swift
//  wingmark
//
//  Created by Bilgesu Çakır on 12.09.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BirdSighting.date, order: .reverse) private var sightings: [BirdSighting]
    @State private var showingAddSighting = false

    var body: some View {
        NavigationViewWrapper {
            List {
                ForEach(sightings) { sighting in
                    NavigationLink {
                        Text(sighting.species?.commonName ?? "Not sure yet")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sighting.species?.commonName ?? "Not sure yet")
                                .font(.headline)
                            Text(sighting.date, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteSightings)
                .listRowBackground(Theme.backgroundElevated)
            }
            .themedBackground()
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
#endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FlowingTitle(text: "Diary")
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button {
                        showingAddSighting = true
                    } label: {
                        Label("Add Sighting", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSighting) {
                AddSightingView()
            }
        }
    }

    private func deleteSightings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sightings[index])
            }
        }
    }
}

fileprivate struct NavigationViewWrapper<Content: View>: View {
    let content: () -> Content

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            content()
        } detail: {
            Text("Select a sighting")
        }
#else
        NavigationStack {
            content()
        }
#endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BirdSighting.self, inMemory: true)
}
