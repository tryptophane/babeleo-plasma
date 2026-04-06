/***********************************************************************************
* Babeleo: Plasmoid for translating clipboard content at leo.org.
* Copyright (C) 2009 Pascal Pollet <pascal@bongosoft.de>
*
* Plasma 6 / KDE Frameworks 6 port.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
***********************************************************************************/

#include "babeleo.h"

#include <algorithm>

#include <QApplication>
#include <QClipboard>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

#include <KConfig>
#include <KConfigGroup>
#include <QMouseEvent>
#include <QQuickWindow>
#include <PlasmaQuick/AppletQuickItem>
#include <KGlobalAccel>
#include <KLocalizedString>
#include <KIO/FavIconRequestJob>
#include <KIO/OpenUrlJob>
#include <KJob>
#include <KMessageBox>
#include <KPluginFactory>
#include <KWaylandExtras>
#include <KWindowSystem>
#include <QFutureWatcher>

// Helper function: loads an icon either from the system theme (if it is a name)
// or from a local file (if it is a path starting with '/').
// Necessary because fetchIcon() saves favicons as files, while the
// predefined icons are theme names like "babelfishleo-en".
static QIcon iconFromValue(const QString &iconValue)
{
    if (iconValue.startsWith(QLatin1Char('/'))) {
        return QIcon(iconValue);
    }
    return QIcon::fromTheme(iconValue);
}

