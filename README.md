# holla-apt

apt repository for **[holla](https://github.com/tailrocks/holla)** — the
adaptive dev environment CLI. Installs and upgrades `holla` with native `apt`.

The signed repository is published to GitHub Pages at:

> https://apt.tailrocks.com/holla-apt/

## Install

```bash
# 1. trust the signing key (scoped to this repo via signed-by)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://apt.tailrocks.com/holla-apt/holla.gpg \
  | sudo tee /etc/apt/keyrings/holla.gpg > /dev/null

# 2. add the repo
echo "deb [signed-by=/etc/apt/keyrings/holla.gpg] https://apt.tailrocks.com/holla-apt stable main" \
  | sudo tee /etc/apt/sources.list.d/holla.list

# 3. install
sudo apt update
sudo apt install holla

# 4. use it
holla
```

Debian packages (`.deb`) for `amd64` and `arm64` are also attached to every GitHub Release of holla and can be installed directly with `dpkg -i holla_*.deb`.

## Upgrade

```bash
sudo apt update && sudo apt upgrade
```

A new tagged release of `holla` adds a new `.deb` to this repo; `apt
upgrade` picks it up.

## How it is built

1. On tag push (or manual dispatch for an existing tag), the dedicated
   [release-deb.yml](https://github.com/tailrocks/holla/blob/main/.github/workflows/release-deb.yml)
   in the holla repo builds the `.deb`(s) for the Linux targets using
   `cargo-deb` (targeting latest Debian / recent glibc only — amd64 native,
   arm64 via zigbuild, `--deb-version` to pin to the tag). This is a separate
   workflow from the main tarball + Homebrew release, exactly as velnor does
   with its release-deb.yml. (The broad glibc 2.17 compat is only for the
   portable tarballs.)
2. It attaches the .deb(s) to the source (holla) GitHub Release, then uploads
   them (cross-repo, using `GH_HOLLA_APT_TOKEN`) to *this* (holla-apt)
   repository's GitHub Releases under the same tag. This is the same pattern
   used by velnor / velnor-apt so that the apt publisher only needs to read
   from its own releases.
3. The [`publish.yml`](.github/workflows/publish.yml) workflow here is
   triggered (via `gh workflow run ... -f version=...` or repository_dispatch),
   downloads the `.deb` from this repo's release, adds it to the apt pool with
   `reprepro` (which GPG-signs `Release` / `InRelease`), uploads the resulting
   tree as a GitHub Pages artifact, and deploys it using GitHub Actions.
   (The `gh-pages` branch is still maintained internally as a git state store
   so that `reprepro` can keep old package versions across publishes.)

Design notes: modeled directly on the velnor-apt + velnor-runner pattern. See
holla's full design doc [docs/debian-apt-repo.md](https://github.com/tailrocks/holla/blob/main/docs/debian-apt-repo.md) (includes the proper serving host `apt.tailrocks.com/holla-apt` as used in the ChainArgos environment), `release-deb.yml`, `Cargo.toml` (the [package.metadata.deb] section),
and the debian/ maintainer scripts.

## One-time setup (maintainer)

- Create a GPG signing key; add its **private** half + passphrase as repo secrets
  `APT_GPG_PRIVATE_KEY` and `APT_GPG_PASSPHRASE`; commit/publish the **public**
  half as `holla.gpg` (and into the published tree).
- Set `SignWith:` in [`conf/distributions`](conf/distributions) to the key id
  (uncomment and replace the placeholder).
- Enable **GitHub Pages** for this repo → Source: `GitHub Actions` (you should **always** use GitHub Actions for Pages deployments in these setups; never "Deploy from a branch").
- In the main `tailrocks/holla` repo, add a PAT (fine-grained with Contents:write +
  Actions:write on `tailrocks/holla-apt`, or a classic PAT with `repo` scope) as
  `GH_HOLLA_APT_TOKEN`. This is used by holla's `release-deb.yml` (the dedicated
  flow, exactly like velnor's release-deb.yml) to create a release on *this* repo
  and upload the `.deb` assets (cross-repo), plus trigger the publish workflow.
  This is the same pattern used by velnor / velnor-apt. Without the token, you
  can still publish manually via `gh workflow run` or the web UI.
- (Optional but recommended) Also wire the dispatch so the publish runs
  automatically after the debs land here.

## Triggering a publish

Manual:

```bash
# From the holla-apt repo
gh workflow run publish.yml -f version=vX.Y.Z
```

From the holla release workflow (or manually), you can also dispatch:

```bash
gh api repos/tailrocks/holla-apt/dispatches \
  -f event_type=publish-deb \
  -F client_payload[version]=vX.Y.Z
```

The `publish.yml` accepts `workflow_dispatch` (with `version` input) and
`repository_dispatch` (type `publish-deb`, optional `client_payload.version`).

## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
