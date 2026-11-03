import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// divineDE shell: wallpaper, menu bar and dock on every monitor; one Control Center, launcher,
// Notification Center, notification banners, OSD, lock screen, app switcher, overview,
// capture bar and the Welcome guide. Run with `qs -p /usr/share/divine-shell`. Hyprland binds
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
                    onLauncherRequested: launcher.toggle()
                    onControlCenterRequested: controlCenter.toggle()
                    onNotificationCenterRequested: notificationCenter.toggle()
                }
            }

            Dock {
                screen: perScreen.modelData
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

    Monitor {
        id: monitor
    }

    Tweaks {
        id: tweaks
    }

    Welcome {}

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
