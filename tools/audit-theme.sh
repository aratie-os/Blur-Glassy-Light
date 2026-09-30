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

ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"

    awk -F= -v section="[$section]" -v key="$key" '
        $0 == section { inside = 1; next }
        /^\[/ { inside = 0 }
        inside && $1 == key { sub(/^[^=]*=/, ""); print; exit }
    ' "$file"
}

if command -v jq >/dev/null 2>&1; then
    while IFS= read -r -d '' json_file; do
        jq empty "$json_file" || fail "invalid JSON: ${json_file#$repo_root/}"
    done < <(find "$repo_root" -name metadata.json -print0)
    ok "metadata.json files are valid JSON"

    mapfile -t duplicate_ids < <(
        find "$repo_root" -name metadata.json -print0 \
            | xargs -0 -r jq -r '.KPlugin.Id // empty' \
            | sort \
            | uniq -d
    )
    if ((${#duplicate_ids[@]})); then
        fail "duplicate KPlugin IDs: ${duplicate_ids[*]}"
    else
        ok "KPlugin IDs are unique"
    fi
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

while IFS= read -r -d '' svgz_file; do
    mapfile -t missing_ids < <(
        gzip -cd "$svgz_file" | perl -0ne '
            my %ids = map { $_ => 1 } /(?:^|\s)id="([^"]+)"/g;
            my %seen;
            while (/url\(#([^)]+)\)/g) {
                next if $seen{$1}++;
                print "$1\n" unless exists $ids{$1};
            }
        '
    )
    if ((${#missing_ids[@]})); then
        fail "broken url(#id) references in ${svgz_file#$repo_root/}: ${missing_ids[*]}"
    fi
done < <(find "$repo_root" -name '*.svgz' -print0)
ok "SVGZ url(#id) references resolve locally"

light_style="$repo_root/Blur-Glassy"
dark_style="$repo_root/Blur-Glassy-Dark"
dark_color_scheme="$repo_root/Color Schemes/BlurGlassyDark.colors"
light_global_theme="$repo_root/Global Themes/Blur-Glassy-Light-Global-6"
dark_global_theme="$repo_root/Global Themes/Blur-Glassy-Dark-Global-6"
aurorae_root="$repo_root/Windows Decorations For Plasma 6"
dark_aurorae="$aurorae_root/Blur-Glassy-Dark-Aurorae-6"

for style in "$light_style" "$dark_style"; do
    [[ -f "$style/metadata.json" ]] || fail "missing Plasma Style metadata.json: ${style#$repo_root/}"
    [[ -f "$style/plasmarc" ]] || fail "missing Plasma Style plasmarc: ${style#$repo_root/}"
    [[ -f "$style/colors" ]] || fail "missing Plasma Style colors: ${style#$repo_root/}"
    [[ ! -f "$style/metadata.desktop" ]] || fail "legacy Plasma Style metadata.desktop remains: ${style#$repo_root/}"
done

if command -v jq >/dev/null 2>&1; then
    [[ "$(jq -r '.KPlugin.Id' "$light_style/metadata.json")" == "Blur-Glassy" ]] || fail "unexpected Light Plasma Style ID"
    [[ "$(jq -r '.KPlugin.Id' "$dark_style/metadata.json")" == "Blur-Glassy-Dark" ]] || fail "unexpected Dark Plasma Style ID"
fi

if rg -n '^FallbackTheme=' "$dark_style/plasmarc" >/dev/null; then
    fail "Dark Plasma Style unexpectedly depends on a fallback theme"
else
    ok "Dark Plasma Style is self-contained"
fi

light_svg_count="$(find "$light_style" -name '*.svg' -type f | wc -l)"
dark_svg_count="$(find "$dark_style" -name '*.svg' -type f | wc -l)"
[[ "$light_svg_count" == "$dark_svg_count" ]] || fail "Light/Dark SVG counts differ: $light_svg_count/$dark_svg_count"

while IFS= read -r -d '' light_svg; do
    relative_path="${light_svg#$light_style/}"
    [[ -f "$dark_style/$relative_path" ]] || fail "Dark Plasma Style is missing asset: $relative_path"
done < <(find "$light_style" -name '*.svg' -type f -print0)
ok "Light and Dark Plasma Styles expose the same SVG asset paths"

[[ -f "$dark_color_scheme" ]] || fail "missing Dark Color Scheme"
[[ "$(ini_value "$dark_color_scheme" General ColorScheme)" == "BlurGlassyDark" ]] || fail "unexpected Dark Color Scheme ID"

if ! diff -u \
    <(sed 's/^ColorScheme=Blur-Glassy-Dark$/ColorScheme=BlurGlassyDark/' "$dark_style/colors") \
    "$dark_color_scheme" >/dev/null; then
    fail "Dark Plasma Style palette and installable Color Scheme diverge"
else
    ok "Dark Plasma Style and installable Color Scheme palettes match"
fi

for global_theme in "$light_global_theme" "$dark_global_theme"; do
    [[ -f "$global_theme/metadata.json" ]] || fail "missing Global Theme metadata.json: ${global_theme#$repo_root/}"
    [[ -f "$global_theme/contents/defaults" ]] || fail "missing Global Theme defaults: ${global_theme#$repo_root/}"
done

check_global_theme() {
    local package="$1"
    local expected_style="$2"
    local expected_color_scheme="$3"
    local expected_aurorae="$4"
    local defaults="$package/contents/defaults"
    local package_id
    local theme_name
    local color_scheme
    local aurorae_theme
    local ksplash_theme

    if command -v jq >/dev/null 2>&1; then
        package_id="$(jq -r '.KPlugin.Id' "$package/metadata.json")"
    else
        package_id="$(basename "$package")"
    fi
    theme_name="$(ini_value "$defaults" 'plasmarc][Theme' name)"
    color_scheme="$(ini_value "$defaults" 'kdeglobals][General' ColorScheme)"
    aurorae_theme="$(ini_value "$defaults" 'kwinrc][org.kde.kdecoration2' theme)"
    aurorae_theme="${aurorae_theme#__aurorae__svg__}"
    ksplash_theme="$(ini_value "$defaults" KSplash Theme)"

    [[ "$theme_name" == "$expected_style" ]] || fail "$package_id points to unexpected Plasma Style: ${theme_name:-<empty>}"
    [[ "$color_scheme" == "$expected_color_scheme" ]] || fail "$package_id points to unexpected Color Scheme: ${color_scheme:-<empty>}"
    [[ "$aurorae_theme" == "$expected_aurorae" ]] || fail "$package_id points to unexpected Aurorae theme: ${aurorae_theme:-<empty>}"
    [[ -d "$aurorae_root/$aurorae_theme" ]] || fail "$package_id Aurorae target is missing: ${aurorae_theme:-<empty>}"
    [[ "$ksplash_theme" == "$package_id" ]] || fail "$package_id KSplash points to unexpected package: ${ksplash_theme:-<empty>}"
}

check_global_theme "$light_global_theme" Blur-Glassy BlurGlassy Blur-Glassy-Solid-Aurorae-6
check_global_theme "$dark_global_theme" Blur-Glassy-Dark BlurGlassyDark Blur-Glassy-Dark-Aurorae-6

[[ -d "$dark_aurorae" ]] || fail "missing Dark Aurorae package"
[[ -f "$dark_aurorae/Blur-Glassy-Dark-Aurorae-6rc" ]] || fail "missing Dark Aurorae configuration"

[[ "$(ini_value "$dark_global_theme/contents/defaults" 'kdeglobals][Icons' Theme)" == "breeze-dark" ]] || fail "Dark Global Theme does not use breeze-dark icons"
if rg -n '^\[Wallpaper\]' "$dark_global_theme/contents/defaults" >/dev/null; then
    fail "Dark Global Theme unexpectedly overrides the user wallpaper"
else
    ok "Dark Global Theme preserves the user wallpaper"
fi

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
