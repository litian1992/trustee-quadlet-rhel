#!/bin/bash
# Test: RPM packaging validation
# These tests verify that the RPM spec file is valid and can build

RPM_DIR="${PROJECT_ROOT}/rpm"
SPEC_FILE="${RPM_DIR}/trustee-quadlet.spec"

# =============================================================================
# TEST: RPM spec file exists
# =============================================================================

test_spec_file_exists() {
    if [[ -f "$SPEC_FILE" ]]; then
        tap_ok "RPM spec file exists" "$SPEC_FILE"
    else
        tap_not_ok "RPM spec file exists" "Missing: $SPEC_FILE"
    fi
}

# =============================================================================
# TEST: Spec file has required fields
# =============================================================================

test_spec_has_name() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec has Name field" "Spec file missing"
        return
    fi

    if grep -q '^Name:' "$SPEC_FILE"; then
        tap_ok "Spec has Name field"
    else
        tap_not_ok "Spec has Name field" "Missing Name: directive"
    fi
}

test_spec_has_version() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec has Version field" "Spec file missing"
        return
    fi

    if grep -q '^Version:' "$SPEC_FILE"; then
        tap_ok "Spec has Version field"
    else
        tap_not_ok "Spec has Version field" "Missing Version: directive"
    fi
}

test_spec_has_license() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec has License field" "Spec file missing"
        return
    fi

    if grep -q '^License:' "$SPEC_FILE"; then
        tap_ok "Spec has License field"
    else
        tap_not_ok "Spec has License field" "Missing License: directive"
    fi
}

test_spec_has_requires_podman() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec requires podman" "Spec file missing"
        return
    fi

    if grep -q 'Requires:.*podman' "$SPEC_FILE"; then
        tap_ok "Spec requires podman"
    else
        tap_not_ok "Spec requires podman" "Missing podman dependency"
    fi
}

test_spec_has_requires_systemd() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec requires systemd" "Spec file missing"
        return
    fi

    if grep -q 'Requires:.*systemd' "$SPEC_FILE"; then
        tap_ok "Spec requires systemd"
    else
        tap_not_ok "Spec requires systemd" "Missing systemd dependency"
    fi
}

# =============================================================================
# TEST: Spec file installs Quadlet files to correct location
# =============================================================================

test_spec_installs_to_containers_systemd() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec installs to /etc/containers/systemd" "Spec file missing"
        return
    fi

    if grep -q '%{_sysconfdir}/containers/systemd' "$SPEC_FILE"; then
        tap_ok "Spec installs to /etc/containers/systemd"
    else
        tap_not_ok "Spec installs to /etc/containers/systemd" "Quadlet files should go in /etc/containers/systemd"
    fi
}

test_spec_installs_configs_to_etc_trustee() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec installs configs to /etc/trustee" "Spec file missing"
        return
    fi

    if grep -q '%{_sysconfdir}/trustee' "$SPEC_FILE"; then
        tap_ok "Spec installs configs to /etc/trustee"
    else
        tap_not_ok "Spec installs configs to /etc/trustee" "Config files should go in /etc/trustee"
    fi
}

# =============================================================================
# TEST: Spec file lists all Quadlet files
# =============================================================================

test_spec_includes_kbs_container() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec includes trustee-kbs.container" "Spec file missing"
        return
    fi

    if grep -q 'trustee-kbs.container' "$SPEC_FILE"; then
        tap_ok "Spec includes trustee-kbs.container"
    else
        tap_not_ok "Spec includes trustee-kbs.container" "Missing from %files"
    fi
}

test_spec_includes_as_container() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec includes trustee-as.container" "Spec file missing"
        return
    fi

    if grep -q 'trustee-as.container' "$SPEC_FILE"; then
        tap_ok "Spec includes trustee-as.container"
    else
        tap_not_ok "Spec includes trustee-as.container" "Missing from %files"
    fi
}

test_spec_includes_rvps_container() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec includes trustee-rvps.container" "Spec file missing"
        return
    fi

    if grep -q 'trustee-rvps.container' "$SPEC_FILE"; then
        tap_ok "Spec includes trustee-rvps.container"
    else
        tap_not_ok "Spec includes trustee-rvps.container" "Missing from %files"
    fi
}

