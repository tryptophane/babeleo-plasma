// SPDX-FileCopyrightText: 2009 Pascal Pollet <pascal@bongosoft.de>
// SPDX-License-Identifier: GPL-2.0-or-later

/*
 * Babeleo - Search Engines configuration page
 *
 * Appears as "Search Engines" in the standard Plasma settings dialog sidebar.
 *
 * Architecture (local-model pattern):
 *   All edits go into the local ListModel only - C++ is never touched until
 *   the user explicitly clicks Apply or OK (saveConfig() is called by Plasma).
 *   This means Cancel correctly discards everything without any cleanup.
 *
 * Data flow:
 *   Load:        Plasmoid.self.engineList() → engineModel + originalSnapshot
 *   Edit form:   form fields → engineModel (via commitCurrentToModel())
 *   Switch item: commitCurrentToModel(), then loadFormFromModel(newIndex)
 *   Add/Delete:  engineModel only (no C++ calls)
 *   Fetch icon:  Plasmoid.self.fetchIcon() → async signal → update model + unsavedChanges
 *   Apply/OK:    saveConfig() → compare model with originalEngineNames →
 *                deleteEngine() for removed, saveEngine() for all current →
 *                rebuildAfterConfigChange()
 *
 * Change detection:
 *   The "unsavedChanges" property is what Plasma 6 binds the Apply button to
 *   (via unsavedChangesChanged signal in AppletConfiguration.qml). It is set
 *   dynamically by comparing the full model state against originalSnapshot.
 *   This allows the Apply button to be re-disabled when the user reverts
 *   changes back to the original values.
 *   We deliberately never emit the "configurationChanged" signal, because that
 *   sets wasConfigurationChangedSignalSent=true permanently in Plasma's dialog,
 *   preventing the Apply button from ever being disabled again until OK/Cancel.
 *
 * The "loading" flag suppresses onTextChanged / onCheckedChanged handlers
 * while we populate form fields programmatically.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import QtQuick.Dialogs
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: root

    // cfg_* properties: Plasma reads these from config on init and writes them back
    // on Apply/OK via saveConfig(). Declaring all entries from main.xml suppresses
    // "Setting initial properties failed" warnings. This page manages engines and
    // currentEngine via saveConfig(); cfg_doubleClickMode is unused here.
    property var    cfg_engines
    property var    cfg_enginesDefault
    property string cfg_currentEngine
    property string cfg_currentEngineDefault
    property bool   cfg_doubleClickMode
    property bool   cfg_doubleClickModeDefault

    // Page title shown in the Plasma settings dialog sidebar.
    property string title: i18nd("plasma_applet_babeleo", "Search Engines")

    // Standard Plasma config page interface.
    // unsavedChanges is read by AppletConfiguration.qml to enable/disable Apply.
    // We never emit configurationChanged signal — see header comment.
    signal configurationChanged
    property bool unsavedChanges: false

    // -------------------------------------------------------------------------
    // Internal state
    // -------------------------------------------------------------------------

    // Suppresses form field change handlers during programmatic population.
    property bool loading: false

    // Index of the engine currently shown in the form
    property int currentIndex: -1

    // Original engine names from C++ at load time, used in saveConfig() to
    // detect which engines were deleted (present in original but not in model).
    property var originalEngineNames: []

    // Full snapshot of engine data at load time (or after last Apply).
    // Used by modelMatchesOriginal() to detect real changes vs. reverts.
    property var originalSnapshot: []

    // Flag to indicate if we're currently fetching all icons, to manage button states and text.
    property bool fetchingAllIcons: false

    // Temporary list of engines without icons, used during fetchAllIcons() to determine when the last icon has been fetched.
    property var enginesWithoutIcons: []

    ListModel {
        id: engineModel
    }

    // -------------------------------------------------------------------------
    // Data functions
    // -------------------------------------------------------------------------

    // Populate the local model from C++. Called once on load.
    function loadAllEngines() {
        engineModel.clear()
        const list = Plasmoid.self.engineList()
        list.sort((a, b) => {
            const aMain = (a.position === "main" || a.position === "0")
            const bMain = (b.position === "main" || b.position === "0")
            if (aMain !== bMain) return aMain ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        originalEngineNames = list.map(e => e.name)
        originalSnapshot = list.map(e => ({
            name: e.name, url: e.url, icon: e.icon,
            position: e.position, hidden: e.hidden
        }))
        for (const eng of list) {
            engineModel.append({
                name:     eng.name,
                url:      eng.url,
                icon:     eng.icon,
                position: eng.position,
                hidden:   eng.hidden
            })
        }
    }

    // Write current form values into the local model (no C++ calls).
    // Called before switching to another engine or before saveConfig().
    function commitCurrentToModel() {
        if (currentIndex < 0 || currentIndex >= engineModel.count) return
        const newName = nameField.text.trim()
        if (!newName) return
        engineModel.setProperty(currentIndex, "name",     newName)
        engineModel.setProperty(currentIndex, "url",      urlField.text)
        engineModel.setProperty(currentIndex, "icon",     iconField.text)
        engineModel.setProperty(currentIndex, "position", mainMenuRadio.checked ? "main" : "submenu")
        engineModel.setProperty(currentIndex, "hidden",   hideBox.checked)
    }

    // Load form fields from the local model at the given index.
    // Sets loading = true so form field handlers don't trigger change detection.
    function loadFormFromModel(index) {
        if (index < 0 || index >= engineModel.count) return
        loading = true
        const eng = engineModel.get(index)
        nameField.text        = eng.name
        urlField.text         = eng.url
        iconField.text        = eng.icon
        hideBox.checked       = eng.hidden
        // Accept both "main" (new) and "0" (legacy config from older installs).
        mainMenuRadio.checked = (eng.position === "main" || eng.position === "0")
        otherRadio.checked    = (eng.position !== "main" && eng.position !== "0")
        loading = false
        currentIndex = index
    }

    // Switch to a different engine in the list, committing any pending changes first.
    function switchToEngine(index) {
        if (index === currentIndex) return
        commitCurrentToModel()
        engineList.currentIndex = index
        loadFormFromModel(index)
        // Don't reset unsavedChanges — the user may have already changed other engines.
    }

    // Returns true if the current model state matches the original snapshot exactly.
    function modelMatchesOriginal() {
        if (engineModel.count !== originalSnapshot.length) return false
        const origMap = {}
        for (const e of originalSnapshot) origMap[e.name] = e
        for (let i = 0; i < engineModel.count; i++) {
            const eng = engineModel.get(i)
            const orig = origMap[eng.name]
            if (!orig) return false
            if (eng.url      !== orig.url      ||
                eng.icon     !== orig.icon     ||
                eng.position !== orig.position ||
                eng.hidden   !== orig.hidden) return false
        }
        return true
    }

    // Called from form field change handlers. Commits form to model, then
    // updates unsavedChanges based on a full comparison with the original snapshot.
    function checkForChanges() {
        commitCurrentToModel()
        unsavedChanges = !modelMatchesOriginal()
    }

    // Called by Plasma when the user clicks Apply or OK.
    // Syncs the complete local model to C++.
    function saveConfig() {
        // Commit whatever is currently in the form to the model
        commitCurrentToModel()

        // Find engines that existed in C++ but are no longer in the model.
        // (user deleted them during this config session)
        const newNames = []
        for (let i = 0; i < engineModel.count; i++) {
            newNames.push(engineModel.get(i).name)
        }
        for (const origName of originalEngineNames) {
            if (!newNames.includes(origName)) {
                Plasmoid.self.deleteEngine(origName)
            }
        }

        // Save all engines from the local model to C++.
        // saveEngine("", newName, ...) creates a new entry.
        // saveEngine(origName, newName, ...) replaces the existing entry.
        for (let i = 0; i < engineModel.count; i++) {
            const eng = engineModel.get(i)
            const oldName = originalEngineNames.includes(eng.name) ? eng.name : ""
            Plasmoid.self.saveEngine(oldName, eng.name, eng.url, eng.icon,
                                     eng.position, eng.hidden)
        }

        // Rebuild the applet's context menu and emit signals
        Plasmoid.self.rebuildAfterConfigChange()

        // Update our baseline for the next Apply click
        originalEngineNames = newNames
        originalSnapshot = []
        for (let i = 0; i < engineModel.count; i++) {
            const eng = engineModel.get(i)
            originalSnapshot.push({ name: eng.name, url: eng.url, icon: eng.icon,
                                    position: eng.position, hidden: eng.hidden })
        }
        unsavedChanges = false

        // Reload engines list and keep the currently edited engine selected if it still exists
        const lastSelectedName = engineModel.get(currentIndex)?.name
        this.loadAllEngines()
        for (let i = 0; i < engineModel.count; i++) {
            if (engineModel.get(i).name === lastSelectedName) {
                engineList.currentIndex = i   
                loadFormFromModel(i)
                break
            }
        }
        // If the currently selected engine was deleted, switch to the first one if any remain
        let selectedEngineStillPresent = false
        for (let i = 0; i < engineModel.count; i++) {
            if (engineModel.get(i).name === Plasmoid.self.currentEngine) {
                selectedEngineStillPresent = true
                break
            }
        }
        if (!selectedEngineStillPresent && engineModel.count > 0) {
            Plasmoid.self.setEngine(engineModel.get(0).name)
        }
    }

    Component.onCompleted: {
        loadAllEngines()
        if (engineModel.count > 0) {
            engineList.currentIndex = 0
            loadFormFromModel(0)
        }
    }

    // Receive async fetchIcon() result
    Connections {
        target: Plasmoid.self
        function onIconFetched(engineName, iconPath) {
            if (!fetchingAllIcons) {
                fetchButton.enabled = true
                fetchButton.text = i18nd("plasma_applet_babeleo","Fetch Icon")
            }
            if (fetchingAllIcons && engineName === enginesWithoutIcons[enginesWithoutIcons.length - 1].name) {
                fetchingAllIcons = false
                enginesWithoutIcons = []
                fetchAllButton.enabled = true
                fetchButton.enabled = true
                fetchAllButton.text = i18nd("plasma_applet_babeleo", "Fetch All Icons")
            }
            if (!iconPath) return

            // Update the local model entry
            for (let i = 0; i < engineModel.count; i++) {
                if (engineModel.get(i).name === engineName) {
                    engineModel.setProperty(i, "icon", iconPath)
                    break
                }
            }
            // Update form field if this engine is currently displayed (suppressed)
            if (currentIndex >= 0 && engineModel.get(currentIndex).name === engineName) {
                loading = true
                iconField.text = iconPath
                loading = false
            }
            // The icon file is already on disk. The path reference will be saved
            // to KConfig when the user clicks Apply or OK.
            unsavedChanges = !modelMatchesOriginal()
        }
    }

    function getEnginesWithoutIcons() {
        const engines = []
        for (let i = 0; i < engineModel.count; i++) {
            const eng = engineModel.get(i)
            if (!eng.icon || eng.icon === "babelfishleo" || (!eng.icon.startsWith('/')
                && !eng.icon.startsWith("file://"))) {
                engines.push(eng)
            }
        }
        return engines
    }

    function fetchAllIcons() {
        fetchingAllIcons = true
        fetchAllButton.enabled = false
        fetchButton.enabled = false
        fetchAllButton.text = i18nd("plasma_applet_babeleo","Downloading\u2026")
        enginesWithoutIcons = getEnginesWithoutIcons()
        for (let i = 0; i < enginesWithoutIcons.length; i++) {
            const eng = enginesWithoutIcons[i]
            Plasmoid.self.fetchIcon(eng.name, eng.url)
        }
    }

    // -------------------------------------------------------------------------
    // Export / Import
    // -------------------------------------------------------------------------

    // Build a JSON array from the local model (no icon, matches engines.json format).
    function doExport(fileUrl) {
        const engines = []
        for (let i = 0; i < engineModel.count; i++) {
            const e = engineModel.get(i)
            engines.push({ 
                name: e.name, 
                url: e.url, 
                icon: e.icon.startsWith('babelfishleo') ? e.icon : 'babelfishleo',
                position: e.position,
                hidden: e.hidden }
            )
        }
        const err = Plasmoid.self.writeFile(fileUrl.toString(),
                                            JSON.stringify(engines, null, 4))
        if (err) {
            exportImportMessage.type = Kirigami.MessageType.Error
            exportImportMessage.text = i18nd("plasma_applet_babeleo", "Export failed: %1").arg(err)
            exportImportMessage.visible = true
        }
    }

    // Replace the local model with engines parsed from a JSON file.
    function doImport(fileUrl) {
        const content = Plasmoid.self.readFile(fileUrl.toString())
        if (!content) {
            exportImportMessage.type = Kirigami.MessageType.Error
            exportImportMessage.text = i18nd("plasma_applet_babeleo", "Could not read the file.")
            exportImportMessage.visible = true
            return
        }
        let parsed
        try { parsed = JSON.parse(content) } catch (e) {
            exportImportMessage.type = Kirigami.MessageType.Error
            exportImportMessage.text = i18nd("plasma_applet_babeleo", "Invalid JSON: %1").arg(e.message)
            exportImportMessage.visible = true
            return
        }
        if (!Array.isArray(parsed) || parsed.length === 0) {
            exportImportMessage.type = Kirigami.MessageType.Error
            exportImportMessage.text = i18nd("plasma_applet_babeleo", "No engines found in the file.")
            exportImportMessage.visible = true
            return
        }
        engineModel.clear()
        for (const eng of parsed) {
            engineModel.append({
                name:     String(eng.name     || ""),
                url:      String(eng.url      || ""),
                icon:     String(eng.icon     || "babelfishleo"),
                position: String(eng.position || "submenu"),
                hidden:   Boolean(eng.hidden)
            })
        }
        if (engineModel.count > 0) {
            engineList.currentIndex = 0
            loadFormFromModel(0)
        } else {
            currentIndex = -1
        }
        unsavedChanges = !modelMatchesOriginal()
    }

    FileDialog {
        id: exportFileDialog
        fileMode: FileDialog.SaveFile
        title: i18nd("plasma_applet_babeleo", "Export Search Engines")
        nameFilters: [i18nd("plasma_applet_babeleo", "JSON files (*.json)"),
                      i18nd("plasma_applet_babeleo", "All files (*)")]
        defaultSuffix: "json"
        currentFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
        onAccepted: doExport(selectedFile)
    }

    FileDialog {
        id: importFileDialog
        fileMode: FileDialog.OpenFile
        title: i18nd("plasma_applet_babeleo", "Import Search Engines")
        nameFilters: [i18nd("plasma_applet_babeleo", "JSON files (*.json)"),
                      i18nd("plasma_applet_babeleo", "All files (*)")]
        onAccepted: doImport(selectedFile)
    }

    // -------------------------------------------------------------------------
    // Layout
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.largeSpacing

        // Left panel: engine list + Add/Delete buttons
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            PC3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing

                ListView {
                    id: engineList
                    model: engineModel
                    clip: true

                    delegate: QC.ItemDelegate {
                        width: ListView.view.width
                        highlighted: ListView.isCurrentItem

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: model.icon
                                implicitWidth:  Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                opacity: model.hidden ? 0.4 : 1.0
                            }
                            PC3.Label {
                                text: model.name
                                color: model.hidden
                                    ? Kirigami.Theme.disabledTextColor
                                    : model.position === 'main' && !highlighted
                                        ? Kirigami.Theme.highlightColor
                                        : Kirigami.Theme.textColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        onClicked: switchToEngine(index)
                    }
                }
            }

            // Add / Delete buttons — equal width, with margins
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                Layout.rightMargin: Kirigami.Units.smallSpacing * 2
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                PC3.Button {
                    icon.name: "list-add"
                    text: i18nd("plasma_applet_babeleo","Add")
                    Layout.fillWidth: true
                    onClicked: {
                        commitCurrentToModel()
                        // Add a new entry to the local model only (no C++ call)
                        const newName = i18nd("plasma_applet_babeleo","New Engine")
                        engineModel.append({
                            name: newName, url: "https://",
                            icon: "babelfishleo", position: "submenu", hidden: false
                        })
                        const newIdx = engineModel.count - 1
                        engineList.currentIndex = newIdx
                        loadFormFromModel(newIdx)
                        unsavedChanges = true
                    }
                }

                PC3.Button {
                    icon.name: "list-remove"
                    text: i18nd("plasma_applet_babeleo","Delete")
                    Layout.fillWidth: true
                    enabled: currentIndex >= 0 && engineModel.count > 0
                    onClicked: {
                        if (currentIndex < 0) return
                        // Remove from local model only (no C++ call)
                        engineModel.remove(currentIndex)
                        const newIdx = Math.max(0, Math.min(currentIndex, engineModel.count - 1))
                        if (engineModel.count > 0) {
                            engineList.currentIndex = newIdx
                            loadFormFromModel(newIdx)
                        } else {
                            currentIndex = -1
                        }
                        unsavedChanges = !modelMatchesOriginal()
                    }
                }
            }
        }

        // Visual divider
        Kirigami.Separator {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
        }

        // Right panel: edit form
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            enabled: currentIndex >= 0 && engineModel.count > 0

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                PC3.Label { text: i18nd("plasma_applet_babeleo","Name:") }
                PC3.TextField {
                    id: nameField
                    Layout.fillWidth: true
                    onTextChanged: if (!loading) checkForChanges()
                }

                Item { Layout.fillWidth: true; implicitHeight: Kirigami.Units.largeSpacing * 2}

                PC3.Label { text: i18nd("plasma_applet_babeleo","URL (%s = search term):") }
                PC3.TextField {
                    id: urlField
                    Layout.fillWidth: true
                    onTextChanged: if (!loading) checkForChanges()
                }

                Item { Layout.fillWidth: true; implicitHeight: Kirigami.Units.largeSpacing * 2 }

                PC3.Label { text: i18nd("plasma_applet_babeleo","Icon:") }
                RowLayout {
                    Layout.fillWidth: true
                    PC3.TextField {
                        id: iconField
                        Layout.fillWidth: true
                        placeholderText: i18nd("plasma_applet_babeleo","Theme name or file path")
                        onTextChanged: if (!loading) checkForChanges()
                    }
                    PC3.Button {
                        id: fetchButton
                        text: i18nd("plasma_applet_babeleo","Fetch Icon")
                        icon.name: "download"
                        onClicked: {
                            commitCurrentToModel()
                            fetchButton.enabled = false
                            fetchButton.text = i18nd("plasma_applet_babeleo","Downloading\u2026")
                            Plasmoid.self.fetchIcon(nameField.text, urlField.text)
                        }
                    }
                }

                Item { Layout.fillWidth: true; implicitHeight: Kirigami.Units.largeSpacing * 2 }

                PC3.Label { text: i18nd("plasma_applet_babeleo","Visibility:") }
                PC3.CheckBox {
                    id: hideBox
                    text: i18nd("plasma_applet_babeleo","Hide this search engine")
                    onCheckedChanged: if (!loading) checkForChanges()
                }

                Item { Layout.fillWidth: true; implicitHeight: Kirigami.Units.largeSpacing * 2 }

                PC3.Label { text: i18nd("plasma_applet_babeleo","Position:") }
                RowLayout {
                    PC3.RadioButton {
                        id: mainMenuRadio
                        text: i18nd("plasma_applet_babeleo","Main menu")
                        onCheckedChanged: if (!loading && checked) checkForChanges()
                    }
                    PC3.RadioButton {
                        id: otherRadio
                        Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                        text: i18nd("plasma_applet_babeleo","More search engines submenu")
                        onCheckedChanged: if (!loading && checked) checkForChanges()
                    }
                }
            }

            Item { Layout.fillHeight: true }  // push form to top
        }
    } // RowLayout

    Kirigami.Separator { Layout.fillWidth: true }

    // Footer: Export / Import buttons, full width below both panels
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Kirigami.InlineMessage {
            id: exportImportMessage
            Layout.fillWidth: true
            showCloseButton: true
            visible: false
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PC3.Button {
                id: fetchAllButton
                text: i18nd("plasma_applet_babeleo", "Fetch All Icons")
                icon.name: "download"
                onClicked:  fetchAllIcons()
                PC3.ToolTip.text: i18nd("plasma_applet_babeleo", "Fetch missing favicons from their respective websites, if available.")
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Item { Layout.fillWidth: true }

            PC3.Button {
                text: i18nd("plasma_applet_babeleo", "Export…")
                icon.name: "document-export"
                onClicked: exportFileDialog.open()
                PC3.ToolTip.text: i18nd("plasma_applet_babeleo", "Export the search engine list to a JSON file. Note: custom icons fetched from websites will not be included.")
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PC3.Button {
                text: i18nd("plasma_applet_babeleo", "Import…")
                icon.name: "document-import"
                onClicked: importFileDialog.open()
                PC3.ToolTip.text: i18nd("plasma_applet_babeleo", "Import search engines from a JSON file. This will completely replace your current list.")
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }

    } // ColumnLayout (outer)
}
