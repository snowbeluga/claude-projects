#!/usr/bin/env bash
# install.sh — install or update claude-projects. Safe to run as many times as you like.
#
#   ./install.sh                 interactive install
#   ./install.sh --yes           accept defaults (installs fzf/jq with Homebrew if missing)
#   ./install.sh --shell=zsh     only hook into zsh  (zsh | bash | both)
#   ./install.sh --no-deps --no-setup --no-shell --quiet

YES=0; DEPS=1; SETUP=1; SHELLS=auto; QUIET=0; HOOK=1
for a in "$@"; do
  case "$a" in
    -y|--yes) YES=1 ;;
    --no-deps) DEPS=0 ;;
    --no-setup) SETUP=0 ;;
    --no-shell) HOOK=0 ;;
    --shell=*) SHELLS=${a#--shell=} ;;
    -q|--quiet) QUIET=1 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

SRC=$(cd "$(dirname "$0")" && pwd -P)
CP_HOME="${CP_HOME:-$HOME/.local/share/claude-projects}"
BIN_DIR="$HOME/.local/bin"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/claude-projects/config"
IS_MAC=0; [ "$(uname -s)" = Darwin ] && IS_MAC=1
MARK_START="# >>> claude-projects >>>"
MARK_END="# <<< claude-projects <<<"

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  E=$(printf '\033'); R="$E[0m"; B="$E[1m"; O="$E[38;5;209m"; G="$E[38;5;114m"; Y="$E[38;5;221m"; D="$E[38;5;244m"; RED="$E[38;5;203m"
else R=""; B=""; O=""; G=""; Y=""; D=""; RED=""; fi
step() { [ $QUIET = 1 ] || printf '\n%s%s%s\n' "$O$B" "$*" "$R" >&2; }
ok()   { [ $QUIET = 1 ] || printf '  %s✓%s %s\n' "$G" "$R" "$*" >&2; }
note() { [ $QUIET = 1 ] || printf '  %s·  %s%s\n' "$D" "$*" "$R" >&2; }
warn() { printf '  %s!%s  %s\n' "$Y" "$R" "$*" >&2; }
fail() { printf '  %s✗%s %s\n' "$RED" "$R" "$*" >&2; }
short() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

HAVE_TTY=0; ( : </dev/tty ) 2>/dev/null && HAVE_TTY=1
confirm() { # confirm "question" -> 0 for yes. Default yes.
  [ $YES = 1 ] && return 0
  [ $HAVE_TTY = 1 ] || return 1
  printf '  %s %s[Y/n]%s ' "$1" "$D" "$R" >&2
  local r; IFS= read -r r </dev/tty || r=""
  case "$r" in [Nn]*) return 1 ;; *) return 0 ;; esac
}
ver_ge() {
  local a b i x y; a=$(printf '%s' "$1" | sed 's/[^0-9.].*//'); b=$2
  for i in 1 2 3; do
    x=$(printf '%s' "$a" | cut -d. -f$i); y=$(printf '%s' "$b" | cut -d. -f$i); x=${x:-0}; y=${y:-0}
    [ "$x" -gt "$y" ] && return 0; [ "$x" -lt "$y" ] && return 1
  done; return 0
}

[ $QUIET = 1 ] || printf '\n%s  ✻ claude-projects installer%s\n' "$O$B" "$R" >&2

# ------------------------------------------------------------------ requirements
step "Checking requirements"
if [ $IS_MAC = 1 ] && ! xcode-select -p >/dev/null 2>&1; then
  warn "git needs Apple's Command Line Tools, which aren't installed. Run: xcode-select --install   then re-run this installer."
elif command -v git >/dev/null 2>&1; then ok "git"
else fail "git not found — install git first"; fi

BREW=""; command -v brew >/dev/null 2>&1 && BREW=brew
[ -z "$BREW" ] && [ -x /opt/homebrew/bin/brew ] && BREW=/opt/homebrew/bin/brew
[ -z "$BREW" ] && [ -x /usr/local/bin/brew ] && BREW=/usr/local/bin/brew

