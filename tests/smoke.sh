#!/usr/bin/env bash
# Smoke tests. Runs everything inside a throwaway fake $HOME with stub fzf/claude binaries,
# so it never touches your real shell config.   Usage: tests/smoke.sh
REPO=$(cd "$(dirname "$0")/.." && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/cp-test.XXXXXX"); trap 'rm -rf "$T"' EXIT
T=$(cd "$T" && pwd)   # macOS TMPDIR ends in '/', giving 'T//cp-test'; normalise so it matches $(pwd)
export HOME="$T/home" XDG_CONFIG_HOME="" XDG_CACHE_HOME="" CLAUDE_CONFIG_DIR="" NO_COLOR=1 LANG=en_US.UTF-8
unset CP_HOME CP_ROOTS CLAUDE_PROJECT_ROOTS FZF_DEFAULT_OPTS ZDOTDIR
mkdir -p "$HOME" "$T/stub"
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; fi; }

# --- stubs: fzf picks the line containing $FZF_STUB_PICK and reports key $FZF_STUB_KEY
cat > "$T/stub/fzf" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in --version) echo "0.56.0 (stub)"; exit 0 ;; --filter=*) cat >/dev/null; exit 1 ;; esac
done
printf '%s\n' "$*" >> "$HOME/fzf-args.log"
in=$(cat)
case " $* " in *" --multi "*) printf '%s\n' "$in"; exit 0 ;; esac
case " $* " in *--expect=*) printf '%s\n' "${FZF_STUB_KEY:-}" ;; esac
printf '%s\n' "$in" | grep -F -- "${FZF_STUB_PICK:-}" | head -1
EOF
cat > "$T/stub/claude" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--version" ] && { echo "9.9.9 (Claude Code stub)"; exit 0; }
printf 'CLAUDE pwd=%s args=%s\n' "$(pwd)" "$*"
EOF
chmod +x "$T/stub/fzf" "$T/stub/claude"
export PATH="$T/stub:$PATH"

mkrepo() { mkdir -p "$1" && (cd "$1" && git init -q && git config user.email t@t && git config user.name t \
  && echo x > f && git add f && GIT_COMMITTER_DATE="$2" git commit -q -m "init $(basename "$1")" --date="$2"); }
mkrepo "$HOME/code/alpha" "2026-01-01T00:00:00"; echo dirty >> "$HOME/code/alpha/f"
mkrepo "$HOME/code/bravo" "2026-03-01T00:00:00"
mkrepo "$HOME/code/org/charlie" "2026-02-01T00:00:00"
mkrepo "$HOME/code/bravo/nested" "2026-02-01T00:00:00"        # nested repo: should be hidden
mkdir -p "$HOME/code/bravo/sub" && echo "gitdir: x" > "$HOME/code/bravo/sub/.git"   # submodule: hidden
mkrepo "$HOME/code/node_modules/pkg" "2026-02-01T00:00:00"   # pruned
mkrepo "$HOME/Documents/GitHub/delta" "2026-02-01T00:00:00"
mkrepo "$HOME/space dir/echo" "2026-02-01T00:00:00"

