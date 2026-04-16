#!/bin/bash

# Linux Hamachi & Haguichi Installer
# This script installs Flatpak, Haguichi, and LogMeIn Hamachi.

set -e

# --- Utility Functions ---

echo_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

echo_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

echo_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo_error "Please run this script with sudo."
    exit 1
fi

# Detect Architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo_warn "Architecture $ARCH detected. This script is optimized for x86_64. 32-bit may fail if links are incorrect."
fi

# Detect Distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_LIKE=$ID_LIKE
else
    echo_error "Could not detect distribution. /etc/os-release missing."
    exit 1
fi

echo_info "Detected Distribution: $DISTRO"

# --- Step 1: Install Flatpak ---

echo_info "Installing Flatpak..."

case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|kali|parrot|raspbian)
        apt-get update
        apt-get install -y flatpak curl
        ;;
    fedora|nobara)
        dnf install -y flatpak curl
        ;;
    arch|manjaro|endeavouros)
        pacman -Sy --noconfirm flatpak curl
        ;;
    opensuse*|suse)
        zypper install -y flatpak curl
        ;;
    *)
        # Fallback to ID_LIKE
        if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
            apt-get update && apt-get install -y flatpak curl
        elif [[ "$DISTRO_LIKE" == *"fedora"* ]]; then
            dnf install -y flatpak curl
        elif [[ "$DISTRO_LIKE" == *"arch"* ]]; then
            pacman -Sy --noconfirm flatpak curl
        else
            echo_error "Unsupported distribution: $DISTRO. Please install Flatpak and Curl manually."
            exit 1
        fi
        ;;
esac

echo_success "Flatpak installed."

# --- Step 1.5: Software Center Integration ---

echo_info "Checking for Software Center integration..."
if command -v gnome-software >/dev/null 2>&1; then
    echo_info "GNOME Software detected, installing Flatpak plugin..."
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop|kali|parrot|raspbian) apt-get install -y gnome-software-plugin-flatpak || true ;;
        fedora|nobara) dnf install -y gnome-software-plugin-flatpak || true ;;
        arch|manjaro|endeavouros) pacman -S --noconfirm gnome-software-plugin-flatpak || true ;;
        opensuse*|suse) zypper install -y gnome-software-plugin-flatpak || true ;;
    esac
fi

if command -v plasma-discover >/dev/null 2>&1; then
    echo_info "KDE Discover detected, installing Flatpak plugin..."
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop|kali|parrot|raspbian) apt-get install -y plasma-discover-backend-flatpak || true ;;
        fedora|nobara) dnf install -y plasma-discover-backend-flatpak || true ;;
        arch|manjaro|endeavouros) pacman -S --noconfirm discover || true ;;
        opensuse*|suse) zypper install -y discover-backend-flatpak || true ;;
    esac
fi

# --- Step 2: Add Flathub and Install Haguichi ---

echo_info "Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo_info "Installing Haguichi (Flatpak)..."
# Using -y to auto-accept installation
flatpak install -y flathub com.github.ztefn.haguichi

echo_success "Haguichi installed."

# --- Step 3: Hamachi Installation ---

echo ""
echo "--------------------------------------------------"
echo "LogMeIn Hamachi Setup"
echo "1) I have already downloaded the installer (provide file path)"
echo "2) Let the script download and install Hamachi automatically"
echo "--------------------------------------------------"
read -p "Select an option [1-2]: " HAMACHI_OPT

# Create a temporary directory for downloads and work
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
INSTALL_FILE=""

echo_info "Using temporary directory: $WORK_DIR"

if [ "$HAMACHI_OPT" == "1" ]; then
    read -p "Enter the full path to the Hamachi installer file: " USER_FILE
    if [ -f "$USER_FILE" ]; then
        # Copy to work dir to ensure we can work with it (especially if it needs extraction)
        cp "$USER_FILE" "$WORK_DIR/"
        INSTALL_FILE="$WORK_DIR/$(basename "$USER_FILE")"
    else
        echo_error "File not found: $USER_FILE"
        exit 1
    fi
elif [ "$HAMACHI_OPT" == "2" ]; then
    echo_info "Downloading Hamachi..."
    VERSION="2.1.0.203-1"
    
    # Architecture check and URL selection
    if [[ "$DISTRO" == "fedora" || "$DISTRO" == "opensuse"* ]]; then
        URL="https://www.vpn.net/installers/logmein-hamachi-${VERSION}.x86_64.rpm"
        FILE_NAME="hamachi.rpm"
    elif [[ "$DISTRO" == "arch" || "$DISTRO" == "manjaro" ]]; then
        URL="https://www.vpn.net/installers/logmein-hamachi-${VERSION}-x86_64.tgz"
        FILE_NAME="hamachi.tgz"
    else
        URL="https://www.vpn.net/installers/logmein-hamachi_${VERSION}_amd64.deb"
        FILE_NAME="hamachi.deb"
    fi

    INSTALL_FILE="$WORK_DIR/$FILE_NAME"
    echo_info "Downloading from: $URL"
    curl -L "$URL" -o "$INSTALL_FILE"
else
    echo_error "Invalid option."
    exit 1
fi

