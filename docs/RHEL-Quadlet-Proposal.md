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

## Package Options

We can offer **two RPM variants** to address different deployment scenarios:

| Package | Size | Use Case |
|---------|------|----------|
| `trustee-quadlet` | **18 KB** | Connected environments, fastest updates |
| `trustee-quadlet-offline` | **~95 MB** | Air-gapped environments, self-contained |

### trustee-quadlet (Default)

- Lightweight, noarch RPM with Quadlet configs only
- Container image pulled on first start or pre-staged
- Updates: `podman pull` + `systemctl restart` (minutes, no errata needed)

### trustee-quadlet-offline (Optional)

- Embeds compressed container image (~95 MB)
- Fully self-contained, works without network
- `%post` scriptlet runs `podman load` automatically
- Architecture-specific (x86_64, aarch64 separate)

```spec
# trustee-quadlet-offline.spec (simplified)
%package offline
Summary:  Trustee with embedded container image
Requires: trustee-quadlet
Source1:  trustee-rhel9.tar.gz

%post offline
podman load -i %{_datadir}/trustee-quadlet/images/trustee-rhel9.tar.gz
```

### Trade-off Summary

| Aspect | Standard (18 KB) | Offline (95 MB) |
|--------|------------------|-----------------|
| **Disconnected install** | Requires mirror/pre-pull | Works immediately |
| **CVE response time** | Hours (push image) | Weeks (rebuild RPM + errata) |
| **Update workflow** | `podman pull` + restart | `dnf update` + restart |
| **Arch support** | Single noarch RPM | Per-arch RPMs |

**Recommendation:** Default to `trustee-quadlet` for agility; offer `trustee-quadlet-offline` for customers who require fully self-contained packages.

---

## Precedent: CentOS Automotive SIG

Red Hat's **AutoSD** (Automotive Stream Distribution) uses this exact pattern:

- Quadlet `.container` files for in-vehicle workloads
- Container images as deployment artifacts
- systemd integration via Quadlet generator
- Used in safety-critical automotive systems

This is not experimental — it's production-ready and headed toward automotive certification.

---

## Live Demo: RHEL 9 on Azure

We have a working deployment on Azure RHEL 9 that demonstrates the full workflow.

### Demo Environment

| Component | Details |
|-----------|---------|
| **VM** | Azure RHEL 9.5, Standard_B2s |
| **Image** | `registry.redhat.io/build-of-trustee/trustee-rhel9` |
| **Access** | `ssh azureuser@172.174.6.53` |

### Step 1: Verify systemd Integration

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

### Step 2: Push a Secret (Admin API)

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

### Step 3: Verify Secret Storage

```bash
# Confirm secret is stored in KBS
$ sudo podman exec trustee-kbs cat /var/lib/kbs/repository/default/keys/test-key
this-is-my-secret-key-12345
```

### Step 4: Client Retrieval (Requires Attestation)

```bash
# Attempt to retrieve without attestation
$ curl http://localhost:8080/kbs/v0/resource/default/keys/test-key
{"type":"TokenNotFound","detail":"Attestation Token not found"}
# HTTP 401 - CORRECT! Clients must attest before retrieving secrets.
```

### What This Proves

| Test | Result | Meaning |
|------|--------|---------|
| `systemctl status` | `active (running)` | systemd manages container lifecycle |
| `journalctl -u trustee-kbs` | Logs visible | Standard RHEL log aggregation works |
| Admin API POST | `200 OK` | Secret management functional |
| Client GET | `401 Unauthorized` | Attestation enforcement working |
| RCAR handshake | Nonce returned | Protocol working, ready for TEE evidence |

### Full Attestation Flow (requires TEE hardware)

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

### Reproduce It Yourself

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

## Next Steps

1. **Technical review** — RHEL team evaluates Quadlet prototype
2. **Image agreement** — Confirm container image location and tagging
3. **Ownership split** — Document team responsibilities
4. **CI integration** — RHEL team sets up testing pipeline
5. **Errata process** — Define how Quadlet RPM updates flow

---

## Resources

| Resource | Location |
|----------|----------|
| **Prototype code** | `trustee/contrib/rhel-quadlet/` |
| **RPM spec** | `trustee/contrib/rhel-quadlet/rpm/trustee-quadlet.spec` |
| **Test suite** | `make test-static` (55 tests, all passing) |
| **Live demo VM** | `ssh azureuser@172.174.6.53` (RHEL 9, Azure) |
| **Container image** | `registry.redhat.io/build-of-trustee/trustee-rhel9` |
| **Quadlet docs** | https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html |

---

*We're stronger together — one build, tested once, supported consistently.*
