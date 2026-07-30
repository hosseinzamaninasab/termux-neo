#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-documentation-$$"

mkdir -p "$fixture"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

required_public_paths=(
    README.md
    LICENSE
    docs/architecture.md
    docs/beta-field-report.md
    docs/beta-issues.md
    docs/beta-testing.md
    docs/changelog.md
    docs/cli.md
    docs/compatibility.md
    docs/configuration.md
    docs/contributing.md
    docs/development.md
    docs/diagnostics.md
    docs/feature-freeze.md
    docs/installation.md
    docs/known-limitations.md
    docs/performance-baseline.md
    docs/performance.md
    docs/project-overview.md
    docs/quality.md
    docs/release-artifacts.md
    docs/releases/0.9.0-beta.md
    docs/releases/1.0.0-rc.1.md
    docs/releases/1.0.0.md
    docs/security-policy.md
    docs/security.md
    docs/settings-schema-v1.md
    docs/themes.md
    docs/troubleshooting.md
    docs/uninstallation.md
    docs/update.md
    docs/versioning.md
    docs/assets/dashboard-matrix.svg
    docs/assets/dashboard-neo.svg
)

cd "$PROJECT_ROOT"

for public_path in "${required_public_paths[@]}"; do
    [[ -f "$public_path" && ! -L "$public_path" && -s "$public_path" ]] ||
        fail "public documentation path is unavailable: $public_path"
    [[ "$(stat -c '%a' "$public_path")" == "644" ]] ||
        fail "public documentation mode is not 644: $public_path"
done

[[ "$(cat VERSION)" == "1.0.0" ]] ||
    fail "documentation does not target the stable release"
grep -Fq 'Current stable release: `1.0.0`' README.md ||
    fail "README version checkpoint is missing"
grep -Fq '[Feature Freeze](docs/feature-freeze.md)' README.md ||
    fail "README freeze statement is missing"

license_hash="$(sha256sum LICENSE)"
license_hash="${license_hash%% *}"
[[ "$license_hash" == \
   "f19ae8588b10c72dbc3e80eb3d5e18957612efbbb3a9d339a86f4e71d67baaf6" ]] ||
    fail "LICENSE does not match the approved MIT text and owner notice"
grep -Fqx 'MIT License' LICENSE ||
    fail "MIT license heading is missing"
grep -Fqx 'Copyright (c) 2026 Hossein Zamaninasab' LICENSE ||
    fail "MIT owner notice is missing"

readme_targets=(
    docs/project-overview.md
    docs/compatibility.md
    docs/installation.md
    docs/update.md
    docs/uninstallation.md
    docs/configuration.md
    docs/settings-schema-v1.md
    docs/themes.md
    docs/cli.md
    docs/diagnostics.md
    docs/troubleshooting.md
    docs/architecture.md
    docs/development.md
    docs/contributing.md
    docs/security-policy.md
    docs/security.md
    docs/known-limitations.md
    docs/changelog.md
    docs/versioning.md
    docs/releases/1.0.0.md
    docs/release-artifacts.md
    docs/quality.md
    docs/performance.md
    docs/performance-baseline.md
    docs/beta-testing.md
    docs/beta-field-report.md
    docs/beta-issues.md
    docs/feature-freeze.md
    docs/assets/dashboard-matrix.svg
    docs/assets/dashboard-neo.svg
    LICENSE
)
for readme_target in "${readme_targets[@]}"; do
    grep -Fq "($readme_target)" README.md ||
        fail "README does not link: $readme_target"
done

markdown_files="$fixture/markdown-files.list"
{
    printf '%s\n' README.md
    find docs -type f -name '*.md' -print
} | LC_ALL=C sort > "$markdown_files"

while IFS= read -r markdown_file; do
    markdown_links="$fixture/markdown-links.list"
    : > "$markdown_links"
    grep -Eo '\]\([^()[:space:]]+\)' "$markdown_file" \
        > "$markdown_links" || true
    while IFS= read -r markdown_link; do
        target="${markdown_link#](}"
        target="${target%)}"
        target="${target%%#*}"
        case "$target" in
            ""|http://*|https://*|mailto:*) continue ;;
            /*) fail "absolute local Markdown link: $markdown_file -> $target" ;;
        esac
        [[ -e "$(dirname "$markdown_file")/$target" ]] ||
            fail "broken Markdown link: $markdown_file -> $target"
    done < "$markdown_links"
done < "$markdown_files"

help_output="$(bash src/main.sh --help)" ||
    fail "released CLI help could not be read"
documented_options="$(
    printf '%s\n' "$help_output" |
        sed -n 's/^  \(--[a-z-]*\).*/\1/p' |
        LC_ALL=C sort
)"
expected_options="$(
    printf '%s\n' \
        --config \
        --diagnose \
        --help \
        --no-color \
        --startup \
        --theme \
        --version |
        LC_ALL=C sort
)"
[[ "$documented_options" == "$expected_options" ]] ||
    fail "released CLI option set is inconsistent"
