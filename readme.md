# winebox

This Bash script is a utility for managing Wine prefixes on Linux systems. It allows users to easily create, run, execute commands in, list, and remove Wine prefixes. Additionally, it provides integration with custom Wine builds (like GloriousEggroll’s Wine-GE) and DXVK for improved gaming performance. 

### Initial Setup

1. **Dependencies**:  
   Ensure the following dependencies are installed using your distribution’s package manager:
   - `wine`
   - `winetricks`
   - `curl`
   - `wget`
   - `tar`
   - `jq`
   - `strings`
   
   For example, on Debian/Ubuntu-based systems:
   ```bash
   sudo apt update
   sudo apt install wine winetricks curl wget tar jq binutils
   ```
   
   On Arch Linux:
   ```bash
   sudo pacman -S wine winetricks curl wget tar jq binutils
   ```

   on Fedora Linux:
   ```bash
   sudo dnf install wine winetricks curl wget tar jq binutils
   ```

2. **Download the Script**:  
   ```bash
   wget -O ~/.local/bin/winebox https://raw.githubusercontent.com/ergolyam/winebox/main/winebox.sh && \
   chmod +x ~/.local/bin/winebox
   ```

### Usage

The `winebox` script supports several commands, each with its own set of options:

```bash
winebox <command> [options]
```

**Commands:**

- `create` : Create a new Wine prefix.
- `exec`   : Execute a command in an existing Wine prefix.
- `rm`     : Remove an existing Wine prefix.
- `list`   : List all existing Wine prefixes.

**Common Options:**
- `--name` **<name>** : Specify the name of the Wine prefix.
- `--path` **<path>** : Specify the path where the Wine prefix will be stored.
- `--arch` **<win32|win64>** : Set the Wine prefix architecture.
- `--type` **<wine|wine-ge>** : Specify which Wine version to use (system wine or Wine-GE).
- `--sandbox` : Use a sandbox environment (via `winetricks sandbox`).
- `--dxvk` : Install and use DXVK for improved DirectX to Vulkan translation.
- `--chdir` : Change the working directory when executing a command (used with `exec`).

**Examples:**

1. **Create a new Wine prefix:**
   ```bash
   winebox create --name mygame --path ~/wineprefixes/mygame --arch win64 --type wine-ge --sandbox --dxvk
   ```
   This creates a `mygame` Wine prefix in `~/wineprefixes/mygame` using Wine-GE, sets it up as win64, applies a sandbox environment, and installs DXVK.

2. **Execute a command in a Wine prefix:**
   ```bash
   winebox exec --name mygame "C:\\windows\\system32\\notepad.exe"
   ```
   Runs `notepad.exe` inside the `mygame` prefix.

   Or change directory before executing:
   ```bash
   winebox exec --name mygame --chdir "C:\\Program Files\\MyGame" "MyGameLauncher.exe"
   ```

4. **List all existing Wine prefixes:**
   ```bash
   winebox list
   ```
   Displays a table of prefix names, paths, types, and detected application paths.

5. **Remove a Wine prefix:**
   ```bash
   winebox rm --name mygame
   ```
   Prompts for confirmation before deleting the prefix directory and removing it from the records.

### Features

- **Multiple Wine Versions**: Easily switch between standard Wine and custom Wine-GE builds.
- **DXVK Integration**: Automatically install and enable DXVK to improve DirectX performance on Linux.
- **Sandboxing**: Optionally run Wine prefixes in a restricted environment using `winetricks sandbox`.
- **User-Friendly**: Provides helpful usage information, prompting, and error handling.
- **Persistent Records**: Keeps track of all created Wine prefixes, their types, and detected application paths for convenience.
- **Easy Management**: Quickly create, run, execute, list, and remove prefixes without manually handling `WINEPREFIX` directories.

### Troubleshooting

- **Missing Dependencies**: Make sure all dependencies are installed.  
- **Wine-GE or DXVK Download Issues**: The script fetches the latest release URLs from GitHub’s API. If you have network issues or if GitHub changes the release structure, the script may fail to install Wine-GE or DXVK. Update dependencies or manually install if needed.
- **Permissions**: Ensure you have proper file permissions and write access to the directories where prefixes will be stored.

For more detailed usage and explanations, run:
```bash
winebox --help
```

Or inspect the script for additional comments and instructions.
