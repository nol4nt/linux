#!/usr/bin/env bash

POWERED=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

if [[ "$POWERED" == "no" ]]; then
    echo '{"text":"<span color=\"#FF4040\">  </span>","class":"off","tooltip":"Bluetooth off"}'
    exit 0
fi

CONNECTED=$(bluetoothctl info | grep "Connected: yes" | wc -l)

if [[ "$CONNECTED" -gt 0 ]]; then
    echo "{\"text\":\" $CONNECTED\",\"class\":\"connected\",\"tooltip\":\"$CONNECTED device(s) connected\"}"
else
    echo '{"text":"<span color=\"#00BFFF\">  </span>","class":"on","tooltip":"Bluetooth on"}'
fi
