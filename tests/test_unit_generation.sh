#!/bin/bash
# Test: Quadlet unit file generation
# These tests verify that Quadlet can generate valid systemd unit files

QUADLET_DIR="${PROJECT_ROOT}/quadlet"
GENERATED_DIR="${PROJECT_ROOT}/.generated-units"

# =============================================================================
# SETUP: Generate units using Quadlet
# =============================================================================

setup_unit_generation() {
    mkdir -p "${GENERATED_DIR}"

    # Check if /usr/libexec/podman/quadlet is available (RHEL/Fedora)
    # or if we can use podman directly
    if command -v /usr/libexec/podman/quadlet &> /dev/null; then
        QUADLET_CMD="/usr/libexec/podman/quadlet"
    elif command -v quadlet &> /dev/null; then
        QUADLET_CMD="quadlet"
    else
        echo "# WARNING: quadlet command not found, using podman systemd generate as fallback"
        QUADLET_CMD=""
    fi
}

# =============================================================================
# TEST: Quadlet can parse container files without errors
# =============================================================================

test_quadlet_parses_container() {
    local container_file="$1"
    local name="$2"

    if [[ ! -f "$container_file" ]]; then
        tap_not_ok "Quadlet parses ${name}" "File does not exist: $container_file"
        return
    fi

    if [[ -z "${QUADLET_CMD}" ]]; then
        tap_skip "Quadlet parses ${name}" "quadlet command not available"
        return
    fi

    # Run quadlet in dryrun mode to check for parse errors
    local output
    if output=$("${QUADLET_CMD}" -dryrun -user "${QUADLET_DIR}" 2>&1); then
        tap_ok "Quadlet parses ${name}"
    else
        tap_not_ok "Quadlet parses ${name}" "Parse error: $output"
    fi
}

# =============================================================================
# TEST: Generated unit files have correct service names
# =============================================================================

test_generated_unit_name() {
    local expected_service="$1"
    local container_file="${QUADLET_DIR}/${expected_service%.service}.container"

    if [[ ! -f "$container_file" ]]; then
        tap_not_ok "Generated unit ${expected_service}" "Source container file does not exist"
        return
    fi

    if [[ -z "${QUADLET_CMD}" ]]; then
        tap_skip "Generated unit ${expected_service}" "quadlet command not available"
        return
    fi

    # Generate units to temp directory
    local temp_dir
    temp_dir=$(mktemp -d)
    "${QUADLET_CMD}" -user "${QUADLET_DIR}" -o "${temp_dir}" 2>/dev/null || true

    if [[ -f "${temp_dir}/${expected_service}" ]]; then
        tap_ok "Generated unit ${expected_service}"
        rm -rf "${temp_dir}"
    else
        tap_not_ok "Generated unit ${expected_service}" "Unit file not generated"
        rm -rf "${temp_dir}"
    fi
}

# =============================================================================
# TEST: Generated units have ExecStart
# =============================================================================

test_generated_unit_has_exec() {
    local service_name="$1"
    local container_file="${QUADLET_DIR}/${service_name%.service}.container"

    if [[ ! -f "$container_file" ]]; then
        tap_not_ok "Generated ${service_name} has ExecStart" "Source file missing"
        return
    fi

    if [[ -z "${QUADLET_CMD}" ]]; then
        tap_skip "Generated ${service_name} has ExecStart" "quadlet command not available"
        return
    fi

    local temp_dir
    temp_dir=$(mktemp -d)
    "${QUADLET_CMD}" -user "${QUADLET_DIR}" -o "${temp_dir}" 2>/dev/null || true

    if [[ -f "${temp_dir}/${service_name}" ]]; then
        if grep -q '^ExecStart=' "${temp_dir}/${service_name}"; then
            tap_ok "Generated ${service_name} has ExecStart"
        else
            tap_not_ok "Generated ${service_name} has ExecStart" "Missing ExecStart directive"
        fi
    else
        tap_not_ok "Generated ${service_name} has ExecStart" "Unit file not generated"
    fi

    rm -rf "${temp_dir}"
}

# =============================================================================
# TEST: Generated units preserve dependencies
# =============================================================================

test_generated_unit_dependencies() {
    local service_name="$1"
    local depends_on="$2"
    local container_file="${QUADLET_DIR}/${service_name%.service}.container"

    if [[ ! -f "$container_file" ]]; then
        tap_not_ok "Generated ${service_name} depends on ${depends_on}" "Source file missing"
        return
    fi

    if [[ -z "${QUADLET_CMD}" ]]; then
        tap_skip "Generated ${service_name} depends on ${depends_on}" "quadlet command not available"
        return
    fi

    local temp_dir
    temp_dir=$(mktemp -d)
    "${QUADLET_CMD}" -user "${QUADLET_DIR}" -o "${temp_dir}" 2>/dev/null || true

    if [[ -f "${temp_dir}/${service_name}" ]]; then
        if grep -qE "(Requires|Wants|After)=.*${depends_on}" "${temp_dir}/${service_name}"; then
            tap_ok "Generated ${service_name} depends on ${depends_on}"
        else
            tap_not_ok "Generated ${service_name} depends on ${depends_on}" "Dependency not found in generated unit"
        fi
    else
        tap_not_ok "Generated ${service_name} depends on ${depends_on}" "Unit file not generated"
    fi

    rm -rf "${temp_dir}"
}

# =============================================================================
# TEST: Network unit is generated correctly
# =============================================================================

test_network_unit_generated() {
    local network_file="${QUADLET_DIR}/trustee.network"

    if [[ ! -f "$network_file" ]]; then
        tap_not_ok "Network unit generated" "Source network file missing"
        return
    fi

    if [[ -z "${QUADLET_CMD}" ]]; then
        tap_skip "Network unit generated" "quadlet command not available"
        return
    fi

    local temp_dir
    temp_dir=$(mktemp -d)
    "${QUADLET_CMD}" -user "${QUADLET_DIR}" -o "${temp_dir}" 2>/dev/null || true

    # Network files generate as trustee-network.service
    if [[ -f "${temp_dir}/trustee-network.service" ]]; then
        tap_ok "Network unit generated" "trustee-network.service"
    else
        tap_not_ok "Network unit generated" "trustee-network.service not found"
    fi

    rm -rf "${temp_dir}"
}

# =============================================================================
# RUN ALL UNIT GENERATION TESTS
# =============================================================================

echo "# Unit generation tests"

setup_unit_generation

# Parse tests
test_quadlet_parses_container "${QUADLET_DIR}/trustee-kbs.container" "KBS"
test_quadlet_parses_container "${QUADLET_DIR}/trustee-as.container" "AS"
test_quadlet_parses_container "${QUADLET_DIR}/trustee-rvps.container" "RVPS"

# Unit name tests
test_generated_unit_name "trustee-kbs.service"
test_generated_unit_name "trustee-as.service"
test_generated_unit_name "trustee-rvps.service"

# ExecStart tests
test_generated_unit_has_exec "trustee-kbs.service"
test_generated_unit_has_exec "trustee-as.service"
test_generated_unit_has_exec "trustee-rvps.service"

# Dependency tests
test_generated_unit_dependencies "trustee-kbs.service" "trustee-as"
test_generated_unit_dependencies "trustee-as.service" "trustee-rvps"

# Network test
test_network_unit_generated

# Cleanup
rm -rf "${GENERATED_DIR}"
