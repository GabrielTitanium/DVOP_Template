param(
    [Parameter(Mandatory = $true)]
    [string]$AppName
)

# Define paths using parameter
$registryPath     = "HKLM:\SOFTWARE\Titanium\$AppName\Install"
$registryPathReg  = "HKEY_LOCAL_MACHINE\SOFTWARE\Titanium\$AppName\Install"
$backupDirectory  = "C:\registry_backup"
$backupFile       = Join-Path -Path $backupDirectory -ChildPath "Titanium_${AppName}_Install_Backup.reg"

Write-Host "Registry path: $registryPath"

# Check if the registry key exists
if (Test-Path -Path $registryPath) {

    # Create the backup directory if it does not exist
    if (-not (Test-Path -Path $backupDirectory)) {
        New-Item -Path $backupDirectory -ItemType Directory -Force | Out-Null
    }

    # Export the registry key to a .reg file
    reg export $registryPathReg $backupFile /y

    if ($LASTEXITCODE -ne 0) {
        Write-Output "Failed to create backup of registry key $registryPath."
        exit 1
    }

    Write-Output "Backup of registry key $registryPath has been successfully created at $backupFile."

    # Check if the backup was created successfully
    if (Test-Path -Path $backupFile) {

        # Remove the registry key and all its subkeys
        try {
            Remove-Item -Path $registryPath -Recurse -Force -ErrorAction Stop
            Start-Sleep -Seconds 2  # Ensure deletion completes

            # Confirm the removal
            if (-not (Test-Path -Path $registryPath)) {
                Write-Output "Registry key $registryPath has been successfully removed."
            } else {
                Write-Output "Failed to remove registry key $registryPath."
                exit 1
            }

        } catch {
            Write-Output "Error occurred while removing registry key $registryPath."
            Write-Output $_.Exception.Message
            exit 1
        }

    } else {
        Write-Output "Backup file was not created, skipping registry deletion."
        exit 1
    }

} else {
    Write-Output "Registry key $registryPath does not exist."
}

exit 0