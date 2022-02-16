#!/usr/bin/env bash

# You can solve users running this script as root
# with this and then doing the same for the next for statement.
# However I will leave this up to you.
# shellcheck disable=SC1091
# shellcheck source=./setup.conf
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

CONFIG_FILE="$SCRIPT_DIR"/setup.conf
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ERROR! Missing file: setup.conf"
    exit 1
fi

install_aur() {
    "$AURHELPER" -S --noconfirm --needed "$@"
}

cd ~ || exit 1
case "$AURHELPER" in
"yay")
    install_pkg "go"
    git clone "https://aur.archlinux.org/yay.git"
    ;;
"trizen")
    install_pkg "perl"
    git clone "https://aur.archlinux.org/trizen.git"
    ;;
"aurman")
    git clone "https://aur.archlinux.org/aurman.git"
    ;;
"aura")
    install_pkg "stack"
    git clone "https://aur.archlinux.org/aura.git"
    ;;
"pikaur")
    git clone "https://aur.archlinux.org/pikaur.git"
    ;;
*)
    something_failed
    ;;
esac

cd "$AURHELPER" || exit 1
makepkg -si --noconfirm
cd ~ || exit 1

while IFS= read -r LINE; do
        echo "INSTALLING: $LINE"
        install_aur "$LINE"
done <~/ArchTitus/pkg-files/aur-pkgs.txt

if [[ "$LAYOUT" -eq 1 ]]; then
    touch "$HOME/.cache/zshhistory"
    git clone "https://github.com/ChrisTitusTech/zsh"
    git clone --depth=1 "https://github.com/romkatv/powerlevel10k.git" "$HOME"/powerlevel10k
    ln -s "$HOME/zsh/.zshrc" "$HOME"/.zshrc

    pip install konsave
    konsave -i "$HOME"/ArchTitus/kde.knsv
    sleep 1
    konsave -a kde
    cp -r "$HOME"/ArchTitus/dotfiles/* "$HOME"/.config/
fi

case "$DESKTOP" in
"lxqt")
    install_aur "sddm-nordic-theme-git"
    ;;
"awesome")
    install_aur "rofi picom i3lock-fancy xclip ttf-roboto polkit-gnome materia-theme lxappearance flameshot pnmixer network-manager-applet xfce4-power-manager qt5-styleplugins papirus-icon-theme"
    git clone "https://github.com/ChrisTitusTech/titus-awesome" "$HOME"/.config/awesome
    mkdir -p "$HOME"/.config/rofi
    cp "$HOME"/.config/awesome/theme/config.rasi "$HOME"/.config/rofi/config.rasi
    sed -i "/@import/c\@import $HOME/.config/awesome/theme/sidebar.rasi" "$HOME"/.config/rofi/config.rasi
    ;;
esac

export PATH=$PATH:~/.local/bin

title "System ready for 3-post-setup.sh"
