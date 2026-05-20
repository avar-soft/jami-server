<div align="center">

# 📡 Jami Server — Auto Installer

**Автоматическая установка сервера Jami**
DHT Bootstrap-нода + STUN/TURN (coturn) - одним скриптом

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](jami.sh)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Jami](https://img.shields.io/badge/Jami-Distributed%20Communication-00A0E3?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyem0wIDE4Yy00LjQxIDAtOC0zLjU5LTgtOHMzLjU5LTggOC04IDggMy41OSA4IDgtMy41OSA4LTggOHoiLz48L3N2Zz4=)](https://jami.net)
[![coturn](https://img.shields.io/badge/coturn-STUN%2FTURN-FF6B35)](https://github.com/coturn/coturn)
[![OpenDHT](https://img.shields.io/badge/OpenDHT-Bootstrap%20Node-6C3483)](https://github.com/savoirfairelinux/opendht)

<br/>

![Demo](https://img.shields.io/badge/▶_Быстрый_старт-одна_команда-success?style=for-the-badge)

```bash
curl -fsSL https://raw.githubusercontent.com/avar-soft/jami-server/main/jami.sh -o jami.sh && sudo bash jami.sh
```

</div>

---

## 💡 О проекте

Этот скрипт разворачивает полноценную инфраструктуру для **децентрализованной связи Jami** без зависимости от публичных серверов:

- **OpenDHT Bootstrap-нода** — точка входа в DHT-сеть, обеспечивает обнаружение пользователей
- **coturn STUN/TURN** — пробивает NAT и обеспечивает надёжную передачу медиа-трафика
- **systemd-сервисы** с авто-перезапуском и изоляцией безопасности
- **UFW firewall** — автоматическая настройка всех нужных правил

> Вся коммуникация остаётся в вашей инфраструктуре. Никаких внешних зависимостей после установки.

---

## ✅ Требования

| Компонент   | Минимум                                      |
|-------------|----------------------------------------------|
| ОС          | Ubuntu 20.04 / 22.04 / 24.04                 |
| Права       | `root` или `sudo`                            |
| CPU         | 1 ядро, x86\_64 / aarch64                   |
| RAM         | 512 MB                                       |
| Сеть        | Публичный IP-адрес                           |
| Порты       | 60000–64000 (настраиваются)                  |

---

## 🚀 Быстрый старт

**Способ 1 — напрямую:**
```bash
curl -fsSL https://raw.githubusercontent.com/avar-soft/jami-server/main/jami.sh -o jami.sh && sudo bash jami.sh
```

**Способ 2 — скачать и запустить:**
```bash
wget https://raw.githubusercontent.com/avar-soft/jami-server/main/jami.sh
chmod +x jami.sh
sudo bash jami.sh
```

Интерактивный ввод при запуске:

```bash
➤ IP-адрес сервера [89.169.44.54]:        ← авто-определяется, можно изменить
➤ Домен для TLS (Enter — пропустить):     ← необязательно
➤ Логин TURN-сервера:
➤ Пароль TURN-сервера:                    ← скрытый ввод
➤ Повторите пароль:                       ← подтверждение
➤ Порт DHT прокси-сервера [8080]:         ← DHT - прокси 
➤ Продолжить установку? [Y/n]:
```

---

## ⚙️ Что делает скрипт

```
1. Проверяет права root и определяет IP сервера
2. Устанавливает все зависимости (apt)
3. Устанавливает dhtnode из репозитория Jami или собирает из исходников
4. Настраивает DHT Bootstrap-ноду как systemd-сервис
5. Настраивает coturn (STUN/TURN) с безопасной конфигурацией
6. Открывает нужные порты через UFW
7. Запускает и проверяет все сервисы
8. Сохраняет готовую конфигурацию в /root/jami-server-config.txt
```

---

## 🔥 Порты и назначение

| Порт          | Протокол  | Сервис       | Назначение                        |
|---------------|-----------|--------------|-----------------------------------|
| `62000`       | UDP + TCP | OpenDHT      | DHT Bootstrap — обнаружение узлов |
| `60000`       | UDP + TCP | coturn       | STUN / TURN                       |
| `61000`       | UDP + TCP | coturn       | TURNS (TLS, после настройки)      |
| `63000–64000` | UDP       | coturn relay | Медиа-трафик (RTP relay)          |

> Все значения портов настраиваются в шапке скрипта.

---

## 📦 Что устанавливается

```
/etc/dhtnode/
└── dhtnode.conf               # конфигурация DHT-ноды

/var/lib/dhtnode/              # рабочий каталог dhtnode

/etc/turnserver.conf           # конфигурация coturn

/etc/systemd/system/
└── dhtnode.service            # systemd-юнит DHT-ноды

/var/log/
├── dhtnode.log                # логи DHT
└── turnserver.log             # логи TURN

/root/jami-server-config.txt   # итоговая конфигурация для клиентов
```

---

## 🛠️ Управление сервисами

```bash
# Статус
systemctl status dhtnode coturn

# Логи DHT в реальном времени
journalctl -u dhtnode -f

# Логи TURN
tail -f /var/log/turnserver.log

# Перезапуск
systemctl restart dhtnode coturn

# Остановка
systemctl stop dhtnode coturn
```

---

## 📱 Настройка клиента Jami

После установки скрипт выведет готовые настройки. В приложении Jami перейдите:

**Аккаунт → Настройки → Соединение**

| Параметр               | Значение                            |
|------------------------|-------------------------------------|
| Bootstrap DHT          | `your.server.ip:62000`              |
| Включить STUN          | ✅ `stun:your.server.ip:60000`      |
| Включить TURN          | ✅ `turn:your.server.ip:60000`      |
| TURN логин             | значение `TURN_USER` из скрипта     |
| TURN пароль            | значение `TURN_PASSWORD` из скрипта |

---

## 🔒 Безопасность

Скрипт применяет следующие меры защиты:

- `dhtnode` запускается от отдельного системного пользователя без shell
- systemd-юнит использует `NoNewPrivileges`, `ProtectSystem`, `ProtectHome`
- coturn настроен с запретом `loopback-peers`, `multicast-peers`, `TLSv1.0/1.1`
- `stale-nonce=600` защищает от replay-атак
- UFW закрывает все порты, кроме явно разрешённых

---

## 🌐 TLS-сертификат для TURNS (опционально)

Для шифрованного TURNS (`turns://`) получите сертификат Let's Encrypt и раскомментируйте строки в `/etc/turnserver.conf`:

```bash
# 1. Установить certbot и получить сертификат
apt install certbot
certbot certonly --standalone -d turn.example.com

# 2. Раскомментировать в /etc/turnserver.conf:
#   cert=/etc/letsencrypt/live/turn.example.com/fullchain.pem
#   pkey=/etc/letsencrypt/live/turn.example.com/privkey.pem

# 3. Перезапустить coturn
systemctl restart coturn
```

---

## 📴 Offline-установка

Для установки без интернета скачайте заранее на машине с доступом:

```bash
# 1. Клонировать OpenDHT
git clone --depth=1 https://github.com/savoirfairelinux/opendht.git

# 2. Скачать .deb зависимости
mkdir deps && cd deps
apt-get download libgnutls28-dev nettle-dev libargon2-dev \
  libmsgpack-dev libssl-dev libfmt-dev libreadline-dev \
  libjsoncpp-dev libasio-dev coturn cmake build-essential

# 3. Перенести папки opendht/ и deps/ на сервер рядом со скриптом
```

Установить на сервере:
```bash
cd deps && dpkg -i *.deb 2>/dev/null; apt-get install -f -y
```

---

## 🗂️ Структура проекта

```
.
├── jami.sh          # Основной скрипт установки
├── README.md        # Документация
└── LICENSE          # MIT License
```

---

## 🐧 Совместимость

| Дистрибутив  | Версия             | Статус |
|--------------|--------------------|--------|
| Ubuntu       | 20.04 / 22.04 / 24.04 | ✅ Поддерживается |
| Debian       | 11 (Bullseye) / 12 (Bookworm) | ✅ Поддерживается |
| Другие       | —                  | ⚠️ Не тестировалось |

---


## 📱 Настройка мобильного клиента

Для корректной работы мобильного клиента используйте следующие параметры конфигурации.

### 🛠️ Общие сетевые параметры

| Параметр | Протокол / Адрес |
| :--- | :--- |
| **Сервер имен** | `xxx.yyy.zzz.www` |
| **DHT Bootstrap** | `xxx.yyy.zzz.www:62000` |
| **STUN** | `stun:xxx.yyy.zzz.www:60000` |
| **TURN** | `turn:xxx.yyy.zzz.www:60000` |
| **DHT Proxy** | `xxx.yyy.zzz.www:8080` |
| **Авторизация TURN** | `Логин: <name>` / `Пароль: *********` |

---

### ⚙️ Пошаговая настройка в приложении

#### 1. Раздел: OpenDHT
* **Начальная загрузка:** `xxx.yyy.zzz.www:62000`
* **Использование DHT прокси:** Включить
  * **Адрес прокси для DHT:** `xxx.yyy.zzz.www:8080`

#### 2. Раздел: Настройки аккаунта
* **Одноранговое соединение:**
  * [x] Включить UPnP
  * [x] Использовать TURN
    * **Адрес:** `turn:xxx.yyy.zzz.www:60000`
    * **Имя пользователя:** `<name>`
    * **Пароль:** `*********`

      
---

## 📄 Лицензия

Распространяется под лицензией [MIT](LICENSE). Свободно для личного и коммерческого использования.

---

<div align="center">

Сделано с ❤️ командой [avar-soft](https://github.com/avar-soft)

**Держите связь под своим контролем**

</div>
