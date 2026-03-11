#!/bin/ash

clear

echo "v1.0"

# Цвета ANSI
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

REPO="https://raw.githubusercontent.com/KyKyIIIKuH/Podkop-Scripts/refs/heads/main"
SUBS_FILE="/etc/subs.sh"
CHECK_FILE="/etc/check-connection.sh"

# Файл crontab пользователя root
CRON_FILE="/etc/crontabs/root"

install_subs() {
    echo ""
    echo "Downloading subs.sh..."

    rm -f "$SUBS_FILE"

    curl -sL "$REPO/subs.sh" -o "$SUBS_FILE"

    if [ ! -f "$SUBS_FILE" ]; then
        echo "Download failed!"
        return
    fi

    chmod +x "$SUBS_FILE"

    echo ""
    echo -e "${YELLOW}Укажите ссылку на подписку: ${RESET}"
    read VLESS_URL

    if [ -z "$VLESS_URL" ]; then
        echo -e "${RED}Ссылка подписки не может быть пустой${RESET}"
        return
    fi

    sed -i "s|^VLESS_URL=.*|VLESS_URL=\"$VLESS_URL\"|g" "$SUBS_FILE"

    # Проверяем и добавляем только если строки нет
    grep -Fxq "0 0 * * * /etc/subs.sh" "$CRON_FILE" || \
        echo "0 0 * * * /etc/subs.sh" >> "$CRON_FILE"

    sh "$SUBS_FILE"

    echo ""
    echo -e "${GREEN}subs.sh успешно установлен и настроен${RESET}"
}

install_check() {
    echo ""
    echo "Downloading check-connection.sh..."

    rm -f "$CHECK_FILE"

    curl -sL "$REPO/check-connection.sh" -o "$CHECK_FILE"

    if [ ! -f "$CHECK_FILE" ]; then
        echo "Download failed!"
        return
    fi

    chmod +x "$CHECK_FILE"

    # Проверяем и добавляем только если строки нет
    grep -Fxq "*/1 * * * * /etc/check-connection.sh" "$CRON_FILE" || \
        echo "*/1 * * * * /etc/check-connection.sh" >> "$CRON_FILE"

    echo -e "${GREEN}check-connection.sh успешно установлен и настроен${RESET}"
}

install_all() {
    install_subs
    install_check
}

show_status() {
    echo ""
    echo "Installed scripts:"

    [ -f "$SUBS_FILE" ] && echo "✔ subs.sh installed" || echo "✘ subs.sh not installed"
    [ -f "$CHECK_FILE" ] && echo "✔ check-connection.sh installed" || echo "✘ check-connection.sh not installed"

    echo ""
}

self_update() {
    echo ""
    echo "Updating menu.sh..."

    TMP="/tmp/menu_update.sh"
    SELF="$0"

    curl -fsSL "$REPO/menu.sh" -o "$TMP"

    if [ ! -s "$TMP" ]; then
        echo -e "${RED}Download failed${RESET}"
        return
    fi

    chmod +x "$TMP"
    mv "$TMP" "$SELF"

    echo -e "${GREEN}Menu successfully updated${RESET}"
    echo "Restarting..."

    exec "$SELF"
}

pause() {
    echo ""
    echo "Нажмите любую клавишу для возвращения в меню..."
    read -n 1 -s
}

while true
do
    echo ""
    echo "=============================="
    echo " Podkop Scripts Installer"
    echo "=============================="
    echo "1) Установить subs.sh"
    echo "2) Установить check-connection.sh"
    echo "3) Установить Всё"
    echo "4) Show status"
    echo "5) Update menu"
    echo "0) Exit"
    echo ""

    printf "Select option: "
    read choice

    case "$choice" in
        1) install_subs ;;
        2) install_check ;;
        3) install_all ;;
        4)
            show_status
            pause
            ;;
        5) self_update ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
