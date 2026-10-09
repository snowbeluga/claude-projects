#!/usr/bin/env bash
# uninstall.sh — remove claude-projects.
#   ./uninstall.sh           remove the shell hook, the command link and the installed files (keeps your config)
#   ./uninstall.sh --purge   also delete your config
#   ./uninstall.sh --yes     don't ask

YES=0; PURGE=0
for a in "$@"; do
  case "$a" in
    -y|--yes) YES=1 ;; --purge) PURGE=1 ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

CP_HOME="${CP_HOME:-$HOME/.local/share/claude-projects}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-projects"
LINK="$HOME/.local/bin/claude-projects"
MARK_START="# >>> claude-projects >>>"
MARK_END="# <<< claude-projects <<<"
short() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
ok() { printf '  ✓ %s\n' "$*" >&2; }

if [ $YES = 0 ]; then
  if ( : </dev/tty ) 2>/dev/null; then
    printf 'Remove claude-projects%s? [y/N] ' "$([ $PURGE = 1 ] && echo ' and your config')" >&2
    IFS= read -r r </dev/tty; case "$r" in [Yy]*) ;; *) echo "Nothing changed." >&2; exit 0 ;; esac
  else echo "Run with --yes to uninstall without a terminal." >&2; exit 1; fi
fi

for rc in "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  [ -f "$rc" ] && grep -qF "$MARK_START" "$rc" || continue
  cp "$rc" "$rc.claude-projects.bak"
  tmp=$(mktemp "${TMPDIR:-/tmp}/cp-rc.XXXXXX")
  awk -v s="$MARK_START" -v e="$MARK_END" '$0==s{skip=1; next} skip&&$0==e{skip=0; next} !skip' "$rc" > "$tmp" && cat "$tmp" > "$rc"
  rm -f "$tmp"
  ok "removed the hook from $(short "$rc")  (backup: $(short "$rc").claude-projects.bak)"
done

if [ -L "$LINK" ]; then rm -f "$LINK" && ok "removed $(short "$LINK")"; fi

if [ -d "$CP_HOME" ]; then
  if [ -d "$CP_HOME/.git" ] && [ -n "$(git -C "$CP_HOME" status --porcelain 2>/dev/null)" ]; then
    printf '  ! %s has local changes — left it in place. Delete it yourself if you are sure.\n' "$(short "$CP_HOME")" >&2
  else
    rm -rf "$CP_HOME" && ok "removed $(short "$CP_HOME")"
  fi
fi

if [ $PURGE = 1 ]; then rm -rf "$CONF_DIR" && ok "removed $(short "$CONF_DIR")"
elif [ -d "$CONF_DIR" ]; then printf '  · kept your config in %s (use --purge to delete it)\n' "$(short "$CONF_DIR")" >&2; fi

printf '\nDone. Open a new terminal tab — or in this one run:  unset -f claude cproj 2>/dev/null\n' >&2
