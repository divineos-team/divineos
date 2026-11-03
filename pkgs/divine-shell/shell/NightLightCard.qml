import QtQuick
import QtQuick.Layouts

// Settings > Displays > Night Light: warmer colours by hand or on a schedule (hyprsunset).
SettingsCard {
    id: card

    required property var settings
    readonly property var night: settings.nightLight
    readonly property var schedule: night.schedule ?? null
    function hour(time) {
        return +time.split(":")[0];
    }

    SettingRow {
        title: "Night Light"
        hint: card.schedule ? "Turning it on or off here lasts until the schedule's next switch." : "Warmer colours, easier on the eyes at night. Also in Control Center."
        Segmented {
            options: [{ label: "On", value: true }, { label: "Off", value: false }]
            value: card.night.on
            onPicked: v => card.settings.setNightLight(v)
        }
    }
    SettingRow {
        title: "Schedule"
        hint: card.schedule ? `Every day from ${card.schedule.from} to ${card.schedule.to}.` : "None: only when you turn it on."
        Segmented {
            options: [{ label: "Off", value: false }, { label: "Custom", value: true }]
            value: card.schedule !== null
            onPicked: v => card.settings.setNightSchedule(v ? { from: "21:00", to: "7:00" } : null)
        }
    }
    SettingRow {
        visible: card.schedule !== null
        title: "Turns on at"
        SettingSlider {
            to: 23
            value: card.hour(card.schedule?.from ?? "21")
            suffix: ":00"
            onMoved: v => card.settings.setNightSchedule({ from: `${v}:00`, to: card.schedule.to })
        }
    }
    SettingRow {
        visible: card.schedule !== null
        title: "Turns off at"
        SettingSlider {
            to: 23
            value: card.hour(card.schedule?.to ?? "7")
            suffix: ":00"
            onMoved: v => card.settings.setNightSchedule({ from: card.schedule.from, to: `${v}:00` })
        }
    }
    SettingRow {
        title: "Warmth"
        hint: "In kelvin: lower is warmer. Screenshots keep the true colours."
        SettingSlider {
            from: 2500
            to: 6000
            step: 100
            value: card.night.temp
            suffix: " K"
            onMoved: v => card.settings.setNightTemp(v)
        }
    }
}
