import AppKit
import IOKit.ps
import KeyboardShortcuts
import Observation
import ServiceManagement
import SwiftUI
import UserNotifications

extension KeyboardShortcuts.Name {
    static let profile1 = Self("profile1")
    static let profile2 = Self("profile2")
    static let profile3 = Self("profile3")
    static let openMainWindow = Self("openMainWindow")
}

/// États repliés/dépliés persistés du panneau de la barre des menus.
enum PanelDisclosureKeys {
    static let profileEditor = "panel.showsProfileEditor"
    static let shortcuts = "panel.showsShortcuts"
    static let automation = "panel.showsAutomation"
}

enum MenuBarTitleMode: String, CaseIterable, Identifiable {
    case none, percentage, presetName

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Aucun"
        case .percentage: "Pourcentage"
        case .presetName: "Preset actif"
        }
    }
}

private enum TemporaryOffKeys {
    static let deadline = "temporaryOffDeadline"
}

/// Defaults used by a fresh install and by the settings reset.
private enum PresetDefaults {
    static let profiles = [
        BrightnessProfile(name: "Travail", brightness: 0.7, icon: "briefcase"),
        BrightnessProfile(name: "Soir", brightness: 0.25, icon: "moon.stars"),
        BrightnessProfile(name: "Cinéma", brightness: 0.05, icon: "film")
    ]
}

struct BrightnessProfile: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var brightness: Double
    var icon: String = "keyboard"
    var isFavorite: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, brightness, icon, isFavorite
    }
}

extension BrightnessProfile {
    /// Earlier versions stored only `id`, `name` and `brightness`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Preset"
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.5
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "keyboard"
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

@MainActor @Observable
final class AdvancedKeyGlowModel {
    /// The single source of truth shared by the menu bar panel and the main window.
    static let shared = AdvancedKeyGlowModel()

    private struct Preferences: Codable {
        var favorites = [0.25, 0.5, 1.0]
        var profiles = PresetDefaults.profiles
        var stepSize = 0.05
        var showHUD = true
        var showPercentage = false
        var powerAutomationEnabled = false
        var batteryBrightness = 0.25
        var adapterBrightness = 0.7
        var scheduleEnabled = false
        var scheduleStartHour = 21
        var scheduleEndHour = 7
        var scheduledProfileIndex = 1
        var restoreBrightnessOnLaunch = false
        var titleShowsPresetName = false
        var notifyAutomation = false

        enum CodingKeys: String, CodingKey {
            case favorites, profiles, stepSize, showHUD, showPercentage, powerAutomationEnabled
            case batteryBrightness, adapterBrightness, scheduleEnabled, scheduleStartHour, scheduleEndHour
            case scheduledProfileIndex, restoreBrightnessOnLaunch, titleShowsPresetName, notifyAutomation
        }

        init() {}

