<#
HiddenScriptRunner (HSR): A universal script runner that hides the console window
1_HSR_Compile.ps1 : Compiles C# source code into binaries
#>

$sOriginalTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "HiddenScriptRunner - Compile"

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

$sCodeCSharp = @"
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Diagnostics;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

// These attributes populate the "Details" tab of the file properties
[assembly: AssemblyProduct("HiddenScriptRunner")]
[assembly: AssemblyTitle("A universal script runner that hides the console window")]
[assembly: AssemblyDescription("A universal script runner that hides the console window")]
[assembly: AssemblyCompany("Zaibai Software Production")]
[assembly: AssemblyCopyright("Copyright \u00A9 2020-2030 Zaibai Software Production")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

public class NoWindowHostOfHSR {
	
	// API to retrieve the exact command line as sent by the OS
	[DllImport("kernel32.dll", CharSet = CharSet.Auto)]
	private static extern IntPtr GetCommandLine();
	
	// Helper to check if an executable exists in the system PATH
	private static bool IsBinaryAvailable(string binaryName) {
		return FindInPath(binaryName) != null;
	}
	
	// Logic to resolve a file name to a full path via the system PATH
	private static string FindInPath(string fileName) {
		
		// Get standard executable extensions (.EXE, .BAT, etc.)
		string pathExt = Environment.GetEnvironmentVariable("PATHEXT") ?? ".EXE;.BAT;.CMD";
		string[] extensions = pathExt.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);

		// Searchs the file (with or without extensions for relative/absolute paths)
		if (File.Exists(fileName)) return Path.GetFullPath(fileName);
		foreach (string ext in extensions) {
			string curPath = fileName.EndsWith(ext, StringComparison.OrdinalIgnoreCase) ? fileName : fileName + ext;
			if (File.Exists(curPath)) return Path.GetFullPath(curPath);
		}

		// Searchs for the file in the PATH
		string pathEnv = Environment.GetEnvironmentVariable("PATH");
		if (string.IsNullOrEmpty(pathEnv)) return null;

		foreach (string pathDir in pathEnv.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries)) {
			try {
				string trimmedDir = pathDir.Trim().Replace("\"", "");
				if (string.IsNullOrEmpty(trimmedDir)) continue;

				string fullPath = Path.Combine(trimmedDir, fileName);
				if (File.Exists(fullPath)) return fullPath;
				
				// Try with extensions if the file doesn't have one
				foreach (string ext in extensions) {
					string pathWithExt = fullPath.EndsWith(ext, StringComparison.OrdinalIgnoreCase) ? fullPath : fullPath + ext;
					if (File.Exists(pathWithExt)) return pathWithExt;
				}
			} catch {
				// Skip invalid paths (like those with illegal characters)
				continue;
			}
		}
		return null;
	}
	
	public static int Main(string[] args) {
		
		// Recovery of the system command line (raw)
		string rawCmd = Marshal.PtrToStringAuto(GetCommandLine());
		
		// Detection of the -silent flag: does not display error message boxes
		bool silent = args.Any(a => a.Equals("-silent", StringComparison.OrdinalIgnoreCase));
		var cleanArgs = args.Where(a => !a.Equals("-silent", StringComparison.OrdinalIgnoreCase)).ToArray();
		
		// Missing target - Help message box
		if (cleanArgs.Length < 1) {
			if (!silent) {
				MessageBox.Show("HiddenScriptRunner (HSR)\n" +
								"A universal script runner that hides the console window.\n\n" +
								"Usage:\n" +
								"HiddenScriptRunner.exe [-silent] \"<script_path>\" \"[arguments]\"\n\n" +
								"Example:\n" +
								"1. Basic: HiddenScriptRunner.exe \"C:\\Script\\test.ps1\"\n" +
								"2. Arguments: HiddenScriptRunner.exe \"C:\\Script\\test.bat\" \"arg1\" \"arg2\"\n" +
								"3. Advanced: HiddenScriptRunner.exe -silent \"powershell.exe\" -NoProfile -ExecutionPolicy Bypass -File \"C:\\Script\\test.ps1\" \"C:\\My Argument 1\\\\\"\n\n" +
								"Exit codes: 0=Success, 1=Missing target, 2=Target not found, 3=Launch error",
								"How to use it?", MessageBoxButtons.OK, MessageBoxIcon.Information);
			}
			return 1;
		}
		
		// Searchs the target
		string target = cleanArgs[0];
		if (!File.Exists(target)) {
			string resolvedPath = FindInPath(target);
			if (resolvedPath != null) target = resolvedPath;
		}
		
		// Target not found
		if (!File.Exists(target)) {
			if (!silent) {
				MessageBox.Show(string.Format("The following target/file cannot be found:\n{0}", target), 
								"Target not found", MessageBoxButtons.OK, MessageBoxIcon.Error);
			}
			return 2;
		}

		// Process start and file information
		target = Path.GetFullPath(target).Trim('"');
		ProcessStartInfo startInfo = new ProcessStartInfo();
		string extension = (Path.GetExtension(target) ?? string.Empty).ToLower();
		
		// Set working directory to the target's folder
		try {
			startInfo.WorkingDirectory = Path.GetDirectoryName(target);
		} catch {}
		
		// Extraction of raw arguments
		string remainingArgs = "";
		string[] allOriginalArgs = Environment.GetCommandLineArgs();
		string hsrPath = allOriginalArgs[0];
		int startIdx = rawCmd.IndexOf(hsrPath, StringComparison.Ordinal);
		if (startIdx != -1) {
			string afterHsr = rawCmd.Substring(startIdx + hsrPath.Length).TrimStart();
			if (afterHsr.StartsWith("\"")) afterHsr = afterHsr.Substring(1).TrimStart();
			string originalTargetEntry = cleanArgs.FirstOrDefault();
			if (!string.IsNullOrEmpty(originalTargetEntry)) {
				int targetIdx = afterHsr.IndexOf(originalTargetEntry, StringComparison.Ordinal);
				if (targetIdx != -1) {
					remainingArgs = afterHsr.Substring(targetIdx + originalTargetEntry.Length);
					if (remainingArgs.StartsWith("\"")) {remainingArgs = remainingArgs.Substring(1);}
					remainingArgs = remainingArgs.Trim(' ');
				}
			}
		}
		
		// Arguments by language (Alphabetical order)
		switch (extension) {
			// Batch / Command
			case ".bat":
			case ".cmd":
				startInfo.FileName = "cmd.exe";
				startInfo.Arguments = string.Format("/s /c \"\"{0}\" {1}\"", target, remainingArgs);
				break;

			// Java
			case ".jar":
				startInfo.FileName = "java.exe";
				startInfo.Arguments = string.Format("-jar \"{0}\" {1}", target, remainingArgs);
				break;

			// JScript (Windows Script Host)
			case ".js":
			case ".jse":
				startInfo.FileName = "wscript.exe";
				startInfo.Arguments = string.Format("\"{0}\" {1}", target, remainingArgs);
				break;

			// Node.js
			case ".node":
				startInfo.FileName = "node.exe";
				startInfo.Arguments = string.Format("\"{0}\" {1}", target, remainingArgs);
				break;

			// Perl
			case ".pl":
				startInfo.FileName = "perl.exe";
				startInfo.Arguments = string.Format("\"{0}\" {1}", target, remainingArgs);
				break;

			// PHP
			case ".php":
				startInfo.FileName = "php.exe";
				startInfo.Arguments = string.Format("-f \"{0}\" -- {1}", target, remainingArgs);
				break;

			// PowerShell
			case ".ps1":
			case ".psm1":
				startInfo.FileName = IsBinaryAvailable("pwsh.exe") ? "pwsh.exe" : "powershell.exe";
				startInfo.Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\" {1}", target, remainingArgs);
				break;

			// Python
			case ".py":
			case ".pyw":
				startInfo.FileName = "pythonw.exe";
				startInfo.Arguments = string.Format("\"{0}\" {1}", target, remainingArgs);
				break;

			// Ruby
			case ".rb":
			case ".rbw":
				startInfo.FileName = "ruby.exe";
				startInfo.Arguments = string.Format("\"{0}\" {1}", target, remainingArgs);
				break;

			// Z - Compiled software
			case ".com":
			case ".exe":
				startInfo.FileName = target;
				startInfo.Arguments = remainingArgs;
				break;
				
			// Z - Default: System association
			default:
				startInfo.FileName = "cmd.exe";
				startInfo.Arguments = string.Format("/s /c \"\"{0}\" {1}\"", target, remainingArgs);
				break;
		}
		
		// Settings for complete invisibility
		startInfo.UseShellExecute = false;
		startInfo.CreateNoWindow = true;
		startInfo.WindowStyle = ProcessWindowStyle.Hidden;
		
		// Settings of redirection
		startInfo.RedirectStandardOutput = false;
		startInfo.RedirectStandardError = false;
		
		// Runs the hidden process
		//MessageBox.Show("DEBUG:\nFileName: " + startInfo.FileName + "\nArgs: " + startInfo.Arguments);
		try {
			Process.Start(startInfo);
			return 0;
		} catch (Exception ex) {
			if (!silent) {
				MessageBox.Show(string.Format("Error during launch of {0}:\n{1}\n\nNote: Ensure the interpreter is installed and in your PATH.", 
								Path.GetFileName(startInfo.FileName), ex.Message), 
								"Error starting process", MessageBoxButtons.OK, MessageBoxIcon.Error);
			}
			return 3;
		}
	}
}
"@

