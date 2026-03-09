# Podkop-Scripts

A set of scripts to simplify working with **Podkop** and automate server management.

---

# 📦 Features

* Automatic subscription updates
* Podkop restart after updates
* Internet connection check
* Automatic server switching when there is no internet

---

# ⬇️ Installation

Download the scripts to `/etc`:

```bash
curl -sL https://raw.githubusercontent.com/KyKyIIIKuH/Podkop-Scripts/refs/heads/main/subs.sh -o /etc/subs.sh
curl -sL https://raw.githubusercontent.com/KyKyIIIKuH/Podkop-Scripts/refs/heads/main/check-connection.sh -o /etc/check-connection.sh
```

Give execution permissions:

```bash
chmod +x /etc/subs.sh
chmod +x /etc/check-connection.sh
```

---

# ⚙️ CRON Setup

Add a task in `crontab` for automatic daily subscription updates.

```bash
crontab -e
```

Add the following lines:

```bash
# Update subscription with Podkop restart
0 0 * * * /etc/subs.sh

# Check internet connection
*/1 * * * * /etc/check-connection.sh
```

---

# 📜 Scripts

## subs.sh

Script for updating subscriptions.

Functions:

* Retrieves the list of servers from the subscription
* Updates Podkop configuration
* Can restart Podkop

Example run:

```bash
bash /etc/subs.sh restart
```

---

## check-connection.sh

Internet connection check script.

Functions:

* Checks internet access
* If no internet:

  * Automatically switches the server in **selector**
  * Restores connection

Example run:

```bash
bash /etc/check-connection.sh
```

---

# 🧠 How it works

1. `subs.sh`

   * Retrieves servers from the subscription
   * Updates configuration
2. `check-connection.sh`

   * Checks internet
   * If no connection → switches server
3. `cron`

   * Automatically updates subscription daily
   * Checks internet connection every minute

---

# 📁 Project Structure

```
Podkop-Scripts
│
├── subs.sh
├── check-connection.sh
└── README.md
```

---

# 🚀 Purpose

This project is designed to **automate Podkop** and improve connection stability through:

* Subscription updates
* Automatic server switching
