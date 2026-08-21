#!/bin/bash
# Custom params
FULL_BATTERY_THRESHOLD=95
LOW_BATTERY_THRESHOLD=20

# color base
COLOR_BASE="#FFFFFF"
COLOR_ALERT="#FF0000"
COLOR_OK="#00FF00"

# Archivos temporales nativos de Linux para guardar el estado
PID_FILE="/tmp/battery-low-alert.pid"

# Función para PONER la alerta en pantalla
show_battery_alert() {
    # Si ya hay una alerta en pantalla, no hacemos nada
    if [ -f "$PID_FILE" ]; then
        return
    fi

    # Creamos un candado vacío
    touch "$PID_FILE"

    # Usamos hyprctl overlay para dibujar texto estático en la esquina superior derecha
    # Redirigimos a segundo plano (&) para que el script no se quede congelado
    hyprctl notify 3 3600000 "rgb(ff0000)" "Your battery is low. Please plug in your charger." &
    
}

# Función para QUITAR la alerta de la pantalla inmediatamente
hide_battery_alert() {
    if [ -f "$PID_FILE" ]; then
        # Leemos el PID y matamos el proceso del overlay de forma segura
        hyprctl dismissnotify -1
        
        # Limpiamos el archivo temporal
        rm -f "$PID_FILE"
    fi
}

TRAY_ICON="󰍛" # Icono de la bandeja del sistema

# 1. Obtener uso de CPU (Suma el uso de usuario y sistema desde top)
CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
CPU_INT=${CPU%.*} # Convertir a entero

# 2. Obtener uso de Memoria RAM
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERC=$(( 100 * MEM_USED / MEM_TOTAL ))

AC_DIR=$(ls -d /sys/class/power_supply/AC* 2>/dev/null | head -n 1)

# Buscar cualquier carpeta que empiece por AC, ADP o line_power en el directorio de energía
PLUGGED_STATE=0
for psu in /sys/class/power_supply/*; do
    if [[ "$psu" == *"AC"* || "$psu" == *"ADP"* || "$psu" == *"line_power"* ]]; then
        if [ -f "$psu/online" ]; then
            PLUGGED_STATE=$(cat "$psu/online")
            break
        fi
    fi
done


if [[ -d /sys/class/power_supply/BAT0 || -d /sys/class/power_supply/BAT1 ]]; then
    # El sistema elegirá automáticamente la carpeta que sí exista
    if [ -d /sys/class/power_supply/BAT0 ]; then
        BAT_DIR="/sys/class/power_supply/BAT0"
    else
        BAT_DIR="/sys/class/power_supply/BAT1"
    fi

    # Leer los datos usando la ruta correcta descubierta arriba
    BAT=$(cat "$BAT_DIR/capacity")
    BAT_STATUS=$(cat "$BAT_DIR/status")
    if [ $BAT -lt $LOW_BATTERY_THRESHOLD ]; then
        if [ $PLUGGED_STATE -eq 1 ]; then
            BAT_ICON="󰢜"
        else
            BAT_INFO="󱊡"
        fi
        BAT_INFO="<span color='$COLOR_ALERT'>$BAT_ICON</span> Low Battery: $BAT%"
    elif [ $BAT -lt $FULL_BATTERY_THRESHOLD ]; then
        if [ $PLUGGED_STATE -eq 1 ]; then
            BAT_ICON="󰂉"
        else
            BAT_ICON="󰁾"
        fi
        BAT_INFO="<span color='$COLOR_BASE'>$BAT_ICON</span> Battery: $BAT%"
    else
        if [ $PLUGGED_STATE -eq 1 ]; then
            BAT_ICON="󰂄"
        else
            BAT_ICON="󰁹"
        fi
        BAT_INFO="<span color='$COLOR_OK'>$BAT_ICON</span> Battery: $BAT%"
    fi
    #BAT_INFO="charging $PLUGGED_STATE, battery $BAT% ($BAT_STATUS)"
else
    BAT_INFO=""
fi

if [ $PLUGGED_STATE -eq 0 ] && [ $BAT -lt $LOW_BATTERY_THRESHOLD ]; then
    TRAY_ICON="<span color='$COLOR_ALERT'>󰻷</span>"
    show_battery_alert
else
    hide_battery_alert
fi

# Formatear el Tooltip (Usamos \n para saltos de línea)
TOOLTIP=" CPU Usage: $CPU_INT%\n Memory Used: $MEM_PERC%\n$BAT_INFO"

# Retornar el JSON que Waybar requiere
printf '{"text": "%s", "tooltip": "%s"}\n' "$TRAY_ICON" "$TOOLTIP"
