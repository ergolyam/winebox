#!/bin/bash

PREFIXES_FILE="$HOME/.local/share/winebox_prefixes.list"

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

create_wine_prefix() {
    local name="$1"
    local path="$2"
    local arch="$3"
    local use_sandbox="$4"

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

    echo "Create a Wine prefix with the name: $name"
    echo "Path: $path"
    echo "Arch: $arch"

    WINEARCH=$arch WINEPREFIX=$path WINEDEBUG=-all wineboot

    if [[ "$use_sandbox" == "true" ]]; then
        check_winetricks
        echo "Applying sandbox environment via winetricks..."
        WINEPREFIX=$path $WINETRICKS sandbox

        sandbox_dir="/home/$USER/Downloads/"
        mkdir -p $sandbox_dir
        ln -s $sandbox_dir "$path/dosdevices/z:"
    fi

    echo "$name $path" >> "$PREFIXES_FILE"
}

exec_wine_prefix() {
    local name="$1"
    local cmd="$2"
    local basedir="$3"

    if [[ ! -f "$PREFIXES_FILE" ]]; then
        echo "Prefixes file not found. No prefixes have been created yet"
        exit 1
    fi

    read -r prefix_name prefix_path exe_path <<< $(grep "^$name " "$PREFIXES_FILE")

    if [[ -z "$prefix_path" ]]; then
        echo "Prefix with name '$name' not found"
        exit 1
    fi

    if [[ "$basedir" == "true" ]]; then
        local dir
        dir=$(dirname "$cmd")
        echo "Executing '$cmd' in Wine prefix '$name' with basedir $dir"
        WINEPREFIX="$prefix_path" env --chdir="$dir" wine "$cmd"
    else
        echo "Executing '$cmd' in Wine prefix '$name'"
        WINEPREFIX="$prefix_path" wine "$cmd"
    fi
    if [[ -n "$exe_path" ]]; then
        echo "Exe path already set for prefix '$name': $exe_path"
    else
        desktop_dir="$prefix_path/drive_c/users/Public/Desktop/"
        if [[ -d "$desktop_dir" ]]; then
            lnk_files=("$desktop_dir"/*.lnk)
            if [[ -e "${lnk_files[0]}" ]]; then
                for lnk in "${lnk_files[@]}"; do
                    exe_path=$(strings "$lnk" | grep 'C:\\.*\.exe' | sed 's|C:\\|drive_c/|' | tr '\\' '/')
                    if [[ -n "$exe_path" ]]; then
                        sed -i "/^$name /s|$| $prefix_path/$exe_path|" "$PREFIXES_FILE"
                        echo "Exe path '$exe_path' add to prefix '$name'"
                        break
                    fi
                done
            else
                echo "No .lnk files found on the Desktop for prefix '$name'"
            fi
        else
            echo "Desktop directory '$desktop_dir' does not exist"
        fi
    fi
}

run_wine_app_prefix() {
    local name="$1"
    shift
    local args=("$@")

    if [[ ! -f "$PREFIXES_FILE" ]]; then
        echo "Prefixes file not found. No prefixes have been created yet"
        exit 1
    fi

    read -r prefix_name prefix_path exe_path <<< $(grep "^$name " "$PREFIXES_FILE")

    if [[ -z "$prefix_path" ]]; then
        echo "Prefix with name '$name' not found"
        exit 1
    fi

    if [[ -z "$exe_path" ]]; then
        echo "Exe path for prefix '$name' not set. Please execute a command first to detect .lnk files."
        exit 1
    fi

    local dir
    dir=$(dirname "$exe_path")

    echo "Running application '$exe_path' in Wine prefix '$name' with basedir $dir and arguments: ${args[*]}"
    WINEPREFIX="$prefix_path" env --chdir="$dir" wine "$exe_path" "${args[@]}"
}

list_wine_prefixes() {
    if [[ ! -f "$PREFIXES_FILE" ]]; then
        echo "Prefixes file not found. No prefixes have been created yet"
        exit 1
    fi

    printf "+----------------+-------------------------------------------------+----------------------------------------------+\n"
    printf "| %-14s | %-47s | %-44s |\n" "Prefix name" "Path" "Exe Path"
    printf "+----------------+-------------------------------------------------+----------------------------------------------+\n"
    
    while IFS=' ' read -r name path exe_path; do
        if [[ -z "$exe_path" ]]; then
            exe_path="-"
        fi
        printf "| %-14s | %-47s | %-44s |\n" "$name" "$path" "$exe_path"
    done < "$PREFIXES_FILE"

    printf "+----------------+-------------------------------------------------+----------------------------------------------+\n"
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
                    --sandbox)
                        use_sandbox="true"
                        shift
                        ;;
                    *)
                        echo "Unknown argument: $1"
                        exit 1
                        ;;
                esac
            done
            create_wine_prefix "$name" "$path" "$arch" "$use_sandbox"
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
        run)
            local name=""
            local app_args=()

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name)
                        name="$2"
                        shift 2
                        ;;
                        --)
                        shift
                        args+=("$@")
                        break
                        ;;
                    *)
                        echo "Unknown argument: $1"
                        exit 1
                        ;;
                esac
            done

            if [[ -z "$name" ]]; then
                echo "Error: You must specify the prefix name with --name"
                exit 1
            fi

            run_wine_app_prefix "$name" "${args[@]}"
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
            exit 1
            ;;
    esac
}

if [[ $# -lt 1 ]]; then
    echo "using: $0 <command> [options]"
    exit 1
fi

command="$1"
shift

process_arguments "$command" "$@"