Babeleo::Babeleo(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : Plasma::Applet(parent, data, args)
{
}

Babeleo::~Babeleo()
{
    if (m_manualQueryAction) {
        KGlobalAccel::self()->removeAllShortcuts(m_manualQueryAction);
    }

    // Remove the "activate widget N" global shortcut entry that Plasma registers
    // for each applet instance but does not clean up when the applet is removed.
    const QString activateKey = QStringLiteral("activate widget %1").arg(id());
    KConfig kgrc(QStringLiteral("kglobalshortcutsrc"), KConfig::NoGlobals);
    KConfigGroup group = kgrc.group(QStringLiteral("plasmashell"));
    if (group.hasKey(activateKey)) {
        group.deleteEntry(activateKey);
        kgrc.sync();
        // Tell kglobalaccel to drop the in-memory entry as well.
        QDBusConnection::sessionBus().call(
            QDBusMessage::createMethodCall(
                QStringLiteral("org.kde.kglobalaccel"),
                QStringLiteral("/component/plasmashell"),
                QStringLiteral("org.kde.kglobalaccel.Component"),
                QStringLiteral("cleanUp")),
            QDBus::NoBlock);
    }

    qDeleteAll(m_enginesHash);
}

void Babeleo::init()
{
    m_configuration = config();
    m_currentEngine = m_configuration.readEntry("currentEngine", QStringLiteral("Leo En - De"));
    createMenu();
    if (m_enginesHash.contains(m_currentEngine)) {
        setIcon(m_enginesHash.value(m_currentEngine)->getIcon());
    }

    // Register a global shortcut for opening the manual query popup.
    // Note: translating the clipboard is handled by the built-in "Activate widget as if clicked"
    // shortcut (Plasma::Applet::setGlobalShortcut), configurable in the widget's Shortcuts tab.
    m_manualQueryAction = new QAction(i18nd("plasma_applet_babeleo", "Open Babeleo manual query"), this);
    m_manualQueryAction->setObjectName(QStringLiteral("manual-query"));
    KGlobalAccel::setGlobalShortcut(m_manualQueryAction, QKeySequence()); // no default shortcut

    // Restore shortcut from applet config (persists across plasmashell restarts independently
    // of kglobalshortcutsrc, which NoAutoloading never writes to).
    const QString savedShortcut = m_configuration.readEntry("manualQueryShortcut", QString());
    if (!savedShortcut.isEmpty()) {
        m_manualQueryShortcutCache = QKeySequence(savedShortcut);
        KGlobalAccel::self()->setShortcut(m_manualQueryAction, {m_manualQueryShortcutCache}, KGlobalAccel::NoAutoloading);
    } else {
        const auto currentShortcuts = KGlobalAccel::self()->shortcut(m_manualQueryAction);
        m_manualQueryShortcutCache = currentShortcuts.isEmpty() ? QKeySequence() : currentShortcuts.first();
    }

    // kglobalacceld activates the shortcut via two paths simultaneously:
    // - invokeAction on plasmashell's KGlobalAccel D-Bus → triggers QAction::triggered()
    // - globalShortcutPressed signal on the component object
    // Using only the D-Bus signal path to avoid a double-emit (which would toggle the popup
    // open and immediately closed again, making it appear as if nothing happened).
    QDBusConnection::sessionBus().connect(
        QStringLiteral("org.kde.kglobalaccel"),
        QStringLiteral("/component/plasmashell"),
        QStringLiteral("org.kde.kglobalaccel.Component"),
        QStringLiteral("globalShortcutPressed"),
        this,
        SLOT(onDbusShortcutPressed(QString, QString, qlonglong))
    );

    // Notify QML that the engine list is ready. This handles the race condition
    // where QML finishes loading before C++ init() completes (e.g. fresh widget add).
    Q_EMIT enginesChanged();
}

void Babeleo::configChanged()
{
    // Called by Plasma when config changes externally (e.g. from a QML config page).
    // Reload all settings from KConfig and rebuild the context menu.
    m_currentEngine = m_configuration.readEntry("currentEngine", QStringLiteral("Leo En - De"));
    createMenu();
    if (m_enginesHash.contains(m_currentEngine)) {
        setIcon(m_enginesHash.value(m_currentEngine)->getIcon());
    }
    Q_EMIT currentEngineChanged();
}

void Babeleo::rebuildAfterConfigChange()
{
    saveEnginesToConfig();
    createMenu();
    if (m_enginesHash.contains(m_currentEngine)) {
        setIcon(m_enginesHash.value(m_currentEngine)->getIcon());
    }
    Q_EMIT currentEngineChanged();
    Q_EMIT enginesChanged();
}

void Babeleo::createMenu()
{
    m_enginesList = m_configuration.readEntry("engines", QStringList());
    if (m_enginesList.size() < 5) {
        populateEngines();
    }

    qDeleteAll(m_actions);
    m_actions.clear();
    delete m_langChoices;
    m_langChoices = new QActionGroup(this);
    m_langChoices->setExclusive(true);
    qDeleteAll(m_enginesHash);
    m_enginesHash.clear();

    QStringList sortedNames;
    for (int i = 0; i + 4 < m_enginesList.size(); i += 5) {
        const bool hidden = (m_enginesList.value(i + 4) == QLatin1String("1"));
        Babelengine *engine = new Babelengine(
            m_enginesList.value(i),
            m_enginesList.value(i + 1),
            m_enginesList.value(i + 2),
            m_enginesList.value(i + 3),
            hidden
        );
        m_enginesHash.insert(m_enginesList.value(i), engine);
        sortedNames.append(m_enginesList.value(i));
    }

    std::sort(sortedNames.begin(), sortedNames.end());

    QMenu *otherMenu = new QMenu(i18nd("plasma_applet_babeleo", "More search engines"));

    for (const QString &name : std::as_const(sortedNames)) {
        Babelengine *eng = m_enginesHash.value(name);
        if (eng->isHidden()) {
            continue;
        }

        QAction *engineAction = new QAction(eng->getName(), this);
        engineAction->setData(eng->getName());
        engineAction->setCheckable(true);
        engineAction->setIcon(iconFromValue(eng->getIcon()));

        // Accept both the new "main" value and the legacy "0" from older configs.
        if (eng->getPosition() == QLatin1String("main") || eng->getPosition() == QLatin1String("0")) {
            m_actions.append(engineAction);
        } else {
            otherMenu->addAction(engineAction);
        }

        m_langChoices->addAction(engineAction);
        connect(engineAction, &QAction::triggered, this, &Babeleo::setEngineFromAction);

        if (m_currentEngine == eng->getName()) {
            engineAction->setChecked(true);
        }
    }

    if (!otherMenu->isEmpty()) {
        QAction *otherAction = new QAction(i18nd("plasma_applet_babeleo", "More search engines"), this);
        otherAction->setMenu(otherMenu);
        m_actions.append(otherAction);
    } else {
        delete otherMenu;
    }

    QAction *separator = new QAction(this);
    separator->setSeparator(true);
    m_actions.append(separator);

    QAction *manualQueryAction = new QAction(i18nd("plasma_applet_babeleo", "Manual query..."), this);
    connect(manualQueryAction, &QAction::triggered, this, [this]() {
        Q_EMIT requestTogglePopup();
    });
    m_actions.append(manualQueryAction);

    // All configuration is now available via the standard Plasma settings dialog
    // (right-click → Configure Babeleo Translator), which has Search Engines,
    // Keyboard Shortcuts, and About pages. No separate menu item needed.
}

QList<QAction *> Babeleo::contextualActions()
{
    // Snapshot the clipboard now, while the primary selection is still valid.
    // If the user navigates into a submenu, mouse movement can invalidate the
    // Wayland primary selection before the action slot fires.
    m_menuClipboardCache = readClipboard();
    return m_actions;
}

QString Babeleo::currentEngine() const
{
    return m_currentEngine;
}

void Babeleo::onDbusShortcutPressed(const QString &component, const QString &shortcut, qlonglong timestamp)
{
    Q_UNUSED(timestamp)
    if (component == QLatin1String("plasmashell") && shortcut == QLatin1String("manual-query")) {
        Q_EMIT requestTogglePopup();
    }
}

void Babeleo::setEngine(const QString &name)
{
    if (!m_enginesHash.contains(name)) {
        return;
    }
    m_currentEngine = name;
    setIcon(m_enginesHash.value(m_currentEngine)->getIcon());
    const auto actions = m_langChoices->actions();
    for (QAction *a : actions) {
        a->setChecked(a->data().toString() == m_currentEngine);
    }
    m_configuration.writeEntry("currentEngine", m_currentEngine);
    Q_EMIT configNeedsSaving();
    Q_EMIT currentEngineChanged();
}

void Babeleo::setEngineFromAction()
{
    QAction *senderAction = qobject_cast<QAction *>(sender());
    if (!senderAction) {
        return;
    }
    const QString engineName = senderAction->data().toString();
    // Ctrl+Click: "click & forget" — search without switching the active engine.
    // Use keyboardModifiers() (cached Qt event state) rather than queryKeyboardModifiers()
    // (live OS query), because on Wayland the popup surface may no longer have keyboard
    // focus by the time the slot runs, making the live query return 0.
    const Qt::KeyboardModifiers mods = QGuiApplication::keyboardModifiers();
    if (mods & Qt::ControlModifier) {
        // Restore checkmark first (QActionGroup already moved it to the clicked action).
        const auto actions = m_langChoices->actions();
        for (QAction *a : actions) {
            a->setChecked(a->data().toString() == m_currentEngine);
        }
        if (mods & Qt::ShiftModifier) {
            // Ctrl+Shift+Click: open manual query popup pre-targeted at this engine.
            // browseWithText() will use m_oneshotEngine instead of m_currentEngine,
            // then clear it, so the selected engine is never permanently changed.
            m_oneshotEngine = engineName;
            Q_EMIT oneshotEngineChanged();
            // Request a Wayland activation token before showing the popup, so it
            // keeps focus even when all windows are minimized (no active surface).
            withActivationToken([this]() { Q_EMIT requestTogglePopup(); });
        } else {
            // Ctrl+Click: "click & forget" — search clipboard without switching engine.
            // Use the clipboard snapshot taken when the menu opened — the primary
            // selection may have been lost during submenu navigation.
            openUrl(engineName, m_menuClipboardCache);
        }
        return;
    }
    setEngine(engineName);
}

void Babeleo::withActivationToken(std::function<void()> callback)
{
    // On Wayland, windows need an xdg-activation token to come to the foreground.
    // Without one, the compositor silently blocks focus (browser stays behind, or
    // the panel popup loses focus immediately and closes).
    // We request a token from KWin using any existing plasmashell window as the
    // "requesting surface", then invoke the callback once the token is set.
    if (KWindowSystem::isPlatformWayland()) {
        const auto windows = QGuiApplication::topLevelWindows();
        QWindow *win = windows.isEmpty() ? nullptr : windows.first();
        auto *watcher = new QFutureWatcher<QString>(this);
        connect(watcher, &QFutureWatcher<QString>::finished, this, [watcher, cb = std::move(callback)]() {
            const QString token = watcher->result();
            if (!token.isEmpty()) {
                KWindowSystem::setCurrentXdgActivationToken(token);
            }
            watcher->deleteLater();
            cb();
        });
        watcher->setFuture(KWaylandExtras::xdgActivationToken(win, QStringLiteral("org.kde.plasma.babeleo")));
    } else {
        callback();
    }
}

void Babeleo::openUrl(const QString &engineName, const QString &query)
{
    if (!m_enginesHash.contains(engineName)) {
        return;
    }

    QString urlTemplate = m_enginesHash.value(engineName)->getURL();
    const QString encodedQuery = QString::fromUtf8(QUrl::toPercentEncoding(query));
    urlTemplate.replace(QLatin1String("%s"), encodedQuery);

    auto *job = new KIO::OpenUrlJob(QUrl(urlTemplate));
    job->setRunExecutables(false); // Security: only open URLs, do not launch programs

    withActivationToken([job]() { job->start(); });
}

QString Babeleo::readClipboard()
{
    // Priority for the search term:
    // 1. Primary Selection (mouse selection) via Qt directly
    //    - Works reliably on X11
    //    - On Wayland: Qt6 uses zwp_primary_selection_v1 - whether plasmashell
    //      has access to it depends on KWin
    // 2. Klipper via D-Bus
    //    - Klipper has NO endpoint for the Primary Selection!
    //    - getClipboardContents() only returns history entries.
    //    - Useful as a fallback for the regular clipboard (Ctrl+C)
    // 3. Regular clipboard (Ctrl+C) via Qt directly
    //
    // IMPORTANT: Klipper must NOT be queried first, because
    // getClipboardContents() can return a non-empty string
    // (last Ctrl+C entry) even when something else is currently selected.
    // This would prevent us from falling through to the Primary Selection.
    QString query;

    // 1. Attempt: wl-paste --primary (Wayland Primary Selection)
    //    wl-paste (from the optional package wl-clipboard) is a regular
    //    Wayland client that is allowed to read the Primary Selection - plasmashell
    //    itself does not have this permission for security reasons.
    //    Without wl-clipboard: code automatically falls back to Klipper.
    //    findExecutable() prevents an unnecessary 500ms timeout when
    //    wl-paste is not installed.
    if (!QStandardPaths::findExecutable(QStringLiteral("wl-paste")).isEmpty()) {
        QProcess proc;
        proc.start(QStringLiteral("wl-paste"),
                   {QStringLiteral("--primary"), QStringLiteral("--no-newline")});
        if (proc.waitForFinished(500) && proc.exitCode() == 0) {
            query = QString::fromUtf8(proc.readAllStandardOutput());
        }
    }

    // 2. Attempt: QClipboard::Selection (works on X11, rarely on Wayland)
    if (query.isEmpty() && QGuiApplication::clipboard()->supportsSelection()) {
        query = QGuiApplication::clipboard()->text(QClipboard::Selection);
    }

    // 3. Attempt: Klipper via D-Bus (returns regular clipboard / last Ctrl+C)
    if (query.isEmpty()) {
        QDBusInterface klipper(
            QStringLiteral("org.kde.klipper"),
            QStringLiteral("/klipper"),
            QStringLiteral("org.kde.klipper.klipper")
        );
        if (klipper.isValid()) {
            const QDBusReply<QString> reply = klipper.call(QStringLiteral("getClipboardContents"));
            if (reply.isValid()) {
                query = reply.value();
            }
        }
    }

    // 4. Last fallback: Qt directly
    if (query.isEmpty()) {
        query = QGuiApplication::clipboard()->text(QClipboard::Clipboard);
    }

    return query;
}

void Babeleo::browseWithClipboard()
{
    openUrl(m_currentEngine, readClipboard());
}

bool Babeleo::isCtrlHeld() const
{
    return QGuiApplication::keyboardModifiers() & Qt::ControlModifier;
}

void Babeleo::requestContextMenu(double globalX, double globalY)
{
    // Synthesise a right-click at the given screen position so that Plasma's
    // containment event handling opens the native context menu — exactly the
    // same menu that appears on a real right-click.
    auto *quickItem = PlasmaQuick::AppletQuickItem::itemForApplet(this);
    if (!quickItem) return;

    QQuickWindow *window = quickItem->window();
    if (!window) return;

    const QPointF globalPos(globalX, globalY);
    const QPointF localPos = window->mapFromGlobal(globalPos.toPoint());

    QCoreApplication::postEvent(window,
        new QMouseEvent(QEvent::MouseButtonPress, localPos, globalPos,
                        Qt::RightButton, Qt::RightButton, Qt::NoModifier));
    QCoreApplication::postEvent(window,
        new QMouseEvent(QEvent::MouseButtonRelease, localPos, globalPos,
                        Qt::RightButton, Qt::NoButton, Qt::NoModifier));
}

void Babeleo::browseWithClipboardOnEngine(const QString &engineName)
{
    // "Click & forget": search on a specific engine without changing the
    // currently selected engine.
    openUrl(engineName, readClipboard());
}

void Babeleo::browseWithText(const QString &text)
{
    const QString target = m_oneshotEngine.isEmpty() ? m_currentEngine : m_oneshotEngine;
    clearOneshotEngine();
    openUrl(target, text);
}

void Babeleo::clearOneshotEngine()
{
    if (!m_oneshotEngine.isEmpty()) {
        m_oneshotEngine.clear();
        Q_EMIT oneshotEngineChanged();
    }
}

void Babeleo::fetchIcon(const QString &engineName, const QString &pageUrl)
{
    // KIO::FavIconRequestJob is KDE's built-in favicon service.
    // It handles everything: parsing HTML, finding the favicon URL, downloading,
    // converting the format (SVG→PNG), and storing it in a shared cache.
    // (~/.cache/favicons/)
    //
    // We only pass the host URL - scheme and host are sufficient.
    // The job starts automatically (no job->start() needed).
    QString resolvedUrl = pageUrl;
    resolvedUrl.replace(QLatin1String("%s"), QLatin1String("test"));

    auto *job = new KIO::FavIconRequestJob(QUrl(resolvedUrl));
    connect(job, &KJob::result, this, [this, engineName, job]() {
        if (job->error()) {
            qDebug() << "[Babeleo] fetchIcon failed:" << job->errorString();
            Q_EMIT iconFetched(engineName, QString());
            return;
        }
        // Copy the favicon from the volatile KIO cache to a persistent location
        // so it survives cache cleanups.
        // Store favicons under AppDataLocation, NOT under plasma/plasmoids/,
        // because Plasma treats any directory under plasma/plasmoids/<id>/ as a
        // local package override, which shadows the system installation.
        const QString iconDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                                + QStringLiteral("/babeleo/icons/");
        QDir().mkpath(iconDir);
        const QString srcPath  = job->iconFile();
        const QString destPath = iconDir + QFileInfo(srcPath).fileName();
        if (!QFile::exists(destPath))
            QFile::copy(srcPath, destPath);
        qDebug() << "[Babeleo] fetchIcon: Icon stored as" << destPath;
        Q_EMIT iconFetched(engineName, destPath);
    });
}

QVariantList Babeleo::engineList() const
{
    QVariantList result;
    for (auto it = m_enginesHash.constBegin(); it != m_enginesHash.constEnd(); ++it) {
        const Babelengine *eng = it.value();
        QVariantMap entry;
        entry[QStringLiteral("name")]     = eng->getName();
        entry[QStringLiteral("url")]      = eng->getURL();
        entry[QStringLiteral("icon")]     = eng->getIcon();
        entry[QStringLiteral("position")] = eng->getPosition();
        entry[QStringLiteral("hidden")]   = eng->isHidden();
        result.append(entry);
    }
    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("name")).toString()
             < b.toMap().value(QStringLiteral("name")).toString();
    });
    return result;
}

