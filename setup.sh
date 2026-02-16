#!/usr/bin/env bash
set -euo pipefail

echo "=== Linux Setup: tmux + neovim + bash aliases + MATE Terminal ==="

# --- Detect package manager ---
detect_pkg_manager() {
    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apt-get &>/dev/null; then
        echo "apt"
    else
        echo "unknown"
    fi
}

PKG_MANAGER="$(detect_pkg_manager)"
echo "Detected package manager: $PKG_MANAGER"

# --- Install packages ---
echo "Installing packages..."

PACMAN_PKGS=(
    tmux neovim xclip wl-clipboard ripgrep fd base-devel cmake git mate-terminal
)
DNF_PKGS=(
    tmux neovim xclip wl-clipboard ripgrep fd-find gcc gcc-c++ make cmake git mate-terminal
)
APT_PKGS=(
    tmux neovim xclip wl-clipboard ripgrep fd-find build-essential cmake git mate-terminal
)
ZYPPER_PKGS=(
    tmux neovim xclip wl-clipboard ripgrep fd gcc gcc-c++ make cmake git mate-terminal
)

case "$PKG_MANAGER" in
    pacman)
        echo "Package set: ${PACMAN_PKGS[*]}"
        sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"
        ;;
    dnf)
        echo "Package set: ${DNF_PKGS[*]}"
        sudo dnf install -y "${DNF_PKGS[@]}"
        ;;
    zypper)
        echo "Package set: ${ZYPPER_PKGS[*]}"
        sudo zypper --non-interactive install "${ZYPPER_PKGS[@]}"
        ;;
    apt)
        sudo apt-get update
        echo "Package set: ${APT_PKGS[*]}"
        sudo apt-get install -y "${APT_PKGS[@]}"
        ;;
    *)
        echo "Error: Unsupported package manager. Install packages manually."
        exit 1
        ;;
esac

# --- Post-install sanity checks ---
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: missing required command '$cmd' after package install."
        return 1
    fi
    return 0
}

missing_any=0
for cmd in nvim git cmake rg; do
    if ! require_cmd "$cmd"; then
        missing_any=1
    fi
done

if ! command -v fd &>/dev/null && ! command -v fdfind &>/dev/null; then
    echo "Error: neither 'fd' nor 'fdfind' is available after package install."
    missing_any=1
fi

if [ "$missing_any" -ne 0 ]; then
    echo "Please install missing packages manually for your distro and re-run setup."
    exit 1
fi

# --- Neovim version detection ---
version_ge() {
    local current="$1"
    local minimum="$2"
    [ "$(printf '%s\n' "$minimum" "$current" | sort -V | head -n1)" = "$minimum" ]
}

NVIM_VERSION_LINE="$(nvim --version | head -n1)"
NVIM_VERSION="$(awk '{print $2}' <<<"$NVIM_VERSION_LINE" | sed 's/^v//')"
MIN_NVIM_VERSION="0.8.0"
NVIM_COMPAT_MODE=0
echo "Detected Neovim version: $NVIM_VERSION"
if ! version_ge "$NVIM_VERSION" "$MIN_NVIM_VERSION"; then
    NVIM_COMPAT_MODE=1
    echo "Warning: Neovim $NVIM_VERSION is older than recommended $MIN_NVIM_VERSION."
    echo "Warning: compatibility mode enabled (plugin manager bootstrap disabled)."
fi

# --- Detect display server for clipboard ---
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    CLIP_COPY="wl-copy"
    CLIP_PASTE="wl-paste"
    echo "Detected Wayland — using wl-clipboard"
else
    CLIP_COPY="xclip -selection clipboard"
    CLIP_PASTE="xclip -selection clipboard -o"
    echo "Detected X11 (or unknown) — using xclip"
fi

# --- Deploy .tmux.conf ---
echo "Installing tmux config..."
cat > "$HOME/.tmux.conf" <<EOF
# --- General ---
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g mouse on
set -g history-limit 10000
set -g escape-time 10
set -g focus-events on

# --- Vim mode ---
set -g mode-keys vi

# --- Splits ---
# prefix + v = vertical split, prefix + s = horizontal split
unbind '"'
unbind %
bind v split-window -h -c "#{pane_current_path}"
bind s split-window -v -c "#{pane_current_path}"

