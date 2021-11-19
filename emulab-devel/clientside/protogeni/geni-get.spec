Summary:        Retrieve GENI information about the current sliver
Name:           geni-get
Version:        1.0
Release:        1%{?dist}
License:        GENI Public License
Group:          Applications/System
BuildArch:      noarch
Source0:        geni-get
Requires:       python

%description
Retrieve GENI information about the current sliver.

%prep
cp %SOURCE0 .
%build
%check
%install
mkdir -p %{buildroot}/usr/bin
cp geni-get %{buildroot}/usr/bin/
%clean
%files
/usr/bin/geni-get
%changelog