        /// Tolerant decoding so preferences written by an older build keep their presets and favorites.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            favorites = try container.decodeIfPresent([Double].self, forKey: .favorites) ?? favorites
            let savedProfiles = try container.decodeIfPresent([BrightnessProfile].self, forKey: .profiles) ?? []
            profiles = savedProfiles.isEmpty ? PresetDefaults.profiles : savedProfiles
            stepSize = try container.decodeIfPresent(Double.self, forKey: .stepSize) ?? stepSize
            showHUD = try container.decodeIfPresent(Bool.self, forKey: .showHUD) ?? showHUD
            showPercentage = try container.decodeIfPresent(Bool.self, forKey: .showPercentage) ?? showPercentage
            powerAutomationEnabled = try container.decodeIfPresent(Bool.self, forKey: .powerAutomationEnabled) ?? powerAutomationEnabled
            batteryBrightness = try container.decodeIfPresent(Double.self, forKey: .batteryBrightness) ?? batteryBrightness
            adapterBrightness = try container.decodeIfPresent(Double.self, forKey: .adapterBrightness) ?? adapterBrightness
            scheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? scheduleEnabled
            scheduleStartHour = try container.decodeIfPresent(Int.self, forKey: .scheduleStartHour) ?? scheduleStartHour
            scheduleEndHour = try container.decodeIfPresent(Int.self, forKey: .scheduleEndHour) ?? scheduleEndHour
            scheduledProfileIndex = try container.decodeIfPresent(Int.self, forKey: .scheduledProfileIndex) ?? scheduledProfileIndex
            restoreBrightnessOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .restoreBrightnessOnLaunch) ?? restoreBrightnessOnLaunch
            titleShowsPresetName = try container.decodeIfPresent(Bool.self, forKey: .titleShowsPresetName) ?? titleShowsPresetName
            notifyAutomation = try container.decodeIfPresent(Bool.self, forKey: .notifyAutomation) ?? notifyAutomation
        }
    }

    private var controller: KeyboardBacklightController?
    private let defaults = UserDefaults.standard
    private let hud = BrightnessHUDController()
    private let menuBarIconController = MenuBarIconController()
    private var preferences: Preferences
    private var lastNonzero: Double
    private var temporaryTimer: Timer?
    private var scheduleTimer: Timer?
    private var powerNotificationSource: CFRunLoopSource?
    private var scrollMonitor: Any?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var pendingLiveValue: Double?
    @ObservationIgnored private var liveWriteTask: Task<Void, Never>?
    @ObservationIgnored private var shortcutRepeatTasks: [Task<Void, Never>] = []
    private weak var statusItem: NSStatusItem?
    private var scheduleWasActive = false

    var brightness: Double?
    var automaticEnabled = false
    var error: String?
    var isMenuPresented = false
    var showsShortcuts = false
    var showsAutomation = false
    var showsProfileEditor = false
    var launchAtLogin = false
    var temporaryOffUntil: Date?
    var isUsingBattery = false
    var appearance: AppAppearance = .system
    var menuBarIconAnimations = true

    var favorites: [Double] { preferences.favorites }
    var profiles: [BrightnessProfile] { preferences.profiles }
    var stepSize: Double { preferences.stepSize }
    var showHUD: Bool { preferences.showHUD }
    var showPercentage: Bool { preferences.showPercentage }
    var powerAutomationEnabled: Bool { preferences.powerAutomationEnabled }
    var batteryBrightness: Double { preferences.batteryBrightness }
    var adapterBrightness: Double { preferences.adapterBrightness }
    var scheduleEnabled: Bool { preferences.scheduleEnabled }
    var scheduleStartHour: Int { preferences.scheduleStartHour }
    var scheduleEndHour: Int { preferences.scheduleEndHour }
    var scheduledProfileIndex: Int { preferences.scheduledProfileIndex }
    var restoreBrightnessOnLaunch: Bool { preferences.restoreBrightnessOnLaunch }
    var notifyAutomation: Bool { preferences.notifyAutomation }

    var menuBarTitleMode: MenuBarTitleMode {
        preferences.titleShowsPresetName ? .presetName : (preferences.showPercentage ? .percentage : .none)
    }

    /// Description discrète de l’automatisme en cours, affichée sous le curseur du panneau.
    var activeAutomationDescription: String? {
        if scheduleEnabled && isScheduleWindowActive { return "Profil horaire actif" }
        if powerAutomationEnabled { return isUsingBattery ? "Automatisme batterie actif" : "Automatisme secteur actif" }
        return nil
    }

    var hasShortcutConflicts: Bool {
        var counts: [KeyboardShortcuts.Shortcut: Int] = [:]
        for name in [KeyboardShortcuts.Name.increase, .decrease, .toggle, .openMenu, .openMainWindow, .profile1, .profile2, .profile3] {
            if let shortcut = KeyboardShortcuts.getShortcut(for: name) { counts[shortcut, default: 0] += 1 }
        }
        return counts.values.contains { $0 > 1 }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "keyGlowPreferencesV2"),
           let saved = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = saved
        } else {
            preferences = Preferences()
        }
        lastNonzero = max(0.01, UserDefaults.standard.double(forKey: "lastNonzeroBrightness"))
        showsProfileEditor = defaults.bool(forKey: PanelDisclosureKeys.profileEditor)
        showsShortcuts = defaults.bool(forKey: PanelDisclosureKeys.shortcuts)
        showsAutomation = defaults.bool(forKey: PanelDisclosureKeys.automation)
        controller = try? KeyboardBacklightController.open()
        appearance = AppAppearance.stored
        menuBarIconAnimations = MenuBarIconAnimations.isEnabled
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if let controller {
            brightness = try? controller.read()
            automaticEnabled = controller.automaticEnabled
            controller.observe { [weak self] in self?.refresh() }
        } else {
            error = KeyboardBacklightController.Failure.unavailable.localizedDescription
        }
        registerShortcuts()
        startPowerMonitoring()
        startScheduleMonitoring()
        startHardwareMonitoring()
        restoreTemporaryOffState()
        if preferences.restoreBrightnessOnLaunch, temporaryOffUntil == nil, (brightness ?? 0) < 0.001, lastNonzero > 0.01 {
            set(lastNonzero, displayHUD: false)
        }
    }

    func refresh() {
        guard let controller else { return }
        do {
            brightness = try controller.read()
            automaticEnabled = controller.automaticEnabled
            updateStatusTitle()
        } catch { self.error = error.localizedDescription }
    }

    func set(_ value: Double, displayHUD: Bool = true) {
        guard let controller else { return }
        do {
            let previous = try controller.read()
            let actual = try controller.write(clamped(value))
            brightness = actual
            if actual > 0.001 {
                lastNonzero = actual
                defaults.set(actual, forKey: "lastNonzeroBrightness")
            }
            automaticEnabled = controller.automaticEnabled
            error = nil
            updateStatusTitle()
            menuBarIconController.showChange(from: previous, to: actual)
            let theme = HUDSettings.shared.theme
            let hidesBehindPanel = theme == .menuBar && isMenuPresented
            if displayHUD && showHUD && !hidesBehindPanel {
                hud.show(brightness: actual, anchor: statusItemScreenRect)
            }
        } catch {
            refresh()
            self.error = error.localizedDescription
        }
    }

    func step(_ direction: Double) {
        refresh()
        guard let brightness else { return }
        set(brightness + (direction < 0 ? -stepSize : stepSize))
    }

    /// Coalesces continuous slider updates to roughly 28 writes per second,
    /// while guaranteeing that the last requested value is written.
    func setLive(_ value: Double) {
        pendingLiveValue = clamped(value)
        guard liveWriteTask == nil else { return }
        liveWriteTask = Task { @MainActor [weak self] in
            defer { self?.liveWriteTask = nil }
            while let self, let target = self.pendingLiveValue {
                self.pendingLiveValue = nil
                self.set(target)
                do { try await Task.sleep(for: .milliseconds(35)) } catch { return }
            }
        }
    }

    func toggle() {
        refresh()
        guard let brightness else { return }
        if brightness > 0.001 {
            lastNonzero = brightness
            set(0)
        } else { set(lastNonzero) }
    }

    var previousBrightness: Double { lastNonzero }

    var canRestorePrevious: Bool { (brightness ?? 0) < 0.001 && lastNonzero > 0.001 }

    func turnOff() {
        refresh()
        guard let brightness, brightness > 0.001 else { return }
        lastNonzero = brightness
        defaults.set(brightness, forKey: "lastNonzeroBrightness")
        set(0)
    }

    func restorePrevious() {
        set(lastNonzero)
    }

    // MARK: Presets partagés avec la fenêtre principale

    /// The preset whose level matches the current hardware level, if any.
    var activePreset: BrightnessProfile? {
        guard let brightness else { return nil }
        return profiles.first { abs($0.brightness - brightness) < 0.005 }
    }

    var favoritePresets: [BrightnessProfile] { profiles.filter(\.isFavorite) }

    /// One preset is always kept so the menu bar and its schedule keep a valid target.
    var canDeletePresets: Bool { profiles.count > 1 }

    func presetIndex(for id: UUID) -> Int? { profiles.firstIndex { $0.id == id } }

    func shortcutName(forPresetAt index: Int) -> KeyboardShortcuts.Name? {
        switch index {
        case 0: .profile1
        case 1: .profile2
        case 2: .profile3
        default: nil
        }
    }

    @discardableResult
    func addPreset(name: String = "Nouveau preset", icon: String = "keyboard", brightness value: Double? = nil) -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = BrightnessProfile(
            name: trimmed.isEmpty ? "Nouveau preset" : trimmed,
            brightness: clamped(value ?? brightness ?? 0.5),
            icon: icon
        )
        preferences.profiles.append(preset)
        save()
        return preset.id
    }

    func updatePreset(id: UUID, name: String? = nil, icon: String? = nil, brightness value: Double? = nil, isFavorite: Bool? = nil) {
        guard let index = presetIndex(for: id) else { return }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            preferences.profiles[index].name = trimmed.isEmpty ? "Preset \(index + 1)" : trimmed
        }
        if let icon { preferences.profiles[index].icon = icon }
        if let value { preferences.profiles[index].brightness = clamped(value) }
        if let isFavorite { preferences.profiles[index].isFavorite = isFavorite }
        save()
    }

    func deletePreset(id: UUID) {
        guard canDeletePresets, let index = presetIndex(for: id) else { return }
        preferences.profiles.remove(at: index)
        preferences.scheduledProfileIndex = min(preferences.scheduledProfileIndex, max(0, preferences.profiles.count - 1))
        save()
    }

    func applyPreset(id: UUID) {
        guard let preset = profiles.first(where: { $0.id == id }) else { return }
        set(preset.brightness)
    }

    func setFavorite(_ isFavorite: Bool, forPreset id: UUID) {
        updatePreset(id: id, isFavorite: isFavorite)
    }

    func movePreset(id: UUID, before targetID: UUID) {
        guard id != targetID,
              let source = presetIndex(for: id),
              let target = presetIndex(for: targetID) else { return }
        let preset = preferences.profiles.remove(at: source)
        // Dropping onto a card places the dragged preset just above it.
        let insertion = source < target ? target - 1 : target
        preferences.profiles.insert(preset, at: min(max(0, insertion), preferences.profiles.count))
        save()
    }

    func movePreset(id: UUID, offset: Int) {
        guard let index = presetIndex(for: id) else { return }
        let target = index + offset
        guard preferences.profiles.indices.contains(target) else { return }
        preferences.profiles.swapAt(index, target)
        save()
    }

    func applyFavorite(_ index: Int) {
        guard favorites.indices.contains(index) else { return }
        set(favorites[index])
    }

    func updateFavorite(_ index: Int, value: Double) {
        guard preferences.favorites.indices.contains(index) else { return }
        preferences.favorites[index] = clamped(value)
        save()
    }

    func applyProfile(_ index: Int) {
        guard profiles.indices.contains(index) else { return }
        set(profiles[index].brightness)
    }

    func updateProfile(_ index: Int, name: String? = nil, brightness: Double? = nil) {
        guard preferences.profiles.indices.contains(index) else { return }
        if let name { preferences.profiles[index].name = name.isEmpty ? "Profil \(index + 1)" : name }
        if let brightness { preferences.profiles[index].brightness = clamped(brightness) }
        save()
    }

    func setStepSize(_ value: Double) { preferences.stepSize = min(0.2, max(0.01, value)); save() }
    func setShowHUD(_ value: Bool) {
        preferences.showHUD = value
        save()
        if !value { hud.hide() }
    }

    func previewHUD() {
        if showHUD { hud.show(brightness: brightness ?? 0.5, anchor: statusItemScreenRect) }
    }

    /// Position de l’icône dans la barre des menus, en coordonnées écran.
    private var statusItemScreenRect: NSRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
    func setShowPercentage(_ value: Bool) {
        preferences.showPercentage = value
        if value { preferences.titleShowsPresetName = false }
        save()
        updateStatusTitle()
    }

    func setMenuBarTitleMode(_ mode: MenuBarTitleMode) {
        preferences.showPercentage = (mode == .percentage)
        preferences.titleShowsPresetName = (mode == .presetName)
        save()
        updateStatusTitle()
    }

    func setNotifyAutomation(_ value: Bool) {
        preferences.notifyAutomation = value
        save()
        guard value else { return }
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    }

    func setRestoreBrightnessOnLaunch(_ value: Bool) { preferences.restoreBrightnessOnLaunch = value; save() }

    func setMenuBarIconAnimations(_ value: Bool) {
        menuBarIconAnimations = value
        MenuBarIconAnimations.setEnabled(value)
    }

    func setAppearance(_ value: AppAppearance) {
        appearance = value
        AppAppearance.apply(value)
    }

    /// Restores the shipped settings while keeping the presets and keyboard shortcuts.
    func restoreDefaultSettings() {
        let keptProfiles = preferences.profiles
        preferences = Preferences()
        preferences.profiles = keptProfiles
        preferences.scheduledProfileIndex = min(preferences.scheduledProfileIndex, max(0, keptProfiles.count - 1))
        save()
        HUDSettings.shared.reset()
        temporaryTimer?.invalidate()
        temporaryTimer = nil
        temporaryOffUntil = nil
        defaults.removeObject(forKey: TemporaryOffKeys.deadline)
        setMenuBarIconAnimations(true)
        setAppearance(.system)
        updateStatusTitle()
    }

    func setPowerAutomation(_ value: Bool) {
        preferences.powerAutomationEnabled = value
        save()
        if value { applyPowerProfile() }
    }

    func setBatteryBrightness(_ value: Double) {
        preferences.batteryBrightness = clamped(value); save()
        if powerAutomationEnabled && isUsingBattery { set(value) }
    }

    func setAdapterBrightness(_ value: Double) {
        preferences.adapterBrightness = clamped(value); save()
        if powerAutomationEnabled && !isUsingBattery { set(value) }
    }

    func setScheduleEnabled(_ value: Bool) {
        preferences.scheduleEnabled = value; scheduleWasActive = false; save(); evaluateSchedule()
    }

    func setScheduleStartHour(_ value: Int) {
        preferences.scheduleStartHour = value; scheduleWasActive = false; save(); evaluateSchedule()
    }

    func setScheduleEndHour(_ value: Int) {
        preferences.scheduleEndHour = value; scheduleWasActive = false; save(); evaluateSchedule()
    }

    func setScheduledProfileIndex(_ value: Int) {
        preferences.scheduledProfileIndex = min(max(0, value), max(0, profiles.count - 1))
        scheduleWasActive = false; save(); evaluateSchedule()
    }

    func turnOffTemporarily(minutes: Int) {
        refresh()
        if let brightness, brightness > 0.001 { lastNonzero = brightness }
        scheduleTemporaryRestore(at: Date().addingTimeInterval(TimeInterval(minutes * 60)))
        set(0)
    }

    func cancelTemporaryOff() {
        temporaryTimer?.invalidate()
        temporaryTimer = nil
        temporaryOffUntil = nil
        defaults.removeObject(forKey: TemporaryOffKeys.deadline)
        set(lastNonzero)
    }

    private func scheduleTemporaryRestore(at date: Date) {
        temporaryTimer?.invalidate()
        temporaryOffUntil = date
        defaults.set(date, forKey: TemporaryOffKeys.deadline)
        temporaryTimer = Timer.scheduledTimer(withTimeInterval: max(0.5, date.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishTemporaryOff() }
        }
    }

    private func finishTemporaryOff() {
        temporaryTimer = nil
        temporaryOffUntil = nil
        defaults.removeObject(forKey: TemporaryOffKeys.deadline)
        set(lastNonzero)
    }

    private func restoreTemporaryOffState() {
        guard let deadline = defaults.object(forKey: TemporaryOffKeys.deadline) as? Date else { return }
        if deadline > Date() {
            scheduleTemporaryRestore(at: deadline)
        } else {
            defaults.removeObject(forKey: TemporaryOffKeys.deadline)
            if (brightness ?? 0) < 0.001, lastNonzero > 0.01 {
                set(lastNonzero, displayHUD: false)
            }
        }
    }

    func configureStatusItem(_ item: NSStatusItem) {
        statusItem = item
        menuBarIconController.configure(statusItem: item)
        MenuBarContextMenuController.shared.configure(statusItem: item)
        updateStatusTitle()
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak item] event in
            guard let self, let button = item?.button, event.window === button.window,
                  button.bounds.contains(button.convert(event.locationInWindow, from: nil)) else { return event }
            guard abs(event.scrollingDeltaY) > 0.2 else { return event }
            self.step(event.scrollingDeltaY > 0 ? 1 : -1)
            return nil
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            error = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            self.error = error.localizedDescription
        }
    }

    func quit() {
        shortcutRepeatTasks.forEach { $0.cancel() }
        liveWriteTask?.cancel()
        workspaceObservers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
            NotificationCenter.default.removeObserver($0)
        }
        controller?.stopObserving()
        NSApplication.shared.terminate(nil)
    }

    private func registerShortcuts() {
        shortcutRepeatTasks.forEach { $0.cancel() }
        shortcutRepeatTasks = [(.increase, 1.0), (.decrease, -1.0)].map { (name: KeyboardShortcuts.Name, direction: Double) in
            Task { @MainActor [weak self] in
                for await _ in KeyboardShortcuts.repeatingKeyDownEvents(for: name) {
                    guard !Task.isCancelled, let self else { return }
                    self.step(direction)
                }
            }
        }
        KeyboardShortcuts.onKeyDown(for: .toggle) { [weak self] in Task { @MainActor in self?.toggle() } }
        KeyboardShortcuts.onKeyDown(for: .openMenu) { [weak self] in Task { @MainActor in self?.isMenuPresented.toggle() } }
        KeyboardShortcuts.onKeyDown(for: .profile1) { [weak self] in Task { @MainActor in self?.applyProfile(0) } }
        KeyboardShortcuts.onKeyDown(for: .profile2) { [weak self] in Task { @MainActor in self?.applyProfile(1) } }
        KeyboardShortcuts.onKeyDown(for: .profile3) { [weak self] in Task { @MainActor in self?.applyProfile(2) } }
        KeyboardShortcuts.onKeyDown(for: .openMainWindow) { Task { @MainActor in MainWindowController.shared.show() } }
    }

    private func startPowerMonitoring() {
        updatePowerSource()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let unmanaged = IOPSNotificationCreateRunLoopSource({ pointer in
            guard let pointer else { return }
            let model = Unmanaged<AdvancedKeyGlowModel>.fromOpaque(pointer).takeUnretainedValue()
            Task { @MainActor in model.updatePowerSource() }
        }, context) else { return }
        let source = unmanaged.takeRetainedValue()
        powerNotificationSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func updatePowerSource() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() else { return }
        let old = isUsingBattery
        isUsingBattery = (source as String) == kIOPSBatteryPowerValue
        if old != isUsingBattery && powerAutomationEnabled { applyPowerProfile() }
    }

    private func applyPowerProfile() {
        applyAutomation(
            isUsingBattery ? batteryBrightness : adapterBrightness,
            reason: isUsingBattery ? "Alimentation sur batterie" : "Alimentation sur secteur"
        )
    }

    private func applyAutomation(_ value: Double, reason: String) {
        set(value)
        guard error == nil, let brightness, notifyAutomation else { return }
        let content = UNMutableNotificationContent()
        content.title = "KeyGlow"
        content.body = "\(reason) : luminosité réglée à \(Int((brightness * 100).rounded())) %."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private var isScheduleWindowActive: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return scheduleStartHour == scheduleEndHour || (scheduleStartHour < scheduleEndHour
            ? hour >= scheduleStartHour && hour < scheduleEndHour
            : hour >= scheduleStartHour || hour < scheduleEndHour)
    }

    private func startHardwareMonitoring() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reloadController() }
        })
        workspaceObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
    }

    /// Re-opens CoreBrightness after a wake or when the built-in keyboard identity changed.
    func reloadController() {
        let reopened = try? KeyboardBacklightController.open()
        controller?.stopObserving()
        controller = reopened
        if let reopened {
            brightness = try? reopened.read()
            automaticEnabled = reopened.automaticEnabled
            reopened.observe { [weak self] in self?.refresh() }
            error = nil
        } else {
            brightness = nil
            error = KeyboardBacklightController.Failure.unavailable.localizedDescription
        }
        updateStatusTitle()
    }

    private func startScheduleMonitoring() {
        evaluateSchedule()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateSchedule() }
        }
        scheduleTimer?.tolerance = 10
    }

    private func evaluateSchedule() {
        guard scheduleEnabled else { scheduleWasActive = false; return }
        let active = isScheduleWindowActive
        if active && !scheduleWasActive, profiles.indices.contains(scheduledProfileIndex) {
            applyAutomation(profiles[scheduledProfileIndex].brightness, reason: "Profil horaire")
        }
        scheduleWasActive = active
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        let title: String
        if preferences.titleShowsPresetName, let preset = activePreset {
            title = " \(preset.name)"
        } else if showPercentage || preferences.titleShowsPresetName {
            // Mode « preset actif » : repli sur le pourcentage quand le niveau est personnalisé.
            title = " \(Int(((brightness ?? 0) * 100).rounded())) %"
        } else {
            title = ""
        }
        button.title = title
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "keyGlowPreferencesV2") }
        // Preset renames and reorders can change a preset-name title.
        updateStatusTitle()
    }

    private func clamped(_ value: Double) -> Double { min(1, max(0, value)) }
}


