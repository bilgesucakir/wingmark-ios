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
            }
            .navigationTitle("Diary")
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addSampleSighting) {
                        Label("Add Sighting", systemImage: "plus")
                    }
                }
            }
        }
    }

    // Temporary — real "New Sighting" form comes in the next piece.
    private func addSampleSighting() {
        withAnimation {
            modelContext.insert(BirdSighting())
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
        content()
#endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BirdSighting.self, inMemory: true)
}
