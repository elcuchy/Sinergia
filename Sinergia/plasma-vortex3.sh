#!/bin/bash
# Instala el splash de Plasma "Arch Simple Blue KDE 6" (KDE Store id 2136517)
# en la ubicación real que usa Plasma 6 para los splash: /usr/share/plasma/look-and-feel/
set -euo pipefail
trap 'echo "==> ERROR en línea $LINENO (comando: $BASH_COMMAND)" >&2' ERR

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")

CONTENT_ID="2136517"   # Arch Simple Blue KDE 6

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> Consultando KDE Store (id $CONTENT_ID)..."
API_URL="https://api.kde-look.org/ocs/v1/content/data/${CONTENT_ID}"
XML=$(curl -fsSL "$API_URL")

DL_URL=$(echo "$XML" | grep -oP '(?<=<downloadlink1>)[^<]+')
DL_NAME=$(echo "$XML" | grep -oP '(?<=<downloadname1>)[^<]+')

if [ -z "$DL_URL" ]; then
    echo "==> ERROR: KDE Store no devolvió un link de descarga para el id $CONTENT_ID." >&2
    exit 1
fi

echo "==> Descargando $DL_NAME..."
curl -fsSL "$DL_URL" -o "$TMP/$DL_NAME"

echo "==> Extrayendo..."
EXTRACT_DIR="$TMP/extracted"
mkdir -p "$EXTRACT_DIR"
case "$DL_NAME" in
    *.tar.gz|*.tgz) tar -xzf "$TMP/$DL_NAME" -C "$EXTRACT_DIR" ;;
    *.tar.xz)       tar -xJf "$TMP/$DL_NAME" -C "$EXTRACT_DIR" ;;
    *.tar.bz2)      tar -xjf "$TMP/$DL_NAME" -C "$EXTRACT_DIR" ;;
    *.zip)          unzip -q "$TMP/$DL_NAME" -d "$EXTRACT_DIR" ;;
    *) echo "==> ERROR: formato de archivo no reconocido ($DL_NAME)." >&2; exit 1 ;;
esac

# Ubicar el paquete real buscando contents/splash/Splash.qml (así funciona
# tanto si el .tar.gz trae una carpeta contenedora como si no)
SPLASH_QML=$(find "$EXTRACT_DIR" -maxdepth 6 -path "*/contents/splash/Splash.qml" | head -n1 || true)
if [ -z "$SPLASH_QML" ]; then
    echo "==> ERROR: no se encontró contents/splash/Splash.qml dentro del paquete descargado." >&2
    echo "==> Estructura descargada:" >&2
    find "$EXTRACT_DIR" -maxdepth 4 >&2
    exit 1
fi
PKG_DIR=$(dirname "$(dirname "$(dirname "$SPLASH_QML")")")
echo "==> Paquete encontrado en: $PKG_DIR"

# ID del tema: primero metadata.json (formato KPackage de Plasma 6),
# si no está, metadata.desktop (formato viejo)
THEME_ID=""
if [ -f "$PKG_DIR/metadata.json" ]; then
    THEME_ID=$(grep -oP '"Id"\s*:\s*"\K[^"]+' "$PKG_DIR/metadata.json" | head -n1 || true)
fi
if [ -z "$THEME_ID" ] && [ -f "$PKG_DIR/metadata.desktop" ]; then
    THEME_ID=$(grep -oP '(?<=^X-KDE-PluginInfo-Name=).+' "$PKG_DIR/metadata.desktop" | head -n1 || true)
fi
THEME_ID=${THEME_ID:-archsimpleblue}
echo "==> ID del tema detectado: $THEME_ID"

# El .git no hace falta y no debe quedar instalado en el sistema
rm -rf "$PKG_DIR/.git"

# Instalar como paquete Plasma/LookAndFeel, que es donde Plasma 6 busca los splash
DEST_DIR="/usr/share/plasma/look-and-feel/$THEME_ID"
echo "==> Instalando en $DEST_DIR ..."
sudo mkdir -p "$DEST_DIR"
sudo cp -r "$PKG_DIR"/* "$DEST_DIR/"

# Fijar el splash por defecto para el usuario
KSPLASHRC="$USER_HOME/.config/ksplashrc"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if [ -f "$KSPLASHRC" ] && grep -q "^\[KSplash\]" "$KSPLASHRC"; then
    if grep -q "^Theme=" "$KSPLASHRC"; then
        sudo -u "$REAL_USER" sed -i "s|^Theme=.*|Theme=$THEME_ID|" "$KSPLASHRC"
    else
        sudo -u "$REAL_USER" sed -i "/^\[KSplash\]/a Theme=$THEME_ID" "$KSPLASHRC"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[KSplash]\nTheme=%s\n' '$THEME_ID' >> '$KSPLASHRC'"
fi

echo "======================================================"
echo " Listo."
echo " Tema instalado en: $DEST_DIR"
echo " Fijado en: $KSPLASHRC (Theme=$THEME_ID)"
echo " Para probarlo sin reiniciar sesión: ksplashqml $THEME_ID --test"
echo "======================================================"
