# Trustee on RHEL: Quadlet-Based Delivery Proposal

**For:** Lukas, Yash (RHEL Attestation Team)
**From:** OpenShift Confidential Computing Team
**Date:** December 2024

---

## Executive Summary

We propose delivering Trustee on RHEL using **Podman Quadlet** — a native RHEL technology that runs containers as systemd services. This approach:

- Provides a **first-class RHEL experience** (`systemctl`, `journalctl`, `/etc/` configs)
- Uses **official container images** as the single build artifact
- Ships as an **RPM package** (`trustee-quadlet`) containing Quadlet configs and default settings
- Follows **Fedora/RHEL packaging guidelines** for systemd services

We have a working prototype validated on RHEL 9 in Azure.

---

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         RHEL 9 Host                             │
│                                                                 │
│  RPM: trustee-quadlet-0.1.0.noarch.rpm                         │
│  ├── /usr/share/containers/systemd/    (vendor defaults)       │
│  │   └── trustee-kbs.container                                 │
│  ├── /etc/containers/systemd/          (user-customizable)     │
│  │   └── trustee-kbs.container                                 │
│  └── /etc/trustee/kbs/                 (configuration)         │
│      ├── config.toml                                           │
│      └── policy.rego                                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  systemd + Quadlet Generator                            │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │  trustee-kbs.service (auto-generated)           │    │   │
│  │  │  └── podman run ... kbs --config-file ...       │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Container Image: registry.redhat.io/build-of-trustee/...      │
│  (Pulled on first start, managed by podman)                    │
└─────────────────────────────────────────────────────────────────┘
```

### User Experience

```bash
# Install
dnf install trustee-quadlet

# Configure
vim /etc/trustee/kbs/config.toml

# Start (systemd-native)
systemctl enable --now trustee-kbs

# Logs (journald-native)
journalctl -u trustee-kbs -f

# Update
podman pull registry.redhat.io/build-of-trustee/trustee-rhel9:latest
systemctl restart trustee-kbs
```

This is the standard RHEL operator experience — no container knowledge required.

---

## RPM Packaging Details

### Spec File Compliance

The `trustee-quadlet.spec` follows Fedora/RHEL packaging guidelines:

| Guideline | Implementation |
|-----------|----------------|
| **Architecture** | `BuildArch: noarch` — config files only, no compiled binaries |
| **Dependencies** | `Requires: podman >= 4.4, systemd, container-selinux` |
| **Conflicts** | `Conflicts: trustee-kbs, trustee-as, trustee-rvps` — prevents dual-install |
| **File locations** | Vendor files in `/usr/share/`, user configs in `/etc/` |
| **Config handling** | `%config(noreplace)` — preserves user changes on upgrade |
| **Post-install** | `systemctl daemon-reload` in `%post` scriptlet |
| **License** | `License: Apache-2.0` with `%license` macro |

### File Layout (per Fedora guidelines)

```
/usr/share/containers/systemd/          # Vendor defaults (like /usr/lib/systemd/)
├── trustee-kbs.container
├── trustee.network
└── *.volume

/etc/containers/systemd/                # User overrides (like /etc/systemd/)
├── trustee-kbs.container               # %config(noreplace)
└── ...

/etc/trustee/                           # Application config
├── kbs/config.toml                     # %config(noreplace)
└── kbs/policy.rego                     # %config(noreplace)

/usr/share/doc/trustee-quadlet/         # Documentation
└── README.md
```

### Build Process

```bash
# Creates noarch RPM (works on both x86_64 and aarch64)
rpmbuild -bb trustee-quadlet.spec

