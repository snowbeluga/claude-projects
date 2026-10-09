# ✻ claude projects

A terminal picker for jumping between your projects and Claude Code sessions.

```
  ┌─┐┬  ┌─┐┬ ┬┌┬┐┌─┐  ┌─┐┬─┐┌─┐ ┬┌─┐┌─┐┌┬┐┌─┐
  │  │  ├─┤│ │ ││├┤   ├─┘├┬┘│ │ │├┤ │   │ └─┐
  └─┘┴─┘┴ ┴└─┘─┴┘└─┘  ┴  ┴└─└─┘└┘└─┘└─┘ ┴ └─┘
  12 projects · 1 running · ✻ Claude session · ● uncommitted
  ↵ new  ^o continue  ^r resume  ^g cd only  ^e editor  ^y copy path  ^x ignore  ^/ preview
  ❯
▌ ▶ identity-api      feat/token-refresh   ●   2h ago ✻    │ identity-api
    pra-console       main                     1d ago ✻    │ ✻ CLAUDE  last session 2h ago · 14 total
    docs-site         main                     3w ago      │   Refactor token refresh flow
    research-notes    no git                   1mo ago ✻   │
                                                           │   › fix the refresh bug in auth middleware
                                                           │   › now add tests for the expiry edge case
                                                           │ ⎇ GIT  feat/token-refresh  ↑2  3 changed
```

Type `claude projects` (or `cproj`). You get your projects sorted by what you touched most recently, with a preview of what you last asked Claude in each one. Pick one and you're in a Claude session there.

Projects don't have to be git repos. Folders directly inside your project folders, and any folder where you've used Claude, are listed too and marked `no git`.

Every other `claude …` command goes straight to Claude Code, unchanged.

## Install

