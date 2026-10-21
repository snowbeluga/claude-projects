# claude-projects

Terminal project picker (`claude projects` / `cproj`) written in plain shell. No build step. See CONTRIBUTING.md for layout and releasing.

## Gotchas
- Everything must be bash 3.2 compatible (macOS `/bin/bash`): no associative arrays, `mapfile`, `${var,,}`. The wrapper `shell/claude-projects.sh` must also work in zsh.
- `install.sh`/`uninstall.sh` only edit rc files between the `# >>> claude-projects >>>` markers and must stay idempotent.
- Try changes with `bin/claude-projects --list` or `CP_HOME="$PWD" bash -c '. shell/claude-projects.sh; cproj'`. Never run install against the real `$HOME` to test.
- Never run `scripts/release.sh` (tags, pushes, edits the Homebrew tap).
- Commits: short imperative subject, no prefix; release commits are `release vX.Y.Z`.

## Before finishing
- `/bin/bash tests/smoke.sh` (uses a throwaway `$HOME` and stubs; ~40s; currently 68 passed, 0 failed). Must use `/bin/bash`, not a newer bash.
