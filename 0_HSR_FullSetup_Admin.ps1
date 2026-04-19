<#
HiddenScriptRunner (HSR): A universal script runner that hides the console window
0_HSR_FullSetup_Admin.ps1: Main script that runs "all" the scripts:
	- 1_HSR_Compile.ps1
	- 2_Optional_HSR_CodeSign_Admin.ps1
	- 3_Optional_HSR_Install_Admin.ps1
Requires administrator privileges for the digital certificate and installation script
#>

$sOriginalTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Full Setup"

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

# Helper function to run setup steps
Function _RunStep($sScriptPath, $sStep, $sStepDetail, $bCritical = $false) {
	$iPSWidth = $Host.UI.RawUI.WindowSize.Width
	$sSeparator = "$([char]0x2500)" * ($iPSWidth - 1)
	Write-Host "`n$sSeparator"
	Write-Host -NoNewline "$sStep" -ForegroundColor Cyan
	Write-Host " - $sStepDetail"

	try {
		if (-not (Test-Path -Path $sScriptPath)) {
			Write-Host "`nScript not found: $sScriptPath" -ForegroundColor Red
			if ($bCritical) { return 1 }
			$script:iGlobalError++
			return 0
		}
		
		& $sScriptPath
		$iLastEC = $LASTEXITCODE
		if ($iLastEC -ne 0) {
			$sScriptFile = Split-Path $sScriptPath -Leaf
			Write-Host "`n$sScriptFile failed with the exit code: $iLastEC" -ForegroundColor Red
			if ($bCritical) { return $iLastEC }
			$script:iGlobalError++
		}
		return 0
	} finally {
		Write-Host $sSeparator
		$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Full Setup (Administrator)"
	}
}

# Forces the working directory to the location of the script
Set-Location -Path $PSScriptRoot

# Checks if the script runs as an administrator
$bIsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $bIsAdmin) {
	Write-Host "`nAdministrator privileges are required for the digital certificate and installation script." -ForegroundColor Yellow
	Write-Host "Request for elevated privileges in 5 seconds..."
	Start-Sleep -Seconds 5
	
	$sPsArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
	try {
		Start-Process -FilePath "$((Get-Process -Id $PID).Path)" -ArgumentList $sPsArgs -Verb RunAs
		_Exit 0
	} catch {
		Write-Host "`nElevating privileges failed. Please run this script as an administrator." -ForegroundColor Red
		_Exit 1 $true
	}
}
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Full Setup (Administrator)"

# Presentation
Write-Host "`nHiddenScriptRunner (HSR): A universal script runner that hides the console window."
Write-Host "`n--- HiddenScriptRunner Installation ---" -ForegroundColor Yellow
Write-Host '0_HSR_FullSetup_Admin.ps1: Main script that runs "all" the scripts:'
Write-Host "	- 1_HSR_Compile.ps1: Compiles C# source code into binaries."
Write-Host "	- 2_Optional_HSR_CodeSign_Admin.ps1: Creates/Installs digital certificate and sign binaries."
Write-Host "	- 3_Optional_HSR_Install_Admin.ps1: Installs binaries and update the system PATH."

# Safety confirmation to avoid accidental execution
$sConfirm = Read-Host "`nDo you confirm that you want to install HiddenScriptRunner and add it to the system PATH? (y/N)"
if ($sConfirm.Trim() -ne "y") {
	Write-Host "`nInstallation cancelled." -ForegroundColor Yellow
	_Exit 0 $true
}

# Scripts path and initialization
$sCompileScript = Join-Path $PSScriptRoot "1_HSR_Compile.ps1"
$sSignScript = Join-Path $PSScriptRoot "2_Optional_HSR_CodeSign_Admin.ps1"
$sInstallScript = Join-Path $PSScriptRoot "3_Optional_HSR_Install_Admin.ps1"
[int]$iGlobalError = 0

# Step 1: Compilation (CRITICAL)
$iLEC = _RunStep $sCompileScript "[Step 1/3]" "Compiling the binaries..." -bCritical $true
if ($iLEC -ne 0) {
	Write-Host "`nFatal error: Compilation failed. Sequence aborted." -ForegroundColor Red
	_Exit $iLEC $true
}

# Step 2: Sign (NON-CRITICAL)
$null =_RunStep $sSignScript "[Step 2/3]" "Applying the digital signature..."

# Step 3: Installation (NON-CRITICAL)
$null =_RunStep $sInstallScript "[Step 3/3]" "Installing binaries and updating the system PATH..."

# Displays the result
if ($iGlobalError -eq 0) {
	Write-Host "`nInstallation complete." -ForegroundColor Green
} else {
	Write-Host "`nInstallation complete with $iGlobalError non-critical error(s)." -ForegroundColor Yellow
}

_Exit $(if ($iGlobalError -gt 0) { $iGlobalError } else { 0 }) $true
