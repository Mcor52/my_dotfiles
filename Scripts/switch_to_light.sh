#!/bin/bash

# Using symlinks to change what the config file sources to easily switch the theme

# Kitty
rm -f ~/.config/kitty/kitty-theme.conf
ln -s $DOT/Themes/Kitty/kitty-light-theme.conf ~/.config/kitty/kitty-theme.conf

# Reloads Kitty so that the theme applies without needing to close and reopen
killall -SIGUSR1 kitty

# Nvim
rm -f ~/.config/nvim/lua/themes/current.lua
ln -s $DOT/Themes/Nvim/lua/themes/light.lua ~/.config/nvim/lua/themes/current.lua

# Starship
rm -f ~/.config/starship.toml
ln -s $DOT/Themes/Starship/starship-light.toml ~/.config/starship.toml

# Waybar
rm -f ~/.config/waybar/colors.css
ln -s  $DOT/Themes/Waybar/light.css $DOT/Configs/Waybar/colors.css
killall waybar
$DOT/Scripts/launch-waybar.sh &

# Yazi
rm -f ~/.config/yazi/theme.toml
ln -s $DOT/Themes/Yazi/theme-light.toml ~/.config/yazi/theme.toml
