# Velocity-Netzwerk mit Lobby & SMP

Fertiges Minecraft-Netzwerk: ein **Velocity-Proxy** mit zwei **Paper-Backends** (Lobby und
SMP). Spieler verbinden sich nur mit dem Proxy; dieser leitet sie serverseitig weiter.
Bedient wird alles über eine **Web-Konsole** – die klassische Terminal-Konsole wird nicht
mehr gebraucht.

## Komponenten

| Ordner         | Rolle                | Software                                                 |
|----------------|----------------------|----------------------------------------------------------|
| `velocity/`    | Proxy (Port 25565)   | Velocity **4.2.0** (Build 30)                            |
| `lobby/`       | Backend (Port 25566) | Paper **1.21.11** (Build 132)                            |
| `smp/`         | Backend (Port 25567) | Paper **1.21.11** (Build 132)                            |
| `webconsole/`  | Weboberfläche        | Python-Web-Konsole (nur Standardbibliothek, Port 8080)   |

Plugins auf **beiden** Paper-Servern (`lobby/plugins`, `smp/plugins`):
**ViaVersion 5.12.1** und **ViaBackwards 5.12.1**. Damit können Spieler mit neueren
(z. B. 26.1–26.3) **und** älteren Clients auf den 1.21.11-Servern spielen.

## Server-Jars

Die Server-Jars liegen **nicht** im Repository (Binärdateien). `./download.sh` lädt die
exakt festgelegten Versionen mit SHA256-Prüfsummen:

| Datei                        | Quelle                                      |
|------------------------------|---------------------------------------------|
| `lobby/paper.jar`, `smp/paper.jar` | Paper 1.21.11 (Build 132)             |
| `velocity/velocity.jar`      | Velocity 4.2.0 (Build 30)                    |
| `*/plugins/ViaVersion-*.jar` | ViaVersion 5.12.1                            |
| `*/plugins/ViaBackwards-*.jar` | ViaBackwards 5.12.1                        |

`./start-all.sh` ruft `./download.sh` automatisch auf, wenn Jars fehlen.

## Java-Versionen

* **Velocity 4.2.0** benötigt **Java 25**.
* **Paper 1.21.11** benötigt **Java 21**.

Die Startskripte wählen automatisch die passende Version (`velocity/start.sh` sucht ein
Java 25+, die Paper-Skripte nutzen `JAVA_HOME`/PATH). Auf diesem System sind beide
vorhanden.

---

## Starten & Stoppen

```bash
./start-all.sh     # startet die Web-Konsole und darüber das ganze Netzwerk
./stop-all.sh      # stoppt Netzwerk und Web-Konsole
./reset.sh         # entfernt Welten/Spielerdaten (fragt nach Bestätigung)
```

Nach `./start-all.sh` ist die Konsole erreichbar unter:

**http://127.0.0.1:8080**

`start-all.sh` startet die Web-Konsole; diese fährt automatisch Lobby, SMP und Velocity
hoch (siehe `autoStart` in `webconsole/config.json`).

---

## Die Web-Konsole

Die Web-Konsole **ersetzt die Minecraft-Konsole** und steuert die Serverprozesse direkt.
Pro Server (Velocity / Lobby / SMP) gibt es einen Reiter mit:

* **Live-Log** in Echtzeit (Farbmarkierungen für Befehle, Fehler, Joins/Leaves)
* **Start / Stop / Neustart** für jeden Server einzeln
* **Konsolen-Eingabe**: Befehl tippen und Enter – wie in der Konsole (Befehlsverlauf mit
  ↑ / ↓)
* Statusanzeige (gestoppt / startet / läuft / stoppt)
* oben: **Alle starten** / **Alle stoppen**

### Einstellungen – `webconsole/config.json`

| Schlüssel      | Standard       | Bedeutung                                                        |
|----------------|----------------|------------------------------------------------------------------|
| `host`         | `127.0.0.1`    | Adresse, auf der die Konsole lauscht                             |
| `port`         | `8080`         | Port der Web-Konsole                                             |
| `password`     | `""` (leer)    | Passwortschutz (HTTP Basic). Leer = kein Passwort                |
| `autoStart`    | `true`         | Server beim Start der Konsole automatisch hochfahren             |
| `bufferLines`  | `4000`         | Anzahl der im Arbeitsspeicher gehaltenen Logzeilen               |

**Sicherheit:** Die Konsole bindet standardmäßig nur an `127.0.0.1`, ist also von außen
nicht erreichbar. Für Zugriff von außen entweder `host` auf `0.0.0.0` setzen **und
unbedingt ein `password` vergeben**, oder besser einen SSH-Tunnel nutzen:

