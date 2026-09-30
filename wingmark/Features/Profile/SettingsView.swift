import SwiftUI

struct SettingsView: View {
    @Environment(AuthSession.self) private var session
    @Environment(DiaryStore.self) private var diary
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system

    @State private var units = UnitPreference.current
    @State private var errorMessage: String?
    @State private var confirmLogoutAll = false
    @State private var isWorking = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Units", selection: $units) {
                    ForEach(UnitPreference.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units are used for distances to your sightings and for species sizes in the Guide.")
                    FieldError(message: errorMessage)
                }
            }

            Section("Account") {
                NavigationLink("Change Password") { ChangePasswordView() }
                Button("Log Out") {
                    Task { await session.logOut() }
                }
                Button("Log Out of All Devices") { confirmLogoutAll = true }
                    .confirmationDialog("Log out of all devices?", isPresented: $confirmLogoutAll, titleVisibility: .visible) {
                        Button("Log Out Everywhere", role: .destructive) { logOutAll() }
                    } message: {
                        Text("You'll be signed out on every device, including this one.")
                    }
            }

            Section {
                NavigationLink {
                    DeleteAccountView()
                } label: {
                    Text("Delete Account").foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .disabled(isWorking)
        .onAppear { units = session.settings?.unitPreference ?? UnitPreference.current }
        .onChange(of: language) { _, newValue in
            save(locale: newValue.resolvedCode) {
                await session.refreshProfile()
                await diary.load()
            }
        }
        .onChange(of: units) { _, newValue in
            guard newValue != session.settings?.unitPreference else { return }
            save(unitPreference: newValue)
        }
    }

    private func save(unitPreference: UnitPreference? = nil, locale: String? = nil, then: (() async -> Void)? = nil) {
        errorMessage = nil
        Task {
            do throws(APIError) {
                try await session.updateSettings(unitPreference: unitPreference, locale: locale)
            } catch {
                errorMessage = error.userMessage
            }
            await then?()
        }
    }

    private func logOutAll() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do throws(APIError) {
                try await session.logOutAllDevices()
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

struct ChangePasswordView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new = ""
    @State private var confirmation = ""
    @State private var showValidation = false
    @State private var currentError: String?
    @State private var newServerError: String?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var didSave = false

    private var isValid: Bool {
        !current.isEmpty && AuthValidation.passwordError(new) == nil
            && AuthValidation.confirmationError(new, confirmation) == nil
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Current Password", text: $current)
                        .textContentType(.password)
                    FieldError(message: currentError)
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("New Password", text: $new)
                        .textContentType(.newPassword)
                    FieldError(message: newServerError ?? (showValidation ? AuthValidation.passwordError(new) : nil))
                }
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Confirm New Password", text: $confirmation)
                        .textContentType(.newPassword)
                    FieldError(message: showValidation ? AuthValidation.confirmationError(new, confirmation) : nil)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You'll stay logged in here; other devices will be signed out.")
                    FieldError(message: errorMessage)
                }
            }
            Section {
                PrimaryActionButton(title: "Change Password", isLoading: isSaving, action: save)
                    .disabled(current.isEmpty || new.isEmpty || confirmation.isEmpty || isSaving)
            }
        }
        .navigationTitle("Change Password")
        .disabled(isSaving)
        .onChange(of: current) { currentError = nil }
        .onChange(of: new) { newServerError = nil }
        .alert("Password changed", isPresented: $didSave) {
            Button("OK") { dismiss() }
        }
    }

    private func save() {
        showValidation = true
        guard isValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do throws(APIError) {
                try await session.changePassword(current: current, new: new)
                didSave = true
            } catch {
                switch error.code {
                case .wrongPassword:
                    currentError = String(localized: "The password is incorrect.", bundle: .app)
                case .samePassword:
                    newServerError = String(localized: "Your new password must be different from the current one.", bundle: .app)
                case .validationFailed:
                    newServerError = AuthValidation.serverFieldMessage(for: "newPassword")
                default:
                    errorMessage = error.userMessage
                }
            }
        }
    }
}

struct DeleteAccountView: View {
    @Environment(AuthSession.self) private var session

    @State private var password = ""
    @State private var passwordError: String?
    @State private var errorMessage: String?
    @State private var confirm = false
    @State private var isDeleting = false

    var body: some View {
        Form {
            Section {
                Text("Deleting your account permanently removes your sightings, photos, badges and profile. This can't be undone.")
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    FieldError(message: passwordError)
                }
            } header: {
                Text("Enter your password to confirm")
            } footer: {
                FieldError(message: errorMessage)
            }
            Section {
                Button(role: .destructive) {
                    confirm = true
                } label: {
                    HStack {
                        Text("Delete Account")
                        if isDeleting { Spacer(); ProgressView() }
                    }
                }
                .disabled(password.isEmpty || isDeleting)
                .confirmationDialog("Delete your account?", isPresented: $confirm, titleVisibility: .visible) {
                    Button("Delete Account", role: .destructive, action: delete)
                } message: {
                    Text("This can't be undone.")
                }
            }
        }
        .navigationTitle("Delete Account")
        .disabled(isDeleting)
        .onChange(of: password) { passwordError = nil }
    }

    private func delete() {
        isDeleting = true
        errorMessage = nil
        Task {
            defer { isDeleting = false }
            do throws(APIError) {
                try await session.deleteAccount(password: password)
            } catch {
                if error.code == .wrongPassword {
                    passwordError = String(localized: "The password is incorrect.", bundle: .app)
                } else {
                    errorMessage = error.userMessage
                }
            }
        }
    }
}
