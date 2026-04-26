<#
HiddenScriptRunner (HSR): A universal script runner that hides the console window
HSR_Test_Suite.ps1: Functional testing of HSR binaries
#>

$sOriginalTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Test Suite"

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

Function Set-Up {
	if (Test-Path $sLogFile) { Remove-Item $sLogFile -ErrorAction SilentlyContinue }
	
	foreach ($sFolderName in $aTestFolder) {
		$null = New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot "$sFolderName") -Force
	}
	$sTestWD = Join-Path $PSScriptRoot $aTestFolder[0]
	$sTestPathFolder = Join-Path $PSScriptRoot $aTestFolder[-1]
	$env:PATH = "$sTestPathFolder;" + $env:PATH
	
	$sPSContent = 'Add-Content -Path "' + $sLogFile + '" -Value "ARG=[$($args -join "|")]"'
	$sCMDContent = '@echo ARG=[%~1^|%~2^|%~3]>> "' + $sLogFile + '"'
	$sCMDPathContent = '@echo ARG=[PATH_SUCCESS]>> "' + $sLogFile + '"'
	$sCMDWDContent = '@echo ARG=[WORKDIR_SUCCESS]>> "' + $sLogFile + '"'
	$sFAKEEXEContent = '"This is a fake executable to test code 103: Launch error'
	
	Set-Content -Path "$PSScriptRoot\HSR_Test.ps1" -Value $sPSContent
	Set-Content -Path "$PSScriptRoot\HSR Test Space.ps1" -Value $sPSContent
	Set-Content -Path "$PSScriptRoot\HSR_Test.bat" -Value $sCMDContent
	Set-Content -Path "$PSScriptRoot\HSR.Test.script.ps1.bat" -Value $sCMDContent
	Set-Content -Path (Join-Path $sTestPathFolder "HSR_Test_Path.bat") -Value $sCMDPathContent
	Set-Content -Path (Join-Path $sTestWD "HSR_Test_WD.bat") -Value $sCMDWDContent
	Set-Content -Path "$PSScriptRoot\HSR_Test_Code3.exe" -Value $sFAKEEXEContent -NoNewline

	$oShell = New-Object -ComObject WScript.Shell
	$oLnk = $oShell.CreateShortcut("$PSScriptRoot\HSR_Test_Default_Case.lnk")
	$oLnk.TargetPath = "$PSScriptRoot\HSR_Test.bat"
	$oLnk.Save()
}

# Forces the working directory to the location of the script
Set-Location -Path $PSScriptRoot

# Setup
$aBinarie = @("HiddenScriptRunner.exe", "HiddenScriptRunner_x86.exe", "HSR.exe", "HSR_x86.exe")
$aTestFolder = @("HSR_Test,Folder", "HSR_Test;Folder", "HSR_Test.Folder", "HSR_Test with space", "HSR_Test (x86)")
$sReleaseDir = Join-Path $PSScriptRoot "..\Release"
$sLogFile = Join-Path $PSScriptRoot "HSR_Test.log"
$iPass = 0
$iFail = 0
Set-Up

