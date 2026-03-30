# Changelog

## 0.8.0 (30.03.2026)

- Added option to trigger search on double click insted of single click. If this is selected, a single click on the icon will open the context menu (like the right click)

## 0.7.3 (20.03.2026)

- Fixed version in metadata.json

## 0.7.2 (20.03.2026)

- Added hint in README to the new AUR package for Arch Linux users
- Renamed icon files to meet conventions 
- Fixed compilation warnings when building AUR package
- Removed AI generated clutter from README

## 0.7.1 (19.03.2026)

- Fix some ctrl + click related bugs

## 0.7.0 (18.03.2026)

- **Quick search on any engine**: Ctrl+Click an engine in the context menu or the desktop widget dropdown to instantly search with the clipboard content, without changing your current engine ("click & forget").
- Tooltip on each engine in the dropdown hints at the Ctrl+Click shortcut.
- The text field of the manual query dialog is now correctly reset when the dialog opens.

## 0.6.0 (16.03.2026)

Complete rewrite for **KDE Plasma 6 / Qt 6**. The applet is fully functional again after over a decade.

- Full Wayland support, including correct browser focus when triggered from a global shortcut.
- Mouse-selected text is read directly (primary selection), no need to press Ctrl+C first.
- Desktop widget mode: Babeleo can now be placed on the desktop with a search engine dropdown.
- Global keyboard shortcut to open the manual query dialog (configurable in settings).
- Favicon download: icons are now stored reliably and no longer cause crashes.
- New configuration interface for search engines, built with the Plasma 6 settings system.
- Translations: German, French, Italian, Spanish, Simplified Chinese.

---

## 0.5.2 (13.10.2011)

- New AUTHORS file and updated credits.
- New packages for SUSE and Ubuntu.

## 0.5.1 (30.09.2009)

- Global shortcut for triggering a query works again.
- Added a global shortcut to open the manual query dialog.
- Added more search engines to the default list.

## 0.5 (10.09.2009)

- Automatic icon download: Babeleo fetches the favicon from each search engine's website.

## 0.4.2 (31.08.2009)

- Fixed a crash on startup.

## 0.4.1 (31.08.2009)

- Search engines are now sorted alphabetically in the menus.
- Added more search engines to the default list.
- Some search engines are now hidden by default.

## 0.4 (30.08.2009)

- New configuration interface for search engines: add, remove and edit engines, hide individual engines, and choose whether each engine appears in the main menu or the "other engines" submenu.
- The applet is now listed as "Babeleo Translator" in the widget browser.

## 0.3.2 (25.08.2009)

- Babeleo now reads the currently highlighted text instead of the clipboard — no need to press Ctrl+C anymore, regardless of Klipper settings.

## 0.3.1 (24.08.2009)

- Fixed a crash that could occur after a fresh install or an upgrade from an older version.

## 0.3 (22.08.2009)

- Added several new search engines.
- The tooltip now shows the currently selected engine.

## 0.2.1 (20.08.2009)

- Improved behaviour of the manual query text field (focus and visibility).

## 0.2 (20.08.2009)

- Added a manual query text field: enter a search term directly instead of using the clipboard.

## 0.1 (18.08.2009)

- Initial release.
