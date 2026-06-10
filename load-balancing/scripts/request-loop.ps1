param(
    [string]$Url = "http://localhost:8080/",
    [int]$Requests = 30,
    [int]$PauseMs = 250
)

$counts = @{}

for ($i = 1; $i -le $Requests; $i++) {
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = Invoke-RestMethod -Uri $Url -TimeoutSec 10
        $timer.Stop()

        $server = [string]$response.server
        if (-not $counts.ContainsKey($server)) {
            $counts[$server] = 0
        }
        $counts[$server]++

        "{0,2}/{1}: {2} backend_delay={3}ms client_time={4}ms" -f $i, $Requests, $server, $response.delay_ms, $timer.ElapsedMilliseconds
    }
    catch {
        $timer.Stop()
        "{0,2}/{1}: Fehler nach {2}ms - {3}" -f $i, $Requests, $timer.ElapsedMilliseconds, $_.Exception.Message
    }

    Start-Sleep -Milliseconds $PauseMs
}

""
"Verteilung:"
$counts.GetEnumerator() | Sort-Object Name | ForEach-Object {
    "{0}: {1}" -f $_.Name, $_.Value
}