# Output
trustee-quadlet-0.1.0-1.el9.noarch.rpm      # Main package (18 KB)
trustee-quadlet-selinux-0.1.0-1.el9.noarch.rpm  # SELinux policy (future)
```

---

## What the RHEL Team Owns

| Deliverable | Description |
|-------------|-------------|
| **trustee-quadlet RPM** | The Quadlet configs, default settings, helper scripts |
| **RHEL-specific testing** | CI pipeline for RHEL 8.x, 9.x, EUS versions |
| **SELinux integration** | Custom policies if needed, enforcing mode validation |
| **FIPS compliance** | Verification that images meet FIPS requirements |
| **Documentation** | RHEL-specific deployment guides, KB articles |
| **Support escalation** | L1/L2 for RHEL-deployed Trustee |

### What We (OpenShift CoCo) Own

| Deliverable | Description |
|-------------|-------------|
| **Container images** | Build, test, CVE patching, registry publishing |
| **Upstream Trustee** | Feature development, bug fixes, releases |
| **Kubernetes/OpenShift** | Operator, Helm charts, OLM integration |

---

## Why Not Separate RPMs for KBS/AS/RVPS?

| Concern | Quadlet Approach | Separate RPMs |
|---------|------------------|---------------|
| **Build maintenance** | One container image, built in existing CI | New Rust build pipeline, 200+ crate dependencies |
| **CVE response** | Push new image, users restart | Rebuild RPMs, new errata, users update packages |
| **Version sync** | Single image tag, guaranteed compatible | Risk of version skew between components |
| **Testing** | Test container once | Test RPM builds separately |
| **FIPS/crypto** | Container uses UBI base OpenSSL | Must vendor/validate Rust crypto |

---

## Disconnected / Air-Gapped Environments

A common concern: *"The RPM requires network access to pull container images."*

### Counter-Arguments

| Concern | Response |
|---------|----------|
| **"RPMs work offline"** | Not really — `dnf install` also requires network access to repos. Disconnected environments already mirror RPM repos; same process applies to container registries. |
| **"Containers are different"** | Red Hat's own products (OpenShift, RHEL AI, Podman Desktop) all use container images. The ecosystem already supports this pattern. |
| **"No precedent"** | RHEL 9 ships `toolbox` which pulls containers. AutoSD (automotive) uses Quadlet in air-gapped vehicles. |
| **"RPM should be self-sufficient"** | The RPM *is* self-sufficient for RHEL integration (systemd, SELinux, config). The container image is a dependency, like how an RPM can depend on `openssl` without bundling it. |

### Solutions for Disconnected Deployment

**Option 1: Mirror Registry (Enterprise Standard)**
```bash
# Mirror to internal Quay/Harbor (same as mirroring RPM repos)
skopeo copy \
  docker://registry.redhat.io/build-of-trustee/trustee-rhel9:latest \
  docker://internal-registry.corp.com/trustee/trustee-rhel9:latest

# Override in Quadlet config
Image=internal-registry.corp.com/trustee/trustee-rhel9:latest
```

**Option 2: Pre-loaded Image Tarball**
```bash
# On connected system
podman save -o trustee-rhel9.tar registry.redhat.io/build-of-trustee/trustee-rhel9

# Transfer to disconnected system
podman load -i trustee-rhel9.tar
systemctl start trustee-kbs  # Uses cached image
```

**Option 3: Embedded Image RPM (see below)**

---

## Deployment Options

We offer **three deployment options** to address different environments and use cases:

| Option | Delivery | Use Case |
|--------|----------|----------|
| **RPM + Quadlet** | `trustee-quadlet` RPM (18 KB) | Traditional RHEL servers, familiar package management |
| **bootc Image** | Container image with embedded Quadlet | Immutable infrastructure, RHEL Image Mode, edge |
| **Offline RPM** | `trustee-quadlet-offline` RPM (~95 MB) | Air-gapped environments, self-contained |

---

## Option 1: RPM + Quadlet (Traditional RHEL)

The standard approach for traditional RHEL deployments.

```bash
# Install
dnf install trustee-quadlet

# Configure
vim /etc/trustee/kbs/config.toml

# Start
systemctl enable --now trustee-kbs
```

**Characteristics:**
- Lightweight noarch RPM (18 KB) with Quadlet configs only
- Container image pulled on first start or pre-staged
- Updates: `podman pull` + `systemctl restart` (minutes, no errata needed)
- Single RPM works on both x86_64 and aarch64

**Best for:** Traditional RHEL servers, data centers with registry access

---

## Option 2: bootc Image (RHEL Image Mode)

For immutable infrastructure deployments using RHEL Image Mode (bootc).

```
┌─────────────────────────────────────────────────────────────────┐
│                    trustee-bootc Image                          │
│                                                                 │
│  FROM quay.io/centos-bootc/centos-bootc:stream9                │
│  (or registry.redhat.io/rhel9/rhel-bootc:9.5)                  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  /etc/containers/systemd/trustee-kbs.container          │   │
│  │  /etc/trustee/kbs/config.toml                           │   │
│  │  /etc/trustee/kbs/policy.rego                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Trustee container image pulled at first boot                  │
│  (or embedded for air-gapped with skopeo copy)                 │
└─────────────────────────────────────────────────────────────────┘
```

**How it works:**
1. Build a bootc container image that includes Quadlet configs
2. Convert to disk image (qcow2, VHD, AMI, ISO) using `bootc-image-builder`
3. Deploy to VMs, bare metal, or cloud instances
4. Trustee starts automatically via systemd/Quadlet

```dockerfile
# Containerfile
FROM quay.io/centos-bootc/centos-bootc:stream9

