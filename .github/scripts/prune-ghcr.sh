#!/usr/bin/env bash
# Entfernt alte, nur mit Commit-SHA getaggte Container-Versionen aus GHCR.
#
# Multi-Arch-sicher: Unsere Images sind OCI-Indizes (amd64 + arm64 +
# Attestation). Deren Kind-Manifeste sind selbst "untagged" Versionen —
# ein naives "lösche alle untagged" (so arbeitet actions/delete-package-
# versions) zerstört damit die noch gültigen Tags. Dieses Script löscht
# eine Version daher immer nur zusammen mit ihren Kind-Manifesten und
# überspringt Kinder, die ein behaltenes Image ebenfalls referenziert.
#
# Behalten werden: alle Versionen mit benanntem Tag (latest, main,
# v1.2.3, 1.2, …) sowie die $KEEP jüngsten Versionen.
#
# Env: PKG (Package-Name), KEEP (Anzahl jüngster Versionen), OWNER,
#      GH_TOKEN (PAT mit read:packages + delete:packages),
#      DRY_RUN=1 zeigt nur an, was entfernt würde
set -euo pipefail

: "${PKG:?PKG fehlt}"
: "${OWNER:?OWNER fehlt}"
KEEP="${KEEP:-5}"

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GHCR_CLEANUP_TOKEN nicht gesetzt — Housekeeping übersprungen."
  exit 0
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
B64="$(printf '%s' "$GH_TOKEN" | base64 | tr -d '\n')"
ACCEPT='application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json'

children() {  # $1 = digest -> Kind-Digests (leer bei Einzel-Manifest)
  curl -sS -H "Authorization: Bearer $B64" -H "Accept: $ACCEPT" \
    "https://ghcr.io/v2/${OWNER}/${PKG}/manifests/$1" \
    | jq -r '.manifests[]?.digest' 2>/dev/null || true
}

gh api "/user/packages/container/${PKG}/versions?per_page=100" --paginate \
  | jq -s 'add' > "$TMP/all.json"

# Getaggte Versionen, jüngste zuerst
jq -r '.[] | select((.metadata.container.tags|length) > 0)
       | [.id, .name, .updated_at, (.metadata.container.tags|join(","))] | @tsv' \
  "$TMP/all.json" | sort -t"$(printf '\t')" -k3,3r > "$TMP/roots.tsv"

: > "$TMP/keep.txt"; : > "$TMP/drop.tsv"; i=0
while IFS="$(printf '\t')" read -r id digest updated tags; do
  i=$((i + 1))
  named=0
  IFS=',' read -ra tag_list <<< "$tags"
  for t in "${tag_list[@]}"; do
    # Reine Commit-SHAs (7 Hex-Zeichen bzw. sha-Präfix) gelten als wegwerfbar
    if [[ ! "$t" =~ ^[0-9a-f]{7}$ ]] && [[ ! "$t" =~ ^sha- ]]; then
      named=1
    fi
  done
  if [ "$named" -eq 1 ] || [ "$i" -le "$KEEP" ]; then
    echo "$digest" >> "$TMP/keep.txt"
  else
    printf '%s\t%s\t%s\n' "$id" "$digest" "$tags" >> "$TMP/drop.tsv"
  fi
done < "$TMP/roots.tsv"

if [ ! -s "$TMP/drop.tsv" ]; then
  echo "Nichts aufzuräumen — alle Versionen sind benannt oder jung genug."
  exit 0
fi

# Kind-Manifeste, die behaltene Images brauchen: niemals anfassen
: > "$TMP/protected.txt"
while read -r d; do children "$d" >> "$TMP/protected.txt"; done < "$TMP/keep.txt"
sort -u -o "$TMP/protected.txt" "$TMP/protected.txt"

drop_version() {  # $1 = version-id, $2 = Beschreibung
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "  [dry-run] würde entfernen: $2"
  else
    gh api -X DELETE "/user/packages/container/${PKG}/versions/$1" --silent
  fi
}

removed=0
while IFS="$(printf '\t')" read -r id digest tags; do
  children "$digest" | sort -u > "$TMP/kids.txt"
  comm -23 "$TMP/kids.txt" "$TMP/protected.txt" > "$TMP/kids-free.txt" || true
  while read -r kid; do
    [ -z "$kid" ] && continue
    kid_id="$(jq -r --arg k "$kid" '.[] | select(.name == $k) | .id' "$TMP/all.json")"
    [ -z "$kid_id" ] && continue
    drop_version "$kid_id" "Kind-Manifest ${kid:0:19}" && removed=$((removed + 1))
  done < "$TMP/kids-free.txt"
  drop_version "$id" "${PKG} [${tags}]" && removed=$((removed + 1))
done < "$TMP/drop.tsv"

echo "Housekeeping fertig — ${removed} Versionen entfernt."
