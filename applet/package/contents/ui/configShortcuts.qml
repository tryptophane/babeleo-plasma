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

    Kirigami.FormLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

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
