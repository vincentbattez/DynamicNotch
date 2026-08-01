//
//  SystemSettingsView.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 7/15/26.
//

import SwiftUI

struct SystemSettingsView: View {
    @ObservedObject var applicationSettings: ApplicationSettingsStore

    @State private var cliState: CLIToolInstaller.InstallState = .absent
    @State private var isInstallingCLI = false
    @State private var cliInstallMessage: LocalizedStringKey?

    var body: some View {
        SettingsPageScrollView {
            systemCard
        }
        .onAppear { cliState = CLIToolInstaller.currentInstallState() }
    }

    private var systemCard: some View {
        SettingsCard() {
            SettingsToggleRow(
                title: "Launch at login",
                description: "Launch Dynamic Notch automatically when you sign in.",
                systemImage: "power",
                color: .red,
                isOn: $applicationSettings.isLaunchAtLoginEnabled,
                accessibilityIdentifier: "settings.general.launchAtLogin"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "Show Dock icon",
                description: "Keep the app visible in the Dock for faster switching and window access.",
                systemImage: "dock.rectangle",
                color: .orange,
                isOn: $applicationSettings.isDockIconVisible,
                accessibilityIdentifier: "settings.general.dockIcon"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(
                    title: "Show menu bar icon",
                    description: "Show a menu bar shortcut for quick access to Settings and Quit.",
                    systemImage: "menubar.rectangle",
                    color: .blue,
                    isOn: $applicationSettings.isMenuBarIconVisible,
                    accessibilityIdentifier: "settings.general.menuBarIcon"
                )
                if !applicationSettings.isMenuBarIconVisible {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.yellow)

                        Text("You can access the menu by right-clicking on the notch area.")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, alignment: .trailing)

            commandLineToolRow
        }
    }

    private var commandLineToolRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsButtonRow(
                title: "Command-line tool",
                description: "Install the dynamicnotch command so scripts, cron jobs and Shortcuts can push notifications from any terminal.",
                systemImage: "terminal",
                color: .purple,
                buttonTitle: buttonTitle,
                isButtonDisabled: isInstallingCLI || cliState == .installedCurrent,
                accessibilityIdentifier: "settings.general.cliTool",
                action: installCLI
            )

            if cliState == .foreign {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.yellow)

                    Text("Another file already occupies this location; installing will replace it.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }

            if let cliInstallMessage {
                Text(cliInstallMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The button label derives from the same `InstallState` that drives the silent launch attempt,
    /// so label and behavior can never diverge.
    private var buttonTitle: LocalizedStringKey {
        switch cliState {
        case .absent, .foreign: "Install"
        case .installedCurrent: "Installed"
        case .installedOther: "Repair"
        }
    }

    /// Runs the (blocking) manual installer off the main thread — the privileged path waits on an
    /// admin dialog — then refreshes the row state and shows a result line only on failure.
    private func installCLI() {
        isInstallingCLI = true
        cliInstallMessage = nil
        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                CLIToolInstaller.install()
            }.value
            isInstallingCLI = false
            cliState = CLIToolInstaller.currentInstallState()
            cliInstallMessage = Self.failureMessage(for: outcome)
        }
    }

    /// Success is silent — the button flipping to `Installed` says it. Only failures surface a line.
    private static func failureMessage(for outcome: CLIToolInstaller.Outcome) -> LocalizedStringKey? {
        switch outcome {
        case .installed, .installedWithPrivileges:
            nil
        case .permissionDenied:
            "Installation was cancelled. Administrator permission is required."
        case .binaryMissing:
            "The command-line tool is missing from the app bundle."
        case .failed:
            "Installation failed. Check that /usr/local/bin is writable."
        }
    }
}