# --- Pane resize with HJKL ---
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# --- Copy mode (vim-like) ---
bind [ copy-mode
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "$CLIP_COPY"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "$CLIP_COPY"

# Paste with prefix + p (in addition to default prefix + ])
bind p run "tmux set-buffer \"\$($CLIP_PASTE)\"; tmux paste-buffer"

# --- Colors (gruvbox dark) ---
set -g status-style "bg=#282828,fg=#ebdbb2"
set -g window-status-current-style "bg=#458588,fg=#282828,bold"
set -g pane-border-style "fg=#504945"
set -g pane-active-border-style "fg=#458588"
set -g mode-style "bg=#d79921,fg=#282828"
set -g message-style "bg=#504945,fg=#ebdbb2"

# --- Reload config ---
bind r source-file ~/.tmux.conf \; display "Config reloaded"
EOF

# --- Deploy neovim config ---
echo "Installing neovim config..."
mkdir -p "$HOME/.config/nvim/lua/plugins"

cat > "$HOME/.config/nvim/init.lua" <<EOF
-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Clipboard: share with system
vim.opt.clipboard = "unnamedplus"

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Tabs / indentation
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- UI
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.updatetime = 250
vim.opt.splitright = true
vim.opt.splitbelow = true

local compat_mode = ${NVIM_COMPAT_MODE}
if compat_mode == 1 then
    vim.schedule(function()
        vim.notify(
            "Neovim compatibility mode is active: skipping lazy.nvim/plugin bootstrap.",
            vim.log.levels.WARN
        )
    end)
    return
end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv then
    vim.api.nvim_err_writeln("Could not initialize libuv handle for lazy.nvim bootstrap.")
    return
end

if not uv.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_err_writeln("Failed to clone lazy.nvim. Check network and git setup.")
        return
    end
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins
local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
    vim.api.nvim_err_writeln("lazy.nvim is not available; skipping plugin setup.")
    return
end
lazy.setup("plugins")
EOF

cat > "$HOME/.config/nvim/lua/plugins/init.lua" <<'EOF'
return {
    -- Colorscheme: gruvbox
    {
        "ellisonleao/gruvbox.nvim",
        priority = 1000,
        config = function()
            require("gruvbox").setup({})
            vim.cmd("colorscheme gruvbox")
        end,
    },

    -- Telescope: fuzzy finder
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            {
                "nvim-telescope/telescope-fzf-native.nvim",
                build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
            },
        },
        config = function()
            local telescope = require("telescope")
            telescope.setup({
                defaults = {
                    file_ignore_patterns = { "node_modules", ".git/" },
                },
            })
            local ok_fzf = pcall(telescope.load_extension, "fzf")
            if not ok_fzf then
                vim.schedule(function()
                    vim.notify(
                        "telescope-fzf-native is unavailable; Telescope will run without fzf extension.",
                        vim.log.levels.WARN
                    )
                end)
            end

            local builtin = require("telescope.builtin")
            vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
            vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
            vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
            vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
        end,
    },

    -- Treesitter: syntax highlighting
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            local ok_ts, ts_configs = pcall(require, "nvim-treesitter.configs")
            if not ok_ts then
                vim.schedule(function()
                    vim.notify("nvim-treesitter is unavailable; skipping treesitter setup.", vim.log.levels.WARN)
                end)
                return
            end
            ts_configs.setup({
                ensure_installed = { "lua", "python", "javascript", "typescript", "bash", "json", "yaml", "markdown" },
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },
}
EOF

# --- Deploy .bash_aliases ---
echo "Installing bash aliases..."
cat > "$HOME/.bash_aliases" <<'EOF'
# --- Listing ---
alias lt='ls -altr'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- Safety ---
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# --- Disk / process ---
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias psg='ps aux | grep -v grep | grep -i'

# --- Git ---
alias gs='git status'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# --- Misc ---
alias cls='clear'
alias h='history'
alias path='echo -e "${PATH//:/\\n}"'
EOF

# --- Ensure .bashrc sources .bash_aliases ---
if ! grep -q '\.bash_aliases' "$HOME/.bashrc" 2>/dev/null; then
    echo "Adding .bash_aliases sourcing to .bashrc..."
    cat >> "$HOME/.bashrc" <<'EOF'

# Source bash aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
else
    echo ".bashrc already sources .bash_aliases — skipping."
fi

# --- Optionally configure MATE Terminal to launch tmux ---
read -rp "Launch tmux automatically in MATE Terminal? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    dconf write /org/mate/terminal/profiles/default/use-custom-command true
    dconf write /org/mate/terminal/profiles/default/custom-command "'tmux new-session -A -s main'"
    echo "MATE Terminal will now launch tmux on startup."
fi

# --- MATE Terminal colors (gruvbox dark) ---
echo "Setting MATE Terminal colors..."
dconf write /org/mate/terminal/profiles/default/use-theme-colors false
dconf write /org/mate/terminal/profiles/default/background-color "'#282828'"
dconf write /org/mate/terminal/profiles/default/foreground-color "'#ebdbb2'"

# --- Set MATE Terminal as default (Debian/Ubuntu only) ---
if [ "$PKG_MANAGER" = "apt" ]; then
    echo "Setting MATE Terminal as default terminal emulator..."
    sudo update-alternatives --set x-terminal-emulator /usr/bin/mate-terminal 2>/dev/null || \
        sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/mate-terminal 50
fi

echo ""
echo "=== Setup complete ==="
echo "Start a new terminal or run: tmux new-session -A -s main"
echo "Then open neovim: nvim"
echo "If you see Neovim issues, run :checkhealth and inspect :messages"
