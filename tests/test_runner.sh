#!/bin/bash
# Quadlet TDD Test Runner
# Outputs TAP (Test Anything Protocol) format

set -uo pipefail
# Note: not using -e because we handle test failures via tap_not_ok

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test mode: syntax, unit, rpm, health, integration, all
TEST_MODE="${1:-all}"

# Print TAP header
tap_header() {
    echo "TAP version 14"
}

# Print test result
tap_ok() {
    local test_name="$1"
    local message="${2:-}"
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    echo -e "${GREEN}ok${NC} ${TESTS_RUN} - ${test_name}"
    [[ -n "$message" ]] && echo "  # ${message}"
}

tap_not_ok() {
    local test_name="$1"
    local message="${2:-}"
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    echo -e "${RED}not ok${NC} ${TESTS_RUN} - ${test_name}"
    [[ -n "$message" ]] && echo "  # ${message}"
}

tap_skip() {
    local test_name="$1"
    local reason="${2:-}"
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    echo -e "${YELLOW}ok${NC} ${TESTS_RUN} - ${test_name} # SKIP ${reason}"
}

# Print TAP footer
tap_footer() {
    echo ""
    echo "1..${TESTS_RUN}"
    echo ""
    echo -e "# Tests: ${TESTS_RUN}, Passed: ${GREEN}${TESTS_PASSED}${NC}, Failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "\n${RED}FAILED${NC}"
        return 1
    else
        echo -e "\n${GREEN}PASSED${NC}"
        return 0
    fi
}

# Source test files based on mode
run_tests() {
    tap_header

    case "${TEST_MODE}" in
        syntax)
            source "${SCRIPT_DIR}/test_syntax.sh"
            ;;
        unit)
            source "${SCRIPT_DIR}/test_unit_generation.sh"
            ;;
        rpm)
            source "${SCRIPT_DIR}/test_rpm.sh"
            ;;
        health)
            source "${SCRIPT_DIR}/test_health.sh"
            ;;
        integration)
            source "${SCRIPT_DIR}/test_integration.sh"
            ;;
        static)
            # All tests that don't require running containers
            source "${SCRIPT_DIR}/test_syntax.sh"
            source "${SCRIPT_DIR}/test_unit_generation.sh"
            source "${SCRIPT_DIR}/test_rpm.sh"
            ;;
        all)
            source "${SCRIPT_DIR}/test_syntax.sh"
            source "${SCRIPT_DIR}/test_unit_generation.sh"
            source "${SCRIPT_DIR}/test_rpm.sh"
            # Health and integration require running containers
            if [[ "${SKIP_RUNTIME_TESTS:-false}" != "true" ]]; then
                source "${SCRIPT_DIR}/test_health.sh"
                source "${SCRIPT_DIR}/test_integration.sh"
            fi
            ;;
        *)
            echo "Unknown test mode: ${TEST_MODE}"
            echo "Usage: $0 [syntax|unit|rpm|health|integration|static|all]"
            exit 1
            ;;
    esac

    tap_footer
}

run_tests