@MainActor @Observable
final class HUDPresentation {
    var brightness = 0.0
    var visible = false
}

enum HUDTheme: String, CaseIterable, Identifiable {
    case modern = "Modern Glass"
    case classic = "Classic iOS"
    case minimal = "Minimal"
    case menuBar = "Menu Bar"

    var id: String { rawValue }
}

enum HUDPosition: String, CaseIterable, Identifiable {
    case center = "Centre", top = "Haut", bottom = "Bas"
    var id: String { rawValue }
}

enum HUDSize: String, CaseIterable, Identifiable {
    case small = "Petit", medium = "Moyen", large = "Grand"
    var id: String { rawValue }
    var scale: CGFloat {
        switch self {
        case .small: 0.85
        case .medium: 1
        case .large: 1.18
        }
    }
}

@MainActor @Observable
final class HUDSettings {
    static let shared = HUDSettings()
    @ObservationIgnored private let defaults: UserDefaults
    var theme: HUDTheme { didSet { defaults.set(theme.rawValue, forKey: "hud.theme") } }
    var position: HUDPosition { didSet { defaults.set(position.rawValue, forKey: "hud.position") } }
    var duration: Double { didSet { defaults.set(duration, forKey: "hud.duration") } }
    var animations: Bool { didSet { defaults.set(animations, forKey: "hud.animations") } }
    var coloredSegments: Bool { didSet { defaults.set(coloredSegments, forKey: "hud.coloredSegments") } }
    var size: HUDSize { didSet { defaults.set(size.rawValue, forKey: "hud.size") } }
    var showsPercentage: Bool { didSet { defaults.set(showsPercentage, forKey: "hud.showsPercentage") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTheme = defaults.string(forKey: "hud.theme")
        theme = HUDTheme(rawValue: storedTheme ?? "") ?? .menuBar
        // Adopts the menu bar style requested on 2026-10-28 for installs that still
        // run with the former shipped default. A theme picked later is left alone.
        if storedTheme == HUDTheme.minimal.rawValue, !defaults.bool(forKey: "hud.menuBarStyleAdopted") {
            theme = .menuBar
            defaults.set(HUDTheme.menuBar.rawValue, forKey: "hud.theme")
        }
        defaults.set(true, forKey: "hud.menuBarStyleAdopted")
        position = HUDPosition(rawValue: defaults.string(forKey: "hud.position") ?? "") ?? .top
        duration = defaults.object(forKey: "hud.duration") == nil ? 1 : min(3, max(0.5, defaults.double(forKey: "hud.duration")))
        animations = defaults.object(forKey: "hud.animations") == nil || defaults.bool(forKey: "hud.animations")
        coloredSegments = defaults.bool(forKey: "hud.coloredSegments")
        size = HUDSize(rawValue: defaults.string(forKey: "hud.size") ?? "") ?? .medium
        showsPercentage = defaults.object(forKey: "hud.showsPercentage") == nil || defaults.bool(forKey: "hud.showsPercentage")
    }

    func reset() {
        theme = .menuBar
        position = .top
        duration = 1
        animations = true
        coloredSegments = false
        size = .medium
        showsPercentage = true
    }
}

struct HUDSettingsView: View {
    @Bindable var model: AdvancedKeyGlowModel
    @Bindable private var settings = HUDSettings.shared
    @State private var expanded = false
    @State private var preview = HUDPresentation()

