param (
    [string]$insuranceHostUrl,
    [string]$basePath,
    [string]$webConfigPath
)


# Find appsettings.json recursively
$file = Get-ChildItem -Path $basePath -Filter "appsettings.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $file) {
    Write-Host "appsettings.json not found under $basePath"
    exit
}

Write-Host "Found: $($file.FullName)"

# Read JSON content
$json = Get-Content $file.FullName -Raw | ConvertFrom-Json

# Backup original file
$backupPath = "$($file.FullName).bak"
Copy-Item $file.FullName $backupPath -Force
Write-Host "Backup created at: $backupPath"

# Update specific fields in InsuranceSettings
$json.InsuranceSettings.TransmissionSystem       = "CDANET"
#$json.InsuranceSettings.DentalXChangeUrl         = "https://staging-api.dentalxchange.com/"
$json.InsuranceSettings.DentalXChangeApiKey      = "eyJvcmciOiI2MzRlNTFhNGQxOWU4MTAwMDFjNjM5ZTkiLCJpZCI6ImYyYTRkMjdlOTU2MTRjOGZiMGJmMDFmNGU1YjQ5ZjZkIiwiaCI6Im11cm11cjEyOCJ9"
$json.InsuranceSettings.DentalXChangeApiUserName = "TitaniumUser"
$json.InsuranceSettings.DentalXChangeApiPassword = "Tooth123"

# Convert back to JSON (proper 2-space indentation)
try {
    Add-Type -AssemblyName 'Newtonsoft.Json' -ErrorAction Stop
    $jsonString = [Newtonsoft.Json.JsonConvert]::SerializeObject($json, [Newtonsoft.Json.Formatting]::Indented)
}
catch {
    # Fallback to built-in ConvertTo-Json
    $jsonString = $json | ConvertTo-Json -Depth 10
}

# Normalize indentation to 2 spaces (PowerShell default uses 4)
$jsonString = ($jsonString -split "`n" | ForEach-Object { $_ -replace '^\s{4}', '  ' }) -join "`n"

# Write the formatted JSON back
$jsonString | Out-File -FilePath $file.FullName -Encoding UTF8

Write-Host "appsettings.json updated and formatted successfully."

# --- Update web.config InsuranceHostURL ---
# Resolve web.config path (accept a directory or direct file path)
$webConfigFullPath = if (Test-Path $webConfigPath -PathType Leaf) { $webConfigPath } else { Join-Path $webConfigPath 'web.config' }

if (-not (Test-Path $webConfigFullPath)) {
    Write-Host "web.config not found at: $webConfigFullPath"
    exit
}

Write-Host "Found web.config: $webConfigFullPath"

# Backup web.config
Copy-Item -Path $webConfigFullPath -Destination "$webConfigFullPath.bak" -Force
Write-Host "Backup created: $webConfigFullPath.bak"

# Load and modify XML
[xml]$webXml = Get-Content -Path $webConfigFullPath

$insuranceNode = $webXml.configuration.appSettings.add | Where-Object { $_.key -eq 'InsuranceHostURL' }

if (-not $insuranceNode) {
    Write-Host 'Key "InsuranceHostURL" not found in <appSettings>.'
} else {
    $insuranceNode.value = $insuranceHostUrl
    $webXml.Save($webConfigFullPath)
    Write-Host "Updated InsuranceHostURL to: $insuranceHostUrl"
}
