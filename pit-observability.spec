#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
Name: %(echo $NAME)
License: MIT
Summary: Daemon for running Nexus repository manager
BuildArch: x86_64
Version: 1.0.1
Release: 1
Source1: grok-exporter.service
Source2: prometheus.service
Source3: grafana.service
Source4: grok-exporter.sh
Source5: prometheus.sh
Source6: grafana.sh
Source7: config.yml
Source8: prometheus.yml
Source: %{name}-%{version}.tar.bz2
Vendor: Hewlett Packard Enterprise Development LP
BuildRequires: coreutils
BuildRequires: docker
BuildRequires: sed
BuildRequires: skopeo
BuildRequires: pkgconfig(systemd)
Requires: podman
Requires: podman-cni-config
%{?systemd_ordering}

%define imagedir %{_sharedstatedir}/cray/container-images/%{name}

%define current_branch %(echo ${GIT_BRANCH} | sed -e 's,/.*$,,')
# Grok-exporter
%define grok_tag   latest
%define grok_image artifactory.algol60.net/csm-docker/stable/docker.io/grok-exporter/grok-exporter:%{grok_tag}
%define grok_file  grok-%{grok_tag}.tar

# Prometheus
%define prometheus_tag  v2.36.1
%define prometheus_image artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/prometheus:%{prometheus_tag}
%define prometheus_file  prometheus-%{prometheus_tag}.tar

# Grafana
%define grafana_tag   8.5.9
%define grafana_image artifactory.algol60.net/csm-docker/stable/docker.io/grafana/grafana:%{grafana_tag}
%define grafana_file  grafana-%{grafana_tag}.tar

%define skopeo_tag   latest
%define skopeo_image quay.io/skopeo/stable
%define skopeo_file  skopeo-stable-%{skopeo_tag}.tar

%{!?_unitdir:
%define _unitdir /usr/lib/systemd/system
}

%if "%(echo ${IS_STABLE})" == "true"
%define bucket csm-docker/stable
%else
%define bucket csm-docker/unstable
%endif

%description
This RPM installs the daemon file for Nexus, launched through podman. This allows nexus to launch
as a systemd service on a system.

%prep
rm -fr "%{name}-%{version}"
mkdir "%{name}-%{version}"
cd "%{name}-%{version}"

%build  
# Grok-exporter
cp %{SOURCE1} grok-exporter.service
cp %{SOURCE7} config.yml
sed -e 's,@@grok-exporter-image@@,%{grok_image},g' \
    -e 's,@@grok-exporter-path@@,%{imagedir}/%{grok_file},g' \
    %{SOURCE4} > grok-exporter.sh \
# Prometheus
cp %{SOURCE2} prometheus.service
cp %{SOURCE8} prometheus.yml
sed -e 's,@@prometheus-image@@,%{prometheus_image},g' \
    -e 's,@@prometheus-path@@,%{imagedir}/%{prometheus_file},g' \
    %{SOURCE5} > prometheus.sh
# Grafana
cp %{SOURCE3} grafana.service
sed -e 's,@@grafana-image@@,%{grafana_image},g' \
    -e 's,@@grafana-path@@,%{imagedir}/%{grafana_file},g' \
    %{SOURCE6} > grafana.sh
# Consder switching to skopeo copy --all docker://<src> oci-archive:<dest>
skopeo --override-arch amd64 --override-os linux copy docker://%{grok_image}  docker-archive:%{grok_file}
skopeo --override-arch amd64 --override-os linux copy docker://%{prometheus_image}     docker-archive:%{prometheus_file}
skopeo --override-arch amd64 --override-os linux copy docker://%{grafana_image}        docker-archive:%{grafana_file}
skopeo --override-arch amd64 --override-os linux copy docker://%{skopeo_image}         docker-archive:%{skopeo_file}:%{skopeo_image}:%{skopeo_tag}

%install
install -D -m 0644 -t %{buildroot}%{_unitdir} grok-exporter.service
install -D -m 0644 -t %{buildroot}%{_unitdir} prometheus.service
install -D -m 0644 -t %{buildroot}%{_unitdir} grafana.service
install -D -m 0755 -t %{buildroot}%{_sbindir} grok-exporter.sh prometheus.sh grafana.sh config.yml prometheus.yml
install -D -m 0644 -t %{buildroot}%{imagedir} \
    %{grok_file} \
	%{prometheus_file} \
    %{grafana_file} \
    %{skopeo_file}

%clean
rm -f \
    grok-exporter.service \
    prometheus.service \
	grafana.service \
    grok-exporter.sh \
    prometheus.sh \
	grafana.sh \
        config.yml \
     prometheus.yml \
	%{grok_file} \
    %{prometheus_file} \
    %{grafana_file} \
    %{skopeo_file}

%pre
%service_add_pre grok-exporter.service
%service_add_pre prometheus.service
%service_add_pre grafana.service

%post
%service_add_post grok-exporter.service
%service_add_post prometheus.service
%service_add_post grafana.service

%preun
%service_del_preun grok-exporter.service
%service_del_preun prometheus.service
%service_del_preun grafana.service

%postun
%service_del_postun grok-exporter.service
%service_del_postun prometheus.service
%service_del_postun grafana.service

%files
%defattr(-,root,root)
%{_unitdir}/grok-exporter.service
%{_unitdir}/prometheus.service
%{_unitdir}/grafana.service
%{_sbindir}/grok-exporter.sh
%{_sbindir}/prometheus.sh
%{_sbindir}/grafana.sh
%{_sbindir}/config.yml
%{_sbindir}/prometheus.yml
%{imagedir}/%{grok_file}
%{imagedir}/%{prometheus_file}
%{imagedir}/%{grafana_file}
%{imagedir}/%{skopeo_file}

%changelog