void Babeleo::saveEngine(const QString &oldName, const QString &newName,
                         const QString &url, const QString &icon,
                         const QString &position, bool hidden)
{
    if (oldName != newName && m_enginesHash.contains(newName)) {
        KMessageBox::error(nullptr, i18nd("plasma_applet_babeleo", "A search engine with this name already exists."));
        return;
    }

    if (!oldName.isEmpty()) {
        delete m_enginesHash.take(oldName);
    }

    m_enginesHash.insert(newName, new Babelengine(newName, url, icon, position, hidden));

    saveEnginesToConfig();
    createMenu();
    Q_EMIT enginesChanged();
}

void Babeleo::deleteEngine(const QString &name)
{
    delete m_enginesHash.take(name);
    saveEnginesToConfig();
    createMenu();
    Q_EMIT enginesChanged();
}

void Babeleo::cycleEngine(int direction)
{
    QStringList visibleNames;
    for (auto it = m_enginesHash.constBegin(); it != m_enginesHash.constEnd(); ++it) {
        if (!it.value()->isHidden()) {
            visibleNames.append(it.key());
        }
    }
    if (visibleNames.size() < 2) {
        return;
    }
    std::sort(visibleNames.begin(), visibleNames.end());

    int idx = visibleNames.indexOf(m_currentEngine);
    if (idx < 0) {
        idx = 0;
    }
    idx = (idx + direction + visibleNames.size()) % visibleNames.size();

    m_currentEngine = visibleNames.at(idx);
    if (m_enginesHash.contains(m_currentEngine)) {
        setIcon(m_enginesHash.value(m_currentEngine)->getIcon());
    }
    const auto actions = m_langChoices->actions();
    for (QAction *a : actions) {
        a->setChecked(a->data().toString() == m_currentEngine);
    }
    m_configuration.writeEntry("currentEngine", m_currentEngine);
    Q_EMIT configNeedsSaving();
    Q_EMIT currentEngineChanged();
}