need_pkg() { # need_pkg name min_version(optional) required(1/0)
  local name=$1 min=$2 req=$3 v=""
  if command -v "$name" >/dev/null 2>&1; then
    [ "$name" = fzf ] && v=$(fzf --version 2>/dev/null | awk '{print $1}')
    [ "$name" = jq ] && v=$(jq --version 2>/dev/null | sed 's/^jq-//')
    if [ -n "$min" ] && ! ver_ge "$v" "$min"; then
      warn "$name $v is older than $min"
      if [ $DEPS = 1 ] && [ -n "$BREW" ] && confirm "Upgrade $name with Homebrew?"; then "$BREW" upgrade "$name" && ok "$name upgraded"; return; fi
      note "upgrade it when you can — some features are turned off on old versions"
    else ok "$name $v"; fi
    return
  fi
  if [ $DEPS = 1 ] && [ -n "$BREW" ] && confirm "$name isn't installed. Install it with Homebrew?"; then
    "$BREW" install "$name" && { ok "$name installed"; return; }
  fi
  if [ "$req" = 1 ]; then
    fail "$name is required and isn't installed."
    if [ -n "$BREW" ]; then note "install it with: brew install $name"
    elif [ $IS_MAC = 1 ]; then note "no Homebrew found. Either install Homebrew (https://brew.sh) or, without admin rights:"
      note "  git clone --depth 1 https://github.com/junegunn/fzf ~/.fzf && ~/.fzf/install --bin && export PATH=\"\$HOME/.fzf/bin:\$PATH\""
    else note "install it with your package manager (apt's version may be old), or: git clone --depth 1 https://github.com/junegunn/fzf ~/.fzf && ~/.fzf/install --bin"; fi
    MISSING_REQ=1
  else
    warn "$name not installed (optional) — the preview won't show your recent prompts until you install it."
  fi
}
MISSING_REQ=0
need_pkg fzf 0.38 1
need_pkg jq "" 0
if command -v claude >/dev/null 2>&1; then ok "Claude Code ($(short "$(command -v claude)"))"
else warn "Claude Code (claude) isn't on PATH — install it before using the picker"; fi

# ------------------------------------------------------------------ files
step "Installing files"
mkdir -p "$CP_HOME" "$BIN_DIR" || { fail "couldn't create $CP_HOME"; exit 1; }
DEST=$(cd "$CP_HOME" && pwd -P)
if [ "$SRC" != "$DEST" ]; then
  rm -rf "$CP_HOME/bin" "$CP_HOME/shell"
  cp -R "$SRC/bin" "$SRC/shell" "$CP_HOME/" || { fail "copy failed"; exit 1; }
  for f in install.sh uninstall.sh README.md LICENSE; do [ -f "$SRC/$f" ] && cp "$SRC/$f" "$CP_HOME/"; done
  ok "copied to $(short "$CP_HOME")"
  note "update later by pulling your clone and re-running its install.sh"
else
  ok "running from $(short "$CP_HOME")"
  [ -d "$CP_HOME/.git" ] && note "update later with: claude projects update"
fi
chmod +x "$CP_HOME/bin/claude-projects" "$CP_HOME/install.sh" "$CP_HOME/uninstall.sh" 2>/dev/null

LINK="$BIN_DIR/claude-projects"
if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
  mv "$LINK" "$LINK.old" && note "moved an older claude-projects script to $(short "$LINK.old")"
fi
ln -sf "$CP_HOME/bin/claude-projects" "$LINK" && ok "linked $(short "$LINK")"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) note "$(short "$BIN_DIR") isn't on your PATH — fine, cproj and 'claude projects' don't need it" ;; esac

