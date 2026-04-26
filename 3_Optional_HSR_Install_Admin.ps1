<#
HiddenScriptRunner (HSR): A universal script runner that hides the console window
3_Optional_HSR_Install_Admin.ps1: Installs binaries and update the System PATH
#>

$sOriginalTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Installation"

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
	Write-Host "`nAdministrator privileges are required for installation. Please restart the script as an administrator." -ForegroundColor Red
	_Exit 1 $true
}
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Installation (Administrator)"

# For refresh environment variables for the system
$sUpdateCode = @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@

# Installs (copy files)
$sInstallDir = Join-Path $env:ProgramFiles "HiddenScriptRunner"
$sReleaseDir = Join-Path $PSScriptRoot "Release"
$aFile = @("HiddenScriptRunner.exe", "HiddenScriptRunner_x86.exe")
$bError = $false
try {
	if (-not (Test-Path -Path $sInstallDir)) {
		New-Item -Path $sInstallDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
	}

	foreach ($sFileName in $aFile) {
		$sSourcePath = Join-Path $sReleaseDir $sFileName
		if (Test-Path -Path $sSourcePath) {
			# Copy original file
			Copy-Item -Path $sSourcePath -Destination $sInstallDir -Force -ErrorAction Stop
			
			# Create short name version by copy (alias)
			$sShortName = $sFileName -replace "HiddenScriptRunner", "HSR"
			$sDestShortPath = Join-Path $sInstallDir $sShortName
			Copy-Item -Path $sSourcePath -Destination $sDestShortPath -Force -ErrorAction Stop
		} else {
			$bError = $true
			Write-Host "`nSource file not found: $sSourcePath" -ForegroundColor Red
		}
	}
} catch {
	$bError = $true
	Write-Host "`nFailed to copy files: $($_.Exception.Message)" -ForegroundColor Red
}

# Adds HSR to the System PATH
$regKey = $null
try {
	$sRegistryPath = "System\CurrentControlSet\Control\Session Manager\Environment"
	$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sRegistryPath, $true)
	if ($null -eq $regKey) { throw "Registry key could not be opened." }
	
	$sCurrentPath = $regKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
	if ($sCurrentPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) -notcontains $sInstallDir) {
		$sNewPath = ("$sCurrentPath;$sInstallDir" -replace ";+", ";").Trim(';')
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
	Write-Host "`nFailed to update System PATH: $($_.Exception.Message)" -ForegroundColor Red
} finally {
	if ($null -ne $regKey) { $regKey.Close() }
}

# Displays the result
if ($bError) {
	Write-Host "`nInstallation process completed with error(s)." -ForegroundColor Yellow
	_Exit 1 $true
}
Write-Host "`nInstallation process completed." -ForegroundColor Green
_Exit 0
