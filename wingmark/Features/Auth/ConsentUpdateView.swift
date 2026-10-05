import SwiftUI

/// Shown over the app while the user has legal documents to accept; the only way past it is accepting or logging out.
struct ConsentUpdateView: View {
    @Environment(AuthSession.self) private var session

    @State private var documents: LegalDocuments?
    @State private var accepted: Set<ConsentType> = []
    @State private var errorMessage: String?
    @State private var isSaving = false
    /// What the screen is about; kept after the last item is accepted so the text doesn't change as it closes.
    @State private var shownTypes: [ConsentType] = []

    private var acceptedAll: Bool { Set(session.pendingConsents).isSubset(of: accepted) }

    private var ageOnly: Bool { (session.pendingConsents.isEmpty ? shownTypes : session.pendingConsents).isAgeOnly }

    private var title: LocalizedStringKey { ageOnly ? "Confirm Your Age" : "Our Terms Changed" }

    private var intro: LocalizedStringKey {
        ageOnly
            ? "To keep using Wingmark, please confirm your age."
            : "We've updated the documents below. Please review and accept them to keep using Wingmark."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(intro)
                }
                if let documents {
                    Section {
                        ConsentRows(types: session.pendingConsents, documents: documents, accepted: $accepted)
                    } footer: {
                        FieldError(message: errorMessage)
                    }
                    Section {
                        PrimaryActionButton(title: "Continue", isLoading: isSaving, action: accept)
                            .disabled(!acceptedAll || isSaving)
                    }
                } else if let errorMessage {
                    Section {
                        FieldError(message: errorMessage)
                        Button("Try Again") { Task { await load() } }
                    }
                } else {
                    Section {
                        HStack { ProgressView(); Text("Loading…") }
                    }
                }
                Section {
                    Button("Log Out", role: .destructive) {
                        Task { await session.logOut() }
                    }
                }
            }
            .opensLinksInApp()
            .navigationTitle(title)
            .disabled(isSaving)
            .task { await load() }
            .onChange(of: session.pendingConsents, initial: true) { _, types in
                if !types.isEmpty { shownTypes = types }
            }
        }
        .interactiveDismissDisabled()
    }

    private func load() async {
        errorMessage = nil
        do throws(APIError) {
            documents = try await session.legalDocuments()
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func accept() {
        guard let documents, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do throws(APIError) {
                try await session.acceptPendingConsents(documents)
            } catch {
                errorMessage = error.userMessage
                if error.code == .consentVersionMismatch {
                    accepted = []
                    await load()
                    errorMessage = error.userMessage
                }
            }
        }
    }
}