# ------------------------------------------------------------------ v0 migration
# The hand-installed version kept its folders in CLAUDE_PROJECT_ROOTS inside the rc block.
OLD_ROOTS=""
for rc in "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  v=$(awk -v s="$MARK_START" -v e="$MARK_END" '$0==s{f=1} f&&/CLAUDE_PROJECT_ROOTS=/{print; exit} $0==e{f=0}' "$rc" \
      | sed -n 's/.*CLAUDE_PROJECT_ROOTS=["'\'']\{0,1\}\([^"'\'']*\).*/\1/p')
  [ -n "$v" ] && OLD_ROOTS=$v && break
done
if [ -n "$OLD_ROOTS" ] && [ ! -f "$CONF" ]; then
  mkdir -p "$(dirname "$CONF")"
  printf '# claude-projects config — migrated from your earlier install. Re-run: claude-projects setup\nCP_ROOTS="%s"\n' "$OLD_ROOTS" > "$CONF"
  ok "kept your folders from the earlier version ($OLD_ROOTS)"
fi

# ------------------------------------------------------------------ shell hook
strip_block() { # remove every claude-projects block from $1 (writes in place, keeps symlinks)
  local rc=$1 tmp
  grep -qF "$MARK_START" "$rc" 2>/dev/null || return 0
  tmp=$(mktemp "${TMPDIR:-/tmp}/cp-rc.XXXXXX") || return 1
  awk -v s="$MARK_START" -v e="$MARK_END" '$0==s{skip=1; next} skip&&$0==e{skip=0; next} !skip' "$rc" > "$tmp" && cat "$tmp" > "$rc"
  rm -f "$tmp"
}
add_block() {
  local rc=$1 home_rel
  [ -e "$rc" ] || : > "$rc"
  if [ ! -w "$rc" ]; then fail "$(short "$rc") isn't writable — add this line yourself: . \"$CP_HOME/shell/claude-projects.sh\""; return 1; fi
  cp "$rc" "$rc.claude-projects.bak" 2>/dev/null
  strip_block "$rc"
  case "$CP_HOME" in "$HOME"/*) home_rel="\$HOME${CP_HOME#"$HOME"}" ;; *) home_rel=$CP_HOME ;; esac
  # make sure we start on a new line
  [ -s "$rc" ] && [ "$(tail -c 1 "$rc" | od -An -c | tr -d ' ')" != '\n' ] && printf '\n' >> "$rc"
  {
    echo "$MARK_START"
    echo "# Added by claude-projects. Remove with: $home_rel/uninstall.sh"
    [ "$CP_HOME" != "$HOME/.local/share/claude-projects" ] && echo "export CP_HOME=\"$home_rel\""
    echo "[ -f \"$home_rel/shell/claude-projects.sh\" ] && . \"$home_rel/shell/claude-projects.sh\""
    echo "$MARK_END"
  } >> "$rc"
  ok "hooked into $(short "$rc")  ${D}(backup: $(short "$rc").claude-projects.bak)${R}"
  [ -L "$rc" ] && note "$(short "$rc") is a symlink — commit this change in your dotfiles repo, or your dotfiles tool may overwrite it"
  if command -v chezmoi >/dev/null 2>&1 && chezmoi source-path "$rc" >/dev/null 2>&1; then
    note "$(short "$rc") is managed by chezmoi — run: chezmoi add $(short "$rc")   so it isn't reverted"
  fi
  # other things that could shadow us
  if grep -Eq '^[[:space:]]*(function[[:space:]]+)?claude[[:space:]]*\(\)' "$rc"; then
    warn "$(short "$rc") also defines its own claude() function — remove it (it was probably the hand-installed version)"
  fi
  if grep -Eq '^[[:space:]]*alias[[:space:]]+claude=' "$rc"; then
    note "found an 'alias claude=…' in $(short "$rc") — that's fine, its flags are kept when the picker launches Claude"
  fi
}

if [ $HOOK = 1 ]; then
  step "Hooking into your shell"
  login=${SHELL##*/}
  ZRC="${ZDOTDIR:-$HOME}/.zshrc"
  do_zsh=0; do_bash=0
  case "$SHELLS" in
    zsh) do_zsh=1 ;; bash) do_bash=1 ;; both) do_zsh=1; do_bash=1 ;;
    auto)
      { [ "$login" = zsh ] || [ -f "$ZRC" ]; } && do_zsh=1
      { [ "$login" = bash ] || [ -f "$HOME/.bashrc" ]; } && do_bash=1 ;;
    *) fail "--shell must be zsh, bash or both"; exit 2 ;;
  esac
  [ "$login" = fish ] && warn "fish isn't supported yet. Hooking into zsh/bash instead — run cproj from one of those."
  [ $do_zsh = 1 ] && add_block "$ZRC"
  if [ $do_bash = 1 ]; then
    add_block "$HOME/.bashrc"
    # macOS terminals start bash as a *login* shell, which reads .bash_profile / .bash_login / .profile, not .bashrc
    if [ $IS_MAC = 1 ] || [ "$login" = bash ]; then
      prof=""
      for f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do [ -f "$f" ] && { prof=$f; break; }; done
      if [ -z "$prof" ]; then [ "$login" = bash ] && prof="$HOME/.bash_profile"; fi
      if [ -n "$prof" ]; then
        if grep -Eq '(\.|source)[[:space:]].*\.bashrc' "$prof"; then note "$(short "$prof") already loads .bashrc"
        else add_block "$prof"; fi
      fi
    fi
  fi
  [ $do_zsh = 0 ] && [ $do_bash = 0 ] && warn "no zsh or bash config found — re-run with --shell=zsh or --shell=bash"
fi

# ------------------------------------------------------------------ setup
if [ $SETUP = 1 ] && [ ! -f "$CONF" ]; then
  step "Choosing your folders"
  if [ $HAVE_TTY = 1 ] && command -v fzf >/dev/null 2>&1; then
    "$CP_HOME/bin/claude-projects" setup || warn "setup didn't finish — run it any time: claude projects setup"
  else
    note "run this when you're ready: claude projects setup"
  fi
fi

# ------------------------------------------------------------------ check
if [ $QUIET = 0 ]; then
  step "Checking the install"
  "$CP_HOME/bin/claude-projects" doctor 2>&1 | sed 's/^/  /' >&2
fi

if [ $QUIET = 0 ]; then
  printf '\n%s✻ Done.%s Open a %snew terminal tab%s, then run:  %sclaude projects%s   (or %scproj%s)\n' "$O$B" "$R" "$B" "$R" "$B" "$R" "$B" "$R" >&2
  printf '  %sProblems? claude projects doctor   ·   Remove: %s/uninstall.sh%s\n\n' "$D" "$(short "$CP_HOME")" "$R" >&2
fi
[ $MISSING_REQ = 1 ] && exit 1
exit 0
