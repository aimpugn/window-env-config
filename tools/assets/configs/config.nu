# config.nu
#
# Installed by:
# version = "0.102.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

const NU_PLUGIN_DIRS = [
  ($nu.current-exe | path dirname)
  ...$NU_PLUGIN_DIRS
]

$env.config.buffer_editor = ["code"]
# Remove welcome message
# - https://www.nushell.sh/book/configuration.html#remove-welcome-message
$env.config.show_banner = false

# tools/install.nu renders this placeholder to the selected tools home.
const TOOLS_DIR = "__WINDOW_ENV_CONFIG_TOOLS_DIR__"
const BIN_DIR = ([$TOOLS_DIR "bin"] | path join)
const ASSETS_DIR = ([$TOOLS_DIR "assets"] | path join)

$env.WINDOW_ENV_CONFIG_TOOLS_DIR = $TOOLS_DIR
$env.WINDOW_ENV_CONFIG_BIN_DIR = $BIN_DIR
$env.PATH = ($env.PATH | append $BIN_DIR | uniq)

use ([$ASSETS_DIR "nu/nu_scripts/aliases/git/git-aliases.nu"] | path join ) *
use ([$ASSETS_DIR "nu/custom_command/renmpkg.nu"] | path join ) *

source ([$ASSETS_DIR "nu/possibles.nu"] | path join )
source ([$ASSETS_DIR "configs/.oh-my-posh.nu"] | path join )

# self defined utils
source ([$ASSETS_DIR "configs/aliases.nu"] | path join )
source ([$ASSETS_DIR "nu/functions.nu"] | path join )
