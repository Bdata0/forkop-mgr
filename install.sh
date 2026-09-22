#!/bin/sh

# ============================================================
# Forkop Control Center installer
# ============================================================

REPO="Bdata0/forkop-mgr"

RAW_URL="https://raw.githubusercontent.com/${REPO}/main/forkop-mgr"

DEST="/usr/bin/forkop-mgr"

TMP="/tmp/forkop-mgr-install.$$"

BACKUP="/usr/bin/forkop-mgr.backup.$(date +%Y%m%d_%H%M%S)"


cleanup() {
    rm -f "$TMP"
}

trap cleanup EXIT INT TERM


# ============================================================
# Helpers
# ============================================================

forkop_running() {

    if [ -x /etc/init.d/forkop ]; then

        if /etc/init.d/forkop status >/dev/null 2>&1; then
            return 0
        fi
    fi


    if command -v pidof >/dev/null 2>&1; then

        if pidof forkop >/dev/null 2>&1; then
            return 0
        fi
    fi


    return 1
}


wt0_up() {
    ip addr show wt0 2>/dev/null | grep -q 'inet '
}


wait_wt0() {

    i=0

    while [ "$i" -lt 30 ]; do

        if wt0_up; then
            return 0
        fi

        sleep 1

        i=$((i + 1))
    done

    return 1
}


restore_forkop() {

    if [ -x /etc/init.d/netbird ]; then

        if ! wt0_up; then
            /etc/init.d/netbird restart >/dev/null 2>&1 || true
            wait_wt0 || true
        fi
    fi


    if [ -x /etc/init.d/forkop ]; then

        /etc/init.d/forkop restart \
            >/dev/null 2>&1 || true
    fi
}


github_test() {

    if command -v curl >/dev/null 2>&1; then

        curl -4 \
            -fsS \
            -I \
            -H "User-Agent: forkop-mgr-installer" \
            --connect-timeout 8 \
            --max-time 12 \
            https://raw.githubusercontent.com/ \
            >/dev/null 2>&1

        return $?
    fi


    if command -v wget >/dev/null 2>&1; then

        wget -4 \
            -q \
            -O /dev/null \
            --timeout=10 \
            https://raw.githubusercontent.com/ \
            >/dev/null 2>&1

        return $?
    fi


    echo "ERROR: curl or wget is required."

    return 1
}


download_file() {

    url="$1"
    output="$2"


    if command -v curl >/dev/null 2>&1; then

        curl -4 \
            -fL \
            -H "User-Agent: forkop-mgr-installer" \
            --connect-timeout 20 \
            --max-time 180 \
            "$url" \
            -o "$output"

        return $?
    fi


    if command -v wget >/dev/null 2>&1; then

        wget -4 \
            --timeout=30 \
            -O "$output" \
            "$url"

        return $?
    fi


    return 1
}


# ============================================================
# Start
# ============================================================

echo ""
echo "========================================================"
echo "        Forkop Control Center Installer"
echo "========================================================"
echo ""
echo "Repository:"
echo "https://github.com/${REPO}"
echo ""


# ============================================================
# Check existing Forkop state
# ============================================================

FORKOP_WAS_RUNNING=0

if forkop_running; then
    FORKOP_WAS_RUNNING=1
fi


# ============================================================
# GitHub test
# ============================================================

echo "[1/5] Checking direct GitHub access..."


if github_test; then

    echo "GitHub: OK"

else

    if [ "$FORKOP_WAS_RUNNING" = "1" ]; then

        echo ""
        echo "GitHub is unreachable while Forkop is active."
        echo ""
        echo "Temporarily stopping Forkop..."
        echo ""

        if [ -x /etc/init.d/forkop ]; then
            /etc/init.d/forkop stop >/dev/null 2>&1 || true
        fi

        sleep 2

    fi


    if ! github_test; then

        echo ""
        echo "ERROR: GitHub is still unreachable."
        echo ""
        echo "Please check WAN connectivity."
        echo ""

        if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
            restore_forkop
        fi

        exit 1
    fi


    echo "GitHub: OK (direct WAN after stopping Forkop)"

fi


# ============================================================
# Download
# ============================================================

echo ""
echo "[2/5] Downloading forkop-mgr..."
echo ""


rm -f "$TMP"


if ! download_file "$RAW_URL" "$TMP"; then

    echo ""
    echo "ERROR: failed to download:"
    echo "$RAW_URL"
    echo ""

    if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
        restore_forkop
    fi

    exit 1
fi


if [ ! -s "$TMP" ]; then

    echo ""
    echo "ERROR: downloaded file is empty."

    if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
        restore_forkop
    fi

    exit 1
fi


# ============================================================
# Validate
# ============================================================

echo ""
echo "[3/5] Validating downloaded script..."
echo ""


FIRST_LINE="$(head -n 1 "$TMP" 2>/dev/null)"


if [ "$FIRST_LINE" != "#!/bin/sh" ]; then

    echo "ERROR: downloaded file is not a valid shell script."

    echo ""
    echo "First line:"
    echo "$FIRST_LINE"
    echo ""

    if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
        restore_forkop
    fi

    exit 1
fi


if ! sh -n "$TMP"; then

    echo ""
    echo "ERROR: shell syntax validation failed."

    if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
        restore_forkop
    fi

    exit 1
fi


# ============================================================
# Backup current manager
# ============================================================

echo ""
echo "[4/5] Installing atomically..."
echo ""


if [ -f "$DEST" ]; then

    echo "Backing up current manager:"
    echo "$BACKUP"

    if ! cp -f "$DEST" "$BACKUP"; then

        echo ""
        echo "ERROR: cannot backup current manager."

        if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
            restore_forkop
        fi

        exit 1
    fi
fi


# ============================================================
# Install
# ============================================================

if ! cp -f "$TMP" "$DEST"; then

    echo ""
    echo "ERROR: cannot install $DEST"

    if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
        restore_forkop
    fi

    exit 1
fi


chmod +x "$DEST"


# ============================================================
# Validate installed file
# ============================================================

if ! sh -n "$DEST"; then

    echo ""
    echo "ERROR: installed file failed validation."
    echo "Restoring previous version..."

    if [ -f "$BACKUP" ]; then

        cp -f "$BACKUP" "$DEST"
        chmod +x "$DEST"

    else

        rm -f "$DEST"

    fi


    if [ "$FORKOP_WAS_RUNNING" = "1" ]; then
        restore_forkop
    fi

    exit 1
fi


# ============================================================
# Restore Forkop
# ============================================================

echo ""
echo "[5/5] Restoring services..."
echo ""


if [ "$FORKOP_WAS_RUNNING" = "1" ]; then

    restore_forkop

    echo "Forkop service restored."

else

    echo "Forkop was not running before installation."
    echo "It was left stopped."

fi


# ============================================================
# Done
# ============================================================

echo ""
echo "========================================================"
echo " Installation completed successfully!"
echo "========================================================"
echo ""
echo "Run:"
echo ""
echo "  forkop-mgr"
echo ""


if [ -f "$BACKUP" ]; then

    echo "Previous manager backup:"
    echo ""
    echo "  $BACKUP"
    echo ""

fi
