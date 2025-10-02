<#
.SYNOPSIS
    Uninstalls AnyDesk from Windows devices via Intune
.DESCRIPTION
    This script removes AnyDesk application and cleans up residual files and registry entries
.NOTES
    Deploy as a Win32 app or PowerShell script in Intune
    Run as SYSTEM account
#>

# Set execution policy and error handling
$ErrorActionPreference = "SilentlyContinue"
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\AnyDesk_Uninstall.log"

function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogPath -Append
    Write-Host $Message
}

Write-Log "=== AnyDesk Uninstallation Started ==="

# Function to stop AnyDesk processes
function Stop-AnyDeskProcesses {
    Write-Log "Stopping AnyDesk processes..."
    $processes = @("AnyDesk", "AnyDeskService")
    foreach ($proc in $processes) {
        Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Log "Stopped process: $proc"
    }
    Start-Sleep -Seconds 2
}

# Function to stop AnyDesk service
function Stop-AnyDeskService {
    Write-Log "Stopping AnyDesk service..."
    $service = Get-Service -Name "AnyDesk" -ErrorAction SilentlyContinue
    if ($service) {
        Stop-Service -Name "AnyDesk" -Force -ErrorAction SilentlyContinue
        Write-Log "AnyDesk service stopped"
    }
}

# Function to uninstall via registry
function Uninstall-ViaRegistry {
    Write-Log "Attempting uninstall via registry..."
    
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AnyDesk",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\AnyDesk"
    )
    
    foreach ($path in $uninstallPaths) {
        if (Test-Path $path) {
            $uninstallString = (Get-ItemProperty -Path $path -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
            if ($uninstallString) {
                Write-Log "Found uninstall string: $uninstallString"
                
                # Execute uninstall silently
                if ($uninstallString -match '"(.+?)"') {
                    $exePath = $matches[1]
                    Start-Process -FilePath $exePath -ArgumentList "--remove", "--silent" -Wait -NoNewWindow
                    Write-Log "Executed uninstall command"
                }
            }
        }
    }
}

# Function to remove AnyDesk files
function Remove-AnyDeskFiles {
    Write-Log "Removing AnyDesk files..."
    
    $pathsToRemove = @(
        "$env:ProgramFiles\AnyDesk",
        "$env:ProgramFiles(x86)\AnyDesk",
        "$env:ProgramData\AnyDesk",
        "$env:APPDATA\AnyDesk",
        "$env:LOCALAPPDATA\AnyDesk"
    )
    
    foreach ($path in $pathsToRemove) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed: $path"
        }
    }
}

# Function to remove AnyDesk from user profiles
function Remove-UserProfileData {
    Write-Log "Removing AnyDesk from user profiles..."
    
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $userProfiles) {
        $userPaths = @(
            "$($profile.FullName)\AppData\Roaming\AnyDesk",
            "$($profile.FullName)\AppData\Local\AnyDesk"
        )
        
        foreach ($path in $userPaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Removed user data: $path"
            }
        }
    }
}

# Function to clean registry entries
function Remove-RegistryEntries {
    Write-Log "Cleaning registry entries..."
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\AnyDesk",
        "HKLM:\SOFTWARE\WOW6432Node\AnyDesk",
        "HKCU:\SOFTWARE\AnyDesk"
    )
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed registry: $path"
        }
    }
}

# Main execution
try {
    Stop-AnyDeskProcesses
    Stop-AnyDeskService
    Uninstall-ViaRegistry
    Start-Sleep -Seconds 3
    Stop-AnyDeskProcesses  # Stop again in case uninstaller relaunched it
    Remove-AnyDeskFiles
    Remove-UserProfileData
    Remove-RegistryEntries
    
    Write-Log "=== AnyDesk Uninstallation Completed Successfully ==="
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "=== AnyDesk Uninstallation Failed ==="
    exit 1
}