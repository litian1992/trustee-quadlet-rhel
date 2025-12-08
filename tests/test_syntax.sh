#!/bin/bash
# Test: Quadlet file syntax validation
# These tests verify that all Quadlet files exist and have valid syntax

QUADLET_DIR="${PROJECT_ROOT}/quadlet"

# =============================================================================
# TEST: Required Quadlet files exist
# =============================================================================

test_network_file_exists() {
    local file="${QUADLET_DIR}/trustee.network"
    if [[ -f "$file" ]]; then
        tap_ok "Network file exists" "$file"
    else
        tap_not_ok "Network file exists" "Missing: $file"
    fi
}

test_kbs_container_file_exists() {
    local file="${QUADLET_DIR}/trustee-kbs.container"
    if [[ -f "$file" ]]; then
        tap_ok "KBS container file exists" "$file"
    else
        tap_not_ok "KBS container file exists" "Missing: $file"
    fi
}

test_as_container_file_exists() {
    local file="${QUADLET_DIR}/trustee-as.container"
    if [[ -f "$file" ]]; then
        tap_ok "AS container file exists" "$file"
    else
        tap_not_ok "AS container file exists" "Missing: $file"
    fi
}

test_rvps_container_file_exists() {
    local file="${QUADLET_DIR}/trustee-rvps.container"
    if [[ -f "$file" ]]; then
        tap_ok "RVPS container file exists" "$file"
    else
        tap_not_ok "RVPS container file exists" "Missing: $file"
    fi
}

test_volume_files_exist() {
    local volumes=("kbs-config.volume" "kbs-data.volume" "as-config.volume" "rvps-config.volume" "rvps-data.volume")
    local all_exist=true

    for vol in "${volumes[@]}"; do
        if [[ ! -f "${QUADLET_DIR}/${vol}" ]]; then
            all_exist=false
            break
        fi
    done

    if $all_exist; then
        tap_ok "All volume files exist" "${volumes[*]}"
    else
        tap_not_ok "All volume files exist" "Missing one or more volume files"
    fi
}

# =============================================================================
# TEST: Quadlet files have required sections
# =============================================================================

test_container_has_unit_section() {
    local file="$1"
    local name="$2"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "${name} has [Unit] section" "File does not exist"
        return
    fi

    if grep -q '^\[Unit\]' "$file"; then
        tap_ok "${name} has [Unit] section"
    else
        tap_not_ok "${name} has [Unit] section" "Missing [Unit] section in $file"
    fi
}

test_container_has_container_section() {
    local file="$1"
    local name="$2"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "${name} has [Container] section" "File does not exist"
        return
    fi

    if grep -q '^\[Container\]' "$file"; then
        tap_ok "${name} has [Container] section"
    else
        tap_not_ok "${name} has [Container] section" "Missing [Container] section in $file"
    fi
}

test_container_has_service_section() {
    local file="$1"
    local name="$2"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "${name} has [Service] section" "File does not exist"
        return
    fi

    if grep -q '^\[Service\]' "$file"; then
        tap_ok "${name} has [Service] section"
    else
        tap_not_ok "${name} has [Service] section" "Missing [Service] section in $file"
    fi
}

test_container_has_install_section() {
    local file="$1"
    local name="$2"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "${name} has [Install] section" "File does not exist"
        return
    fi

    if grep -q '^\[Install\]' "$file"; then
        tap_ok "${name} has [Install] section"
    else
        tap_not_ok "${name} has [Install] section" "Missing [Install] section in $file"
    fi
}

# =============================================================================
# TEST: Container files have required fields
# =============================================================================

test_container_has_image() {
    local file="$1"
    local name="$2"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "${name} has Image field" "File does not exist"
        return
    fi

    if grep -q '^Image=' "$file"; then
        tap_ok "${name} has Image field"
    else
        tap_not_ok "${name} has Image field" "Missing Image= in $file"
    fi
}

test_container_has_network() {
    local file="$1"
    local name="$2"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "${name} has Network field" "File does not exist"
        return
    fi

    if grep -q '^Network=' "$file"; then
        tap_ok "${name} has Network field"
    else
        tap_not_ok "${name} has Network field" "Missing Network= in $file"
    fi
}

# =============================================================================
# TEST: Network file has required fields
# =============================================================================

test_network_has_subnet() {
    local file="${QUADLET_DIR}/trustee.network"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "Network has Subnet field" "File does not exist"
        return
    fi

    if grep -q '^Subnet=' "$file"; then
        tap_ok "Network has Subnet field"
    else
        tap_not_ok "Network has Subnet field" "Missing Subnet= in $file"
    fi
}

# =============================================================================
# TEST: Service dependencies are correct
# =============================================================================

test_kbs_depends_on_as() {
    local file="${QUADLET_DIR}/trustee-kbs.container"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "KBS depends on AS" "File does not exist"
        return
    fi

    if grep -q 'trustee-as' "$file"; then
        tap_ok "KBS depends on AS"
    else
        tap_not_ok "KBS depends on AS" "KBS should depend on trustee-as service"
    fi
}

test_as_depends_on_rvps() {
    local file="${QUADLET_DIR}/trustee-as.container"

    if [[ ! -f "$file" ]]; then
        tap_not_ok "AS depends on RVPS" "File does not exist"
        return
    fi

    if grep -q 'trustee-rvps' "$file"; then
        tap_ok "AS depends on RVPS"
    else
        tap_not_ok "AS depends on RVPS" "AS should depend on trustee-rvps service"
    fi
}

# =============================================================================
# RUN ALL SYNTAX TESTS
# =============================================================================

echo "# Syntax validation tests"

# File existence tests
test_network_file_exists
test_kbs_container_file_exists
test_as_container_file_exists
test_rvps_container_file_exists
test_volume_files_exist

# Section tests for each container
for container in "trustee-kbs" "trustee-as" "trustee-rvps"; do
    file="${QUADLET_DIR}/${container}.container"
    test_container_has_unit_section "$file" "$container"
    test_container_has_container_section "$file" "$container"
    test_container_has_service_section "$file" "$container"
    test_container_has_install_section "$file" "$container"
done

# Required field tests
for container in "trustee-kbs" "trustee-as" "trustee-rvps"; do
    file="${QUADLET_DIR}/${container}.container"
    test_container_has_image "$file" "$container"
    test_container_has_network "$file" "$container"
done

# Network tests
test_network_has_subnet

# Dependency tests
test_kbs_depends_on_as
test_as_depends_on_rvps
