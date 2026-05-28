#!/bin/bash
# XRoboToolkit PC Service — Master Setup & Launch
#
# Can be run from two locations:
#   1. Source root  (here): builds & installs the deb, then launches
#   2. Install dir  (/opt/apps/roboticsservice/): checks prereqs, then launches
#
# Usage:
#   ./setup.sh          # check/fix without sudo, launch if OK
#   ./setup.sh y        # allow sudo: apt installs, deb install, firewall rules

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ── Detect mode: source tree vs install dir ──────────────────────────────────
INSTALL_DIR="/opt/apps/roboticsservice"
SOURCE_ROOT=""
if [[ -f "$SCRIPT_DIR/RoboticsService/qt-gcc.sh" ]]; then
    SOURCE_ROOT="$SCRIPT_DIR"                    # running from source root
elif [[ -f "$SCRIPT_DIR/RoboticsServiceProcess" ]]; then
    INSTALL_DIR="$SCRIPT_DIR"                    # running from install dir
fi

LIB_DIR="$INSTALL_DIR/lib"
QML_DIR="$INSTALL_DIR/qml"
PLUGINS_DIR="$INSTALL_DIR/plugins"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

USE_SUDO=0
[[ "${1:-}" == "y" || "${1:-}" == "--sudo" || "${1:-}" == "-s" ]] && USE_SUDO=1

ERRORS=0; WARNINGS=0; FIXES=0

