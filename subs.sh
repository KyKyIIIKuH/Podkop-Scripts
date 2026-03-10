#!/bin/sh

CONFIG="/etc/config/podkop"
TMP_FILE="/tmp/podkop_tmp"
VLESS_URL="https://ССЫЛКА_НА_ПОДПИСКУ"
PKG="idn"

if ! opkg list-installed | grep -q "^$PKG "; then
    echo "Package $PKG not installed. Installing..."
    opkg update
    opkg install $PKG
else
    echo "Package $PKG already installed."
fi

# Получаем домен из URL
DOMAIN=$(echo "$VLESS_URL" | sed -E 's#https?://([^/]+).*#\1#')

# Конвертируем в punycode
DOMAIN_IDN=$(idn "$DOMAIN")

# Собираем обратно URL
URL_IDN=$(echo "$URL" | sed "s#$DOMAIN#$DOMAIN_IDN#")

log() { echo "[$(date '+%F %T')] $*"; }

# --- Рестарт сервиса ---
restart_target() {
  # Под разные прошивки/сервисы: podkop, sing-box, или просто reload network (не трогаем лишнее)
  if [ -x /etc/init.d/podkop ]; then
    /etc/init.d/podkop restart && log "podkop: restart OK" && return 0
  fi
  if [ -x /etc/init.d/sing-box ]; then
    if /etc/init.d/sing-box reload 2>/dev/null; then
      log "sing-box: reload OK"
    else
      /etc/init.d/sing-box restart
      log "sing-box: restart OK"
    fi
    return 0
  fi
  log "Не нашёл /etc/init.d/podkop и /etc/init.d/sing-box — рестарт пропущен."
}

# --- Получаем список и декодируем base64 ---
VLESS_LIST=$(wget --no-check-certificate --user-agent="KyKyIIIKuHVless" -qO- "$URL_IDN" | base64 -d | grep 'vless://' | grep -v 'xhttp')

if [ -z "$VLESS_LIST" ]; then
    echo "❌ Не удалось получить VLESS список"
    exit 1
fi

# --- Удаляем старые selector_proxy_links из section main ---
awk '
BEGIN { in_main=0 }
/^config section '\''main'\''/ { in_main=1; print; next }
/^config section / && !/^config section '\''main'\''/ { in_main=0 }

{
    if (in_main && $1=="list" && $2=="selector_proxy_links") {
        next
    }
    print
}
' "$CONFIG" > "$TMP_FILE"

# --- Добавляем новые строки в конец section main ---
awk -v vless_list="$VLESS_LIST" '
BEGIN {
    split(vless_list, arr, "\n")
    in_main=0
}
/^config section '\''main'\''/ { in_main=1 }
in_main && /^config section / && !/^config section '\''main'\''/ { in_main=0 }

{
    print

    # Если следующий блок начинается и мы были в main — вставляем список
    if (in_main && /^config section / && !/^config section '\''main'\''/) {
        for (i in arr) {
            if (arr[i] != "") {
                printf "\tlist selector_proxy_links '\''%s'\''\n", arr[i]
            }
        }
        in_main=0
    }
}
END {
    # если main был последним блоком
    if (in_main) {
        for (i in arr) {
            if (arr[i] != "") {
                printf "\tlist selector_proxy_links '\''%s'\''\n", arr[i]
            }
        }
    }
}
' "$TMP_FILE" > "$CONFIG"

rm -f "$TMP_FILE"

# --- Перезапускаем сервис  ---
restart_target

echo "✅ selector_proxy_links обновлены"
