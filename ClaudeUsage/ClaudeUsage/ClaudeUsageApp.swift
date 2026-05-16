import SwiftUI
import AppKit
import Core
import os

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(
        subsystem: "dev.emmanueloluwafemi.claude-usage",
        category: "app"
    )

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        startColdScan()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let symbol = NSImage(
                systemSymbolName: "gauge.with.dots.needle.50percent",
                accessibilityDescription: "Claude Usage"
            )
            symbol?.isTemplate = true
            button.image = symbol
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 320, height: 170)
        pop.contentViewController = NSHostingController(rootView: ContentView())
        popover = pop
    }

    private func startColdScan() {
        let logger = AppDelegate.logger
        Task.detached(priority: .utility) {
            logger.info("cold-start codex scan: starting")
            do {
                let result = try await Ingestor().runColdStartScan()
                logger.info(
                    "cold-start codex scan: inserted \(result.observationsInserted, privacy: .public) observations across \(result.filesScanned, privacy: .public) of \(result.filesConsidered, privacy: .public) candidate files"
                )
            } catch {
                logger.error("cold-start scan failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
