# ✻ claude projects

A terminal picker for jumping between your projects and Claude Code sessions.

```
  ┌─┐┬  ┌─┐┬ ┬┌┬┐┌─┐  ┌─┐┬─┐┌─┐ ┬┌─┐┌─┐┌┬┐┌─┐
  │  │  ├─┤│ │ ││├┤   ├─┘├┬┘│ │ │├┤ │   │ └─┐
  └─┘┴─┘┴ ┴└─┘─┴┘└─┘  ┴  ┴└─└─┘└┘└─┘└─┘ ┴ └─┘
  12 projects · 1 running · ✻ Claude session · ● uncommitted
  ↵ open  ^n new project  ^o continue  ^r resume  ^g cd only  ^e editor  ^y copy  ^x ignore  ^l refresh
  ❯
▌ ▶ identity-api      feat/token-refresh   ●  2h ago ✻   │ identity-api
    pra-console       main                    1d ago ✻   │ ✻ CLAUDE  last session 2h ago · 14 total
    research-notes    no git                  1w ago ✻   │   Refactor token refresh flow
    docs-site         main                    3w ago     │   › fix the refresh bug in auth middleware
    ＋ New project  ctrl-n                               │   › now add tests for the expiry edge case
                                                         │ ⎇ GIT  feat/token-refresh  ↑2  3 changed
```

Type `claude projects` (or `cproj`). You get your projects sorted by what you touched most recently, with a preview of what you last asked Claude in each one. Pick one and you're in a Claude session there.

Projects don't have to be git repos. Folders directly inside your project folders, and any folder where you've used Claude, are listed too and marked `no git`.

Starting something new? Pick **＋ New project** at the bottom of the list, or press `ctrl-n`. Give it a name and, if you like, say what you want to build. It makes the folder, sets up git, and opens Claude with that as your first message.

Every other `claude …` command goes straight to Claude Code, unchanged.

## Install

