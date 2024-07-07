#!/usr/bin/env bash
#github-action genshdoc
#
# @file Startup
# @brief This script will ask users about their prefrences like disk, file system, timezone, keyboard layout, user name, password, etc.
# @stdout Output routed to startup.log
# @stderror Output routed to startup.log
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

# @setting-header General Settings
# @setting CONFIG_FILE string[$CONFIGS_DIR/setup.conf] Location of setup.conf to be used by set_option and all subsequent scripts. 
CONFIG_FILE=$CONFIGS_DIR/setup.conf
if [ ! -f $CONFIG_FILE ]; then # check if file exists
    touch -f $CONFIG_FILE # create file if not exists
fi

# @description set options in setup.conf
# @arg $1 string Configuration variable.
# @arg $2 string Configuration value.
set_option() {
    if grep -Eq "^${1}.*" $CONFIG_FILE; then # check if option exists
        sed -i -e "/^${1}.*/d" $CONFIG_FILE # delete option if exists
    fi
    echo "${1}=${2}" >>$CONFIG_FILE # add option
}

set_password() {
    read -rs -p "Please enter password: " PASSWORD1
    echo -ne "\n"
    read -rs -p "Please re-enter password: " PASSWORD2
    echo -ne "\n"
    if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
        set_option "$1" "$PASSWORD1"
    else
        echo -ne "ERROR! Passwords do not match. \n"
        set_password
    fi
}

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERROR! This script must be run under the 'root' user!\n"
        exit 0
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    elif [[ -f /.dockerenv ]]; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    fi
}

arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -ne "ERROR! This script must be run in Arch Linux!\n"
        exit 0
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "ERROR! Pacman is blocked."
        echo -ne "If not running remove /var/lib/pacman/db.lck.\n"
        exit 0
    fi
}

background_checks() {
    root_check
    arch_check
    pacman_check
    docker_check
}

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
select_option() {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "$2   $1 "; }
    print_selected()   { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    get_cursor_col()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${COL#*[}; }
    key_input()         {
                        local key
                        IFS= read -rsn1 key 2>/dev/null >&2
                        if [[ $key = ""      ]]; then echo enter; fi;
                        if [[ $key = $'\x20' ]]; then echo space; fi;
                        if [[ $key = "k" ]]; then echo up; fi;
                        if [[ $key = "j" ]]; then echo down; fi;
                        if [[ $key = "h" ]]; then echo left; fi;
                        if [[ $key = "l" ]]; then echo right; fi;
                        if [[ $key = "a" ]]; then echo all; fi;
                        if [[ $key = "n" ]]; then echo none; fi;
                        if [[ $key = $'\x1b' ]]; then
                            read -rsn2 key
                            if [[ $key = [A || $key = k ]]; then echo up;    fi;
                            if [[ $key = [B || $key = j ]]; then echo down;  fi;
                            if [[ $key = [C || $key = l ]]; then echo right;  fi;
                            if [[ $key = [D || $key = h ]]; then echo left;  fi;
                        fi 
    }
    print_options_multicol() {
        # print options by overwriting the last lines
        local curr_col=$1
        local curr_row=$2
        local curr_idx=0

        local idx=0
        local row=0
        local col=0
        
        curr_idx=$(( $curr_col + $curr_row * $colmax ))
        
        for option in "${options[@]}"; do

            row=$(( $idx/$colmax ))
            col=$(( $idx - $row * $colmax ))

            cursor_to $(( $startrow + $row + 1)) $(( $offset * $col + 1))
            if [ $idx -eq $curr_idx ]; then
                print_selected "$option"
            else
                print_option "$option"
            fi
            ((idx++))
        done
    }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local return_value=$1
    local lastrow=`get_cursor_row`
    local lastcol=`get_cursor_col`
    local startrow=$(($lastrow - $#))
    local startcol=1
    local lines=$( tput lines )
    local cols=$( tput cols ) 
    local colmax=$2
    local offset=$(( $cols / $colmax ))

    local size=$4
    shift 4

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active_row=0
    local active_col=0
    while true; do
        print_options_multicol $active_col $active_row 
        # user key control
        case `key_input` in
            enter)  break;;
            up)     ((active_row--));
                    if [ $active_row -lt 0 ]; then active_row=0; fi;;
            down)   ((active_row++));
                    if [ $active_row -ge $(( ${#options[@]} / $colmax ))  ]; then active_row=$(( ${#options[@]} / $colmax )); fi;;
            left)     ((active_col=$active_col - 1));
                    if [ $active_col -lt 0 ]; then active_col=0; fi;;
            right)     ((active_col=$active_col + 1));
                    if [ $active_col -ge $colmax ]; then active_col=$(( $colmax - 1 )) ; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $(( $active_col + $active_row * $colmax ))
}
# @description Displays ArchTitus logo
# @noargs
logo () {
# This will be shown on every set as user is progressing
echo -ne "
-------------------------------------------------------------------------
 █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
------------------------------------------------------------------------
            Please select presetup settings for your system              
------------------------------------------------------------------------
"
}
# @description This function will handle file systems. At this movement we are handling only
# btrfs and ext4. Others will be added in future.
filesystem () {
echo -ne "
Please Select your file system for both boot and root
"
options=("btrfs" "ext4" "luks" "exit")
select_option $? 1 "${options[@]}"

case $? in
0) set_option FS btrfs;;
1) set_option FS ext4;;
2) 
    set_password "LUKS_PASSWORD"
    set_option FS luks
    ;;
3) exit ;;
*) echo "Wrong option please select again"; filesystem;;
esac
}
# @description Detects and sets timezone. 
timezone () {
# Added this from arch wiki https://wiki.archlinux.org/title/System_time
time_zone="$(curl --fail https://ipapi.co/timezone)"
echo -ne "
System detected your timezone to be '$time_zone' \n"
echo -ne "Is this correct?
" 
options=("Yes" "No")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    y|Y|yes|Yes|YES)
    echo "${time_zone} set as timezone"
    set_option TIMEZONE $time_zone;;
    n|N|no|NO|No)
    echo "Please enter your desired timezone e.g. Europe/London :" 
    read new_timezone
    echo "${new_timezone} set as timezone"
    set_option TIMEZONE $new_timezone;;
    *) echo "Wrong option. Try again";timezone;;
