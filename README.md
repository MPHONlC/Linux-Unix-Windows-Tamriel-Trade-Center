# Tamriel Trade Center, HarvestMap & ESO-Hub Auto-Updater for Linux, macOS, SteamDeck, & Windows

An **interactive script** to fully automate your TTC, HarvestMap, and ESO-Hub data syncing without ever needing to run their respective "Client.exe" via Proton, Wine, or Java.

I originally created this because getting the TTC Client to run flawlessly on Proton/Wine/Lutris was often a hassle and I had to run not just 1 but 2 to 3 clients just to update those data (TTC, HarvestMap, and ESO-Hub). It was mainly created for Linux but has now evolved to be completely cross-platform. 

The script will automatically find your game directory, detect your addons folder, set up Steam Launch options, extract and display recent sales & listings with item qualities, generate links to their respective websites, and run silently in the background alongside the game.

## Features Include
* **Uploads Your Listings:** Automatically detects & extracts your local TTC/ESO-Hub sales/listings data **every hour** and uploads them to the TTC/ESO-Hub Servers.
* **Downloads Latest PriceTables:** Detects if there is a new version of the PriceTable and downloads it from TTC/ESO-Hub Servers **DAILY**.
* **HarvestMap Data Sync:** Uploads and merges your node data with the server's database.
* **Auto Setup:** Scans drives to locate your game and addon folders automatically, and checks *AddOnSettings.txt* to skip disabled addons.
* **Native OS Notifications:** Sends clean system notifications (Windows Action Center, Linux `notify-send`, macOS `osascript`) to summarize update statuses.

