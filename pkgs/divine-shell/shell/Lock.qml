import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The lock screen: an ext-session-lock surface on every screen, unlocked only by a PAM success
// ("divine-lock", which includes login, so faillock applies). If the shell dies while locked,
// Hyprland keeps the session locked. Super+L, the Control Center and hypridle lock it.
Scope {
    id: root

    property date now: new Date()
    property string message: ""
    property string pending: "" // the typed password, held only until PAM asks for it
    readonly property bool locked: session.locked

    signal failed

    function lock() {
        message = "";
        session.locked = true;
    }
    function tryUnlock(password) {
        if (pam.active) // an empty password is PAM's call (the live ISO user has none)
            return;
        pending = password;
        message = "";
        if (!pam.start()) {
            pending = "";
            message = "Authentication couldn't start.";
            failed();
        }
    }

    WlSessionLock {
        id: session

        WlSessionLockSurface {
            color: "black"

            LockContent {
                id: content
                anchors.fill: parent
                wallpaper: Sys.wallpaper
                now: root.now
                clock24: Sys.clock24
                userName: Sys.fullName
                avatar: Sys.face
                busy: pam.active
                message: root.message
                onSubmit: password => root.tryUnlock(password)

                Connections {
                    target: root
                    function onFailed() {
                        content.fail();
                    }
                }
            }
        }
    }

    PamContext {
        id: pam
        config: "divine-lock"

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root.pending);
                root.pending = "";
            } else if (pam.messageIsError) {
                root.message = pam.message; // e.g. faillock: the account is locked for some minutes
            }
        }
        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success) {
                root.message = "";
                session.locked = false;
            } else {
                if (!root.message)
                    root.message = "Incorrect password";
                root.failed();
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            root.lock();
        }
    }
}
