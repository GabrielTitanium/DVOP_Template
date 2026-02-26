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

# Check if the 'w3svc' service exists
$service = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
if ($service) {
    try {
        Write-Host "Starting IIS ($service.Name)..."
        Start-Service -Name "W3SVC" -ErrorAction Stop
    } catch {
        Write-Host "Error starting IIS: $_"
        exit 1
    }

    # Wait for IIS to start completely
    $timeout = 90 # Max wait time in seconds
    $elapsed = 0
    $interval = 10  # Check every 10 seconds

    while (($service = Get-Service -Name "W3SVC").Status -ne "Running" -and $elapsed -lt $timeout) {
        if ((Get-Service -Name "W3SVC").Status -ne "Running") {
            Write-Host "Waiting for IIS to start... ($elapsed seconds elapsed)"
            Start-Sleep -Seconds $interval
            $elapsed += $interval
        }
    }

    # Final verification
    if ((Get-Service -Name "W3SVC").Status -eq "Running") {
        Write-Host "IIS (w3svc) has started successfully."
    } else {
        Write-Host "IIS did not start within $timeout seconds."
        exit 1
    }
}
else {
    Write-Host "Service 'W3SVC' not found. Skipping IIS (w3svc) start step."
}