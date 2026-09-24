# Series of colours to edit syntax highlighting before antidote loads the plugin
typeset -A FAST_HIGHLIGHT_STYLES

# Commands, builtins, functions, and main args get red
FAST_HIGHLIGHT_STYLES[command]='fg=#ea6962'
FAST_HIGHLIGHT_STYLES[builtin]='fg=#ea6962'
FAST_HIGHLIGHT_STYLES[function]='fg=#ea6962'
FAST_HIGHLIGHT_STYLES[arg0]='fg=#ea6962'

# File paths and slashes get yellow/gold
FAST_HIGHLIGHT_STYLES[path]='fg=#d8a567'
FAST_HIGHLIGHT_STYLES[path_pathseparator]='fg=#d8a567'

# Text strings and quotes get orange
FAST_HIGHLIGHT_STYLES[string]='fg=#e78a4e'
FAST_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#e78a4e'
FAST_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#e78a4e'

# Variables and assignments get purple
FAST_HIGHLIGHT_STYLES[variable]='fg=#b16286'
FAST_HIGHLIGHT_STYLES[assign]='fg=#b16286'

# Aliases get a slightly lighter red/pink
FAST_HIGHLIGHT_STYLES[alias]='fg=#e67e80'

# Keywords like 'if' or 'for' and precommands get red
FAST_HIGHLIGHT_STYLES[reserved-word]='fg=#ea6962'
FAST_HIGHLIGHT_STYLES[precommand]='fg=#ea6962'

# Code comments get muted grey
FAST_HIGHLIGHT_STYLES[comment]='fg=#7c6f64'

# Typos or invalid commands turn red
FAST_HIGHLIGHT_STYLES[unknown-token]='fg=#ea6962'

# Color for ghost text predictions from autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#7c6f64'

# Colors for ctrl+r / history substring search matches
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=#1d2021,bg=#d8a567'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=#ea6962,bold'

# Initialize Zsh completions BEFORE loading antidote plugins
autoload -Uz compinit && compinit
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# Setting defaults
export EDITOR="nvim"
export VISUAL="$EDITOR"
export BROWSER="firefox"
export TERMINAL="kitty"
export PAGER="bat --style=numbers,changes --theme=gruvbox-dark --color=always"
export DOT="$HOME/Dotfiles"
export DOTCONF="$HOME/Dotfiles/Configs"

# Deduplicated PATH management
typeset -U path PATH
path=(
    "$DOT/Scripts"
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/.spicetify"
    "$HOME/.opencode/bin"
    $path
)
export PATH

# Source environment from local binaries if present
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# FZF theme
export FZF_DEFAULT_OPTS="
--color=bg+:#3c3836,bg:#282828,spinner:#fe8019,hl:#83a598
--color=fg:#ebdbb2,header:#83a598,info:#8ec07c,pointer:#fe8019
--color=marker:#fe8019,query:#ebdbb2
"

# Fedora system maintenance (syncs script from $DOT to /usr/local/bin if changed)
up() {
  local src="$DOT/Scripts/fedora-tune.sh" dst=/usr/local/bin/fedora-tune
  if ! cmp -s "$src" "$dst" 2>/dev/null; then
    echo "Syncing fedora-tune -> $dst"
    sudo install -m 755 "$src" "$dst" || return
  fi
  sudo "$dst" "$@"
}
alias up-dry='up --dry-run'
alias up-deep='up --deep --containers --dev-caches'
alias up-quick='up --no-cleanup --no-firmware'
alias up-clean='up --no-update'

# A function to let me access my config files easier by typing config "letter" in the terminal
config() {
    case $1 in
        a)
            nvim ~/.zsh_plugins.txt
            ;;
        b)
            nvim ~/.config/btop/btop.conf
            ;;
        k)
            nvim ~/.config/kitty/kitty.conf
            ;;
        lg)
            nvim ~/.config/lazygit/config.yml
            ;;
        m)
            nvim ~/.config/mpv/mpv.conf
            ;;
        ma)
            nvim ~/.config/mimeapps.list
            ;;
        nc)
            nvim ~/.config/ncspot/config.toml
            ;;
        ni)
            nvim ~/.config/nvim/init.lua
            ;;
        s)
            nvim ~/.config/starship.toml
            ;;
        ft)
            nvim "$DOT/Scripts/fedora-tune.sh"
            ;;
        z)
            nvim ~/.zshrc
            ;;
        zs)
            source ~/.zshrc
            ;;
        --help|-h)
            echo "Open configs:"
            echo "a  = zsh_plugins.txt"
            echo "b  = btop.conf"
            echo "ft = fedora-tune.sh"
            echo "k  = kitty.conf"
            echo "lg = lazygit config.yml"
            echo "m  = mpv.conf"
            echo "ma = mimeapps.list"
            echo "nc = ncspot config.toml"
            echo "ni = nvim init.lua"
            echo "s  = starship.toml"
            echo "z  = .zshrc"
            echo "zs = source .zshrc"
            echo "--help or -h to see these again"
            ;;
        *)
            echo "Option does not exist. Please type config -h or --help to see available options."
            ;;
    esac
}

# Shell and Dotfiles aliases
alias cdf='cd $DOT'
alias sz='source ~/.zshrc'
alias clear='clear && printf "\e[3J"'
alias n='flatpak run io.github.hrkfdn.ncspot'
alias ncspot='flatpak run io.github.hrkfdn.ncspot'
alias dot-stow='$DOT/Scripts/stow.zsh'
alias dot-backup='$DOT/Scripts/backup-configs.sh'

# Start Starship prompt
eval "$(starship init zsh)"

# Startup and settings for the zsh-autosuggestions plugin

ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Get the autocompletion folders and files coloured to my preferred theme
export LS_COLORS="di=38;5;167:fi=38;5;208:ex=38;5;167;1:ln=38;5;108"

# Menu settings for autocompletion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}── %d ──%f'
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Source antidote and load plugins HERE before binding keys
source ~/.antidote/antidote.zsh
antidote load

# Keybindings for history search and tab autocompletion (MUST be below antidote load)
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^I' expand-or-complete
bindkey '^[[Z' reverse-menu-complete

# When using "touch", if the directory that the file resides in doesnt exist, make it
# Literally the best function I've ever made lol
touch() {
  for file in "$@"; do
    if [[ "$file" == */* ]]; then
      mkdir -p -- "${file%/*}"
    fi
  done
  command touch "$@"
}
