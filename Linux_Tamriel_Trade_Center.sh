#!/bin/bash

# ==============================================================================
# Linux/Unix Tamriel Trade Center: Cross-Platform Auto-Updater for TTC, HarvestMap & ESO-Hub
# Created by @APHONIC
# ==============================================================================

unset LD_PRELOAD
unset LD_LIBRARY_PATH

APP_VERSION="4.0"
OS_TYPE=$(uname -s)
TARGET_DIR="$HOME/Documents"

if [ "$OS_TYPE" = "Darwin" ]; then
    OS_BRAND="Unix"
    TARGET_DIR="$TARGET_DIR/${OS_BRAND}_Tamriel_Trade_Center"
    LOG_FILE="$TARGET_DIR/UTTC.log"
else
    OS_BRAND="Linux"
    TARGET_DIR="$TARGET_DIR/${OS_BRAND}_Tamriel_Trade_Center"
    LOG_FILE="$TARGET_DIR/LTTC.log"
fi

APP_TITLE="$OS_BRAND Tamriel Trade Center v$APP_VERSION"
SCRIPT_NAME="${OS_BRAND}_Tamriel_Trade_Center.sh"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# only allow one instance to run
IS_BACKGROUND=false
for arg in "$@"; do
    if [ "$arg" = "--silent" ] || [ "$arg" = "--task" ] || [ "$arg" = "--steam" ]; then
        IS_BACKGROUND=true
    fi
done

handle_existing_process() {
    local old_pid=$1
    if [ "$IS_BACKGROUND" = true ]; then
        # kill itself if another proccess exist if it runs in the background
        exit 0
    fi
    
    echo -e "\e[0;33m[!] Another instance of the updater (PID: $old_pid) is already running.\e[0m"
    read -p "Do you want to terminate the existing process and continue? (y/n): " kill_choice
    if [[ "$kill_choice" =~ ^[Yy]$ ]]; then
        echo -e "\e[0;31mTerminating old process ($old_pid)...\e[0m"
        kill -9 "$old_pid" 2>/dev/null || true
        sleep 1
        return 0
    else
        echo -e "\e[0;32mKeeping the existing process safe. Exiting new instance.\e[0m"
        exit 1
    fi
}

if [ "$OS_TYPE" = "Linux" ] && command -v flock >/dev/null 2>&1; then
    LOCK_FILE="/tmp/ttc_updater_$APP_VERSION.lock"
    exec 200<>"$LOCK_FILE"
    if ! flock -n 200; then
        OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            handle_existing_process "$OLD_PID"
            if ! flock -n 200; then
                sleep 1
                flock -n 200 || { echo -e "\e[0;31mFailed to acquire lock. Exiting.\e[0m"; exit 1; }
            fi
        else
            echo -e "\e[0;31m[!] Another instance is running but PID is unknown. Exiting.\e[0m"
            exit 1
        fi
    fi
    > "$LOCK_FILE"
    echo $$ >&200
else
    LOCK_DIR="/tmp/ttc_updater_dir_$APP_VERSION"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid"
        trap 'rm -rf "$LOCK_DIR"; exit 0' EXIT SIGHUP SIGINT SIGTERM
    else
        OLD_PID=$(cat "$LOCK_DIR/pid" 2>/dev/null)
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            handle_existing_process "$OLD_PID"
            rm -rf "$LOCK_DIR"
            mkdir "$LOCK_DIR" 2>/dev/null
            echo $$ > "$LOCK_DIR/pid"
            trap 'rm -rf "$LOCK_DIR"; exit 0' EXIT SIGHUP SIGINT SIGTERM
        else
            rm -rf "$LOCK_DIR"
            mkdir "$LOCK_DIR" 2>/dev/null
            echo $$ > "$LOCK_DIR/pid"
            trap 'rm -rf "$LOCK_DIR"; exit 0' EXIT SIGHUP SIGINT SIGTERM
        fi
    fi
fi

mkdir -p "$TARGET_DIR"
CONFIG_FILE="$TARGET_DIR/lttc_updater.conf"
DB_FILE="$TARGET_DIR/LTTC_Database.db"
touch "$DB_FILE" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null

LOG_MODE="simple"

log_event() {
    local level="$1"
    local message="$2"
    
    # Filter out detailed item logs if logging mode is set to simple
    if [ "$LOG_MODE" != "detailed" ] && [ "$level" == "ITEM" ]; then
        return
    fi
    
    clean_msg=$(echo "$message" | perl -pe 's/\e\[[0-9;]*m//g')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $clean_msg" >> "$LOG_FILE"
}

scan_game_dir() {
    declare -a game_paths=()
    if [ "$OS_TYPE" = "Linux" ]; then
        game_paths=(
            "$HOME/.local/share/Steam/steamapps/common/Zenimax Online/The Elder Scrolls Online/game/client"
            "$HOME/.steam/steam/steamapps/common/Zenimax Online/The Elder Scrolls Online/game/client"
            "$HOME/.var/app/com.valvesoftware.Steam/.steam/root/steamapps/common/Zenimax Online/The Elder Scrolls Online/game/client"
            "/var/lib/flatpak/app/com.valvesoftware.Steam/.steam/root/steamapps/common/Zenimax Online/The Elder Scrolls Online/game/client"
        )
    elif [ "$OS_TYPE" = "Darwin" ]; then
        game_paths=(
            "$HOME/Library/Application Support/Steam/steamapps/common/Zenimax Online/The Elder Scrolls Online/game/client"
            "$HOME/Library/Application Support/Steam/steamapps/common/Zenimax Online/The Elder Scrolls Online"
        )
    fi

    for p in "${game_paths[@]}"; do
        if [ -f "$p/eso64.exe" ] || [ -f "$p/eso.app/Contents/MacOS/eso" ] || [ -d "$p/eso.app" ]; then 
            echo "$p"
            return 0
        fi
    done
    
    if [ "$OS_TYPE" = "Linux" ]; then
        FOUND_ZOS=$(find "$HOME" /run/media /mnt /media -maxdepth 6 -type d -name "Zenimax Online" 2>/dev/null | head -n 1)
        if [ -n "$FOUND_ZOS" ] && [ -f "$FOUND_ZOS/The Elder Scrolls Online/game/client/eso64.exe" ]; then
            echo "$FOUND_ZOS/The Elder Scrolls Online/game/client"; return 0;
        fi
    fi
    echo ""
}

check_game_active() {
    if ps ax | grep -iE 'eso64\.exe|steam_app_306130|eso\.app|Bethesda\.net_Launcher\.exe|Bethesda\.net_Launcher' | grep -v grep > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

SILENT=false
AUTO_PATH=false
AUTO_SRV=""
AUTO_MODE=""
ADDON_DIR=""
SETUP_COMPLETE=false
ENABLE_NOTIFS=false
HAS_ARGS=false
IS_TASK=false
IS_STEAM_LAUNCH=false
ENABLE_DISPLAY="true"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

TTC_LAST_SALE="${TTC_LAST_SALE:-0}"
TTC_LAST_DOWNLOAD="${TTC_LAST_DOWNLOAD:-0}"
TTC_LAST_CHECK="${TTC_LAST_CHECK:-0}"
TTC_LOC_VERSION="${TTC_LOC_VERSION:-0}"

EH_LAST_SALE="${EH_LAST_SALE:-0}"
EH_LAST_DOWNLOAD="${EH_LAST_DOWNLOAD:-0}"
EH_LAST_CHECK="${EH_LAST_CHECK:-0}"
EH_LOC_5="${EH_LOC_5:-0}"
EH_LOC_7="${EH_LOC_7:-0}"
EH_LOC_9="${EH_LOC_9:-0}"

HM_LAST_DOWNLOAD="${HM_LAST_DOWNLOAD:-0}"
HM_LAST_CHECK="${HM_LAST_CHECK:-0}"
LOG_MODE="${LOG_MODE:-simple}"

save_config() {
    cat <<EOF > "$CONFIG_FILE"
AUTO_SRV="$AUTO_SRV"
SILENT=$SILENT
AUTO_MODE="$AUTO_MODE"
ADDON_DIR="$ADDON_DIR"
SETUP_COMPLETE=$SETUP_COMPLETE
ENABLE_NOTIFS=$ENABLE_NOTIFS
ENABLE_DISPLAY="$ENABLE_DISPLAY"
LOG_MODE="$LOG_MODE"
TTC_LAST_SALE="$TTC_LAST_SALE"
TTC_LAST_DOWNLOAD="$TTC_LAST_DOWNLOAD"
TTC_LAST_CHECK="$TTC_LAST_CHECK"
TTC_LOC_VERSION="$TTC_LOC_VERSION"
EH_LAST_SALE="$EH_LAST_SALE"
EH_LAST_DOWNLOAD="$EH_LAST_DOWNLOAD"
EH_LAST_CHECK="$EH_LAST_CHECK"
EH_LOC_5="$EH_LOC_5"
EH_LOC_7="$EH_LOC_7"
EH_LOC_9="$EH_LOC_9"
HM_LAST_DOWNLOAD="$HM_LAST_DOWNLOAD"
HM_LAST_CHECK="$HM_LAST_CHECK"
EOF
}

if [ "$#" -gt 0 ]; then HAS_ARGS=true; fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --silent) SILENT=true ;;
        --auto) AUTO_PATH=true ;;
        --na) AUTO_SRV="1" ;;
        --eu) AUTO_SRV="2" ;;
        --loop) AUTO_MODE="2" ;;
        --once) AUTO_MODE="1" ;;
        --task) IS_TASK=true; SILENT=true ;;
        --steam) IS_STEAM_LAUNCH=true ;;
        --addon-dir) shift; ADDON_DIR="$1" ;;
    esac
    shift
done

send_notification() {
    local msg="$1"
    if [ "$ENABLE_NOTIFS" = "false" ]; then return; fi
    
    if [ "$OS_TYPE" = "Darwin" ]; then
        osascript -e "display notification \"$msg\" with title \"$APP_TITLE\"" 2>/dev/null
    elif command -v notify-send > /dev/null; then
        notify-send "$APP_TITLE" "$msg" 2>/dev/null
    fi
}

detect_terminal() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        echo "Terminal"
    elif command -v alacritty &> /dev/null; then echo "alacritty -e"
    elif command -v konsole &> /dev/null; then echo "konsole -e"
    elif command -v gnome-terminal &> /dev/null; then echo "gnome-terminal --"
    elif command -v xfce4-terminal &> /dev/null; then echo "xfce4-terminal -e"
    elif command -v kitty &> /dev/null; then echo "kitty --"
    else echo "xterm -e"
    fi
}

