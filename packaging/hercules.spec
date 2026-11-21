Name:           hercules
Version:        %{?hercules_version}%{!?hercules_version:4.9.1}
Release:        %{?hercules_release}%{!?hercules_release:ZWIEGNET.1.el10}
Summary:        SDL Hercules System/370, ESA/390 and z/Architecture emulator
License:        QPL
URL:            https://www.hercules-390.eu/
Source0:        %{name}-%{version}.tar.gz
Source1:        hercules.1
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  libtool-ltdl-devel
BuildRequires:  ncurses-devel
BuildRequires:  zlib-devel
BuildRequires:  bzip2-devel
BuildRequires:  openssl-devel
BuildRequires:  curl-devel

%description
SDL Hercules emulates IBM System/370, ESA/390 and 64-bit z/Architecture
mainframe hardware, including processors, storage, channels and I/O devices.

%prep
%setup -q -n hercules

%build
CFLAGS="%{optflags}" ./configure \
    --prefix=%{_prefix} \
    --exec-prefix=%{_exec_prefix} \
    --bindir=%{_bindir} \
    --sbindir=%{_sbindir} \
    --sysconfdir=%{_sysconfdir}/hercules \
    --datadir=%{_datadir}/hercules \
    --includedir=%{_includedir}/hercules \
    --libdir=%{_libdir}/hercules \
    --libexecdir=%{_libexecdir}/hercules \
    --localstatedir=%{_localstatedir}/lib/hercules
%make_build

%install
rm -rf %{buildroot}
%make_install DESTDIR=%{buildroot}
install -Dpm 0644 %{SOURCE1} %{buildroot}%{_mandir}/man1/hercules.1
find %{buildroot} -type f ! -name '*.la' ! -path '%{buildroot}%{_mandir}/man1/hercules.1' -printf '/%%P\n' | sort > %{_builddir}/hercules-filelist
find %{buildroot} -type l -printf '/%%P\n' | sort >> %{_builddir}/hercules-filelist

%files -f %{_builddir}/hercules-filelist
%license COPYRIGHT
%doc README.md BUILDING CHANGES
%{_mandir}/man1/hercules.1*