void Babeleo::saveEnginesToConfig()
{
    m_enginesList.clear();
    for (auto it = m_enginesHash.constBegin(); it != m_enginesHash.constEnd(); ++it) {
        const Babelengine *eng = it.value();
        m_enginesList << eng->getName()
                      << eng->getURL()
                      << eng->getIcon()
                      << eng->getPosition()
                      << (eng->isHidden() ? QStringLiteral("1") : QStringLiteral("0"));
    }
    m_configuration.writeEntry("engines", m_enginesList);
    Q_EMIT configNeedsSaving();
}

void Babeleo::populateEngines()
{
    // Locate the bundled default engines file inside the installed QML package.
    const QString jsonPath = QStandardPaths::locate(
        QStandardPaths::GenericDataLocation,
        QStringLiteral("plasma/plasmoids/org.kde.plasma.babeleo/contents/data/engines.json"));

    if (jsonPath.isEmpty()) {
        qWarning() << "[Babeleo] engines.json not found — no default engines loaded";
        return;
    }

    QFile file(jsonPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[Babeleo] Cannot open engines.json:" << file.errorString();
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isArray()) {
        qWarning() << "[Babeleo] engines.json: expected a JSON array at top level";
        return;
    }

    m_enginesList.clear();
    for (const QJsonValue &val : doc.array()) {
        const QJsonObject obj = val.toObject();
        const QString position = obj.value(QStringLiteral("position")).toString(QStringLiteral("submenu"));
        const QString hidden = obj.value(QStringLiteral("hidden")).toBool(false)
                               ? QStringLiteral("1") : QStringLiteral("0");
        m_enginesList << obj.value(QStringLiteral("name")).toString()
                      << obj.value(QStringLiteral("url")).toString()
                      << obj.value(QStringLiteral("icon")).toString()
                      << position
                      << hidden;
    }

    m_configuration.writeEntry("engines", m_enginesList);
    Q_EMIT configNeedsSaving();
}

QKeySequence Babeleo::manualQueryShortcut() const
{
    return m_manualQueryShortcutCache;
}

void Babeleo::setManualQueryShortcut(const QKeySequence &shortcut)
{
    if (!m_manualQueryAction) {
        return;
    }
    // NoAutoloading forces the new shortcut to take effect immediately and
    // be saved to kglobalshortcutsrc. setGlobalShortcut() uses Autoloading
    // which re-reads kglobalshortcutsrc after setting, discarding our change.
    KGlobalAccel::self()->setShortcut(m_manualQueryAction, {shortcut}, KGlobalAccel::NoAutoloading);
    // Update the local cache immediately so manualQueryShortcut() returns the
    // new value before the KGlobalAccel D-Bus round-trip completes.
    m_manualQueryShortcutCache = shortcut;
    // Persist to applet config so the shortcut survives plasmashell restarts.
    // (NoAutoloading never writes to kglobalshortcutsrc.)
    m_configuration.writeEntry("manualQueryShortcut", shortcut.toString());
    Q_EMIT configNeedsSaving();
    Q_EMIT manualQueryShortcutChanged();
}

K_PLUGIN_CLASS_WITH_JSON(Babeleo, "metadata.json")

#include "babeleo.moc"
