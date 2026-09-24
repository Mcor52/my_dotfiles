# my_dotfiles

Personal dotfiles for Fedora + KDE Plasma, managed with **GNU Stow**. Themed
around Gruvbox Material (dark) with Catppuccin (light) variants.

> **Public repo.** Every tracked file is scanned for secrets before it can be
> committed — see [Security](#security).

## What's here

```
Configs/          Stow packages (each mirrors $HOME)
  Bash/           .bashrc, .bash_profile, .profile, .bash_logout
  Btop/           btop.conf + noctalia / catppuccin-latte themes
  Desktop/        .desktop entries
  Git/            .gitconfig
  Gtk/            GTK3/4 settings + .gtkrc-2.0
  Htop/           htoprc
  Kitty/          kitty terminal (config + included theme)
  Lazygit/        lazygit config + theme
  Mpv/            mpv config
  Ncspot/         ncspot config (no credentials)
  Nvim/           LazyVim-based Neovim config
  Starship/       starship prompt
  Zsh/            .zshrc, .zshenv, .zprofile, .zsh_plugins.txt

Themes/           dark/light variants consumed by Scripts/theme.sh
  Kitty/          kitty-dark.conf, kitty-light.conf
  Starship/       starship-dark.toml, starship-light.toml

Aesthetics/       wallpapers (large media is gitignored)
Scripts/          setup + maintenance scripts (below)
.githooks/        pre-commit hook running the secret scanner
```

## Requirements

Install the tools the config actually depends on:

```bash
./Scripts/installapps.sh
```

This installs the DNF packages, Flatpaks, Starship and Antidote, and offers to
change your shell to zsh. Use `--cli-only`, `--flatpaks-only` or `-n` to narrow
or preview what it does.

## Setup

```bash
chmod +x Scripts/*.sh Scripts/stow.zsh Scripts/*.py
./Scripts/stow.zsh -n     # preview which symlinks would be created
./Scripts/stow.zsh        # stow every package in Configs/
exec zsh
```

`stow.zsh` backs up any real (non-symlink) file it would replace into
`~/.dotfiles_backup/<timestamp>/`, so it is safe to run on an existing machine.

To work on a single package: `./Scripts/stow.zsh -R Kitty`, or `-D Kitty` to
remove it.

## Scripts

| Script | Purpose |
| --- | --- |
| `installapps.sh` | Install packages, Flatpaks, Starship, Antidote; set shell to zsh |
| `stow.zsh` | Stow / restow / unstow packages, with automatic conflict backups |
| `backup-configs.sh` | Sync live configs from `$HOME` back into `Configs/` |
| `theme.sh` | Switch the whole desktop between dark and light |
| `fedora-tune.sh` | System update, cleanup and health check (dnf4 + dnf5) |
| `setup-fedora-tune.sh` | Install `fedora-tune.sh` as a systemd timer / `up` command |
| `switch_audio.sh` | Cycle the default PipeWire/PulseAudio output sink |
| `leak-guard.py` | Secret / PII scanner (see below) |

### Theme switching

```bash
./Scripts/theme.sh dark      # apply dark theme
./Scripts/theme.sh light     # apply light theme
./Scripts/theme.sh toggle    # flip to the other
./Scripts/theme.sh status    # which is active
./Scripts/theme.sh -n dark   # preview, change nothing
```

Updates Kitty, Starship, btop, GTK and the KDE colour scheme + cursor together.
The active theme is recorded in `~/.config/theme.current`.

### System maintenance

`fedora-tune.sh` wraps updates and cleanup for both dnf4 (Fedora <= 40) and dnf5
(Fedora 41+). `setup-fedora-tune.sh` installs it as `fedora-tune` on `$PATH` and
can schedule it via a systemd timer.

In `zsh` there are shortcuts (see `.zshrc`): `up`, `up-dry`, `up-deep`,
`up-quick`, `up-clean`.

## Security

This repository is **public**, so the following are enforced:

1. **`.gitignore`** excludes keys, tokens, cookies, shell history, app session
   state and large media before they can ever be tracked.
2. **`Scripts/leak-guard.py`** scans for private keys, tokens, credentials,
   AI-redaction damage and personal data (emails, IPs, MACs, absolute home
   paths). It fails a commit on *blocking* findings and warns otherwise.
3. **`.githooks/pre-commit`** runs the scanner on staged changes. Enable it with:

   ```bash
   git config core.hooksPath .githooks
   ```

Run the scanner yourself any time:

```bash
python3 Scripts/leak-guard.py --tree      # scan the working tree
python3 Scripts/leak-guard.py --staged    # scan staged changes only
python3 Scripts/leak-guard.py --history   # scan the full git history
python3 Scripts/leak-guard.py --path FILE # scan specific paths
```

Never commit: live app passwords, OAuth client secrets, API keys, `gh` host
tokens, or shell history. Instead, keep machine-specific values in an untracked
file (e.g. `~/.dotfiles.local`) and source it from the relevant dotfile.

## License

See [LICENSE](LICENSE).
