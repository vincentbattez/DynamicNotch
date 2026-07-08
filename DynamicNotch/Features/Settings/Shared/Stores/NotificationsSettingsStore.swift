import Combine
import Foundation

@MainActor
final class NotificationsSettingsStore: SettingsStoreBase {
    /// The inbox directory where scripts drop notification JSON files.
    static var inboxDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DynamicNotch", isDirectory: true)
            .appendingPathComponent("inbox", isDirectory: true)
    }

    @Published var isEnabled: Bool {
        didSet { persist(isEnabled, for: GeneralSettingsStorage.Keys.notificationsEnabled) }
    }

    override init(defaults: UserDefaults = .standard) {
        defaults.register(defaults: GeneralSettingsStorage.defaultValues)
        self.isEnabled = (defaults.object(forKey: GeneralSettingsStorage.Keys.notificationsEnabled) as? Bool)
            ?? true
        super.init(defaults: defaults)
    }
}
