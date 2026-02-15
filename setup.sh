#!/usr/bin/env bash
set -euo pipefail

echo "=== Linux Setup: tmux + neovim + bash aliases + MATE Terminal ==="

# --- Detect package manager ---
detect_pkg_manager() {
    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
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
case "$PKG_MANAGER" in
    pacman)
        sudo pacman -Syu --needed --noconfirm \
            tmux neovim xclip wl-clipboard ripgrep fd base-devel cmake mate-terminal
        ;;
    dnf)
        sudo dnf install -y \
            tmux neovim xclip wl-clipboard ripgrep fd-find gcc gcc-c++ make cmake mate-terminal
        ;;
    apt)
        sudo apt-get update
        sudo apt-get install -y \
            tmux neovim xclip wl-clipboard ripgrep fd-find build-essential cmake mate-terminal
        ;;
    *)
        echo "Error: Unsupported package manager. Install packages manually."
        exit 1
        ;;
esac

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

cat > "$HOME/.config/nvim/init.lua" <<'EOF'
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

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins
require("lazy").setup("plugins")
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
            telescope.load_extension("fzf")

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
            require("nvim-treesitter.configs").setup({
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
