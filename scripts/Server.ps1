$prefix = "https://+:443/"
$maintenancePage = "C:\MaintenancePage\MaintenancePage\maintenance.html"
$logFile = "C:\MaintenancePage\MaintenancePage\server.log"

function Write-Log {
    param($msg)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp $msg" | Out-File $logFile -Append
}

Write-Log "Starting maintenance listener..."

try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    $listener.Start()

    Write-Log "Maintenance listener running on port 443"
    Write-Host "Maintenance listener running on HTTPS port 443..."

    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $response = $context.Response

            $html = Get-Content $maintenancePage -Raw
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)

            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
        catch {
            Write-Log "Request error: $_"
        }
    }
}
catch {
    Write-Log "Listener error: $_"
}
finally {
    if ($listener) {
        $listener.Stop()
        Write-Log "Listener stopped."
    }
}
