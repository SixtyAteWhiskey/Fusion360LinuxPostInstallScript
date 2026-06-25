#!/usr/bin/env bash
set -euo pipefail

echo "=== Fusion 360 Proton Post-Install v2 ==="
echo "This copies Fusion into a stable prefix so deleting the Steam installer entry won't break it."
echo

STEAM_CANDIDATES=(
  "$HOME/.steam/steam"
  "$HOME/.local/share/Steam"
  "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
)

STABLE_ROOT="$HOME/.local/share/fusion360-proton"
STABLE_COMPATDATA="$STABLE_ROOT/compatdata"

echo "[1/10] Closing Fusion/Proton leftovers..."
pkill -f Fusion360.exe 2>/dev/null || true
pkill -f AdskIdentityManager.exe 2>/dev/null || true
pkill -f msedgewebview2.exe 2>/dev/null || true
pkill -f wineserver 2>/dev/null || true
sleep 2

echo "[2/10] Finding Fusion360.exe inside Steam Proton prefixes..."

FUSION_RESULTS=()

for STEAMROOT in "${STEAM_CANDIDATES[@]}"; do
  if [ -d "$STEAMROOT/steamapps/compatdata" ]; then
    while IFS= read -r found; do
      FUSION_RESULTS+=("$found")
    done < <(find "$STEAMROOT/steamapps/compatdata" \
      -path "*/Autodesk/webdeploy/production/*/Fusion360.exe" \
      -type f 2>/dev/null)
  fi
done

if [ "${#FUSION_RESULTS[@]}" -eq 0 ]; then
  echo "ERROR: Could not find Fusion360.exe."
  echo "Install Fusion through Steam/Proton first, then run this script again."
  exit 1
fi

if [ "${#FUSION_RESULTS[@]}" -gt 1 ]; then
  echo "Multiple Fusion installs found:"
  select choice in "${FUSION_RESULTS[@]}"; do
    SOURCE_FUSION_EXE="$choice"
    break
  done
else
  SOURCE_FUSION_EXE="${FUSION_RESULTS[0]}"
fi

SOURCE_COMPATDATA="${SOURCE_FUSION_EXE%%/pfx/*}"
SOURCE_STEAMROOT="${SOURCE_COMPATDATA%/steamapps/compatdata/*}"

echo "Found Fusion:"
echo "$SOURCE_FUSION_EXE"
echo

echo "[3/10] Finding Proton..."

if [ -f "$SOURCE_STEAMROOT/steamapps/common/Proton - Experimental/proton" ]; then
  PROTON="$SOURCE_STEAMROOT/steamapps/common/Proton - Experimental/proton"
else
  PROTON="$(find "$SOURCE_STEAMROOT/compatibilitytools.d" "$SOURCE_STEAMROOT/steamapps/common" \
    -path "*/proton" -type f 2>/dev/null | sort -V | tail -n 1)"
fi

if [ -z "${PROTON:-}" ] || [ ! -f "$PROTON" ]; then
  echo "ERROR: Could not find Proton."
  echo "Install Proton Experimental in Steam first."
  exit 1
fi

echo "Using Proton:"
echo "$PROTON"
echo

echo "[4/10] Copying Steam Proton prefix to stable location..."
mkdir -p "$STABLE_ROOT"

if [ -d "$STABLE_COMPATDATA" ]; then
  echo "Existing stable Fusion prefix found. Backing it up..."
  mv "$STABLE_COMPATDATA" "$STABLE_COMPATDATA.backup.$(date +%Y%m%d-%H%M%S)"
fi

rsync -a --info=progress2 "$SOURCE_COMPATDATA/" "$STABLE_COMPATDATA/"

REL_FUSION_PATH="${SOURCE_FUSION_EXE#"$SOURCE_COMPATDATA/pfx/"}"
FUSION_EXE="$STABLE_COMPATDATA/pfx/$REL_FUSION_PATH"

echo "Stable Fusion path:"
echo "$FUSION_EXE"
echo

echo "[5/10] Finding Autodesk Identity Manager in stable prefix..."

IDENTITY_EXE="$(find "$(dirname "$FUSION_EXE")" "$STABLE_COMPATDATA/pfx" \
  -iname "AdskIdentityManager.exe" \
  -type f 2>/dev/null | head -n 1)"

if [ -z "$IDENTITY_EXE" ]; then
  echo "ERROR: Could not find AdskIdentityManager.exe."
  exit 1
fi

echo "Found Identity Manager:"
echo "$IDENTITY_EXE"
echo

echo "[6/10] Downloading Microsoft Edge WebView2 Runtime..."
mkdir -p "$HOME/Downloads/webview2"
WEBVIEW2_INSTALLER="$HOME/Downloads/webview2/MicrosoftEdgeWebView2RuntimeInstallerX64.exe"

curl -L -o "$WEBVIEW2_INSTALLER" \
  "https://go.microsoft.com/fwlink/?linkid=2124701"

echo "[7/10] Installing WebView2 into stable Fusion prefix..."

env \
  WINEDLLOVERRIDES="bcp47langs=" \
  STEAM_COMPAT_DATA_PATH="$STABLE_COMPATDATA" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$SOURCE_STEAMROOT" \
  "$PROTON" run "$WEBVIEW2_INSTALLER" /silent /install || true

sleep 5

