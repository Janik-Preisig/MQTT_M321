$ErrorActionPreference = "Stop"

function Invoke-Compose {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ComposeArgs
    )

    & docker compose @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($ComposeArgs -join ' ') fehlgeschlagen"
    }
}

function Invoke-ComposeOutput {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ComposeArgs
    )

    $output = & docker compose @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($ComposeArgs -join ' ') fehlgeschlagen"
    }

    return ($output -join "`n")
}

Write-Host "[test] Baue die Sensor-Images..."
Invoke-Compose -ComposeArgs @("build")

Write-Host "[test] Starte den kompletten Stack..."
Invoke-Compose -ComposeArgs @("up", "--detach", "--remove-orphans")

Write-Host "[test] Warte auf Mosquitto..."
$mosquittoReady = $false
for ($i = 1; $i -le 30; $i++) {
    & docker compose exec -T mosquitto mosquitto_pub -h localhost -p 1883 -t test/health -m ok *> $null
    if ($LASTEXITCODE -eq 0) {
        $mosquittoReady = $true
        break
    }
    Start-Sleep -Seconds 1
}

if (-not $mosquittoReady) {
    throw "[test] Fehler: Mosquitto ist nicht erreichbar."
}

Write-Host "[test] Prüfe direkten MQTT Publish/Subscribe..."
Invoke-Compose -ComposeArgs @("exec", "-T", "mosquitto", "sh", "-c", "mosquitto_sub -h localhost -p 1883 -t test/direct -C 1 -W 10 -v > /tmp/mqtt-test.out & sleep 1; mosquitto_pub -h localhost -p 1883 -t test/direct -m hello; wait")
$directMessage = Invoke-ComposeOutput -ComposeArgs @("exec", "-T", "mosquitto", "cat", "/tmp/mqtt-test.out")
if ($directMessage -notmatch "test/direct hello") {
    throw "[test] Fehler: Direktes MQTT Publish/Subscribe fehlgeschlagen. Ausgabe: $directMessage"
}

Write-Host "[test] Prüfe Bash-Sensor-Topics..."
$bashMessages = Invoke-ComposeOutput -ComposeArgs @("exec", "-T", "mosquitto", "mosquitto_sub", "-h", "localhost", "-p", "1883", "-t", "bash/#", "-C", "6", "-W", "20", "-v")
Write-Host $bashMessages
foreach ($topic in @("bash/r1", "bash/r2", "bash/r3")) {
    if ($bashMessages -notmatch [regex]::Escape($topic)) {
        throw "[test] Fehler: Keine Nachricht für $topic empfangen."
    }
}

Write-Host "[test] Prüfe Java-Sensor-Topics..."
$javaMessages = Invoke-ComposeOutput -ComposeArgs @("exec", "-T", "mosquitto", "mosquitto_sub", "-h", "localhost", "-p", "1883", "-t", "java/#", "-C", "6", "-W", "20", "-v")
Write-Host $javaMessages
foreach ($topic in @("java/r1", "java/r2", "java/r3")) {
    if ($javaMessages -notmatch [regex]::Escape($topic)) {
        throw "[test] Fehler: Keine Nachricht für $topic empfangen."
    }
}

Write-Host "[test] Prüfe Java-Subscriber-Command..."
Invoke-Compose -ComposeArgs @("exec", "-T", "mosquitto", "mosquitto_pub", "-h", "localhost", "-p", "1883", "-t", "java/commands", "-m", "status")
Start-Sleep -Seconds 2
$javaLogs = Invoke-ComposeOutput -ComposeArgs @("logs", "--tail=120", "java-sensoren")
if ($javaLogs -notmatch "Befehl=status") {
    throw "[test] Fehler: Java-Command status wurde nicht sichtbar verarbeitet."
}

Write-Host "[test] Prüfe Grafana HTTP..."
$grafanaPort = if ($env:GRAFANA_PORT) { $env:GRAFANA_PORT } else { "3001" }
$grafanaReady = $false
for ($i = 1; $i -le 60; $i++) {
    & curl.exe -fsS "http://localhost:$grafanaPort/api/health" *> $null
    if ($LASTEXITCODE -eq 0) {
        $grafanaReady = $true
        break
    }
    Start-Sleep -Seconds 1
}

if (-not $grafanaReady) {
    throw "[test] Fehler: Grafana API ist nicht erreichbar."
}

Write-Host "[test] Setze Grafana Admin-Passwort..."
Invoke-Compose -ComposeArgs @("exec", "-T", "grafana", "grafana", "cli", "admin", "reset-admin-password", "admin")

Write-Host "[test] Prüfe provisionierte Grafana-Datenquelle..."
$datasourceJson = & curl.exe -fsS -u admin:admin "http://localhost:$grafanaPort/api/datasources/uid/mqtt"
if ($LASTEXITCODE -ne 0) {
    throw "[test] Fehler: Grafana Datasource API nicht erreichbar."
}

if (($datasourceJson -join "`n") -notmatch "grafana-mqtt-datasource") {
    throw "[test] Fehler: MQTT-Datenquelle wurde nicht gefunden."
}

Write-Host "[test] Alle Container-Integrationstests erfolgreich."
