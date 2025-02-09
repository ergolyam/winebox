#!/bin/bash

WINEBOX_DIR="$HOME/.local/share/winebox"
mkdir -p "$WINEBOX_DIR"

PREFIXES_FILE="$WINEBOX_DIR/winebox_prefixes.list"

WINE_GE_DIR="$WINEBOX_DIR/wine-ge"
DXVK_DIR="$WINEBOX_DIR/dxvk"

print_help() {
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  create         Create a new Wine prefix"
    echo "  exec           Execute a command in an existing Wine prefix"
    echo "  run            Run a Wine application in a prefix"
    echo "  rm             Remove an existing Wine prefix"
    echo "  list           List all existing Wine prefixes"
    echo
    echo "Options for each command:"
    echo "  --name         Specify the name of the Wine prefix"
    echo "  --path         Specify the path for the Wine prefix"
    echo "  --arch         Set the architecture (win32 or win64)"
    echo "  --type         Specify Wine version (wine or wine-ge)"
    echo "  --sandbox      Use a sandbox environment"
    echo "  --dxvk         Use DXVK for Vulkan-based DirectX to Vulkan translation"
    echo "  --chdir        Change working directory for executing commands"
    echo
    echo "For more information, please refer to the script documentation."
    exit 0
}

check_winetricks() {
    if command -v winetricks &>/dev/null; then
        WINETRICKS="winetricks"
    else
        echo "winetricks not found. Downloading via curl..."
        TEMPFILE=$(mktemp)
        curl -s https://raw.githubusercontent.com/Winetricks/winetricks/refs/heads/master/src/winetricks -o "$TEMPFILE"
        chmod +x $TEMPFILE
        WINETRICKS=$TEMPFILE
    fi
}

install_wine_ge() {
    if [[ ! -x "$WINE_GE_DIR/bin/wine" ]]; then
        echo "wine-ge not installed. Starting installation..."
        
        local DOWNLOAD_URL=$(curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest | \
            jq -r '.assets[] | select(.name | test(".*\\.tar\\.xz$")) | .browser_download_url')

        if [[ -z "$DOWNLOAD_URL" ]]; then
            echo "Failed to get link to wine-ge archive"
            exit 1
        fi

        echo "Download link: $DOWNLOAD_URL"

        local TEMPFILE=$(mktemp)
        wget "$DOWNLOAD_URL" -O "$TEMPFILE" 2>&1
        if [[ $? -ne 0 ]]; then
            echo "Error: download wine-ge"
            rm -f "$TEMPFILE"
            exit 1
        fi

        tar -xf "$TEMPFILE" -C "$WINEBOX_DIR"
        if [[ $? -ne 0 ]]; then
            echo "Error: unpacking wine-ge"
            rm -f "$TEMPFILE"
            exit 1
        fi

        local EXTRACTED_DIR=$(tar -tf "$TEMPFILE" | head -1 | cut -f1 -d"/")
        mv "$WINEBOX_DIR/$EXTRACTED_DIR" "$WINE_GE_DIR"

        rm -f "$TEMPFILE"

        echo "wine-ge installed successfully in $WINE_GE_DIR"
    else
        echo "wine-ge is already installed"
    fi
}

