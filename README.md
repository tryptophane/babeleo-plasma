# Babeleo — KDE Plasma 6 Quick Translation and Search Applet

#### 🎉 **Finally!** The good old Babeleo Translator plasmoid is back in it's new Qt6 dress!

A KDE Plasma 6 applet to query any web service with the clipboard content or typed text. The fastest way to translate or query any text on your desktop!  
Select text with the mouse, click the icon — your browser opens the result directly.
Works with translation services, dictionaries, encyclopedias, search engines, and anything else you can reach with a URL.

<img alt="Babeleo - At A Glance" src="https://github.com/user-attachments/assets/9a689101-feac-437f-ab61-8184de539459" />  
Babeleos panel icon with context menu, the settings dialog and the desktop applet  

---  

<img alt="Babeleo - Manual Query" src="https://github.com/user-attachments/assets/c79e0701-c567-4670-b19a-765e683d131c" />

Manual query dialog, open it through the context menu or by a keyboard shortcut

---

## Features

- **One-click lookup**: select text with the mouse, click the icon or press the keyboard shortcut → browser opens the result
- **Manual query**: enter a search term directly in the applet's popup dialog
- **Global keyboard shortcuts**: configurable shortcuts for even faster use
- **Fully configurable services**: add, edit, remove any engine — point it at any URL that accepts a query string
- **Automatic favicon download**: each service displays its website icon
- **Context menu**: quickly switch between services, organize them into main menu and submenu
- **Desktop widget**: query clipboard content with your keyboard shortcut or make a manual query. Choose your search engine in the dropdown
- **Quick search on any engine**: Ctrl+Click an engine in the context menu or the desktop widget dropdown to search with the clipboard content without changing your current engine ("click & forget")
- **Quick manual query on any engine**: Ctrl+Shift+Click an engine in the context menu of the panel applet to open the manual query dialog for this engine, without changing your current engine.

## Built-in services (all configurable)

The applet ships with a set of example services to get you started. You can add,
remove or change all of them freely — none are mandatory.

No data is ever sent to any service without an explicit user action (clicking). Your browser handles all communication — Babeleo only opens a URL.
The developper is not affiliated with any of these services.

---

## Keyboard shortcuts

Babeleo exposes two independent global keyboard shortcuts, both configurable in Babeleo's settings dialog:

- Query clipboard content with the selected engine
- Open the manual query dialog

Due to Plasma limitations, this shortcuts have to be configured on two distinct shortcut pages in the settings dialog.

---

## Requirements

| Dependency | Version |
|---|---|
| KDE Plasma | 6.x |
| Qt | ≥ 6.7 |
| KDE Frameworks | ≥ 6.0 |
| CMake | ≥ 3.22 |
| Extra CMake Modules (ECM) | ≥ 6.0 |

---

## Build & Install

### Arch Linux AUR package

Arch Linux users can simply install Babeleo from the AUR:
https://aur.archlinux.org/packages/babeleo

### Manual build and install

```bash
# Clone
git clone https://github.com/tryptophane/babeleo-plasma.git
cd babeleo-plasma

# Build
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
cmake --build .

# Install (requires root)
sudo cmake --install .
```

After installation, right-click the desktop or panel → *Add Widgets* → search for **Babeleo**.

To reload Plasma without restarting your session:
```bash
kquitapp6 plasmashell && kstart plasmashell
```

### Build dependencies

**Arch Linux / Manjaro:**
```bash
sudo pacman -S cmake extra-cmake-modules libplasma \
    qt6-base ki18n kio kcoreaddons kconfig \
    kglobalaccel kwidgetsaddons kxmlgui kwindowsystem wl-clipboard
```

**KDE Neon / Ubuntu with Plasma 6:**
```bash
sudo apt install cmake extra-cmake-modules libplasma-dev qt6-base-dev \
    libkf6coreaddons-dev libkf6i18n-dev libkf6config-dev \
    libkf6globalaccel-dev libkf6kio-dev libkf6widgetsaddons-dev \
    libkf6xmlgui-dev libkf6windowsystem-dev wl-clipboard
```

**Fedora:**
```bash
sudo dnf install cmake extra-cmake-modules plasma-devel qt6-qtbase-devel \
    kf6-kcoreaddons-devel kf6-ki18n-devel kf6-kconfig-devel \
    kf6-kglobalaccel-devel kf6-kio-devel kf6-kwidgetsaddons-devel \
    kf6-kxmlgui-devel kf6-kwindowsystem-devel wl-clipboard
```

---

## Uninstall

### With the build directory

```bash
cd build
sudo cmake --build . --target uninstall
```

(`KDECMakeSettings` generates this target automatically.)

### Without the build directory (manual)

```bash
# C++ plugin
sudo rm -f /usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.babeleo.so

# QML package
sudo rm -rf /usr/share/plasma/plasmoids/org.kde.plasma.babeleo/

# Translations
sudo rm -f /usr/share/locale/*/LC_MESSAGES/plasma_applet_babeleo.mo
```

Afterwards, remove the applet from your panel and restart Plasma:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

---

## License

GPL-2.0-or-later — see [LICENSE](LICENSE)

## Credits

- Icon based on *Crystal Clear app babelfish* by Everaldo Coelho (LGPL)
- Original KDE 4 concept by Pascal Pollet (2009)
- Ported to KDE Plasma 6 (2026) — most of the implementation by Claude Sonnet 4.6, directed by Pascal Pollet
