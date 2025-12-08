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

%changelog
* Sun Dec 08 2024 Trustee Maintainers <trustee-maintainers@redhat.com> - 0.1.0-1
- Initial package
- Quadlet configurations for KBS, AS, and RVPS
- Default configuration files
- systemd integration via Podman Quadlet
