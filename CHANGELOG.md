# Changelog

## 0.13.0 (02.05.2026)

- It is now possible to configure custom URI schemes like "spotify:search:%s" as the search engines URL. Very handy for example to quickly search for the currently running track (maybe in you favorite web radio) directly in the spotify app (if installed),
- Added "Spotify (App)" ans "Spotify (browser) to the default search engines, the second one is hidden by default
- The text in the textfields of the search engines settings page is now selected automatically on focus
- Added a tooltip to the "Fetch icon" button in the engines settings page

## 0.12.0 (17.04.2026)

- The "Fetch All Icons" functionality now also works for engines which have not already been saved (by clicking on "Apply"" or "OK")
- Replaced the LICENSE file with the GPL 2 license. It contained the GPL 3 by error, Babeleo was always licensed under GPL 2 or later
- Added SPDX headers to all C++ and QML files, tagging the files as licensed under GPL-2.0-or-later


## 0.11.0 (16.04.2026)

- The main menu engines are now sorted on top in the list of the settings dialog and in the combobox of the desktop widget.The names of the main menu engines are highlighted (color depends on your KDE theme) 
- Added Import / Export buttons in the engines settings page. The engines list is saved in JSON format (without downloaded icons)
- Added a "Fetch All Icons" Button to the engines settings page. This will perform the "fetch Icon" action for all search engines which don't have a specific icon set (all those who have the yellow babelfishleo icon). It will work only for engines which have already been saved
- In engines settings, when clicking on apply, the engines list is reloaded and re-sorted. The previously selected engine stays selected
- The global shortcuts configured in babeleo are now correctly cleaned up when the applet is removed from the panel or desktop
- Fixed some inconsistencies when deleting search engines, especially if the deleted engine was selected in the applet
- A few updates to the default engines list. Added opendesktop.org, where you now could search for "babeleo" :-) 
- The sorting of the search engines in the context menu is now case insensitive  
- Fixed some warnings seen in the system logs which were related to the UI of the settings dialog pages.
- Fixed some small UI glitches on selected items in the engines list of settings

## 0.10.0 (06.04.2026)

- Desktop widget header icon is now clickable: single-click or double-click searches with clipboard content depending on the click behaviour setting
- Tooltip on the icon reflects the active click mode
- Settings config page is now shown for desktop widgets too, displaying only the click behaviour section; the keyboard shortcut section and its panel-specific hint remain panel-only
- fixes the bug where the one-shot manual query popup immediately disappeared when all windows on the KDE desktop were minimized
- Default search engines are now defined in applet/package/contents/data/engines.json instead of being hardcoded in babeleo.cpp

## 0.9.0 (04.04.2026)

- **Quick manual query on any engine**: Ctrl+Shift+Click an engine in the context menu of the panel applet to open the manual query dialog for this engine, without changing your current engine ("one shot manual query"). Similar to the Ctrl+Click "click & forget" feature published in version 0.7.0
- Added missing translations for name and description fields of the metadata.json files
- Improved the preconfigured URLs for the Wikipedia and Wiktionary engines, which will now support a more fuzzy search

## 0.8.0 (30.03.2026)

- Added option to trigger search on double click instead of single click. If this is selected, a single click on the icon will open the context menu (like the right click)

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

- **Quick search on any engine**: Ctrl+Click an engine in the context menu or the desktop widget dropdown to instantly search with the clipboard content, without changing your current engine ("click & forget")
- Tooltip on each engine in the dropdown hints at the Ctrl+Click shortcut
- The text field of the manual query dialog is now correctly reset when the dialog opens

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