# Claude sessions: alpha via a subfolder cwd (newest), delta via folder-name fallback (no cwd field)
enc() { printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g'; }
A="$HOME/.claude/projects/$(enc "$HOME/code/alpha/packages")"; mkdir -p "$A"
cat > "$A/s1.jsonl" <<EOF
{"type":"summary","summary":"Refactor token refresh"}
{"type":"user","cwd":"$HOME/code/alpha/packages","message":{"content":"fix the refresh bug"}}
{"type":"user","cwd":"$HOME/code/alpha/packages","message":{"content":[{"type":"tool_result","content":"x"}]}}
{"type":"user","cwd":"$HOME/code/alpha/packages","isMeta":true,"message":{"content":"meta"}}
{"type":"user","cwd":"$HOME/code/alpha/packages","message":{"content":"<command-name>/clear</command-name>"}}
{"type":"user","cwd":"$HOME/code/alpha/packages","message":{"content":[{"type":"text","text":"now add   tests"}]}}
broken{
EOF
D="$HOME/.claude/projects/$(enc "$HOME/Documents/GitHub/delta")"; mkdir -p "$D"
echo '{"type":"user","message":{"content":"hello delta"}}' > "$D/s.jsonl"
touch -t 202606010000 "$A/s1.jsonl"; touch -t 202604010000 "$D/s.jsonl"

BIN="$REPO/bin/claude-projects"
echo "list + preview"
export CP_ROOTS="$HOME/code:$HOME/Documents/GitHub:$HOME/space dir" CP_DEPTH=3
L=$("$BIN" --list)
order=$(printf '%s\n' "$L" | cut -f1 | sed "s|$HOME/||" | tr '\n' ' ')
check "order by recency (alpha session > delta session > bravo commit > charlie/echo)" '[ "$order" = "code/alpha Documents/GitHub/delta code/bravo code/org/charlie space dir/echo " ] || { echo "     got: $order"; false; }'
check "nested repo, submodule and node_modules hidden" '! printf "%s" "$L" | grep -Eq "nested|/sub|node_modules"'
check "alpha marked dirty + Claude" 'printf "%s\n" "$L" | grep "code/alpha" | grep -q "●" && printf "%s\n" "$L" | grep "code/alpha" | grep -q "✻"'
check "bravo has no Claude mark" '! printf "%s\n" "$L" | grep "code/bravo" | grep -q "✻"'
export CP_INDEX="$T/idx"; CP_NO_MAIN=1 bash -c ". '$BIN'; load_config; setup_style; build_index" > "$CP_INDEX"
P=$("$BIN" --preview "$HOME/code/alpha")
check "preview shows summary" 'printf "%s" "$P" | grep -q "Refactor token refresh"'
check "preview shows real prompts only" 'printf "%s" "$P" | grep -q "fix the refresh bug" && printf "%s" "$P" | grep -q "now add tests" && ! printf "%s" "$P" | grep -Eq "meta|command-name|tool_result"'
P2=$(CP_HIDE_PROMPTS=yes "$BIN" --preview "$HOME/code/alpha")
check "CP_HIDE_PROMPTS hides prompts" '! printf "%s" "$P2" | grep -q "fix the refresh bug" && printf "%s" "$P2" | grep -q "prompts hidden"'
P3=$("$BIN" --preview "$HOME/Documents/GitHub/delta")
check "fallback match via folder name" 'printf "%s" "$P3" | grep -q "hello delta"'
P4=$("$BIN" --preview "$HOME/space dir/echo")
check "paths with spaces preview" 'printf "%s" "$P4" | grep -q "no sessions yet"'
unset CP_INDEX
P5=$("$BIN" --preview "$HOME/code/alpha")
check "standalone preview (no CP_INDEX) finds sessions" 'printf "%s" "$P5" | grep -q "fix the refresh bug"'

echo "picker"
O=$(FZF_STUB_PICK=charlie FZF_STUB_KEY=ctrl-o "$BIN")
check "picker returns key + path" '[ "$O" = "ctrl-o	$HOME/code/org/charlie" ]'
check "user FZF_DEFAULT_OPTS ignored, header present" 'grep -q -- "--header=" "$HOME/fzf-args.log"'
O=$(CP_ROOTS="$HOME/nowhere" "$BIN" 2>&1); rc=$?
check "no repos -> helpful message, exit 1" '[ $rc = 1 ] && printf "%s" "$O" | grep -q "claude-projects setup"'

echo "non-git projects + ignore rules"
mkdir -p "$HOME/code/notes" "$HOME/code/old-backups" "$HOME/code/org/drafts" && echo n > "$HOME/code/notes/todo.md"
G="$HOME/.claude/projects/$(enc "$HOME/code/org/drafts")"; mkdir -p "$G"
echo "{\"type\":\"user\",\"cwd\":\"$HOME/code/org/drafts\",\"message\":{\"content\":\"draft the memo\"}}" > "$G/s.jsonl"
L=$("$BIN" list)
check "plain list shows git + folder kinds" 'printf "%s\n" "$L" | grep -q "^folder .*~/code/notes$" && printf "%s\n" "$L" | grep -q "^git .*~/code/bravo$"'
check "folder Claude was used in is listed, container folder is not" 'printf "%s\n" "$L" | grep -q "^folder  yes .*~/code/org/drafts$" && ! printf "%s\n" "$L" | grep -q "~/code/org$"'
check "picker row says no git" '"$BIN" --list | grep "code/notes" | grep -q "no git"'
check "preview of a folder" '"$BIN" --preview "$HOME/code/notes" 2>/dev/null | grep -q "not a git repo" && "$BIN" --preview "$HOME/code/org/drafts" 2>/dev/null | grep -q "draft the memo"'
check "CP_INCLUDE_NONGIT=no lists git only" '! CP_INCLUDE_NONGIT=no "$BIN" list | grep -q "^folder"'
check "piped output has no colour codes" '! env -u NO_COLOR "$BIN" list | grep -q "$(printf "\033")"'
O=$("$BIN" ignore '*-backups' "$HOME/code/notes")
check "ignore reports what it hides" 'printf "%s" "$O" | grep -q "ignored: \*-backups  (hides 1 project)" && printf "%s" "$O" | grep -q "ignored: ~/code/notes"'
check "ignore twice is a no-op" '"$BIN" ignore "*-backups" | grep -q "already ignored" && [ "$(grep -c "^\*-backups$" "$HOME/.config/claude-projects/ignore")" = 1 ]'
check "ignored projects leave the picker" '! "$BIN" --list | grep -Eq "old-backups|code/notes"'
check "list --all shows them with the rule" '"$BIN" list --all | grep -q "^ignored .*~/code/old-backups   (rule: \*-backups)"'
check "ignored explains each rule" '"$BIN" ignored | grep -A1 "^  \*-backups" | grep -q "hides ~/code/old-backups"'
O=$("$BIN" unignore "$HOME/code/old-backups" 2>&1); rc=$?
check "unignore of a glob-hidden path points at the rule" '[ $rc = 1 ] && printf "%s" "$O" | grep -q "unignore '"'"'\*-backups'"'"'"'
check "unignore by path and by rule" '"$BIN" unignore "$HOME/code/notes" "*-backups" | grep -c "no longer ignored" | grep -q 2 && "$BIN" ignored | grep -q "Nothing is ignored"'

echo "setup scan"
S=$(cd "$T" && CP_NO_MAIN=1 bash -c ". '$BIN'; load_config; setup_style; make_tmp; scan_candidates" 2>/dev/null)
check "scan groups by top folder" 'printf "%s\n" "$S" | grep -q "	$HOME/code$" && printf "%s\n" "$S" | grep -q "	$HOME/Documents/GitHub$"'
check "scan skips node_modules" '! printf "%s" "$S" | grep -q node_modules'

echo "install (zsh + bash, v0 migration, alias, run twice)"
unset CP_ROOTS CP_DEPTH
cat > "$HOME/.zshrc" <<'EOF'
alias claude='claude --model opus'
# >>> claude-projects >>>
export CLAUDE_PROJECT_ROOTS="$HOME/code"
claude() { command claude "$@"; }
# <<< claude-projects <<<
EOF
echo 'export FOO=1' > "$HOME/.bashrc"
mkdir -p "$T/dotfiles" && echo '# bash profile' > "$T/dotfiles/bash_profile" && ln -s "$T/dotfiles/bash_profile" "$HOME/.bash_profile"
SHELL=/bin/zsh "$REPO/install.sh" --yes --no-deps --quiet --shell=both </dev/null >/dev/null 2>"$T/inst1.log"
SHELL=/bin/bash "$REPO/install.sh" --yes --no-deps --quiet --shell=both </dev/null >/dev/null 2>"$T/inst2.log"
check "exactly one block in .zshrc after two runs" '[ "$(grep -c ">>> claude-projects >>>" "$HOME/.zshrc")" = 1 ]'
check "old v0 claude() removed, alias kept" '! grep -q "claude() {" "$HOME/.zshrc" && grep -q "alias claude=" "$HOME/.zshrc"'
check "v0 folders migrated to config" 'grep -q "CP_ROOTS=\"\$HOME/code\"" "$HOME/.config/claude-projects/config"'
check "bashrc hooked" 'grep -q "claude-projects.sh" "$HOME/.bashrc" && grep -q "FOO=1" "$HOME/.bashrc"'
check ".bash_profile symlink preserved and hooked" '[ -L "$HOME/.bash_profile" ] && grep -q claude-projects.sh "$T/dotfiles/bash_profile"'
check "files installed + linked" '[ -x "$HOME/.local/share/claude-projects/bin/claude-projects" ] && [ -L "$HOME/.local/bin/claude-projects" ]'

echo "wrapper (bash)"
printf "alias claude='claude --model opus'\n" | cat - "$HOME/.bashrc" > "$T/b" && cat "$T/b" > "$HOME/.bashrc"
W=$(cd "$T" && bash -c 'source ~/.bashrc; type -t claude; type -t cproj; claude --print hi' 2>&1)
check "claude + cproj are functions" 'printf "%s\n" "$W" | sed -n 1,2p | tr "\n" " " | grep -q "function function"'
check "passthrough keeps alias flags" 'printf "%s" "$W" | grep -q "args=--model opus --print hi"'
W=$(cd "$T" && FZF_STUB_PICK=bravo FZF_STUB_KEY=ctrl-o bash -c 'source ~/.bashrc; claude projects --verbose; pwd' 2>&1)
check "claude projects -> cd + continue with flags" 'printf "%s" "$W" | grep -q "pwd=$HOME/code/bravo args=--model opus -c --verbose" && printf "%s" "$W" | tail -1 | grep -q "code/bravo$"'
W=$(cd "$T" && FZF_STUB_PICK=bravo FZF_STUB_KEY=ctrl-g bash -c 'source ~/.bashrc; cproj; pwd' 2>&1)
check "ctrl-g only changes folder" '! printf "%s" "$W" | grep -q CLAUDE && printf "%s" "$W" | grep -q "code/bravo$"'
W=$(cd "$T" && bash -c 'source ~/.bashrc; source ~/.bashrc; claude x' 2>&1)
check "sourcing twice still keeps alias flags" 'printf "%s" "$W" | grep -q "args=--model opus x"'
W=$(cd "$T" && bash -c 'source ~/.bashrc; claude projects version' 2>&1)
check "claude projects version" 'printf "%s" "$W" | grep -q "claude-projects 1"'
W=$(cd "$T" && bash -c 'source ~/.bashrc; claude projects ignored; cproj list' 2>&1)
check "claude projects ignored / cproj list" 'printf "%s" "$W" | grep -q "Nothing is ignored" && printf "%s" "$W" | grep -q "^KIND"'
sed -i.tmp 's/^CP_ROOTS=.*/&\nCP_WRAP_CLAUDE=no/' "$HOME/.config/claude-projects/config" && rm -f "$HOME/.config/claude-projects/config.tmp"
W=$(cd "$T" && bash -c 'source ~/.bashrc; type -t claude; claude hi' 2>&1)
check "CP_WRAP_CLAUDE=no leaves claude alone" 'printf "%s" "$W" | grep -q "^alias$" || ! printf "%s" "$W" | grep -q "^function$"'
if command -v zsh >/dev/null 2>&1; then
  W=$(cd "$T" && ZDOTDIR=$HOME zsh -c 'source ~/.zshrc; type claude' 2>&1)
  check "zsh: CP_WRAP_CLAUDE=no + alias parses cleanly" '! printf "%s" "$W" | grep -q "parse error" && printf "%s" "$W" | grep -q "alias"'
  sed -i.tmp '/^CP_WRAP_CLAUDE=no$/d' "$HOME/.config/claude-projects/config" && rm -f "$HOME/.config/claude-projects/config.tmp"
  W=$(cd "$T" && ZDOTDIR=$HOME zsh -c 'source ~/.zshrc; cproj version; claude --print x' 2>&1)
  check "zsh wrapper works" 'printf "%s" "$W" | grep -q "claude-projects 1" && printf "%s" "$W" | grep -q "args=--model opus --print x"'
else echo "  skip zsh tests (zsh not installed)"; fi

echo "doctor"
Dout=$(SHELL=/bin/bash "$HOME/.local/bin/claude-projects" doctor 2>&1); rc=$?
check "doctor runs and counts git + non-git projects" 'printf "%s" "$Dout" | grep -Eq "~/code — [0-9]+ projects \([0-9]+ git, [1-9][0-9]* without git\)" && printf "%s" "$Dout" | grep -q "Claude Code 9.9.9"'
printf '%s\n' "$Dout" | sed 's/^/     | /'

echo "uninstall"
"$HOME/.local/share/claude-projects/uninstall.sh" --yes 2>/dev/null
check "blocks removed everywhere" '! grep -q claude-projects "$HOME/.zshrc" "$HOME/.bashrc" "$T/dotfiles/bash_profile"'
check "files removed, config kept" '[ ! -e "$HOME/.local/share/claude-projects" ] && [ ! -e "$HOME/.local/bin/claude-projects" ] && [ -f "$HOME/.config/claude-projects/config" ]'
check "user lines untouched" 'grep -q "FOO=1" "$HOME/.bashrc" && grep -q "alias claude=" "$HOME/.zshrc"'

echo "homebrew layout"
# Mimic brew: Cellar/<name>/<ver>/libexec holds the files, opt/<name> -> Cellar/<name>/<ver>, bin/ links in.
BR="$T/brew"; K="$BR/Cellar/claude-projects/1.0.0"
mkdir -p "$K/libexec" "$K/bin" "$BR/opt" "$BR/bin" "$HOME/.local/bin"
cp -R "$REPO/bin" "$REPO/shell" "$REPO/install.sh" "$REPO/uninstall.sh" "$K/libexec/"
ln -s ../libexec/bin/claude-projects "$K/bin/claude-projects"
ln -s ../Cellar/claude-projects/1.0.0 "$BR/opt/claude-projects"
ln -s ../Cellar/claude-projects/1.0.0/bin/claude-projects "$BR/bin/claude-projects"
ln -s "$HOME/.local/share/claude-projects/bin/claude-projects" "$HOME/.local/bin/claude-projects"   # left by a git install
SHELL=/bin/zsh "$BR/bin/claude-projects" install-shell --yes --quiet --shell=zsh </dev/null >/dev/null 2>"$T/brew.log"
BRP=$(cd "$BR" && pwd -P)
check "install-shell hooks zsh via the stable opt/ path" 'grep -q "CP_HOME=\"$BRP/opt/claude-projects/libexec\"" "$HOME/.zshrc" && ! grep -q Cellar "$HOME/.zshrc" && grep -q "Remove with: claude-projects uninstall-shell" "$HOME/.zshrc"'
check "brew mode copies nothing, drops the old git-install link" '[ ! -e "$HOME/.local/share/claude-projects" ] && [ ! -L "$HOME/.local/bin/claude-projects" ]'
if command -v zsh >/dev/null 2>&1; then
  W=$(cd "$T" && ZDOTDIR=$HOME zsh -c 'source ~/.zshrc; cproj version; claude projects update' 2>&1)
  check "wrapper runs the brew copy; update says brew upgrade" 'printf "%s" "$W" | grep -q "claude-projects 1" && printf "%s" "$W" | grep -q "brew upgrade claude-projects"'
fi
check "doctor knows it's Homebrew" '"$BR/bin/claude-projects" doctor 2>&1 | grep -q "opt/claude-projects/libexec (Homebrew)"'
"$BR/bin/claude-projects" uninstall-shell 2>/dev/null
check "uninstall-shell removes the hook, leaves brew's files" '! grep -q claude-projects "$HOME/.zshrc" && [ -x "$K/libexec/bin/claude-projects" ]'
"$K/libexec/uninstall.sh" --yes 2>/dev/null
check "uninstall.sh inside brew never deletes brew's files" '[ -x "$K/libexec/bin/claude-projects" ]'

echo; echo "$PASS passed, $FAIL failed"; [ $FAIL = 0 ]