## Dependencies
This script requires the following addons to fully function:
* [Tamriel Trade Centre](https://www.esoui.com/downloads/info1245-TamrielTradeCentre.html)
* [HarvestMap](https://www.esoui.com/downloads/info57-HarvestMap.html)
* [HarvestMap-Data](https://www.esoui.com/downloads/info3034-HarvestMap-Data.html)
* [ESO-Hub Trading](https://www.esoui.com/downloads/info4095-ESO-HubTrading.html)

---

## Installation & Usage

### For Linux
1. Download the `Linux_Tamriel_Trade_Center.sh` script.
2. Open your terminal, navigate to where you downloaded it (e.g., `cd ~/Downloads`).
3. Make it executable by typing: `chmod +x Linux_Tamriel_Trade_Center.sh`
4. Run it by typing: `./Linux_Tamriel_Trade_Center.sh`
5. Follow the interactive setup.

### For Steam Deck
1. Switch your Steam Deck to **Desktop Mode**.
2. Download the `Linux_Tamriel_Trade_Center.sh` script.
3. Open the **Konsole** application and navigate to your downloads (e.g., `cd ~/Downloads`).
4. Make it executable by typing: `chmod +x Linux_Tamriel_Trade_Center.sh`
5. Run it by typing: `./Linux_Tamriel_Trade_Center.sh`
6. Follow the setup. When finished, you can safely return to Gaming Mode.

### For macOS
1. Download the `Linux_Tamriel_Trade_Center.sh` script.
2. Open the **Terminal** app and navigate to your download location (e.g., `cd ~/Downloads`).
3. Make it executable by typing: `chmod +x Linux_Tamriel_Trade_Center.sh`
4. Run it by typing: `./Linux_Tamriel_Trade_Center.sh`
5. Follow the interactive setup.

### For Windows
1. Download the `Windows_Tamriel_Trade_Center.bat` file.
2. Double-click the file to run it. 
3. Follow the interactive setup.

---

## Command Line Arguments & Steam Launch Options

* **`--silent`**
  Hides the terminal window and suppresses all text output. Useful for running the script invisibly in the background.
* **`--task`**
  Used internally for invisible background startup tasks (activates the System Tray icon on Windows).
* **`--auto`**
  Skips the interactive setup questions. It forces the script to run immediately using your saved configuration or defaults.
* **`--steam`**
  Signals the script that it was launched via Steam. It will track your game process and automatically shut down when you close ESO.
* **`--na`** or **`--eu`**
  Forces the script to download price data from the North American (US) or European (EU) Tamriel Trade Centre server.
* **`--loop`**
  Runs the updater continuously. It will update your data, wait for 60 minutes, and then update again as long as the script is open.
* **`--once`**
  Runs the updater exactly one time and then immediately closes the script.
* **`--addon-dir "/path/to/folder"`**
  Manually overrides the auto-detection and forces the script to use a specific folder for your AddOns.

---

## How It Works & Where Files Go

To keep your system clean, the script completely isolates its environment. It installs itself into a dedicated folder in your system's **Documents** directory.

* **Configuration & Database:** `lttc_updater.conf` and a local item database are saved here to remember your server, terminal preferences, and extracted data.
* **Snapshots:** Snapshot files (e.g., `lttc_ttc_snapshot.lua`) are created to compare file hashes so the script only uploads data when actual changes occur.
* **Logs:** A `.log` file is generated here tracking script events, uploads, and detailed item extractions if enabled.
* **Steam Injection & Backups:** If you choose to automatically apply the Steam Launch commands, the script modifies your `localconfig.vdf`. A timestamped backup of your original Steam config is always saved to a "Backups" folder first.

> **⚠️ NOTE:** To avoid rate-limits and "Too many requests" blocks, the background loop timer for downloading data is strictly set to update a maximum of once every 60 minutes (either way they only update daily). This timer also affects uploads, and uploads only happen when there is actual data to be uploaded.

---

## Additional Information & Default Paths

The script automatically scans your system for the following default Addon locations to speed up setup. If yours is not found, you can always enter it manually:

**Windows:**
```text
C:\Users\%USERPROFILE%\Documents\Elder Scrolls Online\live\AddOns
C:\Users\%USERPROFILE%\OneDrive\Documents\Elder Scrolls Online\live\AddOns
C:\Users\Public\Documents\Elder Scrolls Online\live\AddOns
```

**macOS:**
```text
~/Documents/Elder Scrolls Online/live/AddOns
```

**Steam Deck & Linux Native Steam:**
```text
~/.local/share/Steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/
~/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/
```

**Flatpak Steam:**
```text
~/.var/app/com.valvesoftware.Steam/.steam/root/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/
```

**PortProton:**
```text
~/PortProton/prefixes/DEFAULT/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/
```

**Lutris / Standard Wine / Bottles:**
```text
~/Games/elder-scrolls-online/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns/
~/.wine/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns/
~/.var/app/com.usebottles.bottles/data/bottles/bottles/NAME-OF-YOUR-BOTTLE/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns/
```

## FOR (TROUBLESHOOTING)

If the updater ever gets stuck running in the background (hidden), or if you need to force quit the background loop immediately, you can use these commands to safely terminate the script on any platform.

**For Linux & Steam Deck:**
Open your Terminal (or the **Konsole** app in Steam Deck's Desktop Mode) and run this command:
```bash
pkill -f "Tamriel_Trade_Center"
rm -rf /tmp/ttc_updater*
```

**For macOS:**
Open the **Terminal** app (found in Applications > Utilities) and run:
```bash
pkill -f "Tamriel_Trade_Center"
```

**For Windows:**
Because the Windows version spawns a hidden PowerShell process, finding it in the standard Task Manager can be tricky. Open **Command Prompt (cmd)** and run this command to safely terminate only the updater:
```cmd
wmic process where "CommandLine like '%Tamriel_Trade_Center%'" call terminate
```

*Secondary Option (Windows only):* If the precise command above doesn't work for some reason, you can immediately wipe out all background PowerShell tasks by running this in the Command Prompt. 
```cmd
taskkill /F /IM powershell.exe /T
``` 
*(Warning: this will close ALL PowerShell windows you might have open).*

## How to Autorun at Startup/Login (Visible Terminal)

If you want the script to automatically start when you boot up your computer, but you want to actually see the terminal window running, here is how to set it up for Linux & macOS.
(Windows has this option built-in, I could not test all distros and macOS devices so I'm providing this as a manual optional option. you can ignore this part if you intend to run it along side steam when you click "Play" Button)

**For Linux & Steam Deck:**
Steam Deck's Desktop Mode and most Linux distributions use ".desktop" files for startup tasks.
1. Open your Terminal (or the **Konsole** app on Steam Deck).
2. Ensure the autostart folder exists by running:
```bash
mkdir -p ~/.config/autostart
```
3. Create a new autostart file:
```bash
nano ~/.config/autostart/ttc-updater.desktop
```
4. Paste the following configuration. Be sure to replace "/path/to/your/" with the actual folder where your script is located:
```ini
[Desktop Entry]
Type=Application
Name=Linux/Unix Auto-Updater for TTC, HarvestMap & ESO-Hub
Exec=/path/to/your/Linux_Tamriel_Trade_Center.sh --auto
Terminal=true
X-GNOME-Autostart-enabled=true
```
5. Save and exit.

**For macOS:**
Because standard macOS background tasks (launchd) are completely invisible, the easiest way to get a visible terminal at login is to use the native Login Items feature.
1. Open Finder and locate your downloaded script.
2. Rename the file extension from ".sh" to ".command" (for example, "Linux_Tamriel_Trade_Center.command"). This tells macOS that it should natively open in the Terminal app.
3. Open your **System Settings** (or System Preferences on older versions) and go to **General > Login Items**.
4. Click the **+** button under the "Open at Login" list.
5. Browse to and select your newly renamed ".command" script.
It will now automatically launch a visible Terminal window every time you log into your Mac.

## How to Autorun at Startup/Login (Hidden/Invisible)

If you want the script to automatically start when you boot up your computer, but you want it to run completely invisibly in the background, here is how to set it up for Linux & macOS.

**For Linux & Steam Deck:**
Steam Deck's Desktop Mode and most Linux distributions use ".desktop" files for startup tasks.
1. Open your Terminal (or the **Konsole** app on Steam Deck).
2. Ensure the autostart folder exists by running:
```bash
mkdir -p ~/.config/autostart
```
3. Create a new autostart file:
```bash
nano ~/.config/autostart/ttc-updater-hidden.desktop
```
4. Paste the following configuration. Be sure to replace "/path/to/your/" with the actual folder where your script is located:
```ini
[Desktop Entry]
Type=Application
Name=Linux/Unix Auto-Updater for TTC, HarvestMap & ESO-Hub
Exec=/path/to/your/Linux_Tamriel_Trade_Center.sh --auto --silent
Terminal=false
X-GNOME-Autostart-enabled=true
```
5. Save and exit. The "Terminal=false" line and the "--silent" flag ensure it runs silently without popping up a window.

**For macOS:**
macOS uses property list (".plist") files to run background processes invisibly.
1. Open your **Terminal** app.
2. Create a new plist file in your LaunchAgents folder:
```bash
nano ~/Library/LaunchAgents/com.trading.autoupdater.plist
```
3. Paste the following configuration. Be sure to replace "/path/to/your/" with the actual folder where your script is located:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "[http://www.apple.com/DTDs/PropertyList-1.0.dtd](http://www.apple.com/DTDs/PropertyList-1.0.dtd)">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.trading.autoupdater</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/your/Linux_Tamriel_Trade_Center.sh</string>
        <string>--auto</string>
        <string>--silent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
```
4. Save and exit.
5. Finally, tell macOS to load and enable this invisible startup task immediately:
```bash
launchctl load ~/Library/LaunchAgents/com.trading.autoupdater.plist
```

## Credits & Disclaimer

**Icon Credits** :
The desktop shortcut and tray icon generated by this script use the official favicon from [Tamriel Trade Centre](https://tamrieltradecentre.com). All rights to this image belong to the creators of TTC.

**Copyright & Addon Rights** :
This script interacts with data from Tamriel Trade Centre (TTC), HarvestMap, and ESO-Hub. I am not affiliated with the developers of these addons, nor do I intend to infringe upon their copyrights or negatively impact their work or user base. All rights, intellectual property, and credit for these addons belong entirely to their respective creators and development teams. 

**Purpose of this Script** :
This is a utility designed solely as a quality-of-life tool. Its only purpose is to help users easily manage, sync, and update their local data for these specific addons automatically, bypassing the need to install or run multiple individual background executables. 

**Liability Waiver** :
This script is provided "as is," without warranty of any kind. While it was built to safely handle your SavedVariables, you use this tool entirely at your own risk. I am not responsible for any data loss, file corruption, or unintended issues that may occur while using this script. It is always recommended to back up your `SavedVariables` folder periodically.

---

<div align="center">

### 🐞 BUG REPORTS
If you encounter any issues, please submit a report here or at:
**[ESOUI Bug Portal](https://www.esoui.com/portal.php?id=360&a=listbugs)**

</div>
