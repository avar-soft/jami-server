#!/bin/bash
# =============================================================================
#  Установка DHT (dhtnode) + STUN/TURN (coturn)
#  Запуск: sudo bash jami.sh
#  Совместимость: Ubuntu 20.04 / 22.04 / 24.04
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header()  { echo -e "\n${BOLD}${GREEN}==> $1${NC}"; }

# =============================================================================
# ССЫЛКИ НА РЕСУРСЫ (GitHub репозиторий)
# =============================================================================
GITHUB_RAW="https://raw.githubusercontent.com/avar-soft/jami-server/main/scr"
GITHUB_REPO="https://github.com/avar-soft/jami-server/raw/main/scr"

URL_OPENDHT="${GITHUB_REPO}/opendht-master.zip"
URL_RESTINIO="${GITHUB_REPO}/restinio-0.7.3.tar.bz2"
URL_EXPECTED="${GITHUB_RAW}/expected.hpp"

BUILD_TMP="/tmp/jami_install"

TURN_PORT=60000
TURNS_PORT=61000
DHT_PORT=62000
MIN_PORT=63000
MAX_PORT=64000

# =============================================================================
# ФУНКЦИИ
# =============================================================================

ask() {
    local prompt="$1" var="$2" default="$3" value
    if [[ -n "$default" ]]; then
        echo -ne "${CYAN}  ➤ ${prompt} [${default}]: ${NC}"
    else
        echo -ne "${CYAN}  ➤ ${prompt}: ${NC}"
    fi
    read -r value
    value="${value:-$default}"
    [[ -z "$value" ]] && error "Поле «${prompt}» не может быть пустым."
    printf -v "$var" '%s' "$value"
}

ask_password() {
    local prompt="$1" var="$2" value
    echo -ne "${CYAN}  ➤ ${prompt}: ${NC}"
    read -rs value
    echo
    [[ -z "$value" ]] && error "Пароль не может быть пустым."
    printf -v "$var" '%s' "$value"
}

download() {
    local url="$1" dest="$2" name
    name=$(basename "$dest")
    info "Скачиваем ${name}..."
    if command -v curl &>/dev/null; then
        curl -fsSL --progress-bar "$url" -o "$dest" \
            || error "Не удалось скачать: ${url}"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress "$url" -O "$dest" \
            || error "Не удалось скачать: ${url}"
    else
        error "Не найден curl или wget."
    fi
    success "${name} — скачан"
}

_build_opendht() {
    mkdir -p "$BUILD_TMP"

    apt-get install -y -qq \
        libcppunit-dev libjsoncpp-dev python3-dev python3-setuptools \
        libhttp-parser-dev libuv1-dev unzip

    # --- Restinio ---
    info "Загружаем Restinio из GitHub (scr/)..."
    download "$URL_EXPECTED" "${BUILD_TMP}/expected.hpp"
    download "$URL_RESTINIO" "${BUILD_TMP}/restinio-0.7.3.tar.bz2"

    mkdir -p /usr/include/nonstd
    cp "${BUILD_TMP}/expected.hpp" /usr/include/nonstd/expected.hpp

    RESTINIO_BUILD="${BUILD_TMP}/restinio_build"
    rm -rf "$RESTINIO_BUILD" && mkdir -p "$RESTINIO_BUILD"
    tar -xjf "${BUILD_TMP}/restinio-0.7.3.tar.bz2" -C "$RESTINIO_BUILD"
    cd "${RESTINIO_BUILD}"/restinio-0.7.3/dev
    cmake . \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DRESTINIO_TEST=Off \
        -DRESTINIO_SAMPLE=Off \
        -DRESTINIO_BENCHMARK=Off \
        -DRESTINIO_WITH_SOBJECTIZER=Off \
        -DRESTINIO_DEP_STANDALONE_ASIO=system \
        -DRESTINIO_DEP_LLHTTP=system \
        -DRESTINIO_DEP_FMT=system \
        -DRESTINIO_DEP_EXPECTED_LITE=system
    make -j"$(nproc)" && make install
    cd /
    success "Restinio установлен"

    # --- OpenDHT ---
    info "Загружаем opendht-master.zip из GitHub (scr/)..."
    download "$URL_OPENDHT" "${BUILD_TMP}/opendht-master.zip"

    OPENDHT_BUILD="${BUILD_TMP}/opendht_build"
    rm -rf "$OPENDHT_BUILD" && mkdir -p "$OPENDHT_BUILD"
    unzip -q "${BUILD_TMP}/opendht-master.zip" -d "$OPENDHT_BUILD"

    # CMakeLists.txt может быть в корне архива или во вложенной папке
    # Берём CMakeLists.txt с минимальной глубиной вложенности (корень проекта, не tools/)
    _cmake_file=$(find "$OPENDHT_BUILD" -name "CMakeLists.txt" | awk -F/ '{print NF" "$0}' | sort -n | head -1 | cut -d" " -f2-)
    [[ -z "$_cmake_file" ]] && error "CMakeLists.txt не найден в архиве opendht."
    SRC_DIR=$(dirname "$_cmake_file")
    info "Исходники OpenDHT: $SRC_DIR"

    info "Сборка OpenDHT (5-10 мин)..."
    BUILD_DIR="${OPENDHT_BUILD}/cmake_build"
    mkdir -p "$BUILD_DIR"
    cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DOPENDHT_TOOLS=ON \
        -DOPENDHT_PYTHON=OFF \
        -DOPENDHT_HTTP=ON \
        -DOPENDHT_PROXY_SERVER=ON \
        -DOPENDHT_PUSH_NOTIFICATIONS=OFF
    cmake --build "$BUILD_DIR" -j"$(nproc)"
    cmake --install "$BUILD_DIR"
    ldconfig
    rm -rf "$BUILD_TMP"
    success "OpenDHT собран и установлен"
}