# Searchs for the csc compiler (priority to current runtime, then Framework 4.0 x64/x86)
$aCSCPath = @(
	(Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) "csc.exe"),
	(Join-Path $env:SystemRoot "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
	(Join-Path $env:SystemRoot "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)
$sCSCFile = $null
foreach ($sFile in $aCSCPath) {
	if (Test-Path -Path $sFile) {
		$sCSCFile = $sFile
		break
	}
}
if (-not $sCSCFile) {
	Write-Host "`nC# Compiler (csc.exe) not found on this system." -ForegroundColor Red
	_Exit 1 $true
}

# Sets the compiler settings (for all versions)
$sUTF8Encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { "UTF8BOM" } else { "UTF8" }
$sSourceFile = Join-Path $env:TEMP "HSR_source.cs"
$sReleaseDir = New-Item -Path (Join-Path $PSScriptRoot "Release") -ItemType Directory -Force
$sIconFile = Join-Path $PSScriptRoot "Data\Image\Icon.ico"
$sCodeCSharp | Out-File -FilePath $sSourceFile -Encoding $sUTF8Encoding -Force
$aTempFile = @($sSourceFile)

# Files configuration and arguments by version: x64, x86 (32-bit)
$bError = $false
$aPlatforms = @("x64", "x86")
foreach ($sArch in $aPlatforms) {
	$sSuffix = if ($sArch -eq "x86") { "_x86" } else { "" }
	$sOutFile = Join-Path $env:TEMP "HSR-csc_out$($sSuffix).txt"
	$sErrorFile = Join-Path $env:TEMP "HSR-csc_error$($sSuffix).txt"
	$sReleaseFile = Join-Path $sReleaseDir "HiddenScriptRunner$($sSuffix).exe"
	$sArguments = "/target:winexe /optimize /platform:$sArch /out:`"$sReleaseFile`" /win32icon:`"$sIconFile`" /utf8output /reference:System.dll,System.Core.dll,System.Windows.Forms.dll `"$sSourceFile`""
	$aTempFile += $sOutFile
	$aTempFile += $sErrorFile
	
	# Runs the compilation
	$pCompil = Start-Process -FilePath $sCSCFile -ArgumentList $sArguments -Wait -WindowStyle Hidden -PassThru -RedirectStandardOutput $sOutFile -RedirectStandardError $sErrorFile
	
	# Checks the result
	if ($pCompil.ExitCode -ne 0) {
		$bError = $true
		Write-Host "`nCompilation error (${sArch} version):`nExit code $($pCompil.ExitCode)" -BackgroundColor Black -ForegroundColor Red
		
		Write-Host "`nStandard error output:" -ForegroundColor Red
		if (Test-Path -Path $sErrorFile) { Get-Content -Path $sErrorFile -Encoding UTF8 | Out-String | Write-Host -ForegroundColor Red }
		
		Write-Host "`nStandard output:" -ForegroundColor Yellow
		if (Test-Path -Path $sOutFile) { Get-Content -Path $sOutFile -Encoding UTF8 | Out-String | Write-Host -ForegroundColor Yellow }
		_Pause
	}
}

# Cleans
Start-Sleep -Milliseconds 200
foreach ($sFile in $aTempFile) {
	if (Test-Path -Path $sFile) {
		Remove-Item -Path $sFile -Force -ErrorAction SilentlyContinue
	}
}

# Finish
if ($bError) {
	Write-Host "`nBuild Failed." -ForegroundColor Red
	_Exit 1
}
Write-Host "`nBuild completed." -ForegroundColor Green
_Exit 0
