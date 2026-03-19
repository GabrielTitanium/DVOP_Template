param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter part or all of the application name(s).")]
    [string[]]$ApplicationName,  # Changed to string array

    [Parameter(Mandatory = $false, HelpMessage = "Include this switch to uninstall the found application.")]
    [switch]$Uninstall
)

# Define registry paths for both 32-bit and 64-bit installations.
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Search the registry for installed applications matching any of the names.
$apps = foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Get-ItemProperty -Path $path | Where-Object {
            $currentApp = $_
            $_.DisplayName -and ($ApplicationName | Where-Object { $currentApp.DisplayName -ilike "*$_*" })
        }
    }
}

# Rest of your script remains the same...
if (-not $apps) {
    Write-Host "No applications matching the specified names were found." -ForegroundColor Yellow
    exit 0
}

foreach ($app in $apps) {
    $productCode = $app.PSChildName
    $displayName = $app.DisplayName
    Write-Host "Found application: $displayName (Product Code: $productCode)" -ForegroundColor Green

    if ($Uninstall) {
        Write-Host "Attempting to uninstall $displayName..." -ForegroundColor Cyan
        $process = Start-Process msiexec.exe -ArgumentList "/x $productCode /qn" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "$displayName uninstalled successfully." -ForegroundColor Green
        }
        else {
            Write-Host "Uninstallation of $displayName (Product Code: $productCode) encountered an error. Exit code: $($process.ExitCode)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Uninstallation skipped for $displayName. Use -Uninstall switch to proceed." -ForegroundColor Yellow
    }
}