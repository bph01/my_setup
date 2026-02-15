# Linux Setup

Single-script setup for a terminal-driven Linux workflow: tmux + Neovim + bash aliases + MATE Terminal.

## Usage

```bash
git clone git@github.com:bph01/my_setup.git && bash my_setup/setup.sh
```

## What it does

1. **Installs packages** via the detected package manager (pacman/dnf/apt):
   tmux, neovim, xclip, wl-clipboard, ripgrep, fd, build tools, cmake, mate-terminal

2. **Deploys `~/.tmux.conf`** — vim-style keybindings, mouse support, gruvbox colors, clipboard integration (auto-detects Wayland vs X11)

3. **Deploys Neovim config** (`~/.config/nvim/`) with [lazy.nvim](https://github.com/folke/lazy.nvim) and plugins:
   - [gruvbox.nvim](https://github.com/ellisonleao/gruvbox.nvim) — colorscheme
   - [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) — fuzzy finder (`<leader>ff`, `<leader>fg`, `<leader>fb`, `<leader>fh`)
   - [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) — syntax highlighting

4. **Deploys `~/.bash_aliases`** and ensures `~/.bashrc` sources it:

   | Category | Aliases |
   |---|---|
   | Listing | `lt` `ll` `la` `l` |
   | Navigation | `..` `...` `....` |
   | Safety | `rm` `cp` `mv` (interactive) |
   | Disk/process | `df` `du` `free` `psg` |
   | Git | `gs` `gl` `gd` `ga` `gc` `gp` |
   | Misc | `cls` `h` `path` |

5. **Configures MATE Terminal** — gruvbox colors, optional auto-launch of tmux, sets as default terminal on Debian/Ubuntu

## Re-running

The script is idempotent. Running it again updates all configs in place and won't duplicate the `.bashrc` sourcing block.
