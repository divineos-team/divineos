import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// divineDE shell: wallpaper, menu bar and dock on every monitor; one Control Center, launcher,
// Notification Center, notification banners, OSD, lock screen, app switcher, overview,
// capture bar, Settings, the Store and the Welcome guide. Run with `qs -p /usr/share/divine-shell`. Hyprland binds
// keys to the global shortcuts below.
ShellRoot {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            PanelWindow {
                screen: perScreen.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "black"
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "divine-wallpaper"

                Image {
                    anchors.fill: parent
                    source: Sys.wallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            PanelWindow {
                visible: Sys.layout !== "windows" // the taskbar has it all there
                screen: perScreen.modelData
                anchors { top: true; left: true; right: true }
                implicitHeight: bar.implicitHeight
                color: "transparent"
                WlrLayershell.namespace: "divine-bar"

                BarContent {
                    id: bar
                    anchors.fill: parent
                    now: clock.date
                    controlCenterOpen: controlCenter.open
                    updates: store.updates.length
                    onLauncherRequested: launcher.toggle()
                    onControlCenterRequested: controlCenter.toggle()
                    onNotificationCenterRequested: notificationCenter.toggle()
                    onUpdatesRequested: store.show("updates")
                }
            }

            Dock {
                visible: Sys.layout !== "windows"
                screen: perScreen.modelData
            }

            Widgets {
                visible: perScreen.modelData === Quickshell.screens[0] // the first screen only
                screen: perScreen.modelData
                now: clock.date
            }

            Taskbar {
                visible: Sys.layout === "windows"
                screen: perScreen.modelData
                now: clock.date
                controlCenterOpen: controlCenter.open
                onLauncherRequested: launcher.toggle()
                onControlCenterRequested: controlCenter.toggle()
                onNotificationCenterRequested: notificationCenter.toggle()
            }
        }
    }

    ControlCenter {
        id: controlCenter
        onLockRequested: lock.lock()
    }

    NotificationCenter {
        id: notificationCenter
        now: clock.date
    }

    Banners {
        now: clock.date
        suppressed: notificationCenter.open || lock.locked
    }

    Osd {
        suppressed: controlCenter.open || lock.locked
    }

    Lock {
        id: lock
        now: clock.date
    }

    Launcher {
        id: launcher
    }

    Switcher {
        id: switcher
    }

    Overview {
        id: overview
    }

    CaptureBar {
        id: captureBar
    }

    Markup {}

    IpcHandler {
        target: "capture"
        function toggle(): void {
            captureBar.toggle();
        }
    }

    Monitor {
        id: monitor
    }

    Tweaks {
        id: tweaks
    }

    Store {
        id: store
    }

    Welcome {
        onApplyTheme: theme => tweaks.applyTheme(theme)
    }

    GlobalShortcut {
        appid: "divine"
        name: "launcher"
        description: "Toggle the launcher"
        onPressed: launcher.toggle()
    }

    GlobalShortcut {
        appid: "divine"
        name: "clipboard"
        description: "Search the clipboard history"
        onPressed: launcher.toggleClipboard()
    }

    GlobalShortcut {
        appid: "divine"
        name: "switcher"
        description: "Switch to the next app (Alt+Tab)"
        onPressed: switcher.step(1)
    }

    GlobalShortcut {
        appid: "divine"
        name: "switcher-back"
        description: "Switch to the previous app (Alt+Shift+Tab)"
        onPressed: switcher.step(-1)
    }

    GlobalShortcut {
        appid: "divine"
        name: "switcher-commit"
        description: "Go to the chosen app (releasing Alt)"
        onPressed: switcher.commit()
    }

    GlobalShortcut {
        appid: "divine"
        name: "overview"
        description: "Toggle the window overview"
        onPressed: overview.toggle()
    }

    GlobalShortcut {
        appid: "divine"
        name: "capture"
        description: "Screenshot and screen recording bar"
        onPressed: captureBar.toggle()
    }

    GlobalShortcut {
        appid: "divine"
        name: "control-center"
        description: "Toggle the Control Center"
        onPressed: controlCenter.toggle()
    }

    GlobalShortcut {
        appid: "divine"
        name: "monitor"
        description: "Toggle the System Monitor"
        onPressed: monitor.toggle()
    }

    GlobalShortcut {
        appid: "divine"
        name: "tweaks"
        description: "Toggle Settings"
        onPressed: tweaks.toggle()
    }

    GlobalShortcut {
        appid: "divine"
        name: "notifications"
        description: "Toggle the Notification Center"
        onPressed: notificationCenter.toggle()
    }

    GlobalShortcut {
        appid: "divine"
        name: "lock"
        description: "Lock the screen"
        onPressed: lock.lock()
    }

    // hypridle (Settings > Power) turns the screens off and back on through here.
    IpcHandler {
        target: "screen"
        function off(): void {
            Hyprland.dispatch('hl.dsp.dpms({ action = "off" })');
        }
        function on(): void {
            Hyprland.dispatch('hl.dsp.dpms({ action = "on" })');
        }
    }

    // hyprsunset runs Night Light's schedule and calls back at each switch, so the toggles follow.
    IpcHandler {
        target: "nightlight"
        function sync(): void {
            Sys.syncNightLight();
        }
    }

    // Brightness keys come here (not straight to brightnessctl) so the OSD can show the level.
    GlobalShortcut {
        appid: "divine"
        name: "brightness-up"
        onPressed: Sys.stepBrightness(0.05)
    }

    GlobalShortcut {
        appid: "divine"
        name: "brightness-down"
        onPressed: Sys.stepBrightness(-0.05)
    }
}