esac
}
# @description Set user's keyboard mapping. 
keymap () {
echo -ne "
Please select key board layout from this list"
# These are default key maps as presented in official arch repo archinstall
options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru sg ua uk)

select_option $? 4 "${options[@]}"
keymap=${options[$?]}

echo -ne "Your key boards layout: ${keymap} \n"
set_option KEYMAP $keymap
}

# @description Choose whether drive is SSD or not.
drivessd () {
echo -ne "
Is this an ssd? yes/no:
"

options=("Yes" "No")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    y|Y|yes|Yes|YES)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,ssd,commit=120";;
    n|N|no|NO|No)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,commit=120";;
    *) echo "Wrong option. Try again";drivessd;;
esac
}

# @description Disk selection for drive to be used with installation.
diskpart () {
echo -ne "
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formating your disk there is no way to get data back
------------------------------------------------------------------------

"

PS3='
Select the disk to install on: '
options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

select_option $? 1 "${options[@]}"
disk=${options[$?]%|*}

echo -e "\n${disk%|*} selected \n"
    set_option DISK ${disk%|*}

drivessd
}

# @description Gather username and password to be used for installation. 
userinfo () {
read -p "Please enter your username: " username
set_option USERNAME ${username,,} # convert to lower case as in issue #109 
set_password "PASSWORD"
read -rep "Please enter your hostname: " nameofmachine
set_option NAME_OF_MACHINE $nameofmachine
}

# @description Choose AUR helper. 
aurhelper () {
  # Let the user choose AUR helper from predefined list
  echo -ne "Please enter your desired AUR helper:\n"
  options=(paru yay picaur aura trizen pacaur none)
  select_option $? 4 "${options[@]}"
  aur_helper=${options[$?]}
  set_option AUR_HELPER $aur_helper
}

# @description Choose Desktop Environment
desktopenv () {
  # Let the user choose Desktop Enviroment from predefined list
  echo -ne "Please select your desired Desktop Enviroment:\n"
  options=( `for f in pkg-files/*.txt; do echo "$f" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done` )
  select_option $? 4 "${options[@]}"
  desktop_env=${options[$?]}
  set_option DESKTOP_ENV $desktop_env
}

# @description Choose whether to do full or minimal installation. 
installtype () {
  echo -ne "Please select type of installation:\n\n
  Full install: Installs full featured desktop enviroment, with added apps and themes needed for everyday use\n
  Minimal Install: Installs only apps few selected apps to get you started\n"
  options=(FULL MINIMAL)
  select_option $? 4 "${options[@]}"
  install_type=${options[$?]}
  set_option INSTALL_TYPE $install_type
}
# @description Install pre requisites for BTRFS-Snapper.
install_pre_req1 () {
    print_the info "Installing Prerequisites"

    print_line info "installing: gptfdisk btrfs-progs glibc btrfs-grub snap-pac snapper rsync"
    pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc btrfs-grub snap-pac snapper rsync
}