# =============================================================================
# ПРОВЕРКИ
# =============================================================================
header "Проверка окружения"
[[ $EUID -ne 0 ]] && error "Запустите скрипт от root: sudo bash $0"
success "Права root — OK"

# =============================================================================
# ИНТЕРАКТИВНЫЙ ВВОД НАСТРОЕК
# =============================================================================
header "Настройка параметров сервера"
echo ""

AUTO_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
       || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
       || hostname -I | awk '{print $1}')

ask "IP-адрес сервера" SERVER_IP "${AUTO_IP}"

echo -ne "${CYAN}  ➤ Домен для TLS (Enter — пропустить): ${NC}"
read -r TURN_DOMAIN
TURN_DOMAIN="${TURN_DOMAIN:-}"

ask "Логин TURN-сервера" TURN_USER ""

while true; do
    ask_password "Пароль TURN-сервера" TURN_PASSWORD
    ask_password "Повторите пароль"    TURN_PASSWORD2
    [[ "$TURN_PASSWORD" == "$TURN_PASSWORD2" ]] && break
    echo -e "${RED}  Пароли не совпадают, попробуйте ещё раз.${NC}"
done

echo ""
echo -e "${BOLD}  Итоговые параметры:${NC}"
echo -e "  IP сервера : ${GREEN}${SERVER_IP}${NC}"
echo -e "  TLS домен  : ${GREEN}${TURN_DOMAIN:-не задан}${NC}"
echo -e "  TURN логин : ${GREEN}${TURN_USER}${NC}"
echo -e "  TURN пароль: ${GREEN}$(echo "$TURN_PASSWORD" | sed 's/./*/g')${NC}"
echo -e "  DHT порт   : ${GREEN}${DHT_PORT}${NC}"
echo -e "  TURN порт  : ${GREEN}${TURN_PORT}${NC}"
echo ""
echo -ne "${YELLOW}  Продолжить установку? [Y/n]: ${NC}"
read -r CONFIRM
[[ "${CONFIRM,,}" == "n" ]] && { echo "Установка отменена."; exit 0; }

# =============================================================================
# ОБНОВЛЕНИЕ СИСТЕМЫ
# =============================================================================
header "Обновление пакетов"

# Убираем старый репозиторий Jami — он больше не нужен и ломает apt update
rm -f /etc/apt/sources.list.d/jami.list /usr/share/keyrings/jami-archive-keyring.gpg

apt-get update -qq || true
apt-get upgrade -y -qq || true

apt-get install -y -qq \
    curl wget git cmake build-essential pkg-config unzip \
    libssl-dev libgnutls28-dev nettle-dev \
    libfmt-dev libmsgpack-dev \
    libargon2-dev libreadline-dev \
    coturn ufw systemd gnupg2 lsb-release || true

apt-get install -y -qq libasio-dev 2>/dev/null \
    || apt-get install -y -qq libboost-dev 2>/dev/null \
    || warn "libasio-dev не найден, продолжаем без него"

success "Пакеты установлены"

