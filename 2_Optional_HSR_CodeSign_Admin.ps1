<#
HiddenScriptRunner (HSR): A universal script runner that hides the console window
2_Optional_HSR_CodeSign_Admin.ps1: Creates/Installs digital certificate and sign binaries
#>

$sOriginalTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Code Signing"

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
	Write-Host "`nAdministrator privileges are required for digital certificate. Please restart the script as an administrator." -ForegroundColor Red
	_Exit 1 $true
}
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Code Signing (Administrator)"

# Preparation the digital signature
$sCertName = "HSR_CodeSign"
$cert = Get-ChildItem Cert:\LocalMachine\My, Cert:\LocalMachine\Root, Cert:\LocalMachine\TrustedPublisher -ErrorAction SilentlyContinue |
		Where-Object { $_.FriendlyName -eq $sCertName -and $_.NotAfter -gt (Get-Date) } |
		Select-Object -First 1
if (-not $cert) {
	try {
		$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=Zaibai Software Production" `
				-TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3") `
				-KeyUsage DigitalSignature -FriendlyName $sCertName `
				-NotAfter (Get-Date).AddYears(10) `
				-CertStoreLocation "Cert:\LocalMachine\My"
	} catch {
		Write-Host "`nCertificate creation failure: $($_.Exception.Message)" -ForegroundColor Red
		_Exit 1 $true
	}
}

# Verification and installation in Trusted Root and TrustedPublisher
$bError = $false
$aStore = @("Root", "TrustedPublisher")
foreach ($sStoreName in $aStore) {
	$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($sStoreName, "LocalMachine")
	try {
		$store.Open("ReadWrite")
		if (-not ($store.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint })) {
			$store.Add($cert)
		}
	} catch {
		$bError = $true
		Write-Host "`nFailed to access $sStoreName store: $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		$store.Close()
	}
}

# Signs the binaries
$sReleaseDir = Join-Path $PSScriptRoot "Release"
$aFile = @("HiddenScriptRunner.exe", "HiddenScriptRunner_x86.exe")
$aTimestampServer = @("http://timestamp.digicert.com", "http://timestamp.sectigo.com")
foreach ($sFile in $aFile) {
	$sFilePath = Join-Path $sReleaseDir $sFile
	if (-not (Test-Path -Path $sFilePath)) {
		$bError = $true
		Write-Host "`n[SKIP] File not found: $sFile" -ForegroundColor Yellow
		continue
	}

	$bSigned = $false
	$oResult = $null
	foreach ($sServer in $aTimestampServer) {
		$oResult = Set-AuthenticodeSignature -FilePath $sFilePath -Certificate $cert -TimestampServer $sServer
		if ($oResult.Status -eq "Valid") {
			$bSigned = $true
			break
		}
	}
	if (-not $bSigned) {
		$bError = $true
		$sStatus = if ($oResult) { $oResult.Status } else { "Unknown" }
		Write-Host "`nDigital signature failed for $sFile (Last Status: $sStatus)" -ForegroundColor Red
	}
}

# Displays the result
if ($bError) {
	Write-Host "`nDigital signature process completed with error(s)." -ForegroundColor Yellow
	_Exit 1 $true
}
Write-Host "`nDigital signature process completed." -ForegroundColor Green
_Exit 0
