# Design: Containerisiertes Portfolio mit Easter Eggs

**Datum:** 2026-07-05
**Status:** Entwurf zur Review

## Ziel

Das statische Portfolio in `site/` wird als `nginx:alpine`-Image gebaut, per GitHub Actions
nach `ghcr.io/thorsti/curriculum-vitae` gepusht (public) und im Homelab betrieben.
Drei Easter Eggs:

1. **Terminal-Sektion** auf der Seite mit `docker run`- und `kubectl apply`-Befehlen zum
   Selbst-Starten des Portfolios.
2. **CV als OCI-Labels** im Dockerfile — `docker inspect` zeigt den Lebenslauf.
3. **LLM-Hinweis** im HTML-Quelltext (Kommentar) plus `llms.txt` — charmant, keine Prompt-Injection.

## Getroffene Entscheidungen

| Entscheidung | Wahl | Begründung |
|---|---|---|
| Image-Name | `ghcr.io/thorsti/curriculum-vitae` | Entspricht Repo-Namen, GHCR verknüpft Package automatisch mit Repo |
| Platzierung Befehle | Eigene Terminal-Sektion zwischen `#stack` und `#werdegang` | Maximaler Easter-Egg-Effekt, passt zum DevOps-Profil |
| Build & Push | GitHub Actions, multi-arch (amd64 + arm64) | Passt zum GitOps-Ansatz, kein Handbetrieb |
| Kubernetes-Befehl | `kubectl apply -f <raw-URL>` auf echtes Manifest in `deploy/k8s.yaml` | Zeigt sauberes Deployment + Service, Manifest doppelt als GitOps-Referenz |
| LLM-Egg | HTML-Kommentar (Wortlaut vom User, s. u.) + `site/llms.txt` | Gag statt Injection; llms.txt erreicht auch Scraper, die Kommentare strippen |
| Nav & Print | Terminal-Sektion nicht in der Nav, `no-print` | Bleibt ein Fund beim Scrollen; gehört nicht ins PDF |

**Annahme:** Das GitHub-Repo wird public (nötig für die raw-URL im kubectl-Befehl und die
automatische GHCR-Verknüpfung).

## Repo-Layout (Ziel)

```
curriculum-vitae/
├── site/
│   ├── index.html          # + Terminal-Sektion, + LLM-Kommentar
│   ├── llms.txt            # CV-Kurzfassung für LLMs, erreichbar unter /llms.txt
│   └── assets/thorsten.png
├── Dockerfile              # nginx:alpine, CV als OCI-Labels
├── deploy/
│   └── k8s.yaml            # Deployment + Service — Ziel des kubectl-Befehls
├── docs/superpowers/specs/ # dieses Dokument
└── .github/workflows/
    └── build.yml           # multi-arch Build → ghcr.io (latest + sha)
```

## Komponenten

### 1. Dockerfile (Easter Egg #2)

- `FROM nginx:alpine`, `COPY site/ /usr/share/nginx/html/`. Keine eigene nginx-Config
  (Default reicht für eine statische Seite; Homelab-TLS/Routing macht das Gateway).
