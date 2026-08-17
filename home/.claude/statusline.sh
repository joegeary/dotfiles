#!/usr/bin/env bash
# Claude Code status line. Self-contained: jq + git + coreutils, no node, no
# npm package, no network. Replaces the `ccstatusline` dependency while keeping
# its exact rendering, so the line looks identical to what it replaced.
#
# Layout (two lines, both edge-to-edge via a flexible gap):
#
#   Model: Opus 4.5 | ⎇ main | (+22,-200)        cwd: /home/joe/dotfiles
#   Ctx: 107.0k | Ctx Used: 10.7%              Session: 3.0% | Weekly: 66.0%
#
#   line 1: model name, git branch, git insertions/deletions <gap> working dir
#   line 2: context tokens, context window used <gap> 5h plan use, weekly plan use
#
# Everything comes from the JSON payload Claude Code writes to stdin, except the
# git segments which shell out to git. Plan usage is read from `rate_limits`,
# which is the true server-side number, so there is nothing to estimate and
# nothing to fetch.
#
# ---- rendering contract (why the odd details matter) ------------------------
# Reproduced deliberately; changing any of these visibly changes the line:
#   * Colors are the 256-color palette, emitted as ESC[38;5;Nm ... ESC[39m.
#     The model segment is intentionally uncolored so it inherits the theme.
#   * Separators are " | ". A separator is emitted only when the nearest
#     preceding segment actually produced content, so a missing segment never
#     leaves a dangling bar. Separators trailing at the end of a line are
#     dropped entirely.
#   * The gap is padded to the real terminal width. Claude Code collapses runs
#     of ordinary spaces, so every space in the output (padding included) is
#     written as U+00A0 NO-BREAK SPACE. This is the reason the right-hand
#     segments stay pinned to the right edge.
#   * Each line is prefixed with ESC[0m to reset whatever styling preceded it.
#   * Usable width is the terminal width minus 6, tightening to minus 40 once
#     context passes SL_COMPACT_THRESHOLD, leaving room for the compact-warning
#     text Claude Code prints alongside the status line.
#   * A line whose segments are all empty is suppressed rather than printed blank.
#
# Widths are counted in codepoints, not bytes, so the "⎇" glyph and non-ASCII
# paths line up. Double-width CJK is counted as one column, same edge case the
# previous implementation had.

LC_ALL=C
export LC_ALL

# ---- tunables ---------------------------------------------------------------
SL_COMPACT_THRESHOLD="${SL_COMPACT_THRESHOLD:-60}"  # context % that tightens the width
SL_WIDTH="${SL_WIDTH:-}"                            # force a width (testing)

# 256-color palette, matched to the previous configuration.
C_MODEL="-"      # no color: inherit the terminal theme
C_BRANCH=140     # bright magenta
C_CHANGES=178    # yellow
C_CWD=59         # bright black
C_CTXLEN=111     # bright blue
C_CTXPCT=80      # bright cyan
C_SESSION=140    # bright magenta
C_WEEKLY=178     # yellow

input=$(cat)

