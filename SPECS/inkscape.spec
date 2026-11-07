# Inkscape RPM specification for AlmaLinux 10
# Target architecture: x86_64

Name:           inkscape
Version:        %{pkg_version}
Release:        1%{?dist}
Summary:        Vector graphics editor

License:        GPL-2.0-or-later
URL:            https://inkscape.org/

Source0:        inkscape-%{version}.tar.xz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  gettext
BuildRequires:  desktop-file-utils
BuildRequires:  double-conversion-devel
BuildRequires:  gtk3-devel
BuildRequires:  gdk-pixbuf2-devel
BuildRequires:  cairo-devel
BuildRequires:  fontconfig-devel
BuildRequires:  freetype-devel
BuildRequires:  pango-devel
BuildRequires:  libxml2-devel
BuildRequires:  libpng-devel
BuildRequires:  zlib-devel
BuildRequires:  gsl-devel
BuildRequires:  gc-devel
BuildRequires:  lcms2-devel
BuildRequires:  potrace-devel
BuildRequires:  poppler-devel
BuildRequires:  glibmm2.4-devel
BuildRequires:  gtkmm3.0-devel
BuildRequires:  boost-devel
BuildRequires:  libxslt-devel
BuildRequires:  poppler-glib-devel
BuildRequires:  chrpath
BuildRequires:  binutils

Requires:       hicolor-icon-theme

%description
Inkscape is a professional vector graphics editor.
It supports the SVG file format and provides tools for
illustration, diagramming, technical drawing and design.

This package is built as a native RPM for AlmaLinux 10.

%prep
%autosetup -n inkscape-%{version} -p1

%build
echo
echo "========================================"
echo "Pango / pangomm build environment diagnostics"
echo "========================================"

echo
echo "===== Installed package versions ====="
rpm -q pangomm glibmm2.4 pango

echo
echo "===== pangomm library ====="
ldconfig -p | grep 'libpangomm-1.4.so.1' || true

echo
echo "===== pangomm wrapper symbols ====="
if [ -f /lib64/libpangomm-1.4.so.1 ]; then
    nm -D -C /lib64/libpangomm-1.4.so.1 | \
        grep -E 'wrap.*FontMap|FontMap.*wrap|PangoFT2FontMap' || true
else
    echo "pangomm library not found at /lib64/libpangomm-1.4.so.1"
fi

echo
echo "===== Pango libraries ====="
ldconfig -p | grep -E 'libpango(ft2|cairo)?-1.0.so' || true

echo
echo "===== pangomm dependencies ====="
if [ -f /lib64/libpangomm-1.4.so.1 ]; then
    ldd /lib64/libpangomm-1.4.so.1
fi

echo
echo "========================================"
echo "End of Pango diagnostics"
echo "========================================"
echo

%cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=%{_prefix} \
    -DCMAKE_INSTALL_LIBDIR=%{_lib} \
    -DCMAKE_INSTALL_SYSCONFDIR=%{_sysconfdir} \
    -DCMAKE_SKIP_RPATH=ON \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=OFF \
    -DCMAKE_INSTALL_RPATH=""

%cmake_build --verbose

%install
%cmake_install

# Register Inkscape's private library directory with the dynamic linker.
mkdir -p %{buildroot}%{_sysconfdir}/ld.so.conf.d
echo "%{_libdir}/inkscape" > \
    %{buildroot}%{_sysconfdir}/ld.so.conf.d/inkscape.conf

# Remove RPATH/RUNPATH from installed shared libraries.
find %{buildroot}%{_libdir} -type f -name '*.so*' -exec \
    chrpath -d {} \; 2>/dev/null || :

# Verify that no RPATH/RUNPATH entries remain.
if find %{buildroot}%{_libdir} -type f -name '*.so*' -exec \
    sh -c 'readelf -d "$1" 2>/dev/null | grep -Eq "\(RPATH\)|\(RUNPATH\)"' _ {} \; \
    -print | grep -q .; then
    echo "ERROR: RPATH/RUNPATH detected in installed libraries"
    exit 1
fi

# Remove 2Geom development files.
rm -rf %{buildroot}%{_includedir}/2geom-*
rm -rf %{buildroot}%{_libdir}/cmake/2Geom
rm -f  %{buildroot}%{_libdir}/pkgconfig/2geom.pc
rm -f  %{buildroot}%{_libdir}/lib2geom.so

%find_lang inkscape

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files -f inkscape.lang
%license COPYING
%doc README.md

# Executables
%{_bindir}/inkscape
%{_bindir}/inkview

# Inkscape runtime libraries
%{_libdir}/inkscape/

# 2Geom runtime library
%{_libdir}/lib2geom.so.*

# Dynamic linker configuration
%config(noreplace) %{_sysconfdir}/ld.so.conf.d/inkscape.conf

# Desktop integration
%{_datadir}/applications/*
%{_datadir}/bash-completion/completions/inkscape
%{_datadir}/icons/hicolor/*
%{_datadir}/inkscape/
%{_datadir}/metainfo/*

# Man pages
%{_mandir}/man1/inkscape.1*
%{_mandir}/man1/inkview.1*
%{_mandir}/*/man1/inkscape.1*
%{_mandir}/*/man1/inkview.1*

%changelog
* %{build_date} AlmaLinux Inkscape - %{version}-%{release}
- Initial AlmaLinux 10 RPM packaging
- Disable RPATH during CMake configuration
- Remove bundled 2Geom development files
- Package 2Geom runtime library
- Register Inkscape private library directory with ldconfig
- Package Inkscape runtime libraries and bash completion
