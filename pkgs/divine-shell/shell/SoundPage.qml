import QtQuick
import QtQuick.Layouts

// Control Center > Sound: where sound goes (speakers, headphones) and where it comes from
// (microphones), plus the microphone's level.
CcPage {
    id: page

    title: "Sound"

    CcPage.Heading { text: "Output" }
    Repeater {
        model: Sys.outputs
        Choice {
            required property var modelData
            icon: /head(phone|set)|buds|airpods/i.test(Sys.audioName(modelData)) ? Theme.icons.headphones : Theme.icons.speaker
            text: Sys.audioName(modelData)
            on: modelData === Sys.output
            onPicked: Sys.setOutput(modelData)
        }
    }

    CcPage.Heading { text: Sys.inputs.length ? "Input" : "No microphone" }
    Repeater {
        model: Sys.inputs
        Choice {
            required property var modelData
            icon: Theme.icons.mic
            text: Sys.audioName(modelData)
            on: modelData === Sys.input
            onPicked: Sys.setInput(modelData)
        }
    }
    RowLayout {
        visible: Sys.inputs.length > 0
        Layout.topMargin: 4
        Layout.leftMargin: 10
        spacing: 10
        Glyph {
            text: Sys.micMuted ? Theme.icons.micOff : Theme.icons.mic
            font.pixelSize: 18
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: Sys.toggleMic()
            }
        }
        SettingSlider {
            Layout.fillWidth: true
            to: 100
            value: Sys.micMuted ? 0 : Math.round(Sys.micVolume * 100)
            suffix: "%"
            onMoved: v => Sys.setMicVolume(v / 100)
        }
    }
}
