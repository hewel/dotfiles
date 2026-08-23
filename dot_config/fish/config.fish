source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
function fish_greeting
    return
end

set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH

zoxide init fish | source

starship init fish | source

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
set -gx XDG_DATA_DIRS $HOME/.local/share $XDG_DATA_DIRS

# Added by Antigravity CLI installer
set -gx PATH "/home/hewel/.local/bin" $PATH

# pnpm
set -gx PNPM_HOME "/home/hewel/.local/share/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
    set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end

set -gx PATH "/home/hewel/.extra/bin" $PATH

# kimi-code
fish_add_path -g "/home/hewel/.kimi-code/bin"

# >>> grok installer >>>
fish_add_path $HOME/.grok/bin
# <<< grok installer <<<

if status is-interactive
    atuin init fish | source
end
