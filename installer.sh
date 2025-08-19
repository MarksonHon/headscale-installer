#!/usr/bin/env sh

set -e

# Colors of outputs
if command -v tput >/dev/null; then
    color_red=$(tput setaf 1)
    color_green=$(tput setaf 2)
    color_yellow=$(tput setaf 3)
    color_reset=$(tput sgr0)
fi
echo_red() {
    echo "$color_red""$1""$color_reset"
}
echo_green() {
    echo "$color_green""$1""$color_reset"
}
echo_yellow() {
    echo "$color_yellow""$1""$color_reset"
}

# Check if the script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo_red "Please run this script as root, or using sudo."
    exit 1
fi

# Check if the script is running on a supported OS
if [ "$(uname -s)" = Linux ]; then
    CURRENT_OS=linux
    case $(uname -m) in
    "x86_64")
        ARCH="amd64"
        ;;
    "armv7l")
        ARCH="armv7"
        ;;
    "aarch64")
        ARCH="arm64"
        ;;
    "i386" | "i686")
        ARCH="386"
        ;;
    *)
        echo_red "Unsupported architecture: $(uname -m) on $(uname -s)"
        exit 1
        ;;
    esac
elif [ "$(uname -s)" = Darwin ]; then
    CURRENT_OS=darwin
    case $(uname -m) in
    "x86_64")
        ARCH="amd64"
        ;;
    "arm64" | "aarch64" | "arm64e")
        ARCH="arm64"
        ;;
    *)
        echo_red "Unsupported architecture: $(uname -m) on $(uname -s)"
        exit 1
        ;;
    esac
elif [ "$(uname -s)" = FreeBSD ]; then
    CURRENT_OS=freebsd
    case $(uname -m) in
    "amd64")
        ARCH="amd64"
        ;;
    *)
        echo_red "Unsupported architecture: $(uname -m) on $(uname -s)"
        exit 1
        ;;
    esac
else
    echo_red "Unsupported OS: $(uname -s)"
    exit 1
fi

# Check HASH command define
if command -v openssl >/dev/null 2>&1; then
    check_sha256sum() {
        openssl dgst -sha256 "$1" | awk -F ' ' '{print$2}'
    }
elif command -v sha256sum >/dev/null 2>&1; then
    check_sha256sum() {
        sha256sum "$1" | awk -F ' ' '{print$1}'
    }
elif command -v shasum >/dev/null 2>&1; then
    check_sha256sum() {
        shasum -a 256 "$1" | awk -F ' ' '{print$1}'
    }
elif command -v busybox >/dev/null 2>&1 && (busybox --list | grep -w "sha256sum"); then
    check_sha256sum() {
        busybox sha256sum "$1" | awk -F ' ' '{print$1}'
    }
else
    echo_red "We cannot find any tool to check the SHA256 hash of the downloaded file,"
    echo_red "Please install busybox, openssl, sha256sum, or shasum and try again."
    exit 1
fi

# Check cURL
if ! command -v curl >/dev/null 2>&1; then
    echo_red "Please install curl and try again."
    exit 1
fi

# Check Local Headscale version
check_local_version() {
    if [ -f /usr/local/bin/headscale ]; then
        LOCAL_VERSION="v$(/usr/local/bin/headscale version)"
    else
        LOCAL_VERSION="v0.0.0"
    fi
}

# Check Remote Headscale version
check_remote_version() {
    temp_file=$(mktemp) || (
        echo_red "Failed to visit TEMP dir, exits."
        exit 1
    )
    if [ "$INSTALL_BETA" = true ]; then
        if ! curl -s https://api.github.com/repos/juanfont/headscale/tags -o "$temp_file"; then
            echo_red "Failed to fetch the latest version of headscale."
            exit 1
        fi
        REMOTE_VERSION=$(grep '"name": ' <$temp_file | head -n 1 | awk -F ':' '{print $2}' | awk -F '"' '{print $2}')
        rm -f "$temp_file"
    else
        if ! curl -s https://api.github.com/repos/juanfont/headscale/releases/latest -o "$temp_file"; then
            echo_red "Failed to fetch the latest version of headscale."
            exit 1
        fi
        REMOTE_VERSION="$(awk -F "tag_name" '{printf $2}' <"$temp_file" | awk -F "," '{printf $1}' | awk -F '"' '{printf $3}')"
        rm -f "$temp_file"
    fi
}

# Compare Local and Remote Headscale version
compare_version() {
    if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
        echo_green "You are using the latest version of headscale."
        echo_green "Current version: $LOCAL_VERSION"
        exit 0
    elif [ "$(printf '%s\n' "$$LOCAL_VERSION" "$REMOTE_VERSION" | sort -rV | head -n1)" = "$$LOCAL_VERSION" ]; then
        echo_yellow "You are using a newer version of headscale than GitHub release,"
        echo_yellow "we are currently unable to downgrade it yet, please remove it"
        echo_yellow "if you want to reinstall the latest version."
        exit 0
    else
        echo_yellow "A new version of headscale is available."
        if [ "$LOCAL_VERSION" = "v0.0.0" ]; then
            echo_yellow "You are no headscale installed."
        else
            echo_yellow "Local version: $LOCAL_VERSION"
        fi
        echo_yellow "Remote version: $REMOTE_VERSION"
    fi
}

