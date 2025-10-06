# 7-Zip Silent Uninstall Script for Intune
# This script forcefully and silently uninstalls 7-Zip from Windows machines

# Set execution policy and error handling
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Continue"

# Function to write log entries
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path "C:\Windows\Temp\7zip_uninstall.log" -Value $logMessage
}

Write-Log "Starting 7-Zip uninstallation process"

# Method 1: Uninstall using Windows Registry (most reliable)
try {
    Write-Log "Attempting registry-based uninstall"
   
    # Get 7-Zip uninstall string from registry
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
   
    $sevenZipFound = $false
   
    foreach ($keyPath in $uninstallKeys) {
        $apps = Get-ItemProperty $keyPath -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*7-Zip*"
        }
       
        foreach ($app in $apps) {
            $sevenZipFound = $true
            Write-Log "Found 7-Zip: $($app.DisplayName) - Version: $($app.DisplayVersion)"
           
            if ($app.UninstallString) {
                $uninstallString = $app.UninstallString
                Write-Log "Uninstall string: $uninstallString"
               
                # Handle different uninstall string formats
                if ($uninstallString -match 'msiexec') {
                    # MSI-based installation
                    $productCode = $app.PSChildName
                    Write-Log "Uninstalling MSI package: $productCode"
                    Start-Process "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait -NoNewWindow
                }
                elseif ($uninstallString -like "*Uninstall.exe*") {
                    # Standard uninstaller
                    $uninstaller = $uninstallString -replace '"', ''
                    Write-Log "Running uninstaller: $uninstaller"
                    Start-Process $uninstaller -ArgumentList "/S" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                }
                else {
                    # Generic approach
                    Write-Log "Running generic uninstall command"
                    Invoke-Expression "& $uninstallString /S" -ErrorAction SilentlyContinue
                }
            }
        }
    }
   
    if (-not $sevenZipFound) {
        Write-Log "7-Zip not found in registry"
    }
}
catch {
    Write-Log "Registry uninstall failed: $($_.Exception.Message)"
}

# Method 2: Using Get-WmiObject (alternative approach)
try {
    Write-Log "Attempting WMI-based uninstall"
    $wmiApps = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*7-Zip*" }
   
    foreach ($app in $wmiApps) {
        Write-Log "Found via WMI: $($app.Name)"
        $app.Uninstall() | Out-Null
        Write-Log "WMI uninstall initiated for: $($app.Name)"
    }
}
catch {
    Write-Log "WMI uninstall failed: $($_.Exception.Message)"
}

# Method 3: Force remove files and folders
try {
    Write-Log "Attempting manual file removal"
   
    # Common 7-Zip installation paths
    $paths = @(
        "${env:ProgramFiles}\7-Zip",
        "${env:ProgramFiles(x86)}\7-Zip",
        "${env:LocalAppData}\7-Zip"
    )
   
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Log "Removing directory: $path"
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
   
    # Remove registry entries
    $regPaths = @(
        "HKLM:\SOFTWARE\7-Zip",
        "HKLM:\SOFTWARE\WOW6432Node\7-Zip",
        "HKCU:\SOFTWARE\7-Zip"
    )
   
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            Write-Log "Removing registry path: $regPath"
            Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
catch {
    Write-Log "Manual removal failed: $($_.Exception.Message)"
}

# Method 4: Remove from PATH environment variable
try {
    Write-Log "Cleaning PATH environment variable"
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $newPath = ($currentPath -split ';' | Where-Object { $_ -notlike "*7-Zip*" }) -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
}
catch {
    Write-Log "PATH cleanup failed: $($_.Exception.Message)"
}

# Method 5: Kill any running 7-Zip processes
try {
    Write-Log "Terminating 7-Zip processes"
    Get-Process | Where-Object { $_.ProcessName -like "*7z*" -or $_.ProcessName -like "*7-Zip*" } | Stop-Process -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Log "Process termination failed: $($_.Exception.Message)"
}

# Verify uninstallation
$verification = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*7-Zip*" }

if ($verification) {
    Write-Log "WARNING: 7-Zip entries still found after uninstallation attempt"
    exit 1
} else {
    Write-Log "7-Zip uninstallation completed successfully"
    exit 0
}
