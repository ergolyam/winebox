#!/bin/bash

PREFIXES_FILE="$HOME/.local/share/winebox_prefixes.list"

create_wine_prefix() {
    local name="$1"
    local path="$2"
    local arch="$3"

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
    echo "$name $path" >> "$PREFIXES_FILE"
}

run_wine_prefix() {
    local name="$1"
    shift
    local cmd="$1"

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

    echo "Run the command '$cmd' in Wine prefix '$name' with path $prefix_path"
    WINEPREFIX="$prefix_path" wine "$cmd"
}

list_wine_prefixes() {
    if [[ ! -f "$PREFIXES_FILE" ]]; then
        echo "Prefixes file not found. No prefixes have been created yet"
        exit 1
    fi

    echo "+----------------+-------------------------------------------------+"
    echo "| Prefix name    | Path                                            |"
    echo "+----------------+-------------------------------------------------+"
    
    while IFS=' ' read -r name path; do
        printf "| %-14s | %-47s |\n" "$name" "$path"
    done < "$PREFIXES_FILE"

    echo "+----------------+-------------------------------------------------+"
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
                    *)
                        echo "Unknown argument: $1"
                        exit 1
                        ;;
                esac
            done
            create_wine_prefix "$name" "$path" "$arch"
            ;;
        run)
            local name=""
            local cmd=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name)
                        name="$2"
                        shift 2
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

            run_wine_prefix "$name" "$cmd"
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