auto_scan_addons() {
    declare -a addon_paths=()
    if [ "$OS_TYPE" = "Linux" ]; then
        addon_paths=(
            "$HOME/.local/share/Steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/.var/app/com.valvesoftware.Steam/.steam/root/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns"
            "/var/lib/flatpak/app/com.valvesoftware.Steam/.steam/root/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/Games/elder-scrolls-online/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/Games/elder-scrolls-online/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/.wine/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/.wine/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/Elder-Scrolls-Online/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/PortWINE/PortProton/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns"
            "$HOME/PortProton/prefixes/DEFAULT/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/"
        )
    elif [ "$OS_TYPE" = "Darwin" ]; then
        addon_paths=(
            "$HOME/Documents/Elder Scrolls Online/live/AddOns"
        )
    fi

    for p in "${addon_paths[@]}"; do
        if [ -d "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    
    if [ "$OS_TYPE" = "Linux" ]; then
        while IFS= read -r base_dir; do
            if [ -z "$base_dir" ]; then continue; fi
            for suffix in "/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns" "/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns" "/live/AddOns"; do
                if [ -d "$base_dir$suffix" ]; then echo "$base_dir$suffix"; return 0; fi
            done
        done <<< "$(find "$HOME" /run/media /mnt /media -maxdepth 6 \( -type d -name "306130" -o -type d -name "Elder Scrolls Online" -o -type d -name "bottles" -o -type d -name "lutris" \) 2>/dev/null)"
    fi
    echo ""
}

run_setup() {
    clear
    echo -e "\n\e[0;33m--- Initial Setup & Configuration ---\e[0m"
    log_event "INFO" "Starting initial setup process."

    if [ "$CURRENT_DIR" != "$TARGET_DIR" ]; then
        cp "${BASH_SOURCE[0]}" "$TARGET_DIR/$SCRIPT_NAME" 2>/dev/null
        chmod +x "$TARGET_DIR/$SCRIPT_NAME"
        echo -e "\e[0;32m[+] Script successfully copied/updated in Documents folder:\e[0m $TARGET_DIR"
        log_event "INFO" "Script installed to target directory: $TARGET_DIR"
    else
        echo -e "\e[0;36m-> Script is already running from the Documents folder.\e[0m\n"
    fi

    echo -e "\n\e[0;33m1. Which server do you play on? (For TTC Pricing)\e[0m"
    echo "1) North America (NA)"
    echo "2) Europe (EU)"
    read -p "Choice [1-2]: " AUTO_SRV

    echo -e "\n\e[0;33m2. Do you want the terminal to be visible when launching via Steam?\e[0m"
    echo "1) Show Terminal (Verbose visible output)"
    echo "2) Hide Terminal (Invisible background hidden)"
    read -p "Choice [1-2]: " term_choice
    [ "$term_choice" == "2" ] && SILENT=true || SILENT=false

    echo -e "\n\e[0;33m3. How should the script run during gameplay?\e[0m"
    echo "1) Run once and close immediately"
    echo "2) Loop continuously (Checks local file & server status every 60 minutes to avoid server rate-limit)"
    read -p "Choice [1-2]: " AUTO_MODE

    echo -e "\n\e[0;33m4. Extract & Display Data (Requires Database)\e[0m"
    echo "Do you want to extract and display item names/sales on the terminal?"
    echo "1) Yes (Extract, Display, and build LTTC_Database.db)"
    echo "2) No (Just upload the files instantly)"
    read -p "Choice [1-2]: " display_choice
    [ "$display_choice" == "2" ] && ENABLE_DISPLAY=false || ENABLE_DISPLAY=true

    echo -e "\n\e[0;33m5. Addon Folder Location\e[0m"
    if [ -n "$ADDON_DIR" ] && [ -d "$ADDON_DIR" ]; then
        echo -e "\e[0;32m[+] Found Saved Addons Directory at:\e[0m $ADDON_DIR"
        FOUND_ADDONS="$ADDON_DIR"
    else
        echo "Scanning default locations and drives for Addons folder..."
        FOUND_ADDONS=$(auto_scan_addons)
        if [ -n "$FOUND_ADDONS" ]; then
            echo -e "\e[0;32m[+] Found Addons folder at:\e[0m $FOUND_ADDONS"
            read -p "Is this the correct location? (y/n): " use_found
            if [[ ! "$use_found" =~ ^[Yy]$ ]]; then
                read -p "Enter full custom path to AddOns folder: " FOUND_ADDONS
            fi
        else
            echo -e "\e[0;31m[-] Could not find AddOns automatically.\e[0m"
            read -p "Enter full custom path to AddOns folder: " FOUND_ADDONS
        fi
    fi
    ADDON_DIR="$FOUND_ADDONS"
    log_event "INFO" "Addon directory set to: $ADDON_DIR"

    echo -e "\n\e[0;33m6. Enable Native System Notifications?\e[0m"
    echo "1) Yes (Summarizes updates, respects Do Not Disturb)"
    echo "2) No"
    read -p "Choice [1-2]: " notif_choice
    [ "$notif_choice" == "1" ] && ENABLE_NOTIFS=true || ENABLE_NOTIFS=false

    echo -e "\n\e[0;33m7. Logging Level\e[0m"
    echo "Creates a log file at $LOG_FILE"
    echo "1) Simple Logging (Default, records basic script events)"
    echo "2) Detailed Logging (Includes listed, sold items, and scans)"
    read -p "Choice [1-2]: " log_choice
    [ "$log_choice" == "2" ] && LOG_MODE="detailed" || LOG_MODE="simple"
    touch "$LOG_FILE" 2>/dev/null

    SETUP_COMPLETE=true
    save_config
    log_event "INFO" "Setup complete. Configuration saved. Log Mode: $LOG_MODE"

    echo -e "\n\e[0;33m8. Desktop Shortcut\e[0m"
    read -p "Create a desktop shortcut? (y/n): " make_shortcut
    
    SHORTCUT_SRV_FLAG="--na"
    [ "$AUTO_SRV" == "2" ] && SHORTCUT_SRV_FLAG="--eu"
    SILENT_FLAG=""
    [ "$SILENT" == true ] && SILENT_FLAG="--silent"
    LOOP_FLAG="--once"
    [ "$AUTO_MODE" == "2" ] && LOOP_FLAG="--loop"

    if [[ "$make_shortcut" =~ ^[Yy]$ ]]; then
        ICON_PATH="$TARGET_DIR/ttc_icon.jpg"
        curl -s -L -o "$ICON_PATH" "https://eu.tamrieltradecentre.com/favicon.ico"

        if [[ "$OS_TYPE" == "Linux" ]]; then
            DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")
            mkdir -p "$DESKTOP_DIR"
            DESKTOP_FILE="$DESKTOP_DIR/${OS_BRAND}_Tamriel_Trade_Center.desktop"
            APP_DIR="$HOME/.local/share/applications"
            
            cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Name=$APP_TITLE
Comment=Cross-Platform Auto-Updater for TTC, HarvestMap & ESO-Hub - Created by @APHONIC
Exec=bash -c '"$TARGET_DIR/$SCRIPT_NAME" $SILENT_FLAG $SHORTCUT_SRV_FLAG $LOOP_FLAG --addon-dir "$ADDON_DIR"'
Icon=$ICON_PATH
Terminal=$([ "$SILENT" = true ] && echo "false" || echo "true")
Type=Application
Categories=Game;Utility;
EOF
            chmod +x "$DESKTOP_FILE"
            mkdir -p "$APP_DIR"
            cp "$DESKTOP_FILE" "$APP_DIR/"
            echo -e "\e[0;32m[+] Linux desktop shortcut installed to Desktop and Application Launcher.\e[0m"
        elif [[ "$OS_TYPE" == "Darwin" ]]; then
            echo -e "\e[0;33m[!] Automatic macOS App creation is not fully supported in pure bash. A Terminal script alias can be used instead.\e[0m"
        fi
    else
        rm -f "$HOME/Desktop/${OS_BRAND}_Tamriel_Trade_Center.desktop" 2>/dev/null
        rm -f "$HOME/.local/share/applications/${OS_BRAND}_Tamriel_Trade_Center.desktop" 2>/dev/null
    fi

    TERM_CMD=$(detect_terminal)
    echo -e "\n\e[0;92m================ SETUP COMPLETE ================\e[0m"
    echo -e "To run this automatically alongside your game, copy this string into your \e[1mSteam Launch Options\e[0m:\n"
    
    if [ "$SILENT" = true ]; then
        LAUNCH_CMD="nohup bash -c '\"$TARGET_DIR/$SCRIPT_NAME\" $SILENT_FLAG $SHORTCUT_SRV_FLAG $LOOP_FLAG --steam' >/dev/null 2>&1 & %command%"
        echo -e "\e[0;104m $LAUNCH_CMD \e[0m\n"
    else
        if [ "$OS_TYPE" = "Darwin" ]; then
            LAUNCH_CMD="osascript -e 'tell application \"Terminal\" to do script \"\\\"$TARGET_DIR/$SCRIPT_NAME\\\" $SHORTCUT_SRV_FLAG $LOOP_FLAG --steam\"' & %command%"
            echo -e "\e[0;104m $LAUNCH_CMD \e[0m\n"
        else
            LAUNCH_CMD="$TERM_CMD \"$TARGET_DIR/$SCRIPT_NAME\" $SHORTCUT_SRV_FLAG $LOOP_FLAG --steam & %command%"
            echo -e "\e[0;104m $LAUNCH_CMD \e[0m\n"
            echo -e "\e[0;33m(Note: Auto-detected your terminal as '$TERM_CMD').\e[0m\n"
        fi
    fi
    
    echo -e "\e[0;33m9. Steam Launch Options\e[0m"
    echo "Would you like this script to automatically inject the Launch Command into your Steam configuration?"
    echo "(WARNING: Steam MUST be closed to do this. We can close it for you.)"
    read -p "Apply automatically? (y/n): " auto_steam
    
    if [[ "$auto_steam" =~ ^[Yy]$ ]]; then
        STEAM_CMD="steam"
        if ! command -v steam >/dev/null 2>&1 && command -v flatpak >/dev/null 2>&1 && flatpak list | grep -qi com.valvesoftware.Steam; then
            STEAM_CMD="flatpak run com.valvesoftware.Steam"
        fi

        STEAM_PIDS=$(pgrep -x "steam" || pgrep -x "Steam" || pgrep -x "steam_osx" || pgrep -f "com.valvesoftware.Steam")
        if [ -n "$STEAM_PIDS" ]; then
            STEAM_PID=$(echo "$STEAM_PIDS" | head -n 1)
            echo -e "\e[0;33m[!] Steam is running. Closing Steam to safely inject options...\e[0m"
            log_event "WARN" "Steam was running during setup. Attempting to close."
            STEAM_EXEC=$(ps -p "$STEAM_PID" -o args= | cut -d' ' -f1)
            if [[ "$STEAM_EXEC" == *"flatpak"* ]] || pgrep -f "flatpak run com.valvesoftware.Steam" > /dev/null 2>&1; then
                STEAM_CMD="flatpak run com.valvesoftware.Steam"
            fi
            
            pkill -x steam > /dev/null 2>&1; pkill -x Steam > /dev/null 2>&1; pkill -x steam_osx > /dev/null 2>&1; pkill -f "com.valvesoftware.Steam" > /dev/null 2>&1
            sleep 5
        fi
        
        export LAUNCH_STR="$LAUNCH_CMD"
        BACKUP_DIR="$TARGET_DIR/Backups"
        mkdir -p "$BACKUP_DIR"
        
        for conf in "$HOME/.steam/steam/userdata"/*/config/localconfig.vdf \
                    "$HOME/.local/share/Steam/userdata"/*/config/localconfig.vdf \
                    "/var/lib/flatpak/app/com.valvesoftware.Steam/.steam/root/userdata"/*/config/localconfig.vdf \
                    "$HOME/Library/Application Support/Steam/userdata"/*/config/localconfig.vdf; do
            if [ -f "$conf" ]; then
                TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
                STEAM_ID=$(basename $(dirname $(dirname "$conf")))
                BACKUP_FILE="$BACKUP_DIR/localconfig_${STEAM_ID}_${TIMESTAMP}.vdf"
                cp "$conf" "$BACKUP_FILE" 2>/dev/null
                echo -e "\e[0;36m-> Backed up Steam config to: $BACKUP_FILE\e[0m"
                log_event "INFO" "Backed up Steam config: $BACKUP_FILE"

                echo -e "\e[0;36m-> Injecting into $conf...\e[0m"
                perl -pi.bak -e 'BEGIN{undef $/;} my $ls=$ENV{LAUNCH_STR}; $ls=~s/"/\\"/g; if (/"306130"\s*\{/) { if (/"306130"\s*\{[^}]*"LaunchOptions"\s*"[^"]*"/) { s/("306130"\s*\{[^}]*)"LaunchOptions"\s*"[^"]*"/$1"LaunchOptions"\t\t"$ls"/s; } else { s/("306130"\s*\{)/$1\n\t\t\t\t"LaunchOptions"\t\t"$ls"/s; } } else { s/("apps"\s*\{)/$1\n\t\t\t"306130"\n\t\t\t{\n\t\t\t\t"LaunchOptions"\t\t"$ls"\n\t\t\t}/s; }' "$conf" 2>/dev/null
                echo -e "\e[0;32m[+] Successfully injected Launch Options into Steam!\e[0m"
                log_event "INFO" "Injected launch options into Steam config."
            fi
        done
        
        echo -e "\e[0;33m[!] Restarting Steam...\e[0m"
        if [ "$OS_TYPE" = "Darwin" ]; then
            open -a Steam
        else
            if [[ "$STEAM_CMD" == *"flatpak"* ]]; then
                nohup flatpak run com.valvesoftware.Steam </dev/null >/dev/null 2>&1 &
            else
                nohup steam </dev/null >/dev/null 2>&1 &
            fi
        fi
    fi
    
    read -p "Press Enter to start the updater now..."
    SILENT=false
}

INSTALLED_SCRIPT="$TARGET_DIR/$SCRIPT_NAME"

if [ "$SETUP_COMPLETE" = "true" ] && [ "$HAS_ARGS" = false ]; then
    if [ -f "$INSTALLED_SCRIPT" ] && [ -f "$CONFIG_FILE" ]; then
        clear
        echo -e "\e[0;32m[+] Configuration found! Using saved settings.\e[0m"
        echo -e "\e[0;36m-> Press 'y' to re-run setup, or wait 5 seconds to continue automatically...\e[0m\n"
        read -t 5 -p "Setup done, do you want to re-run setup? (y/N): " rerun_setup
        if [[ "$rerun_setup" =~ ^[Yy]$ ]]; then
            run_setup
        else
            if [ "$CURRENT_DIR" != "$TARGET_DIR" ]; then
                cp "${BASH_SOURCE[0]}" "$TARGET_DIR/$SCRIPT_NAME" 2>/dev/null
            fi
        fi
    else
        run_setup
    fi
elif [ "$SETUP_COMPLETE" != "true" ] && [ "$HAS_ARGS" = false ]; then
    run_setup
fi

if [ "$SILENT" = true ]; then exec >/dev/null 2>&1; fi
exec 3>&2
exec 2>/dev/null

[ "$AUTO_SRV" == "1" ] && TTC_DOMAIN="us.tamrieltradecentre.com" || TTC_DOMAIN="eu.tamrieltradecentre.com"
TTC_URL="https://$TTC_DOMAIN/download/PriceTable"
SAVED_VAR_DIR="$(dirname "$ADDON_DIR")/SavedVariables"
TEMP_DIR="$HOME/Downloads/${OS_BRAND}_Tamriel_Trade_Center_Temp"

TTC_USER_AGENT="TamrielTradeCentreClient/1.0.0"
HM_USER_AGENT="HarvestMapClient/1.0.0"

USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:124.0) Gecko/20100101 Firefox/124.0"
)

