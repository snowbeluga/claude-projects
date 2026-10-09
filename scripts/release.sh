#!/usr/bin/env bash
# Cut a release:  scripts/release.sh 1.1.0
# Sets CP_VERSION, runs the tests, tags v<version>, pushes, then points the Homebrew
# formula (in a clone of the tap repo, default ../homebrew-tap) at the new tarball.
set -euo pipefail
die() { printf 'release: %s\n' "$*" >&2; exit 1; }
V=${1:-}; case "$V" in [0-9]*.[0-9]*.[0-9]*) ;; *) die "usage: scripts/release.sh <version>   e.g. 1.1.0" ;; esac
REPO=$(cd "$(dirname "$0")/.." && pwd)
TAP=${TAP_DIR:-$REPO/../homebrew-tap}
F="$TAP/Formula/claude-projects.rb"
cd "$REPO"
SLUG=$(git remote get-url origin | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')
[ -f "$F" ] || die "no formula at $F (clone the tap repo there, or set TAP_DIR)"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "switch to main first"
[ -z "$(git status --porcelain)" ] || die "commit or stash your changes first"
[ -z "$(git -C "$TAP" status --porcelain)" ] || die "the tap repo has uncommitted changes"
git rev-parse -q --verify "refs/tags/v$V" >/dev/null && die "tag v$V already exists"
git pull -q --ff-only

sed -i.bak "s/^CP_VERSION=\".*\"/CP_VERSION=\"$V\"/" bin/claude-projects && rm -f bin/claude-projects.bak
/bin/bash tests/smoke.sh >/dev/null || { git checkout -- bin/claude-projects; die "tests failed — see: tests/smoke.sh"; }
git diff --quiet || git commit -q -am "release v$V"
git tag -a "v$V" -m "claude-projects $V"
git push -q origin main "v$V"

URL="https://github.com/$SLUG/archive/refs/tags/v$V.tar.gz"
SHA=$(curl -fsSL "$URL" | shasum -a 256 | cut -d' ' -f1)
[ ${#SHA} = 64 ] || die "couldn't download $URL"
git -C "$TAP" pull -q --ff-only
sed -i.bak -e "s#^  url \".*\"#  url \"$URL\"#" -e "s#^  sha256 \".*\"#  sha256 \"$SHA\"#" "$F" && rm -f "$F.bak"
git -C "$TAP" commit -q -am "claude-projects $V"
git -C "$TAP" push -q
echo "Released v$V. People update with:  brew update && brew upgrade claude-projects"

# Keep the maintainer's own Homebrew install current too (otherwise you'd run the old release).
if command -v brew >/dev/null 2>&1 && brew list --formula claude-projects >/dev/null 2>&1; then
  echo "Upgrading your own Homebrew install…"
  brew update -q >/dev/null 2>&1 || true
  brew upgrade claude-projects >/dev/null 2>&1 || true
  echo "You're on: $("$(brew --prefix)/opt/claude-projects/bin/claude-projects" version)"
fi
