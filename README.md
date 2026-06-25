# Fusion360 Linux Post Install Script
Unofficial helper script for running Autodesk Fusion 360 on Linux using Steam Proton

The post-install script:

- Finds an existing Fusion 360 install inside a Steam Proton prefix
- Copies that prefix to a stable location under ~/.local/share/fusion360-proton/compatdata
- Installs Microsoft Edge WebView2 Runtime into the stable prefix
- Copies WebView2 to C:\webview2 to avoid path/quoting issues
- Adds registry/environment fixes for WebView2 detection
- Creates a launcher at ~/.local/bin/fusion360-launch
- Creates an Autodesk sign-in URL handler for adsk://, adskidmgr://, and adsk.idmgr://
- Creates a desktop launcher for Fusion 360

**Requirements:**

- Linux Mint, Ubuntu, or a similar Debian-based distro
- Steam installed
- Proton Experimental installed through Steam
- curl
- rsync

**Install dependencies:**

```
sudo apt update
sudo apt install -y curl rsync
```

---

# Installation

## Step 1: Download Fusion Client Downloader

Download Fusion Client Downloader.exe from Autodesk:

https://www.autodesk.com/products/fusion-360/personal-form

On Linux, the Autodesk site may not show the Windows installer unless your browser user agent is set to Windows.

Do not place the installer in this repo.

---

## Step 2: Install Fusion through Steam Proton

- Open Steam.
- Add Fusion Client Downloader.exe as a non-Steam game.
- Right-click it in Steam and open Properties.
- Go to Compatibility.
- Enable Force the use of a specific Steam Play compatibility tool.
- Select Proton Experimental.
- Launch the downloader through Steam.
- Complete the Fusion 360 install.
- Close Fusion and the installer.

Do not remove the Steam entry yet.

---

## Step 3: Run the post-install script

From this repo:
```
chmod +x scripts/fusion360-postinstall-v2.sh
./scripts/fusion360-postinstall-v2.sh
```

The script will create:

```
~/.local/bin/fusion360-launch
~/.local/bin/fusion360-proton-url-handler
~/.local/share/fusion360-proton/compatdata
```
---

## Step 4: Launch Fusion

Run:

```
~/.local/bin/fusion360-launch
```

Fusion should launch through Proton with the WebView2 fixes applied.

---

## Step 5: Sign in

When Fusion opens, click Sign In.

Your browser may open an Autodesk login page. After logging in, click Open Product or Return to Product.

When your browser asks to open the external application or handler, allow it.

A sign-in error may appear even after sign-in succeeds. If Fusion shows your account and project hub, the login worked.

---

## Step 6: Optional Steam shortcut

After confirming the launcher works, you can add this file to Steam as a new non-Steam game:

~/.local/bin/fusion360-launch

For this new Steam shortcut:

- Do not force Proton compatibility
- Leave Steam launch options blank

The wrapper script already launches Proton correctly.

## Important warning

Do not delete the original Steam installer/Fusion entry until after the post-install script has copied the Proton prefix and ~/.local/bin/fusion360-launch has been tested.

The original Steam entry owns the original Proton prefix. Deleting that entry too early can delete the Fusion install.
