[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

if [ -d "${HOME}/.local/bin" ] && [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
    PATH="${HOME}/.local/bin:${PATH}"
fi

# Added by JetBrains Toolbox App
if [ -d "$HOME/.local/share/JetBrains/Toolbox/scripts" ]; then
    PATH="$PATH:$HOME/.local/share/JetBrains/Toolbox/scripts"
fi

[ -f "$HOME/.bin/env" ] && . "$HOME/.bin/env"
