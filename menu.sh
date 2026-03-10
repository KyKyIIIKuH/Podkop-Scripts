#!/bin/ash

REPO="https://raw.githubusercontent.com/KyKyIIIKuH/Podkop-Scripts/refs/heads/main"
SUBS_FILE="/etc/subs.sh"
CHECK_FILE="/etc/check-connection.sh"

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
    echo "Enter subscription URL:"
    read VLESS_URL < /dev/tty

    if [ -z "$VLESS_URL" ]; then
        echo "Subscription URL cannot be empty"
        return
    fi

    sed -i "s|^VLESS_URL=.*|VLESS_URL=\"$VLESS_URL\"|g" "$SUBS_FILE"

    sh "$SUBS_FILE"

    echo ""
    echo "subs.sh installed and configured!"
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

    echo "check-connection.sh installed!"
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

while true
do
    echo ""
    echo "=============================="
    echo " Podkop Scripts Installer"
    echo "=============================="
    echo "1) Install subs.sh"
    echo "2) Install check-connection.sh"
    echo "3) Install ALL"
    echo "4) Show status"
    echo "0) Exit"
    echo ""

    printf "Select option: "
    read choice < /dev/tty

    case "$choice" in
        1) install_subs ;;
        2) install_check ;;
        3) install_all ;;
        4) show_status ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
