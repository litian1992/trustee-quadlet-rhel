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

# Runtime dependencies
Requires:       podman >= 4.4
Requires:       systemd
Requires:       container-selinux

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

%package        selinux
Summary:        SELinux policy for Trustee Quadlet
Requires:       %{name} = %{version}-%{release}
Requires:       selinux-policy
Requires:       policycoreutils

%description    selinux
SELinux policy module for running Trustee services via Podman Quadlet.
This package provides additional SELinux contexts and policies for
secure operation in enforcing mode.

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
install -d %{buildroot}%{_docdir}/%{name}

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
install -m 0644 configs/kbs/* %{buildroot}%{_sysconfdir}/trustee/kbs/
install -m 0644 configs/as/* %{buildroot}%{_sysconfdir}/trustee/as/
install -m 0644 configs/rvps/* %{buildroot}%{_sysconfdir}/trustee/rvps/

# Install documentation
install -m 0644 README.md %{buildroot}%{_docdir}/%{name}/
install -m 0644 docs/*.md %{buildroot}%{_docdir}/%{name}/ 2>/dev/null || true

# Install helper scripts
install -m 0755 scripts/* %{buildroot}%{_datadir}/%{name}/ 2>/dev/null || true

%post
# Reload systemd to pick up new Quadlet files
systemctl daemon-reload

# Pull container images (optional, can be slow)
echo "To pull container images now, run:"
echo "  podman pull registry.redhat.io/rhtas/trustee-kbs:latest"
echo "  podman pull registry.redhat.io/rhtas/trustee-as:latest"
echo "  podman pull registry.redhat.io/rhtas/trustee-rvps:latest"
echo ""
echo "To start Trustee services:"
echo "  systemctl start trustee-kbs"
echo ""
echo "Configuration files are in /etc/trustee/"

%preun
# Stop services before uninstall
if [ $1 -eq 0 ]; then
    systemctl stop trustee-kbs trustee-as trustee-rvps 2>/dev/null || true
fi

%postun
# Reload systemd after removal
if [ $1 -eq 0 ]; then
    systemctl daemon-reload
fi

%files
%license LICENSE
%doc %{_docdir}/%{name}

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

# Configuration directories (noreplace to preserve user changes)
%dir %{_sysconfdir}/trustee
%dir %{_sysconfdir}/trustee/kbs
%dir %{_sysconfdir}/trustee/as
%dir %{_sysconfdir}/trustee/rvps
%config(noreplace) %{_sysconfdir}/trustee/kbs/*
%config(noreplace) %{_sysconfdir}/trustee/as/*
%config(noreplace) %{_sysconfdir}/trustee/rvps/*

# Helper scripts
%{_datadir}/%{name}

%files selinux
# SELinux policy files would go here
# %{_datadir}/selinux/packages/%{name}.pp

%changelog
* Mon Dec 02 2024 Trustee Maintainers <trustee-maintainers@redhat.com> - 0.1.0-1
- Initial package
- Quadlet configurations for KBS, AS, and RVPS
- Default configuration files
- systemd integration