# Download headscale
download_headscale() {
    remote_version_lite=$(echo "$REMOTE_VERSION" | awk -F "v" '{print $2}')
    download_url="https://github.com/juanfont/headscale/releases/download/""$REMOTE_VERSION"/headscale_"$remote_version_lite"_"$CURRENT_OS"_"$ARCH"
    temp_file=$(mktemp) || (
        echo_red "Failed to visit TEMP dir, exits."
        exit 1
    )
    echo_green "Downloading headscale..."
    echo_green "Download URL: $download_url"
    if ! curl -L -# "$download_url" -o "$temp_file"; then
        echo_red "Failed to download headscale, read the error message above"
        echo_red "of curl and try again if it's a network issue."
        exit 1
    fi
    hash_temp_file=$(mktemp) || (
        echo_red "Failed to visit TEMP dir, exits."
        exit 1
    )
    if ! curl -sL https://github.com/juanfont/headscale/releases/download/"$REMOTE_VERSION"/checksums.txt -o "$hash_temp_file"; then
        echo_red "Failed to download checksums.txt, read the error message above"
        echo_red "of curl and try again if it's a network issue."
        exit 1
    fi
    SHA256SUM_LOCAL=$(check_sha256sum "$temp_file")
    SHA256SUM_REMOTE=$(grep -w "headscale_""$remote_version_lite""_""$CURRENT_OS"_"$ARCH" <"$hash_temp_file" | grep -v ".deb" | cut -d ' ' -f 1)
    if [ "$SHA256SUM_LOCAL" != "$SHA256SUM_REMOTE" ]; then
        echo_red "SHA256SUM of the downloaded file does not match the one from"
        echo_red "the GitHub release, please try again later, if it always fails,"
        echo_red "please report this issue to the headscale project."
        rm -f "$temp_file" "$hash_temp_file"
        exit 1
    fi
}

# Install headscale
install_headscale() {
    install "$temp_file" /usr/local/bin/headscale
    chmod +x /usr/local/bin/headscale
    setcap cap_net_admin=+ep /usr/local/bin/headscale
    setcap cap_net_bind_service=+ep /usr/local/bin/headscale
    echo_green "headscale has been installed successfully."
    rm -f "$temp_file" "$hash_temp_file"
}

# Create user and group
create_user_group() {
    if ! getent group headscale >/dev/null; then
        if command -v groupadd >/dev/null; then
            groupadd --system headscale --gid 924
        else
            echo_yellow "We cannot find any tool to create a group, please create a group"
            echo_yellow "named headscale manually for headscale service to use."
        fi
    fi
    if ! getent passwd headscale >/dev/null; then
        if command -v useradd >/dev/null; then
            useradd --shell /bin/sh --comment "headscale default user" --gid headscale --system --create-home --home-dir /var/lib/headscale --gid 924 --uid 924 headscale
        else
            echo_yellow "We cannot find any tool to create a user, please create a user"
            echo_yellow "named headscale manually for headscale service to use."
        fi
    fi
}

# Download headscale config file
download_headscale_example_config() {
    [ -d /etc/headscale ] || mkdir -p /etc/headscale
    config_temp_file=$(mktemp) || (
        echo_red "Failed to visit TEMP dir, exits."
        exit 1
    )
    echo_green "Downloading headscale config-example.yaml..."
    if ! curl -L -# "https://github.com/juanfont/headscale/raw/refs/tags/$REMOTE_VERSION/config-example.yaml" -o "$config_temp_file"; then
        echo_red "Failed to download headscale config.example.yaml, read the error message above"
        echo_red "of curl and try again if it's a network issue."
        exit 1
    fi
    install "$config_temp_file" /etc/headscale/config-example.yaml
    echo_green "headscale config.example.yaml has been downloaded successfully, howerver,"
    echo_green "you should copy it to config.yaml and modify it according to your needs, "
    echo_green "never use config.example.yaml in production."
    rm -f "$config_temp_file"
}

# Install headscale service
install_headscale_service() {
    service_temp_file=$(mktemp) || (
        echo_red "Failed to visit TEMP dir, exits."
        exit 1
    )
    if command -v systemctl >/dev/null; then
        if [ -f /etc/systemd/system/headscale.service ]; then
            echo_yellow "headscale.service already exists, we will not overwrite it."
        else
            echo_green "Downloading headscale systemd service..."
            curl -L -# "https://github.com/MarksonHon/headscale-installer/raw/refs/heads/main/Systemd/headscale.service" -o "$service_temp_file"
            install "$service_temp_file" /etc/systemd/system/headscale.service
            systemctl daemon-reload
            echo_green "headscale.service has been installed successfully."
            rm -f "$service_temp_file"
        fi
    elif command -v /sbin/openrc-run >/dev/null; then
        if [ -f /etc/init.d/headscale ]; then
            echo_yellow "headscale service already exists, we will not overwrite it."
        else
            echo_green "Downloading headscale OpenRC service..."
            curl -L -# "https://github.com/MarksonHon/headscale-installer/raw/refs/heads/main/OpenRC/headscale.openrc" -o "$service_temp_file"
            install "$service_temp_file" /etc/init.d/headscale
            chmod +x /etc/init.d/headscale
            echo_green "headscale OpenRC service has been installed successfully."
            rm -f "$service_temp_file"
        fi
    else
        echo_yellow "We cannot find any supported init system, please write a service"
        echo_yellow "file for headscale manually according to your init system."
    fi
}

# Install headscale
while [ $# != 0 ]; do
    case $1 in
    --beta)
        INSTALL_BETA=true
        shift
        ;;
    *)
        echo_red "Invalid argument: $1" && exit 1
        shift
        ;;
    esac
done
check_local_version
check_remote_version
compare_version
download_headscale
install_headscale
create_user_group
download_headscale_example_config
install_headscale_service
echo_green "headscale has been installed successfully."
