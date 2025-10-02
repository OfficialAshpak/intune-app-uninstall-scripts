# Uninstall UltraViewer Script for Intune
# This script removes UltraViewer from Windows devices

$AppName = "UltraViewer"
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogPath\UltraViewer_Uninstall.log"

# Create log directory if it doesn't exist
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Function to write to log
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Output $Message
}

Write-Log "Starting UltraViewer uninstallation process..."

# Method 1: Check registry for uninstall string (most reliable)
$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$Found = $false

foreach ($Path in $UninstallPaths) {
    $Apps = Get-ItemProperty $Path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*UltraViewer*" }
    
    foreach ($App in $Apps) {
        $Found = $true
        Write-Log "Found UltraViewer: $($App.DisplayName)"
        
        if ($App.UninstallString) {
            Write-Log "Uninstall string: $($App.UninstallString)"
            
            # Parse the uninstall string
            if ($App.UninstallString -match '"(.+?)"') {
                $UninstallPath = $matches[1]
                $Arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
                
                Write-Log "Executing uninstall: $UninstallPath $Arguments"
                
                try {
                    $Process = Start-Process -FilePath $UninstallPath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
                    
                    if ($Process.ExitCode -eq 0) {
                        Write-Log "UltraViewer uninstalled successfully (Exit Code: 0)"
                    } else {
                        Write-Log "Uninstall completed with exit code: $($Process.ExitCode)"
                    }
                } catch {
                    Write-Log "ERROR: Failed to execute uninstaller - $($_.Exception.Message)"
                }
            }
        }
    }
}

# Method 2: Check common installation paths
$CommonPaths = @(
    "$env:ProgramFiles\UltraViewer",
    "$env:ProgramFiles(x86)\UltraViewer",
    "$env:LOCALAPPDATA\UltraViewer"
)

foreach ($InstallPath in $CommonPaths) {
    if (Test-Path $InstallPath) {
        Write-Log "Found installation directory: $InstallPath"
        
        # Look for uninstaller
        $UninstallerPath = Join-Path $InstallPath "unins000.exe"
        if (Test-Path $UninstallerPath) {
            Write-Log "Found uninstaller at: $UninstallerPath"
            
            try {
                $Process = Start-Process -FilePath $UninstallerPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -NoNewWindow
                Write-Log "Uninstaller executed with exit code: $($Process.ExitCode)"
                $Found = $true
            } catch {
                Write-Log "ERROR: Failed to execute uninstaller - $($_.Exception.Message)"
            }
        }
    }
}

# Method 3: Stop UltraViewer process if running
$ProcessName = "UltraViewer"
$RunningProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

if ($RunningProcess) {
    Write-Log "Stopping UltraViewer process..."
    try {
        Stop-Process -Name $ProcessName -Force -ErrorAction Stop
        Write-Log "UltraViewer process stopped successfully"
    } catch {
        Write-Log "ERROR: Failed to stop process - $($_.Exception.Message)"
    }
}

# Final verification
Start-Sleep -Seconds 3
$Verification = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*UltraViewer*" }

if ($Verification) {
    Write-Log "WARNING: UltraViewer may still be installed"
    exit 1
} elseif ($Found) {
    Write-Log "UltraViewer uninstallation completed successfully"
    exit 0
} else {
    Write-Log "UltraViewer was not found on this system"
    exit 0
}