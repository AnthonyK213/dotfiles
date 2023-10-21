# DBus
daemonize -e /tmp/dbus-${USER}.log -o /tmp/dbus-${USER}.log -p /tmp/dbus-${USER}.pid -l /tmp/dbus-${USER}.pid -a /usr/bin/dbus-daemon --address="unix:path=$XDG_RUNTIME_DIR/bus" --session --nofork  >>/dev/null 2>&1
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

# fcitx5
daemonize -e /tmp/fcitx5.log -o /tmp/fcitx5.log -p /tmp/fcitx5.pid -l /tmp/fcitx5.pid -a /usr/bin/fcitx5 --disable=wayland
export INPUT_METHOD=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
