import AppKit
import QuartzCore

/// Preference shared with the main window; the icons and their design stay untouched.
enum MenuBarIconAnimations {
    static let defaultsKey = "keyGlowMenuBarIconAnimations"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
    }
}

@MainActor
final class MenuBarIconController {
    enum State: Equatable {
        case neutral
        case increasing
        case decreasing

        fileprivate var assetName: NSImage.Name {
            switch self {
            case .neutral: "KeyGlowMenuBarNeutral"
            case .increasing: "KeyGlowMenuBarIncrease"
            case .decreasing: "KeyGlowMenuBarDecrease"
            }
        }
    }

    private enum AnimationKey {
        static let entrance = "KeyGlowIconEntrance"
        static let settle = "KeyGlowIconSettle"
        static let step = "KeyGlowIconStep"
    }

    private static let iconSize = NSSize(width: 18, height: 18)
    private static let neutralDelay = Duration.milliseconds(700)
    private static let entranceDuration: CFTimeInterval = 0.3
    private static let settleDuration: CFTimeInterval = 0.16
    private static let stepDuration: CFTimeInterval = 0.12

    private let imageLoader: (NSImage.Name) -> NSImage?
    private var imageCache: [NSImage.Name: NSImage] = [:]
    private weak var statusItem: NSStatusItem?
    private var neutralTask: Task<Void, Never>?
    private(set) var state = State.neutral

    private var animationsAllowed: Bool {
        MenuBarIconAnimations.isEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(imageLoader: @escaping (NSImage.Name) -> NSImage? = { NSImage(named: $0) }) {
        self.imageLoader = imageLoader
    }

    func configure(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        apply(.neutral, animated: false)
    }

    /// Plays the feedback for one accepted hardware write. A new direction gets the
    /// directional entrance; extra writes in the same direction only nudge the icon, so
    /// holding a shortcut or dragging the slider never restarts the entrance.
    func showChange(from oldValue: Double, to newValue: Double) {
        let difference = newValue - oldValue
        guard abs(difference) > 0.001 else { return }

        let target: State = difference > 0 ? .increasing : .decreasing
        neutralTask?.cancel()

        if target != state {
            apply(target, animated: true)
        } else if animationsAllowed,
                  let layer = statusItem?.button?.layer,
                  layer.animation(forKey: AnimationKey.entrance) == nil {
            // Extra steps wait for the entrance to finish so the two scale animations
            // never compete; a held shortcut or slider then gets a steady micro-feedback.
            playStepTick(on: layer, isIncreasing: difference > 0)
        }

        neutralTask = Task { [weak self] in
            try? await Task.sleep(for: Self.neutralDelay)
            guard !Task.isCancelled else { return }
            self?.apply(.neutral, animated: true)
        }
    }

    private func apply(_ newState: State, animated: Bool) {
        guard let button = statusItem?.button else { return }
        let changed = newState != state
        state = newState
        button.wantsLayer = true

        if changed || button.image == nil, let image = image(for: newState) {
            button.image = image
            button.imageScaling = .scaleProportionallyDown
        }

        guard let layer = button.layer else { return }
        guard animated, changed, animationsAllowed else {
            clearAnimations(on: layer)
            return
        }

        switch newState {
        case .neutral:
            playSettle(on: layer)
        case .increasing, .decreasing:
            // A visible title shares the button layer, so the motion stays minimal there.
            playEntrance(on: layer, state: newState, alongsideTitle: !button.title.isEmpty)
        }
    }

    /// Directional entrance: the icon fades in while travelling in the direction of the
    /// change (up for a brighter keyboard, down for a darker one) and lands with a soft
    /// overshoot instead of a symmetric pulse.
    private func playEntrance(on layer: CALayer, state: State, alongsideTitle: Bool) {
        clearAnimations(on: layer)
        let grows = state == .increasing

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.1, 1.0]
        fade.keyTimes = [0.0, 1.0]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = grows ? [0.9, 1.035, 1.0] : [1.09, 0.982, 1.0]
        scale.keyTimes = [0.0, 0.6, 1.0]
        if alongsideTitle {
            scale.values = grows ? [0.985, 1.008, 1.0] : [1.018, 0.994, 1.0]
        }

        let slide = CAKeyframeAnimation(keyPath: "transform.translation.y")
        // CALayer coordinates grow upward unless the host view is flipped.
        let flip: CGFloat = layer.isGeometryFlipped ? -1 : 1
        let travel: CGFloat = alongsideTitle ? 0 : (grows ? -1.6 : 1.6) * flip
        slide.values = [travel, -travel * 0.12, 0]
        slide.keyTimes = [0.0, 0.6, 1.0]

        let group = CAAnimationGroup()
        group.animations = [fade, scale, slide]
        group.duration = Self.entranceDuration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.3, 1)
        layer.add(group, forKey: AnimationKey.entrance)
    }

    /// Returning to the neutral icon is a quiet fade: no second pulse at the end of a gesture.
    private func playSettle(on layer: CALayer) {
        clearAnimations(on: layer)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.55
        fade.toValue = 1.0
        fade.duration = Self.settleDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(fade, forKey: AnimationKey.settle)
    }

    /// Micro-feedback for each extra step in the same direction. Restarting it holds a
    /// slightly larger or smaller icon while a shortcut or the slider keeps adjusting.
    private func playStepTick(on layer: CALayer, isIncreasing: Bool) {
        layer.removeAnimation(forKey: AnimationKey.step)

        let tick = CABasicAnimation(keyPath: "transform.scale")
        tick.fromValue = isIncreasing ? 1.028 : 0.972
        tick.toValue = 1.0
        tick.duration = Self.stepDuration
        tick.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(tick, forKey: AnimationKey.step)
    }

    private func clearAnimations(on layer: CALayer) {
        layer.removeAnimation(forKey: AnimationKey.entrance)
        layer.removeAnimation(forKey: AnimationKey.settle)
        layer.removeAnimation(forKey: AnimationKey.step)
    }

    private func image(for state: State) -> NSImage? {
        let name = state.assetName
        if let cached = imageCache[name] { return cached }
        guard let image = imageLoader(name)?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        image.size = Self.iconSize
        imageCache[name] = image
        return image
    }
}
