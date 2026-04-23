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

ln -s ~/Dotfiles/Configs/Zsh/.zshrc ~/
source ~/.zshrc

ln -s $DOT/Configs/Hypr ~/.config/hypr

ln -s $DOT/Configs/Kitty ~/.config/kitty

ln -s $DOT/Configs/Nvim ~/.config/nvim

ln -s $DOT/Configs/Rofi ~/.config/rofi

ln -s $DOT/Configs/Spotify/Spicetify ~/.config/spicetify

ln -s $DOT/Configs/Spotify/spotify-launcher.desktop ~/.local/share/applications/

ln -s $DOT/Configs/Waybar ~/.config/waybar

ln -s $DOT/Configs/Yazi ~/.config/yazi

ln -s $DOT/Configs/Zsh/.zsh_plugins.txt
ln -s $DOT/Configs/Zsh/.zsh_plugins.zsh

# Finally, ask the user if they'd like a dark or light theme, then running the previously made scripts based on the choice

echo "Would you like a dark or light theme?"
read -p "[L/D] " lord
if [[ "$lord" == "l" || "$lord" == "L" ]]; then
    ~/Dotfiles/Scripts/switch_to_light.sh
elif [[ "$lord" == "d" || "$lord" == "D" ]]; then
    ~/Dotfiles/Scripts/switch_to_dark.sh
fi

# Reloads Kitty so that the theme applies without needing to close and reopen
kitty @ load-config
