#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi

[ -f "$HOME/.bin/env" ] && . "$HOME/.bin/env"
