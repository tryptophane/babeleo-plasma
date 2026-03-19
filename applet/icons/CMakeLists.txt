# ecm_install_icons() is the ECM/KDE6 replacement for kde4_install_icons().
# It reads the icon filename (format: SIZE-CATEGORY-NAME.png)
# and installs into the correct directory structure under ${KDE_INSTALL_ICONDIR}.
# "hicolor" is the standard Freedesktop icon theme.
include(ECMInstallIcons)
ecm_install_icons(ICONS
    128-apps-babelfishleo.png
    128-apps-babelfishleo-en.png
    128-apps-babelfishleo-fr.png
    128-apps-babelfishleo-es.png
    128-apps-babelfishleo-it.png
    128-apps-babelfishleo-ch.png
    DESTINATION ${KDE_INSTALL_ICONDIR}
    THEME hicolor
)
