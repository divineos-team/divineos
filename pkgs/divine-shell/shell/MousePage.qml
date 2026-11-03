import QtQuick
import QtQuick.Layouts

// Settings > Mouse & Touchpad: pointer speed and feel, scrolling, the primary button, and on
// laptops tap to click and swiping between workspaces. Written to tweaks.lua's input block.
Flickable {
    id: page

    required property var settings
    readonly property var pointer: settings.pointer
    function set(key, value) {
        settings.setPointer({ [key]: value });
    }

    clip: true
    contentHeight: column.implicitHeight

    component OnOff: Segmented {
        options: [{ label: "On", value: true }, { label: "Off", value: false }]
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.gap

        SettingsCard {
            SettingRow {
                title: "Pointer speed"
                hint: "For mice and touchpads; 0 is normal."
                SettingSlider {
                    from: -10
                    to: 10
                    value: Math.round(page.pointer.speed * 10)
                    onMoved: v => page.set("speed", v / 10)
                }
            }
            SettingRow {
                title: "Acceleration"
                hint: "Off: the pointer moves the same distance however fast you move. Many gamers prefer it."
                OnOff { value: !page.pointer.flat; onPicked: v => page.set("flat", !v) }
            }
            SettingRow {
                title: "Natural scrolling"
                hint: "Content follows your fingers, as on a phone."
                OnOff { value: page.pointer.natural; onPicked: v => page.set("natural", v) }
            }
            SettingRow {
                title: "Primary button"
                Segmented {
                    options: [{ label: "Left", value: false }, { label: "Right", value: true }]
                    value: page.pointer.leftHanded
                    onPicked: v => page.set("leftHanded", v)
                }
            }
        }

        SettingsCard {
            visible: page.settings.hasTouchpad
            Label { Layout.topMargin: 10; text: "Touchpad"; font.weight: Font.DemiBold }
            SettingRow {
                title: "Tap to click"
                hint: "Tap with one finger to click, two to right-click."
                OnOff { value: page.pointer.tap; onPicked: v => page.set("tap", v) }
            }
            SettingRow {
                title: "Natural scrolling"
                OnOff { value: page.pointer.touchNatural; onPicked: v => page.set("touchNatural", v) }
            }
            SettingRow {
                title: "Ignore while typing"
                hint: "So a palm on the touchpad doesn't move the cursor."
                OnOff { value: page.pointer.typing; onPicked: v => page.set("typing", v) }
            }
            SettingRow {
                title: "Swipe between workspaces"
                hint: "Swipe left or right with this many fingers."
                Segmented {
                    options: [{ label: "Off", value: 0 }, { label: "3 fingers", value: 3 }, { label: "4 fingers", value: 4 }]
                    value: page.pointer.swipe
                    onPicked: v => page.set("swipe", v)
                }
            }
        }
    }
}
