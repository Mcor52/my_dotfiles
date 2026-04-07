# Fix Starship + zsh-vi-mode conflict before antidote or starship even load
ZVM_VI_HIGHLIGHT_FOREGROUND=white 
ZVM_VI_HIGHLIGHT_BACKGROUND=blue
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT

# Source (pull info from) the antidote.zsh, and load the plugin manager itself
source /usr/share/zsh-antidote/antidote.zsh
antidote load

# Setting defaults. For example, nvim is default editor for sudoedit and yazi
export EDITOR="nvim"
export VISUAL="nvim"
export PATH="$HOME/bin:$HOME/.spicetify:$PATH"

# A function to let me access my config files easier by typing config "letter" in the terminal
config() {
  case $1 in
    h)
      nvim ~/.config/hypr/hyprland.conf
      ;;
    k)
      nvim ~/.config/kitty/kitty.conf
      ;;
    z) 
      nvim ~/.zshrc
      ;;
    --help|-h)
      echo "Open configs:\nh = hyprland.conf\nk = kitty.conf\nz = .zshrc\n--help or -h to see these again"
      ;;
    *)
      echo "Option does not exist. Please type config -h or --help to see available options."
      ;;
  esac
}

# Start Starship the Prompt Editor
eval "$(starship init zsh)"
