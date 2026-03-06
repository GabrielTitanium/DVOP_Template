# Define the path to the web.config file
$webConfigPath = "C:\Program Files\Titanium Solutions\Dental Web Services\web.config"

# Load the XML
if (-Not (Test-Path $webConfigPath)) {
    Write-Error "web.config not found at $webConfigPath"
    exit 1
}

[xml]$webConfig = Get-Content $webConfigPath

# Ensure appSettings section exists
if (-not $webConfig.configuration.appSettings) {
    Write-Error "appSettings section not found in web.config."
    exit 1
}

# Define ALL keys and values in one place
$appSettings = @{
    "TitaniumBrowserReportingServicesUserName" = "ReportsUser"
    "TitaniumBrowserReportingServicesPassword" = "!Accountforreportingservices1"
    "TitaniumSolutionsNoSecurity"              = "true"
}

# Update or Add appSettings
foreach ($key in $appSettings.Keys) {

    $existingNode = $webConfig.configuration.appSettings.add |
        Where-Object { $_.key -eq $key }

    if ($existingNode) {
        # Update existing node
        $existingNode.value = $appSettings[$key]
        Write-Host "Updated key: $key"
    }
    else {
        # Add new node
        $newNode = $webConfig.CreateElement("add")
        $newNode.SetAttribute("key", $key)
        $newNode.SetAttribute("value", $appSettings[$key])
        $webConfig.configuration.appSettings.AppendChild($newNode) | Out-Null
        Write-Host "Added key: $key"
    }
}

# Save changes
$webConfig.Save($webConfigPath)

Write-Host "web.config updated successfully."