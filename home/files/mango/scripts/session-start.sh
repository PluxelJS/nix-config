#!/bin/sh
set -eu

# Run inside Mango, never from Home Manager's possibly stale terminal session.
: "${XDG_RUNTIME_DIR:?}" "${WAYLAND_DISPLAY:?}"
test -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"

unset GTK_IM_MODULE
systemctl --user unset-environment GTK_IM_MODULE
# Clear the DBus value too, without reintroducing it into the user manager.
GTK_IM_MODULE= dbus-update-activation-environment GTK_IM_MODULE
dbus-update-activation-environment --systemd \
  PATH XDG_DATA_DIRS XDG_CONFIG_DIRS DISPLAY XAUTHORITY MANGO_INSTANCE_SIGNATURE \
  XDG_MENU_PREFIX WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
  XDG_SESSION_DESKTOP DESKTOP_SESSION DMS_DISABLE_POLKIT \
  ELECTRON_OZONE_PLATFORM_HINT GDK_BACKEND GTK_THEME GTK_USE_PORTAL INPUT_METHOD \
  MOZ_ENABLE_WAYLAND NIXOS_OZONE_WL OZONE_PLATFORM QT_IM_MODULE QT_IM_MODULES \
  QT_QPA_PLATFORM SDL_IM_MODULE GLFW_IM_MODULE XMODIFIERS XCURSOR_THEME XCURSOR_SIZE

systemctl --user reset-failed dms.service
systemctl --user start mango-session.target
# Also recover a stopped shell if the target was already active.
systemctl --user start dms.service
systemctl --user restart xdg-desktop-portal.service
