
# Add ~/.local/bin to PATH
if [ -d "${HOME}/.local/bin" ] && [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
    PATH="${HOME}/.local/bin:${PATH}"
fi


# Added by Toolbox App
export PATH="$PATH:${HOME}/.local/share/JetBrains/Toolbox/scripts"