```bash
ssh -L 8080:127.0.0.1:8080 benutzer@server
```

Änderungen an `config.json` werden beim nächsten Start übernommen
(`./stop-all.sh` → `./start-all.sh`).

### Einzelne Server im Terminal (optional)

Jeder Server lässt sich auch direkt starten – dann aber **nicht** parallel zur Web-Konsole
(die Ports sind belegt):

```bash
cd lobby && ./start.sh        # bzw. smp/ und velocity/
```

---

## Netzwerkaufbau (Modern Forwarding)

Proxy und Paper-Server tauschen Spielerdaten über **Velocity Modern Forwarding** aus.
Diese Stellen müssen zusammenpassen:

* `velocity/velocity.toml` → `player-info-forwarding-mode = "modern"`
* `velocity/forwarding.secret` → gemeinsames Geheimnis
* `lobby/config/paper-global.yml` und `smp/config/paper-global.yml`:
  ```yaml
  proxies:
    velocity:
      enabled: true
      online-mode: true
      secret: '<Inhalt von forwarding.secret>'
  ```

Die Backends laufen mit `online-mode=false` (der Login läuft über den Proxy) und lauschen
nur auf `127.0.0.1`. Von außen ist ausschließlich der Proxy-Port 25565 erreichbar.

Die Server-Ports in `velocity.toml` unter `[servers]`:

```toml
lobby = "127.0.0.1:25566"
smp   = "127.0.0.1:25567"
```

Im Spiel wechselt man mit `/server lobby` bzw. `/server smp` (Velocity bringt den Befehl
mit).

## Häufige Anpassungen

* **MOTD des Proxys:** `velocity/velocity.toml` → `motd` (MiniMessage-Format).
* **MOTD der Backends:** `lobby/server.properties` / `smp/server.properties` → `motd`.
* **Port nach außen:** `velocity/velocity.toml` → `bind` (Standard `0.0.0.0:25565`).
* **Arbeitsspeicher:** `lobby/start.sh`, `smp/start.sh` (`-Xms2G -Xmx4G`) bzw.
  `velocity/start.sh` (`-Xms512M -Xmx1G`).
* **Spielmodus / Difficulty:** in den jeweiligen `server.properties`.
* **Offline-/Cracked-Betrieb:** `velocity/velocity.toml` → `online-mode = false`
  (unsicher – nur wenn bewusst gewünscht).
* **Neues Forwarding-Secret:** neuen Zufallswert in `velocity/forwarding.secret` schreiben
  und **denselben** Wert in beiden `paper-global.yml` (`proxies.velocity.secret`) eintragen,
  danach alles neu starten.
* **Weiterer Server:** neuen Paper-Ordner anlegen, `proxies.velocity` wie oben setzen und in
  `velocity.toml` unter `[servers]` ergänzen; die Web-Konsole kennt die Server aus
  `webconsole/server.py` (Liste `SERVERS`).

## Projektstruktur

```
.
├── velocity/     Proxy (velocity.toml, forwarding.secret, start.sh, velocity.jar*)
├── lobby/        Paper-Backend (config/, plugins/, server.properties, start.sh, paper.jar*)
├── smp/          Paper-Backend (wie lobby)
├── webconsole/   Web-Konsole (server.py, config.json, static/index.html, start.sh/stop.sh)
├── download.sh   lädt die Server-Jars (Versionen + Prüfsummen)
├── reset.sh      setzt auf Template-Zustand zurück (Welten/Spielerdaten löschen)
├── start-all.sh  startet die Web-Konsole + Netzwerk
├── stop-all.sh   stoppt alles
└── README.md

* Jars werden nicht eingecheckt, sondern mit ./download.sh geladen.
```

## Hinweise

* Das Repository enthält **keine Welten und keine Spielerdaten**: Beim ersten Start werden
  frische Welten generiert. `./reset.sh` entfernt Welten, Spielerdaten und Logs jederzeit
  wieder (z. B. vor einer Weitergabe).
* Das Forwarding-Secret in `velocity/forwarding.secret` (und beiden `paper-global.yml`) ist
  ein Beispielwert. Für einen öffentlichen Betrieb besser ein eigenes Secret erzeugen
  (siehe oben) – die Backends sind ansonsten nur lokal erreichbar.
* Paper und Velocity werden nicht automatisch aktualisiert. Neue Builds:
  [PaperMC](https://papermc.io/downloads); ViaVersion/ViaBackwards:
  [GitHub](https://github.com/ViaVersion).
