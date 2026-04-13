#!/bin/bash

# Using symlinks to change what the config file sources to easily switch the theme

# Kitty
rm -f ~/.config/kitty/kitty-theme.conf
ln -s ~/Dotfiles/Themes/Kitty/kitty-dark-theme.conf ~/.config/kitty/kitty-theme.conf

# Reloads Kitty so that the theme applies without needing to close and reopen
killall -SIGUSR1 kitty

# Nvim
rm -f ~/.config/nvim/lua/themes/current.lua
ln -s ~/Dotfiles/Themes/Nvim/lua/themes/dark.lua ~/.config/nvim/lua/themes/current.lua

# Starship
rm -f ~/.config/starship.toml
ln -s ~/Dotfiles/Themes/Starship/starship-dark.toml ~/.config/starship.toml

# Waybar
rm -f ~/.config/waybar/style.css
ln -s  ~/Dotfiles/Themes/Waybar/style-dark.css ~/.config/waybar/style.css
killall waybar
~/Dotfiles/Scripts/launch-waybar.sh &

# Yazi
rm -f ~/.config/yazi/theme.toml
ln -s ~/Dotfiles/Themes/Yazi/theme-dark.toml ~/.config/yazi/theme.toml