You need macOS or Linux with zsh or bash, and [Claude Code](https://docs.claude.com/en/docs/claude-code).

### With Homebrew (recommended, macOS or Linux)

```sh
brew install snowbeluga/tap/claude-projects
claude-projects install-shell
```

`brew install` puts the tool on your PATH and installs `fzf` and `jq`. Homebrew never edits shell config, so `install-shell` does that step:

- adds **one line** to your `~/.zshrc` and/or `~/.bashrc`, after making a backup (`*.claude-projects.bak`)
- asks which folders your projects live in (skipped if you already have a config). If you don't have one yet, it suggests creating `~/projects`. Press enter to accept, or type another name or an existing folder
- runs `claude projects doctor` to confirm everything works

### Without Homebrew

```sh
git clone https://github.com/snowbeluga/claude-projects.git ~/.local/share/claude-projects
~/.local/share/claude-projects/install.sh
```

The installer does the same three steps as `install-shell`. It also checks for `fzf` (required) and `jq` (optional), and offers to install them for you if you have Homebrew.

**Either way, open a new terminal tab when it finishes**, then run `claude projects`.

### Switching from a git install to Homebrew

```sh
brew install snowbeluga/tap/claude-projects
"$(brew --prefix)/opt/claude-projects/bin/claude-projects" install-shell   # full path, just this once
rm -rf ~/.local/share/claude-projects                                      # the old copy
```

You need the full path the first time because the old `~/.local/bin/claude-projects` comes earlier on your PATH. `install-shell` removes it and points your rc file at Homebrew's copy. Your config and ignore rules are kept.

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
| `ctrl-n` | start a new project (same as the **＋ New project** row at the bottom) |
| `ctrl-x` | ignore that project (hide it from the list) |
| `ctrl-l` or `F5` | refresh the list, e.g. after working in another tab |
| `ctrl-/` | show or hide the preview (handy when screen-sharing) |
| `esc` | cancel |

Anything else after `projects` is passed to Claude. For example, `claude projects --model opus` starts the chosen session with that flag. The words in the table below are commands rather than Claude arguments.

| Command | |
|---|---|
| `claude projects new [name]` | start a new project: makes the folder, runs `git init`, opens Claude |
| `claude projects setup` | choose folders, editor, privacy settings |
| `claude projects doctor` | check the install and explain any problems |
| `claude projects update` | update to the latest version (Homebrew installs: `brew upgrade claude-projects`) |
| `claude projects list [--all]` | plain list of projects. `--all` includes ignored ones |
| `claude projects ignore <path\|name\|pattern>` | hide projects |
| `claude projects unignore <rule\|path>` | show them again |
| `claude projects ignored` | the ignore rules, and what each one hides |
| `claude projects install-shell` | add the line to your rc file (needed once after `brew install`) |
| `claude projects uninstall-shell` | remove that line again |
| `cproj …` | same as `claude projects …`, and always available |
| `claude-projects …` | the command itself, on your PATH. Use it in scripts, or anywhere the shell functions aren't loaded |

## Starting a new project

From the picker, choose **＋ New project** (the last row) or press `ctrl-n`. Or run `claude projects new`. You're asked:

1. **A name.** Spaces become hyphens. If you typed something in the search box first, that's used. Typing a name that matches no project and pressing enter offers to create it too.
2. **Where**, only if you have more than one project folder.
3. **What you want to build** (optional). This becomes your first message to Claude, so you can go straight from an idea to Claude working on it.

The folder is created with `git init`, so every change Claude makes can be reviewed or undone. If git isn't installed, it offers to install it: Apple's Command Line Tools on macOS, or your package manager on Linux. You can also skip it and the project is still created. Set `CP_NEW_GIT=no` to never use git for new projects.

Scripts, and Claude, can do the same without any questions: `claude-projects new recipe-app --prompt "a recipe app" [--in FOLDER] [--no-git]` prints the new folder's path.

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

**Or ask Claude.** These commands print plain text and never prompt, so Claude Code can run them for you. For example: *"hide my backup folders from claude-projects"* or *"why isn't intel-brief showing up in claude projects?"* Claude runs commands in a shell that doesn't load your rc file, so it has to use the hyphenated `claude-projects` (for example `claude-projects ignored`), not `claude projects`. `claude-projects help` lists everything.

## Config

Settings live in `~/.config/claude-projects/config`. `setup` writes the file, and you can also edit it directly.

| Setting | Default | |
|---|---|---|
| `CP_ROOTS` | (from setup) | folders to scan, colon-separated |
| `CP_DEPTH` | `3` | how many folder levels below a root a repo can be |
| `CP_INCLUDE_NONGIT` | `yes` | also list folders that aren't git repos. `no` means repos only |
| `CP_NEW_GIT` | `yes` | new projects start with `git init`. `no` to skip |
| `CP_EDITOR` | auto | command for `ctrl-e` (cursor, code, zed…) |
| `CP_HIDE_PROMPTS` | `no` | `yes` hides your past prompts in the preview |
| `CP_WRAP_CLAUDE` | `yes` | `no` means only `cproj` works and `claude` is left completely alone |
| `CP_WORDS` | `projects` | words that open the picker, e.g. `"projects p"` |
| `CP_THEME` | `auto` | `dark`, `light`, `none` (also respects `NO_COLOR`) |
| `CP_ASCII` | `auto` | `yes` for plain symbols if your font lacks box-drawing characters |
| `CP_FZF_OPTS` | | extra fzf flags. Your own `FZF_DEFAULT_OPTS` are ignored here |

## Troubleshooting

Run **`claude projects doctor`** first. It checks every item below and tells you what to do.

- **`claude projects` or `cproj` isn't found after installing**: open a new terminal tab. With Homebrew, make sure you ran `claude-projects install-shell`.
- **`install-shell` prints usage, or "unknown command"**: an older copy of `claude-projects` is earlier on your PATH. Run it by full path: `"$(brew --prefix)/opt/claude-projects/bin/claude-projects" install-shell`.
- **"No projects found"**, or a project is missing: run `claude projects ignored` in case a rule hides it. Otherwise run `claude projects setup` and pick the right folders, or raise `CP_DEPTH` if your repos sit deeper than 3 levels. A folder that only contains other repos (like `~/code/my-org/`) is treated as a group, not a project.
- **`claude projects` just starts Claude with "projects" as the prompt**: something redefines `claude` after this tool loads, such as an alias or a plugin. Move the `# >>> claude-projects >>>` block to the end of your rc file. `cproj` works regardless.
- **Your `alias claude='claude --flags'`**: supported. The picker keeps those flags.
- **Old fzf** (common with `apt`): the picker still works, with some features off. Upgrade with `brew upgrade fzf`.
- **macOS asks to install "command line developer tools"**: git needs them. Run `xcode-select --install`. Without git, everything still works: repos show `(git not installed)` and new projects are created without history.
- **The list is out of date** (you made a commit or ran Claude in another tab): press `ctrl-l` or `F5`.
- **Dotfiles managers** (stow, chezmoi, a symlinked `~/.zshrc`): the installer edits through the symlink. Commit the change in your dotfiles repo so it isn't reverted.
- **No Claude history for a repo**: history appears once you've run `claude` there. Claude Code deletes old transcripts after a while (`cleanupPeriodDays`), so older repos are sorted by last commit instead, and folders without git by when their files last changed.
- **▶ never shows**: detection looks for a process named `claude`, or node running `@anthropic-ai/claude-code`. On macOS it needs `lsof`.
- **fish**: not supported yet. Use `cproj` from zsh or bash.

## Privacy and safety

- It only **reads** `~/.claude/projects`. It never changes your sessions.
- The preview shows your recent prompts. Set `CP_HIDE_PROMPTS=yes`, or press `ctrl-/`, before sharing your screen.
- Git runs with optional locks off (so it never competes with a Claude session running git in the same repo), and with the repo's fsmonitor and hooks disabled.
- Nothing is sent anywhere. The only network access is `update` on git installs, which runs `git pull`.
- The preview reads Claude Code's local session files (`~/.claude/projects/*/*.jsonl`). That format is internal to Claude Code and may change. If it does, the preview degrades (no prompt history) rather than breaking, and `doctor` flags it.

## Update / uninstall

With Homebrew:

```sh
brew update && brew upgrade claude-projects             # update
claude-projects uninstall-shell                         # remove the rc-file line
brew uninstall claude-projects                          # remove the tool (your config in ~/.config/claude-projects stays)
```

With a git install:

```sh
claude projects update                                  # git pull + re-install
~/.local/share/claude-projects/uninstall.sh             # keeps your config
~/.local/share/claude-projects/uninstall.sh --purge     # also deletes config
```

## Contributing

Want to change something? See [CONTRIBUTING.md](CONTRIBUTING.md) for running the tests and cutting a release.

## License

[MIT](LICENSE)
