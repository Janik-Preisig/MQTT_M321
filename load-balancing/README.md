# Load-Balancing Demo mit NGINX

Diese Demo zeigt einen NGINX Load Balancer vor drei einfachen Webservern. Jeder Webserver antwortet verzögert und meldet im JSON zurück, welcher Backend-Server die Anfrage verarbeitet hat.

## Architektur

```text
Client oder Skript
      |
      v
localhost:8080
      |
      v
NGINX Load Balancer
      |
      +--> web-a:8000, schnell, Gewicht 3
      +--> web-b:8000, mittel, Gewicht 1
      +--> web-c:8000, langsam, Gewicht 1
```

Der zentrale Access Point ist:

```text
http://localhost:8080/
```

## Start

```powershell
cd load-balancing
docker compose up -d --build
docker compose ps
```

Einzelne Anfrage:

```powershell
Invoke-RestMethod http://localhost:8080/
```

Zyklische Abfrage unter PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/request-loop.ps1 -Requests 30
```

Zyklische Abfrage unter Bash:

```bash
sh scripts/request-loop.sh http://localhost:8080/ 30 0.25
```

Stoppen:

```powershell
docker compose down
```

## 1. Bedeutung von Load Balancing

Load Balancing verteilt eingehende Anfragen auf mehrere Server. Dadurch muss nicht ein einzelner Server die gesamte Last tragen. In einer IT-Infrastruktur verbessert das die Verfügbarkeit, die Antwortzeiten und die Skalierbarkeit.

Ohne Load Balancer hängt der Dienst direkt an einem einzelnen Server. Ist dieser Server überlastet oder fällt aus, merken Benutzer sofort Fehler oder lange Wartezeiten. Mit einem Load Balancer kann derselbe Dienst über mehrere Instanzen betrieben werden.

## 2. Funktionsweise

Der Load Balancer nimmt die Anfrage des Clients entgegen und leitet sie an einen passenden Backend-Server weiter. Für den Client sieht es so aus, als gäbe es nur einen Dienst unter einer Adresse.

In dieser Demo ruft der Client `http://localhost:8080/` auf. NGINX entscheidet anhand der konfigurierten Strategie, ob `web-a`, `web-b` oder `web-c` antwortet. Die Backend-Server kennen den Client nicht direkt als Zieladresse, sondern erhalten die Anfrage über NGINX.

Die Aufteilung ist hier bewusst sichtbar:

- Jeder Backend-Server sendet seinen Namen als JSON-Feld `server`.
- Jeder Backend-Server wartet vor der Antwort unterschiedlich lange.
- Das Skript zählt am Schluss, wie oft welcher Server geantwortet hat.

## 3. Demo-Umgebung

Die Demo besteht aus diesen Dateien:

| Datei | Zweck |
| --- | --- |
| `docker-compose.yml` | Startet drei Webserver und den Load Balancer |
| `backend/server.py` | Einfacher Python-Webserver mit verzögerter JSON-Antwort |
| `backend/Dockerfile` | Container-Image für die Backend-Server |
| `nginx/nginx.conf` | Load-Balancing-Konfiguration |
| `scripts/request-loop.ps1` | PowerShell-Skript für zyklische Anfragen |
| `scripts/request-loop.sh` | Bash-Skript für zyklische Anfragen |
| `docs/testplan.md` | Testplan für die Abgabe |

Erwartung bei 30 Anfragen mit der aktiven Gewichtung `3:1:1`:

- `web-a` erhält ungefähr 18 Anfragen.
- `web-b` erhält ungefähr 6 Anfragen.
- `web-c` erhält ungefähr 6 Anfragen.

Kleine Abweichungen sind möglich, weil NGINX Verbindungen und Timing berücksichtigt.

## 4. Vorteile des Load Balancers

Servicequalität:

- Anfragen werden auf mehrere Server verteilt.
- Antwortzeiten bleiben stabiler, wenn mehrere Benutzer gleichzeitig zugreifen.
- Wartung und Updates sind einfacher, weil einzelne Backend-Server entfernt oder neu gestartet werden können.

Schutz vor Serverüberlastung:

- Die Last liegt nicht nur auf einer Instanz.
- Langsame oder fehlerhafte Backend-Server können durch `max_fails` und `fail_timeout` temporär gemieden werden.
- Neue Backend-Server können ergänzt werden, wenn mehr Kapazität nötig ist.