# =============================================================================
# УСТАНОВКА dhtnode — ТОЛЬКО из исходников с GitHub
# =============================================================================
header "Установка OpenDHT (dhtnode)"

if command -v dhtnode &>/dev/null; then
    warn "dhtnode уже установлен: $(dhtnode --version 2>/dev/null || echo 'версия неизвестна')"
else
    info "Собираем dhtnode из исходников (avar-soft/jami-server scr/)..."
    _build_opendht
fi

DHTNODE_BIN=$(command -v dhtnode 2>/dev/null || echo "")
[[ -z "$DHTNODE_BIN" ]] && error "dhtnode не найден после установки."
success "dhtnode найден: $DHTNODE_BIN"

# =============================================================================
# КОНФИГУРАЦИЯ dhtnode
# =============================================================================
header "Настройка DHT Bootstrap-ноды"

useradd --system --no-create-home --shell /usr/sbin/nologin dhtnode 2>/dev/null || true
mkdir -p /etc/dhtnode /var/lib/dhtnode
chown dhtnode:dhtnode /var/lib/dhtnode
touch /var/log/dhtnode.log
chown dhtnode:dhtnode /var/log/dhtnode.log

cat > /etc/dhtnode/dhtnode.conf <<EOF
port = ${DHT_PORT}
logfile = /var/log/dhtnode.log
bootstrap = bootstrap.jami.net:4222
EOF

cat > /etc/systemd/system/dhtnode.service <<EOF
[Unit]
Description=OpenDHT Bootstrap Node for Jami
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=dhtnode
Group=dhtnode
WorkingDirectory=/var/lib/dhtnode
ExecStart=${DHTNODE_BIN} -s -p ${DHT_PORT} -b bootstrap.jami.net:4222 -l /var/log/dhtnode.log
Restart=on-failure
RestartSec=10
LimitNOFILE=65536
StandardInput=null
StandardOutput=journal
StandardError=journal
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/dhtnode /var/log

[Install]
WantedBy=multi-user.target
EOF

success "DHT сервис настроен (порт $DHT_PORT/UDP)"

# =============================================================================
# КОНФИГУРАЦИЯ COTURN (STUN/TURN)
# =============================================================================
header "Настройка coturn (STUN/TURN)"

[[ -f /etc/turnserver.conf ]] && cp /etc/turnserver.conf /etc/turnserver.conf.bak

REALM="${TURN_DOMAIN:-$SERVER_IP}"

cat > /etc/turnserver.conf <<EOF
listening-port=${TURN_PORT}
tls-listening-port=${TURNS_PORT}
listening-ip=${SERVER_IP}
external-ip=${SERVER_IP}
relay-ip=${SERVER_IP}

realm=${REALM}
server-name=${REALM}

lt-cred-mech
user=${TURN_USER}:${TURN_PASSWORD}

min-port=${MIN_PORT}
max-port=${MAX_PORT}

# TLS (раскомментируйте после получения сертификата)
# cert=/etc/letsencrypt/live/${REALM}/fullchain.pem
# pkey=/etc/letsencrypt/live/${REALM}/privkey.pem

no-multicast-peers
no-loopback-peers
fingerprint
stale-nonce=600
no-tlsv1
no-tlsv1_1

total-quota=200
bps-capacity=0
max-allocate-timeout=60

log-file=/var/log/turnserver.log
verbose

pidfile=/var/run/turnserver.pid
EOF

if grep -q "TURNSERVER_ENABLED" /etc/default/coturn 2>/dev/null; then
    sed -i 's/.*TURNSERVER_ENABLED.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
else
    echo "TURNSERVER_ENABLED=1" >> /etc/default/coturn
fi

success "coturn настроен (STUN/TURN порт $TURN_PORT, TLS $TURNS_PORT)"

# =============================================================================
# НАСТРОЙКА FIREWALL (UFW)
# =============================================================================
header "Настройка Firewall (UFW)"

ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

ufw allow 22/tcp                       comment "SSH"              >/dev/null
ufw allow ${DHT_PORT}/udp              comment "Jami DHT"         >/dev/null
ufw allow ${TURN_PORT}/udp             comment "STUN/TURN UDP"    >/dev/null
ufw allow ${TURN_PORT}/tcp             comment "STUN/TURN TCP"    >/dev/null
ufw allow ${TURNS_PORT}/udp            comment "TURNS TLS UDP"    >/dev/null
ufw allow ${TURNS_PORT}/tcp            comment "TURNS TLS TCP"    >/dev/null
ufw allow ${MIN_PORT}:${MAX_PORT}/udp  comment "TURN relay media" >/dev/null

