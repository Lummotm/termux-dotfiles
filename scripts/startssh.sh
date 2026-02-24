#!/usr/bin/env bash
if pgrep -x "sshd" >/dev/null; then
    echo "sshd ya estaba corriendo"
else
    sshd
    echo "sshd iniciado"
fi

ip=$(ifconfig 2>/dev/null | grep -A 2 "wlan0:" | grep "inet " | awk '{print $2}')

echo "IP local: $ip"
echo "Usuario: $(whoami)"
