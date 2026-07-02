#!/usr/bin/env bash
#
# list_issues_mu2e.sh — list open GitHub issues across all Mu2e organisation repositories

set -uo pipefail

SCRIPT_NAME=$(basename "$0")
ORG="mu2e"
SORT_ORDER="newest"
OUTPUT_FORMAT="terminal"
OUTPUT_FILE=""
ISSUE_LIMIT=500
REPO_LIMIT=4000
FILTER_REPO=""
FILTER_LABEL=""
MAX_JOBS=4

usage() {
    cat <<'EOF'
Usage: list_issues_mu2e.sh [OPTIONS]

Fetch and display open GitHub issues across all Mu2e organisation repositories.
Repositories are discovered automatically from GitHub; no local clone required.

OPTIONS
  -s, --sort <order>     Sort by date: newest (default) or oldest
  -o, --output <format>  Output format: terminal (default), html, pdf, browser
  -f, --file <path>      Output file for html/pdf (default: /tmp/mu2e-issues.{html,pdf})
  -r, --repo <name>      Limit to one repository, e.g. Offline or mu2e/Offline
  -l, --label <label>    Filter issues by label
  -j, --jobs <n>         Parallel API fetches (default: 4)
  -h, --help             Print this help and exit

OUTPUT FORMATS
  terminal  Colour-formatted table on stdout (default)
  html      Standalone HTML file with clickable GitHub links
  pdf       PDF with clickable links — requires pandoc+weasyprint or wkhtmltopdf
  browser   Generate HTML and open in the default browser

AUTHENTICATION
  If ~/.credentials/github.token exists it is loaded as GH_TOKEN automatically.
  Otherwise the existing 'gh auth login' session is used.

EXAMPLES
  list_issues_mu2e.sh
  list_issues_mu2e.sh --sort oldest
  list_issues_mu2e.sh --repo Offline --sort newest
  list_issues_mu2e.sh --output html --file ~/mu2e-issues.html
  list_issues_mu2e.sh --output browser
  list_issues_mu2e.sh --label bug --output html
  list_issues_mu2e.sh --output pdf --file ~/mu2e-issues.pdf
EOF
}

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "$*" >&2; }

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--sort)
            SORT_ORDER="${2:?--sort requires an argument}"; shift 2
            [[ "$SORT_ORDER" == "newest" || "$SORT_ORDER" == "oldest" ]] ||
                die "--sort must be 'newest' or 'oldest'"
            ;;
        -o|--output)
            OUTPUT_FORMAT="${2:?--output requires an argument}"; shift 2
            [[ "$OUTPUT_FORMAT" =~ ^(terminal|html|pdf|browser)$ ]] ||
                die "--output must be: terminal, html, pdf, or browser"
            ;;
        -f|--file)
            OUTPUT_FILE="${2:?--file requires an argument}"; shift 2
            ;;
        -r|--repo)
            FILTER_REPO="${2:?--repo requires an argument}"; shift 2
            [[ "$FILTER_REPO" == */* ]] || FILTER_REPO="${ORG}/${FILTER_REPO}"
            ;;
        -l|--label)
            FILTER_LABEL="${2:?--label requires an argument}"; shift 2
            ;;
        -j|--jobs)
            MAX_JOBS="${2:?--jobs requires an argument}"; shift 2
            [[ "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]] || die "--jobs must be a positive integer"
            ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*) die "Unknown option: $1  (run with --help for usage)" ;;
        *)  die "Unexpected argument: $1  (run with --help for usage)" ;;
    esac
done

# ── Prerequisites ─────────────────────────────────────────────────────────────
command -v gh &>/dev/null || die "GitHub CLI (gh) is required but not found in PATH"
command -v jq &>/dev/null || die "jq is required but not found in PATH"

if [[ -f ~/.credentials/github.token ]]; then
    _cand=$(< ~/.credentials/github.token)
    if GH_TOKEN="$_cand" gh api user --silent &>/dev/null 2>&1; then
        export GH_TOKEN="$_cand"
    else
        info "Warning: ~/.credentials/github.token is invalid or expired; falling back to gh keyring auth"
    fi
    unset _cand
fi

gh api user --silent &>/dev/null ||
    die "GitHub authentication failed. Run 'gh auth login' or update ~/.credentials/github.token"

# ── Collect repositories ──────────────────────────────────────────────────────
info "Fetching repository list for ${ORG}..."

REPOS=()
if [[ -n "$FILTER_REPO" ]]; then
    REPOS=("$FILTER_REPO")
else
    while IFS= read -r line; do
        REPOS+=("$line")
    done < <(
        gh repo list "$ORG" --limit "$REPO_LIMIT" \
            --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null
    )
fi

REPO_COUNT="${#REPOS[@]}"
(( REPO_COUNT > 0 )) || die "No repositories found for organisation '${ORG}'"
info "Found ${REPO_COUNT} repositories. Fetching issues (${MAX_JOBS} in parallel)..."

# ── Collect issues in parallel batches ───────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

BATCH=0
for repo in "${REPOS[@]}"; do
    (
        out="$TMP_DIR/$(tr '/' '_' <<< "$repo").jsonl"
        args=(issue list --repo "$repo" --state open
              --limit "$ISSUE_LIMIT"
              --json number,title,createdAt,updatedAt,url,labels,assignees)
        [[ -n "$FILTER_LABEL" ]] && args+=(--label "$FILTER_LABEL")
        issues=$(gh "${args[@]}" 2>/dev/null) || exit 0
        [[ "$issues" == "[]" || -z "$issues" ]] && exit 0
        jq -c --arg r "$repo" '.[] | . + {repo: $r}' <<< "$issues" >> "$out"
    ) &
    BATCH=$(( BATCH + 1 ))
    if (( BATCH >= MAX_JOBS )); then
        wait
        BATCH=0
    fi
done
wait

# Merge per-repo JSONL files
ISSUES_FILE="$TMP_DIR/issues.jsonl"
find "$TMP_DIR" -maxdepth 1 -name '*.jsonl' -exec cat {} + > "$ISSUES_FILE" 2>/dev/null || true

if [[ ! -s "$ISSUES_FILE" ]]; then
    info "No open issues found."
    exit 0
fi

TOTAL_ISSUES=$(wc -l < "$ISSUES_FILE" | tr -d ' ')
info "Found ${TOTAL_ISSUES} open issue(s) across ${REPO_COUNT} repositories."

# Sort globally by createdAt; result is a JSON array
SORTED_JSON=$(
    jq -s --arg order "$SORT_ORDER" '
        if $order == "newest"
        then sort_by(.createdAt) | reverse
        else sort_by(.createdAt)
        end
    ' "$ISSUES_FILE"
)

# ── Terminal renderer (flat chronological list) ───────────────────────────────
render_terminal() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 100)
    local tw=$(( cols - 32 ))
    (( tw < 20 )) && tw=20

    local reset='\033[0m' bold='\033[1m' cyan='\033[36m'
    local yellow='\033[33m' green='\033[32m' dim='\033[2m'

    local prev_repo=""
    while IFS=$'\t' read -r repo number date title url; do
        if [[ "$repo" != "$prev_repo" ]]; then
            printf "\n${bold}${cyan}%s${reset}\n" "── ${repo}"
            printf "${bold}${dim}%-8s  %-12s  %-*s${reset}\n" \
                   "#" "OPENED" "$tw" "TITLE"
            prev_repo="$repo"
        fi
        if (( ${#title} > tw )); then
            title="${title:0:$(( tw - 1 ))}…"
        fi
        printf "${yellow}#%-7s${reset}  ${green}%-12s${reset}  %s\n" \
               "$number" "$date" "$title"
    done < <(
        jq -r '.[] | [.repo,
                       (.number | tostring),
                       (.createdAt | split("T")[0]),
                       .title,
                       .url] | @tsv' <<< "$SORTED_JSON"
    )
    echo
}

# ── HTML renderer (grouped by repo) ──────────────────────────────────────────
render_html() {
    local file="$1"
    local gen_date
    gen_date=$(date -u '+%Y-%m-%d %H:%M UTC')

    # Build HTML rows grouped by repo; jq does all the heavy lifting
    local body
    body=$(jq -r '
        group_by(.repo)[] |
        . as $grp |
        ($grp[0].repo) as $repo |
        (length) as $cnt |
        "<div class=\"rs\">",
        "  <div class=\"rh\">",
        "    <a class=\"rn\" href=\"https://github.com/\($repo)/issues\" target=\"_blank\">\($repo)</a>",
        "    <span class=\"badge\">\($cnt) open</span>",
        "  </div>",
        "  <table>",
        "    <thead><tr><th>#</th><th>Opened</th><th>Title</th><th>Labels</th><th>Assignees</th></tr></thead>",
        "    <tbody>",
        ($grp[] |
            "    <tr>",
            "      <td class=\"num\"><a href=\"\(.url)\" target=\"_blank\">#\(.number)</a></td>",
            "      <td class=\"date\">\(.createdAt | split("T")[0])</td>",
            "      <td><a class=\"tl\" href=\"\(.url)\" target=\"_blank\">\(.title | @html)</a></td>",
            "      <td>\([.labels[] | "<span class=\"lbl\" style=\"background:#\(.color)\">\(.name | @html)</span>"] | join(" "))</td>",
            "      <td class=\"asgn\">\([.assignees[].login] | map("@"+.) | join(", "))</td>",
            "    </tr>"
        ),
        "    </tbody></table>",
        "</div>"
    ' <<< "$SORTED_JSON")

    cat > "$file" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mu2e Open Issues — ${gen_date}</title>
<style>
*{box-sizing:border-box}
body{font-family:system-ui,-apple-system,sans-serif;margin:0;background:#0d1117;color:#c9d1d9}
a{color:inherit}
header{background:#161b22;padding:16px 28px;border-bottom:1px solid #30363d;
  display:flex;align-items:baseline;gap:16px;flex-wrap:wrap}
header h1{margin:0;font-size:1.2rem;color:#f0f6fc;white-space:nowrap}
header p{margin:0;font-size:.8rem;color:#8b949e}
main{padding:20px 28px}
.rs{margin-bottom:26px}
.rh{display:flex;align-items:center;gap:10px;background:#161b22;
  border:1px solid #30363d;border-radius:6px 6px 0 0;padding:9px 14px}
.rn{font-weight:600;font-size:.9rem;color:#58a6ff;text-decoration:none}
.rn:hover{text-decoration:underline}
.badge{background:#21262d;border:1px solid #30363d;border-radius:20px;
  padding:1px 9px;font-size:.72rem;color:#8b949e}
table{width:100%;border-collapse:collapse;border:1px solid #30363d;
  border-top:none;border-radius:0 0 6px 6px;overflow:hidden}
thead tr{background:#161b22}
th{padding:6px 11px;text-align:left;font-size:.75rem;color:#8b949e;
  border-bottom:1px solid #30363d;font-weight:600;white-space:nowrap}
td{padding:6px 11px;border-bottom:1px solid #21262d;font-size:.83rem;vertical-align:top}
tr:last-child td{border-bottom:none}
tbody tr:hover td{background:#161b22}
.num a{color:#8b949e;text-decoration:none;white-space:nowrap;font-size:.78rem}
.num a:hover{color:#58a6ff}
.date{color:#8b949e;white-space:nowrap;font-size:.78rem}
.tl{color:#c9d1d9;text-decoration:none}
.tl:hover{color:#58a6ff;text-decoration:underline}
.lbl{display:inline-block;padding:1px 7px;border-radius:20px;font-size:.7rem;
  font-weight:600;color:#fff;margin:1px 2px}
.asgn{font-size:.78rem;color:#8b949e;white-space:nowrap}
</style>
</head>
<body>
<header>
  <h1>Mu2e Open Issues</h1>
  <p>Generated ${gen_date} &mdash; ${TOTAL_ISSUES} open issue(s) across ${REPO_COUNT} repos &mdash; sorted: ${SORT_ORDER}</p>
</header>
<main>
${body}
</main>
</body>
</html>
HTMLEOF
}

# ── PDF renderer ──────────────────────────────────────────────────────────────
render_pdf() {
    local file="$1"
    local html_tmp="$TMP_DIR/mu2e-issues.html"
    render_html "$html_tmp"

    if command -v pandoc &>/dev/null; then
        if pandoc "$html_tmp" -o "$file" --pdf-engine=weasyprint 2>/dev/null; then
            return 0
        elif pandoc "$html_tmp" -o "$file" --pdf-engine=wkhtmltopdf 2>/dev/null; then
            return 0
        elif pandoc "$html_tmp" -o "$file" 2>/dev/null; then
            return 0
        fi
    fi

    if command -v wkhtmltopdf &>/dev/null; then
        wkhtmltopdf --enable-local-file-access --quiet "$html_tmp" "$file"
        return 0
    fi

    if command -v google-chrome &>/dev/null || command -v chromium-browser &>/dev/null; then
        local browser
        browser=$(command -v google-chrome || command -v chromium-browser)
        "$browser" --headless --disable-gpu \
            --print-to-pdf="$file" "file://${html_tmp}" 2>/dev/null
        return 0
    fi

    die "No PDF engine found. Install one of:
  pandoc + weasyprint : brew install pandoc && pip install weasyprint
  wkhtmltopdf         : brew install wkhtmltopdf
  Chromium/Chrome     : brew install --cask chromium"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$OUTPUT_FORMAT" in
    terminal)
        render_terminal
        ;;
    html)
        dst="${OUTPUT_FILE:-/tmp/mu2e-issues.html}"
        render_html "$dst"
        info "HTML written to: ${dst}"
        ;;
    pdf)
        dst="${OUTPUT_FILE:-/tmp/mu2e-issues.pdf}"
        render_pdf "$dst"
        info "PDF written to: ${dst}"
        ;;
    browser)
        dst="${OUTPUT_FILE:-/tmp/mu2e-issues.html}"
        render_html "$dst"
        if   command -v open     &>/dev/null; then open "$dst"
        elif command -v xdg-open &>/dev/null; then xdg-open "$dst"
        else info "HTML saved to ${dst} — open it in your browser manually"
        fi
        ;;
esac
