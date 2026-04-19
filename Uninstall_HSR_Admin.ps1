<#
HiddenScriptRunner (HSR): A universal script runner that hides the console window
Uninstall_HSR_Admin.ps1: Uninstalls HSR and remove it from the system PATH
#>

$sOriginalTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Uninstall"

Function _Pause([string]$sMsg = "Press any key to continue...") {
	Write-Host -NoNewline $sMsg
	[void][System.Console]::ReadKey($true)
	Write-Host ""
}

Function _Exit([int]$iExit = 0, [bool]$bPause = $false) {
	if ($bPause) { _Pause "Press any key to exit the script..." }
	$Host.UI.RawUI.WindowTitle = $sOriginalTitle
	exit $iExit
}

# Forces the working directory to the location of the script
Set-Location -Path $PSScriptRoot

# Checks if the script runs as an administrator
$bIsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $bIsAdmin) {
	Write-Host "`nAdministrator privileges are required for uninstallation. Please restart the script as an administrator." -ForegroundColor Red
	_Exit 1 $true
}
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Uninstall (Administrator)"

# Safety confirmation to avoid accidental execution
Write-Host "`n--- HiddenScriptRunner Uninstallation ---" -ForegroundColor Yellow
$sConfirm = Read-Host "Are you sure you want to uninstall HiddenScriptRunner and remove it from system PATH? (y/N)"
if ($sConfirm.Trim() -ne "y") {
	Write-Host "`nUninstallation cancelled." -ForegroundColor Yellow
	_Exit 0 $true
}

# For refresh environment variables for the system
$sUpdateCode = @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@

# Stops any running HSR processes to avoid file lock
$aProcName = @("HiddenScriptRunner", "HiddenScriptRunner_x86", "HSR", "HSR_x86")
$oRunning = Get-Process -Name $aProcName -ErrorAction SilentlyContinue
if ($oRunning) {
	Write-Host "`nClosing running HSR processes..." -ForegroundColor Gray
	$oRunning | Stop-Process -Force -ErrorAction SilentlyContinue
	Start-Sleep -Milliseconds 400
}

# Removes HSR from the system PATH
$sInstallDir = Join-Path $env:ProgramFiles "HiddenScriptRunner"
$bError = $false
$regKey = $null
try {
	$sRegistryPath = "System\CurrentControlSet\Control\Session Manager\Environment"
	$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sRegistryPath, $true)
	if ($null -eq $regKey) { throw "Registry key could not be opened." }
	
	$sCurrentPath = $regKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
	$aPathParts = $sCurrentPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
	if ($aPathParts -contains $sInstallDir) {
		
		# Clean reconstruction without the HSR directory
		$sNewPath = ($aPathParts | Where-Object { $_ -ne $sInstallDir }) -join ";"
		$regKey.SetValue("Path", $sNewPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)
		
		# Refreshes environment variables for the system (broadcast change)
		if (-not ([System.Management.Automation.PSTypeName]"Win32.HSR_Win32SendMessage").Type) {
			Add-Type -MemberDefinition $sUpdateCode -Name "HSR_Win32SendMessage" -Namespace "Win32" | Out-Null
		}
		$null = [Win32.HSR_Win32SendMessage]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 0x0002, 5000, [ref][UIntPtr]::Zero)
		
		# Refreshes $env:Path for the current terminal
		$sFullRawPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
		$env:Path = [System.Environment]::ExpandEnvironmentVariables($sFullRawPath)
	}
} catch {
	$bError = $true
	Write-Host "`nFailed to clean system PATH: $($_.Exception.Message)" -ForegroundColor Red
} finally {
	if ($null -ne $regKey) { $regKey.Close() }
}

# Removes files and directory
Start-Sleep -Milliseconds 200
try {
	if (Test-Path -Path $sInstallDir) {
		Remove-Item -Path $sInstallDir -Recurse -Force -ErrorAction Stop
	}
} catch {
	$bError = $true
	Write-Host "`nFailed to remove files: $($_.Exception.Message)" -ForegroundColor Red
}

# Displays the result
if ($bError) {
	Write-Host "`nUninstallation process completed with error(s)." -ForegroundColor Yellow
	_Exit 1 $true
}
Write-Host "`nUninstallation process completed." -ForegroundColor Green
_Exit 0
