/*
 * Babeleo - KDE Plasma 6 Plasmoid
 * Config page: click behaviour and keyboard shortcuts.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

Item {
    property bool unsavedChanges: false
    property bool pendingDoubleClickMode: Plasmoid.configuration.doubleClickMode

    function saveConfig() {
        Plasmoid.configuration.doubleClickMode = pendingDoubleClickMode
        Plasmoid.self.setManualQueryShortcut(shortcutItem.keySequence)
        unsavedChanges = false
    }

    // Recompute unsavedChanges by comparing against the currently saved values,
    // so that reverting a change correctly disables the Apply button again.
    function checkUnsavedChanges() {
        unsavedChanges = (pendingDoubleClickMode !== Plasmoid.configuration.doubleClickMode)
                      || (shortcutItem.keySequence.toString() !== Plasmoid.self.manualQueryShortcut.toString())
    }

    ColumnLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: Kirigami.Units.largeSpacing
            rightMargin: Kirigami.Units.largeSpacing
        }
        spacing: Kirigami.Units.largeSpacing

        // ── Click Behavior ───────────────────────────────────────────────────

        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing; Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
    
            PlasmaComponents3.Label {
                text: i18nd("plasma_applet_babeleo", "Click Behavior")
                color: Kirigami.Theme.disabledTextColor
                font.bold: true
            }
            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item { Layout.preferredHeight: Kirigami.Units.smallSpacing; Layout.fillWidth: true }

        QQC2.ButtonGroup { id: clickModeGroup }

        PlasmaComponents3.RadioButton {
            QQC2.ButtonGroup.group: clickModeGroup
            text: i18nd("plasma_applet_babeleo", "Single click: search with clipboard content")
            checked: !pendingDoubleClickMode
            onToggled: if (checked) { pendingDoubleClickMode = false; checkUnsavedChanges() }
        }

        PlasmaComponents3.RadioButton {
            QQC2.ButtonGroup.group: clickModeGroup
            text: i18nd("plasma_applet_babeleo", "Double click: search with clipboard content")
            checked: pendingDoubleClickMode
            onToggled: if (checked) { pendingDoubleClickMode = true; checkUnsavedChanges() }
        }

        // Discreet hint, only visible when double-click mode is selected
        PlasmaComponents3.Label {
            visible: pendingDoubleClickMode
            text: i18nd("plasma_applet_babeleo", "A single left click will open the context menu (same as right click).")
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        // ── Keyboard Shortcut ────────────────────────────────────────────────

        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing * 2; Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: i18nd("plasma_applet_babeleo", "Keyboard Shortcut")
                color: Kirigami.Theme.disabledTextColor
                font.bold: true
            }
            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item { Layout.preferredHeight: Kirigami.Units.smallSpacing; Layout.fillWidth: true }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            KeySequenceItem {
                id: shortcutItem
                Kirigami.FormData.label: i18nd("plasma_applet_babeleo", "Open manual query dialog:")
                keySequence: Plasmoid.self.manualQueryShortcut
                patterns: ShortcutPattern.Modifier | ShortcutPattern.ModifierAndKey
                onKeySequenceModified: checkUnsavedChanges()
            }
        }
    }
}
