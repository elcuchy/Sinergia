#!/bin/bash

# --- CONFIGURACIÓN DE TUS SCRIPTS DE GITHUB ---
URL_SCRIPT_1="https://github.com/SinergiaLinux/LinuxScripts/blob/main/Arch/Daro/Gnome/gnome-sinergia.sh"
URL_SCRIPT_2="https://github.com/SinergiaLinux/LinuxScripts/blob/main/Arch/Daro/Gnome/gnome-full.sh"
URL_SCRIPT_3="https://github.com/SinergiaLinux/LinuxScripts/blob/main/Arch/Daro/Gnome/gnome-monochrome.sh"

# Colores para la terminal
VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
NC='\033[0m' # Sin color

# Función para verificar dependencias básicas
check_deps() {
    if ! command -v curl &> /dev/null; then
        echo -e "${AMARILLO}curl no está instalado. Instalando...${NC}"
        sudo pacman -S --noconfirm curl
    fi
}

# Función para descargar y ejecutar el script seleccionado
ejecutar_script() {
    local url="$1"
    local nombre="$2"
    local tmp_file="/tmp/instalador_gnome_$$.sh"

    echo -e "${AMARILLO}Descargando $nombre...${NC}"
    if curl -fsSL "$url" -o "$tmp_file"; then
        chmod +x "$tmp_file"
        echo -e "${VERDE}Ejecutando $nombre...${NC}"
        # Ejecuta el script descargado
        bash "$tmp_file"
        rm -f "$tmp_file"
    else
        echo -e "${ROJO}Error: No se pudo descargar el script desde $url${NC}"
        echo -e "Verifica tu conexión a internet o que la URL sea correcta."
        return 1
    fi
}

# Verificamos que tengamos curl
check_deps

PS3="Selecciona una opción para instalar GNOME (1-3) o 4 para salir: "

# El comando select crea el menú automáticamente
select opcion in "Instalar GNOME Versión A" "Instalar GNOME Versión B" "Instalar GNOME Versión C" "Salir"; do
    case $REPLY in
        1)
            ejecutar_script "$URL_SCRIPT_1" "GNOME Versión Sinergia"
            break
            ;;
        2)
            ejecutar_script "$URL_SCRIPT_2" "GNOME Versión Full"
            break
            ;;
        3)
            ejecutar_script "$URL_SCRIPT_3" "GNOME Versión Monochrome"
            break
            ;;
        4)
            echo "Saliendo..."
            break
            ;;
        *)
            echo -e "${ROJO}Opción no válida. Por favor, elige un número del 1 al 4.${NC}"
            ;;
    esac
done
