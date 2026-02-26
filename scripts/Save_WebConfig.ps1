# backup-webconfig.ps1
# This script must be run as Administrator

$sourcePath = "C:\Program Files\Titanium Solutions\Dental Web Services\web.config"
$backupFolder = "C:\Web.config_Backups"

# Ensure backup directory exists (continue if it already exists)
if (!(Test-Path -Path $backupFolder)) {
    New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
    Write-Host "Created folder: $backupFolder"
} else {
    Write-Host "Folder already exists: $backupFolder"
}

# Generate base backup filename with date
$date = Get-Date -Format "dd_MM_yyyy"
$baseName = "web.config.backup_$date"
$backupFilePath = Join-Path $backupFolder $baseName

# If file already exists, append counter (_2, _3, etc.)
$counter = 1
while (Test-Path -Path $backupFilePath) {
    $counter++
    $backupFilePath = Join-Path $backupFolder ("web.config.backup_{0}_{1}" -f $counter, $date)
}

# Copy the web.config file to the backup folder
Write-Host "Creating backup: $backupFilePath"
Copy-Item -Path $sourcePath -Destination $backupFilePath -Force

Write-Host "Backup completed successfully."