    var body: some View {
        DisclosureGroup("Personnalisation du HUD", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Activer le HUD", isOn: Binding(get: { model.showHUD }, set: model.setShowHUD))
                Picker("Apparence du HUD", selection: $settings.theme) {
                    ForEach(HUDTheme.allCases) { Text($0.rawValue).tag($0) }
                }
                ThemedHUDView(presentation: preview, settings: settings)
                    .frame(width: 320, height: settings.theme == .classic ? 285 : 150)
                    .onAppear { preview.brightness = 0.65; preview.visible = true }
                    .accessibilityLabel("Aperçu du HUD à 65 pour cent")
                Button("Tester à l’écran") { model.previewHUD() }.disabled(!model.showHUD)
                HStack {
                    Text("Durée")
                    Slider(value: $settings.duration, in: 0.5...3, step: 0.1)
                    Text(String(format: "%.1f s", settings.duration)).monospacedDigit()
                }
                Picker("Position", selection: $settings.position) {
                    ForEach(HUDPosition.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Animations", isOn: $settings.animations)
                if settings.theme == .classic {
                    Toggle("Derniers segments jaunes et rouges", isOn: $settings.coloredSegments)
                }
            }.padding(.top, 8)
        }
        .onChange(of: settings.theme) { model.previewHUD() }
        .onChange(of: settings.position) { model.previewHUD() }
        .onChange(of: settings.duration) { model.previewHUD() }
        .onChange(of: settings.animations) { model.previewHUD() }
        .onChange(of: settings.coloredSegments) { model.previewHUD() }
    }
}

struct ThemedHUDView: View {
    let presentation: HUDPresentation
    let settings: HUDSettings
    /// Lets the main window show another theme than the active one in its gallery.
    var themeOverride: HUDTheme? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animate: Bool { settings.animations && !reduceMotion }
    private var theme: HUDTheme { themeOverride ?? settings.theme }
    var body: some View {
        Group {
            switch theme {
            case .modern: ModernHUDView(presentation: presentation, settings: settings)
            case .classic: ClassicIOSHUDView(brightness: presentation.brightness, settings: settings).padding(18)
            case .minimal: MinimalHUDView(brightness: presentation.brightness, settings: settings).padding(18)
            case .menuBar: MenuBarHUDView(brightness: presentation.brightness).padding(12)
            }
        }
        .opacity(presentation.visible ? 1 : 0)
        .offset(y: animate && !presentation.visible ? -7 : 0)
        .scaleEffect(animate && theme == .classic && !presentation.visible ? 0.97 : 1)
        .animation(animate ? .easeOut(duration: 0.2) : nil, value: presentation.visible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Luminosité du clavier")
        .accessibilityValue("\(Int((presentation.brightness * 100).rounded())) pour cent")
    }
}

private struct ClassicIOSHUDView: View {
    let brightness: Double
    let settings: HUDSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var lit = 0
    private var target: Int { Int((brightness * 17).rounded()) }
    private var title: String {
        if brightness >= 0.999 { return "Luminosité maximale" }
        if brightness <= 0.001 { return "Clavier éteint" }
        return "Luminosité du clavier"
    }
    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
            Image("KeyGlowIconLarge").renderingMode(.template)
                .resizable().scaledToFit().frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.4), radius: 0, y: 1)
            if settings.showsPercentage {
                Text("\(Int((brightness * 100).rounded())) %").font(.system(size: 15, weight: .medium)).monospacedDigit()
            }
            HStack(spacing: 3) {
                ForEach(0..<17, id: \.self) { index in
                    Rectangle().fill(index < lit ? segmentColor(index) : .white.opacity(0.12)).frame(height: 12)
                }
            }.padding(5).background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 3))
        }
        .foregroundStyle(.white).padding(20).frame(width: 250, height: 250)
        .background {
            if reduceTransparency { Color(red: 0.23, green: 0.29, blue: 0.37) }
            else {
                Rectangle().fill(.regularMaterial)
                    .overlay(Color(red: 0.15, green: 0.23, blue: 0.34).opacity(0.72))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(contrast == .increased ? 0.8 : 0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .task(id: target) {
            if reduceMotion || !settings.animations { lit = target; return }
            while lit != target && !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.08)) { lit += lit < target ? 1 : -1 }
                do { try await Task.sleep(for: .milliseconds(15)) } catch { return }
            }
        }
        .onChange(of: settings.animations) { if !settings.animations { lit = target } }
        .onChange(of: reduceMotion) { if reduceMotion { lit = target } }
    }
    private func segmentColor(_ index: Int) -> Color {
        guard settings.coloredSegments else { return .white }
        if index >= 15 { return .red }
        if index >= 12 { return .yellow }
        return .white
    }
}

