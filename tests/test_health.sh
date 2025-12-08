#!/bin/bash
# Test: Service health checks
# These tests verify that containers start and become healthy

QUADLET_DIR="${PROJECT_ROOT}/quadlet"
TIMEOUT_SECONDS="${HEALTH_TIMEOUT:-60}"

# =============================================================================
# HELPER: Wait for container to be healthy
# =============================================================================

wait_for_healthy() {
    local container_name="$1"
    local timeout="$2"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        local health
        health=$(podman inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "not_found")

        case "$health" in
            healthy)
                return 0
                ;;
            unhealthy)
                return 1
                ;;
            not_found)
                # Container doesn't exist yet
                ;;
            *)
                # starting or no healthcheck
                ;;
        esac

        sleep 2
        ((elapsed+=2))
    done

    return 1
}

# =============================================================================
# HELPER: Check if container is running
# =============================================================================

container_is_running() {
    local container_name="$1"
    local state
    state=$(podman inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")
    [[ "$state" == "running" ]]
}

# =============================================================================
# TEST: RVPS container starts and is healthy
# =============================================================================

test_rvps_starts() {
    if ! command -v podman &> /dev/null; then
        tap_skip "RVPS container starts" "podman not available"
        return
    fi

    if container_is_running "trustee-rvps"; then
        tap_ok "RVPS container starts" "Container is running"
    else
        tap_not_ok "RVPS container starts" "Container not running"
    fi
}

test_rvps_healthy() {
    if ! command -v podman &> /dev/null; then
        tap_skip "RVPS container is healthy" "podman not available"
        return
    fi

    if ! container_is_running "trustee-rvps"; then
        tap_not_ok "RVPS container is healthy" "Container not running"
        return
    fi

    if wait_for_healthy "trustee-rvps" "${TIMEOUT_SECONDS}"; then
        tap_ok "RVPS container is healthy"
    else
        tap_not_ok "RVPS container is healthy" "Health check failed or timed out"
    fi
}

test_rvps_port_listening() {
    if ! command -v podman &> /dev/null; then
        tap_skip "RVPS port 50003 is listening" "podman not available"
        return
    fi

    if ! container_is_running "trustee-rvps"; then
        tap_not_ok "RVPS port 50003 is listening" "Container not running"
        return
    fi

    # Check if the port is listening inside the container
    if podman exec trustee-rvps sh -c 'ss -tlnp | grep -q 50003' 2>/dev/null; then
        tap_ok "RVPS port 50003 is listening"
    else
        tap_not_ok "RVPS port 50003 is listening" "Port not bound"
    fi
}

# =============================================================================
# TEST: AS container starts and is healthy
# =============================================================================

test_as_starts() {
    if ! command -v podman &> /dev/null; then
        tap_skip "AS container starts" "podman not available"
        return
    fi

    if container_is_running "trustee-as"; then
        tap_ok "AS container starts" "Container is running"
    else
        tap_not_ok "AS container starts" "Container not running"
    fi
}

test_as_healthy() {
    if ! command -v podman &> /dev/null; then
        tap_skip "AS container is healthy" "podman not available"
        return
    fi

    if ! container_is_running "trustee-as"; then
        tap_not_ok "AS container is healthy" "Container not running"
        return
    fi

    if wait_for_healthy "trustee-as" "${TIMEOUT_SECONDS}"; then
        tap_ok "AS container is healthy"
    else
        tap_not_ok "AS container is healthy" "Health check failed or timed out"
    fi
}

test_as_port_listening() {
    if ! command -v podman &> /dev/null; then
        tap_skip "AS port 50004 is listening" "podman not available"
        return
    fi

    if ! container_is_running "trustee-as"; then
        tap_not_ok "AS port 50004 is listening" "Container not running"
        return
    fi

    if podman exec trustee-as sh -c 'ss -tlnp | grep -q 50004' 2>/dev/null; then
        tap_ok "AS port 50004 is listening"
    else
        tap_not_ok "AS port 50004 is listening" "Port not bound"
    fi
}

# =============================================================================
# TEST: KBS container starts and is healthy
# =============================================================================

test_kbs_starts() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS container starts" "podman not available"
        return
    fi

    if container_is_running "trustee-kbs"; then
        tap_ok "KBS container starts" "Container is running"
    else
        tap_not_ok "KBS container starts" "Container not running"
    fi
}

test_kbs_healthy() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS container is healthy" "podman not available"
        return
    fi

    if ! container_is_running "trustee-kbs"; then
        tap_not_ok "KBS container is healthy" "Container not running"
        return
    fi

    if wait_for_healthy "trustee-kbs" "${TIMEOUT_SECONDS}"; then
        tap_ok "KBS container is healthy"
    else
        tap_not_ok "KBS container is healthy" "Health check failed or timed out"
    fi
}

test_kbs_port_listening() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS port 8080 is listening" "podman not available"
        return
    fi

    if ! container_is_running "trustee-kbs"; then
        tap_not_ok "KBS port 8080 is listening" "Container not running"
        return
    fi

    if podman exec trustee-kbs sh -c 'ss -tlnp | grep -q 8080' 2>/dev/null; then
        tap_ok "KBS port 8080 is listening"
    else
        tap_not_ok "KBS port 8080 is listening" "Port not bound"
    fi
}

test_kbs_http_responds() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS HTTP endpoint responds" "podman not available"
        return
    fi

    if ! container_is_running "trustee-kbs"; then
        tap_not_ok "KBS HTTP endpoint responds" "Container not running"
        return
    fi

    # Try to curl the KBS endpoint
    local response
    if response=$(curl -sf http://localhost:8080/ 2>&1); then
        tap_ok "KBS HTTP endpoint responds"
    elif response=$(curl -sf http://localhost:8080/kbs/v0/attestation-policy 2>&1); then
        tap_ok "KBS HTTP endpoint responds" "Got response from attestation-policy endpoint"
    else
        # Even a 4xx response means the server is up
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null || echo "000")
        if [[ "$http_code" != "000" ]]; then
            tap_ok "KBS HTTP endpoint responds" "HTTP $http_code"
        else
            tap_not_ok "KBS HTTP endpoint responds" "No response from HTTP endpoint"
        fi
    fi
}

# =============================================================================
# RUN ALL HEALTH TESTS
# =============================================================================

echo "# Health check tests"

# RVPS tests (should start first, no dependencies)
test_rvps_starts
test_rvps_healthy
test_rvps_port_listening

# AS tests (depends on RVPS)
test_as_starts
test_as_healthy
test_as_port_listening

# KBS tests (depends on AS)
test_kbs_starts
test_kbs_healthy
test_kbs_port_listening
test_kbs_http_responds