while IFS= read -r cli_option; do
    grep -Fq "\`termux-neo $cli_option" docs/cli.md ||
        fail "CLI reference is missing: $cli_option"
done <<< "$expected_options"

settings_keys="$(
    sed -n 's/^\([a-z_][a-z_]*\)=.*/\1/p' \
        config/settings.example.conf |
        LC_ALL=C sort
)"
expected_settings_keys="$(
    printf '%s\n' \
        color_mode \
        display_user \
        schema_version \
        startup_integration \
        theme |
        LC_ALL=C sort
)"
[[ "$settings_keys" == "$expected_settings_keys" ]] ||
    fail "settings example key set is inconsistent"
while IFS= read -r settings_key; do
    grep -Fq "\`$settings_key\`" docs/configuration.md ||
        fail "configuration reference is missing: $settings_key"
done <<< "$expected_settings_keys"

diagnostic_fields=(
    VERSION
    INSTALLATION_PATH
    CONFIG_PATH
    CONFIG_STATUS
    SCHEMA_STATUS
    TERMINAL_WIDTH
    THEME
    COLOR_MODE
    "OPTIONAL_COMMAND ip"
    "OPTIONAL_COMMAND ifconfig"
    "OPTIONAL_COMMAND termux-battery-status"
    "OPTIONAL_COMMAND dumpsys"
    "OPTIONAL_COMMAND getprop"
    NETWORK_SOURCE
    BATTERY_SOURCE
    DISPLAY_USER
    SYSTEM_USER
    DEVICE
    SYSTEM
    NETWORK_TYPE
    NETWORK_STATE
    LOCAL_IP
    VPN_STATE
    BATTERY
    TIME
)
for diagnostic_field in "${diagnostic_fields[@]}"; do
    grep -Fq "\`$diagnostic_field\`" docs/diagnostics.md ||
        fail "diagnostics reference is missing: $diagnostic_field"
done

grep -Fq 'Samsung Galaxy Note5, model `SM-N920C`' docs/compatibility.md ||
    fail "reference device evidence is missing"
grep -Fq 'Portrait `56`, landscape `94`' docs/compatibility.md ||
    fail "physical orientation evidence is missing"
grep -Fq 'No distribution-specific claim' docs/compatibility.md ||
    fail "Termux distribution boundary is missing"
grep -Fq 'no additional device was available' docs/compatibility.md ||
    fail "single-device evidence boundary is missing"
grep -Fq 'not additional device evidence' README.md ||
    fail "README screenshot evidence boundary is missing"
grep -Fq 'No runtime, CLI surface, settings, theme,' \
    docs/changelog.md ||
    fail "stable changelog boundary is missing"
grep -Fq '`VERSION` file is the only committed' docs/versioning.md ||
    fail "version source ownership is undocumented"
grep -Fqx 'Release version: `1.0.0`' \
    docs/releases/1.0.0.md ||
    fail "release-note version metadata is missing"
grep -Fqx 'Prospective tag: `v1.0.0`' \
    docs/releases/1.0.0.md ||
    fail "release-note tag metadata is missing"
grep -Fqx \
    'Publication status: stable public release; GitHub release.' \
    docs/releases/1.0.0.md ||
    fail "release-note publication boundary is missing"
grep -Fqx \
    'Publication status: release candidate; GitHub prerelease only.' \
    docs/releases/1.0.0-rc.1.md ||
    fail "historical release-candidate publication boundary changed"
grep -Fqx \
    'Publication status: checkpoint only; no Git tag or public release.' \
    docs/releases/0.9.0-beta.md ||
    fail "historical beta publication boundary changed"
