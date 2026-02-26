# Dotfiles

My personal Linux dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Overview

A modern Wayland-focused configuration with the following components:

- **Niri** - Scrollable-tiling Wayland compositor
- **Anyrun** - Wayland-native application launcher
- **Ghostty** - Modern GPU-accelerated terminal emulator
- **Helix** - Modal text editor with tree-sitter support
- **Spotify Launcher** - Spotify with Wayland support
- **Paru** - AUR helper configuration
- **Custom theming** via DMS (Dynamic Module System)

## Prerequisites

- Linux distribution with Wayland support
- [chezmoi](https://www.chezmoi.io/) for dotfile management
- Niri compositor
- Ghostty terminal
- Anyrun launcher

## Installation

```bash
# Install chezmoi
# Arch/Arch-based: pacman -S chezmoi
# Nix: nix-env -iA nixpkgs.chezmoi

# Clone and apply dotfiles
chezmoi init git@github.com:hewel/dotfiles.git
chezmoi apply
```

## Components

### Niri (Wayland Compositor)

- Modular configuration split into logical sections in `dot_config/niri/cfg/`:
  - `animation.kdl` - Window animations and transitions
  - `autostart.kdl` - Autostart applications
  - `display.kdl` - Display settings
  - `input.kdl` - Keyboard and input device configuration
  - `keybinds.kdl` - Keybindings
  - `layout.kdl` - Layout behavior
  - `misc.kdl` - Miscellaneous settings
  - `rules.kdl` - Window rules
- DMS modules in `dot_config/niri/dms/` for dynamic theming and behaviors
  - `alttab.kdl` - Alt-tab behavior
  - `binds.kdl` - Custom bindings
  - `colors.kdl` - Color schemes
  - `cursor.kdl` - Cursor settings
  - `layout.kdl` - Layout preferences
  - `outputs.kdl` - Output/display configuration
  - `windowrules.kdl` - Per-window rules
  - `wpblur.kdl` - Wallpaper blur effects

### Anyrun (Launcher)

- Centered horizontal launcher with 800px width
- Plugins enabled: applications, shell, translate, niri focus
- Custom keybindings for navigation and selection
- See `dot_config/anyrun/config.ron` for details

### Ghostty (Terminal)

- Font size: 12px
- Custom "dankcolors" theme
- Background blur radius: 32px
- Window padding: 12px
- Shell integration enabled
- Keybindings for font size adjustment
- See `dot_config/ghostty/config` for full configuration

### Helix (Editor)

- Modal text editor with tree-sitter syntax highlighting
- Custom "onedark_transparent" theme
- See `dot_config/helix/config.toml` for configuration

### Other Configurations

- **Spotify Launcher**: Enabled with Wayland Ozone platform and IME support
- **Fontconfig**: Local font configuration
- **Paru**: AUR helper with SkipReview enabled
- **Environment**: Sets `ELECTRON_OZONE_PLATFORM_HINT=auto` and `TERMINAL=ghostty`

## Structure

```
dot_config/
├── anyrun/config.ron          # Anyrun launcher configuration
├── environment.d/90-dms.conf  # Environment variables
├── fontconfig/local.conf      # Font configuration
├── ghostty/
│   ├── config                 # Main Ghostty config
│   └── themes/dankcolors      # Custom theme
├── helix/
│   ├── config.toml            # Main Helix config
│   └── themes/                # Custom themes
│       └── onedark_transparent.toml
├── niri/
```

## Customization

### Changing Keybindings

Edit `dot_config/niri/cfg/keybinds.kdl` or `dot_config/niri/dms/binds.kdl`

### Theming

Modify colors in `dot_config/niri/dms/colors.kdl` or update the Ghostty theme in `dot_config/ghostty/themes/`

### Display Configuration

Adjust outputs in `dot_config/niri/dms/outputs.kdl` or `dot_config/niri/cfg/display.kdl`

## License

MIT
