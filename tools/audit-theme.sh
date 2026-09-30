#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

failures=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
}

ok() {
    printf 'OK: %s\n' "$*"
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "missing command: $1"
        return 1
    fi
}

require_command jq || true
require_command xmllint || true

if command -v jq >/dev/null 2>&1; then
    while IFS= read -r -d '' json_file; do
        jq empty "$json_file" || fail "invalid JSON: ${json_file#$repo_root/}"
    done < <(find "$repo_root" -name metadata.json -print0)
    ok "metadata.json files are valid JSON"
fi

if command -v xmllint >/dev/null 2>&1; then
    svg_count=0
    while IFS= read -r -d '' svg_file; do
        svg_count=$((svg_count + 1))
        xmllint --noout "$svg_file" || fail "invalid SVG XML: ${svg_file#$repo_root/}"
    done < <(find "$repo_root" -name '*.svg' -print0)
    ok "$svg_count SVG files are valid XML"

    svgz_count=0
    while IFS= read -r -d '' svgz_file; do
        svgz_count=$((svgz_count + 1))
        gzip -cd "$svgz_file" | xmllint --noout - || fail "invalid SVGZ XML: ${svgz_file#$repo_root/}"
    done < <(find "$repo_root" -name '*.svgz' -print0)
    ok "$svgz_count SVGZ files are valid compressed XML"
fi

while IFS= read -r -d '' svg_file; do
    mapfile -t missing_ids < <(
        perl -0ne '
            my %ids = map { $_ => 1 } /(?:^|\s)id="([^"]+)"/g;
            my %seen;
            while (/url\(#([^)]+)\)/g) {
                next if $seen{$1}++;
                print "$1\n" unless exists $ids{$1};
            }
        ' "$svg_file"
    )
    if ((${#missing_ids[@]})); then
        fail "broken url(#id) references in ${svg_file#$repo_root/}: ${missing_ids[*]}"
    fi
done < <(find "$repo_root" -name '*.svg' -print0)
ok "SVG url(#id) references resolve locally"

plasma_style="$repo_root/Blur-Glassy"
global_theme="$repo_root/Global Themes/Blur-Glassy-Light-Global-6"
aurorae_root="$repo_root/Windows Decorations For Plasma 6"

[[ -f "$plasma_style/metadata.json" ]] || fail "missing Plasma Style metadata.json"
[[ -f "$plasma_style/plasmarc" ]] || fail "missing Plasma Style plasmarc"
[[ ! -f "$plasma_style/metadata.desktop" ]] || fail "legacy Plasma Style metadata.desktop remains"

[[ -f "$global_theme/metadata.json" ]] || fail "missing Global Theme metadata.json"
[[ -f "$global_theme/contents/defaults" ]] || fail "missing Global Theme defaults"

theme_name="$(awk -F= '/^\[plasmarc\]\[Theme\]/{seen=1; next} seen && /^name=/{print $2; exit}' "$global_theme/contents/defaults")"
[[ "$theme_name" == "Blur-Glassy" ]] || fail "Global Theme points to unexpected Plasma Style: ${theme_name:-<empty>}"

aurorae_theme="$(awk -F= '/^theme=__aurorae__svg__/ {sub(/^__aurorae__svg__/, "", $2); print $2; exit}' "$global_theme/contents/defaults")"
[[ -n "$aurorae_theme" ]] || fail "Global Theme has no Aurorae theme reference"
[[ -d "$aurorae_root/$aurorae_theme" ]] || fail "Global Theme Aurorae target is missing: ${aurorae_theme:-<empty>}"

ksplash_theme="$(awk -F= '/^\[KSplash\]/{seen=1; next} seen && /^Theme=/{print $2; exit}' "$global_theme/contents/defaults")"
[[ "$ksplash_theme" == "Blur-Glassy-Light-Global-6" ]] || fail "KSplash points to unexpected package: ${ksplash_theme:-<empty>}"

if rg -n 'QtGraphicalEffects|X-KDE-ServiceTypes=Plasma/LookAndFeel|X-Plasma-API=5.0' "$repo_root/Global Themes" "$repo_root/Windows Decorations For Plasma 6" >/dev/null; then
    fail "legacy Plasma 5-only markers remain in Global Theme or Aurorae metadata"
else
    ok "no legacy Plasma 5-only markers in Global Theme or Aurorae metadata"
fi

if ((failures)); then
    printf '\n%d audit check(s) failed.\n' "$failures" >&2
    exit 1
fi

printf '\nTheme audit passed.\n'
