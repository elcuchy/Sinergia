#!/bin/bash

# ==========================================
# CONFIGURACIÓN DE TUS SCRIPTS DE GITHUB
# ==========================================
# Reemplaza estas URLs con los enlaces "Raw" reales de tus scripts.

# --- URLs de GNOME ---
URL_GNOME_1="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Gnome/gnome-sinergia.sh"
URL_GNOME_2="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Gnome/gnome-full.sh"
URL_GNOME_3="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Gnome/gnome-monochrome.sh"

# --- URLs de Plasma ---
URL_PLASMA_1="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Plasma/plasma-sinergia.sh"
URL_PLASMA_2="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Plasma/plasma-full.sh"
URL_PLASMA_3="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Plasma/plasma-monochrome.sh"

# --- URLs de XFCE ---
URL_XFCE_1="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Xfce/xfce-sinergia.sh"
URL_XFCE_2="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Xfce/xfce-full.sh"
URL_XFCE_3="https://raw.githubusercontent.com/SinergiaLinux/LinuxScripts/refs/heads/main/Arch/Daro/Xfce/xfce-monochrome.sh"

# --- URLs de Trinity ---
URL_TRINITY_1="https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/trinity-variante1.sh"
URL_TRINITY_2="https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/trinity-variante2.sh"

# --- URLs de Enlightenment ---
URL_ENLIGHTENMENT_1="https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/enlightenment-variante1.sh"
URL_ENLIGHTENMENT_2="https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/enlightenment-variante2.sh"

# --- URLs de MATE ---
URL_MATE_1="https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/mate-variante1.sh"
URL_MATE_2="https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/mate-variante2.sh"

# ==========================================
# COLORES Y FUNCIONES BASE
# ==========================================
VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
AZUL='\033[0;36m'
NC='\033[0m' # Sin color

# Función para verificar dependencias básicas
check_deps() {
    if ! command -v curl &> /dev/null; then
        echo -e "${AMARILLO}curl no está instalado. Instalando...${NC}"
        sudo pacman -S --noconfirm curl
    fi
}

# Función maestra para descargar y ejecutar
ejecutar_script() {
    local url="$1"
    local nombre="$2"
    local tmp_file="/tmp/instalador_entorno_$$.sh"

    echo -e "${AMARILLO}Descargando $nombre...${NC}"
    # Usamos --fail para evitar descargar HTML de error
    if curl -fsSL --fail "$url" -o "$tmp_file"; then
        chmod +x "$tmp_file"
        echo -e "${VERDE}Ejecutando $nombre...${NC}"
        bash "$tmp_file"
        rm -f "$tmp_file"
    else
        echo -e "${ROJO}Error: No se pudo descargar el script desde $url${NC}"
        echo -e "Verifica tu conexión a internet o que la URL sea correcta."
        return 1
    fi
    # Pausa para que el usuario pueda leer los mensajes antes de volver al menú
    read -p "Presiona Enter para continuar..."
}

# ==========================================
# SUBMENÚS POR ENTORNO
# ==========================================

menu_gnome() {
    while true; do
        echo -e "\n${AZUL}--- MENÚ DE GNOME ---${NC}"
        echo "1) Instalar GNOME Versión Sinergia"
        echo "2) Instalar GNOME Versión Full"
        echo "3) Instalar GNOME Versión Monochrome"
        echo "4) Volver al menú principal"
        read -p "Selecciona una opción (1-4): " opcion_gnome

        case $opcion_gnome in
            1) ejecutar_script "$URL_GNOME_1" "GNOME Versión Sinergia" ;;
            2) ejecutar_script "$URL_GNOME_2" "GNOME Versión Full" ;;
            3) ejecutar_script "$URL_GNOME_3" "GNOME Versión Monochrome" ;;
            4) break ;;
            *) echo -e "${ROJO}Opción no válida.${NC}" ;;
        esac
    done
}

menu_plasma() {
    while true; do
        echo -e "\n${AZUL}--- MENÚ DE PLASMA ---${NC}"
        echo "1) Instalar Plasma Sinergia"
        echo "2) Instalar Plasma Full"
        echo "3) Instalar Plasma Monochrome"
        echo "4) Volver al menú principal"
        read -p "Selecciona una opción (1-4): " opcion_plasma

        case $opcion_plasma in
            1) ejecutar_script "$URL_PLASMA_1" "Plasma Sinergia" ;;
            2) ejecutar_script "$URL_PLASMA_2" "Plasma Full" ;;
            3) ejecutar_script "$URL_PLASMA_3" "Plasma Monochrome" ;;
            4) break ;;
            *) echo -e "${ROJO}Opción no válida.${NC}" ;;
        esac
    done
}

menu_xfce() {
    while true; do
        echo -e "\n${AZUL}--- MENÚ DE XFCE ---${NC}"
        echo "1) Instalar XFCE Sinergia"
        echo "2) Instalar XFCE Full"
        echo "3) Instalar XFCE Monochrome"
        echo "4) Volver al menú principal"
        read -p "Selecciona una opción (1-4): " opcion_xfce

        case $opcion_xfce in
            1) ejecutar_script "$URL_XFCE_1" "XFCE Sinergia" ;;
            2) ejecutar_script "$URL_XFCE_2" "XFCE Full" ;;
            3) ejecutar_script "$URL_XFCE_3" "XFCE Monochrome" ;;
            4) break ;;
            *) echo -e "${ROJO}Opción no válida.${NC}" ;;
        esac
    done
}

# ==========================================
# MENÚ PRINCIPAL
# ==========================================

# Verificamos dependencias al iniciar
check_deps

while true; do
    echo -e "\n${VERDE}=== INSTALADOR DE ENTORNOS DE ESCRITORIO ==="
    echo -e "===          ARCH LINUX                    ===${NC}"
    echo "1) Gestionar instalación de GNOME"
    echo "2) Gestionar instalación de Plasma (KDE)"
    echo "3) Gestionar instalación de XFCE"
    echo "4) Salir"
    read -p "Selecciona un entorno (1-4): " opcion_principal

    case $opcion_principal in
        1) menu_gnome ;;
        2) menu_plasma ;;
        3) menu_xfce ;;
        4) 
            echo -e "${VERDE}Saliendo del instalador. ¡Hasta luego!${NC}"
            exit 0 
            ;;
        *) echo -e "${ROJO}Opción no válida. Por favor, elige del 1 al 4.${NC}" ;;
    esac
done
