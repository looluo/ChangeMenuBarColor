//
//  NotchRow.swift
//  ChangeMenuBarColor
//

import Cocoa

/// One menu row: an NSSwitch and a "Notch" label, as an NSMenuItem.view.
/// NSMenuItem.state cannot render a real switch and the operator asked for one.
final class NotchRow: NSView {
    var onToggle: ((NotchIntent) -> Void)?

    private let notchSwitch = NSSwitch()

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 150, height: 26))

        let label = NSTextField(labelWithString: "Notch")
        label.font = NSFont.menuFont(ofSize: 0)
        label.frame.origin = CGPoint(x: 16, y: (bounds.height - label.fittingSize.height) / 2)
        label.sizeToFit()
        addSubview(label)

        // The action fires after the state has flipped, so the new state is the
        // intent to converge to.
        notchSwitch.target = self
        notchSwitch.action = #selector(switchFlipped(_:))
        let switchSize = notchSwitch.intrinsicContentSize
        notchSwitch.frame.origin = CGPoint(x: bounds.width - switchSize.width - 14, y: (bounds.height - switchSize.height) / 2)
        addSubview(notchSwitch)
    }

    required init?(coder: NSCoder) {
        fatalError("NotchRow is built in code")
    }

    func setIntent(_ intent: NotchIntent) {
        notchSwitch.state = intent == .on ? .on : .off
    }

    @objc private func switchFlipped(_ sender: NSSwitch) {
        onToggle?(sender.state == .on ? .on : .off)
    }
}
