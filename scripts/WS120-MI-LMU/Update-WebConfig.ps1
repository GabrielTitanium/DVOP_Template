# Define the path to the web.config file
$webConfigPath = "C:\Program Files\Titanium Solutions\Dental Web Services\web.config"

# Load the XML
[xml]$webConfig = Get-Content $webConfigPath

# Define the appSettings keys and their new values
$appSettings = @{
    "TitaniumBrowserReportingServicesUserName" = "ReportsUser"
    "TitaniumBrowserReportingServicesPassword" = "!Accountforreportingservices1"   
}

# Update appSettings
foreach ($key in $appSettings.Keys) {
    $existingNode = $webConfig.configuration.appSettings.add | Where-Object { $_.key -eq $key }
    if ($existingNode) {
        # Update existing node
        $existingNode.value = $appSettings[$key]
    } else {
        # Add new node
        $newNode = $webConfig.CreateElement("add")
        $newNode.SetAttribute("key", $key)
        $newNode.SetAttribute("value", $appSettings[$key])
        $webConfig.configuration.appSettings.AppendChild($newNode)
    }
}

# Save the changes back to the web.config file
$webConfig.Save($webConfigPath)

Write-Host "web.config updated successfully."