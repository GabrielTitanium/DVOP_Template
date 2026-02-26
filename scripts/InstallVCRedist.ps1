# Define the URLs for the Visual C++ Redistributable installers
$vcRedistX86Url = "https://aka.ms/vs/16/release/vc_redist.x86.exe"
$vcRedistX64Url = "https://aka.ms/vs/16/release/vc_redist.x64.exe"
$installerPathX86 = "C:\Redist\vc_redist.x86.exe"
$installerPathX64 = "C:\Redist\vc_redist.x64.exe"

function Test-VCRedistInstalled {
    param (
        [string]$arch
    )
    $key = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$arch"
    if (Test-Path $key) {
        $val = Get-ItemProperty -Path $key -Name "Installed" -ErrorAction SilentlyContinue
        return ($val.Installed -eq 1)
    }
    return $false
}

$vcRedistX86Installed = Test-VCRedistInstalled -arch "x86"
$vcRedistX64Installed = Test-VCRedistInstalled -arch "x64"

if ($vcRedistX86Installed -and $vcRedistX64Installed) {
    Write-Output "Both Visual C++ Redistributables (x86 and x64) are already installed. Skipping installation."
    return
}

try {
    # Ensure the download directory exists
    if (-Not (Test-Path -Path "C:\Redist")) {
        New-Item -ItemType Directory -Path "C:\Redist" -Force
    }

    if (-not $vcRedistX86Installed) {
        # Download the x86 installer
        Write-Output "Downloading Visual C++ Redistributable x86 installer from $vcRedistX86Url..."
        Invoke-WebRequest -Uri $vcRedistX86Url -OutFile $installerPathX86 -Verbose
        Write-Output "Download complete."

        # Install the x86 Redistributable
        Write-Output "Starting Visual C++ Redistributable x86 installation..."
        Start-Process -FilePath $installerPathX86 -ArgumentList "/quiet", "/norestart" -Wait
        Write-Output "Visual C++ Redistributable x86 installation complete."
    } else {
        Write-Output "Visual C++ Redistributable x86 is already installed. Skipping."
    }

    if (-not $vcRedistX64Installed) {
        # Download the x64 installer
        Write-Output "Downloading Visual C++ Redistributable x64 installer from $vcRedistX64Url..."
        Invoke-WebRequest -Uri $vcRedistX64Url -OutFile $installerPathX64 -Verbose
        Write-Output "Download complete."

        # Install the x64 Redistributable
        Write-Output "Starting Visual C++ Redistributable x64 installation..."
        Start-Process -FilePath $installerPathX64 -ArgumentList "/quiet", "/norestart" -Wait
        Write-Output "Visual C++ Redistributable x64 installation complete."
    } else {
        Write-Output "Visual C++ Redistributable x64 is already installed. Skipping."
    }

    # Clean up the installer files
    if (Test-Path $installerPathX86) { Remove-Item -Path $installerPathX86 -Force }
    if (Test-Path $installerPathX64) { Remove-Item -Path $installerPathX64 -Force }
    Write-Output "Installer files removed successfully."
} catch {
    Write-Error "An error occurred: $_"
    Exit 1
}