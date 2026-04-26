# HiddenScriptRunner (HSR)
![Tool Language: C#](https://img.shields.io/badge/Tool%20Language-C%23-239120?style=flat&logo=c-sharp&logoColor=white) ![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=flat&logo=windows&logoColor=white) ![Automation: PowerShell](https://img.shields.io/badge/Automation-PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)

HiddenScriptRunner (HSR) is a lightweight C# utility designed to execute scripts (`.ps1`, `.bat`, `.py`, `.rb`, `.exe`, etc.) or executables in the background without showing any console window. It is perfect for scheduled tasks, automation, or launching scripts where a persistent terminal window is undesirable.

## Why use HSR?

*	**True Stealth:** Eliminates the "console flash" (even for a fraction of a second) common with standard shell flags.
*	**Smart Resolution:** Automatically finds scripts in the current directory or the **System PATH**.
*	**Argument Passthrough:** Seamlessly forwards complex arguments and special characters to the target script.
*	**Multi-Language Support:** Pre-configured for `.ps1`, `.bat`, `.py`, `.js`, `.exe`, etc., with a **default fallback** for unknown extensions.
*	**Extensive Compatibility:** Supports local paths, UNC paths (network shares), and complex nested commands.

---

## How to use it

### Syntax
```powershell
HiddenScriptRunner.exe [-silent] [-wait] <script_or_exe> [arguments]
hsr [-silent] [-wait] <script_or_exe> [arguments]
hsr [-help]
```

### Command Line Arguments
Arguments must be placed before the target to be interpreted by HSR.

| Long Flag | Short Flag | Description |
| :--- | :--- | :--- |
| -help, /help | -h, /h, /? | Displays the usage help message box and returns the exit code 0. |
| -silent, /silent | -s, /s | Suppresses all HSR message boxes (errors or help). |
| -wait, /wait | -w, /w | Waits for the target to finish and returns its exit code. |

> Note: If installed via the provided scripts, you can simply use the `hsr` alias from any terminal.

### Exit Codes
HSR uses specific exit codes to distinguish between its own operational errors and the target script's results:

*	**0**: Success (Process started successfully, or help displayed via its own flag).
*	**101**: Missing target (No target provided; Displays the usage help message box).
*	**102**: Target not found (The file does not exist locally or in the PATH).
*	**103**: Launch error (Execution failed).
*	**Target's exit code**: When using -wait, HSR returns the target's exit code (which may overlap with HSR codes if the target also uses 101-103).

---

## Build & Installation Scripts
The project includes a suite of PowerShell scripts to manage the lifecycle of the tool.

| Script Name | Description | Requires Admin |
| :--- | :--- | :---: |
| `0_HSR_FullSetup_Admin.ps1` | **The Main Script.** Runs Compile, Sign, and Install in one go. | **Yes** |
| `1_HSR_Compile.ps1` | Compiles source code using the native C# compiler (`csc.exe`). | No |
| `2_Optional_HSR_CodeSign_Admin.ps1` | Creates a local self-signed certificate and signs binaries. | **Yes** |
| `3_Optional_HSR_Install_Admin.ps1` | Installs to `Program Files` and adds HSR to the **System PATH**. | **Yes** |
| `HSR_TestSuite.ps1` | Runs a comprehensive series of automated tests. | No |
| `Uninstall_HSR_Admin.ps1` | Full cleanup of binaries and removal of the HSR entry from the **System PATH**. | **Yes** |

---

## Getting Started

### 1. Obtain the Tool
You can either download the latest version or build it yourself from the source.

*	**Option A: Download** pre-compiled binaries from **GitHub Releases**.
*	**Option B: Build from source** (No external SDK required):
    ```powershell
    .\1_HSR_Compile.ps1
    ```

### 2. Recommended Setup
To ensure the best experience and avoid system warnings, run the following optional scripts:

*	**Prevent SmartScreen Blocks:** Run `2_Optional_HSR_CodeSign_Admin.ps1`. This signs the binaries with a local trusted certificate so **Microsoft SmartScreen** won't block execution.
*	**Enable Global Access:** Run `3_Optional_HSR_Install_Admin.ps1` to install the tool and add it to your **System PATH**. This allows you to call the tool from anywhere using the simple `hsr` alias:
    ```powershell
    # After installation, you can simply run:
    hsr "C:\Path\To\Script.ps1"
    ```

---

## Security & Requirements

*	**Zero-Dependency Compilation:** Uses the native Windows C# compiler (`csc.exe`). No heavy IDE, external SDK, or third-party build tools are required.
*	**Granular Permissions:** Admin rights are strictly reserved for scripts that modify system-wide settings (PATH, Program Files, or certificates).
*	**Standard Execution:** HSR runs with the same permission level as the caller.

---

## Extensive Usage Examples

### Path Resolution
HSR is designed to handle various path formats, including spaces, special characters, and network locations.

```powershell
# Standard resolution (Current folder or PATH)
hsr "Script.ps1"

# Special characters
hsr "C:\My.Folder (x86),Test;Files\Script.bat.ps1"

# Network (UNC) paths
hsr "\\127.0.0.1\c$\Scripts\Script.rb"

# Relative path resolution
hsr "..\Scripts\Target.ps1"

# Environment variables (Resolved by the shell before HSR is called)
hsr "%USERPROFILE%\Documents\Script.ps1"   # CMD
hsr "$Env:USERPROFILE\Documents\Script.py" # PowerShell
```

### Arguments & Special Characters
HSR forwards arguments exactly as they are provided. Parameters placed before the target are for HSR, while those after are for the target.

```powershell
# Handling empty arguments
hsr "Script.ps1" "arg 1" "" "arg 3"

# Distinguishing flags (HSR consumes -s, script receives -verbose; Only HSR is silent)
hsr -s "Script.ps1" -verbose

# Only the script is silent
hsr "Script.ps1" -silent "--config=prod;debug=true"

# Both are silent (HSR consumes the first, script receives the second)
hsr -silent "Script.ps1" -silent
```

### Nested Shells & Advanced Escaping
Perfect for wrapping commands or overriding default execution behaviors.

```powershell
# Manual interpreter call (To force specific flags)
hsr powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Script.ps1" "arg 1"

# Escaping trailing backslashes (Crucial to prevent "eating" the closing quote)
hsr "Script.ps1" "C:\Test Path\\"

# CMD special characters escaping (using ^)
hsr "Script.bat" "arg1^&calc"

# Nested quotes handling (Crucial for complex CMD calls)
hsr cmd /s /c ""C:\Scripts\Test.bat" "Nested quotes""     # CMD
hsr cmd /s /c --% ""C:\Scripts\Test.bat" "Nested quotes"" # PowerShell

# Complex special characters
hsr powershell -File "Script.ps1" "C:\Path\\" "\"Double Quote\"" "Special !@#$%^&() chars"     # CMD
hsr powershell -File "Script.ps1" --% "C:\Path\\" "\"Double Quote\"" "Special !@#$%^&() chars" # PowerShell
```

### Edge Cases & Advanced Shell Handling
HSR is tested against complex shell behaviors to ensure maximum compatibility.

```powershell
# Complex PowerShell command wrapping using character codes
hsr powershell -Command "& 'C:\Script.ps1' ([char]34 + 'Nested' + [char]34)"
```
