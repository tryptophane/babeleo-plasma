/*
 * Babeleo - KDE Plasma 6 Plasmoid
 * Config page registration.
 *
 * In Plasma 6, custom config pages are registered here and appear
 * as sidebar items in the standard Plasma settings dialog.
 * The "Keyboard Shortcuts" and "About" pages are added automatically by Plasma.
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nd("plasma_applet_babeleo", "Search Engines")
        icon: "internet-services"
        source: "configSearchEngines.qml"
    }
    ConfigCategory {
        name: i18nd("plasma_applet_babeleo", "Shortcuts")
        icon: "preferences-desktop-keyboard"
        source: "configShortcuts.qml"
        // The manual query shortcut is a global shortcut — only meaningful when the
        // applet lives in a panel (formFactor != 0). Hide this page for desktop widgets.
        visible: Plasmoid.formFactor !== 0
    }
}
