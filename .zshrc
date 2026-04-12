# Fix Starship + zsh-vi-mode conflict before antidote or starship even load
ZVM_VI_HIGHLIGHT_FOREGROUND=white 
ZVM_VI_HIGHLIGHT_BACKGROUND=blue
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT

# Series of colours to edit syntax highlighting before antidote loads the plugin
typeset -A FAST_HIGHLIGHT_STYLES

FAST_HIGHLIGHT_STYLES[command]='fg=#ea6962'
FAST_HIGHLIGHT_STYLES[builtin]='fg=#ea6962'
FAST_HIGHLIGHT_STYLES[function]='fg=#ea6962'

FAST_HIGHLIGHT_STYLES[arg0]='fg=#ea6962'

FAST_HIGHLIGHT_STYLES[path]='fg=#d8a567'
FAST_HIGHLIGHT_STYLES[path_pathseparator]='fg=#d8a567'

FAST_HIGHLIGHT_STYLES[string]='fg=#e78a4e'
FAST_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#e78a4e'
FAST_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#e78a4e'

FAST_HIGHLIGHT_STYLES[variable]='fg=#b16286'
FAST_HIGHLIGHT_STYLES[assign]='fg=#b16286'

FAST_HIGHLIGHT_STYLES[alias]='fg=#e67e80'

FAST_HIGHLIGHT_STYLES[reserved-word]='fg=#ea6962'
FAST_HIGHLIGHT_STYLES[precommand]='fg=#ea6962'

FAST_HIGHLIGHT_STYLES[comment]='fg=#7c6f64'

FAST_HIGHLIGHT_STYLES[unknown-token]='fg=#ea6962'

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#7c6f64'

HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=#1d2021,bg=#d8a567'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=#ea6962,bold'

ZVM_CURSOR_STYLE_ENABLED=true

ZVM_CURSOR_STYLE_DEFAULT=block
ZVM_CURSOR_STYLE_INSERT=beam
ZVM_CURSOR_STYLE_VISUAL=underline

ZVM_CURSOR_COLOR='#ea6962'

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

# Simple aliases to switch between light and dark mode, and one for full setup
alias light='$HOME/Code/my_dotfiles/Scripts/switch_to_light.sh'
alias dark='$HOME/Code/my_dotfiles/Scripts/switch_to_dark.sh'
alias setup='$HOME/Code/my_dotfiles/Scripts/setup.sh'

# Start Starship the Prompt Editor
eval "$(starship init zsh)"