test_spec_includes_network() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec includes trustee.network" "Spec file missing"
        return
    fi

    if grep -q 'trustee.network' "$SPEC_FILE"; then
        tap_ok "Spec includes trustee.network"
    else
        tap_not_ok "Spec includes trustee.network" "Missing from %files"
    fi
}

# =============================================================================
# TEST: Spec uses noreplace for config files
# =============================================================================

test_spec_uses_noreplace() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec uses noreplace for configs" "Spec file missing"
        return
    fi

    # Config files should use %config(noreplace) to preserve user changes
    if grep -q '%config(noreplace)' "$SPEC_FILE"; then
        tap_ok "Spec uses noreplace for configs"
    else
        tap_not_ok "Spec uses noreplace for configs" "Should use %config(noreplace) for config files"
    fi
}

# =============================================================================
# TEST: Spec has post-install scriptlet for daemon-reload
# =============================================================================

test_spec_has_post_daemon_reload() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec has post-install daemon-reload" "Spec file missing"
        return
    fi

    if grep -A10 '^%post' "$SPEC_FILE" | grep -q 'daemon-reload'; then
        tap_ok "Spec has post-install daemon-reload"
    else
        tap_not_ok "Spec has post-install daemon-reload" "Should run systemctl daemon-reload in %post"
    fi
}

# =============================================================================
# TEST: Spec conflicts with standalone Trustee RPMs
# =============================================================================

test_spec_conflicts_with_standalone() {
    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Spec conflicts with standalone RPMs" "Spec file missing"
        return
    fi

    if grep -q '^Conflicts:' "$SPEC_FILE"; then
        tap_ok "Spec conflicts with standalone RPMs" "Prevents dual-install confusion"
    else
        tap_not_ok "Spec conflicts with standalone RPMs" "Should conflict with standalone trustee RPMs"
    fi
}

# =============================================================================
# TEST: rpmlint validation (if available)
# =============================================================================

test_rpmlint_passes() {
    if ! command -v rpmlint &> /dev/null; then
        tap_skip "rpmlint validation" "rpmlint not available"
        return
    fi

    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "rpmlint validation" "Spec file missing"
        return
    fi

    local output
    if output=$(rpmlint "$SPEC_FILE" 2>&1); then
        tap_ok "rpmlint validation" "No errors"
    else
        # Check if there are only warnings (no errors)
        if echo "$output" | grep -q ' E: '; then
            tap_not_ok "rpmlint validation" "Has errors: $(echo "$output" | grep ' E: ' | head -1)"
        else
            tap_ok "rpmlint validation" "Warnings only"
        fi
    fi
}

# =============================================================================
# TEST: Can build SRPM (if rpmbuild available)
# =============================================================================

test_can_build_srpm() {
    if ! command -v rpmbuild &> /dev/null; then
        tap_skip "Can build SRPM" "rpmbuild not available"
        return
    fi

    if [[ ! -f "$SPEC_FILE" ]]; then
        tap_not_ok "Can build SRPM" "Spec file missing"
        return
    fi

    # We can't actually build without sources, but we can parse the spec
    local output
    if output=$(rpmbuild --nobuild "$SPEC_FILE" 2>&1); then
        tap_ok "Can build SRPM" "Spec parses correctly"
    else
        tap_not_ok "Can build SRPM" "Parse error: $(echo "$output" | head -1)"
    fi
}

# =============================================================================
# RUN ALL RPM TESTS
# =============================================================================

echo "# RPM packaging tests"

# File existence
test_spec_file_exists

# Required fields
test_spec_has_name
test_spec_has_version
test_spec_has_license
test_spec_has_requires_podman
test_spec_has_requires_systemd

# Installation paths
test_spec_installs_to_containers_systemd
test_spec_installs_configs_to_etc_trustee

# File list
test_spec_includes_kbs_container
test_spec_includes_as_container
test_spec_includes_rvps_container
test_spec_includes_network

# Best practices
test_spec_uses_noreplace
test_spec_has_post_daemon_reload
test_spec_conflicts_with_standalone

# External validation
test_rpmlint_passes
test_can_build_srpm
