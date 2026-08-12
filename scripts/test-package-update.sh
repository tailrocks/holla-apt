#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/." "$tmp/repo"
verified="$tmp/verified"
mkdir "$verified"
version=1.2.3
commit=0123456789abcdef0123456789abcdef01234567
: > "$tmp/assets.jsonl"
for target in x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu; do
  name="holla-${version}-${target}.deb"
  printf 'fixture-%s\n' "$target" > "$verified/$name"
  digest=$(shasum -a 256 "$verified/$name" | awk '{print $1}')
  jq -cn --arg name "$name" --arg sha256 "$digest" '{name:$name,sha256:$sha256}' >> "$tmp/assets.jsonl"
done
jq -Sn --arg source_repository tailrocks/holla --arg source_ref refs/tags/v$version \
  --arg source_commit "$commit" --arg version "$version" --slurpfile assets "$tmp/assets.jsonl" \
  '{schema:"velnor.package-release.v1",source_repository:$source_repository,source_ref:$source_ref,source_commit:$source_commit,version:$version,assets:$assets}' > "$verified/release-manifest.json"
jq -Sn --arg source_repository tailrocks/holla --arg source_ref refs/tags/v$version \
  --arg source_digest "$commit" --slurpfile manifest "$verified/release-manifest.json" \
  '{source_repository:$source_repository,source_ref:$source_ref,source_digest:$source_digest,manifest:$manifest[0]}' > "$verified/identity.json"
(
  cd "$tmp/repo"
  VELNOR_VERIFIED_PACKAGE_DIR="$verified" ./scripts/package-update.sh
  shasum -a 256 package-state.json > "$tmp/first.sha"
  VELNOR_VERIFIED_PACKAGE_DIR="$verified" ./scripts/package-update.sh
  shasum -a 256 -c "$tmp/first.sha"
  jq -e '.version=="1.2.3" and (.packages|length)==2' package-state.json
)
jq '.assets[0].name = "unexpected.deb"' "$verified/release-manifest.json" > "$tmp/bad.json"
mv "$tmp/bad.json" "$verified/release-manifest.json"
if (cd "$tmp/repo" && VELNOR_VERIFIED_PACKAGE_DIR="$verified" ./scripts/package-update.sh); then
  echo "incomplete package set was accepted" >&2
  exit 1
fi

publish="$root/.github/workflows/publish.yml"
verify_line=$(rg -n 'name: Download and verify merged package state' "$publish" | cut -d: -f1)
gpg_line=$(rg -n 'name: Import GPG signing key' "$publish" | cut -d: -f1)
test "$verify_line" -lt "$gpg_line"
rg -q 'gh attestation verify "incoming/\$name"' "$publish"
rg -q 'sha256sum --check --strict incoming/consumer-SHA256SUMS' "$publish"
rg -q 'paths: \[package-state.json\]' "$publish"
if rg -q 'repository_dispatch|event\.client_payload|release view --json tagName|Download \.debs from this repo' "$publish"; then
  echo "publication regained mutable or cross-upload authority" >&2
  exit 1
fi