# ---- payload -> fields ------------------------------------------------------
# One jq pass does all the numeric work, because the token/percentage
# derivations are fiddly and jq has real floats. Fields are joined by US
# (0x1f) and read with IFS=$'\x1f'. NOT tab: tab is IFS-whitespace, so `read`
# would collapse empty fields and misalign everything after a missing value.
#
# Context length prefers the live per-request usage: input + cache-creation +
# cache-read tokens, which is what actually occupies the window (output tokens
# do not). It falls back to deriving tokens from used_percentage when only the
# percentage is reported.
IFS=$'\x1f' read -r model cwd gitcwd ctxlen_raw ctxpct_raw s5_raw s7_raw < <(printf '%s' "$input" | jq -r '
  # Numeric strings are coerced, matching the payload schema.
  def fin: if type == "string" then (tonumber? // null) else . end
           | if type == "number" and (isnan | not) and (isinfinite | not) then . else null end;
  # Context-window fields reject negatives outright; rate-limit fields do not,
  # they only clamp. That asymmetry is intentional and load-bearing.
  def n: fin | if . != null and . >= 0 then . else null end;
  def clampp: if . == null then null elif . < 0 then 0 elif . > 100 then 100 else . end;

  (.context_window // null)                                       as $cw
  | ($cw.context_window_size | n)                                 as $wraw
  | (if $wraw != null and $wraw > 0 then $wraw else null end)      as $win
  | ($cw.current_usage)                                           as $cu
  | ($cu | type)                                                  as $cut
  | (if $cut == "number" then ($cu | n)
     elif $cut == "object" then
       (($cu.input_tokens | n) // 0) + (($cu.output_tokens | n) // 0)
       + (($cu.cache_creation_input_tokens | n) // 0) + (($cu.cache_read_input_tokens | n) // 0)
     else null end)                                               as $cutotal
  | (if $cut == "number" then ($cu | n)
     elif $cut == "object" then
       (($cu.input_tokens | n) // 0)
       + (($cu.cache_creation_input_tokens | n) // 0) + (($cu.cache_read_input_tokens | n) // 0)
     else null end)                                               as $ctxlen0
  | ($cw.used_percentage | n)                                     as $rawpct
  | (if $rawpct != null and $win != null then $rawpct / 100 * $win else null end) as $pcttok
  | ($cutotal // $pcttok)                                         as $usedtok
  | (if $rawpct != null then ($rawpct | clampp)
     elif $usedtok != null and $win != null and $win > 0 then (($usedtok / $win * 100) | clampp)
     else null end)                                               as $usedpct
  | ($ctxlen0 // $usedtok)                                        as $ctxlen

  | (.model | if type == "string" then . elif type == "object" then (.display_name // .id) else null end) as $m
  | (.rate_limits.five_hour.used_percentage | fin | clampp)       as $s5
  | (.rate_limits.seven_day.used_percentage | fin | clampp)       as $s7

  | [ ($m // "" | sub("[[:space:]]*\\(.*\\)$"; "")),
      (.cwd // ""),
      (.cwd // .workspace.current_dir // .workspace.project_dir // ""),
      ($ctxlen // "" | tostring),
      ($usedpct // "" | tostring),
      ($s5 // "" | tostring),
      ($s7 // "" | tostring)
    ] | join("")' 2>/dev/null)

# Formatting happens here rather than in jq because it has to reproduce
# JavaScript's toFixed(1): a tie rounds away from zero, where C's printf rounds
# it to even. A tie only occurs when the value is exactly representable at two
# decimals (50.25 is, 50.55 is not), so those are detected and nudged.
IFS=$'\x1f' read -r ctxtok ctxpct sess week < <(
  SL_TOK="$ctxlen_raw" SL_CTX="$ctxpct_raw" SL_S5="$s5_raw" SL_S7="$s7_raw" awk '
    function fixed1(x,   s) {
        s = sprintf("%.20f", x); sub(/^-?[0-9]*\./, "", s)
        if (substr(s, 2, 1) == "5" && substr(s, 3) ~ /^0*$/) x += (x < 0 ? -1e-9 : 1e-9)
        return sprintf("%.1f", x)
    }
    function ftok(n) {
        if (n >= 1000000) return fixed1(n / 1000000) "M"
        if (n >= 1000)    return fixed1(n / 1000) "k"
        if (n == int(n))  return sprintf("%d", n)
        return sprintf("%.15g", n)
    }
    function pct(v) { return v == "" ? "" : fixed1(v + 0) }
    BEGIN {
        printf "%s\037%s\037%s\037%s",
            (ENVIRON["SL_TOK"] == "" ? "" : ftok(ENVIRON["SL_TOK"] + 0)),
            pct(ENVIRON["SL_CTX"]), pct(ENVIRON["SL_S5"]), pct(ENVIRON["SL_S7"])
    }')

# ---- git --------------------------------------------------------------------
# Runs against the directory from the payload, falling back to wherever the
# script was invoked when the payload names none. Three cheap plumbing calls per
# render: status-line renders are event-driven, so there is nothing to cache.
G=(git); [ -n "$gitcwd" ] && G=(git -C "$gitcwd")

if [ "$("${G[@]}" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; then
    # Staged and unstaged are summed. Untracked files are not counted, because
    # --shortstat does not see them.
    changes=$( { "${G[@]}" diff --shortstat 2>/dev/null
                 "${G[@]}" diff --cached --shortstat 2>/dev/null; } | awk '
        match($0, /[0-9]+ insertion/) { i += substr($0, RSTART, RLENGTH - 10) }
        match($0, /[0-9]+ deletion/)  { d += substr($0, RSTART, RLENGTH - 9) }
        END { printf "(+%d,-%d)", i + 0, d + 0 }')
    # A detached HEAD has no symbolic ref, and reads as "no git" here.
    branch=$("${G[@]}" symbolic-ref --short HEAD 2>/dev/null)
    [ -z "$branch" ] && branch="no git"
else
    # Outside a work tree both segments still render, so the line does not
    # silently change shape when you cd somewhere untracked.
    branch="no git"
    changes="(no git)"
fi

# ---- terminal width ---------------------------------------------------------
# The status line runs with its stdout piped, so the tty has to be found by
# walking up the process tree to the first ancestor that owns one.
term_width() {
    if [ -n "$SL_WIDTH" ]; then printf '%s' "$SL_WIDTH"; return; fi
    local pid=$$ depth parent tty w
    for depth in 1 2 3 4 5 6 7 8; do
        parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')
        case "$parent" in ''|*[!0-9]*) break ;; esac
        pid=$parent
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d '[:space:]')
        case "$tty" in ''|'?'|'??') continue ;; esac
        w=$(stty -F "/dev/$tty" size 2>/dev/null | awk '{ print $2 }')
        case "$w" in ''|*[!0-9]*|0) ;; *) printf '%s' "$w"; return ;; esac
    done
    w=$(tput cols 2>/dev/null)
    case "$w" in ''|*[!0-9]*|0) ;; *) printf '%s' "$w" ;; esac
}

detected=$(term_width)
width=""
if [ -n "$detected" ]; then
    # Tighten once context crosses the threshold so the compact warning fits.
    if [ -n "$ctxpct_raw" ] && awk -v p="$ctxpct_raw" -v t="$SL_COMPACT_THRESHOLD" 'BEGIN { exit !(p >= t) }'; then
        width=$(( detected - 40 ))
    else
        width=$(( detected - 6 ))
    fi
    # Deliberately not clamped. A width of exactly 0 means "no width to lay out
    # against", so the gap falls back to a dim separator, while a negative width
    # still lays out but yields no padding. Both fall out of a very narrow
    # terminal, and both match what this replaced.
fi

# ---- element buffer ---------------------------------------------------------
# One line is described by three parallel arrays before layout. Kinds:
#   w  widget that produced content     w0 widget that produced nothing
#   s  separator slot                   f  flexible gap
K=(); T=(); L=()
buf_reset() { K=(); T=(); L=(); }

# Codepoint width of plain text. ASCII takes the fast path; anything else is
# counted by stripping UTF-8 continuation bytes.
vwidth() {
    case "$1" in
        *[!\ -~]*) printf '%s' "$1" | tr -d '\200-\277' | wc -c | tr -d '[:space:]' ;;
        *) printf '%s' "${#1}" ;;
    esac
}

# widget <plain-text> <color256|-> [visible-width]
widget() {
    local plain=$1 col=$2 vis=${3:-}
    if [ -z "$plain" ]; then K+=(w0); T+=(""); L+=(0); return; fi
    [ -z "$vis" ] && vis=$(vwidth "$plain")
    K+=(w); L+=("$vis")
    if [ "$col" = - ]; then T+=("$plain"); else T+=($'\e[38;5;'"$col"'m'"$plain"$'\e[39m'); fi
}
sep()  { K+=(s); T+=(""); L+=(0); }
flex() { K+=(f); T+=(""); L+=(0); }

# Lay the buffer out and print it, or print nothing when it holds no content.
render_line() {
    local -a fk=() ft=() fl=()   # kind (w/s/f), text, visible width
    local i j n=${#K[@]} had

    for (( i = 0; i < n; i++ )); do
        case ${K[i]} in
            w)  fk+=(w); ft+=("${T[i]}"); fl+=("${L[i]}") ;;
            w0) : ;;
            f)  fk+=(f); ft+=(""); fl+=(0) ;;
            s)  # only after a segment that actually rendered something
                had=0
                for (( j = i - 1; j >= 0; j-- )); do
                    case ${K[j]} in
                        s|f) continue ;;
                        w)   had=1; break ;;
                        w0)  had=0; break ;;
                    esac
                done
                if [ "$had" = 1 ]; then fk+=(s); ft+=(" | "); fl+=(3); fi
                ;;
        esac
    done

    [ ${#fk[@]} -eq 0 ] && return
    # Trailing separators are dropped; a trailing gap is kept so the last
    # segment stays right-aligned.
    while [ ${#fk[@]} -gt 0 ] && [ "${fk[${#fk[@]}-1]}" = s ]; do
        unset "fk[${#fk[@]}-1]" "ft[${#ft[@]}-1]" "fl[${#fl[@]}-1]"
    done
    [ ${#fk[@]} -eq 0 ] && return

    local out="" content=0 flexcount=0 filled=0
    for (( i = 0; i < ${#fk[@]}; i++ )); do
        case ${fk[i]} in
            f) flexcount=$(( flexcount + 1 )) ;;
            w) filled=1; content=$(( content + fl[i] )) ;;
            *) content=$(( content + fl[i] )) ;;
        esac
    done
    # Nothing rendered means no line at all, rather than a line of padding.
    [ "$filled" = 0 ] && return

    if [ "$flexcount" -gt 0 ] && [ -n "$width" ] && [ "$width" -ne 0 ]; then
        local space=$(( width - content )); [ "$space" -lt 0 ] && space=0
        local per=$(( space / flexcount )) extra=$(( space % flexcount )) seen=0 pad spaces
        for (( i = 0; i < ${#fk[@]}; i++ )); do
            if [ "${fk[i]}" = f ]; then
                pad=$per; [ "$seen" -lt "$extra" ] && pad=$(( per + 1 ))
                seen=$(( seen + 1 ))
                printf -v spaces '%*s' "$pad" ''
                out+="$spaces"
            else
                out+="${ft[i]}"
            fi
        done
    else
        # No width to fill against: a gap degrades to a dim separator.
        for (( i = 0; i < ${#fk[@]}; i++ )); do
            if [ "${fk[i]}" = f ]; then out+=$'\e[90m | \e[39m'
            else out+="${ft[i]}"; fi
        done
    fi

    # Content wider than the terminal is cut and marked with "...". Trailing
    # color codes are left open exactly as they were, matching the previous
    # behavior; the ESC[0m at the start of each line cleans up after them.
    if [ -n "$width" ] && [ "$width" -gt 0 ]; then
        out=$(SL_TEXT="$out" SL_MAX="$width" awk '
            BEGIN {
                for (k = 128; k <= 191; k++) CONT[sprintf("%c", k)] = 1  # UTF-8 continuation bytes
                t = ENVIRON["SL_TEXT"]; max = ENVIRON["SL_MAX"] + 0; n = length(t)
                if (max <= 0) exit
                # Pass one: visible width, ignoring escape sequences.
                vis = 0; i = 1
                while (i <= n) {
                    c = substr(t, i, 1)
                    if (c == "\033") { i = esc(t, i, n); continue }
                    if (!(c in CONT)) vis++
                    i++
                }
                if (vis <= max) { printf "%s", t; exit }
                if (max <= 3) { while (max-- > 0) printf "."; exit }
                # Pass two: copy up to max-3 visible columns, then ellipsis.
                target = max - 3; w = 0; i = 1
                while (i <= n) {
                    c = substr(t, i, 1)
                    if (c == "\033") { j = esc(t, i, n); printf "%s", substr(t, i, j - i); i = j; continue }
                    if (!(c in CONT)) { if (w >= target) break; w++ }
                    printf "%s", c; i++
                }
                printf "..."
            }
            # Length of the CSI sequence starting at i, so it is copied whole.
            function esc(t, i, n,   j) {
                j = i + 1
                if (substr(t, j, 1) != "[") return i + 1
                for (j++; j <= n; j++) if (substr(t, j, 1) ~ /[@-~]/) return j + 1
                return j
            }')
    fi

    # Claude Code collapses runs of ordinary spaces, which would undo the
    # padding, so every space is written as U+00A0 (UTF-8 \xc2\xa0).
    printf '\e[0m%s\n' "${out// /$'\xc2\xa0'}"
}

# ---- line 1: model, branch, changes <gap> working directory -----------------
buf_reset
widget "${model:+Model: $model}" "$C_MODEL"
sep
# "⎇ " is two columns; passed explicitly so the width never depends on locale.
widget "${branch:+⎇ $branch}" "$C_BRANCH" "${branch:+$(( 2 + ${#branch} ))}"
sep
widget "$changes" "$C_CHANGES"
flex
widget "${cwd:+cwd: $cwd}" "$C_CWD"
render_line

# ---- line 2: context <gap> plan usage --------------------------------------
buf_reset
widget "${ctxtok:+Ctx: $ctxtok}" "$C_CTXLEN"
sep
widget "${ctxpct:+Ctx Used: $ctxpct%}" "$C_CTXPCT"
flex
widget "${sess:+Session: $sess%}" "$C_SESSION"
sep
widget "${week:+Weekly: $week%}" "$C_WEEKLY"
render_line
