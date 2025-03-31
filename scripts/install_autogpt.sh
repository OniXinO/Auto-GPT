#!/bin/bash

# Скрипт для автоматичного створення та встановлення пакету Auto-GPT
# Автор: Mentat
# Дата: 2025-03-31

set -e  # Скрипт зупиниться при виникненні помилки

# Кольори для виводу
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функція для виведення повідомлень з форматуванням
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Перевірка, чи скрипт запущено з правами суперкористувача
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        error "Цей скрипт потрібно запускати з правами суперкористувача (sudo)"
    fi
}

# Встановлення необхідних залежностей
install_dependencies() {
    log "Встановлення необхідних залежностей..."
    
    apt-get update
    apt-get install -y git dpkg python3 python3-pip python3-venv docker.io curl
    
    # Опціонально встановити ImageMagick для створення іконки
    if ! command -v convert >/dev/null 2>&1; then
        log "Встановлення ImageMagick для створення іконки..."
        apt-get install -y imagemagick
    fi
}

# Створення пакету за допомогою іншого скрипту
build_package() {
    log "Створення .deb пакету Auto-GPT..."
    
    # Перевіряємо, чи існує скрипт створення пакету
    build_script="./scripts/build_linux_package.sh"
    
    if [ ! -f "$build_script" ]; then
        # Якщо запускаємо з іншої директорії, намагаємося знайти скрипт
        if [ -f "build_linux_package.sh" ]; then
            build_script="./build_linux_package.sh"
        else
            error "Скрипт створення пакету не знайдено. Перейдіть у кореневу директорію проекту."
        fi
    fi
    
    # Налаштовуємо права на виконання для скрипту
    chmod +x $build_script
    
    # Запускаємо скрипт від імені звичайного користувача для створення пакету
    if [ -n "$SUDO_USER" ]; then
        sudo -u $SUDO_USER $build_script
    else
        $build_script
    fi
}

# Встановлення пакету
install_package() {
    log "Встановлення пакету Auto-GPT..."
    
    # Перевіряємо наявність .deb файлу
    if [ ! -f "autogpt_1.0.0_all.deb" ]; then
        error "Файл пакету autogpt_1.0.0_all.deb не знайдено. Створення пакету не вдалося."
    fi
    
    # Встановлюємо пакет
    DEBIAN_FRONTEND=noninteractive apt-get install -y ./autogpt_1.0.0_all.deb
    
    log "Auto-GPT успішно встановлено!"
}

# Налаштування OpenAI API ключа (опціонально)
configure_openai_key() {
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
    else
        USER_HOME=$HOME
    fi
    
    CONFIG_DIR="$USER_HOME/.autogpt"
    ENV_FILE="$CONFIG_DIR/.env"
    
    # Налаштувати конфігураційний файл, якщо не існує
    if [ ! -d "$CONFIG_DIR" ]; then
        log "Створення конфігураційної директорії для користувача $SUDO_USER..."
        mkdir -p "$CONFIG_DIR"
        if [ -n "$SUDO_USER" ]; then
            chown $SUDO_USER:$SUDO_USER "$CONFIG_DIR"
        fi
    fi
    
    # Копіювати шаблон, якщо .env не існує
    if [ ! -f "$ENV_FILE" ]; then
        log "Створення файлу конфігурації $ENV_FILE..."
        cp /usr/share/autogpt/.env.template "$ENV_FILE"
        if [ -n "$SUDO_USER" ]; then
            chown $SUDO_USER:$SUDO_USER "$ENV_FILE"
        fi
    fi
    
    # Запитати OpenAI API ключ, якщо користувач хоче його налаштувати зараз
    read -p "Бажаєте налаштувати OpenAI API ключ зараз? (y/n): " setup_key
    if [[ "$setup_key" == "y" || "$setup_key" == "Y" ]]; then
        read -p "Введіть ваш OpenAI API ключ: " api_key
        
        # Зберегти ключ у файлі .env
        if [ -n "$api_key" ]; then
            # Замінюємо рядок OPENAI_API_KEY у файлі .env
            sed -i "s/^OPENAI_API_KEY=.*$/OPENAI_API_KEY=$api_key/" "$ENV_FILE"
            log "OpenAI API ключ успішно налаштовано!"
        else
            warn "API ключ не було введено. Вам потрібно буде налаштувати його пізніше в $ENV_FILE"
        fi
    else
        info "Ви можете налаштувати OpenAI API ключ пізніше, відредагувавши файл $ENV_FILE"
    fi
}

# Показати інструкції користувачу
show_instructions() {
    info "================================================================================"
    info "Auto-GPT успішно встановлено та налаштовано!"
    info ""
    info "Щоб запустити Auto-GPT, виконайте команду:"
    info "   autogpt"
    info ""
    info "Налаштування знаходяться у директорії ~/.autogpt/"
    info "Для зміни параметрів відредагуйте файл ~/.autogpt/.env"
    info ""
    info "Якщо у вас виникнуть проблеми, перевірте документацію:"
    info "   https://github.com/Significant-Gravitas/Auto-GPT"
    info "================================================================================"
}

# Основна функція
main() {
    log "Початок автоматичного встановлення Auto-GPT..."
    
    check_sudo
    install_dependencies
    build_package
    install_package
    configure_openai_key
    show_instructions
    
    log "Встановлення Auto-GPT завершено успішно!"
}

# Запуск скрипту
main
