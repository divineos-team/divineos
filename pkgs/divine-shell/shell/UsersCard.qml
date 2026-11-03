import QtQuick
import QtQuick.Layouts

// Settings > Users: every account on this computer, adding one, and who's an administrator.
SettingsCard {
    id: card

    required property var settings
    property bool adding: false
    property bool admin: false
    property bool nameEdited: false // stop deriving the username once it's typed
    property string confirming: "" // the account a second click removes

    readonly property string problem: {
        if (!fullName.text.trim())
            return "Type their name.";
        if (/[:,]/.test(fullName.text))
            return "Names can't contain : or ,.";
        if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(userName.text))
            return "Usernames start with a lowercase letter and have only a-z, 0-9, - and _.";
        if (settings.users.some(u => u.name === userName.text))
            return "That username is taken.";
        if (!password.text)
            return "Choose a password.";
        return password.text === confirm.text ? "" : "The passwords don't match.";
    }
    function reset() {
        adding = admin = nameEdited = false;
        fullName.text = userName.text = password.text = confirm.text = "";
    }

    Label { text: "Users"; font.weight: Font.DemiBold; topPadding: 8 }
    Label { text: "Administrators can install apps and change settings for everyone."; dim: true; font.pixelSize: 12; bottomPadding: 6 }

    Repeater {
        model: card.settings.users
        RowLayout {
            id: user
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            spacing: 12
            Avatar { implicitWidth: 34; implicitHeight: 34; source: "file:///var/lib/AccountsService/icons/" + user.modelData.name; name: user.modelData.fullName }
            Column {
                Layout.fillWidth: true
                spacing: 1
                Label { width: parent.width; text: user.modelData.fullName + (user.modelData.me ? " (you)" : ""); font.weight: Font.Medium }
                Label { width: parent.width; text: user.modelData.name + " · " + (user.modelData.admin ? "Administrator" : "Standard"); dim: true; font.pixelSize: 12 }
            }
            PillButton {
                visible: !user.modelData.me
                text: user.modelData.admin ? "Make Standard" : "Make Administrator"
                primary: false
                onClicked: card.settings.setAdmin(user.modelData.name, !user.modelData.admin)
            }
            PillButton {
                visible: !user.modelData.me
                text: card.confirming === user.modelData.name ? "Remove " + user.modelData.name + "?" : "Remove"
                primary: card.confirming === user.modelData.name
                onClicked: {
                    if (card.confirming === user.modelData.name)
                        card.settings.deleteUser(user.modelData.name);
                    card.confirming = card.confirming === user.modelData.name ? "" : user.modelData.name;
                }
            }
        }
    }
    Label {
        visible: card.confirming !== ""
        Layout.fillWidth: true
        text: "Their files stay in /home/" + card.confirming + "."
        dim: true
        font.pixelSize: 12
    }

    PillButton {
        visible: !card.adding
        Layout.topMargin: 8
        Layout.bottomMargin: 10
        text: "Add User…"
        primary: false
        onClicked: card.adding = true
    }
    GridLayout {
        visible: card.adding
        Layout.fillWidth: true
        Layout.topMargin: 10
        columns: 2
        columnSpacing: 10
        rowSpacing: 10
        Field {
            id: fullName
            Layout.fillWidth: true
            placeholder: "Full name"
            onTextChanged: {
                if (!card.nameEdited)
                    userName.text = text.trim().toLowerCase().split(/\s+/)[0].replace(/[^a-z0-9_-]/g, "");
            }
        }
        Field {
            id: userName
            Layout.fillWidth: true
            placeholder: "Username"
            onTextChanged: card.nameEdited = card.nameEdited || activeFocus
        }
        Field { id: password; Layout.fillWidth: true; placeholder: "Password"; echoMode: TextInput.Password }
        Field { id: confirm; Layout.fillWidth: true; placeholder: "Confirm password"; echoMode: TextInput.Password }
        Segmented {
            options: [{ label: "Standard", value: false }, { label: "Administrator", value: true }]
            value: card.admin
            onPicked: v => card.admin = v
        }
        Row {
            Layout.alignment: Qt.AlignRight
            spacing: 6
            PillButton { text: "Cancel"; primary: false; onClicked: card.reset() }
            PillButton {
                text: "Add"
                enabled: card.problem === ""
                onClicked: {
                    card.settings.addUser(userName.text, fullName.text.trim(), password.text, card.admin);
                    card.reset();
                }
            }
        }
    }
    Label {
        Layout.fillWidth: true
        visible: text !== ""
        topPadding: 6
        bottomPadding: 10
        text: card.adding && fullName.text ? card.problem : card.settings.usersStatus
        dim: true
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