ADDON_SETTINGS_FILE="$(dirname "$ADDON_DIR")/AddOnSettings.txt"
check_addon_enabled() {
    local addon="$1"
    if [ -f "$ADDON_SETTINGS_FILE" ]; then
        if grep -qw "$addon" "$ADDON_SETTINGS_FILE"; then echo "true"; else echo "false"; fi
    else
        if [ -d "$ADDON_DIR/$addon" ]; then echo "true"; else echo "false"; fi
    fi
}

format_date() {
    local ts="$1"
    if [ "$OS_TYPE" = "Darwin" ]; then
        date -r "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown Date"
    else
        date -d "@$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown Date"
    fi
}

apply_db_updates() {
    local updates="$1"
    if [ -n "$updates" ]; then
        echo "$updates" | awk -F'|' -v db="$DB_FILE" '
        BEGIN {
            while ((getline < db) > 0) {
                if ($1 == "GUILD") { lines["GUILD_"$2] = $0 }
                else if ($1 ~ /^[0-9]+$/) { lines["ITEM_"$1] = $0 }
            }
            close(db)
        }
        {
            if ($1 == "DB_UPDATE") {
                id = $2; val = $2
                for(i=3; i<=NF; i++) val = val "|" $i
                lines["ITEM_"id] = val
            } else if ($1 == "DB_GUILD") {
                gname = $2; gid = $3
                lines["GUILD_"gname] = "GUILD|" gname "|" gid
            }
        }
        END {
            for (k in lines) { print lines[k] }
        }' > "$DB_FILE.tmp"
        mv "$DB_FILE.tmp" "$DB_FILE"
        sort -t'|' -k1,1 -k7,7 -k6,6 "$DB_FILE" -o "$DB_FILE" 2>/dev/null
        log_event "INFO" "Database updated and sorted with new item and guild mappings."
    fi
}

# Item Quality Logic (I can't cover all items since I have to invent this from scratch, if an item is colored incorrectly then I haven't encountered that item while i was creating this)
# You can probably add those items manually if you understand the table below
master_color_logic='
function get_hq(q) {
    if(q==6)return "Mythic (Orange) 6"; if(q==5)return "Legendary (Gold) 5"; if(q==4)return "Epic (Purple) 4";
    if(q==3)return "Superior (Blue) 3"; if(q==2)return "Fine (Green) 2"; if(q==1)return "Normal (White) 1";
    return "Trash (Grey) 0"
}
function get_cat(n,i,s,v) {
    ln = tolower(n)
    if(ln~/motif/)return "Crafting Motif"; if(ln~/blueprint|praxis|design|pattern|formula|diagram/)return "Furniture Plan";
    if(ln~/style page|runebox/)return "Style/Collectible"; 
    if(ln~/tea blends of tamriel|tin of high isle taffy|assorted stolen shiny trinkets|lightly used fiddle|stuffed bear|grisly trophy|companion gift/)return "Companion Gift"; 
    if(v>1||s>=20)return "Equipment (Armor/Weapon)"; return "Materials/Misc"
}
function calc_quality(id, name, s, v) {
    ln = tolower(name)
    if(id~/^(165899|187648|171437|165910|175510|181971|181961|175402|184206|191067)$/) return 6
    if(ln~/citation|truly superb glyph|tempering alloy|dreugh wax|rosin|kuta|perfect roe|aetherial dust|chromium plating/) return 5
    if(ln~/unknown .* writ|welkynar binding|rekuta|grain solvent|mastic|elegant lining|zircon plating/) return 4
    if(ln~/survey report|dwarven oil|turpen|embroidery|iridium plating/) return 3
    if(ln~/tea blends of tamriel|tin of high isle taffy|assorted stolen shiny trinkets|lightly used fiddle|stuffed bear|grisly trophy|companion gift/) return 3
    if(ln~/blessed thistle|bugloss|columbine|corn flower|dragonthorn|mountain flower|hemming|honing stone|pitch|terne plating|soul gem/) return 2
    if(id~/^(30148|30149|30151|30152|30153|30154|30155|30157|30158|30159|30160|54234|54171|54319|33271)$/) return 2
    if(ln~/style page:|runebox:/ && s==124) return 5
    if(ln~/crafting motif/ && s==5) return 4
    if(ln~/blueprint:/ && s==4) return 3
    if(ln~/praxis:/ && s==3) return 2
    if(id~/^(45349|45330|45354)$/) { if(s==365)return 1; if(s==364)return 5; if(s==361)return 4; if(s==360)return 3; if(s==358)return 2; return 1 }
    if(s>=305 && s<=309) return s-304
    if(s==366 || s==1) return 6
    if(v<50) {
        if(s==6)return 5; if(s==5)return 4; if(s==4)return 3; if(s==3)return 2; if(s==2)return 1; return 1
    } else {
        if(s>=361 && s<=365)return s-360; return 1
    }
}
'

log_event "INFO" "Updater started. OS: $OS_BRAND. Version: $APP_VERSION"

