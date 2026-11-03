//@ pragma AppId divine-greeter
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// divineOS login screen: the lock screen's look, with account switching and Restart / Shut Down.
// greetd runs it as the "greeter" user inside the cage kiosk (/usr/bin/divine-greeter); a
// successful login starts Hyprland. Only Theme-based views are used here, never Sys, so none
// of the desktop's services start before anyone has logged in.
ShellRoot {
    id: root

    property var users: [] // [{ name, fullName }], the last one to log in first
    property int index: 0
    property string message: ""
    property string pending: "" // the typed password, held only until greetd asks for it
    readonly property var user: users[index] ?? null
    readonly property bool busy: Greetd.state !== GreetdState.Inactive

    signal failed

    function login(password) {
        if (!user || busy)
            return;
        pending = password;
        message = "";
        Greetd.createSession(user.name);
    }
    function fail(text) {
        pending = "";
        message = text;
        failed();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Written after each login so that account comes first next time.
    FileView {
        id: lastUser
        path: "/var/cache/divine-greeter/last-user"
        blockLoading: true
    }

    // Accounts that can log in: uid 1000–59999 with a real shell.
    Process {
        running: true
        command: ["getent", "passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                const last = lastUser.text().trim();
                const users = text.split("\n").map(l => l.split(":")).filter(f => {
                    const uid = parseInt(f[2]);
                    return f.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6]);
                }).map(f => ({ name: f[0], fullName: f[4].split(",")[0] || f[0] }));
                users.sort((a, b) => (b.name === last) - (a.name === last));
                root.users = users;
            }
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (error) {
                root.message = message; // e.g. faillock: the account is locked for some minutes
            }
        }
        function onAuthFailure(message) {
            root.fail(root.message || "Incorrect password");
        }
        function onError(error) { // greetd ends the session on errors; just say what happened
            root.fail(error);
        }
        function onReadyToLaunch() {
            lastUser.setText(root.user.name + "\n");
            Greetd.launch(["start-hyprland"]);
        }
    }

    FloatingWindow { // cage shows it fullscreen
        title: "divineOS"
        color: "black"

        LockContent {
            id: content
            anchors.fill: parent
            now: clock.date
            wallpaper: "file:///usr/share/backgrounds/divineos/default.png"
            userName: root.user?.fullName ?? ""
            userCount: root.users.length
            avatar: root.user ? "file:///var/lib/AccountsService/icons/" + root.user.name : ""
            busy: root.busy
            message: root.message
            showPower: true
            onSubmit: password => root.login(password)
            onSwitchUser: delta => {
                root.index = (root.index + delta + root.users.length) % root.users.length;
                root.message = "";
            }
            onReboot: Quickshell.execDetached(["systemctl", "reboot"])
            onPoweroff: Quickshell.execDetached(["systemctl", "poweroff"])

            Connections {
                target: root
                function onFailed() {
                    content.fail();
                }
            }
        }
    }
}
