#!/bin/bash

# First removes all of the config directories in case they exist so as to not interfere with symlinks

rm -rf ~/.config/hypr

rm -rf ~/.config/kitty

rm -rf ~/.config/nvim

rm -rf ~/.config/rofi

rm -rf ~/.config/spicetify

rm -f ~/.local/share/applications/spotify-launcher.desktop

rm -f ~/.config/starship.toml

rm -rf ~/.config/waybar

rm -rf ~/.config/yazi

# Then, makes symlinks to connect the theme-agnostic config dotfiles from my repo to their proper locations

ln -s ~/Code/my_dotfiles/Configs/Hypr ~/.config/hypr

ln -s ~/Code/my_dotfiles/Configs/Kitty ~/.config/kitty

ln -s ~/Code/my_dotfiles/Configs/Nvim ~/.config/nvim

ln -s ~/Code/my_dotfiles/Configs/Rofi ~/.config/rofi

ln -s ~/Code/my_dotfiles/Configs/Spotify/Spicetify ~/.config/spicetify

ln -s ~/Code/my_dotfiles/Configs/Spotify/spotify-launcher.desktop ~/.local/share/applications/

ln -s ~/Code/my_dotfiles/Configs/Waybar ~/.config/waybar

ln -s ~/Code/my_dotfiles/Configs/Yazi ~/.config/yazi

# Finally, ask the user if they'd like a dark or light theme, then running the previously made scripts based on the choice

echo "Would you like a dark or light theme?"
read -p "[L/D] " lord
if [[ "$lord" == "l" || "$lord" == "L" ]]; then
    ~/Code/my_dotfiles/Scripts/switch_to_light.sh
elif [[ "$lord" == "d" || "$lord" == "D" ]]; then
    ~/Code/my_dotfiles/Scripts/switch_to_dark.sh
fi

# Reloads Kitty so that the theme applies without needing to close and reopen
kitty @ load-config
