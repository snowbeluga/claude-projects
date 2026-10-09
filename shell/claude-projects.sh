# claude-projects shell integration — works in zsh and bash.
# install.sh adds one line to your rc file that sources this. Don't paste it in by hand.
#
#   cproj                  open the picker (always available)
#   cproj new [name]       start a new project
#   claude projects        same thing, if CP_WRAP_CLAUDE=yes (the default)
#   claude <anything else> goes straight to Claude Code, untouched

# Only zsh and bash are supported; quietly do nothing in sh/dash (e.g. if sourced from ~/.profile).
[ -n "${BASH_VERSION:-}${ZSH_VERSION:-}" ] || return 0 2>/dev/null

CP_HOME="${CP_HOME:-$HOME/.local/share/claude-projects}"
_CP_BIN="$CP_HOME/bin/claude-projects"
_CP_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/claude-projects/config"

# Read only the two settings the wrapper needs, in a subshell so nothing else leaks.
_CP_WRAP=yes
_CP_WORDS=projects
if [ -f "$_CP_CONF" ]; then
  _CP_WRAP=$( . "$_CP_CONF" >/dev/null 2>&1; printf '%s' "${CP_WRAP_CLAUDE:-yes}" )
  _CP_WORDS=$( . "$_CP_CONF" >/dev/null 2>&1; printf '%s' "${CP_WORDS:-projects}" )
fi

# If you already have `alias claude=...` (e.g. extra flags), remember it so launches keep
# those flags. It has to be removed before defining a claude() function, or zsh/bash would
# expand the alias inside the function definition.
_CP_ALIAS="${_CP_ALIAS:-}"   # kept if this file is sourced again
if _cp_a=$(alias claude 2>/dev/null) && [ -n "$_cp_a" ]; then
  _cp_a=${_cp_a#alias }
  _cp_a=${_cp_a#claude=}
  eval "_CP_ALIAS=$_cp_a" 2>/dev/null || _CP_ALIAS=""
  _CP_ALIAS=${_CP_ALIAS#noglob }
  [ "$_CP_WRAP" = yes ] && unalias claude 2>/dev/null
fi
unset _cp_a

_cp_claude() {
  if [ -n "$_CP_ALIAS" ]; then
    case "$_CP_ALIAS" in
      claude|claude\ *) eval "command $_CP_ALIAS \"\$@\"" ;;
      *)                eval "$_CP_ALIAS \"\$@\"" ;;
    esac
  else
    command claude "$@"
  fi
}

# $1 = what the picker printed: "key \t dir" or, for a new project, "new \t dir \t first-prompt".
# The rest of the arguments go to Claude.
_cp_launch() {
  local out=$1 key dir rest prompt=""
  shift
  key=${out%%$'\t'*}
  rest=${out#*$'\t'}
  dir=${rest%%$'\t'*}
  [ "$rest" != "$dir" ] && prompt=${rest#*$'\t'}
  [ -d "$dir" ] || { echo "claude-projects: folder not found: $dir" >&2; return 1; }
  cd "$dir" || return
  case "$key" in
    ctrl-o) _cp_claude -c "$@" ;;        # continue the last session
    ctrl-r) _cp_claude --resume "$@" ;;  # choose a past session
    ctrl-g) ;;                           # just cd
    new)    if [ -n "$prompt" ]; then _cp_claude "$@" "$prompt"; else _cp_claude "$@"; fi ;;  # new project
    *)      _cp_claude "$@" ;;           # fresh session
  esac
}

_cp_pick() {
  local out
  [ -x "$_CP_BIN" ] || { echo "claude-projects: not installed at $CP_HOME (re-run install.sh)" >&2; return 2; }
  out=$("$_CP_BIN") || return $?
  _cp_launch "$out" "$@"
}

# claude projects new [name] [--prompt …]: create it, then open Claude there
_cp_new() {
  local out
  out=$("$_CP_BIN" new --for-shell "$@") || return $?
  _cp_launch "$out"
}

_cp_dispatch() {
  case "${1:-}" in
    setup|doctor|update|help|--help|-h|version|--version|list|ignore|unignore|ignored|install-shell|uninstall-shell) "$_CP_BIN" "$@" ;;
    new) shift; _cp_new "$@" ;;
    *) _cp_pick "$@" ;;
  esac
}

# `function name {` rather than `name() {`: zsh expands an existing alias in `name()` while
# parsing, even inside a branch that never runs (e.g. CP_WRAP_CLAUDE=no plus alias claude=...).
function cproj { _cp_dispatch "$@"; }

if [ "$_CP_WRAP" = yes ]; then
  function claude {
    if [ -n "${1:-}" ] && case " $_CP_WORDS " in *" $1 "*) true ;; *) false ;; esac; then
      shift
      _cp_dispatch "$@"
    else
      _cp_claude "$@"
    fi
  }
fi

export CP_WRAPPER_LOADED=1
