/*
 * Babeleo - KDE Plasma 6 Plasmoid
 * Config page: keyboard shortcuts.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols
import org.kde.plasma.plasmoid

Item {
    property bool unsavedChanges: false

    function saveConfig() {
        Plasmoid.self.setManualQueryShortcut(shortcutItem.keySequence)
        unsavedChanges = false
    }

    ColumnLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 0

        Kirigami.Heading {
            Layout.topMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing *3
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            level: 1
            text: i18nd("plasma_applet_babeleo", "Manual Query Shortcut")
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            KeySequenceItem {
                id: shortcutItem
                Kirigami.FormData.label: i18nd("plasma_applet_babeleo", "Open manual query dialog:")
                keySequence: Plasmoid.self.manualQueryShortcut
                patterns: ShortcutPattern.Modifier | ShortcutPattern.ModifierAndKey
                onKeySequenceModified: {
                    unsavedChanges = (keySequence.toString() !== Plasmoid.self.manualQueryShortcut.toString())
                }
            }
        }
    }
}
