#!/usr/bin/env bash

ACTIVE=$(nmcli -t -f active,ssid,signal,security,device dev wifi list | grep '^yes')

ACTIVE_SSID=$(echo "$ACTIVE" | cut -d: -f2)
ACTIVE_SIGNAL=$(echo "$ACTIVE" | cut -d: -f3)
ACTIVE_SEC=$(echo "$ACTIVE" | cut -d: -f4)

echo "<b>📡 Current Connection</b>"
echo "SSID: <span class='ssid'>$ACTIVE_SSID</span>"
echo "Signal: ${ACTIVE_SIGNAL}%"
echo "Security: ${ACTIVE_SEC:-Open}"
echo ""

echo "<b>📶 Available Access Points</b>"
echo "<span class='ap-header'>SSID │ Signal │ Security │ Band │ In Use</span>"

nmcli -t -f in-use,ssid,signal,security,freq dev wifi list | \
while IFS=: read -r INUSE SSID SIGNAL SECURITY FREQ; do
    [[ -z "$SSID" ]] && SSID="<hidden>"

    if [[ "$INUSE" == "*" ]]; then
        INUSE_ICON="●"
    else
        INUSE_ICON=""
    fi

    echo "<span class='ap-row'>${SSID} │ ${SIGNAL}% │ ${SECURITY:-Open} │ ${FREQ} │ ${INUSE_ICON}</span>"
done