ufw --force enable >/dev/null
success "Firewall настроен"

# =============================================================================
# ЗАПУСК СЕРВИСОВ
# =============================================================================
header "Запуск сервисов"

systemctl daemon-reload

systemctl enable dhtnode >/dev/null 2>&1
systemctl restart dhtnode
sleep 2
if systemctl is-active --quiet dhtnode; then
    success "dhtnode запущен"
else
    warn "dhtnode не запустился — проверьте: journalctl -u dhtnode -n 30"
fi

systemctl enable coturn >/dev/null 2>&1
systemctl restart coturn
sleep 2
if systemctl is-active --quiet coturn; then
    success "coturn (STUN/TURN) запущен"
else
    warn "coturn не запустился — проверьте: journalctl -u coturn -n 30"
fi

# =============================================================================
# ПРОВЕРКА ПОРТОВ
# =============================================================================
header "Проверка портов"

check_port() {
    local port=$1 proto=$2 name=$3
    if ss -ln --${proto} 2>/dev/null | grep -qE ":${port}\s" \
    || ss -ln -${proto:0:1} 2>/dev/null | grep -qE ":${port}\s"; then
        success "$name порт $port/$proto — СЛУШАЕТ"
    else
        warn "$name порт $port/$proto — НЕ СЛУШАЕТ"
    fi
}

check_port $DHT_PORT  udp "DHT"
check_port $TURN_PORT udp "STUN/TURN"
check_port $TURN_PORT tcp "STUN/TURN"

# =============================================================================
# СОХРАНЕНИЕ КОНФИГУРАЦИИ
# =============================================================================
CREDS_FILE="/root/jami-server-config.txt"
cat > "$CREDS_FILE" <<EOF
===========================================================
  Настройки серверов Jami
  Дата установки: $(date '+%Y-%m-%d %H:%M:%S')
===========================================================

--- DHT Bootstrap-нода ---
Адрес:     ${SERVER_IP}:${DHT_PORT}

--- STUN сервер ---
URI:       stun:${SERVER_IP}:${TURN_PORT}

--- TURN сервер ---
URI:       turn:${SERVER_IP}:${TURN_PORT}
Логин:     ${TURN_USER}
Пароль:    ${TURN_PASSWORD}

--- TURN TLS (после настройки сертификатов) ---
URI:       turns:${SERVER_IP}:${TURNS_PORT}

===========================================================
  Настройка в Jami (клиент)
===========================================================

Аккаунт → Настройки → Соединение:

[Bootstrap-нода DHT]
  ${SERVER_IP}:${DHT_PORT}

[STUN]
  Включить STUN: YES
  Сервер: stun:${SERVER_IP}:${TURN_PORT}

[TURN]
  Включить TURN: YES
  Сервер: turn:${SERVER_IP}:${TURN_PORT}
  Логин:  ${TURN_USER}
  Пароль: ${TURN_PASSWORD}

===========================================================
  Полезные команды
===========================================================

Статус:       systemctl status dhtnode coturn
Логи DHT:     journalctl -u dhtnode -f
Логи TURN:    tail -f /var/log/turnserver.log
Перезапуск:   systemctl restart dhtnode coturn

TLS-сертификат (Let's Encrypt):
  apt install certbot
  certbot certonly --standalone -d ${REALM}
  # Раскомментируйте cert= и pkey= в /etc/turnserver.conf
  # systemctl restart coturn

===========================================================
  ХРАНИТЕ ЭТОТ ФАЙЛ В БЕЗОПАСНОМ МЕСТЕ
===========================================================
EOF

chmod 600 "$CREDS_FILE"

# =============================================================================
# ИТОГ
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║        Установка завершена успешно!                      ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}DHT Bootstrap:${NC}  ${SERVER_IP}:${DHT_PORT}"
echo -e "  ${BOLD}STUN:${NC}           stun:${SERVER_IP}:${TURN_PORT}"
echo -e "  ${BOLD}TURN:${NC}           turn:${SERVER_IP}:${TURN_PORT}"
echo -e "  ${BOLD}TURN login:${NC}     ${TURN_USER} / $(echo "$TURN_PASSWORD" | sed 's/./*/g')"
echo ""
echo -e "  ${YELLOW}Полная конфигурация сохранена в:${NC} ${CREDS_FILE}"
echo ""
