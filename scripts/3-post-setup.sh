#!/usr/bin/env bash
#github-action genshdoc
#
# @file Post-Setup
# @brief Finalizing installation configurations and cleaning up after script.
echo -ne "
-------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
                        SCRIPTHOME: ArchTitus
-------------------------------------------------------------------------

Final Setup and Configurations
GRUB EFI Bootloader Install & Check
"
source ${HOME}/ArchTitus/configs/setup.conf

if [[ -d "/sys/firmware/efi" ]]; then
    grub-install --efi-directory=/boot ${DISK}
fi

echo -ne "
-------------------------------------------------------------------------
               Creating (and Theming) Grub Boot Menu
-------------------------------------------------------------------------
"
# set kernel parameter for decrypting the drive
if [[ "${FS}" == "luks" ]]; then
sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
fi
# set kernel parameter for adding splash screen
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub

echo -e "Installing CyberRe Grub theme..."
THEME_DIR="/boot/grub/themes"
THEME_NAME=CyberRe
echo -e "Creating the theme directory..."
mkdir -p "${THEME_DIR}/${THEME_NAME}"
echo -e "Copying the theme..."
cd ${HOME}/ArchTitus
cp -a configs${THEME_DIR}/${THEME_NAME}/* ${THEME_DIR}/${THEME_NAME}
echo -e "Backing up Grub config..."
cp -an /etc/default/grub /etc/default/grub.bak
echo -e "Setting the theme as the default..."
grep "GRUB_THEME=" /etc/default/grub 2>&1 >/dev/null && sed -i '/GRUB_THEME=/d' /etc/default/grub
echo "GRUB_THEME=\"${THEME_DIR}/${THEME_NAME}/theme.txt\"" >> /etc/default/grub
echo -e "Updating grub..."
grub-mkconfig -o /boot/grub/grub.cfg
echo -e "All set!"

echo -ne "
-------------------------------------------------------------------------
               Enabling (and Theming) Login Display Manager
-------------------------------------------------------------------------
"
if [[ ${DESKTOP_ENV} == "kde" ]]; then
  systemctl enable sddm.service
  if [[ ${INSTALL_TYPE} == "FULL" ]]; then
    echo [Theme] >>  /etc/sddm.conf
    echo Current=Nordic >> /etc/sddm.conf
  fi

elif [[ "${DESKTOP_ENV}" == "gnome" ]]; then
  systemctl enable gdm.service

else
  if [[ ! "${DESKTOP_ENV}" == "server"  ]]; then
  sudo pacman -S --noconfirm --needed lightdm lightdm-gtk-greeter
  systemctl enable lightdm.service
  fi
fi

echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
echo "Enabling Essential Services"
   services=(
        cups.service
        ntpd.service
        NetworkManager.service
        bluetooth
        avahi-daemon.service
        snapper-timeline.timer 
        snapper-cleanup.timer 
        btrfs-scrub@-.timer 
        btrfs-scrub@home.timer 
        btrfs-scrub@var-log.timer 
        btrfs-scrub@\\x2esnapshots.timer 
        grub-btrfsd.service 
        systemd-oomd
    )
 for service in "${services[@]}"; do
        systemctl enable "$service" --root=/mnt &>/dev/null
        echo "  $service enabled"
 done
    
systemctl disable dhcpcd.service
echo "  DHCP disabled"
systemctl stop dhcpcd.service
echo "  DHCP stopped"


if [[ "${FS}" == "luks" || "${FS}" == "btrfs" ]]; then
echo -ne "
-------------------------------------------------------------------------
                    Creating Snapper Config
-------------------------------------------------------------------------
"

setup_grub_hooks () {
    # Boot backup hook.
    echo "Configuring /boot backup when pacman transactions are made."
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

setup_grub_hooks
create_and_copy_snapper_config
snapper_root_config

fi

echo -ne "
-------------------------------------------------------------------------
               Enabling (and Theming) Plymouth Boot Splash
-------------------------------------------------------------------------
"
PLYMOUTH_THEMES_DIR="$HOME/ArchTitus/configs/usr/share/plymouth/themes"
PLYMOUTH_THEME="arch-glow" # can grab from config later if we allow selection
mkdir -p /usr/share/plymouth/themes
echo 'Installing Plymouth theme...'
cp -rf ${PLYMOUTH_THEMES_DIR}/${PLYMOUTH_THEME} /usr/share/plymouth/themes
if [[ $FS == "luks" ]]; then
  sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
  sed -i 's/HOOKS=(base udev \(.*block\) /&plymouth-/' /etc/mkinitcpio.conf # create plymouth-encrypt after block hook
else
  sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
fi
plymouth-set-default-theme -R arch-glow # sets the theme and runs mkinitcpio
echo 'Plymouth theme installed'

echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"
# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

rm -r $HOME/ArchTitus
rm -r /home/$USERNAME/ArchTitus

# Replace in the same state
cd $pwd