install_dxvk () {
    if [[ ! -d "$DXVK_DIR" ]]; then
        echo "dxvk not installed. Starting installation..."
        local DOWNLOAD_URL=$(curl -s https://api.github.com/repos/doitsujin/dxvk/releases/latest | \
            jq -r '.assets[] | select(.name | test(".*\\.tar\\.gz$") and (test("native") | not)) | .browser_download_url')

        if [[ -z "$DOWNLOAD_URL" ]]; then
            echo "Failed to get link to dxvk archive"
            exit 1
        fi

        echo "Download link: $DOWNLOAD_URL"

        local TEMPFILE=$(mktemp)
        wget "$DOWNLOAD_URL" -O "$TEMPFILE" 2>&1
        if [[ $? -ne 0 ]]; then
            echo "Error: download dxvk"
            rm -f "$TEMPFILE"
            exit 1
        fi

        tar -xf "$TEMPFILE" -C "$WINEBOX_DIR"
        if [[ $? -ne 0 ]]; then
            echo "Error: unpacking dxvk"
            rm -f "$TEMPFILE"
            exit 1
        fi

        local EXTRACTED_DIR=$(tar -tf "$TEMPFILE" | head -1 | cut -f1 -d"/")
        mv "$WINEBOX_DIR/$EXTRACTED_DIR" "$DXVK_DIR"

        rm -f "$TEMPFILE"

        echo "dxvk installed successfully in $DXVK_DIR"
    else
        echo "dxvk is already installed"
    fi
}

