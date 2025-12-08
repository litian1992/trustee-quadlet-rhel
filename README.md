# Trustee Quadlet - RHEL Integration

Run Trustee attestation services (KBS, AS, RVPS) as systemd-managed containers on RHEL using Podman Quadlet.

## Demo

![Trustee on RHEL via Quadlet](docs/trustee-quadlet-demo.gif)

## Overview

This package provides Quadlet configurations that enable running Trustee on RHEL/Fedora systems using native systemd service management while leveraging container images as the deployment artifact.

**Benefits:**
- Single source of truth: Uses official Trustee container images
- Native RHEL experience: `systemctl start/stop/status`, `journalctl` for logs
- Familiar configuration: Edit files in `/etc/trustee/`, restart services
- Security: SELinux, systemd sandboxing, container isolation
- Updates: Pull new images, restart services

## Architecture

```
                        ┌──────────────────┐
                        │   Confidential   │
                        │    Workloads     │
                        └────────┬─────────┘
                                 │ HTTPS :8080
                                 ▼
┌────────────────────────────────────────────────────────────────┐
│                      RHEL/Fedora Host                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              trustee.network (10.89.0.0/24)             │   │
│  │                                                         │   │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   │   │
│  │  │  trustee-   │   │  trustee-   │   │  trustee-   │   │   │
│  │  │    kbs      │──▶│     as      │──▶│    rvps     │   │   │
│  │  │  :8080 (pub)│   │   :50004    │   │   :50003    │   │   │
│  │  └─────────────┘   └─────────────┘   └─────────────┘   │   │
│  │        │                 │                 │           │   │
│  │        ▼                 ▼                 ▼           │   │
│  │  /etc/trustee/     /etc/trustee/     /etc/trustee/     │   │
│  │      kbs/              as/              rvps/          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                │
│  systemd + Quadlet generator                                   │
│  /etc/containers/systemd/*.container                           │
└────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- RHEL 9.2+ / Fedora 38+ with Podman 4.4+
- Container registry access (Red Hat registry or quay.io)

### Installation (from RPM)

```bash
# Install the package
dnf install trustee-quadlet

# Configure (edit as needed)
vim /etc/trustee/kbs/config.toml
vim /etc/trustee/kbs/policy.rego

# Start services (KBS will auto-start AS and RVPS)
systemctl start trustee-kbs

# Check status
systemctl status trustee-kbs trustee-as trustee-rvps
```

### Installation (manual)

```bash
# Clone and navigate
git clone https://github.com/confidential-containers/trustee.git
cd trustee/contrib/rhel-quadlet

# Install Quadlet files
sudo cp quadlet/*.container /etc/containers/systemd/
sudo cp quadlet/*.network /etc/containers/systemd/
sudo cp quadlet/*.volume /etc/containers/systemd/

# Install configuration
sudo mkdir -p /etc/trustee/{kbs,as,rvps}
sudo cp configs/kbs/* /etc/trustee/kbs/
sudo cp configs/as/* /etc/trustee/as/
sudo cp configs/rvps/* /etc/trustee/rvps/

# Reload systemd
sudo systemctl daemon-reload

# Start services
sudo systemctl start trustee-kbs
```

## Usage

### Service Management

```bash
# Start all services (dependencies auto-start)
systemctl start trustee-kbs

# Stop all services
systemctl stop trustee-kbs trustee-as trustee-rvps

# Restart a specific service
systemctl restart trustee-as

# Enable at boot
systemctl enable trustee-kbs

# View status
systemctl status trustee-kbs trustee-as trustee-rvps
```

### Viewing Logs

```bash
# Follow all Trustee logs
journalctl -f -u trustee-kbs -u trustee-as -u trustee-rvps

# View KBS logs only
journalctl -u trustee-kbs

# View recent errors
journalctl -u trustee-kbs -p err --since "1 hour ago"
```

### Updating Container Images

```bash
# Pull latest images
podman pull registry.redhat.io/rhtas/trustee-kbs:latest
podman pull registry.redhat.io/rhtas/trustee-as:latest
podman pull registry.redhat.io/rhtas/trustee-rvps:latest

# Restart services to use new images
systemctl restart trustee-kbs
```

### Configuration

Configuration files are stored in `/etc/trustee/`:

| File | Purpose |
|------|---------|
| `/etc/trustee/kbs/config.toml` | KBS main configuration |
| `/etc/trustee/kbs/policy.rego` | Authorization policy (OPA/Rego) |
| `/etc/trustee/as/config.json` | Attestation Service configuration |
| `/etc/trustee/rvps/config.json` | Reference Value Provider configuration |

After editing configuration:
```bash
systemctl restart trustee-kbs  # Or the specific service you changed
```

## Development

### Running Tests

```bash
cd contrib/rhel-quadlet

# Run all static tests (no containers needed)
make test-static

# Run specific test suites
make test-syntax     # Quadlet file validation
make test-unit       # systemd unit generation
make test-rpm        # RPM spec validation

# Run full tests (requires running containers)
make test
```

### Building RPM

```bash
# Build source tarball and RPM
make build-rpm

# RPM will be in build/rpmbuild/RPMS/
```

### Local Development

```bash
# Install locally for testing
make install

# Start services
make start

# View logs
make logs

# Stop and cleanup
make stop
make clean-containers
```

## Directory Structure

```
contrib/rhel-quadlet/
├── quadlet/              # Quadlet unit files
│   ├── trustee-kbs.container
│   ├── trustee-as.container
│   ├── trustee-rvps.container
│   ├── trustee.network
│   └── *.volume
├── configs/              # Default configurations
│   ├── kbs/
│   ├── as/
│   └── rvps/
├── rpm/                  # RPM packaging
│   └── trustee-quadlet.spec
├── tests/                # TDD test suite
│   ├── test_runner.sh
│   ├── test_syntax.sh
│   ├── test_unit_generation.sh
│   ├── test_health.sh
│   ├── test_integration.sh
│   └── test_rpm.sh
├── scripts/              # Helper scripts
├── Makefile
└── README.md
```

## Customization

### Using Different Container Images

Edit the `.container` files in `/etc/containers/systemd/`:

```ini
# Use a different registry
Image=quay.io/confidential-containers/kbs:v0.10.0

# Use a local image
Image=localhost/my-custom-kbs:latest
```

### Overriding Quadlet Files

The RPM installs defaults to `/usr/share/containers/systemd/`. To customize:

1. Copy the file you want to override to `/etc/containers/systemd/`
2. Edit the copy
3. Run `systemctl daemon-reload`

Files in `/etc/` take precedence over `/usr/share/`.

### Rootless Mode

For rootless containers, install files to user directories:

```bash
mkdir -p ~/.config/containers/systemd
cp quadlet/*.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start trustee-kbs
```

## Security Considerations

- **TLS:** Configure TLS in production. Edit `/etc/trustee/kbs/config.toml`
- **Policies:** Review and customize `/etc/trustee/kbs/policy.rego`
- **SELinux:** Runs in enforcing mode by default
- **Secrets:** Use Vault or external secret management for production

## Troubleshooting

### Service won't start

```bash
# Check Quadlet generation
/usr/libexec/podman/quadlet -dryrun /etc/containers/systemd/

# Check container logs
podman logs trustee-kbs

# Check if image exists
podman images | grep trustee
```

### Network connectivity issues

```bash
# Verify network exists
podman network ls | grep trustee

# Test connectivity from container
podman exec trustee-kbs curl -s http://trustee-as:50004/
```

## License

Apache-2.0

## Contributing

Contributions welcome! Please run `make test-static` before submitting PRs.
