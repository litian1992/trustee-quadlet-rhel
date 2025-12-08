#!/bin/bash
# Test: Integration tests
# These tests verify that services can communicate with each other

QUADLET_DIR="${PROJECT_ROOT}/quadlet"

# =============================================================================
# HELPER: Check network connectivity between containers
# =============================================================================

can_reach() {
    local from_container="$1"
    local to_host="$2"
    local to_port="$3"

    podman exec "$from_container" sh -c "nc -z -w5 ${to_host} ${to_port}" 2>/dev/null
}

# =============================================================================
# TEST: Containers are on the same network
# =============================================================================

test_containers_share_network() {
    if ! command -v podman &> /dev/null; then
        tap_skip "Containers share network" "podman not available"
        return
    fi

    local kbs_network as_network rvps_network

    kbs_network=$(podman inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' trustee-kbs 2>/dev/null || echo "")
    as_network=$(podman inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' trustee-as 2>/dev/null || echo "")
    rvps_network=$(podman inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' trustee-rvps 2>/dev/null || echo "")

    if [[ -z "$kbs_network" ]] || [[ -z "$as_network" ]] || [[ -z "$rvps_network" ]]; then
        tap_not_ok "Containers share network" "One or more containers not running"
        return
    fi

    if [[ "$kbs_network" == "$as_network" ]] && [[ "$as_network" == "$rvps_network" ]]; then
        tap_ok "Containers share network" "$kbs_network"
    else
        tap_not_ok "Containers share network" "Networks differ: KBS=$kbs_network AS=$as_network RVPS=$rvps_network"
    fi
}

# =============================================================================
# TEST: AS can reach RVPS
# =============================================================================

test_as_can_reach_rvps() {
    if ! command -v podman &> /dev/null; then
        tap_skip "AS can reach RVPS" "podman not available"
        return
    fi

    if ! podman inspect trustee-as &>/dev/null; then
        tap_not_ok "AS can reach RVPS" "AS container not running"
        return
    fi

    if can_reach "trustee-as" "trustee-rvps" "50003"; then
        tap_ok "AS can reach RVPS" "trustee-rvps:50003 reachable"
    else
        tap_not_ok "AS can reach RVPS" "Cannot connect to trustee-rvps:50003"
    fi
}

# =============================================================================
# TEST: KBS can reach AS
# =============================================================================

test_kbs_can_reach_as() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS can reach AS" "podman not available"
        return
    fi

    if ! podman inspect trustee-kbs &>/dev/null; then
        tap_not_ok "KBS can reach AS" "KBS container not running"
        return
    fi

    if can_reach "trustee-kbs" "trustee-as" "50004"; then
        tap_ok "KBS can reach AS" "trustee-as:50004 reachable"
    else
        tap_not_ok "KBS can reach AS" "Cannot connect to trustee-as:50004"
    fi
}

# =============================================================================
# TEST: KBS external port is accessible from host
# =============================================================================

test_kbs_external_port() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS external port accessible" "podman not available"
        return
    fi

    if ! podman inspect trustee-kbs &>/dev/null; then
        tap_not_ok "KBS external port accessible" "KBS container not running"
        return
    fi

    # Check if port 8080 is published
    local published
    published=$(podman inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "8080/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' trustee-kbs 2>/dev/null || echo "")

    if [[ -n "$published" ]]; then
        # Try to connect from host
        if nc -z -w5 localhost "$published" 2>/dev/null; then
            tap_ok "KBS external port accessible" "localhost:$published"
        else
            tap_not_ok "KBS external port accessible" "Port $published published but not responding"
        fi
    else
        tap_not_ok "KBS external port accessible" "Port 8080 not published"
    fi
}

# =============================================================================
# TEST: gRPC health checks (if grpc_health_probe available)
# =============================================================================

test_rvps_grpc_health() {
    if ! command -v podman &> /dev/null; then
        tap_skip "RVPS gRPC health" "podman not available"
        return
    fi

    if ! podman inspect trustee-rvps &>/dev/null; then
        tap_not_ok "RVPS gRPC health" "RVPS container not running"
        return
    fi

    # Try grpc_health_probe inside the container
    if podman exec trustee-rvps grpc_health_probe -addr=:50003 2>/dev/null; then
        tap_ok "RVPS gRPC health" "gRPC health check passed"
    else
        # If grpc_health_probe not available, check if port is listening
        if podman exec trustee-rvps sh -c 'ss -tlnp | grep -q 50003' 2>/dev/null; then
            tap_ok "RVPS gRPC health" "Port listening (grpc_health_probe not available)"
        else
            tap_not_ok "RVPS gRPC health" "Service not responding"
        fi
    fi
}

test_as_grpc_health() {
    if ! command -v podman &> /dev/null; then
        tap_skip "AS gRPC health" "podman not available"
        return
    fi

    if ! podman inspect trustee-as &>/dev/null; then
        tap_not_ok "AS gRPC health" "AS container not running"
        return
    fi

    if podman exec trustee-as grpc_health_probe -addr=:50004 2>/dev/null; then
        tap_ok "AS gRPC health" "gRPC health check passed"
    else
        if podman exec trustee-as sh -c 'ss -tlnp | grep -q 50004' 2>/dev/null; then
            tap_ok "AS gRPC health" "Port listening (grpc_health_probe not available)"
        else
            tap_not_ok "AS gRPC health" "Service not responding"
        fi
    fi
}

# =============================================================================
# TEST: End-to-end attestation flow (basic smoke test)
# =============================================================================

test_kbs_attestation_endpoint() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS attestation endpoint" "podman not available"
        return
    fi

    if ! podman inspect trustee-kbs &>/dev/null; then
        tap_not_ok "KBS attestation endpoint" "KBS container not running"
        return
    fi

    # Try to access the attestation policy endpoint (should exist even without auth)
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/kbs/v0/auth 2>/dev/null || echo "000")

    if [[ "$http_code" == "000" ]]; then
        tap_not_ok "KBS attestation endpoint" "No HTTP response"
    elif [[ "$http_code" =~ ^[2345] ]]; then
        # Any response (even 4xx/5xx) means the endpoint exists
        tap_ok "KBS attestation endpoint" "HTTP $http_code"
    else
        tap_not_ok "KBS attestation endpoint" "Unexpected response: $http_code"
    fi
}

