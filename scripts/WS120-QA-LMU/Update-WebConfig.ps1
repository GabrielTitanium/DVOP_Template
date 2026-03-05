# Path to your web.config file
$webConfigPath = "C:\Program Files\Titanium Solutions\Dental Web Services\web.config"

# Load the config as XML
[xml]$config = Get-Content $webConfigPath

# Define the updates you want (key = value)
$updates = @{
    "WebServicesHost" = "ws120-QA-LMU.T.TITANIUM.SOLUTIONS"
    "ImagingHostBaseAddress" = "https://ws120-QA-LMU.T.TITANIUM.SOLUTIONS/TitaniumImaging/api/"   
    "ClientApplicationIdentity" = "QA_LMU"
    "ClientPort" = "1000"  
    "ServerApplicationIdentity" = "MI_SERVER"  
    "ServerAddress" = "TI-PACS-QA.t.titanium.solutions"  
    "ServerPort" = "104"  
    "RenderExternalAddress" = "https://ws120-QA-LMU.t.titanium.solutions/TitaniumRender"  
}

# Update the values
foreach ($key in $updates.Keys) {
    $node = $config.configuration.appSettings.add | Where-Object { $_.key -eq $key }
    if ($node) {
        $node.value = $updates[$key]
        Write-Host "Updated $key to $($updates[$key])"
    } else {
        # Add if not exists
        $newNode = $config.CreateElement("add")
        $newNode.SetAttribute("key", $key)
        $newNode.SetAttribute("value", $updates[$key])
        $config.configuration.appSettings.AppendChild($newNode) | Out-Null
        Write-Host "Added $key with value $($updates[$key])"
    }
}

# Save changes back
$config.Save($webConfigPath)

Write-Host "web.config updated successfully!"