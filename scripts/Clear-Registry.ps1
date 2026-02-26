# Ensure script is running as administrator
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Script is not running as administrator. Relaunching with elevation..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = 'runas'
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Host "Failed to relaunch script as administrator: $_"
        exit 1
    }
    exit 0
}

# Define the path to the registry key
$registryPath = "HKLM:\SOFTWARE\Titanium\Origin\Install"
$registryPathReg = "HKEY_LOCAL_MACHINE\SOFTWARE\Titanium\Origin\Install"
$backupDirectory = "C:\registry_backup"
$backupFile = Join-Path -Path $backupDirectory -ChildPath "Titanium_Origin_Install_Backup.reg"

# Check if the registry key exists
if (Test-Path -Path $registryPath) {
    # Create the backup directory if it does not exist
    if (-not (Test-Path -Path $backupDirectory)) {
        New-Item -Path $backupDirectory -ItemType Directory
    }

    # Export the registry key to a .reg file
    try {
        reg export $registryPathReg $backupFile /y
        Write-Output "Backup of registry key $registryPath has been successfully created at $backupFile."
    } catch {
        Write-Output "Failed to create backup of registry key $registryPath."
        throw
    }

    # Check if the backup was created successfully
    if (Test-Path -Path $backupFile) {
        # Remove the registry key and all its subkeys
        Remove-Item -Path $registryPath -Recurse -Force

        # Confirm the removal
        if (-not (Test-Path -Path $registryPath)) {
            Write-Output "Registry key $registryPath has been successfully removed."
        } else {
            Write-Output "Failed to remove registry key $registryPath."
        }
    } else {
        Write-Output "Failed to create backup of registry key $registryPath."
    }
} else {
    Write-Output "Registry key $registryPath does not exist."
}
exit 0
