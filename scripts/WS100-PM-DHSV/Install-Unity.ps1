param (
    [string]$buildDirectory = "C:\Build\",
    [string]$installerFile = "Setup_Origin.msi",
    [string]$logFile = "msiexec.log",
    [string]$installDir = "C:\Program Files\Titanium Solutions",
    [string]$features = "SelfCheckInFeature,WebServicesFeature,ConfigureIISFeature,APIServicesFeature,RenderServicesFeature",
    [string]$webSite = "Default Web Site",
    [string]$webDescription = "Default Web Site",
    [string]$webSPort = 80,
    [string]$webSiteIp = "*",
    [string]$dsnMssqlDatabase,
    [string]$dsnMssqlPassword,
    [string]$dsnMssqlServer,
    [string]$dsnMssqlUsername,
    [string]$webServicesPathName = "TITANIUMWSERVER",
    [string]$webApplicationsPathName = "TITANIUMCLIENT",
    [string]$allowMultipleVersions = "No",
    [string]$webAppName = "Unity",
    [string]$webAppPool = "TitaniumSolutionsDentalAppPool",
    [string]$webAppPoolCreate = "true",
    [string]$documentsPath = "%ALLUSERSPROFILE%\Titanium Solutions\Documents",
    [string]$reportingServicesURL = "",
    [string]$reportingServicesContextFolder = "",
    [string]$reportingServicesMenuFolder = "",
    [string]$reportingServicesUserName = "",
    [string]$reportingServicesPassword
)

# Check if the script is running with admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script requires administrative privileges but is running without them. Ensure the agent is running with sufficient privileges."
    Exit 1
}

if ($?) {
    Write-Host "Windows Installer service started successfully."
} else {
    Write-Host "Failed to start Windows Installer service."
    exit 1
}

$buildPath = "C:\Build"
if (-Not (Test-Path -Path $buildPath)) {
    Write-Host "Creating Build directory..."
    New-Item -ItemType Directory -Path $buildPath
} else {
    Write-Host "Build directory already exists."
}

cd "C:\Build"

$features = "WebServicesFeature,ConfigureIISFeature,APIServicesFeature,RenderServicesFeature"

$installerGuestName = "C:\Build\Setup_Unity.msi"
if (-Not (Test-Path -Path $installerGuestName)) {
    Write-Host "Installer is not in Build directory... $installerGuestName"
    exit 0
} else {
    Write-Host "Installer found."
}

 Write-Host "dsnMssqlDatabase $dsnMssqlDatabase"
# Construct installation command
$arguments = @(
    "/i", "`"$installerPath`"",
    "/l*v", "`"$logPath`"",
    "/qb",
    "INSTALLDIR=`"$installDir`"",
    "ADDLOCAL=`"$features`"",
    "WEBSITE=`"$webSite`"",
    "WEBSITE_IP=`"$webSiteIp`"",
    "WEBSITE_PORT=`"$webSPort`"",
    "WEBSITE_DESCRIPTION=`"$webDescription`"",
    "DSN_MSSQL_DATABASE=`"$dsnMssqlDatabase`"",
    "DSN_MSSQL_PASSWORD=`"$dsnMssqlPassword`"",
    "DSN_MSSQL_SERVER=`"$dsnMssqlServer`"",
    "DSN_MSSQL_USERNAME=`"$dsnMssqlUsername`"",
    "WEBSERVICESPATHNAME=`"$webServicesPathName`"",
    "WEBAPPLICATIONSPATHNAME=`"$webApplicationsPathName`"",
    "ALLOWMULTIPLEVERSIONS=`"$allowMultipleVersions`"",
    "WEBAPP_NAME=`"$webAppName`"",
    "WEBSITE_APPPOOL=`"$webAppPool`"",
    "WEBSITE_APPPOOL_CREATE=`"$webAppPoolCreate`"",
    "REPORTING_SERVICES_URL=`"$reportingServicesURL`"",
    "REPORTING_SERVICES_CONTEXT_FOLDER=`"$reportingServicesContextFolder`"",
    "REPORTING_SERVICES_MENU_FOLDER=`"$reportingServicesMenuFolder`"",
    "REPORTING_SERVICES_USER_NAME=`"$reportingServicesUserName`"",
    "REPORTING_SERVICES_PASSWORD=`"$reportingServicesPassword`"",
    "DOCUMENTS_PATH=`"$documentsPath`""
)

Write-Host "Starting MSI installer..."
$process = Start-Process "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow -PassThru

# Monitor installation progress
$timeout = 600 # 10 minutes
$elapsedTime = 0 # seconds
$interval = 5 # seconds

while (!$process.HasExited -and $elapsedTime -lt $timeout) {
    Start-Sleep -Seconds $interval
    $elapsedTime += $interval
    Write-Host "Waiting for installer to complete... ($elapsedTime seconds elapsed)"
}

if (!$process.HasExited) {
    Write-Host "Installer is still running after $timeout seconds. Terminating process."
    $process.Kill()
    exit 1
} else {
    Write-Host "Installer completed successfully."
}