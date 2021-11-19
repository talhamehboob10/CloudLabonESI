%define module emulab-ipod-dkms

Summary: Emulab IPOD ping-of-death DKMS kernel module
Name: %{module}
Version: 3.3.0
License: GPL
Release: 0
BuildArch: noarch
Requires: dkms gcc kernel-devel

%description
Emulab IPOD ping-of-death DKMS kernel module

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/src/%{module}-%{version}/
cp %{_sourcedir}/Makefile %{buildroot}/usr/src/%{module}-%{version}
cp %{_sourcedir}/ipod.c %{buildroot}/usr/src/%{module}-%{version}
cp %{_sourcedir}/emulab-ipod-dkms.conf %{buildroot}/usr/src/%{module}-%{version}/dkms.conf

%clean
rm -rf %{buildroot}

%files
%defattr(0644,root,root)
%attr(0755,root,root) /usr/src/%{module}-%{version}/

%post
occurrences=`/usr/sbin/dkms status | grep "%{module}" | grep "%{version}" | wc -l`
if [ $occurrences -eq 0 ]; then
    /usr/sbin/dkms add -m %{module} -v %{version}
fi
/usr/sbin/dkms build -m %{module} -v %{version}
/usr/sbin/dkms install -m %{module} -v %{version}
exit 0

%preun
/usr/sbin/dkms remove -m %{module} -v %{version} --all
exit 0

%changelog
* Tue Nov 12 2019 David M. Johnson <johnsond@flux.utah.edu> 3.3.0-0
- Update Emulab IPOD DKMS kernel module to version 3.3.0.

* Mon Feb 04 2019 David M. Johnson <johnsond@flux.utah.edu> 3.2.0-0
- Update Emulab IPOD DKMS kernel module to version 3.2.0.

* Wed Sep 05 2018 David M. Johnson <johnsond@flux.utah.edu> 3.0.0-0
- Initial release of Emulab IPOD kernel module DKMS support.