# Install Quadlet configs and default configuration
COPY quadlet/trustee-kbs.container /etc/containers/systemd/
COPY configs/kbs/ /etc/trustee/kbs/

# Create data directories
RUN mkdir -p /var/lib/kbs/repository

EXPOSE 8080
```

**Build and deploy:**
```bash
# Build bootc container
podman build -t trustee-bootc:latest .

# Create disk image
sudo podman run --rm --privileged \
  -v ./output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --local \
  trustee-bootc:latest

# Deploy to VM/cloud
# Boot from output/qcow2/disk.qcow2
```

**Characteristics:**
- Immutable OS image with Trustee pre-configured
- Atomic updates via `bootc upgrade`
- Same Quadlet configs as RPM approach
- Works with any bootc-compatible base (CentOS Stream 9, RHEL 9)

**Best for:** Edge deployments, immutable infrastructure, automated provisioning, RHEL AI-style deployments

---

## Option 3: Offline RPM (Air-Gapped)

For disconnected environments that require fully self-contained packages.

```spec
# trustee-quadlet-offline.spec (simplified)
%package offline
Summary:  Trustee with embedded container image
Requires: trustee-quadlet
Source1:  trustee-rhel9.tar.gz

%post offline
podman load -i %{_datadir}/trustee-quadlet/images/trustee-rhel9.tar.gz
```

**Characteristics:**
- Embeds compressed container image (~95 MB)
- Fully self-contained, works without network
- `%post` scriptlet runs `podman load` automatically
- Architecture-specific (x86_64, aarch64 separate)

**Best for:** Air-gapped environments, high-security deployments

---

## Comparison Matrix

| Aspect | RPM + Quadlet | bootc Image | Offline RPM |
|--------|---------------|-------------|-------------|
| **Package size** | 18 KB | ~1.5 GB (disk image) | ~95 MB |
| **Disconnected install** | Requires mirror/pre-pull | Fully self-contained | Fully self-contained |
| **CVE response time** | Hours (push image) | Hours (rebuild image) | Weeks (rebuild RPM + errata) |
| **Update workflow** | `podman pull` + restart | `bootc upgrade` | `dnf update` + restart |
| **Arch support** | Single noarch RPM | Per-arch images | Per-arch RPMs |
| **OS model** | Mutable | Immutable | Mutable |
| **Use case** | Traditional servers | Edge, immutable infra | Air-gapped |

**Recommendation:**
- Default to **RPM + Quadlet** for traditional RHEL servers
- Use **bootc** for edge, immutable infrastructure, or RHEL AI-style deployments
- Offer **Offline RPM** for customers who require fully self-contained packages

---

## Precedent: RHEL AI and CentOS Automotive SIG

### RHEL AI

**RHEL AI** uses bootc for deploying AI/ML workloads:

- Bootable container images with pre-configured AI stack
- Immutable OS with atomic updates
- Quadlet for service management
- Production-ready and GA

Trustee for RHEL AI would follow the same pattern — a bootc image with attestation services pre-configured.

### CentOS Automotive SIG

Red Hat's **AutoSD** (Automotive Stream Distribution) uses this exact pattern:

- Quadlet `.container` files for in-vehicle workloads
- Container images as deployment artifacts
- systemd integration via Quadlet generator
- Used in safety-critical automotive systems

This is not experimental — it's production-ready and headed toward automotive certification.

---

## Live Demos

We have working deployments demonstrating both deployment options.

---

### Demo 1: RPM + Quadlet on RHEL 9

![RPM + Quadlet Demo](trustee-quadlet-demo.gif)

#### Demo Environment

| Component | Details |
|-----------|---------|
| **VM** | Azure RHEL 9.5, Standard_B2s |
| **Image** | `registry.redhat.io/build-of-trustee/trustee-rhel9` |
| **Access** | See TEST-ENV.md (gitignored) |

#### Step 1: Verify systemd Integration

```bash
# Check service status (standard RHEL admin experience)
$ systemctl status trustee-kbs
● trustee-kbs.service - Trustee Key Broker Service (All-in-One)
     Loaded: loaded (/etc/containers/systemd/trustee-kbs.container; generated)
     Active: active (running) since Tue 2024-12-03 09:56:13 UTC

