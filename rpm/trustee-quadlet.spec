# Trustee Quadlet - Podman Quadlet configurations for Trustee attestation services
# This RPM packages the Quadlet files that run Trustee containers as systemd services

%global project_name trustee-quadlet
%global project_version 0.1.0

Name:           %{project_name}
Version:        %{project_version}
Release:        1%{?dist}
Summary:        Podman Quadlet configurations for Trustee attestation services

License:        Apache-2.0
URL:            https://github.com/confidential-containers/trustee
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

# Build dependencies
BuildRequires:  systemd-rpm-macros

# Runtime dependencies
Requires:       podman >= 4.4
Requires:       systemd
Requires:       container-selinux
%{?systemd_requires}

# For health checks
Recommends:     curl
Recommends:     netcat

# Conflicts with any standalone RPM builds of Trustee
# (we want to ensure single source of truth)
Conflicts:      trustee-kbs
Conflicts:      trustee-as
Conflicts:      trustee-rvps

%description
Trustee is the attestation backend for confidential computing workloads.
This package provides Podman Quadlet configurations to run Trustee services
(KBS, Attestation Service, RVPS) as systemd-managed containers.

The container images are pulled from the official Red Hat registry,
ensuring a single source of truth for builds and security updates.

# Offline subpackage with embedded container image
%package        offline
Summary:        Trustee Quadlet with embedded container image for air-gapped environments
Requires:       %{name} = %{version}-%{release}

# This subpackage is architecture-specific because container images are arch-specific
# Override the noarch from main package
BuildArch:      x86_64

%description    offline
This package includes the Trustee container image embedded as a tarball,
enabling installation in air-gapped (disconnected) environments without
requiring network access to pull container images.

The embedded image is automatically loaded into podman's local storage
during package installation.

Note: This package is significantly larger (~95 MB) than the base package.
For connected environments, use the base trustee-quadlet package instead.

%prep
%autosetup -n %{name}-%{version}

%build
# Nothing to build - these are configuration files

%install
# Create directories
install -d %{buildroot}%{_sysconfdir}/containers/systemd
install -d %{buildroot}%{_sysconfdir}/trustee/kbs
install -d %{buildroot}%{_sysconfdir}/trustee/as
install -d %{buildroot}%{_sysconfdir}/trustee/rvps
install -d %{buildroot}%{_datadir}/%{name}
install -d %{buildroot}%{_datadir}/%{name}/images

