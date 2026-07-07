#!/bin/bash
set -e

# ------------------------------------------------------------
# Установка сертификатов (если есть)
# ------------------------------------------------------------
CERT_DIR="/certs"
if [ -d "$CERT_DIR" ] && [ -n "$(ls -A $CERT_DIR/*.crt 2>/dev/null)" ]; then
    echo "Обнаружены сертификаты в $CERT_DIR, устанавливаем в системное хранилище..."
    sudo cp $CERT_DIR/*.crt /usr/local/share/ca-certificates/
    sudo update-ca-certificates --fresh
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    echo "Сертификаты установлены, переменные окружения настроены."
else
    echo "Папка /certs не содержит .crt файлов или отсутствует, пропускаем."
fi

# ------------------------------------------------------------
# Фикс прав для ~/.local
# ------------------------------------------------------------
echo "Настраиваем права на ~/.local для пользователя vscode..."
sudo mkdir -p /home/vscode/.local/share/code-server
sudo chown -R vscode:vscode /home/vscode/.local

# ------------------------------------------------------------
# Копирование запасных расширений, если папка extensions пуста или отсутствует
# ------------------------------------------------------------
EXTENSIONS_DIR="/home/vscode/.local/share/code-server/extensions"
SAVE_DIR="/home/vscode/.local/share/code-server/extensions-save"

if [ -d "$SAVE_DIR" ]; then
    if [ ! -d "$EXTENSIONS_DIR" ] || [ -z "$(ls -A "$EXTENSIONS_DIR" 2>/dev/null)" ]; then
        echo "Копируем сохранённые расширения из $SAVE_DIR в $EXTENSIONS_DIR"
        mkdir -p "$EXTENSIONS_DIR"
        cp -r "$SAVE_DIR"/* "$EXTENSIONS_DIR/"
        # После копирования снова убедимся, что права принадлежат vscode
        sudo chown -R vscode:vscode "$EXTENSIONS_DIR"
    else
        echo "Папка $EXTENSIONS_DIR уже содержит расширения, пропускаем копирование."
    fi
else
    echo "Запасная папка $SAVE_DIR не найдена, пропускаем."
fi

# ------------------------------------------------------------
# Настройка пароля (если задан)
# ------------------------------------------------------------
if [ ! -z "$PASSWORD" ]; then
    echo "Устанавливаем пароль из переменной окружения..."
    sed -i "s/password:.*/password: $PASSWORD/g" /home/vscode/.config/code-server/config.yaml
fi

# ------------------------------------------------------------
# Переход в рабочую директорию (если задана)
# ------------------------------------------------------------
if [ ! -z "$WORKSPACE" ]; then
    mkdir -p /home/vscode/$WORKSPACE
    cd /home/vscode/$WORKSPACE
fi

# ------------------------------------------------------------
# Запуск code-server с отключённой проверкой доверия
# ------------------------------------------------------------
exec code-server --bind-addr 0.0.0.0:8080 --disable-workspace-trust /home/vscode/$WORKSPACE