/// Reproduit le HUD de volume de macOS : pilule sombre, pictogramme et segments.
private struct MenuBarHUDView: View {
    let brightness: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let segmentCount = 16

    private var filled: Int {
        guard brightness > 0.001 else { return 0 }
        return max(1, Int((brightness * Double(Self.segmentCount)).rounded()))
    }

    var body: some View {
        HStack(spacing: 14) {
            Image("KeyGlowMenuBarNeutral")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(.white)

            HStack(spacing: 3) {
                ForEach(0..<Self.segmentCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.6, style: .continuous)
                        .fill(index < filled ? Color.white : Color.white.opacity(0.22))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 16)
        .frame(width: 290, height: 56)
        .background { pill }
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.26), radius: 8, y: 3)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: filled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Luminosité du clavier")
        .accessibilityValue("\(Int((brightness * 100).rounded())) pour cent")
    }

    @ViewBuilder private var pill: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        if reduceTransparency {
            shape.fill(Color(white: 0.18))
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.black.opacity(0.42)))
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.8))
        }
    }
}

private struct MinimalHUDView: View {
    let brightness: Double
    let settings: HUDSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image("KeyGlowMenuBarNeutral").renderingMode(.template)
                Spacer()
                if settings.showsPercentage {
                    Text("\(Int((brightness * 100).rounded())) %").monospacedDigit()
                }
            }
            GeometryReader { geometry in
                Capsule().fill(.primary.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(.primary).frame(width: geometry.size.width * brightness)
                    }
            }.frame(height: 3)
        }.padding(16).frame(width: 200)
        .background {
            if reduceTransparency { RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .windowBackgroundColor)) }
            else { RoundedRectangle(cornerRadius: 16).fill(.regularMaterial) }
        }
    }
}