grep -Fq \
    'github.com/hosseinzamaninasab/termux-neo/releases/download/v1.0.0' \
    README.md ||
    fail "README stable public download URL is missing"
grep -Fq \
    'github.com/hosseinzamaninasab/termux-neo/releases/tag/v1.0.0' \
    docs/installation.md ||
    fail "stable public release page is undocumented"

render_output="$(
    bash -s -- "$PROJECT_ROOT" "$fixture" <<'RENDER'
set -Eeuo pipefail

project_root="$1"
fixture_home="$2"

export HOME="$fixture_home"
export TERMUX_NEO_CONFIG_PATH="$project_root/config/settings.conf"
export TERMUX_NEO_USER=Zoro
export NO_COLOR=1

source "$project_root/src/main.sh"

tput() {
    case "${1-}" in
        cols) printf '56' ;;
        colors) printf '0' ;;
        *) return 1 ;;
    esac
}

module_device_user() { printf 'u0_a191'; }
module_device_name() { printf 'samsung SM-N920C'; }
module_system_name() { printf 'Android 11'; }
module_network_prepare_render_cache() { :; }
module_battery_prepare_render_cache() { :; }
module_network_type() { printf 'Wi-Fi'; }
module_network_local_ip() { printf '192.0.2.10'; }
module_network_state() { printf 'UP'; }
module_vpn_state() { printf 'OFF'; }
module_battery_value() { printf '82+'; }
module_time_value() { printf '21:35'; }

PWD="$HOME/Projects/termux-neo"
TERMUX_NEO_CLI_THEME_OVERRIDE=neo
TERMUX_NEO_CLI_COLOR_MODE_OVERRIDE=never
termux_neo_render_once
RENDER
)" || fail "documentation renderer fixture failed"

[[ "$(printf '%s\n' "$render_output" | wc -l)" == "16" ]] ||
    fail "documentation renderer transcript is incomplete"
[[ "$render_output" == *"samsung SM-N920C"* &&
   "$render_output" == *"192.0.2.10"* &&
   "$render_output" == *"NET:UP • VPN:OFF • BAT:82+ • TIME:21:35"* &&
   "$render_output" == *"╭─ Zoro • ~/Projects/termux-neo"* ]] ||
    fail "documentation renderer transcript changed"

render_hash="$(printf '%s\n' "$render_output" | sha256sum)"
render_hash="${render_hash%% *}"
[[ "$render_hash" == \
   "69af0ee570715a8de24b93f508b3809e5c445d9616254d3094f4c0d79eb44fb2" ]] ||
    fail "documentation renderer fixture hash changed"

for theme in neo matrix; do
    asset="docs/assets/dashboard-$theme.svg"
    asset_transcript="$(
        sed -n \
            '/<g xml:space="preserve">/,/<\/g>/ {
                s/^[[:space:]]*<text[^>]*>\(.*\)<\/text>$/\1/p
            }' "$asset" |
            sed 's/<[^>]*>//g'
    )"
    [[ "$asset_transcript" == "$render_output" ]] ||
        fail "SVG visible transcript differs from the renderer: $asset"
    grep -Fq "data-render-version=\"0.9.0-beta\"" "$asset" ||
        fail "SVG version provenance is missing: $asset"
    grep -Fq "data-render-width=\"56\"" "$asset" ||
        fail "SVG width provenance is missing: $asset"
    grep -Fq "data-render-theme=\"$theme\"" "$asset" ||
        fail "SVG theme provenance is missing: $asset"
    grep -Fq "data-render-sha256=\"$render_hash\"" "$asset" ||
        fail "SVG transcript provenance is stale: $asset"
    grep -Fq '<svg xmlns="http://www.w3.org/2000/svg"' "$asset" ||
        fail "SVG root is missing: $asset"
    grep -Fq '</svg>' "$asset" ||
        fail "SVG close tag is missing: $asset"
    grep -Fq 'TERMUX NEO' "$asset" ||
        fail "SVG title text is missing: $asset"
    grep -Fq 'samsung SM-N920C' "$asset" ||
        fail "SVG device row is missing: $asset"
    grep -Fq '192.0.2.10' "$asset" ||
        fail "SVG documentation address is missing: $asset"
    if grep -Eqi '<script|javascript:|(xlink:)?href="https?://' "$asset"; then
        fail "SVG contains active or external content: $asset"
    fi
done

printf 'PASS: public documentation set and renderer-derived assets\n'
