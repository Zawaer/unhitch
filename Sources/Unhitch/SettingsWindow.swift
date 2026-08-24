import AppKit
import SwiftUI

/// The app's window, for people who would rather not keep an icon in the menu bar.
/// Everything here is also reachable from the menu; neither is the "real" UI.
final class SettingsWindowController {

    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        model.refreshDevices()

        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let created = NSWindow(contentViewController: hosting)
            created.title = "Unhitch"
            created.styleMask = [.titled, .closable, .miniaturizable]
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    private static let repository = URL(string: "https://github.com/Zawaer/unhitch")!

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            settings
            Divider()
            footer
        }
        .frame(width: 460, height: 660)
        // The header and footer sit outside the Form, which paints its own
        // background, so they need the window colour spelled out or they render
        // as bare white in dark mode.
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { model.refreshDevices() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("Unhitch").font(.system(size: 17, weight: .semibold))
                Text(model.versionSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $model.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(model.isEnabled ? "Pause Unhitch" : "Resume Unhitch")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private var settings: some View {
        Form {
            Section {
                if model.devices.isEmpty {
                    Text("No paired Bluetooth devices.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.devices) { device in
                        Toggle(isOn: model.binding(for: device.address)) {
                            HStack(spacing: 8) {
                                Text(device.name)
                                if device.isConnected {
                                    Text("connected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Devices to let go of")
            } footer: {
                Text("Everything you leave unticked — keyboards, mice, trackpads — is never touched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Let go when") {
                if model.hasClamshell {
                    Toggle("The lid closes", isOn: $model.disconnectOnLidClose)
                }
                Toggle("The Mac sleeps", isOn: $model.disconnectOnSystemSleep)
                Toggle("Reconnect when the lid opens", isOn: $model.reconnectOnLidOpen)
            }

            Section {
                Toggle("Launch at login", isOn: $model.launchesAtLogin)
                Toggle("Show in the menu bar", isOn: $model.showsMenuBarIcon)
            } footer: {
                Text(model.showsMenuBarIcon
                     ? "Unhitch runs in the background either way."
                     : "Unhitch keeps running with no icon. Open it from your Applications folder to get back to this window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Disconnect Now") { model.disconnectNow() }
                .disabled(model.watched.isEmpty || !model.isEnabled)
                .help("Drop the ticked devices right now, without waiting for the lid")
            Spacer()
            Link("GitHub", destination: Self.repository)
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