private struct ModernHUDView: View {
    let presentation: HUDPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    @State private var displayedLevel = 0
    let settings: HUDSettings
    private var level: Int { Int((presentation.brightness * 12).rounded()) }

    var body: some View {
        surface
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.primary.opacity(contrast == .increased ? 0.55 : 0.12), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0.24 : 0.12), radius: 12, y: 5)
            .padding(18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Luminosité du clavier")
            .accessibilityValue("\(Int((presentation.brightness * 100).rounded())) pour cent")
            .task(id: level) {
                if reduceMotion || !settings.animations { displayedLevel = level; return }
                while displayedLevel != level && !Task.isCancelled {
                    withAnimation(.easeOut(duration: 0.1)) {
                        displayedLevel += displayedLevel < level ? 1 : -1
                    }
                    do { try await Task.sleep(for: .milliseconds(18)) }
                    catch { return }
                }
            }
            .onChange(of: reduceMotion) {
                if reduceMotion { displayedLevel = level }
            }
            .onChange(of: settings.animations) {
                if !settings.animations { displayedLevel = level }
            }
    }

    @ViewBuilder private var surface: some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 26))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
        }
    }

    private var content: some View {
        VStack(spacing: 17) {
            HStack {
                Image("KeyGlowMenuBarNeutral")
                    .renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 30, height: 30)
                Spacer()
                if settings.showsPercentage {
                    Text("\(Int((presentation.brightness * 100).rounded())) %")
                        .font(.system(size: 23, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.primary)
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(index < displayedLevel ? Color.white : Color.white.opacity(0.13))
                        .frame(height: 17)
                }
            }
            .padding(5)
            .background(.black.opacity(scheme == .dark ? 0.28 : 0.48), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 22).padding(.vertical, 19)
        .frame(width: 260)
    }
}

