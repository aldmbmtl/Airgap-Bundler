#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/.test-integration"
BUNDLE_PATTERN="airgap-bundle-*.tar.gz"
BUNDLE_DIR=""

cleanup() {
    local exit_code=$?
    echo ""
    echo "=== Cleaning up ==="
    
    if [ -n "${BUNDLE_DIR:-}" ] && [ -d "${BUNDLE_DIR}" ]; then
        cd "${BUNDLE_DIR}"
        if [ -f docker-compose.yaml ]; then
            docker compose down --volumes 2>/dev/null || true
        fi
    fi
    
    rm -rf "${TEST_DIR}"
    rm -f "${BUNDLE_PATTERN}"
    
    echo "Cleanup complete (exit code: ${exit_code})"
    exit "${exit_code}"
}

trap cleanup EXIT

echo "=== Integration Test Suite ==="
echo ""

echo "=== Step 1: Build the bundle ==="
./build-bundle.sh

BUNDLE_FILE=$(find . -maxdepth 1 -name "airgap-bundle-*.tar.gz" -type f 2>/dev/null | head -n1)
if [ -z "${BUNDLE_FILE}" ]; then
    echo "ERROR: No bundle file created"
    exit 1
fi
echo "Bundle created: ${BUNDLE_FILE}"
echo ""

echo "=== Step 2: Extract bundle ==="
mkdir -p "${TEST_DIR}"
tar -xzf "${BUNDLE_FILE}" -C "${TEST_DIR}"

BUNDLE_DIR=$(find "${TEST_DIR}" -maxdepth 1 -name "airgap-bundle-*" -type d 2>/dev/null | head -n1)
if [ -z "${BUNDLE_DIR}" ]; then
    echo "ERROR: Bundle extraction failed"
    exit 1
fi
cd "${BUNDLE_DIR}"
echo "Extracted to: ${BUNDLE_DIR}"
echo ""

echo "=== Step 3: Start services (load.sh) ==="
./load.sh

echo "Waiting for services to be ready..."
sleep 5

echo "=== Step 4: Test Docker Registry ==="

TEST_IMAGE_NAME="test-image"
TEST_IMAGE_TAG="test-tag"
TEST_IMAGE_FULL="localhost:5000/${TEST_IMAGE_NAME}:${TEST_IMAGE_TAG}"

echo "Pulling alpine image for testing..."
docker pull alpine:latest

echo "Tagging for local registry..."
docker tag alpine:latest "${TEST_IMAGE_FULL}"

echo "Pushing to local registry..."
docker push "${TEST_IMAGE_FULL}"

echo "Removing local image..."
docker rmi "${TEST_IMAGE_FULL}" alpine:latest

echo "Pulling from local registry..."
docker pull "${TEST_IMAGE_FULL}"

if docker images "${TEST_IMAGE_FULL}" | grep -q "${TEST_IMAGE_TAG}"; then
    echo "Docker Registry: PASS"
else
    echo "Docker Registry: FAIL"
    exit 1
fi

echo ""

echo "=== Step 5: Test Git Server ==="

TEST_REPO_NAME="Orion-Deployment"

echo "Cloning test repository from git server..."
git clone "http://localhost:8080/git/${TEST_REPO_NAME}.git" "${TEST_DIR}/${TEST_REPO_NAME}" 2>/dev/null || true

if [ -d "${TEST_DIR}/${TEST_REPO_NAME}/.git" ]; then
    echo "Git Server: PASS"
else
    echo "Git Server: FAIL"
    exit 1
fi

echo ""

echo "=== All Tests Passed ==="