# @description Enable important services for BTRFS-Snapper.
ena_essential_services () {

    print_the info "Enabling Essential Services"

    # Enabling various services.
    print_line info "Enabling automatic snapshots, BTRFS scrubbing and systemd-oomd."
    services=(snapper-timeline.timer snapper-cleanup.timer btrfs-scrub@-.timer btrfs-scrub@home.timer btrfs-scrub@var-log.timer btrfs-scrub@\\x2esnapshots.timer grub-btrfsd.service systemd-oomd)
    for service in "${services[@]}"; do
        systemctl enable "$service" --root=/mnt &>/dev/null
    done
    
}

# @description Set up grub hooks to backup /boot when pacman transactions are made.
setup_grub_hooks () {
    # Boot backup hook.
    print_the info "Configuring /boot backup when pacman transactions are made."
    mkdir /mnt/etc/pacman.d/hooks
    cat > /mnt/etc/pacman.d/hooks/50-bootbackup.hook <<EOF
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF
}

# @description Create and copy the snapper configuration file.
create_and_copy_snapper_config() {
    local filename="root"
    local snapper_dir="/etc/snapper/configs"

    # Create the text file
    echo "
    # /etc/snapper/configs/root
    # subvolume to snapshot
    SUBVOLUME=\"/\"

    # filesystem type
    FSTYPE=\"btrfs\"

    # btrfs qgroup for space aware cleanup algorithms
    QGROUP=\"\"

    # fraction or absolute size of the filesystems space the snapshots may use
    SPACE_LIMIT=\"0.5\"

    # fraction or absolute size of the filesystems space that should be free
    FREE_LIMIT=\"0.2\"

    # users and groups allowed to work with config
    ALLOW_USERS=\"\"
    ALLOW_GROUPS=\"wheel\"

    # sync users and groups from ALLOW_USERS and ALLOW_GROUPS to .snapshots
    # directory
    SYNC_ACL=\"yes\"

    # start comparing pre- and post-snapshot in background after creating
    # post-snapshot
    BACKGROUND_COMPARISON=\"yes\"

    # run daily number cleanup
    NUMBER_CLEANUP=\"yes\"

    # limit for number cleanup
    NUMBER_MIN_AGE=\"3600\"
    NUMBER_LIMIT=\"10\"
    NUMBER_LIMIT_IMPORTANT=\"10\"

    # create hourly snapshots
    TIMELINE_CREATE=\"yes\"

    # cleanup hourly snapshots after some time
    TIMELINE_CLEANUP=\"yes\"

    # limits for timeline cleanup
    TIMELINE_MIN_AGE=\"3600\"
    TIMELINE_LIMIT_HOURLY=\"5\"
    TIMELINE_LIMIT_DAILY=\"7\"
    TIMELINE_LIMIT_WEEKLY=\"0\"
    TIMELINE_LIMIT_MONTHLY=\"0\"
    TIMELINE_LIMIT_QUARTERLY=\"0\"
    TIMELINE_LIMIT_YEARLY=\"0\"

    # cleanup empty pre-post-pairs
    EMPTY_PRE_POST_CLEANUP=\"yes\"

    # limits for empty pre-post-pair cleanup
    EMPTY_PRE_POST_MIN_AGE=\"3600\"
    " > "$filename"

    # Copy to snapper directory
    mv "$filename" "$snapper_dir"
}
# @description Create a snapper configuration and update /etc/conf.d/snapper
snapper_root_config() {
    local config_name="root"
    local content="## Path: System/Snapper
## Type:        string
## Default:     \"\"
# List of snapper configurations.
SNAPPER_CONFIGS=\"$config_name\""

    # Create the text file
    echo "$content" > snapper.txt

    # Move to /etc/conf.d/snapper
    mv snapper.txt /etc/conf.d/snapper
}
# More features in future
# language (){}

# Starting functions
background_checks
clear
logo
userinfo
clear
logo
desktopenv
# Set fixed options that installation uses if user choses server installation
set_option INSTALL_TYPE MINIMAL
set_option AUR_HELPER NONE
if [[ ! $desktop_env == server ]]; then
  clear
  logo
  aurhelper
  clear
  logo
  installtype
fi
clear
logo
diskpart
clear
logo
filesystem
clear
logo
timezone
clear
logo
keymap