private struct HUDPanelView: View {
    let presentation: HUDPresentation
    @Bindable var settings = HUDSettings.shared

    var body: some View {
        ThemedHUDView(presentation: presentation, settings: settings)
            .scaleEffect(settings.size.scale)
    }
}

@MainActor
private final class BrightnessHUDController {
    private let panel: NSPanel
    private let presentation = HUDPresentation()
    private var dismissal: Task<Void, Never>?

    init() {
        panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 320, height: 300),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.ignoresMouseEvents = true
        let hosting = NSHostingView(rootView: HUDPanelView(presentation: presentation))
        // Keeps the panel at the size computed below instead of letting the hosting
        // view shrink it to the content, which would move an anchored HUD.
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    func hide() {
        dismissal?.cancel()
        presentation.visible = false
        panel.orderOut(nil)
    }

    func show(brightness: Double, anchor: NSRect? = nil) {
        dismissal?.cancel()
        presentation.brightness = min(1, max(0, brightness))
        let scale = HUDSettings.shared.size.scale
        panel.contentView?.layoutSubtreeIfNeeded()
        if let fitted = panel.contentView?.fittingSize, fitted.width > 1, fitted.height > 1 {
            panel.setContentSize(.init(width: fitted.width * scale, height: fitted.height * scale))
        }
        let size = panel.frame.size
        let theme = HUDSettings.shared.theme
        do {
            if theme == .menuBar, let anchor {
                let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) }
                    ?? NSScreen.main
                var x = anchor.midX - size.width / 2
                if let visible = screen?.visibleFrame {
                    x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
                }
                // Just under the menu bar, never overlapping it.
                let top = min(anchor.minY, screen?.visibleFrame.maxY ?? anchor.minY) - 4
                panel.setFrameOrigin(.init(x: x, y: top - size.height))
            } else {
                let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
                    ?? NSScreen.main
                if let frame = screen?.visibleFrame {
                    let y: CGFloat
                    switch HUDSettings.shared.position {
                    case .top: y = frame.maxY - panel.frame.height - 20
                    case .center: y = frame.midY - panel.frame.height / 2
                    case .bottom: y = frame.minY + 20
                    }
                    panel.setFrameOrigin(.init(x: frame.midX - panel.frame.width / 2, y: y))
                }
            }
            panel.orderFrontRegardless()
        }
        dismissal = Task { @MainActor [weak self] in
            // Give the hosting view a layout pass before the entry transition.
            await Task.yield()
            guard !Task.isCancelled, let self else { return }
            self.presentation.visible = true
            do {
                try await Task.sleep(for: .seconds(HUDSettings.shared.duration))
                self.presentation.visible = false
                try await Task.sleep(for: .milliseconds(220))
                self.panel.orderOut(nil)
            } catch { return }
        }
    }
}
