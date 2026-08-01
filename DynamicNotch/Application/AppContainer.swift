import Foundation
import DynamicNotchContract

@MainActor
final class AppContainer {
    /// Where scripts drop notification JSON. Derived once in `DynamicNotchContract` so the
    /// app and the `dynamicnotch` CLI can never disagree; honors `$DYNAMICNOTCH_INBOX`.
    static var notificationsInboxDirectory: URL {
        NotificationInbox.resolvedURL
    }

    /// Where scripts drop Command JSON — a sibling of the inbox (ADR-0002). Resolved in
    /// `DynamicNotchContract` so the app and CLI agree; honors `$DYNAMICNOTCH_COMMANDS`.
    static var commandsDirectory: URL {
        CommandFolder.resolvedURL
    }

    private let isRunningUITests: Bool

    let powerService = PowerService()
    let bluetoothViewModel = BluetoothViewModel()
    let focusViewModel = FocusViewModel()
    let airDropViewModel = AirDropNotchViewModel()
    let fileTrayViewModel = FileTrayViewModel()
    let fileConverterViewModel = FileConverterViewModel()
    let settingsViewModel: SettingsViewModel
    let wifiViewModel: WifiViewModel
    let vpnViewModel: VpnViewModel
    let homePageViewModel = HomePageViewModel()
    let localTimerViewModel = LocalTimerViewModel()
    let notificationCenterViewModel = NotificationCenterViewModel(
        monitor: NotificationInboxMonitor(inboxDirectory: AppContainer.notificationsInboxDirectory)
    )
    let calendarViewModel = CalendarViewModel()
    let screenshotViewModel = ScreenshotViewModel()

    let powerViewModel: PowerViewModel
    let downloadViewModel: DownloadViewModel
    let nowPlayingViewModel: NowPlayingViewModel
    let timerViewModel: TimerViewModel
    let screenRecordingViewModel: ScreenRecordingViewModel
    let lockScreenManager: LockScreenManager
    let clockTimerController: any ClockTimerControlling

    lazy var hardwareHUDMonitor: HardwareHUDMonitor = {
        MainActor.assumeIsolated {
            let monitor = HardwareHUDMonitor()
            monitor.onEvent = { [weak self] event in
                self?.notchEventCoordinator.handleHudEvent(event)
            }
            monitor.updateConfiguration(
                interceptVolume: settingsViewModel.hud.isVolumeHUDEnabled,
                interceptBrightness: settingsViewModel.hud.isBrightnessHUDEnabled
            )
            return monitor
        }
    }()

    lazy var notchViewModel = NotchViewModel(settings: settingsViewModel.application)
    lazy var airDropController = NotchAirDropController(
        airDropViewModel: airDropViewModel,
        fileTrayViewModel: fileTrayViewModel,
        fileConverterViewModel: fileConverterViewModel
    )

    lazy var notchEventCoordinator = NotchEventCoordinator(
        notchViewModel: notchViewModel,
        bluetoothViewModel: bluetoothViewModel,
        powerService: powerService,
        wifiViewModel: wifiViewModel,
        vpnViewModel: vpnViewModel,
        downloadViewModel: downloadViewModel,
        airDropViewModel: airDropViewModel,
        fileTrayViewModel: fileTrayViewModel,
        fileConverterViewModel: fileConverterViewModel,
        settingsViewModel: settingsViewModel,
        nowPlayingViewModel: nowPlayingViewModel,
        timerViewModel: timerViewModel,
        screenRecordingViewModel: screenRecordingViewModel,
        lockScreenManager: lockScreenManager,
        homePageViewModel: homePageViewModel,
        localTimerViewModel: localTimerViewModel,
        notificationCenterViewModel: notificationCenterViewModel,
        calendarViewModel: calendarViewModel,
        screenshotViewModel: screenshotViewModel
    )

    /// Carries the timer conflict/replacement policy. Its collaborators are passed as closures
    /// so the routing is testable without the container (Test 3). See `CommandRouter`.
    lazy var commandRouter = CommandRouter(
        localTimerViewModel: localTimerViewModel,
        isClockTimerActive: { [weak self] in
            // ANY Clock timer owns the surface — running *or paused*. User story #17: a script
            // must never displace a countdown the user set themselves in Horloge, even a paused
            // one. (This is stricter than the live-activity display guard, which ignores paused.)
            self?.timerViewModel.snapshot != nil
        },
        emitNotification: { [weak self] payload in
            self?.notificationCenterViewModel.add(payload: payload)
        }
    )

    /// Watches `commands/` and routes each ingested Command. Inert under UI tests.
    lazy var commandMonitor: any CommandMonitoring = {
        let monitor: any CommandMonitoring = isRunningUITests
            ? InactiveCommandMonitor()
            : CommandMonitor(commandsDirectory: AppContainer.commandsDirectory)
        monitor.onCommand = { [weak self] command in
            // `onCommand` fires on the monitor's queue; hop to main for the @MainActor router.
            DispatchQueue.main.async { self?.commandRouter.route(command) }
        }
        return monitor
    }()

    lazy var lockScreenPanelManager = LockScreenPanelManager(
        nowPlayingViewModel: nowPlayingViewModel,
        lockScreenManager: lockScreenManager,
        settingsViewModel: settingsViewModel
    )

    lazy var lockScreenLiveActivityWindowManager = LockScreenLiveActivityWindowManager(
        notchViewModel: notchViewModel,
        lockScreenManager: lockScreenManager,
        settingsViewModel: settingsViewModel
    )

    init(isRunningUITests: Bool = ProcessInfo.processInfo.arguments.contains("-ui-testing")) {
        self.isRunningUITests = isRunningUITests
        self.settingsViewModel = SettingsViewModel()
        self.wifiViewModel = WifiViewModel(settings: settingsViewModel.connectivity)
        self.vpnViewModel = VpnViewModel(settings: settingsViewModel.connectivity)
        self.powerViewModel = PowerViewModel(
            powerService: powerService,
            batterySettings: settingsViewModel.battery
        )
        self.nowPlayingViewModel = NowPlayingViewModel(
            service: isRunningUITests ?
                InactiveNowPlayingService() :
                MediaRemoteNowPlayingService(),
            audioOutputRouting: isRunningUITests ?
                InactiveAudioOutputRoutingService() :
                SystemAudioOutputRoutingService(),
            lyricsProvider: isRunningUITests ?
                InactiveLyricsProvider() :
                LRCLIBLyricsProvider(),
            sourceFilter: settingsViewModel.mediaAndFiles.nowPlayingSourceFilter
        )
        self.downloadViewModel = DownloadViewModel(
            monitor: isRunningUITests ?
                InactiveDownloadMonitor() :
                FolderFileDownloadMonitor()
        )
        self.clockTimerController = isRunningUITests ?
            InactiveClockTimerController() :
            ClockTimerController()
        self.timerViewModel = TimerViewModel(
            monitor: isRunningUITests ?
                InactiveClockTimerMonitor() :
                ClockTimerMonitor(),
            controller: clockTimerController
        )
        self.screenRecordingViewModel = ScreenRecordingViewModel(
            monitor: isRunningUITests ?
                InactiveScreenRecordingMonitor() :
                SystemScreenRecordingMonitor()
        )
        self.lockScreenManager = LockScreenManager(
            service: isRunningUITests ?
                InactiveLockScreenMonitoringService() :
                DistributedLockScreenMonitoringService(),
            soundPlayer: isRunningUITests ?
                InactiveLockScreenSoundPlayer() :
                LockScreenSoundPlayer()
        )
    }
}
