#!/bin/bash

# Скрипт для автоматичного створення .deb пакету Auto-GPT
# Автор: Mentat
# Дата: 2025-03-31

set -e  # Скрипт зупиниться при виникненні помилки

# Кольори для виводу
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Перевірка наявності необхідних пакетів
check_dependencies() {
    log "Перевірка залежностей..."
    
    command -v git >/dev/null 2>&1 || { error "Потрібно встановити git. Виконайте: sudo apt install git"; }
    command -v dpkg-deb >/dev/null 2>&1 || { error "Потрібно встановити dpkg-deb. Виконайте: sudo apt install dpkg"; }
    command -v convert >/dev/null 2>&1 || { warn "ImageMagick не встановлено. Іконка за замовчуванням не буде створена."; }
}

# Створення структури каталогів
create_directory_structure() {
    log "Створення структури каталогів..."
    
    rm -rf autogpt-package
    
    mkdir -p autogpt-package/DEBIAN
    mkdir -p autogpt-package/usr/local/bin
    mkdir -p autogpt-package/usr/share/autogpt
    mkdir -p autogpt-package/usr/share/applications
    mkdir -p autogpt-package/usr/share/icons/hicolor/256x256/apps
}

# Створення файлів метаданих
create_metadata_files() {
    log "Створення файлів метаданих..."
    
    # Control file
    cat > autogpt-package/DEBIAN/control << EOF
Package: autogpt
Version: 1.0.0
Section: utils
Priority: optional
Architecture: all
Depends: python3 (>= 3.10), python3-pip, python3-venv, git, docker.io, curl
Maintainer: Auto-GPT Packager <autogpt@example.com>
Description: Auto-GPT - Autonomous AI Agent
 An experimental open-source application showcasing 
 the capabilities of the GPT-4 language model.
 Auto-GPT autonomously achieves goals using LLM models.
EOF

    # Post-installation script
    cat > autogpt-package/DEBIAN/postinst << EOF
#!/bin/bash
set -e

# Створення віртуального середовища
if [ ! -d "/usr/share/autogpt/.venv" ]; then
    echo "Створення віртуального середовища Python..."
    cd /usr/share/autogpt
    python3 -m venv .venv
    .venv/bin/pip install --upgrade pip
    .venv/bin/pip install -r requirements.txt
fi

# Встановлення прав виконання для скриптів
chmod +x /usr/local/bin/autogpt
chmod +x /usr/share/autogpt/run.sh

echo "Auto-GPT встановлено успішно!"
echo "Для запуску виконайте команду: autogpt"
echo "Перед першим запуском не забудьте налаштувати файл .env у директорії ~/.autogpt/"

# Створення конфігураційної директорії користувача
if [ ! -d "\$HOME/.autogpt" ]; then
    mkdir -p "\$HOME/.autogpt"
    cp /usr/share/autogpt/.env.template "\$HOME/.autogpt/.env"
    echo "Створено директорію \$HOME/.autogpt з шаблоном .env файлу"
    echo "Будь ласка, відредагуйте файл \$HOME/.autogpt/.env і додайте свій OpenAI API ключ"
fi

exit 0
EOF
    chmod +x autogpt-package/DEBIAN/postinst

    # Скрипт для запуску
    cat > autogpt-package/usr/local/bin/autogpt << EOF
#!/bin/bash

# Перевірка наявності .env файлу
if [ ! -f "\$HOME/.autogpt/.env" ]; then
    echo "Файл .env не знайдено в \$HOME/.autogpt/"
    echo "Копіюю шаблон .env файлу..."
    mkdir -p "\$HOME/.autogpt"
    cp /usr/share/autogpt/.env.template "\$HOME/.autogpt/.env"
    echo "Будь ласка, відредагуйте файл \$HOME/.autogpt/.env і додайте свій OpenAI API ключ"
    exit 1
fi

# Запуск Auto-GPT
cd /usr/share/autogpt
ln -sf "\$HOME/.autogpt/.env" ./.env
./run.sh "\$@"
EOF
    chmod +x autogpt-package/usr/local/bin/autogpt

    # .desktop файл
    cat > autogpt-package/usr/share/applications/autogpt.desktop << EOF
[Desktop Entry]
Name=Auto-GPT
Comment=Autonomous AI Agent
Exec=/usr/local/bin/autogpt
Icon=/usr/share/icons/hicolor/256x256/apps/autogpt.png
Terminal=true
Type=Application
Categories=Utility;AI;
EOF
}

# Створення іконки
create_icon() {
    log "Створення іконки..."
    
    # Спроба створити простий плейсхолдер для іконки, якщо ImageMagick встановлено
    if command -v convert >/dev/null 2>&1; then
        convert -size 256x256 xc:none -fill "#4A86E8" -draw "circle 128,128 128,64" \
                -fill white -pointsize 100 -gravity center -annotate 0 "AGT" \
                autogpt-package/usr/share/icons/hicolor/256x256/apps/autogpt.png
    else
        warn "ImageMagick не встановлено, іконка не буде створена."
        touch autogpt-package/usr/share/icons/hicolor/256x256/apps/autogpt.png
    fi
}

# Клонування коду Auto-GPT
clone_autogpt() {
    log "Клонування репозиторію Auto-GPT..."
    
    if [ -d "temp-autogpt" ]; then
        rm -rf temp-autogpt
    fi
    
    git clone -b stable https://github.com/Significant-Gravitas/Auto-GPT.git temp-autogpt
    
    log "Копіювання файлів у структуру пакету..."
    cp -r temp-autogpt/* autogpt-package/usr/share/autogpt/
    
    # Видалення зайвих файлів для зменшення розміру
    rm -rf autogpt-package/usr/share/autogpt/.git
    rm -rf autogpt-package/usr/share/autogpt/.github
    find autogpt-package/usr/share/autogpt -name "__pycache__" -type d -exec rm -rf {} +
    
    log "Видалення тимчасової директорії..."
    rm -rf temp-autogpt
}

# Збірка пакету
build_package() {
    log "Створення .deb пакету..."
    
    package_filename="autogpt_1.0.0_all.deb"
    dpkg-deb --build autogpt-package $package_filename
    
    if [ -f "$package_filename" ]; then
        log "Пакет успішно створено: $package_filename"
        log "Для встановлення виконайте: sudo apt install ./$package_filename"
    else
        error "Не вдалося створити пакет"
    fi
}

# Основна функція
main() {
    log "Початок процесу створення пакету Auto-GPT..."
    
    check_dependencies
    create_directory_structure
    create_metadata_files
    create_icon
    clone_autogpt
    build_package
    
    log "Процес створення пакету завершено успішно!"
}

# Запуск скрипту
main