# MATRIX - Functional
$aMatrixTest = @(
	# --- PATH RESOLUTION ---
	@{ Name = "Relative Path No Quotes"; Cmd = "{EXE} HSR_Test.ps1 `"Done`""; Expected = "ARG=[Done]"; Category = "PATH RESOLUTION" }
	@{ Name = "Relative Path with Space"; Cmd = "{EXE} `"HSR Test Space.ps1`" `"Done`""; Expected = "ARG=[Done]" }
	@{ Name = "Double Extension"; Cmd = "{EXE} `"{ROOT}\HSR.Test.script.ps1.bat`" `"Done`""; Expected = "ARG=[Done||]" }
	@{ Name = "Implicit Extension"; Cmd = "{EXE} `"HSR_Test`" `"Done`""; Expected = "ARG=[Done||]" }
	@{ Name = "File in System PATH"; Cmd = "{EXE} `"HSR_Test_Path.bat`""; Expected = "ARG=[PATH_SUCCESS]" }
	@{ Name = "Path with Parenthesis (x86)"; Cmd = "{EXE} `"{ROOT}\HSR_Test (x86)\..\HSR_Test.bat`" `"Done`""; Expected = "ARG=[Done||]" }
	@{ Name = "Path with Dot"; Cmd = "{EXE} `"{ROOT}\HSR_Test.Folder\..\HSR_Test.ps1`" `"Done`""; Expected = "ARG=[Done]" }
	@{ Name = "Path with Comma"; Cmd = "{EXE} `"{ROOT}\HSR_Test,Folder\..\HSR_Test.ps1`" `"Done`""; Expected = "ARG=[Done]" }
	@{ Name = "Path with Semicolon"; Cmd = "{EXE} `"{ROOT}\HSR_Test;Folder\..\HSR_Test.ps1`" `"Done`""; Expected = "ARG=[Done]" }
	@{ Name = "UNC Path Simulation"; Cmd = "{EXE} `"\\127.0.0.1\c$\Windows\System32\cmd.exe`" `"/c echo ARG=[UNC]>>{LOG}`""; Expected = "ARG=[UNC]" }
	@{ Name = "Explicit Relative Path"; Cmd = "{EXE} `".\HSR_Test.ps1`" `"Done`""; Expected = "ARG=[Done]" }

	# --- ARGUMENTS & SPECIAL CHARACTERS ---
	@{ Name = "Single Argument"; Cmd = "{EXE} `"{ROOT}\HSR_Test.ps1`" `"C:\My Argument 1`""; Expected = "ARG=[C:\My Argument 1]"; Category = "ARGUMENTS & SPECIAL CHARACTERS" }
	@{ Name = "Multiple Arguments"; Cmd = "{EXE} `"{ROOT}\HSR_Test.ps1`" `"C:\My Argument 1`" `"C:\My Argument 2`""; Expected = "ARG=[C:\My Argument 1|C:\My Argument 2]" }
	@{ Name = "Silent Flag (Tunneling)"; Cmd = "{EXE} -silent `"HSR_Test.ps1`" -silent -verbose"; Expected = "ARG=[-silent|-verbose]" }
	@{ Name = "Complex Config Arg"; Cmd = "{EXE} `"HSR_Test.ps1`" `"--config=prod;debug=true`""; Expected = "ARG=[--config=prod;debug=true]" }
	@{ Name = "Space as Argument"; Cmd = "{EXE} `"HSR_Test.ps1`" `" `" `"arg2`""; Expected = "ARG=[ |arg2]" }
	@{ Name = "Empty Argument (Middle)"; Cmd = "{EXE} `"HSR_Test.ps1`" `"arg1`" `"`" `"arg3`""; Expected = "ARG=[arg1||arg3]" }
	@{ Name = "Killer Backslash Final"; Cmd = "{EXE} `"{ROOT}\HSR_Test.ps1`" `"C:\Test Path\`" `"Argument 2`""; Expected = "ARG=[C:\Test Path`" Argument|2]"}
	
	# --- NESTED SHELLS & ESCAPING ---
	@{ Name = "Double Backslash Final"; Cmd = "{EXE} powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"{ROOT}\HSR_Test.ps1`" `"C:\My Argument 1\\`""; Expected = "ARG=[C:\My Argument 1\]"; Category = "NESTED SHELLS & ESCAPING" }
	@{ Name = "CMD Escape Chars ^&"; Cmd = "{EXE} `"HSR_Test.bat`" `"arg1^&calc`""; Expected = "ARG=[arg1&calc||]" }
	@{ Name = "PS Call Operator & and [char]"; Cmd = "{EXE} powershell -NoProfile -Command `"& '{ROOT}\HSR_Test.ps1' ([char]34 + 'Nested quotes' + [char]34)`""; Expected = "ARG=[`"Nested quotes`"]" }
	@{ Name = "CMD Complex Nested Quotes"; Cmd = '{EXE} cmd /s /c ""{ROOT}\HSR_Test.bat" "Nested quotes""'; Expected = "ARG=[Nested quotes||]" }
	@{ Name = "PS Complex Nested Quotes"; Cmd = 'powershell -NoProfile -Command "{EXE} --% \"{ROOT}\HSR_Test.bat\" \"Nested quotes\""'; Expected = "ARG=[Nested quotes||]" }
	@{ Name = "PS Escape Special Chars"; Cmd = "{EXE} powershell -NoProfile -File `"{ROOT}\HSR_Test.ps1`" `"C:\Test Path\\`" `"\`"Double Quote Test\`"`" `"Special !@#`$%^&() chars`""; Expected = "ARG=[C:\Test Path\|`"Double Quote Test`"|Special !@#$%^&() chars]" }
	@{ Name = "PS --% Special Chars"; Cmd = "{EXE} powershell -NoProfile -File `"{ROOT}\HSR_Test.ps1`" --% `"C:\Test Path\\`" `"\`"Double Quote Test\`"`" `"Special !@#`$%^&() chars`""; Expected = "ARG=[C:\Test Path\|`"Double Quote Test`"|Special !@#$%^&() chars]" }
	
	# --- TERMINAL SPECIFIC (ENV VARS) ---
	@{ Name = "CMD Env Var UserProfile"; Cmd = "{EXE} `"%USERPROFILE%\..\..\Windows\System32\cmd.exe`" `"/c echo ARG=[USERPROFILE]>>{LOG}`""; Expected = "ARG=[USERPROFILE]"; Category = "TERMINAL SPECIFIC (ENV VARS)" }
	@{ Name = "PS Env Var UserProfile"; Cmd = "{EXE} `"`$env:USERPROFILE\..\..\Windows\System32\cmd.exe`" `"/c echo ARG=[PS_ENV]>>{LOG}`""; Expected = "ARG=[PS_ENV]"}

	# --- HSR OTHER LOGIC ---
	@{ Name = "Default Case Association"; Cmd = "{EXE} `"{ROOT}\HSR_Test_Default_Case.lnk`" `"Done`""; Expected = "ARG=[Done||]"; Category = "HSR OTHER LOGIC" }
)

# MATRIX - Exit codes
# Exit codes: 0=Success, 101=Missing target, 102=Target not found, 103=Launch error (simulated via invalid interpreter)
$aMatrixExitCode = @(
	@{ Name = "Exit code 0 (Success)"; Cmd = "{EXE} -silent `"{ROOT}\HSR_Test.ps1`""; ExpectedCode = 0 }
	@{ Name = "Exit code 101 (Missing target)"; Cmd = "{EXE} -silent"; ExpectedCode = 101 }
	@{ Name = "Exit code 102 (Not Found)"; Cmd = "{EXE} -silent `"NonExistent.ps1`""; ExpectedCode = 102 }
	@{ Name = "Exit code 103 (Launch Error)"; Cmd = "{EXE} -silent `"{ROOT}\HSR_Test_Code3.exe`""; ExpectedCode = 103 }
	@{ Name = "Flag -help (Return 0)"; Cmd = "{EXE} -help -silent"; ExpectedCode = 0 }
    @{ Name = "Flag /? (Return 0)"; Cmd = "{EXE} /? -silent"; ExpectedCode = 0 }
    @{ Name = "Flag -wait & CMD Exit Code (42)"; Cmd = "{EXE} -wait -silent cmd.exe /c `"exit 42`""; ExpectedCode = 42 }
    @{ Name = "Flag -w & PS Exit Code (13)"; Cmd = "{EXE} -w -silent powershell.exe -Command `"exit 13`""; ExpectedCode = 13 }
)

# Runs the tests
Write-Host "`n--- HSR Test Suite ---" -ForegroundColor White
$iPadRight = 35
foreach ($sFileExe in $aBinarie) {
	$sFullPath = Join-Path $sReleaseDir $sFileExe
	if (-not (Test-Path $sFullPath)) {
		Write-Host "`n[SKIP] $sFileExe not found in Release folder." -ForegroundColor Yellow
		continue
	}
	Write-Host "`n---------------------------------------------------------" -ForegroundColor Gray
	Write-Host ">>> Target Binary: $sFileExe" -ForegroundColor Magenta
	

	# Tests - Functional
	$iBinPass = 0
	$iBinFail = 0
	$sCurrentCategory = ""
	foreach ($hMatrix in $aMatrixTest) {
		if ($hMatrix.Category -and $hMatrix.Category -ne $sCurrentCategory) {
			$sCurrentCategory = $hMatrix.Category
			Write-Host "`n[$sCurrentCategory]" -ForegroundColor Cyan
		}
		
		if (Test-Path $sLogFile) { Remove-Item $sLogFile -Force -ErrorAction SilentlyContinue }
		$sTitleTest = $hMatrix.Name.PadRight($iPadRight)
		Write-Host "Testing: $sTitleTest " -NoNewline
		$sCommand = $hMatrix.Cmd.Replace("{EXE}", "`"$sFullPath`"").Replace("{ROOT}", $PSScriptRoot).Replace("{LOG}", $sLogFile)
		
		#$oProcess = Start-Process cmd -ArgumentList "/c $sCommand" -NoNewWindow -PassThru
		$oProcess = Start-Process cmd -ArgumentList "/s /c `"$sCommand`"" -NoNewWindow -PassThru
		
		$iTimeout = 0
		while (-not (Test-Path $sLogFile) -and $iTimeout -lt 30) {
			Start-Sleep -Milliseconds 100
			$iTimeout++
		}
		if (-not $oProcess.HasExited) {
			[void]$oProcess.WaitForExit(500)
			Stop-Process -Id $oProcess.Id -Force -ErrorAction SilentlyContinue
		}
		
		if (Test-Path $sLogFile) {
			Start-Sleep -Milliseconds 100
			$sRawContent = Get-Content $sLogFile -Raw -ErrorAction SilentlyContinue
			$sLastLog = "NO_DATA"
			if ($sRawContent) {
				$sLastLog = $sRawContent.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries) | Select-Object -Last 1
			}
			if ($sLastLog -eq $hMatrix.Expected) {
				$iPass++; $iBinPass++
				Write-Host "[OK]" -ForegroundColor Green
			} else {
				$iFail++; $iBinFail++
				Write-Host "[FAIL]" -ForegroundColor Red
				Write-Host "  > Received: $sLastLog" -ForegroundColor Magenta
				Write-Host "  > Expected: $($hMatrix.Expected)" -ForegroundColor Gray
			}
		} else {
			$iFail++; $iBinFail++
			Write-Host "[FAIL - No Log / Timeout]" -ForegroundColor Red
		}
	}

	# Tests - Exit codes & HSR flags
	Write-Host "`n[EXIT CODES]" -ForegroundColor Cyan
	foreach ($hMatrix in $aMatrixExitCode) {
		$sTitleTest = $hMatrix.Name.PadRight($iPadRight)
		Write-Host "Testing: $sTitleTest " -NoNewline
		$sCommand = $hMatrix.Cmd.Replace("{EXE}", "`"$sFullPath`"").Replace("{ROOT}", $PSScriptRoot)
		
		$oProcess = Start-Process cmd -ArgumentList "/s /c `"$sCommand`"" -PassThru -NoNewWindow -Wait
		
		if ($oProcess.ExitCode -eq $hMatrix.ExpectedCode) {
			$iPass++; $iBinPass++
			Write-Host "[OK]" -ForegroundColor Green
		} else {
			$iFail++; $iBinFail++
			Write-Host "[FAIL]" -ForegroundColor Red
			Write-Host "  > Received: Code $($oProcess.ExitCode)" -ForegroundColor Magenta
			Write-Host "  > Expected: Code $($hMatrix.ExpectedCode)" -ForegroundColor Gray
		}
	}

	$sColor = if ($iBinFail -gt 0) { "Red" } else { "Green" }
	Write-Host "`nSummary for ${sFileExe}: PASS=$iBinPass | FAIL=$iBinFail" -ForegroundColor $sColor
	Write-Host "---------------------------------------------------------" -ForegroundColor Gray
}

# Displays the result
Write-Host "`n=========================================================" -ForegroundColor White
Write-Host "TESTING FINISHED" -ForegroundColor Cyan
Write-Host "Total Checks : $($iPass + $iFail)"
Write-Host "Passed       : $iPass" -ForegroundColor Green
if ($iFail -gt 0) {
	Write-Host "Failed       : $iFail" -ForegroundColor Red
} else {
	Write-Host "Failed       : 0" -ForegroundColor Gray
}
Write-Host "=========================================================`n" -ForegroundColor White
_Pause

# Cleans
Write-Host "`nCleaning up test environment..."
Get-Process | Where-Object { $aBinarie -contains ($_.Name + ".exe") } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300
Get-ChildItem -Path $PSScriptRoot -Filter "HSR*Test*" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $PSCommandPath } | Remove-Item -Force
foreach ($sFolderName in $aTestFolder) {
	$sDirToDel = Join-Path $PSScriptRoot $sFolderName
	if (Test-Path $sDirToDel) { Remove-Item $sDirToDel -Recurse -Force -ErrorAction SilentlyContinue }
}
_Exit 0
