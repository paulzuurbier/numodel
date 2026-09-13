#!/bin/bash
# siunitx-matrix.sh -- render the axis-label harness against several
# siunitx versions and diff the results.
#
#   ./siunitx-matrix.sh v3.3.8 v3.5.10 v3.6.0
#   ./siunitx-matrix.sh bad7d1f378          # a commit works too
#
# Each argument is a git ref of josephwright/siunitx.  For each one the
# script downloads the source archive from GitHub, generates
# siunitx.sty with `tex siunitx.ins`, compiles siunitx-matrix.tex with
# TEXINPUTS pointing at that siunitx first, and extracts the rendered
# labels with pdftotext.  The reference is the same harness compiled
# against the siunitx installed in the TeX distribution.  Every version
# must render every label identically; anything else is printed as a
# diff and makes the script exit non-zero.
#
# Why this exists: numodel-plot drives siunitx through its code-level
# interface and, for the scale-format=prefix feasibility check, through
# a few internals behind \cs_if_exist guards.  A renamed internal does
# not error -- the guard shuts and the label silently comes out in the
# 10^k form -- so the only way to know a siunitx release is fine is to
# render against it.  l3build check cannot do this: it always uses the
# installed siunitx.  See CHANGELOG.md, 0.9.1 and 0.9.2.
#
# Needs: bash, curl, unzip, tex, pdflatex, pdftotext.  Downloads and
# builds land in tests/build/, which git ignores.
#
# numodel-plot.sty is taken from ../numodel-plot.sty, regenerated from
# the .dtx first if missing or older than it.

set -u
here=$(cd "$(dirname "$0")" && pwd)
module=$(cd "$here/.." && pwd)
work="$here/build"
harness="siunitx-matrix"
mkdir -p "$work"

# --- numodel-plot.sty -------------------------------------------------
if [ ! -f "$module/numodel-plot.sty" ] \
   || [ "$module/numodel-plot.dtx" -nt "$module/numodel-plot.sty" ]; then
  echo "regenerating numodel-plot.sty from the .dtx"
  (cd "$module" && tex numodel-plot.ins </dev/null >/dev/null 2>&1) \
    || { echo "could not run numodel-plot.ins" >&2; exit 2; }
fi

# --- one render -------------------------------------------------------
# render <label> <siunitx-dir|installed>  -> writes $work/<label>.txt
render() {
  local label="$1" siu="$2"
  local dir="$work/run-$label"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$here/$harness.tex" "$module/numodel-plot.sty" "$dir/"
  (
    cd "$dir" || exit 1
    if [ "$siu" != "installed" ]; then
      # Git Bash rewrites POSIX paths in the environment; hand TeX a
      # native path and switch the rewriting off for this call.
      if command -v cygpath >/dev/null 2>&1; then siu=$(cygpath -w "$siu"); fi
      export MSYS_NO_PATHCONV=1
      export TEXINPUTS="$siu;"
    fi
    pdflatex -interaction=nonstopmode "$harness.tex" </dev/null >/dev/null 2>&1
  )
  local loaded errors
  loaded=$(grep -o "Package: siunitx [0-9-]* v[0-9.]*" "$dir/$harness.log" | head -1)
  errors=$(grep -c '^!' "$dir/$harness.log")
  printf '%-14s %-36s errors: %s\n' "$label" "${loaded:-siunitx NOT FOUND}" "$errors"
  pdftotext -nopgbrk "$dir/$harness.pdf" - 2>/dev/null \
    | sed 's/ \(Q\|LBL\)\[/\n\1[/g' | grep '^LBL\|^Q' > "$work/$label.txt"
  [ "$errors" -eq 0 ]
}

# --- fetch + build one siunitx ref --------------------------------------
# siunitx_for <ref> -> prints the directory holding its siunitx.sty
siunitx_for() {
  local ref="$1"
  local zip="$work/siunitx-$ref.zip" dir
  if [ ! -f "$zip" ]; then
    curl -sSL -o "$zip" "https://github.com/josephwright/siunitx/archive/$ref.zip" \
      || { echo "download of $ref failed" >&2; return 1; }
  fi
  dir="$work/$(unzip -Z1 "$zip" | head -1 | cut -d/ -f1)"
  [ -d "$dir" ] || unzip -q -o "$zip" -d "$work"
  if [ ! -f "$dir/siunitx.sty" ]; then
    (cd "$dir" && tex siunitx.ins </dev/null >/dev/null 2>&1) \
      || { echo "siunitx.ins failed for $ref" >&2; return 1; }
  fi
  echo "$dir"
}

# --- main ---------------------------------------------------------------
status=0
render installed installed || status=1
for ref in "$@"; do
  dir=$(siunitx_for "$ref") || { status=1; continue; }
  render "$ref" "$dir" || status=1
  if diff "$work/installed.txt" "$work/$ref.txt" > "$work/$ref.diff"; then
    printf '%-14s identical to installed\n' "$ref"
  else
    printf '%-14s DIFFERS from installed:\n' "$ref"
    sed 's/^/    /' "$work/$ref.diff"
    status=1
  fi
done
exit $status
