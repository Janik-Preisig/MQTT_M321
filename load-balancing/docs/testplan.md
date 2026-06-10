# Testplan Load-Balancing Demo

## Ziel

Der Test zeigt, dass die Demo reproduzierbar startet, dass der Load Balancer erreichbar ist und dass Anfragen auf mehrere Backend-Server verteilt werden.

## Voraussetzungen

- Docker Desktop läuft.
- Der Port `8080` ist frei.
- PowerShell ist verfügbar.

Optional kann ein anderer Port verwendet werden:

```powershell
$env:LOAD_BALANCER_PORT=8081
docker compose up -d --build
```

## Test 1: Stack starten

```powershell
cd load-balancing
docker compose up -d --build
docker compose ps
```

Erwartung:

- `web-a`, `web-b`, `web-c` und `load-balancer` laufen.
- Die Healthchecks sind `healthy`.

## Test 2: Einzelne Anfrage

```powershell
Invoke-RestMethod http://localhost:8080/
```

Erwartung:

- Die Antwort ist JSON.
- Das Feld `server` enthält `web-a`, `web-b` oder `web-c`.
- Das Feld `delay_ms` zeigt die simulierte Antwortverzögerung.

## Test 3: Verteilung prüfen

```powershell
powershell -ExecutionPolicy Bypass -File scripts/request-loop.ps1 -Requests 30
```

Erwartung:

- Es werden 30 Antworten angezeigt.
- Mehr als ein Backend-Server kommt in der Ausgabe vor.
- `web-a` erscheint häufiger als `web-b` und `web-c`, weil `web-a` das Gewicht `3` hat.

Beispielhafte Verteilung:

```text
web-a: 18
web-b: 6
web-c: 6
```

## Test 4: Ausfall eines Backends

```powershell
docker compose stop web-b
powershell -ExecutionPolicy Bypass -File scripts/request-loop.ps1 -Requests 15
```

Erwartung:

- Der Dienst bleibt über `http://localhost:8080/` erreichbar.
- Die Antworten kommen nur noch von `web-a` und `web-c`.

Backend wieder starten:

```powershell
docker compose start web-b
```

## Test 5: Strategie wechseln

In `nginx/nginx.conf` im Block `upstream backend_pool` die Zeile aktivieren:

```nginx
least_conn;
```

Danach:

```powershell
docker compose restart load-balancer
powershell -ExecutionPolicy Bypass -File scripts/request-loop.ps1 -Requests 30
```

Erwartung:

- NGINX bevorzugt Server mit weniger aktiven Verbindungen.
- Bei parallelen oder langsamen Anfragen sieht man eine andere Verteilung als bei Weighted Round Robin.

## Aufräumen

```powershell
docker compose down
```