_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; WARNINGS=$((WARNINGS+1)); }
_error()   { echo -e "${RED}[ERROR]${NC} $*"; ERRORS=$((ERRORS+1)); }
_fixed()   { echo -e "${GREEN}[FIXED]${NC} $*"; FIXES=$((FIXES+1)); }
_sudo_hint() { echo -e "${YELLOW}        → Re-run with: ${BOLD}./setup.sh y${NC}"; }
_section() { echo ""; echo -e "${BOLD}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

_copy() {
    local src="$1" dst="$2"
    if [[ -w "$dst" ]]; then cp -P "$src" "$dst"
    elif [[ $USE_SUDO -eq 1 ]]; then sudo cp -P "$src" "$dst"
    else return 1; fi
}
_copy_dir() {
    local src="$1" dst="$2"
    if [[ -w "$(dirname "$dst")" ]]; then cp -rP "$src" "$dst"
    elif [[ $USE_SUDO -eq 1 ]]; then sudo cp -rP "$src" "$dst"
    else return 1; fi
}

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       XRoboToolkit PC Service — Setup & Launch           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
if [[ -n "$SOURCE_ROOT" ]]; then
    echo -e "  Source: ${CYAN}$SOURCE_ROOT${NC}"
fi
echo -e "  Install: ${CYAN}$INSTALL_DIR${NC}"
[[ $USE_SUDO -eq 1 ]] && echo -e "  Mode: ${GREEN}sudo enabled${NC}" \
                       || echo -e "  Mode: non-sudo  (run ${BOLD}./setup.sh y${NC} to allow installs)"

# ──────────────────────────────────────────────────────────────────────────────
_section "1. Qt 6.6.x"
# ──────────────────────────────────────────────────────────────────────────────
QT_BASE=""
for candidate in \
        "$HOME/Qt6/6.6.3/gcc_64" \
        "$HOME/Qt/6.6.3/gcc_64" \
        "/opt/Qt/6.6.3/gcc_64" \
        "/usr/local/Qt-6.6.3"; do
    if [[ -d "$candidate/lib" && -f "$candidate/lib/libQt6Core.so.6" ]]; then
        QT_BASE="$candidate"
        _ok "Found Qt 6.6.3 at: $QT_BASE"
        break
    fi
done

if [[ -z "$QT_BASE" ]]; then
    _warn "Qt 6.6.3 not found — cannot auto-copy missing Qt libs"
    echo    "        Install via aqtinstall:"
    echo    "          pip install aqtinstall"
    echo    "          aqt install-qt linux desktop 6.6.3 gcc_64 \\"
    echo    "            -m qtmultimedia qtshadertools qt5compat --outputdir ~/Qt6"
fi

# ──────────────────────────────────────────────────────────────────────────────
_section "2. Application install"
# ──────────────────────────────────────────────────────────────────────────────
APP_INSTALLED=0
[[ -f "$INSTALL_DIR/RoboticsServiceProcess" ]] && APP_INSTALLED=1

if [[ $APP_INSTALLED -eq 1 ]]; then
    APP_VER=$(dpkg -l roboticsservice 2>/dev/null | awk '/^ii/{print $3}' || echo "unknown")
    _ok "Application installed (version: $APP_VER)"
else
    _warn "Application not installed at $INSTALL_DIR"
    if [[ -n "$SOURCE_ROOT" ]]; then
        if [[ $USE_SUDO -eq 1 ]]; then
            if [[ -z "$QT_BASE" ]]; then
                _error "Qt 6.6.3 required to build — install it first (see section 1)"
            else
                _info "Building deb from source ..."
                cd "$SOURCE_ROOT/RoboticsService"

                # Patch qt-gcc.sh to use the local Qt install if path differs
                QT_GCC_IN_SCRIPT=$(grep "^QT_GCC_64=" qt-gcc.sh | cut -d= -f2 | tr -d '"' || true)
                if [[ "$QT_GCC_IN_SCRIPT" != "$QT_BASE" && -n "$QT_GCC_IN_SCRIPT" ]]; then
                    _info "Patching qt-gcc.sh: QT_GCC_64 → $QT_BASE"
                    sed -i "s|^QT_GCC_64=.*|QT_GCC_64=$QT_BASE|" qt-gcc.sh
                fi

                ./qt-gcc.sh 1 && _info "Build succeeded" || { _error "Build failed — check output above"; exit 1; }

                cd Package/debPack
                ./setup.sh && _info "Package built" || { _error "Packaging failed"; exit 1; }

                DEB=$(ls "$SOURCE_ROOT/RoboticsService/Package/output/"*.deb 2>/dev/null | sort -V | tail -1)
                if [[ -z "$DEB" ]]; then
                    _error "No deb found in Package/output/"
                    exit 1
                fi
                _info "Installing: $DEB"
                sudo dpkg -i "$DEB" && sudo apt-get install -f -y
                _fixed "Application installed"
                APP_INSTALLED=1
                cd "$SOURCE_ROOT"
            fi
        else
            echo "        Run ${BOLD}./setup.sh y${NC} to build and install automatically"
            _sudo_hint
            ERRORS=$((ERRORS+1))
        fi
    else
        _error "Install the application first:"
        echo    "        sudo dpkg -i XRoboToolkit-PC-Service_*.deb"
        echo    "        Or clone the source and run: ./setup.sh y"
    fi
fi

# Abort early if app still not installed — remaining checks need it
if [[ $APP_INSTALLED -eq 0 ]]; then
    echo ""
    echo -e "  ${RED}✖ Application not installed — cannot continue.${NC}"
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
_section "3. Bundled Qt libraries"
# ──────────────────────────────────────────────────────────────────────────────
REQUIRED_QT_LIBS=(
    libQt6Core.so.6
    libQt6Gui.so.6
    libQt6Network.so.6
    libQt6DBus.so.6
    libQt6OpenGL.so.6
    libQt6XcbQpa.so.6
    libQt6Qml.so.6
    libQt6QmlModels.so.6
    libQt6QmlWorkerScript.so.6
    libQt6QmlCore.so.6
    libQt6QmlCompiler.so.6
    libQt6Quick.so.6
    libQt6QuickControls2.so.6
    libQt6QuickTemplates2.so.6
    libQt6ShaderTools.so.6
    libQt6Multimedia.so.6
    libQt6MultimediaQuick.so.6
)

MISSING_QT_LIBS=()
for lib in "${REQUIRED_QT_LIBS[@]}"; do
    [[ ! -f "$LIB_DIR/$lib" ]] && MISSING_QT_LIBS+=("$lib")
done

if [[ ${#MISSING_QT_LIBS[@]} -eq 0 ]]; then
    _ok "All required Qt libs present in lib/"
else
    if [[ -n "$QT_BASE" ]]; then
        _info "Copying ${#MISSING_QT_LIBS[@]} missing Qt lib(s) from $QT_BASE/lib ..."
        for lib in "${MISSING_QT_LIBS[@]}"; do
            base="${lib%.so.*}"
            files=("$QT_BASE/lib/${base}".so*)
            if [[ ${#files[@]} -gt 0 && -e "${files[0]}" ]]; then
                copied=0
                for f in "${files[@]}"; do
                    _copy "$f" "$LIB_DIR/" 2>/dev/null && copied=1
                done
                [[ $copied -eq 1 ]] && _fixed "Installed: $lib" \
                    || { _error "Cannot write to $LIB_DIR"; _sudo_hint; }
            else
                _error "Not found in Qt install: $lib"
            fi
        done
    else
        for lib in "${MISSING_QT_LIBS[@]}"; do
            _error "Missing: $LIB_DIR/$lib  (Qt 6.6.3 required to auto-fix)"
        done
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
_section "4. XCB platform plugin"
# ──────────────────────────────────────────────────────────────────────────────
XCB_PLUGIN="$PLUGINS_DIR/platforms/libqxcb.so"
if [[ -f "$XCB_PLUGIN" ]]; then
    SYSTEM_QT=$(LD_LIBRARY_PATH="$INSTALL_DIR:$LIB_DIR:$INSTALL_DIR/SDK/x64" \
        ldd "$XCB_PLUGIN" 2>/dev/null \
        | grep "Qt6" | grep -v "$LIB_DIR" | grep -v "not found" || true)
    if [[ -z "$SYSTEM_QT" ]]; then
        _ok "XCB plugin: all Qt6 deps resolve to bundled lib/"
    else
        _error "XCB plugin resolves Qt6 from system (version mismatch will crash):"
        echo "$SYSTEM_QT" | sed 's/^/        /'
    fi
else
    _warn "XCB platform plugin not found: $XCB_PLUGIN"
fi

# ──────────────────────────────────────────────────────────────────────────────
_section "5. System packages"
# ──────────────────────────────────────────────────────────────────────────────
if dpkg -l libxcb-cursor0 2>/dev/null | grep -q '^ii'; then
    _ok "libxcb-cursor0 installed"
else
    _warn "libxcb-cursor0 not installed (required by Qt 6.5+ xcb plugin)"
    if [[ $USE_SUDO -eq 1 ]]; then
        sudo apt-get install -y libxcb-cursor0 && _fixed "Installed libxcb-cursor0" \
            || _error "apt install failed — run: sudo apt-get install libxcb-cursor0"
    else
        echo "        Fix: sudo apt-get install libxcb-cursor0"
        _sudo_hint
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
_section "6. QML modules"
# ──────────────────────────────────────────────────────────────────────────────
for mod in QtQml QtQuick QtMultimedia; do
    if [[ -d "$QML_DIR/$mod" ]]; then
        _ok "QML module present: $mod"
    else
        if [[ -n "$QT_BASE" && -d "$QT_BASE/qml/$mod" ]]; then
            _copy_dir "$QT_BASE/qml/$mod" "$QML_DIR/$mod" 2>/dev/null \
                && _fixed "Installed QML module: $mod" \
                || { _error "Cannot write to $QML_DIR"; _sudo_hint; }
        else
            _warn "Missing QML module: $mod"
            [[ -z "$QT_BASE" ]] && echo "        (requires Qt 6.6.3 to auto-fix)"
        fi
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
_section "7. Display / X11"
# ──────────────────────────────────────────────────────────────────────────────
if [[ -z "${DISPLAY:-}" ]]; then
    _warn "DISPLAY not set — defaulting to :0"
    export DISPLAY=:0
else
    _ok "DISPLAY=$DISPLAY"
fi

if xdpyinfo >/dev/null 2>&1; then
    DISPLAY_RES=$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2}' | head -1)
    _ok "X display accessible — desktop: ${DISPLAY_RES:-unknown}"
else
    _error "Cannot connect to X display ($DISPLAY) — must run inside a graphical session"
fi

# SDL must use X11 backend — required for correct window info on Optimus/X11
export SDL_VIDEODRIVER=x11

# ──────────────────────────────────────────────────────────────────────────────
_section "8. GPU / NVIDIA PRIME"
# ──────────────────────────────────────────────────────────────────────────────
if command -v nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)
    _ok "NVIDIA GPU: ${GPU_NAME:-unknown}"

    PRIME_ACTIVE=0
    if command -v prime-select &>/dev/null; then
        PRIME_MODE=$(prime-select query 2>/dev/null || true)
        _info "PRIME mode: ${PRIME_MODE:-unknown}"
        [[ "$PRIME_MODE" == "on-demand" || "$PRIME_MODE" == "intel" ]] && PRIME_ACTIVE=1
    fi

    if [[ $PRIME_ACTIVE -eq 1 ]]; then
        _info "Optimus/PRIME: enabling NVIDIA render offload for Unity"
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
    fi

    command -v vulkaninfo &>/dev/null && \
        vulkaninfo --summary 2>/dev/null | grep -q "NVIDIA" && _ok "Vulkan: NVIDIA driver active"
else
    _info "No NVIDIA GPU detected"
fi

# ──────────────────────────────────────────────────────────────────────────────
_section "9. Binary dependencies"
# ──────────────────────────────────────────────────────────────────────────────
LD_CHECK="$INSTALL_DIR:$LIB_DIR:$INSTALL_DIR/SDK/x64"

_check_bin() {
    local bin="$1" label="$2"
    [[ ! -f "$bin" ]] && { _warn "$label not found: $bin"; return; }
    local missing
    missing=$(LD_LIBRARY_PATH="$LD_CHECK" ldd "$bin" 2>/dev/null | grep "not found" || true)
    [[ -z "$missing" ]] && _ok "$label: all libs resolved" \
        || { _error "$label missing:"; echo "$missing" | sed 's/^/        /'; }
}

_check_bin "$INSTALL_DIR/RoboticsServiceProcess" "RoboticsServiceProcess"
_check_bin "$INSTALL_DIR/SDKDemo/RobotUnityDemo/RobotLinuxDemo.x86_64" "Unity demo"

XCB_MISSING=$(LD_LIBRARY_PATH="$LD_CHECK" ldd "$XCB_PLUGIN" 2>/dev/null | grep "not found" || true)
[[ -n "$XCB_MISSING" ]] && { _error "XCB plugin unresolved:"; echo "$XCB_MISSING" | sed 's/^/        /'; }

# ──────────────────────────────────────────────────────────────────────────────
_section "10. Network / firewall"
# ──────────────────────────────────────────────────────────────────────────────
SETTING_INI="$INSTALL_DIR/setting.ini"
if [[ -f "$SETTING_INI" ]]; then
    grep -q "listenAddr=0.0.0.0" "$SETTING_INI" \
        && _ok "setting.ini: listenAddr=0.0.0.0" \
        || { _warn "setting.ini: listenAddr not set to 0.0.0.0 — device discovery may fail"; \
             echo "        Fix: set 'listenAddr=0.0.0.0' in $SETTING_INI"; }
else
    _warn "setting.ini not found"
fi

if command -v ufw &>/dev/null; then
    UFW_ENABLED=$(grep -s "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null && echo "yes" || echo "no")
    if [[ "$UFW_ENABLED" == "yes" ]]; then
        _info "UFW enabled — checking ports ..."
        UFW_RULES=$(cat /etc/ufw/user.rules /etc/ufw/user6.rules 2>/dev/null || true)
        PORTS_OK=1
        for port_proto in "29888/udp" "63901/tcp" "60061/tcp"; do
            port="${port_proto%/*}"; proto="${port_proto#*/}"
            if ! echo "$UFW_RULES" | grep -qiE "dport ${port}[^0-9]"; then
                PORTS_OK=0
                if [[ $USE_SUDO -eq 1 ]]; then
                    sudo ufw allow "$port_proto" comment "PXREA" 2>/dev/null \
                        && _fixed "Opened: $port_proto" || _warn "Could not open $port_proto"
                else
                    _warn "UFW may block port $port_proto"
                fi
            fi
        done
        [[ $PORTS_OK -eq 1 ]] && _ok "Firewall: required ports open"
        [[ $PORTS_OK -eq 0 && $USE_SUDO -eq 0 ]] && {
            echo "        Fix: sudo ufw allow 29888/udp 63901/tcp 60061/tcp"
            _sudo_hint
        }
    else
        _ok "UFW inactive"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
_section "Summary"
# ──────────────────────────────────────────────────────────────────────────────
echo ""
[[ $FIXES    -gt 0 ]] && echo -e "  ${GREEN}✔ $FIXES fix(es) applied${NC}"
[[ $WARNINGS -gt 0 ]] && echo -e "  ${YELLOW}⚠ $WARNINGS warning(s)${NC}"
[[ $ERRORS   -gt 0 ]] && echo -e "  ${RED}✖ $ERRORS error(s) — resolve before launching${NC}"

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo -e "  Resolve the errors above, then re-run ${BOLD}./setup.sh${NC}"
    [[ $USE_SUDO -eq 0 ]] && echo -e "  Many issues can be auto-fixed with: ${BOLD}./setup.sh y${NC}"
    exit 1
fi

echo ""
_info "All checks passed — launching XRoboToolkit PC Service ..."
echo ""

export LD_LIBRARY_PATH="$INSTALL_DIR:$LIB_DIR:$INSTALL_DIR/SDK/x64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$PLUGINS_DIR/:${QT_PLUGIN_PATH:-}"
export QT_QML_PATH="$QML_DIR/:${QT_QML_PATH:-}"

exec "$INSTALL_DIR/run3D.sh"
