# Contributing to claude-projects

Everything is plain shell, with no build step:

| File | |
|---|---|
| `bin/claude-projects` | the picker, plus `setup`, `doctor`, `list`, `ignore` and the other commands |
| `shell/claude-projects.sh` | the zsh/bash wrapper sourced from rc files. It defines `cproj` and `claude projects` |
| `install.sh` / `uninstall.sh` | edit rc files only between the `# >>> claude-projects >>>` markers, and are safe to re-run |
| `tests/smoke.sh` | the test suite |
| `scripts/release.sh` | cuts a release |

Keep everything **bash 3.2 compatible** (macOS `/bin/bash`): no associative arrays, `mapfile` or `${var,,}`. The wrapper also has to work in zsh.

## Tests

`tests/smoke.sh` runs the whole flow in a throwaway `$HOME` with stub `fzf` and `claude` binaries: listing, preview, picker, non-git folders, ignore rules, install twice, wrapper, doctor, uninstall, and a fake Homebrew layout. It never touches your real setup. Run it with macOS's bash 3.2 to catch compatibility slips:

```sh
/bin/bash tests/smoke.sh
```

## Trying changes before a release

Pushing to `main` doesn't reach anyone's Homebrew install, yours included. Only a release does. To try your working copy:

```sh
bin/claude-projects --list                      # any command, straight from the repo
CP_HOME="$PWD" bash -c '. shell/claude-projects.sh; cproj'   # the full picker + launch, in a subshell
```

## Releasing

For maintainers with push access to both this repo and [snowbeluga/homebrew-tap](https://github.com/snowbeluga/homebrew-tap).

Releases are git tags, and the Homebrew formula points at the tag's tarball. One-time setup: clone the tap next to this repo.

```sh
git clone https://github.com/snowbeluga/homebrew-tap.git ../homebrew-tap
```

Then, with your changes committed on `main`:

```sh
scripts/release.sh 1.1.0
```

It sets `CP_VERSION`, runs the tests, tags `v1.1.0`, pushes, and updates the formula's `url` and `sha256` in the tap. Users then get it with `brew update && brew upgrade claude-projects`. If you installed it with Homebrew yourself, the script also upgrades your copy, so you're never a release behind.
