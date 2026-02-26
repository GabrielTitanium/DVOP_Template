param (
    [string]$exePath = "C:\Program Files\Titanium Solutions\Dental Web Services\bin\Titanium.Migration.DataAccess.Migration.exe",
    [string]$server ,
    [string]$database,
    [string]$user,
    [string]$password,
    [string]$logFile = "C:\Build\DataMigrationLog.txt"
)
# Ensure script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator."
    exit 1
}

# Ensure the EXE exists
if (-not (Test-Path -Path $exePath)) {
    Write-Host "Error: Migration executable not found at $exePath"
    exit 1
}

# Build command line
$cmd = "`"$exePath`" -server=`"$server`" -database=`"$database`" -user=`"$user`" -password=`"$password`" -autorun -audittables"

Write-Host "Running data migration command:"
Write-Host "   $cmd"
Write-Host "--------------------------------------------"

# Run the migration and capture live + file output
try {
    cmd /c $cmd | Tee-Object -FilePath $logFile

    # Get process exit code
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Host "Migration process failed with exit code: $exitCode"
        Write-Host "----- Last 10 log lines -----"
        Get-Content $logFile -Tail 10 | ForEach-Object { Write-Host $_ }
        exit $exitCode
    }
    else {
        Write-Host "Data migration completed successfully."
        Write-Host "--------------------------------------------"
        Write-Host "Log saved to: $logFile"
    }
}
catch {
    Write-Host "Error while running migration process: $_"
    exit 1
}