#!/usr/bin/env bash

ICON=""
SIGNAL=$(nmcli -t -f in-use,signal dev wifi | grep '^*' | cut -d: -f2)

TOOLTIP=$(
  ~/.config/waybar/modules/wifi.sh | sed 's/"/\\"/g'
)

cat <<EOF
{
  "icon": "$ICON",
  "signal": "$SIGNAL",
  "tooltip": "$TOOLTIP"
}
EOF

