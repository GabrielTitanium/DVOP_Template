param(
    [string]$DB_IP,
    [string]$DB_NAME,
    [string]$BackupPath,
    [string]$SQL_USER
)

# Grab the password from environment variable
$SQL_PASSWORD = $env:SQL_PASSWORD

# Log input values (for debugging)
Write-Host "DB_IP: $DB_IP"
Write-Host "DB_NAME: $DB_NAME"
Write-Host "BackupPath: $BackupPath"
Write-Host "SQL_USER: $SQL_USER"
Write-Host "SQL_PASSWORD length: $($SQL_PASSWORD.Length)"

# --- Ensure backup folder exists ---
if (-not (Test-Path $BackupPath)) {
    Write-Host "Backup directory '$BackupPath' does not exist. Creating it..."
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
}

# --- Generate dynamic filename if not supplied via env ---
$file = $env:BackupFileName
if ([string]::IsNullOrEmpty($file)) {
    $file = "$($DB_NAME)-pre-upgrade_$(Get-Date -Format yyyy-MM-dd).bak"
}

$path = Join-Path $BackupPath $file

# --- Delete existing backup if present ---
if (Test-Path $path) {
    Write-Host "Overwriting existing backup: $path"
    Remove-Item $path -Force
}

# --- Build T-SQL BACKUP command and connection string ---
$qry = @"
BACKUP DATABASE [$DB_NAME]
TO DISK = N'$path'
WITH NOFORMAT, INIT,
NAME = N'$($DB_NAME)-Full Database Backup',
SKIP, STATS = 10;
"@

$cs  = "Server=$DB_IP;Database=$DB_NAME;User ID=$SQL_USER;Password=$SQL_PASSWORD;TrustServerCertificate=True;"

# --- Perform backup ---
Write-Host "Starting backup of '$DB_NAME' to '$path'..."
try {
    Invoke-Sqlcmd -ConnectionString $cs -Query $qry
    Write-Host "✔ Backup completed successfully."
    Write-Host "Backup file: $path"

    # --- SAFELY export the final path as a pipeline output variable ---
    $safePath = $path -replace ";","%3B" -replace "]","%5D" -replace "`n","" -replace "`r",""
    $adoCommand = "##vso[task.setvariable variable=BackupFilePath;isOutput=true]$safePath"
    Write-Host $adoCommand
}
catch {
    Write-Host "Backup failed. Raw exception:"
    Write-Host $_ | Out-String
    exit 1
}
