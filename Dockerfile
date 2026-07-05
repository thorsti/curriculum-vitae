FROM nginx:alpine

# --- Standard-OCI-Labels (version/revision/created injiziert der CI-Workflow) ---
LABEL org.opencontainers.image.title="Thorsten Jezierski — Curriculum Vitae" \
      org.opencontainers.image.description="Portfolio & Lebenslauf als nginx-Container. Dieses Image IST der Lebenslauf — siehe die sh.hackflei.cv.*-Labels." \
      org.opencontainers.image.authors="Thorsten Jezierski <jezierski.thorsten@gmail.com>" \
      org.opencontainers.image.url="https://github.com/thorsti/curriculum-vitae" \
      org.opencontainers.image.source="https://github.com/thorsti/curriculum-vitae"

# --- Easter Egg: der Lebenslauf als OCI-Labels ---
LABEL sh.hackflei.cv.name="Thorsten Jezierski" \
      sh.hackflei.cv.role="Senior DevOps / Platform Engineer" \
      sh.hackflei.cv.location="Gummersbach, NRW" \
      sh.hackflei.cv.experience="~8 Jahre zwischen Entwicklung und Betrieb" \
      sh.hackflei.cv.stack.platform="Kubernetes (MicroK8s) · Helm · ArgoCD · GitOps · Docker · Digital Ocean" \
      sh.hackflei.cv.stack.cicd="CI/CD-Pipelines · Git · Node-RED" \
      sh.hackflei.cv.stack.identity="Keycloak (OIDC) · cert-manager · Active Directory" \
      sh.hackflei.cv.stack.data="PostgreSQL · MariaDB · MongoDB · MySQL · MinIO (S3) · Strimzi Kafka" \
      sh.hackflei.cv.stack.observability="LGTM-Stack — Loki · Grafana · Tempo · Mimir" \
      sh.hackflei.cv.stack.dev="PHP · Vue.js · Flutter · Firebase · OPC UA · Maschinendatenerfassung" \
      sh.hackflei.cv.station.2024="DevOps Engineer · ABUS Kransysteme GmbH · Gummersbach · seit 2024" \
      sh.hackflei.cv.station.2016="Administrator · THELEICO Schleiftechnik GmbH & Co. KG · Meschede · 06.2016–03.2024" \
      sh.hackflei.cv.station.2013="IT-Systembetreuung · OPTI GmbH · 08.2013–06.2016" \
      sh.hackflei.cv.station.2010="Ausbildung Fachinformatiker Systemintegration · Kobecke GmbH · Berlin · 08.2010–08.2013" \
      sh.hackflei.cv.station.2008="Praktikum Webentwickler · Travelworks GmbH · Münster · 2008" \
      sh.hackflei.cv.qualification.2013="Fachinformatiker Systemintegration (OSZ Medizin- & Informationstechnik, Berlin)" \
      sh.hackflei.cv.qualification.2008="Informationstechnischer Assistent · Fachhochschulreife (Berufskolleg des HSK, Olsberg)" \
      sh.hackflei.cv.qualification.2004="Fachoberschulreife · Realschule Olsberg" \
      sh.hackflei.cv.languages="Deutsch (Muttersprache) · Englisch (verhandlungssicher)" \
      sh.hackflei.cv.email="jezierski.thorsten@gmail.com" \
      sh.hackflei.cv.linkedin="https://www.linkedin.com/in/thorsten-jezierski-350952252" \
      sh.hackflei.cv.github="https://github.com/thorsti" \
      sh.hackflei.cv.homelab="https://hackflei.sh" \
      sh.hackflei.cv.hint="Glückwunsch, du hast das zweite Easter Egg gefunden. Das dritte steckt im HTML-Quelltext. 👀"

COPY site/ /usr/share/nginx/html/