WEBVIEW2_EXE="$(find "$STABLE_COMPATDATA/pfx" \
  -iname "msedgewebview2.exe" \
  -path "*/Microsoft/EdgeWebView/Application/*/msedgewebview2.exe" \
  -type f 2>/dev/null | sort -V | tail -n 1)"

if [ -z "$WEBVIEW2_EXE" ]; then
  echo "ERROR: WebView2 install did not appear to complete."
  exit 1
fi

WEBVIEW2_VERSION_DIR="$(dirname "$WEBVIEW2_EXE")"
WEBVIEW2_VERSION="$(basename "$WEBVIEW2_VERSION_DIR")"

echo "Found WebView2 version:"
echo "$WEBVIEW2_VERSION"
echo

echo "[8/10] Copying WebView2 to no-spaces path C:\\webview2..."

mkdir -p "$STABLE_COMPATDATA/pfx/drive_c/webview2"
rsync -a "$WEBVIEW2_VERSION_DIR/" "$STABLE_COMPATDATA/pfx/drive_c/webview2/"

if [ ! -f "$STABLE_COMPATDATA/pfx/drive_c/webview2/msedgewebview2.exe" ]; then
  echo "ERROR: Failed to copy WebView2 to C:\\webview2."
  exit 1
fi

echo "[9/10] Writing registry and environment fixes..."

REGFILE="$HOME/Downloads/webview2/fusion360-webview2-fix.reg"

cat > "$REGFILE" <<EOF
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}]
"name"="Microsoft Edge WebView2 Runtime"
"pv"="$WEBVIEW2_VERSION"

[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}]
"name"="Microsoft Edge WebView2 Runtime"
"pv"="$WEBVIEW2_VERSION"

[HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}]
"name"="Microsoft Edge WebView2 Runtime"
"pv"="$WEBVIEW2_VERSION"

[HKEY_CURRENT_USER\\Environment]
"WEBVIEW2_BROWSER_EXECUTABLE_FOLDER"="C:\\\\webview2"
"WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS"="--no-sandbox --disable-gpu"
EOF

env \
  STEAM_COMPAT_DATA_PATH="$STABLE_COMPATDATA" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$SOURCE_STEAMROOT" \
  "$PROTON" run regedit /S "$REGFILE"

echo "[10/10] Creating launcher and URL handler..."

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/applications"

LAUNCHER="$HOME/.local/bin/fusion360-launch"
URL_HANDLER="$HOME/.local/bin/fusion360-proton-url-handler"

cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash

COMPATDATA="$STABLE_COMPATDATA"
STEAMROOT="$SOURCE_STEAMROOT"
PROTON="$PROTON"
FUSION_EXE="$FUSION_EXE"

env \\
WEBVIEW2_BROWSER_EXECUTABLE_FOLDER="C:\\\\webview2" \\
WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox --disable-gpu" \\
WINEDLLOVERRIDES="bcp47langs=" \\
STEAM_COMPAT_DATA_PATH="\$COMPATDATA" \\
STEAM_COMPAT_CLIENT_INSTALL_PATH="\$STEAMROOT" \\
"\$PROTON" run "\$FUSION_EXE"
EOF

chmod +x "$LAUNCHER"

cat > "$URL_HANDLER" <<EOF
#!/usr/bin/env bash

URL="\$1"

COMPATDATA="$STABLE_COMPATDATA"
STEAMROOT="$SOURCE_STEAMROOT"
PROTON="$PROTON"
IDENTITY_EXE="$IDENTITY_EXE"

echo "\$(date) - URL received: \$URL" >> "\$HOME/fusion360-url-handler.log"

env \\
WEBVIEW2_BROWSER_EXECUTABLE_FOLDER="C:\\\\webview2" \\
WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--no-sandbox --disable-gpu" \\
WINEDLLOVERRIDES="bcp47langs=" \\
STEAM_COMPAT_DATA_PATH="\$COMPATDATA" \\
STEAM_COMPAT_CLIENT_INSTALL_PATH="\$STEAMROOT" \\
"\$PROTON" run "\$IDENTITY_EXE" "\$URL"
EOF

chmod +x "$URL_HANDLER"

cat > "$HOME/.local/share/applications/fusion360.desktop" <<EOF
[Desktop Entry]
Name=Autodesk Fusion 360
Exec=$LAUNCHER
Type=Application
Terminal=false
Categories=Graphics;Engineering;
StartupNotify=true
EOF

cat > "$HOME/.local/share/applications/fusion360-proton-url-handler.desktop" <<EOF
[Desktop Entry]
Name=Fusion 360 Proton URL Handler
Exec=$URL_HANDLER %u
Type=Application
Terminal=false
NoDisplay=true
MimeType=x-scheme-handler/adsk;x-scheme-handler/adskidmgr;x-scheme-handler/adsk.idmgr;
EOF

xdg-mime default fusion360-proton-url-handler.desktop x-scheme-handler/adsk
xdg-mime default fusion360-proton-url-handler.desktop x-scheme-handler/adskidmgr
xdg-mime default fusion360-proton-url-handler.desktop x-scheme-handler/adsk.idmgr

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo
echo "=== Done ==="
echo
echo "Stable prefix:"
echo "$STABLE_COMPATDATA"
echo
echo "Launch Fusion with:"
echo "$LAUNCHER"
echo
echo "You can now add this launcher script to Steam if you want:"
echo "$LAUNCHER"
echo
echo "Important: Leave Steam launch options blank and do not force Proton on the wrapper script."
echo
echo "After confirming the launcher works, you may remove the original Steam installer entry."