create_wine_prefix() {
    local name="$1"
    local path="$2"
    local arch="$3"
    local use_sandbox="$4"
    local wine_type="$5"
    local use_dxvk="$6"

    if grep -qE "^\s*$name\s+|\s*$path\s+" "$PREFIXES_FILE"; then
        echo "Error: Prefix with name '$name' or path '$path' already exists"
        exit 1
    fi

    if [[ -z "$name" ]]; then
        name=$(basename "$path")
    fi

    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    echo "Create a Wine prefix..."
    echo "Name: $name"
    echo "Path: $path"
    echo "Arch: $arch"
    echo "Type: $wine_type"

    if [[ "$wine_type" == "wine-ge" ]]; then
        install_wine_ge
        WINE_BIN="$WINE_GE_DIR/bin/wine"
    else
        WINE_BIN="wine"
    fi

    WINEARCH=$arch WINEPREFIX=$path WINEDEBUG=-all "$WINE_BIN" wineboot

    if [[ "$use_sandbox" == "true" ]]; then
        check_winetricks
        echo "Applying sandbox environment via winetricks..."
        WINEPREFIX=$path WINE="$WINE_BIN" $WINETRICKS sandbox

        sandbox_dir="/home/$USER/Downloads/"
        mkdir -p $sandbox_dir
        ln -s $sandbox_dir "$path/dosdevices/z:"
    fi

    if [[ "$use_dxvk" == "true" ]]; then
        install_dxvk
        echo "Applying dxvk environment..."
      if [[ $arch == "win32" ]]; then
          cp -v $DXVK_DIR/x32/*.dll "$path/drive_c/windows/system32"
      elif [[ $arch == "win64" ]]; then
          cp -v $DXVK_DIR/x64/*.dll "$path/drive_c/windows/system32"
          cp -v $DXVK_DIR/x32/*.dll "$path/drive_c/windows/syswow64"
      fi
    fi

    echo "$name $path $wine_type" >> "$PREFIXES_FILE"
}

exec_wine_prefix() {
    local name="$1"
    local cmd="$2"
    local basedir="$3"

    if [[ ! -f "$PREFIXES_FILE" ]]; then
        echo "Prefixes file not found. No prefixes have been created yet"
        exit 1
    fi

    read -r prefix_name prefix_path wine_type <<< $(grep "^$name " "$PREFIXES_FILE")

    if [[ -z "$prefix_path" ]]; then
        echo "Prefix with name '$name' not found"
        exit 1
    fi

    if [[ "$wine_type" == "wine-ge" ]]; then
        WINE_BIN="$WINE_GE_DIR/bin/wine"
    else
        WINE_BIN="wine"
    fi

    if [[ "$basedir" == "true" ]]; then
        local dir
        dir=$(dirname "$cmd")
        echo "Executing '$cmd' in Wine prefix '$name' with basedir $dir"
        WINEPREFIX="$prefix_path" env --chdir="$dir" "$WINE_BIN" "$cmd"
    else
        echo "Executing '$cmd' in Wine prefix '$name'"
        WINEPREFIX="$prefix_path" "$WINE_BIN" "$cmd"
    fi
}

list_wine_prefixes() {
    if [[ ! -f "$PREFIXES_FILE" ]]; then
        echo "Prefixes file not found. No prefixes have been created yet"
        exit 1
    fi

    printf "+----------------+-------------------------------------------------+---------+----------------------------------------------+\n"
    printf "| %-14s | %-47s | %-7s | %-44s |\n" "Prefix name" "Path" "Type"
    printf "+----------------+-------------------------------------------------+---------+----------------------------------------------+\n"
    
    while IFS=' ' read -r name path wine_type; do
        printf "| %-14s | %-47s | %-7s | %-44s |\n" "$name" "$path" "$wine_type"
    done < "$PREFIXES_FILE"

    printf "+----------------+-------------------------------------------------+---------+----------------------------------------------+\n"
}

remove_wine_prefix() {
    local name="$1"

    if [[ ! -f "$PREFIXES_FILE" ]]; then
        echo "Prefixes file not found. No prefixes have been created yet"
        exit 1
    fi

    local prefix_path
    prefix_path=$(grep "^$name " "$PREFIXES_FILE" | cut -d' ' -f2)

    if [[ -z "$prefix_path" ]]; then
        echo "Prefix with name '$name' not found"
        exit 1
    fi

    read -p "Are you sure you want to delete prefix '$name' (path: $prefix_path)? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Prefix deletion cancelled"
        exit 0
    fi

    echo "Deleting prefix $name from path $prefix_path..."
    rm -rf "$prefix_path"
    
    sed -i "/^$name /d" "$PREFIXES_FILE"
    echo "Prefix $name has been successfully deleted"
}

process_arguments() {
    local cmd="$1"
    shift

    case "$cmd" in
        create)
            local name=""
            local path="wine"
            local arch="win64"
            local use_sandbox="false"
            local wine_type="wine"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name)
                        name="$2"
                        shift 2
                        ;;
                    --path)
                        path="$2"
                        shift 2
                        ;;
                    --arch)
                        arch="$2"
                        shift 2
                        ;;
                    --type)
                        wine_type="$2"
                        shift 2
                        ;;
                    --sandbox)
                        use_sandbox="true"
                        shift
                        ;;
                    --dxvk)
                        use_dxvk="true"
                        shift
                        ;;
                    *)
                        echo "Unknown argument: $1"
                        echo "Use --help for usage information"
                        exit 1
                        ;;
                esac
            done
            create_wine_prefix "$name" "$path" "$arch" "$use_sandbox" "$wine_type" "$use_dxvk"
            ;;
        exec)
            local name=""
            local cmd=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name)
                        name="$2"
                        shift 2
                        ;;
                    --chdir)
                        use_basedir="true"
                        shift
                        ;;
                    *)
                        cmd="$1"
                        shift
                        ;;
                esac
            done

            if [[ -z "$name" ]]; then
                echo "Error: Prefix name must be specified with --name"
                exit 1
            fi

            if [[ -z "$cmd" ]]; then
                echo "Error: You must specify a command to execute in the prefix"
                exit 1
            fi

            exec_wine_prefix "$name" "$cmd" "$use_basedir"
            ;;
        rm)
            local name=""
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name)
                        name="$2"
                        shift 2
                        ;;
                    *)
                        echo "Unknown argument: $1"
                        echo "Use --help for usage information"
                        exit 1
                        ;;
                esac
            done

            if [[ -z "$name" ]]; then
                echo "Error: You must specify the prefix name with --name"
                exit 1
            fi

            remove_wine_prefix "$name"
            ;;
        list)
            list_wine_prefixes
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

if [[ $# -lt 1 ]]; then
    echo "Error: Missing command. Use --help for usage information"
    exit 1
fi

if [[ $# -eq 0 || "$1" == "--help" ]]; then
    print_help
fi

command="$1"
shift

process_arguments "$command" "$@"