# View logs via journald
$ journalctl -u trustee-kbs -n 5
Dec 03 09:56:13 trustee-vm trustee-kbs[48713]: [INFO  kbs] Using config file /etc/kbs/config.toml
Dec 03 09:56:13 trustee-vm trustee-kbs[48713]: [INFO  kbs::api_server] Starting HTTP server at [0.0.0.0:8080]
```

#### Step 2: Push a Secret (Admin API)

```bash
# Generate admin JWT (Ed25519 signed)
HEADER=$(echo -n '{"alg":"EdDSA","typ":"JWT"}' | base64 -w0 | tr "+/" "-_" | tr -d "=")
NOW=$(date +%s); EXP=$((NOW + 3600))
PAYLOAD=$(echo -n "{\"iss\":\"admin\",\"iat\":$NOW,\"exp\":$EXP}" | base64 -w0 | tr "+/" "-_" | tr -d "=")
echo -n "${HEADER}.${PAYLOAD}" > /tmp/to_sign.txt
SIGNATURE=$(openssl pkeyutl -sign -inkey /tmp/admin-key.pem -in /tmp/to_sign.txt | base64 -w0 | tr "+/" "-_" | tr -d "=")
JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# Push secret via admin API
$ curl -X POST "http://localhost:8080/kbs/v0/resource/default/keys/test-key" \
    -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/octet-stream" \
    -d "this-is-my-secret-key-12345"
# Returns: HTTP 200 OK
```

#### Step 3: Verify Secret Storage

```bash
# Confirm secret is stored in KBS
$ sudo podman exec trustee-kbs cat /var/lib/kbs/repository/default/keys/test-key
this-is-my-secret-key-12345
```

#### Step 4: Client Retrieval (Requires Attestation)

```bash
# Attempt to retrieve without attestation
$ curl http://localhost:8080/kbs/v0/resource/default/keys/test-key
{"type":"TokenNotFound","detail":"Attestation Token not found"}
# HTTP 401 - CORRECT! Clients must attest before retrieving secrets.
```

#### What This Proves

| Test | Result | Meaning |
|------|--------|---------|
| `systemctl status` | `active (running)` | systemd manages container lifecycle |
| `journalctl -u trustee-kbs` | Logs visible | Standard RHEL log aggregation works |
| Admin API POST | `200 OK` | Secret management functional |
| Client GET | `401 Unauthorized` | Attestation enforcement working |
| RCAR handshake | Nonce returned | Protocol working, ready for TEE evidence |

#### Full Attestation Flow (requires TEE hardware)

For complete end-to-end attestation, you need:

1. **Azure Confidential VM** (DCasv5/ECasv5 series with AMD SEV-SNP), or
2. **Intel TDX-enabled hardware**

The attestation flow works like this:
```
┌─────────────────┐         ┌─────────────────┐
│  Confidential   │         │       KBS       │
│    Workload     │         │   (our demo)    │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │ 1. POST /auth             │
         │   {tee: "snp"}            │
         │ ─────────────────────────>│
         │                           │
         │ 2. Challenge nonce        │
         │ <─────────────────────────│
         │                           │
         │ 3. POST /attest           │
         │   {tee-evidence: <SNP>}   │  ← Requires real TEE
         │ ─────────────────────────>│
         │                           │
         │ 4. Attestation Token      │
         │ <─────────────────────────│
         │                           │
         │ 5. GET /resource/...      │
         │   + Token                 │
         │ ─────────────────────────>│
         │                           │
         │ 6. Encrypted Secret       │
         │ <─────────────────────────│
         └───────────────────────────┘
```

Our demo validates steps 1-2 and the secret storage (step 6). Steps 3-5 require
actual TEE hardware generating cryptographic attestation evidence.

#### Reproduce It Yourself

```bash
# 1. Install the RPM (on RHEL 9)
sudo dnf install trustee-quadlet-0.1.0-1.el9.noarch.rpm

# 2. Pull the container image
sudo podman pull registry.redhat.io/build-of-trustee/trustee-rhel9:latest

# 3. Generate admin keys
openssl genpkey -algorithm ed25519 -out /etc/trustee/kbs/admin-key.pem
openssl pkey -in /etc/trustee/kbs/admin-key.pem -pubout -out /etc/trustee/kbs/admin-pub.pem

