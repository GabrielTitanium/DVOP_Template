param(
    [string]$DB_IP,
    [string]$DB_NAME,
    [string]$BackupPath,
    [string]$SQL_USER,
    [string]$SQL_PASSWORD
)

write-host "Received parameters:"
write-host "DB_IP: $DB_IP"
write-host "DB_NAME: $DB_NAME"
write-host "BackupPath: $BackupPath"
write-host "SQL_USER: $SQL_USER"

#— verify that the backup folder exists
if (-not (Test-Path $BackupPath)) {
Write-Host "Backup directory '$BackupPath' does not exist. Creating it..."
New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
}

# if no filename was supplied, generate one as "<Database>_pre-upgrade_<yyyy-MM-dd>.bak"
$file = $env:BackupFileName
if ([string]::IsNullOrEmpty($file)) {
$file = "$($DB_NAME)-pre-upgrade_$(Get-Date -Format yyyy-MM-dd).bak"
}

$path = Join-Path $BackupPath $file
#— if a file already exists, skip backup
if (Test-Path $path) {
    Write-Host "Backup file already exists. Skipping backup."
    Write-Host "Existing backup file: $path"
    #— export the final path as a pipeline (output) variable
    Write-Host "##vso[task.setvariable variable=BackupFilePath;isOutput=true]$path"

    # Export variable for downstream tasks
    Write-Host "##vso[task.setvariable variable=BackupFilePath;isOutput=true]$path"
    exit 0
}

#— build the T-SQL BACKUP command and connection string (with TrustServerCertificate=True)
$qry = "BACKUP DATABASE [$DB_NAME] TO DISK = N'$path' WITH NOFORMAT, INIT, NAME = N'$DB_NAME-Full Database Backup', SKIP, STATS = 10;"
$cs  = "Server=$DB_IP;Database=$DB_NAME;User ID=$SQL_USER;Password=$SQL_PASSWORD;TrustServerCertificate=True;"

Write-Host "Starting backup of '$DB_NAME' to '$path'..."
try {
    Invoke-Sqlcmd -ConnectionString $cs -Query $qry
    Write-Host "✔ Backup completed successfully."
    Write-Host "Backup file: $path"
    #— export the final path as a pipeline (output) variable
    Write-Host "##vso[task.setvariable variable=BackupFilePath;isOutput=true]$path"
}
catch {
    Write-Error "Backup failed: $($_.Exception.Message)"
    exit 1
}