## 5. Strategien und Konfiguration

NGINX Open Source unterstützt in dieser Demo folgende Strategien:

| Strategie | Konfiguration | Einsatz |
| --- | --- | --- |
| Round Robin | keine Zusatzzeile im `upstream` Block | Gleichmässige Verteilung auf alle Server |
| Weighted Round Robin | `server web-a:8000 weight=3;` | Schnellere Server erhalten mehr Anfragen |
| Least Connections | `least_conn;` im `upstream` Block | Server mit weniger aktiven Verbindungen bevorzugen |
| IP Hash | `ip_hash;` im `upstream` Block | Gleiche Client-IP landet möglichst beim gleichen Backend |
| Generic Hash | `hash $request_uri consistent;` | Anfragen anhand eines Schlüssels stabil verteilen |

Die aktive Konfiguration steht in `nginx/nginx.conf`:

```nginx
upstream backend_pool {
  server web-a:8000 weight=3 max_fails=2 fail_timeout=5s;
  server web-b:8000 weight=1 max_fails=2 fail_timeout=5s;
  server web-c:8000 weight=1 max_fails=2 fail_timeout=5s;
}
```

Für Least Connections:

```nginx
upstream backend_pool {
  least_conn;
  server web-a:8000 weight=3 max_fails=2 fail_timeout=5s;
  server web-b:8000 weight=1 max_fails=2 fail_timeout=5s;
  server web-c:8000 weight=1 max_fails=2 fail_timeout=5s;
}
```

Für IP Hash:

```nginx
upstream backend_pool {
  ip_hash;
  server web-a:8000 max_fails=2 fail_timeout=5s;
  server web-b:8000 max_fails=2 fail_timeout=5s;
  server web-c:8000 max_fails=2 fail_timeout=5s;
}
```

Least Response Time ist bei NGINX vor allem ein Feature von NGINX Plus. Diese Open-Source-Demo nutzt es deshalb nicht.

Nach einer Änderung der NGINX-Konfiguration:

```powershell
docker compose restart load-balancer
```

## 6. Algorithmus: Weighted Round Robin

Weighted Round Robin ist eine gewichtete Variante von Round Robin. Round Robin geht der Reihe nach durch alle Server. Die gewichtete Variante gibt stärkeren Servern mehr Anfragen.

In dieser Demo gilt:

```text
web-a: weight=3
web-b: weight=1
web-c: weight=1
```

Das Verhältnis ist also `3:1:1`. Von ungefähr fünf Anfragen gehen etwa drei an `web-a`, eine an `web-b` und eine an `web-c`.

Das ist sinnvoll, wenn die Server unterschiedlich leistungsfähig sind. Ein schneller Server darf mehr übernehmen, ein langsamer Server bleibt aber weiterhin beteiligt.

## 7. Ab wann lohnt sich Load Balancing?

Load Balancing lohnt sich, sobald ein Dienst nicht mehr sinnvoll auf einer einzelnen Instanz betrieben werden soll. Typische Gründe sind:

- Viele gleichzeitige Benutzer verursachen hohe CPU-, RAM- oder Netzwerk-Last.
- Der Dienst muss auch während Wartung oder Updates erreichbar bleiben.
- Ausfälle einzelner Server dürfen nicht direkt zum Ausfall des ganzen Dienstes führen.
- Die Anwendung soll horizontal skalieren, also mit zusätzlichen Instanzen wachsen.

Für sehr kleine interne Dienste mit wenigen Anfragen lohnt sich der zusätzliche Betrieb oft noch nicht. Zuerst sollten Anwendung, Datenbank und Caching sauber funktionieren. Load Balancing wird interessant, wenn Verfügbarkeit, Wachstum oder gleichzeitige Last wichtig werden.

## Kontrollfragen für die Präsentation

- Warum sieht der Client nur `localhost:8080`?
- Warum bekommt `web-a` mehr Anfragen als `web-b` und `web-c`?
- Was passiert, wenn ein Backend-Container gestoppt wird?
- Welche Strategie wäre besser für sehr lange Requests?
- Warum ersetzt Load Balancing keine Datenbank-Optimierung?
