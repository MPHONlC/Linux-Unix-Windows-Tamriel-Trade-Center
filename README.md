# Linux Tamriel Trade Center Updater for Linux, macOS, SteamDeck, & Windows

An **interactive script** to fully automate your TTC, HarvestMap, and ESO-Hub data syncing without ever needing to run their respective "Client.exe" via Proton, Wine, or Java.

I originally created this because getting the TTC Client to run flawlessly on Proton/Wine/Lutris was often a hassle and I had to run not just 1 but 2 to 3 clients just to update those data (TTC, HarvestMap, and ESO-Hub). It was mainly created for linux but now has evolved to be crossplatform and and while it was all manually done by editing the script (which you still can if I didin't cover all the proper locations, as there are too many variables to account for "different distros, different drive locations, different software clients") now it will automatically find your game directory, detect your addons folder, sets up a Steam Launch argument (you can still manually launch the script if you do not wish to use the steam launch options), and runs silently in the background alongside your game.

### 🌟 Features Include:
* **Uploads Your Listings:** Automatically extracts your local TTC sales/listings and uploads them to the TTC Server.
* **Downloads TTC Prices:** Download the latest PriceTables.
* **Downloads ESOHub Prices:** Checks the ESOUI schedule and downloads weekly ESOHub price data.
* **HarvestMap Data Sync:** Uploads and merges your node data with the global database.
* **Auto-Setup:** Scans drives to locate your game and addon folders automatically.

### 📦 Dependencies:
This addon requires the following addons to fully function:
* [Tamriel Trade Centre](https://www.esoui.com/downloads/info1245-TamrielTradeCentre.html)
* [HarvestMap](https://www.esoui.com/downloads/info57-HarvestMap.html)
* [HarvestMap-Data](https://www.esoui.com/downloads/info3034-HarvestMap-Data.html)
* [ESO-Hub Trading](https://www.esoui.com/downloads/info4095-ESO-HubTrading.html)

---

## 🚀 INSTALLATION & USAGE

**For Linux:**
1. Download the `Linux_Tamriel_Trade_Center.sh` script.
2. Open your terminal, navigate to where you downloaded it (e.g., `cd ~/Downloads`).
3. Make it executable by typing: `chmod +x Linux_Tamriel_Trade_Center.sh`
4. Run it by typing: `./Linux_Tamriel_Trade_Center.sh`
5. Follow the interactive setup.

**For Steam Deck:**
1. Switch your Steam Deck to **Desktop Mode**.
2. Download the `Linux_Tamriel_Trade_Center.sh` script.
3. Open the **Konsole** application and navigate to your downloads (e.g., `cd ~/Downloads`).
4. Make it executable by typing: `chmod +x Linux_Tamriel_Trade_Center.sh`
5. Run it by typing: `./Linux_Tamriel_Trade_Center.sh`
6. Follow the setup. When finished, you can safely return to Gaming Mode.

**For macOS:**
1. Download the `Linux_Tamriel_Trade_Center.sh` script.
2. Open the **Terminal** app and navigate to your download location (e.g., `cd ~/Downloads`).
3. Make it executable by typing: `chmod +x Linux_Tamriel_Trade_Center.sh`
4. Run it by typing: `./Linux_Tamriel_Trade_Center.sh`
5. Follow the interactive setup.

**For Windows:**
1. Download the `Windows_Tamriel_Trade_Center.bat` file.
2. Double-click the file to run it. 
3. Follow the interactive setup.

---

## ⚙️ Command Line Arguments & Launch Options

* **`--silent`**
  Hides the terminal window and suppresses all text output. Useful for running the script invisibly in the background.
* **`--auto`**
  Skips the interactive setup questions. It forces the script to run immediately using your saved configuration or defaults.
* **`--na`**
  Forces the script to download price data from the **North American (US)** Tamriel Trade Centre server.
* **`--eu`**
  Forces the script to download price data from the **European (EU)** Tamriel Trade Centre server.
* **`--loop`**
  Runs the updater continuously. It will update your data, wait for 60 minutes, and then update again as long as the script is open.
* **`--once`**
  Runs the updater exactly one time and then immediately closes the script. Good if you only want to update before you start playing and don't want it running in the background.
* **`--addon-dir "/path/to/folder"`**
  Manually overrides the auto detection and forces the script to use a specific folder for your AddOns. *(Example: `--addon-dir "/home/user/Documents/Elder Scrolls Online/live/AddOns"`)*.

---

## 📁 HOW IT WORKS & WHERE FILES GO

To keep your system clean, the script organizes its files directly inside your **Game Client Directory** (the folder containing `eso64.exe` or `eso.app`). 
* **The Script:** `Linux_Tamriel_Trade_Center.sh` (or the `.bat` file) is copied here so Steam can safely launch it.
* **Configuration:** `lttc_updater.conf` (or `.ini`) is saved here to remember your server, terminal preferences, and addon paths. (A backup is also saved to your system's global user config folder).
* **Tracking Files:** `lttc_last_download.txt`, `lttc_last_sale.txt`, and `lttc_esohub_tracker.txt` are created here to track 1 hour cooldowns and prevent spamming the servers.
* **Desktop Icon:** `ttc_icon.ico` is downloaded here to provide an icon for your desktop shortcut.
* **Steam Injection:** If you choose to automatically apply the Steam Launch commands, the script modifies your `localconfig.vdf` file located in your Steam "userdata" directory. It safely injects the launch arguments directly into the ESO AppID (`306130`) configuration.

> **NOTE:** To avoid rate-limits and "Too many requests" blocks, the background loop timer for downloading TTC data is strictly set to update a maximum of once every 60 minutes while your game is open. Uploads happen every loop which is also 60 minutes.

---

## 🔍 ADDITIONAL INFORMATION & DEFAULT PATHS

The script automatically scans your system for the following default Addon locations to speed up setup. If yours is not found, you can always enter it manually:

**Windows:**
> "C:\Users\%USERPROFILE%\Documents\Elder Scrolls Online\live\AddOns"

> "C:\Users\%USERPROFILE%\OneDrive\Documents\Elder Scrolls Online\live\AddOns"

**macOS:**
> "~/Documents/Elder Scrolls Online\live\AddOns"

**Steam Deck & Linux Native Steam:**
> "~/.local/share/Steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/"

> "~/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/"

**Flatpak Steam:**
> "~/.var/app/com.valvesoftware.Steam/.steam/root/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/"

**PortProton:**
> "~/PortProton/prefixes/DEFAULT/drive_c/users/steamuser/My Documents/Elder Scrolls Online/live/AddOns/"

**Lutris / Standard Wine / Bottles:**
> "~/Games/elder-scrolls-online/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns/"

> "~/.wine/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns/"

> "~/.var/app/com.usebottles.bottles/data/bottles/bottles/NAME-OF-YOUR-BOTTLE/drive_c/users/$USER/My Documents/Elder Scrolls Online/live/AddOns/"

---

<div align="center">

### 🐞 BUG REPORTS
If you encounter any issues, please submit a report here or at:
**[ESOUI Bug Portal](https://www.esoui.com/portal.php?id=360&a=listbugs)**

</div>
