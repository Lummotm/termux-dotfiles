if status is-interactive
    set -g fish_greeting
    if not set -q SSH_CONNECTION
        setsid bash ~/scripts/sync-git-phone.sh >> ~/sync-git.log 2>&1 && echo "Sincronización finalizada"
    end

    function startssh
        if pgrep -x sshd > /dev/null
            echo "✅ sshd ya estaba corriendo"
        else
            sshd
            echo "🚀 sshd iniciado"
        end
        set ip (ifconfig 2>/dev/null | grep -A 2 "wlan0:" | grep "inet " | awk '{print $2}')
        echo "📡 IP local: $ip"
        echo "👤 Usuario: "(whoami)
    end
end

starship init fish | source
