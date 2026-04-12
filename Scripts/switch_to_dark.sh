#!/bin/bash

# Using symlinks to change what the config file sources to easily switch the theme
rm -f ~/.config/kitty/kitty-theme.conf
ln -s ~/Code/my_dotfiles/Themes/Kitty/kitty-dark-theme.conf ~/.config/kitty/kitty-theme.conf

# Reloads Kitty so that the theme applies without needing to close and reopen
killall -SIGUSR1 kitty

rm -f ~/.config/nvim/lua/themes/current.lua
ln -s ~/Code/my_dotfiles/Themes/Nvim/lua/themes/dark.lua ~/.config/nvim/lua/themes/current.lua

rm -f ~/.config/starship.toml
ln -s ~/Code/my_dotfiles/Themes/Starship/starship-dark.toml ~/.config/starship.toml

rm -f ~/.config/yazi/theme.toml
ln -s ~/Code/my_dotfiles/Themes/Yazi/theme-dark.toml ~/.config/yazi/theme.toml