# Install Quadlet files to /usr/share (vendor location, can be overridden in /etc)
# Following systemd convention: vendor files in /usr, user overrides in /etc
install -d %{buildroot}%{_datadir}/containers/systemd
install -m 0644 quadlet/*.container %{buildroot}%{_datadir}/containers/systemd/
install -m 0644 quadlet/*.network %{buildroot}%{_datadir}/containers/systemd/
install -m 0644 quadlet/*.volume %{buildroot}%{_datadir}/containers/systemd/

# Also install to /etc for user convenience (noreplace so upgrades don't overwrite)
install -m 0644 quadlet/*.container %{buildroot}%{_sysconfdir}/containers/systemd/
install -m 0644 quadlet/*.network %{buildroot}%{_sysconfdir}/containers/systemd/
install -m 0644 quadlet/*.volume %{buildroot}%{_sysconfdir}/containers/systemd/

# Install default configurations
install -m 0644 configs/kbs/config.toml %{buildroot}%{_sysconfdir}/trustee/kbs/
install -m 0644 configs/kbs/policy.rego %{buildroot}%{_sysconfdir}/trustee/kbs/
install -m 0644 configs/as/config.json %{buildroot}%{_sysconfdir}/trustee/as/
install -m 0644 configs/rvps/config.json %{buildroot}%{_sysconfdir}/trustee/rvps/

# Install embedded container image for offline subpackage (if present)
# The image tarball should be created during the build process:
#   podman pull registry.redhat.io/build-of-trustee/trustee-rhel9:latest
#   podman save -o images/trustee-rhel9.tar.gz registry.redhat.io/build-of-trustee/trustee-rhel9:latest
if [ -f images/trustee-rhel9.tar.gz ]; then
    install -m 0644 images/trustee-rhel9.tar.gz %{buildroot}%{_datadir}/%{name}/images/
fi

%post
# Reload systemd to pick up new Quadlet files
# Note: We don't use %systemd_post because Quadlet generates the units dynamically
systemctl daemon-reload >/dev/null 2>&1 || :

%preun
# Stop services before uninstall
if [ $1 -eq 0 ]; then
    systemctl stop trustee-kbs trustee-as trustee-rvps >/dev/null 2>&1 || :
fi

%postun
# Reload systemd after removal
if [ $1 -eq 0 ]; then
    systemctl daemon-reload >/dev/null 2>&1 || :
fi

# Offline subpackage scriptlets
%post offline
# Load the embedded container image into podman's local storage
if [ -f %{_datadir}/%{name}/images/trustee-rhel9.tar.gz ]; then
    echo "Loading Trustee container image into local storage..."
    podman load -i %{_datadir}/%{name}/images/trustee-rhel9.tar.gz >/dev/null 2>&1 || :
    echo "Container image loaded successfully."
fi

%preun offline
# Optionally remove the loaded image on uninstall
# Commented out by default to preserve user data
# if [ $1 -eq 0 ]; then
#     podman rmi registry.redhat.io/build-of-trustee/trustee-rhel9 >/dev/null 2>&1 || :
# fi

%files
%license LICENSE
%doc README.md

# Vendor Quadlet files (in /usr/share - the "defaults")
%dir %{_datadir}/containers
%dir %{_datadir}/containers/systemd
%{_datadir}/containers/systemd/trustee-kbs.container
%{_datadir}/containers/systemd/trustee-as.container
%{_datadir}/containers/systemd/trustee-rvps.container
%{_datadir}/containers/systemd/trustee.network
%{_datadir}/containers/systemd/kbs-config.volume
%{_datadir}/containers/systemd/kbs-data.volume
%{_datadir}/containers/systemd/as-config.volume
%{_datadir}/containers/systemd/rvps-config.volume
%{_datadir}/containers/systemd/rvps-data.volume

# User-customizable Quadlet files (in /etc - noreplace to preserve changes)
%config(noreplace) %{_sysconfdir}/containers/systemd/trustee-kbs.container
%config(noreplace) %{_sysconfdir}/containers/systemd/trustee-as.container
%config(noreplace) %{_sysconfdir}/containers/systemd/trustee-rvps.container
%config(noreplace) %{_sysconfdir}/containers/systemd/trustee.network
%config(noreplace) %{_sysconfdir}/containers/systemd/kbs-config.volume
%config(noreplace) %{_sysconfdir}/containers/systemd/kbs-data.volume
%config(noreplace) %{_sysconfdir}/containers/systemd/as-config.volume
%config(noreplace) %{_sysconfdir}/containers/systemd/rvps-config.volume
%config(noreplace) %{_sysconfdir}/containers/systemd/rvps-data.volume

# Configuration directories and files
%dir %{_sysconfdir}/trustee
%dir %{_sysconfdir}/trustee/kbs
%dir %{_sysconfdir}/trustee/as
%dir %{_sysconfdir}/trustee/rvps
%config(noreplace) %{_sysconfdir}/trustee/kbs/config.toml
%config(noreplace) %{_sysconfdir}/trustee/kbs/policy.rego
%config(noreplace) %{_sysconfdir}/trustee/as/config.json
%config(noreplace) %{_sysconfdir}/trustee/rvps/config.json

# Helper scripts directory
%dir %{_datadir}/%{name}

%files offline
%{_datadir}/%{name}/images/trustee-rhel9.tar.gz

%changelog
* Sun Dec 08 2024 Trustee Maintainers <trustee-maintainers@redhat.com> - 0.1.0-1
- Initial package
- Quadlet configurations for KBS, AS, and RVPS
- Default configuration files
- systemd integration via Podman Quadlet
- Added offline subpackage for air-gapped environments