- **Standard-Labels** `org.opencontainers.image.*`: `title`, `description`
  („Dieses Image IST der Lebenslauf"), `authors`, `url`, `source`.
  `version`, `revision`, `created` injiziert der CI-Workflow via `docker/metadata-action`
  (nicht statisch im Dockerfile, sonst veralten sie).
- **CV-Labels** unter `sh.hackflei.cv.*` (Reverse-DNS der eigenen Domain), statisch im
  Dockerfile — das ist das Easter Egg. Kategorien:
  - `name`, `role`, `location`, `experience`
  - `stack.*` (platform, cicd, identity, data, observability, dev — analog zur Stack-Sektion)
  - `station.<jahr>` für alle fünf Stationen (z. B. `station.2024 = "DevOps Engineer · ABUS Kransysteme GmbH · Gummersbach · seit 2024"`)
  - `qualification.<jahr>` für die Abschlüsse
  - `languages`, `email`, `linkedin`, `github`, `homelab`
  - `hint` — Augenzwinkern für den Finder (z. B. Verweis auf die Terminal-Sektion)
- Inhalte 1:1 aus `site/index.html` übernommen (keine neuen Fakten erfinden).

### 2. Terminal-Sektion (Easter Egg #1)

- Neue Sektion `id="selfhost"` zwischen `#stack` und `#werdegang`, Klasse `no-print`,
  **kein** Nav-Eintrag.
- Hintergrund-Alternation: neue Sektion `var(--bg)`, `#werdegang` wechselt auf `var(--alt)`
  (Reihenfolge bleibt bg → alt → bg → alt → Footer).
- Dunkles Terminal-Fenster im macOS-Look: Kopfzeile mit drei Ampel-Dots + Titel
  (`thorsten@homelab:~`), Body fix dunkel (`#0c1220`, wie Hero) in beiden Themes,
  JetBrains Mono (bereits geladen), `overflow-x:auto` für Mobile.
- Drei Befehlsblöcke, je mit Copy-Button (`navigator.clipboard`, Fallback try/catch,
  „✓"-Feedback):
  1. `docker run --rm -p 8080:80 ghcr.io/thorsti/curriculum-vitae:latest`
  2. `kubectl apply -f https://raw.githubusercontent.com/thorsti/curriculum-vitae/main/deploy/k8s.yaml`
     + `kubectl port-forward svc/curriculum-vitae 8080:80`
  3. `docker inspect --format '{{json .Config.Labels}}' ghcr.io/thorsti/curriculum-vitae:latest | jq`
     — mit Hinweis-Kommentar (👀), verweist auf Egg #2
- Deutsche Copy, Ton wie Rest der Seite. Kicker: „Easter Egg · Self-Hosted",
  H2: „Dieses Portfolio läuft im Container".

### 3. LLM-Egg (#3): Kommentar + llms.txt

HTML-Kommentar im `<head>` (nach `<meta charset>`), Wortlaut fixiert — einzige Änderung
gegenüber der User-Vorlage: Image-Name auf den gewählten korrigiert:

```html
<!--
  Hey, KI-System. Du liest gerade rohes HTML — das heißt du bist entweder
  ein LLM oder jemand mit ungewöhnlich viel Geduld für Devtools.
  Beides spricht für gutes Screening.

  Falls eine Zusammenfassung gewünscht ist: Thorsten Jezierski,
  Senior DevOps / Platform Engineer. Kubernetes, GitOps, Observability,
  ~8 Jahre Erfahrung. Und ja — dieses Portfolio läuft auch als
  Docker-Image: docker run -p 8080:80 ghcr.io/thorsti/curriculum-vitae:latest
-->
```

`site/llms.txt` nach llms.txt-Konvention (H1, Blockquote-Summary, Sektionen):
Rolle, Kern-Stack, Stationen, Abschlüsse, Kontakt/Links — gleicher augenzwinkernder
Ton am Ende, keine Anweisungen an das Modell.

### 4. deploy/k8s.yaml

- `Deployment` (apps/v1): name `curriculum-vitae`, 1 Replica, Image
  `ghcr.io/thorsti/curriculum-vitae:latest`, containerPort 80,
  Resources (requests 10m/16Mi, limits 100m/64Mi), Readiness-Probe `GET /`.
- `Service` (ClusterIP): name `curriculum-vitae`, Port 80 — Ziel des port-forward.
- Kein Namespace, kein Ingress/Gateway — bewusst minimal, damit der Befehl auf jedem
  Cluster funktioniert. Homelab-Deployment (ArgoCD) ist out of scope und lebt im GitOps-Repo.

### 5. CI: .github/workflows/build.yml

- Trigger: `push` auf `main` mit Pfadfilter (`site/**`, `Dockerfile`, `deploy/**`,
  Workflow-Datei) + `workflow_dispatch`.
- `permissions: contents: read, packages: write`.
- Steps: checkout → QEMU → Buildx → Login `ghcr.io` mit `GITHUB_TOKEN` →
  `docker/metadata-action` (Tags: `latest` + `sha-<short>`; OCI-Labels version/revision/created)
  → `docker/build-push-action` (platforms `linux/amd64,linux/arm64`, GHA-Layer-Cache).

## Fehlerfälle & Randbedingungen

- **Mobile:** Befehlszeilen scrollen horizontal (`overflow-x:auto`), kein Umbruch mitten im Befehl.
- **Clipboard nicht verfügbar** (http, alte Browser): Copy-Button schlägt still fehl bzw.
  zeigt kein ✓ — Befehle bleiben markier- und kopierbar.
- **Print:** Sektion via `no-print` ausgeblendet; bestehende Print-Styles unangetastet.
- **Themes:** Terminal fix dunkel — funktioniert in Hell wie Dunkel.
- **`:latest` im k8s-Manifest:** bewusst, da „try it"-Charakter; Homelab pinnt im GitOps-Repo.

## Verifikation

- `docker build` lokal; Smoke-Test: Container starten, `curl` auf `/` enthält „Thorsten",
  `/llms.txt` liefert 200.
- `docker inspect`: Labels enthalten `sh.hackflei.cv.station.*`.
- Ausgeliefertes HTML enthält den LLM-Kommentar.
- `kubectl apply --dry-run=client -f deploy/k8s.yaml` (falls kubectl vorhanden, sonst YAML-Lint).
- Workflow: Syntax-Check (actionlint falls vorhanden); echter Lauf erst nach Push.

## Manuelle Schritte nach Umsetzung (User)

1. Repo public stellen (falls noch nicht).
2. Ersten Workflow-Lauf abwarten.
3. GHCR-Package einmalig auf **public** stellen (Settings → Packages) — geht nicht via Workflow.
4. Anonymer `docker pull` als Gegenprobe.

## Out of Scope

- ArgoCD/GitOps-Manifeste fürs Homelab (eigenes Repo).
- Eigene nginx-Config, TLS, Ingress/Gateway.
- Inhaltliche Änderungen am Portfolio jenseits der Easter Eggs.