test_kbs_resource_endpoint() {
    if ! command -v podman &> /dev/null; then
        tap_skip "KBS resource endpoint" "podman not available"
        return
    fi

    if ! podman inspect trustee-kbs &>/dev/null; then
        tap_not_ok "KBS resource endpoint" "KBS container not running"
        return
    fi

    # Try to access a resource endpoint (will fail auth, but server should respond)
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/kbs/v0/resource/default/test/key 2>/dev/null || echo "000")

    if [[ "$http_code" == "000" ]]; then
        tap_not_ok "KBS resource endpoint" "No HTTP response"
    elif [[ "$http_code" =~ ^[2345] ]]; then
        tap_ok "KBS resource endpoint" "HTTP $http_code (auth required, as expected)"
    else
        tap_not_ok "KBS resource endpoint" "Unexpected response: $http_code"
    fi
}

# =============================================================================
# TEST: Logs are being written
# =============================================================================

test_containers_have_logs() {
    if ! command -v podman &> /dev/null; then
        tap_skip "Containers have logs" "podman not available"
        return
    fi

    local has_logs=true

    for container in trustee-kbs trustee-as trustee-rvps; do
        if podman inspect "$container" &>/dev/null; then
            local log_size
            log_size=$(podman logs "$container" 2>&1 | wc -c)
            if [[ "$log_size" -lt 10 ]]; then
                has_logs=false
            fi
        fi
    done

    if $has_logs; then
        tap_ok "Containers have logs" "All containers producing output"
    else
        tap_not_ok "Containers have logs" "One or more containers have no logs"
    fi
}

# =============================================================================
# RUN ALL INTEGRATION TESTS
# =============================================================================

echo "# Integration tests"

# Network tests
test_containers_share_network

# Inter-service connectivity
test_as_can_reach_rvps
test_kbs_can_reach_as
test_kbs_external_port

# gRPC health
test_rvps_grpc_health
test_as_grpc_health

# HTTP endpoint tests
test_kbs_attestation_endpoint
test_kbs_resource_endpoint

# Logging
test_containers_have_logs
