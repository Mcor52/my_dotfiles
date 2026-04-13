#!/bin/bash

# Using symlinks to change what the config file sources to easily switch the theme

# Kitty
rm -f ~/.config/kitty/kitty-theme.conf
ln -s ~/Code/my_dotfiles/Themes/Kitty/kitty-light-theme.conf ~/.config/kitty/kitty-theme.conf

# Reloads Kitty so that the theme applies without needing to close and reopen
killall -SIGUSR1 kitty

# Nvim
rm -f ~/.config/nvim/lua/themes/current.lua
ln -s ~/Code/my_dotfiles/Themes/Nvim/lua/themes/light.lua ~/.config/nvim/lua/themes/current.lua

# Starship
rm -f ~/.config/starship.toml
ln -s ~/Code/my_dotfiles/Themes/Starship/starship-light.toml ~/.config/starship.toml

# Waybar
rm -f ~/.config/waybar/style.css
ln -s  ~/Code/my_dotfiles/Themes/Waybar/style-light.css ~/.config/waybar/style.css
killall waybar
~/Code/my_dotfiles/Scripts/launch-waybar.sh &

# Yazi
rm -f ~/.config/yazi/theme.toml
ln -s ~/Code/my_dotfiles/Themes/Yazi/theme-light.toml ~/.config/yazi/theme.toml
