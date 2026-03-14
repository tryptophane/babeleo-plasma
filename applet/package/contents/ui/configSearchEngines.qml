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
 *   Fetch icon:  Plasmoid.self.fetchIcon() → async signal → saveEngine() directly
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
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: root

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
        engineModel.setProperty(currentIndex, "position", mainMenuRadio.checked ? "0" : "1")
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
        mainMenuRadio.checked = (eng.position === "0")
        otherRadio.checked    = (eng.position !== "0")
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
            fetchButton.enabled = true
            fetchButton.text = i18nd("plasma_applet_babeleo","Fetch Icon")
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
            // Save the icon immediately to KConfig — no Apply click needed.
            // The icon file is already on disk; we just persist the path reference.
            for (let i = 0; i < engineModel.count; i++) {
                const eng = engineModel.get(i)
                if (eng.name === engineName) {
                    Plasmoid.self.saveEngine(engineName, engineName, eng.url, iconPath,
                                            eng.position, eng.hidden)
                    // Also update the snapshot so this no longer counts as a change.
                    for (let j = 0; j < originalSnapshot.length; j++) {
                        if (originalSnapshot[j].name === engineName) {
                            const s = originalSnapshot[j]
                            originalSnapshot[j] = { name: s.name, url: s.url, icon: iconPath,
                                                    position: s.position, hidden: s.hidden }
                            break
                        }
                    }
                    break
                }
            }
            unsavedChanges = !modelMatchesOriginal()
        }
    }

    // -------------------------------------------------------------------------
    // Layout
    // -------------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
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

                ListView {
                    id: engineList
                    model: engineModel
                    clip: true

                    highlight: Rectangle {
                        color: Kirigami.Theme.highlightColor
                        radius: 3
                        opacity: 0.6
                    }
                    highlightMoveDuration: 0

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
                            icon: "babelfishleo", position: "1", hidden: false
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
        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: Kirigami.Theme.separatorColor
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
    }
}
