#!/usr/bin/env bash
# Fixing annoying issue that breaks GitHub Actions
# shellcheck disable=SC2001

#github-action genshdoc
## (colours for text banners).
RED='\033[0;31m'
BLUE='\033[0;34m'  
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'     ## No Color
## ---------------------------------------------------------------------------
## The Function begin here..

## For printing out the info banners
# @description Print a title with a message.
# @param $1 - The Type of message (info, error).
# @param $2 - The message to display.
# @example print_the "info" "Hello, World!"
print_the () {
    
    ## syntax use
    ## print_the info "Some important message"
    ## print_the error "Some important error"

    local info=$2
    local arg1=$1

    if [ "$arg1" == "info" ]; then
        color=${GREEN}
    elif [ "$arg1" == "error" ]; then 
        color=${RED}
    else
        color=${RED} 
        info="Error with the Title check your input"
    fi

    echo -ne "
    ${BLUE}-------------------------------------------------------------------------
               ${color} $info
    ${BLUE}-------------------------------------------------------------------------
    ${RESET}"
}
# @description Print a line with a title.
# @param $1 - The Type of message (info, error).
# @param $2 - The message to display.
# @example print_line "info" "Hello, World!"
print_line () {

    ## syntax use
    ## print_line info "Some important message"
    ## print_line error " Some important error"

    local arg2=$1
    local pl=$2

    if [ "$arg2" == "info" ]; then
        color=${GREEN}
    elif [ "$arg2" == "error" ]; then 
        color=${RED}
    else
        color=${RED} 
        info="Error with the Title check your input"
    fi

    echo -ne "
    ${color} $pl
    ${RESET}"
}
# @description Logo banner for the script.
# @param $1 - The message to display with the logo.
# @example print_logo "Hello, World!"
logo () {
    # This will display the Logo banner and a message

    logo_message=$1

    echo -ne "
    ${BLUE}-------------------------------------------------------------------------
    ${GREEN}
     █████╗ ██████╗  ██████╗██╗  ██╗     ██╗████████╗
    ██╔══██╗██╔══██╗██╔════╝██║  ██║     ██║╚══██╔══╝
    ███████║██████╔╝██║     ███████║     ██║   ██║   
    ██╔══██║██╔══██╗██║     ██╔══██║     ██║   ██║   
    ██║  ██║██║  ██║╚██████╗██║  ██║     ██║   ██║    ██║
    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝     ╚═╝   ╚═╝   ╚══╝
    ${BLUE}------------------------------------------------------------------------
                ${GREEN} $logo_message
    ${BLUE}------------------------------------------------------------------------
    ${RESET}"
}
# @description Install packages from a file.
# @param $1 - The file containing the list of packages to install.
# @example install_packages "packages.txt" "/path/to/source"
# @exitcode 1 - File not found.
# @exitcode 0 - Success.
install_packages() {

    # Usage: install_packages <file>
    # install_packages "packages.txt"
    local source_file_path="$2"

    # Check if the file exists
    if [ ! -f "$source_file_path/pkg-files/$1" ]; then
        echo "File not found! $1"
        exit 1
    fi

    local file="$source_file_path/pkg-files/$1"
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
        sudo pacman -S "$PKG" --noconfirm --needed
    done
}
# @description Create and copy a configuration file to a specified directory.
# @param $1 - Source file path of the configuration file.
# @param $2 - Destination directory where the configuration file should be moved.
# @example create_and_copy_config "source_file_path" "destination_dir"
create_and_copy_config() {
    local source_file_path="$1"
    local destination_dir="$2"
    local destination_path="$destination_dir/$(basename "$source_file_path")"

    # Create the source directory if it doesn't exist
    mkdir -p "$(dirname "$destination_path")"

    # Copy the file to the destination
    if cp -rfv "$source_file_path" "$destination_path"; then
        printf "Configuration file successfully copied to %s\n" "$destination_path"
        # rm "$source_file_path" # Remove the source file
    else
        printf "Failed to copy the configuration file.\n"
        return 1 # Exit the function with an error status
    fi
}
# @description Enable and start the specified services.
# @example enable_services "services.txt" "/path/to/source"
enabling_services() {
    local source_file_path="$2"
    local services_file="$source_file_path/$1"
    local services=()

    # Check if the file exists
    if [ ! -f "$services_file" ]; then
        echo "Services file not found! $services_file"
        exit 1
    fi

    # Read the file and populate the services array
    while IFS= read -r line; do
        if [[ ! $line =~ ^\s*# ]]; then
            services+=("$line")
        fi
    done < "$services_file"

    for service in "${services[@]}"; do
        if systemctl enable "$service" --root=/mnt &>/dev/null; then
            echo "  $service enabled"
        else
            echo "Failed to enable $service"
        fi
        if systemctl start "$service" --root=/mnt &>/dev/null; then
            echo "  $service started"
        else
            echo "Failed to start $service"
        fi
    done
}