You need macOS or Linux with zsh or bash, and [Claude Code](https://docs.claude.com/en/docs/claude-code).

**With Homebrew** (recommended):

```sh
brew install snowbeluga/tap/claude-projects
claude-projects install-shell
```

Homebrew installs `fzf` and `jq` for you. `install-shell` then does the one thing Homebrew can't: it hooks the tool into your shell.

**Without Homebrew:**

```sh
git clone https://github.com/snowbeluga/claude-projects.git ~/.local/share/claude-projects
~/.local/share/claude-projects/install.sh
```

Either way, the installer:

- checks for `fzf` (required) and `jq` (optional), and offers to install them with Homebrew (git installs)
- adds **one line** to your `~/.zshrc` / `~/.bashrc`, after making a backup
- asks which folders your projects live in
- runs `claude projects doctor` to confirm everything works

When it finishes, **open a new terminal tab** and run `claude projects`.

> On macOS the folder scan may trigger *"Terminal would like to access files in your Documents folder"*. Allow it if your code lives there.

## Using it

| Key | Does |
|---|---|
| `enter` | new Claude session in that project |
| `ctrl-o` | continue the last session (`claude -c`) |
| `ctrl-r` | pick a past session (`claude --resume`) |
| `ctrl-g` | just `cd` there, no Claude |
| `ctrl-e` | open the project in your editor |
| `ctrl-y` | copy the path |
| `ctrl-x` | ignore that project (hide it from the list) |
| `ctrl-/` | show or hide the preview (handy when screen-sharing) |
| `esc` | cancel |

Anything after `projects` is passed to Claude. For example, `claude projects --model opus` starts the chosen session with that flag.

| Command | |
|---|---|
| `claude projects setup` | choose folders, editor, privacy settings |
| `claude projects doctor` | check the install and explain any problems |
| `claude projects update` | update to the latest version (Homebrew installs: `brew upgrade claude-projects`) |
| `claude projects list [--all]` | plain list of projects. `--all` includes ignored ones |
| `claude projects ignore <path\|name\|pattern>` | hide projects |
| `claude projects unignore <rule\|path>` | show them again |
| `claude projects ignored` | the ignore rules, and what each one hides |
| `cproj …` | same as `claude projects …`, and always available |

**Symbols:** ▶ Claude is running there now · ✻ you were last active there through Claude (for `no git` folders: you've used Claude there) · ● uncommitted changes.

## Ignoring projects

Hide anything you don't want in the list, such as backups, archives or scratch folders:

```sh
claude projects ignore ~/projects/old-prototype     # one folder, and everything inside it
claude projects ignore scratch                      # any project with this folder name
claude projects ignore '*-backups'                  # a pattern on the folder name
```

Missing something? `claude projects ignored` lists every rule and what it hides, and `claude projects list --all` shows hidden projects next to the rule hiding each one. Use `claude projects unignore <rule>` to bring one back. If a project is hidden by a pattern, `unignore <its path>` tells you which rule to remove.

The rules live in `~/.config/claude-projects/ignore`, one per line, so you can also edit the file directly.

**Or ask Claude.** These commands are plain text and never prompt, so Claude Code can run them for you. For example: *"hide my backup folders from claude-projects"* or *"why isn't intel-brief showing up in claude projects?"* Claude can run `claude-projects help` to see the commands.

## Config

Settings live in `~/.config/claude-projects/config`. `setup` writes the file, and you can also edit it directly.

| Setting | Default | |
|---|---|---|
| `CP_ROOTS` | (from setup) | folders to scan, colon-separated |
| `CP_DEPTH` | `3` | how many folder levels below a root a repo can be |
| `CP_INCLUDE_NONGIT` | `yes` | also list folders that aren't git repos. `no` means repos only |
| `CP_EDITOR` | auto | command for `ctrl-e` (cursor, code, zed…) |
| `CP_HIDE_PROMPTS` | `no` | `yes` hides your past prompts in the preview |
| `CP_WRAP_CLAUDE` | `yes` | `no` means only `cproj` works and `claude` is left completely alone |
| `CP_WORDS` | `projects` | words that open the picker, e.g. `"projects p"` |
| `CP_THEME` | `auto` | `dark`, `light`, `none` (also respects `NO_COLOR`) |
| `CP_ASCII` | `auto` | `yes` for plain symbols if your font lacks box-drawing characters |
| `CP_FZF_OPTS` | | extra fzf flags. Your own `FZF_DEFAULT_OPTS` are ignored here |

## Troubleshooting

Run **`claude projects doctor`** first. It checks every item below and tells you what to do.

- **"No projects found"**, or a project is missing: run `claude projects ignored` in case a rule hides it. Otherwise run `claude projects setup` and pick the right folders, or raise `CP_DEPTH` if your repos sit deeper than 3 levels. A folder that only contains other repos (like `~/code/my-org/`) is treated as a group, not a project.
- **`claude projects` just starts Claude with "projects" as the prompt**: something redefines `claude` after this tool loads, such as an alias or a plugin. Move the `# >>> claude-projects >>>` block to the end of your rc file. `cproj` works regardless.
- **Your `alias claude='claude --flags'`**: supported. The picker keeps those flags.
- **Old fzf** (common with `apt`): the picker still works, with some features off. Upgrade with `brew upgrade fzf`.
- **macOS asks to install "command line developer tools"**: git needs them. Run `xcode-select --install`.
- **Dotfiles managers** (stow, chezmoi, a symlinked `~/.zshrc`): the installer edits through the symlink. Commit the change in your dotfiles repo so it isn't reverted.
- **No Claude history for a repo**: history appears once you've run `claude` there. Claude Code deletes old transcripts after a while (`cleanupPeriodDays`), so older repos are sorted by last commit instead, and folders without git by when their files last changed.
- **▶ never shows**: detection looks for a process named `claude`, or node running `@anthropic-ai/claude-code`. On macOS it needs `lsof`.
- **fish**: not supported yet. Use `cproj` from zsh or bash.

## Privacy and safety

- It only **reads** `~/.claude/projects`. It never changes your sessions.
- The preview shows your recent prompts. Set `CP_HIDE_PROMPTS=yes`, or press `ctrl-/`, before sharing your screen.
- Git runs with optional locks off (so it never competes with a Claude session running git in the same repo), and with the repo's fsmonitor and hooks disabled.
- Nothing is sent anywhere. No network access except `update`, which runs `git pull`.

## Update / uninstall

With Homebrew:

```sh
brew upgrade claude-projects
claude-projects uninstall-shell && brew uninstall claude-projects
```

With a git install:

```sh
claude projects update                                  # git pull + re-install
~/.local/share/claude-projects/uninstall.sh             # keeps your config
~/.local/share/claude-projects/uninstall.sh --purge     # also deletes config
```

## Develop

`tests/smoke.sh` runs the whole flow in a throwaway `$HOME` with stub `fzf` and `claude` binaries: listing, preview, picker, non-git folders, ignore rules, install twice, wrapper, doctor, uninstall. It never touches your real setup.

```sh
tests/smoke.sh
```

To release, run `scripts/release.sh 1.1.0`. It sets the version, runs the tests, tags and pushes, then updates the formula in [snowbeluga/homebrew-tap](https://github.com/snowbeluga/homebrew-tap) (cloned next to this repo).

## License

MIT

Note: the preview reads Claude Code's local session files (`~/.claude/projects/*/*.jsonl`). That format is internal to Claude Code and may change. If it does, the preview degrades (no prompt history) rather than breaking, and `doctor` flags it.