# 4. Configure KBS (minimal config)
cat > /etc/trustee/kbs/config.toml << 'EOF'
[http_server]
sockets = ["0.0.0.0:8080"]
insecure_http = true

[attestation_token]
insecure_key = true

[attestation_service]
type = "coco_as_builtin"
work_dir = "/tmp/as"
policy_engine = "opa"

[attestation_service.rvps_config]
type = "BuiltIn"

[admin]
auth_public_key = "/etc/kbs/admin-pub.pem"

[[plugins]]
name = "resource"
type = "LocalFs"
dir_path = "/var/lib/kbs/repository"
EOF

# 5. Start the service
sudo systemctl daemon-reload
sudo systemctl start trustee-kbs

# 6. Test it
curl http://localhost:8080/kbs/v0/resource/default/test/key
# Should return 401 - attestation required
```

---

### Demo 2: bootc Image (RHEL Image Mode)

A bootc image with Trustee pre-configured, built and deployed to a VM.

#### Demo Environment

| Component | Details |
|-----------|---------|
| **Base Image** | CentOS Stream 9 bootc |
| **Trustee Image** | `registry.redhat.io/build-of-trustee/trustee-rhel9:1.0` |
| **Disk Format** | qcow2 (1.3 GB) |
| **Access** | See TEST-ENV.md (gitignored) |

#### What the Demo Shows

1. **Immutable OS**: The system boots from a container-derived disk image
2. **Pre-configured Quadlet**: Trustee starts automatically via systemd
3. **Same behavior**: Identical attestation workflow as RPM deployment

```bash
# Check the bootc status
$ bootc status
Current staged image: quay.io/myorg/trustee-bootc:latest
State: booted

# Trustee is running (started automatically)
$ systemctl status trustee-kbs
● trustee-kbs.service - Trustee Key Broker Service
     Loaded: loaded (/etc/containers/systemd/trustee-kbs.container; generated)
     Active: active (running)

# Test the auth endpoint
$ curl -s -X POST http://localhost:8080/kbs/v0/auth \
    -H "Content-Type: application/json" \
    -d '{"version":"0.2.0","tee":"sample","extra-params":""}' | jq
{
  "nonce": "VlZN0bapScEI1+OWASLIjP8Euav/U6o/vWFtTniWSXQ=",
  "extra-params": ""
}
```

#### Reproduce It Yourself

```bash
# 1. Clone the bootc repository
git clone https://github.com/jensfr/trustee-bootc.git
cd trustee-bootc

# 2. Build the bootc container image
podman build -t trustee-bootc:latest .

# 3. Create a qcow2 disk image
sudo podman run --rm --privileged \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --local \
  localhost/trustee-bootc:latest

# 4. Boot the disk image (QEMU example)
qemu-system-x86_64 -m 4G -smp 2 -enable-kvm \
  -drive file=output/qcow2/disk.qcow2,format=qcow2 \
  -net nic -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080

# 5. SSH into the VM and verify
ssh -p 2222 admin@localhost
systemctl status trustee-kbs
curl http://localhost:8080/kbs/v0/auth -X POST -H "Content-Type: application/json" \
  -d '{"version":"0.2.0","tee":"sample","extra-params":""}'
```

---

## Next Steps

1. **Technical review** — RHEL team evaluates Quadlet and bootc prototypes
2. **Image agreement** — Confirm container image location and tagging
3. **Ownership split** — Document team responsibilities
4. **CI integration** — RHEL team sets up testing pipeline
5. **Errata process** — Define how Quadlet RPM updates flow
6. **bootc integration** — Evaluate bootc approach for RHEL AI and edge deployments

---

## Resources

| Resource | Location |
|----------|----------|
| **Quadlet prototype** | https://github.com/jensfr/trustee-quadlet-rhel |
| **bootc prototype** | https://github.com/jensfr/trustee-bootc |
| **RPM spec** | `rpm/trustee-quadlet.spec` |
| **Test suite** | `make test-static` (55 tests, all passing) |
| **Live demo VMs** | See TEST-ENV.md (gitignored) |
| **Container image** | `registry.redhat.io/build-of-trustee/trustee-rhel9` |
| **Trustee documentation** | https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.10/html/deploying_trustee/ |
| **Quadlet docs** | https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html |
| **bootc docs** | https://docs.fedoraproject.org/en-US/bootc/ |

---

*We're stronger together — one build, tested once, supported consistently.*
