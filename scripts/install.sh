#!/usr/bin/env bash

## This can be used to Install packages from a file
## Usage: install_packages <file>
# install_packages "base-pkgs.txt"
# install_packages "software-pacman.txt"
# Get the directory of the current script


install_packages() {
    # Create a source path relative to the script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script_dir="${script_dir%/*}"
    echo "Script directory: $script_dir"
    local source_file_path="$script_dir/pkg-files"

    # Check if the file exists
    if [ ! -f "$source_file_path/$1" ]; then
        echo "File not found! $1"
        exit 1
    fi

    local file="$source_file_path/$1"
    local PKGS=()

    echo "INSTALLING SOFTWARE"

    # Read the file and populate the PKGS array
    while IFS= read -r line; do
        if [[ ! $line =~ ^\s*# ]]; then
            # Extract content within single quotes
            if [[ $line =~ \'([^\']*)\' ]]; then
                PKGS+=("${BASH_REMATCH[1]}")
            fi
        fi
    done < "$file"

    # Install the packages
    for PKG in "${PKGS[@]}"; do
        echo "INSTALLING: ${PKG}"
        #sudo pacman -S "$PKG" --noconfirm --needed
    done
}

# Menu for selecting install_packages
select_option() {
    echo "Select an option:"
    echo "1. Install base packages"
    echo "2. Install software packages (pacman)"
    echo "3. Install hypland packages"
    echo "4. Install dwm packages"
    echo "0. Exit"

    read -p "Enter your choice: " choice

    case $choice in
        1)
            install_packages "base-pkgs.txt"
            ;;
        2)
            install_packages "software-pacman.txt"
            ;;
        3)
            install_packages "hypland.txt"
            ;;
        4)
            install_packages "dwm.txt"
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            select_option
            ;;
    esac

    # Prompt the user if they want to install more packages
    read -p "Do you want to install more packages? (y/n): "[n] more_packages

    if [[ $more_packages =~ ^[Yy]$|^yes$|^YES$|^Yes$ ]]; then
        select_option
    else
        echo "Exiting..."
        exit 0
    fi
}

# Call the menu function
select_option