# Install the downloaded/provided file
echo_info "Installing Hamachi package..."
if [[ "$INSTALL_FILE" == *.deb ]]; then
    apt-get install -y "$INSTALL_FILE" || (dpkg -i "$INSTALL_FILE" && apt-get install -f -y)
elif [[ "$INSTALL_FILE" == *.rpm ]]; then
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y "$INSTALL_FILE"
    else
        zypper install -y "$INSTALL_FILE"
    fi
elif [[ "$INSTALL_FILE" == *.tgz ]]; then
    mkdir -p "$WORK_DIR/hamachi_tmp"
    tar -xzf "$INSTALL_FILE" -C "$WORK_DIR/hamachi_tmp" --strip-components=1
    CURRENT_DIR=$(pwd)
    cd "$WORK_DIR/hamachi_tmp"
    ./install.sh
    cd "$CURRENT_DIR"
fi

echo_success "Hamachi installation attempted."

# --- Step 4: Service Setup ---

echo_info "Starting and enabling Hamachi service..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable logmein-hamachi
    systemctl start logmein-hamachi
    systemctl status logmein-hamachi --no-pager || echo_warn "Service did not start correctly, please check 'journalctl -u logmein-hamachi'"
else
    echo_warn "systemctl not found. Please start logmein-hamachi service manually."
fi

# --- Step 5: Application Desktop Entry ---

echo_info "Downloading Haguichi icon..."
curl -L "https://raw.githubusercontent.com/ztefn/haguichi/refs/heads/master/data/icons/hicolor-source.svg" -o /usr/share/pixmaps/haguichi.svg

echo_info "Creating desktop entry for Haguichi..."
DESKTOP_FILE="/usr/share/applications/haguichi.desktop"

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Haguichi
GenericName=Hamachi GUI
Comment=A graphical frontend for LogMeIn Hamachi
Exec=flatpak run com.github.ztefn.haguichi
Icon=/usr/share/pixmaps/haguichi.svg
Terminal=false
Categories=Network;GTK;
Keywords=hamachi;vpn;haguichi;
EOF

chmod 644 "$DESKTOP_FILE"
echo_success "Desktop entry created at $DESKTOP_FILE"

echo_info "Starting Automated Network Configuration..."

echo_info "Processing New Client..."
sleep 5
sudo hamachi login
sleep 2

# Set Nickname based on hostname and date so you can identify them in your logs
sudo hamachi set-nick "Player-$(hostname)-$(date +%m/%d/%y)"

# Define your list of networks here
NETWORKS=(
    "BudgetGamers01"
    "BudgetGamers02"
    "BudgetGamers03"
    "BudgetGamers04"
    "BudgetGamers05"
    "BudgetGamers06"
    "BudgetGamers07"
    "BudgetGamers08"
    "BudgetGamers09"
    "BudgetGamers10"
    "BudgetGamers11"
    "BudgetGamers12"
    "BudgetGamers13"
    "BudgetGamers14"
    "BudgetGamers15"
    "BudgetGamers16"
    "BudgetGamers17"
    "BudgetGamers18"
    "BudgetGamers19"
    "BudgetGamers20"
)

# The shared password for all networks
SHARED_PASS="BudgetGamers"

# --- Smart Joiner Loop ---
# This iterates through your list and stops as soon as it successfully joins one
JOINED=false
echo_info "Waiting 5 seconds before connecting to networks..."
sleep 5
for NETWORK_ID in "${NETWORKS[@]}"; do
    echo_info "Attempting to join network: $NETWORK_ID..."
    
    # Attempt to join and capture output (stdout + stderr)
    JOIN_RESULT=$(sudo hamachi join "$NETWORK_ID" "$SHARED_PASS" 2>&1 || true)
    
    # Check if we are actually in the network list now
    # -F for fixed string, -w for whole word to ensure exact match of ID
    if sudo hamachi list | grep -Fwq "$NETWORK_ID"; then
        sudo hamachi go-online "$NETWORK_ID"
        echo_success "Successfully joined $NETWORK_ID!"
        JOINED=true
        break
    else
        echo_warn "Could not join $NETWORK_ID. It may be full or unavailable."
        if [[ -n "$JOIN_RESULT" ]]; then
            echo "   Hamachi said: $JOIN_RESULT"
        fi
        echo_info "Trying next network..."
    fi
done

if [ "$JOINED" = false ]; then
    echo_error "Could not join any networks. They may all be full (5/5)."
fi

# Implement Broadcast Protection (The "Quest Fix")
# This prevents discovery 'pings' from saturating your 60yo home's upload
if command -v iptables >/dev/null 2>&1; then
    echo_info "Implementing broadcast block to protect bandwidth..."
    # Drop mDNS and SSDP discovery on the hamachi interface
    sudo iptables -A INPUT -i ham0 -p udp --dport 5353 -j DROP
    sudo iptables -A INPUT -i ham0 -p udp --dport 1900 -j DROP
    echo_success "Firewall rules applied (Quest discovery chatter blocked)."
fi

echo_success "Setup complete!"
echo_info "Haguichi is ready in your Applications menu."
echo_info "Your Hamachi IP is stable and will not change after reboots."