while true; do
    CONFIG_CHANGED=false
    TEMP_DIR_USED=false
    CURRENT_TIME=$(date +%s)
    
    NOTIF_TTC="Up-to-date"
    NOTIF_EH="Up-to-date"
    NOTIF_HM="Up-to-date"

    shuffled_uas=("${USER_AGENTS[@]}")
    for i in "${!shuffled_uas[@]}"; do
        j=$((RANDOM % ${#shuffled_uas[@]})); temp="${shuffled_uas[$i]}"; shuffled_uas[$i]="${shuffled_uas[$j]}"; shuffled_uas[$j]="$temp"
    done
    RAND_UA="${shuffled_uas[0]}"

    if [ "$SILENT" = false ]; then
        echo -ne "\033]0;$APP_TITLE - Created by @APHONIC\007"
        clear
        echo -e "\e[0;92m===========================================================================\e[0m"
        echo -e "\e[1m\e[0;94m                         $APP_TITLE\e[0m"
        echo -e "\e[0;97m         Cross-Platform Auto-Updater for TTC, HarvestMap & ESO-Hub\e[0m"
        echo -e "\e[0;90m                            Created by @APHONIC\e[0m"
        echo -e "\e[0;92m===========================================================================\e[0m\n"
        echo -e "Target AddOn Directory: \e[35m$ADDON_DIR\e[0m\n"
    fi
    
    mkdir -p "$TEMP_DIR" && cd "$TEMP_DIR" || exit

    HAS_TTC=$(check_addon_enabled "TamrielTradeCentre")
    HAS_HM=$(check_addon_enabled "HarvestMap")

    # TTC Data extraction & upload
    if [ "$HAS_TTC" = "false" ]; then
        [ "$SILENT" = false ] && echo -e "\e[1m\e[97m [1/4] & [2/4] Updating TTC Data (SKIPPED)\e[0m"
        [ "$SILENT" = false ] && echo -e " \e[31m[-] TamrielTradeCentre is not installed/enabled in AddOnSettings.txt. \e[35mSkipping TTC updates.\e[0m\n"
        NOTIF_TTC="Not Installed (Skipped)"
        log_event "WARN" "TTC not found or enabled. Skipping TTC updates."
    else
        [ "$SILENT" = false ] && echo -e "\e[1m\e[97m [1/4] Uploading your Local TTC Data to TTC Server \e[0m"
        
        TTC_CHANGED=true
        if [ -f "$SAVED_VAR_DIR/TamrielTradeCentre.lua" ]; then
            if [ -f "$TARGET_DIR/lttc_ttc_snapshot.lua" ]; then
                if cmp -s "$SAVED_VAR_DIR/TamrielTradeCentre.lua" "$TARGET_DIR/lttc_ttc_snapshot.lua"; then
                    TTC_CHANGED=false
                fi
            fi
        fi

        if [ -f "$SAVED_VAR_DIR/TamrielTradeCentre.lua" ]; then
            if [ "$TTC_CHANGED" = false ]; then
                [ "$SILENT" = false ] && echo -e " \e[90mNo changes detected in TamrielTradeCentre.lua. \e[35mSkipping upload.\e[0m\n"
                log_event "INFO" "No changes in local TTC data. Skipping upload."
            else
                cp -f "$SAVED_VAR_DIR/TamrielTradeCentre.lua" "$TARGET_DIR/lttc_ttc_snapshot.lua" 2>/dev/null
                if [ "$ENABLE_DISPLAY" = true ] && [ "$SILENT" = false ]; then
                    echo -e " \e[36mExtracting new local listings & sales data from TTC...\e[0m"
                    log_event "INFO" "Extracting new TTC sales data."
                    
                    AWK_OUT=$(awk -v last_time="$TTC_LAST_SALE" -v db_file="$DB_FILE" "
                    $master_color_logic
                    BEGIN { 
                        max_time = last_time; count = 0;
                        while ((getline line < db_file) > 0) {
                            split(line, p, \"|\")
                            if (p[1] == \"GUILD\") {
                                db_guild_id[p[2]] = p[3]
                            } else if (p[1] ~ /^[0-9]+\$/) {
                                db_cols[p[1]] = length(p)
                                db_qual[p[1]] = p[2]
                                if (length(p) >= 6) { db_name[p[1]] = p[6] } else { db_name[p[1]] = p[3] }
                            }
                        }
                        close(db_file)
                    }
                    { sub(/\r$/, \"\") }
                    
                    # stack parser
                    /^[ \t]*\\[\"?([^\"]+)\"?\\][ \t]*=/ {
                        match(\$0, /^[ \t]*/)
                        lvl = RLENGTH + 0
                        
                        match(\$0, /^[ \t]*\\[\"?([^\"]+)\"?\\]/)
                        key = substr(\$0, RSTART, RLENGTH)
                        sub(/^[ \t]*\\[\"?/, \"\", key)
                        sub(/\"?\\]\$/, \"\", key)
                        
                        # Purge deeper dangling array nodes to prevent state bleed
                        for (i in path) {
                            if ((i + 0) >= lvl) {
                                delete path[i]
                            }
                        }
                        path[lvl] = key
                        
                        if (key == \"KioskLocationID\") {
                            n = 0
                            for (i in path) { keys[n++] = i + 0 }
                            for (i = 0; i < n; i++) {
                                for (j = i + 1; j < n; j++) {
                                    if (keys[i] > keys[j]) { temp = keys[i]; keys[i] = keys[j]; keys[j] = temp; }
                                }
                            }
                            gname = \"\"
                            for (i = 0; i < n; i++) {
                                if (path[keys[i]] == \"Guilds\" && i + 1 < n) {
                                    gname = path[keys[i+1]]
                                }
                            }
                            if (gname != \"\") {
                                match(\$0, /[0-9]+/)
                                guild_kiosks[gname] = substr(\$0, RSTART, RLENGTH)
                            }
                        }
                        
                        if (key ~ /^[0-9]+\$/ && !in_item) {
                            in_item = 1
                            item_lvl = lvl
                            
                            n = 0
                            for (i in path) { keys[n++] = i + 0 }
                            for (i = 0; i < n; i++) {
                                for (j = i + 1; j < n; j++) {
                                    if (keys[i] > keys[j]) { temp = keys[i]; keys[i] = keys[j]; keys[j] = temp; }
                                }
                            }
                            
                            action = \"Listed\"
                            guild = \"\"
                            player = \"\"
                            
                            for (i = 0; i < n; i++) {
                                k = path[keys[i]]
                                if (k == \"SaleHistoryEntries\") action = \"Sold\"
                                if (k == \"AutoRecordEntries\" || k == \"Entries\") action = \"Listed\"
                                
                                if (k == \"Guilds\" && i + 1 < n) guild = path[keys[i+1]]
                                if (k == \"PlayerListings\" && i + 1 < n) player = path[keys[i+1]]
                            }
                        }
                    }
                    
                    in_item && /\\[\"Amount\"\\][ \t]*=/ { match(\$0, /[0-9]+/); amt=substr(\$0, RSTART, RLENGTH) }
                    in_item && /\\[\"SaleTime\"\\][ \t]*=/ { match(\$0, /[0-9]+/); stime=substr(\$0, RSTART, RLENGTH) }
                    in_item && /\\[\"TotalPrice\"\\][ \t]*=/ { match(\$0, /[0-9]+/); price=substr(\$0, RSTART, RLENGTH) }
                    in_item && /\\[\"Price\"\\][ \t]*=/ { 
                        if (\$0 !~ /TotalPrice/) {
                            match(\$0, /[0-9]+/)
                            if(price==\"\") price=substr(\$0, RSTART, RLENGTH) 
                        }
                    }
                    in_item && /\\[\"ID\"\\][ \t]*=/ { match(\$0, /[0-9]+/); itemid=substr(\$0, RSTART, RLENGTH) }
                    in_item && /\\[\"ItemLink\"\\][ \t]*=/ {
                        match(\$0, /\"(\\|H[^\"]+)\"/)
                        if (RLENGTH > 0) {
                            full_link = substr(\$0, RSTART+1, RLENGTH-2)
                            split(full_link, lp, \":\")
                            subtype = lp[4]; internal_level = lp[5]
                        }
                    }
                    in_item && /\\[\"Name\"\\][ \t]*=/ {
                        val = \$0; sub(/.*Name\"\\][ \t]*=[ \t]*\"/, \"\", val); sub(/\",[ \t]*\$/, \"\", val); name = val
                    }
                    
                    in_item && /^[ \t]*\\},?[ \t]*\$/ {
                        match(\$0, /^[ \t]*/)
                        if (RLENGTH <= item_lvl) {
                            in_item = 0
                            stime_num = (stime == \"\") ? 0 : stime + 0
                            if (stime_num > max_time) max_time = stime_num
                            
                            if (stime_num > last_time || last_time == 0) {
                                if (amt == \"\") amt = \"1\"
                                
                                if (name != \"\" && name !~ /^\\|[0-9]+\\|$/ && price != \"\") {
                                
                                    s = subtype + 0
                                    v = internal_level + 0
                                    needs_update = 0
                                    real_name = name

                                    if (itemid in db_name) {
                                        if (db_name[itemid] ~ /^Unknown Item/ && real_name != \"\" && real_name !~ /^Unknown Item/) {
                                            needs_update = 1
                                        } else {
                                            real_name = db_name[itemid]
                                        }
                                        if (db_cols[itemid] < 7) needs_update = 1
                                    } else {
                                        needs_update = 1
                                        if (real_name == \"\") real_name = \"Unknown Item (\" itemid \")\"
                                    }

                                    real_qual = calc_quality(itemid, real_name, s, v)
                                    if (itemid in db_qual && db_qual[itemid] != real_qual) needs_update = 1

                                    hq = get_hq(real_qual)
                                    cat = get_cat(real_name, itemid, s, v)

                                    if (needs_update) {
                                        db_updated[itemid] = itemid \"|\" real_qual \"|\" s \"|\" v \"|\" hq \"|\" real_name \"|\" cat
                                        db_name[itemid] = real_name
                                        db_qual[itemid] = real_qual
                                        db_cols[itemid] = 7
                                    }

                                    q_num = real_qual + 0
                                    c = \"\\033[0m\"
                                    if(q_num==0) c=\"\\033[90m\"; else if(q_num==1) c=\"\\033[97m\"; else if(q_num==2) c=\"\\033[32m\"
                                    else if(q_num==3) c=\"\\033[36m\"; else if(q_num==4) c=\"\\033[35m\"; else if(q_num==5) c=\"\\033[33m\"
                                    else if(q_num==6) c=\"\\033[38;5;214m\"
                                    
                                    # Output fake URL using ID taken from ESO Hub and Kiosk Tags
                                    guild_str = \"\"
                                    if (guild != \"\" && guild != \"Guilds\") {
                                        if (guild in db_guild_id) {
                                            gid = db_guild_id[guild]
                                            fake_url = \"|H1:guild:\" gid \"|h\" guild \"|h\"
                                            g_display = \"\\033[35m\\033]8;;\" fake_url \"\\033\\\\\" guild \"\\033]8;;\\033\\\\\\033[0m\"
                                        } else {
                                            g_display = \"\\033[35m\" guild \"\\033[0m\"
                                        }
                                        
                                        kiosk = guild_kiosks[guild]
                                        if (kiosk != \"\" && kiosk != \"0\") {
                                            k_str = \" \\033[90m(Kiosk: \" kiosk \")\\033[0m\"
                                        } else {
                                            k_str = \" \\033[90m(Local)\\033[0m\"
                                        }
                                        
                                        guild_str = \" in \" g_display k_str
                                    }
                                    
                                    # append @ to usernames
                                    player_str = \"\"
                                    if (player != \"\" && player != guild) {
                                        if (player !~ /^@/) player = \"@\" player
                                        player_str = \" by \\033[36m\" player \"\\033[0m\"
                                    }
                                    
                                    link_start = \"\\033]8;;https://us.tamrieltradecentre.com/pc/Trade/SearchResult?ItemID=\" itemid \"\\033\\\\\"
                                    link_end = \"\\033]8;;\\033\\\\\"
                                    
                                    ts_str = (stime_num > 0) ? stime_num \"|\" : \"0|\"
                                    lines[count++] = ts_str \" \\033[36m\" action \"\\033[0m for \\033[32m\" price \"\\033[33mgold\\033[0m - \\033[32m\" amt \"x\\033[0m \" link_start c real_name \"\\033[0m\" link_end player_str guild_str
                                }
                            }
                            name=\"\"; price=\"\"; amt=\"\"; stime=\"\"; itemid=\"\"; subtype=\"0\"; internal_level=\"0\"
                        }
                    }
                    END {
                        for (i = 0; i < count; i++) { print lines[i] }
                        print \"MAX_TIME:\" max_time
                        for (i in db_updated) { print \"DB_UPDATE|\" db_updated[i] }
                    }" "$SAVED_VAR_DIR/TamrielTradeCentre.lua")
                    
                    NEXT_TIME=$(echo "$AWK_OUT" | grep "^MAX_TIME:" | cut -d':' -f2)
                    RAW_DATA=$(echo "$AWK_OUT" | grep -vE "^(MAX_TIME:|DB_UPDATE\|)")
                    DB_OUTPUT=$(echo "$AWK_OUT" | grep "^DB_UPDATE|")

                    if [ -n "$RAW_DATA" ]; then
                        while IFS='|' read -r ts output_str; do
                            if [ "$ts" = "0" ]; then
                                human_date="Listing"
                            else
                                human_date=$(format_date "$ts")
                            fi
                            echo -e " [\e[90m$human_date\e[0m]$output_str"
                            log_event "ITEM" "[$human_date]$output_str"
                        done <<< "$RAW_DATA"
                    else
                        echo -e " \e[90mNo new sales or listings found since last upload.\e[0m"
                        log_event "INFO" "No new TTC sales or listings found."
                    fi

                    apply_db_updates "$DB_OUTPUT"
                    
                    if [ -n "$NEXT_TIME" ] && [ "$NEXT_TIME" != "$TTC_LAST_SALE" ]; then
                        TTC_LAST_SALE="$NEXT_TIME"
                        CONFIG_CHANGED=true
                    fi
                else
                    [ "$SILENT" = false ] && echo -e " \e[90mExtraction disabled by user. Proceeding instantly to upload...\e[0m"
                    log_event "INFO" "TTC extraction disabled. Skipping to upload."
                fi
                echo -e "\n \e[36mUploading to:\e[0m https://$TTC_DOMAIN/pc/Trade/WebClient/Upload"
                
                if curl -s -A "$TTC_USER_AGENT" -F "SavedVarFileInput=@$SAVED_VAR_DIR/TamrielTradeCentre.lua" "https://$TTC_DOMAIN/pc/Trade/WebClient/Upload" > /dev/null 2>&1; then
                    NOTIF_TTC="Data Uploaded"
                    [ "$SILENT" = false ] && echo -e " \e[92m[+] Upload finished.\e[0m\n"
                    log_event "INFO" "TTC data upload successful."
                else
                    NOTIF_TTC="Upload Failed"
                    [ "$SILENT" = false ] && echo -e " \e[31m[!] Upload failed.\e[0m\n"
                    log_event "ERROR" "TTC data upload failed."
                fi
            fi
        else
            [ "$SILENT" = false ] && echo -e " \e[33m[-] No TamrielTradeCentre.lua found. \e[35mSkipping upload.\e[0m\n"
            log_event "WARN" "TamrielTradeCentre.lua not found. Skipping upload."
        fi

        # TTC DOWNLOAD 
        [ "$SILENT" = false ] && echo -e "\e[1m\e[97m [2/4] Updating your Local TTC Data \e[0m"
        [ "$SILENT" = false ] && echo -e " \e[33mChecking TTC API for price table version...\e[0m"
        log_event "INFO" "Checking TTC API for updates."
        
        TTC_LAST_CHECK="$CURRENT_TIME"
        CONFIG_CHANGED=true

        API_RESP=$(curl -s -A "$TTC_USER_AGENT" "https://$TTC_DOMAIN/api/GetTradeClientVersion")
        SRV_VERSION=$(echo "$API_RESP" | grep -o '"PriceTableVersion":[^,}]*' | cut -d':' -f2 | tr -d ' ' | tr -d '"')

        if [ -z "$SRV_VERSION" ] || ! [[ "$SRV_VERSION" =~ ^[0-9]+$ ]]; then
            NOTIF_TTC="Download Error"
            [ "$SILENT" = false ] && echo -e " \e[31m[-] Could not fetch version from TTC API. \e[35mSkipping download.\e[0m\n"
            log_event "ERROR" "Failed to fetch TTC API version."
        else
            LOCAL_VERSION="0"
            PT_FILE="$ADDON_DIR/TamrielTradeCentre/PriceTableNA.lua"
            [ "$AUTO_SRV" == "2" ] && PT_FILE="$ADDON_DIR/TamrielTradeCentre/PriceTableEU.lua"
            
            if [ -f "$PT_FILE" ]; then
                LOCAL_VERSION=$(head -n 5 "$PT_FILE" 2>/dev/null | grep -iE '^--Version[ \t]*=[ \t]*[0-9]+' | grep -oE '[0-9]+' | head -n 1)
                [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0"
            fi

            LOCAL_DISPLAY="$LOCAL_VERSION"
            [ "$LOCAL_VERSION" = "0" ] && LOCAL_DISPLAY="None / Not Found"
            [ "$SRV_VERSION" = "$LOCAL_VERSION" ] && V_COL="\e[92m" || V_COL="\e[31m"

            if [ "$SRV_VERSION" -gt "$LOCAL_VERSION" ] 2>/dev/null; then
                [ "$SILENT" = false ] && echo -ne " \e[92mNew TTC Price Table available \e[0m"
                log_event "INFO" "New TTC Price Table available (Server: $SRV_VERSION, Local: $LOCAL_VERSION)."
                
                TTC_TIME_DIFF=$((CURRENT_TIME - TTC_LAST_DOWNLOAD))
                if [ "$TTC_TIME_DIFF" -lt 3600 ] && [ "$TTC_TIME_DIFF" -ge 0 ]; then
                    WAIT_MINS=$(( (3600 - TTC_TIME_DIFF) / 60 ))
                    [ "$NOTIF_TTC" = "Data Uploaded" ] && NOTIF_TTC="Uploaded (DL Cooldown)" || NOTIF_TTC="Download Cooldown"
                    [ "$SILENT" = false ] && echo -e "\n \t\e[90mServer Version: ${V_COL}$SRV_VERSION\e[0m"
                    [ "$SILENT" = false ] && echo -e " \t\e[90mLocal Version: ${V_COL}$LOCAL_DISPLAY\e[0m"
                    [ "$SILENT" = false ] && echo -e " \e[33mbut download is on cooldown. Please wait $WAIT_MINS minutes. \e[35mSkipping.\e[0m\n"
                    log_event "WARN" "TTC download on cooldown ($WAIT_MINS mins remaining). Skipping."
                else
                    [ "$SILENT" = false ] && echo ""
                    [ "$SILENT" = false ] && echo -e " \t\e[90mServer Version: ${V_COL}$SRV_VERSION\e[0m"
                    [ "$SILENT" = false ] && echo -e " \t\e[90mLocal Version: ${V_COL}$LOCAL_DISPLAY\e[0m"
                    
                    SUCCESS=false
                    TEMP_DIR_USED=true
                    
                    if curl -f -A "$TTC_USER_AGENT" -# -L -o "TTC-data.zip" "$TTC_URL" 2>&3; then
                        if unzip -t "TTC-data.zip" > /dev/null 2>&1; then SUCCESS=true; fi
                    fi
                    
                    if [ "$SUCCESS" = false ]; then
                        [ "$SILENT" = false ] && echo -e " \e[33m[-] Primary User-Agent blocked. Falling back...\e[0m"
                        log_event "WARN" "TTC primary UA blocked. Retrying."
                        for UA in "${shuffled_uas[@]}"; do
                            if curl -f -H "User-Agent: $UA" -# -L -o "TTC-data.zip" "$TTC_URL" 2>&3; then
                                if unzip -t "TTC-data.zip" > /dev/null 2>&1; then SUCCESS=true; break; fi
                            fi
                        done
                    fi

                    if [ "$SUCCESS" = true ]; then
                        unzip -o "TTC-data.zip" -d TTC_Extracted > /dev/null
                        mkdir -p "$ADDON_DIR/TamrielTradeCentre"
                        rsync -avh TTC_Extracted/ "$ADDON_DIR/TamrielTradeCentre/" > /dev/null
                        
                        TTC_LAST_DOWNLOAD=$CURRENT_TIME
                        TTC_LOC_VERSION="$SRV_VERSION"
                        CONFIG_CHANGED=true
                        
                        [ "$NOTIF_TTC" = "Data Uploaded" ] && NOTIF_TTC="Uploaded & Updated" || NOTIF_TTC="Updated"
                        [ "$SILENT" = false ] && echo -e " \e[92m[+] TTC Data Successfully Updated.\e[0m\n"
                        log_event "INFO" "TTC PriceTable updated successfully."
                    else
                        [ "$NOTIF_TTC" = "Data Uploaded" ] && NOTIF_TTC="Uploaded, DL Failed" || NOTIF_TTC="Download Error"
                        [ "$SILENT" = false ] && echo -e " \e[31m[!] Error: TTC Data download was blocked by the server.\e[0m\n"
                        log_event "ERROR" "TTC Data download failed (blocked or corrupted)."
                    fi
                fi
            else
                TTC_LOC_VERSION="$LOCAL_VERSION"
                CONFIG_CHANGED=true
                [ "$SILENT" = false ] && echo -e " \t\e[90mServer Version: ${V_COL}$SRV_VERSION\e[0m"
                [ "$SILENT" = false ] && echo -e " \t\e[90mLocal Version: ${V_COL}$LOCAL_DISPLAY\e[0m\n"
                [ "$SILENT" = false ] && echo -e " \e[90mNo changes detected. \e[92mLocal PriceTable is up-to-date. \e[35mSkipping download.\e[0m"
                log_event "INFO" "TTC PriceTable is up-to-date."
            fi
        fi
    fi

    # ESO-HUB extraction & upload
    [ "$SILENT" = false ] && echo -e "\e[1m\e[97m [3/4] Updating ESO-Hub Prices & Uploading Scans \e[0m"
    [ "$SILENT" = false ] && echo -e " \e[36mFetching latest ESO-Hub version data...\e[0m"
    log_event "INFO" "Checking ESO-Hub API for updates."
    
    EH_LAST_CHECK="$CURRENT_TIME"
    CONFIG_CHANGED=true
    EH_UPLOAD_COUNT=0
    EH_UPDATE_COUNT=0

    API_RESP=$(curl -s -X POST -H "User-Agent: ESOHubClient/1.0.9" -d "user_token=&client_system=windows&client_version=1.0.9&lang=en" "https://data.eso-hub.com/v1/api/get-addon-versions")
    ADDON_LINES=$(echo "$API_RESP" | sed 's/{"folder_name"/\n{"folder_name"/g' | grep '"folder_name"')
    
    if [ -z "$ADDON_LINES" ]; then
        NOTIF_EH="Download Error"
        [ "$SILENT" = false ] && echo -e " \e[31m[-] Could not fetch ESO-Hub data.\e[0m\n"
        log_event "ERROR" "Failed to fetch ESO-Hub API data."
    else
        EH_TIME_DIFF=$((CURRENT_TIME - EH_LAST_DOWNLOAD))
        EH_DOWNLOAD_OCCURRED=false

        while read -r line; do
            FNAME=$(echo "$line" | grep -oE '"folder_name":"[^"]+"' | cut -d'"' -f4)
            SV_NAME=$(echo "$line" | grep -oE '"sv_file_name":"[^"]+"' | cut -d'"' -f4)
            UP_EP=$(echo "$line" | grep -oE '"endpoint":"[^"]+"' | cut -d'"' -f4 | sed 's/\\//g')
            DL_URL=$(echo "$line" | grep -oE '"file":"[^"]+"' | cut -d'"' -f4 | sed 's/\\//g')
            
            if [ -z "$FNAME" ]; then continue; fi
            HAS_THIS_EH=$(check_addon_enabled "$FNAME")
            if [ "$HAS_THIS_EH" = "false" ]; then
                [ "$SILENT" = false ] && echo -e " \e[31m[-] $FNAME is not enabled. \e[35mSkipping.\e[0m"
                log_event "INFO" "$FNAME not enabled. Skipping."
                continue
            fi

            ID_NUM=$(echo "$DL_URL" | grep -oE '[0-9]+$')
            [ -z "$ID_NUM" ] && ID_NUM="0"
            SRV_VER=$(echo "$line" | grep -oE '"version":\{[^}]*\}' | grep -oE '"string":"[^"]+"' | cut -d'"' -f4)
            
            PREFIX="$FNAME"
            [ "$FNAME" = "EsoTradingHub" ] && PREFIX="ETH5"
            [ "$FNAME" = "LibEsoHubPrices" ] && PREFIX="LEHP7"
            [ "$FNAME" = "EsoHubScanner" ] && PREFIX="EHS"

            VAR_LOC_NAME="EH_LOC_$ID_NUM"
            LOC_VER="${!VAR_LOC_NAME}"
            [ -z "$LOC_VER" ] && LOC_VER="0"
            [ "$SRV_VER" = "$LOC_VER" ] && V_COL="\e[92m" || V_COL="\e[31m"

            [ "$SILENT" = false ] && echo -e " \e[33mChecking server for $FNAME.zip...\e[0m"
            [ "$SILENT" = false ] && echo -e "\t\e[90m${PREFIX}_Server_Version= ${V_COL}$SRV_VER\e[0m"
            [ "$SILENT" = false ] && echo -e "\t\e[90m${PREFIX}_Local_Version= ${V_COL}$LOC_VER\e[0m"

            if [ -n "$SV_NAME" ] && [ -n "$UP_EP" ] && [ -f "$SAVED_VAR_DIR/$SV_NAME" ]; then
                UP_SNAP="$TARGET_DIR/lttc_eh_$(echo "$SV_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/\.lua//')_snapshot.lua"
                EH_LOCAL_CHANGED=true
                if [ -f "$UP_SNAP" ] && cmp -s "$SAVED_VAR_DIR/$SV_NAME" "$UP_SNAP"; then
                    EH_LOCAL_CHANGED=false
                fi

                if [ "$EH_LOCAL_CHANGED" = false ]; then
                    [ "$SILENT" = false ] && echo -e " \e[90mNo changes detected in $SV_NAME. \e[35mSkipping upload.\e[0m"
                    log_event "INFO" "No changes in $SV_NAME. Skipping upload."
                else
                    if [ "$SV_NAME" = "EsoTradingHub.lua" ] && [ "$ENABLE_DISPLAY" = true ] && [ "$SILENT" = false ]; then
                        echo -e " \e[36mExtracting new sales & scan data from EsoTradingHub...\e[0m"
                        log_event "INFO" "Extracting EsoTradingHub data."
                        
                        AWK_OUT=$(awk -v last_time="$EH_LAST_SALE" -v db_file="$DB_FILE" -v rand_ua="$RAND_UA" "
                        $master_color_logic
                        BEGIN { 
                            max_time = last_time; count = 0 
                            while ((getline line < db_file) > 0) {
                                split(line, p, \"|\")
                                if (p[1] == \"GUILD\") {
                                    db_guild_id[p[2]] = p[3]
                                } else if (p[1] ~ /^[0-9]+\$/) {
                                    db_cols[p[1]] = length(p)
                                    db_qual[p[1]] = p[2]
                                    if (length(p) >= 6) { db_name[p[1]] = p[6] } else { db_name[p[1]] = p[3] }
                                }
                            }
                            close(db_file)
                        }
                        { sub(/\r$/, \"\") }

                        /^[ \t]*\\[[0-9]+\\][ \t]*=/ {
                            match(\$0, /[0-9]+/)
                            current_guild_id = substr(\$0, RSTART, RLENGTH)
                            scan_type = \"\"
                        }
                        
                        # Grab Guild name mapped to its real ID and push to DB format
                        /\\[\"traderGuildName\"\\][ \t]*=[ \t]*\"/ {
                            val = \$0
                            sub(/.*\\[\"traderGuildName\"\\][ \t]*=[ \t]*\"/, \"\", val)
                            sub(/\",[ \t]*\$/, \"\", val)
                            guild_names[current_guild_id] = val
                            db_guild_updated[val] = current_guild_id
                        }
                        
                        /\\[\"(scannedSales|scannedItems|cancelledItems|purchasedItems|traderHistory)\"\\]/ {
                            match(\$0, /\"(scannedSales|scannedItems|cancelledItems|purchasedItems|traderHistory)\"/)
                            stype = substr(\$0, RSTART+1, RLENGTH-2)
                            if (stype == \"scannedSales\") scan_type = \"Sold\"
                            else if (stype == \"scannedItems\") scan_type = \"Listed\"
                            else if (stype == \"cancelledItems\") scan_type = \"Cancelled\"
                            else if (stype == \"purchasedItems\") scan_type = \"Purchased\"
                            else if (stype == \"traderHistory\") scan_type = \"History\"
                        }
                        
                        /\\|H[0-9a-fA-F]*:item:/ {
                            if (scan_type == \"\") next;

                            s_idx = index(\$0, \"\\\"|H\")
                            if (s_idx > 0) {
                                t_str = substr(\$0, s_idx + 1)
                                e_idx = index(t_str, \"\\\",\")
                                if (e_idx == 0) e_idx = index(t_str, \"\\\"\")
                                if (e_idx > 0) {
                                    full_val = substr(t_str, 1, e_idx - 1)
                                    
                                    split_idx = index(full_val, \"|h|h,\")
                                    offset = 5
                                    if (split_idx == 0) {
                                        split_idx = index(full_val, \"|h,\")
                                        offset = 3
                                    }
                                    
                                    if (split_idx > 0) {
                                        item_link = substr(full_val, 1, split_idx + 1)
                                        data_csv = substr(full_val, split_idx + offset)
                                        
                                        split(item_link, lp, \":\")
                                        itemid = lp[3]; subtype = lp[4]; internal_level = lp[5]
                                        s = subtype + 0; v = internal_level + 0
                                        
                                        split(data_csv, arr, \",\")
                                        price = arr[1]; qty = arr[2]; buyer = \"\"; seller = \"\"
                                        if (qty == \"\") qty = \"1\"
                                        
                                        if (scan_type == \"Sold\" || scan_type == \"Purchased\") {
                                            buyer = arr[3]; seller = arr[4]; stime = arr[5] + 0
                                        } else {
                                            seller = arr[3]; stime = arr[4] + 0
                                        }
                                        
                                        needs_scrape = 0
                                        real_name = \"Unknown Item (\" itemid \")\"
                                        
                                        if (itemid in db_name) {
                                            real_name = db_name[itemid]
                                            if (real_name ~ /^Unknown Item/) needs_scrape = 1
                                        } else {
                                            needs_scrape = 1
                                        }

                                        if (needs_scrape) {
                                            u_name = \"\"; blocked = 1
                                            curl_cmd = \"curl -s -m 5 --compressed -H \\\"User-Agent: \" rand_ua \"\\\" \\\"https://esoitem.uesp.net/itemLink.php?itemid=\" itemid \"\\\"\"
                                            while ((curl_cmd | getline line) > 0) {
                                                if (line ~ /<title>/ && line !~ /Just a moment/) { blocked=0; u_name=line; sub(/.*ESO Item -- /, \"\", u_name); sub(/<\\/title>.*/, \"\", u_name) }
                                            }
                                            close(curl_cmd)
                                            if (!blocked && u_name != \"\") real_name = u_name
                                        }

                                        real_qual = calc_quality(itemid, real_name, s, v)

                                        needs_update = 0
                                        if (itemid in db_name) {
                                            if (db_name[itemid] != real_name) needs_update = 1
                                            if (db_qual[itemid] != real_qual) needs_update = 1
                                            if (db_cols[itemid] < 7) needs_update = 1
                                        } else {
                                            needs_update = 1
                                        }

                                        if (needs_update) {
                                            hq = get_hq(real_qual)
                                            cat = get_cat(real_name, itemid, s, v)
                                            db_updated[itemid] = itemid \"|\" real_qual \"|\" s \"|\" v \"|\" hq \"|\" real_name \"|\" cat
                                            db_name[itemid] = real_name
                                            db_qual[itemid] = real_qual
                                            db_cols[itemid] = 7
                                        }

                                        if (real_name != \"\" && price != \"\") {
                                            q_num = real_qual + 0
                                            c = \"\\033[0m\"
                                            if(q_num==0) c=\"\\033[90m\"; else if(q_num==1) c=\"\\033[97m\"; else if(q_num==2) c=\"\\033[32m\"
                                            else if(q_num==3) c=\"\\033[36m\"; else if(q_num==4) c=\"\\033[35m\"; else if(q_num==5) c=\"\\033[33m\"
                                            else if(q_num==6) c=\"\\033[38;5;214m\"
                                            
                                            link_start = \"\\033]8;;https://eso-hub.com/en/trading/\" itemid \"\\033\\\\\"
                                            link_end = \"\\033]8;;\\033\\\\\"
                                            item_display = link_start c real_name \"\\033[0m\" link_end
                                            
                                            if (stime > max_time) max_time = stime
                                            if (stime > last_time) {
                                                b_str = (buyer != \"\") ? \" to \\033[36m\" buyer \"\\033[0m\" : \"\"
                                                s_str = (seller != \"\") ? \" by \\033[36m\" seller \"\\033[0m\" : \"\"
                                                lines[count++] = stime \"|\" \" \\033[36m\" scan_type \"\\033[0m for \\033[32m\" price \"\\033[33mgold\\033[0m - \\033[32m\" qty \"x\\033[0m \" item_display s_str b_str \" in GUILD_PLACEHOLDER_\" current_guild_id
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        END {
                            for (i = 0; i < count; i++) { 
                                l = lines[i]
                                for (gid in guild_names) {
                                    g_link = \"\\033[35m\\033]8;;|H1:guild:\" gid \"|h\" guild_names[gid] \"|h\\033\\\\\" guild_names[gid] \"\\033]8;;\\033\\\\\\033[0m\"
                                    gsub(\"GUILD_PLACEHOLDER_\" gid, g_link, l)
                                }
                                gsub(/GUILD_PLACEHOLDER_[0-9]+/, \"\\033[35mUnknown Guild\\033[0m\", l)
                                print l 
                            }
                            print \"MAX_TIME:\" max_time
                            for (i in db_updated) { print \"DB_UPDATE|\" db_updated[i] }
                            for (g in db_guild_updated) { print \"DB_GUILD|\" g \"|\" db_guild_updated[g] }
                        }" "$SAVED_VAR_DIR/$SV_NAME")
                        
                        NEXT_TIME=$(echo "$AWK_OUT" | grep "^MAX_TIME:" | cut -d':' -f2)
                        RAW_DATA=$(echo "$AWK_OUT" | grep -vE "^(MAX_TIME:|DB_UPDATE\||DB_GUILD\|)")
                        DB_OUTPUT=$(echo "$AWK_OUT" | grep -E "^(DB_UPDATE\||DB_GUILD\|)")

                        if [ -n "$RAW_DATA" ]; then
                            while IFS='|' read -r ts output_str; do
                                human_date=$(format_date "$ts")
                                echo -e " [\e[90m$human_date\e[0m]$output_str"
                                log_event "ITEM" "[$human_date]$output_str"
                            done <<< "$RAW_DATA"
                        else
                            echo -e " \e[90mNo new ESO-Hub sales or scans found since last upload.\e[0m"
                            log_event "INFO" "No new ESO-Hub sales found."
                        fi

                        apply_db_updates "$DB_OUTPUT"
                        
                        if [ -n "$NEXT_TIME" ] && [ "$NEXT_TIME" != "$EH_LAST_SALE" ]; then
                            EH_LAST_SALE="$NEXT_TIME"
                            CONFIG_CHANGED=true
                        fi
                    else
                         if [ "$SV_NAME" = "EsoTradingHub.lua" ] && [ "$ENABLE_DISPLAY" = false ] && [ "$SILENT" = false ]; then
                             echo -e " \e[90mExtraction disabled by user. Proceeding instantly to upload...\e[0m"
                             log_event "INFO" "EsoTradingHub extraction disabled."
                         fi
                    fi
                    
                    if [ "$SV_NAME" = "EsoHubScanner.lua" ] && [ "$ENABLE_DISPLAY" = true ] && [ "$SILENT" = false ]; then
                        echo -e " \e[36mExtracting scanned items from EsoHubScanner...\e[0m"
                        log_event "INFO" "Extracting EsoHubScanner data."
                        
                        AWK_SCAN_OUT=$(awk -v db_file="$DB_FILE" -v rand_ua="$RAND_UA" "
                        $master_color_logic
                        BEGIN { 
                            while ((getline line < db_file) > 0) {
                                split(line, p, \"|\")
                                if (p[1] == \"GUILD\") {
                                    db_guild_id[p[2]] = p[3]
                                } else if (p[1] ~ /^[0-9]+\$/) {
                                    db_cols[p[1]] = length(p)
                                    db_qual[p[1]] = p[2]
                                    if (length(p) >= 6) { db_name[p[1]] = p[6] } else { db_name[p[1]] = p[3] }
                                }
                            }
                            close(db_file)
                        }
                        { sub(/\r$/, \"\") }

                        /\\|H[0-9a-fA-F]*:item:/ {
                            s_idx = index(\$0, \"\\\"|H\")
                            if (s_idx > 0) {
                                t_str = substr(\$0, s_idx + 1)
                                e_idx = index(t_str, \"\\\",\")
                                if (e_idx == 0) e_idx = index(t_str, \"\\\"\")
                                if (e_idx > 0) {
                                    full_val = substr(t_str, 1, e_idx - 1)
                                    
                                    split_idx = index(full_val, \"|h|h\")
                                    if (split_idx == 0) split_idx = index(full_val, \"|h\")
                                    if (split_idx > 0) {
                                        item_link = substr(full_val, 1, split_idx + 1)
                                        split(item_link, lp, \":\")
                                        itemid = lp[3]; subtype = lp[4]; internal_level = lp[5]
                                        
                                        s = subtype + 0; v = internal_level + 0
                                        needs_scrape = 0
                                        real_name = \"Unknown Item (\" itemid \")\"

                                        if (itemid in db_name) {
                                            real_name = db_name[itemid]
                                            if (real_name ~ /^Unknown Item/) needs_scrape = 1
                                        } else {
                                            needs_scrape = 1
                                        }
                                        
                                        if (needs_scrape) {
                                            u_name = \"\"; blocked = 1
                                            curl_cmd = \"curl -s -m 5 --compressed -H \\\"User-Agent: \" rand_ua \"\\\" \\\"https://esoitem.uesp.net/itemLink.php?itemid=\" itemid \"\\\"\"
                                            while ((curl_cmd | getline line) > 0) {
                                                if (line ~ /<title>/ && line !~ /Just a moment/) { blocked=0; u_name=line; sub(/.*ESO Item -- /, \"\", u_name); sub(/<\\/title>.*/, \"\", u_name) }
                                            }
                                            close(curl_cmd)
                                            if (!blocked && u_name != \"\") real_name = u_name
                                        }

                                        real_qual = calc_quality(itemid, real_name, s, v)

                                        needs_update = 0
                                        if (itemid in db_name) {
                                            if (db_name[itemid] != real_name) needs_update = 1
                                            if (db_qual[itemid] != real_qual) needs_update = 1
                                            if (db_cols[itemid] < 7) needs_update = 1
                                        } else {
                                            needs_update = 1
                                        }

                                        if (needs_update) {
                                            hq = get_hq(real_qual)
                                            cat = get_cat(real_name, itemid, s, v)
                                            db_updated[itemid] = itemid \"|\" real_qual \"|\" s \"|\" v \"|\" hq \"|\" real_name \"|\" cat
                                            db_name[itemid] = real_name
                                            db_qual[itemid] = real_qual
                                            db_cols[itemid] = 7
                                        }
                                        
                                        if (real_name != \"\" && real_name !~ /^\\|[0-9]+\\|$/) {
                                            q_num = real_qual + 0
                                            c = \"\\033[0m\"
                                            if(q_num==0) c=\"\\033[90m\"; else if(q_num==1) c=\"\\033[97m\"; else if(q_num==2) c=\"\\033[32m\"
                                            else if(q_num==3) c=\"\\033[36m\"; else if(q_num==4) c=\"\\033[35m\"; else if(q_num==5) c=\"\\033[33m\"
                                            else if(q_num==6) c=\"\\033[38;5;214m\"

                                            lines[count++] = \" [\\033[90mScanned\\033[0m] \" c real_name \"\\033[0m\"
                                        }
                                    }
                                }
                            }
                        }
                        END {
                            for (i = 0; i < count; i++) { print lines[i] }
                            for (i in db_updated) { print \"DB_UPDATE|\" db_updated[i] }
                        }" "$SAVED_VAR_DIR/$SV_NAME")
                        
                        DB_OUTPUT=$(echo "$AWK_SCAN_OUT" | grep "^DB_UPDATE|")
                        RAW_SCAN=$(echo "$AWK_SCAN_OUT" | grep -v "^DB_UPDATE|")
                        
                        if [ -n "$RAW_SCAN" ]; then
                            echo "$RAW_SCAN"
                            if [ "$LOG_MODE" = "detailed" ]; then
                                echo "$RAW_SCAN" | perl -pe 's/\e\[[0-9;]*m//g' >> "$LOG_FILE"
                            fi
                        else
                            echo -e " \e[90mNo new items found in scanner.\e[0m"
                            log_event "INFO" "No new scanner items."
                        fi

                        apply_db_updates "$DB_OUTPUT"
                    else
                         if [ "$SV_NAME" = "EsoHubScanner.lua" ] && [ "$ENABLE_DISPLAY" = false ] && [ "$SILENT" = false ]; then
                             echo -e " \e[90mExtraction disabled by user. Proceeding instantly to upload...\e[0m"
                             log_event "INFO" "EsoHubScanner extraction disabled."
                         fi
                    fi

                    [ "$SILENT" = false ] && echo -e " \e[36mUploading local scan data ($SV_NAME)...\e[0m"
                    if curl -s -A "ESOHubClient/1.0.9" -F "file=@$SAVED_VAR_DIR/$SV_NAME" "https://data.eso-hub.com$UP_EP?user_token=" > /dev/null 2>&1; then
                        cp -f "$SAVED_VAR_DIR/$SV_NAME" "$UP_SNAP" 2>/dev/null
                        EH_UPLOAD_COUNT=$((EH_UPLOAD_COUNT + 1))
                        [ "$SILENT" = false ] && echo -e " \e[92m[+] Upload finished ($SV_NAME).\e[0m"
                        log_event "INFO" "Uploaded $SV_NAME successfully."
                    else
                        log_event "ERROR" "Failed to upload $SV_NAME."
                    fi
                fi
            fi

            if [ -n "$DL_URL" ]; then
                if [ "$SRV_VER" = "$LOC_VER" ]; then
                    [ "$SILENT" = false ] && echo -e " \e[90mNo changes detected. \e[92m($FNAME.zip) is up-to-date. \e[35mSkipping download.\e[0m"
                    log_event "INFO" "$FNAME is up-to-date."
                else
                    if [ "$EH_TIME_DIFF" -lt 3600 ] && [ "$EH_TIME_DIFF" -ge 0 ]; then
                        WAIT_MINS=$(( (3600 - EH_TIME_DIFF) / 60 ))
                        [ "$SILENT" = false ] && echo -e " \e[33mNew $FNAME.zip available, but download is on cooldown for $WAIT_MINS more minutes. \e[35mSkipping.\e[0m"
                        log_event "WARN" "$FNAME download on cooldown ($WAIT_MINS mins)."
                    else
                        [ "$SILENT" = false ] && echo -e " \e[36mDownloading: $FNAME.zip\e[0m"
                        log_event "INFO" "Downloading $FNAME.zip"
                        TEMP_DIR_USED=true
                        if ! curl -f -# -L -A "ESOHubClient/1.0.9" -o "EH_$ID_NUM.zip" "$DL_URL" 2>&3; then
                            curl -f -# -L -A "$RAND_UA" -o "EH_$ID_NUM.zip" "$DL_URL" 2>&3
                        fi
                        
                        if unzip -t "EH_$ID_NUM.zip" > /dev/null 2>&1; then
                            unzip -o "EH_$ID_NUM.zip" -d ESOHub_Extracted > /dev/null
                            rsync -avh ESOHub_Extracted/ "$ADDON_DIR/" > /dev/null
                            
                            eval "$VAR_LOC_NAME=\"\$SRV_VER\""
                            CONFIG_CHANGED=true
                            EH_DOWNLOAD_OCCURRED=true
                            EH_UPDATE_COUNT=$((EH_UPDATE_COUNT + 1))
                            
                            [ "$SILENT" = false ] && echo -e " \e[92m[+] $FNAME.zip updated successfully.\e[0m"
                            log_event "INFO" "$FNAME updated successfully."
                        else
                            [ "$SILENT" = false ] && echo -e " \e[31m[!] Error: $FNAME.zip download corrupted.\e[0m"
                            log_event "ERROR" "$FNAME download corrupted."
                        fi
                    fi
                fi
            fi
        done <<< "$ADDON_LINES"
        
        if [ "$EH_DOWNLOAD_OCCURRED" = true ]; then EH_LAST_DOWNLOAD=$CURRENT_TIME; fi
        if [ "$EH_UPDATE_COUNT" -gt 0 ] || [ "$EH_UPLOAD_COUNT" -gt 0 ]; then
            NOTIF_EH="Updated ($EH_UPDATE_COUNT), Uploaded ($EH_UPLOAD_COUNT)"
        fi
        [ "$SILENT" = false ] && echo -e ""
    fi

    # HarvestMap extraction & upload
    if [ "$HAS_HM" = "false" ]; then
        NOTIF_HM="Not Installed (Skipped)"
        [ "$SILENT" = false ] && echo -e "\e[1m\e[97m [4/4] Updating HarvestMap Data (SKIPPED) \e[0m"
        [ "$SILENT" = false ] && echo -e " \e[31m[-] HarvestMap is not enabled in AddOnSettings.txt. \e[35mSkipping...\e[0m\n"
        log_event "WARN" "HarvestMap not enabled. Skipping."
    else
        HM_DIR="$ADDON_DIR/HarvestMapData"
        EMPTY_FILE="$HM_DIR/Main/emptyTable.lua"
        MAIN_HM_FILE="$SAVED_VAR_DIR/HarvestMap.lua"
        HM_SNAP="$TARGET_DIR/lttc_hm_main_snapshot.lua"
        
        if [[ -d "$HM_DIR" ]]; then
            HM_CHANGED=true
            LOCAL_HM_STATUS="Out-of-Sync"
            SRV_HM_STATUS="Latest"

            if [[ -f "$MAIN_HM_FILE" ]]; then
                if [[ -f "$HM_SNAP" ]] && cmp -s "$MAIN_HM_FILE" "$HM_SNAP"; then
                    HM_CHANGED=false
                    LOCAL_HM_STATUS="Synced"
                fi
            fi

            HM_LAST_CHECK="$CURRENT_TIME"
            CONFIG_CHANGED=true
            
            [ "$HM_CHANGED" = false ] && V_COL="\e[92m" || V_COL="\e[31m"

            if [ "$SILENT" = false ]; then
                echo -e "\e[1m\e[97m [4/4] Updating HarvestMap Data \e[0m"
                echo -e " \e[33mVerifying HarvestMap local data state...\e[0m"
                echo -e "\t\e[90mServer_Data_Status= \e[92m$SRV_HM_STATUS\e[0m"
                echo -e "\t\e[90mLocal_Data_Status= ${V_COL}$LOCAL_HM_STATUS\e[0m"
            fi

            if [[ "$HM_CHANGED" = false ]]; then
                [ "$SILENT" = false ] && echo -e " \e[90mNo changes detected. \e[92mHarvestMap.lua is up-to-date. \e[35mSkipping process.\e[0m\n"
                log_event "INFO" "HarvestMap is up-to-date."
            else
                HM_TIME_DIFF=$((CURRENT_TIME - HM_LAST_DOWNLOAD))
                
                if [ "$HM_TIME_DIFF" -lt 3600 ] && [ "$HM_TIME_DIFF" -ge 0 ]; then
                    WAIT_MINS=$(( (3600 - HM_TIME_DIFF) / 60 ))
                    NOTIF_HM="Cooldown ($WAIT_MINS min)"
                    [ "$SILENT" = false ] && echo -e " \e[33mHarvestMap local changes detected, but download is on cooldown for $WAIT_MINS more minutes. \e[35mSkipping.\e[0m\n"
                    log_event "WARN" "HarvestMap download on cooldown ($WAIT_MINS mins)."
                else
                    [[ -f "$MAIN_HM_FILE" ]] && cp -f "$MAIN_HM_FILE" "$HM_SNAP" 2>/dev/null
                    mkdir -p "$SAVED_VAR_DIR"
                    log_event "INFO" "Starting HarvestMap update process."
                    
                    hmFailed=false
                    for zone in AD EP DC DLC NF; do
                        svfn1="$SAVED_VAR_DIR/HarvestMap${zone}.lua"
                        svfn2="${svfn1}~"
                        
                        if [[ -e "$svfn1" ]]; then
                            mv -f "$svfn1" "$svfn2"
                        else
                            name="Harvest${zone}_SavedVars"
                            if [[ -f "$EMPTY_FILE" ]]; then
                                echo -n "$name" | cat - "$EMPTY_FILE" > "$svfn2" 2>/dev/null
                            else
                                echo -n "$name={[\"data\"]={}}" > "$svfn2"
                            fi
                        fi
                        
                        mkdir -p "$HM_DIR/Modules/HarvestMap${zone}"
                        [ "$SILENT" = false ] && echo -e " \e[36mDownloading database chunk to:\e[0m $HM_DIR/Modules/HarvestMap${zone}/HarvestMap${zone}.lua"
                        
                        if ! curl -f -s -L -A "$HM_USER_AGENT" -d @"$svfn2" -o "$HM_DIR/Modules/HarvestMap${zone}/HarvestMap${zone}.lua" "http://harvestmap.binaryvector.net:8081"; then
                            [ "$SILENT" = false ] && echo -e "  \e[33m[-] Primary UA blocked. Retrying with fallback UA...\e[0m"
                            log_event "WARN" "HarvestMap primary UA blocked. Retrying."
                            if ! curl -f -s -L -H "User-Agent: $RAND_UA" -d @"$svfn2" -o "$HM_DIR/Modules/HarvestMap${zone}/HarvestMap${zone}.lua" "http://harvestmap.binaryvector.net:8081"; then
                                hmFailed=true
                                log_event "ERROR" "Failed to download HarvestMap zone: $zone"
                            fi
                        fi
                    done
                    
                    if [ "$hmFailed" = false ]; then
                        HM_LAST_DOWNLOAD=$CURRENT_TIME
                        CONFIG_CHANGED=true
                        NOTIF_HM="Updated successfully"
                        [ "$SILENT" = false ] && echo -e "\n \e[92m[+] HarvestMap Data Successfully Updated.\e[0m\n"
                        log_event "INFO" "HarvestMap updated successfully."
                    else
                        NOTIF_HM="Error (Server Blocked)"
                        log_event "ERROR" "HarvestMap update failed."
                    fi
                fi
            fi
        else
            NOTIF_HM="Not Found (Skipped)"
            [ "$SILENT" = false ] && echo -e "\e[1m\e[97m [4/4] Updating HarvestMap Data (SKIPPED) \e[0m"
            [ "$SILENT" = false ] && echo -e " \e[31m[!] HarvestMapData folder not found in: $ADDON_DIR. \e[35mSkipping...\e[0m\n"
            log_event "WARN" "HarvestMap folder not found."
        fi
    fi

    if [ "$CONFIG_CHANGED" = true ]; then save_config; fi

    if [ "$TEMP_DIR_USED" = true ]; then
        [ "$SILENT" = false ] && echo -e "\e[31mCleaning up temporary files...\e[0m"
        [ "$SILENT" = false ] && echo -e "\e[31mDeleting Temp Directory at: $TEMP_DIR\e[0m"
    fi
    cd "$HOME" || exit
    rm -rvf "$TEMP_DIR" > /dev/null
    if [ "$TEMP_DIR_USED" = true ]; then
        [ "$SILENT" = false ] && echo -e "\e[92m[+] Cleanup Complete.\e[0m\n"
    fi

    if [ "$ENABLE_NOTIFS" = true ]; then
        send_notification "TTC: $NOTIF_TTC\nESO-Hub: $NOTIF_EH\nHarvestMap: $NOTIF_HM"
    fi

    if [ "$AUTO_MODE" == "1" ]; then 
        log_event "INFO" "Run-once mode complete. Exiting."
        exit 0
    fi

    if [ "$IS_STEAM_LAUNCH" = true ]; then
        log_event "INFO" "Entering Steam background loop."
        if [ "$SILENT" = true ]; then
            for (( i=0; i<3600; i++ )); do
                read -t 1 -n 1 -s 2>/dev/null || true
                if (( i % 10 == 0 )); then
                    if ! check_game_active; then 
                        log_event "INFO" "Game closed. Exiting."
                        exit 0; 
                    fi
                fi
            done
        else
            echo -e " \e[1;97;101m Restarting Sequence in 60 minutes... (Steam Mode) \e[0m\n"
            for (( i=3600; i>0; i-- )); do
                min=$(( i / 60 )); sec=$(( i % 60 ))
                printf " \e[1;97;101m Countdown: %02d:%02d \e[0m\033[0K\r" "$min" "$sec"
                read -t 1 -n 1 -s 2>/dev/null || true
                if (( i % 5 == 0 )); then
                    if ! check_game_active; then
                        echo -e "\n\n \e[33mGame closed. Terminating updater...\e[0m"
                        log_event "INFO" "Game closed. Exiting."
                        exit 0
                    fi
                fi
            done
        fi
    else
        log_event "INFO" "Entering standalone background loop."
        if [ "$SILENT" = true ]; then
            read -t 3600 -n 1 -s 2>/dev/null || true
        else
            echo -e " \e[1;97;101m Restarting Sequence in 60 minutes... (Standalone Mode) \e[0m\n"
            for (( i=3600; i>0; i-- )); do
                min=$(( i / 60 )); sec=$(( i % 60 ))
                printf " \e[1;97;101m Countdown: %02d:%02d \e[0m\033[0K\r" "$min" "$sec"
                read -t 1 -n 1 -s 2>/dev/null || true
            done
        fi
    fi
done
