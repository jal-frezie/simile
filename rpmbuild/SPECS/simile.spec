# this is the instructions to build an RPM binary package. Put it in
# the SPECS directory of an rpmbuild tree, put a tarball of the Simile
# source in the SOURCES directory, and build with "rpmbuild -ba
# simile.spec"

Name:		simile
Version:	7.0
Release:	97%{?dist}
Summary:	Multi-paradigm graphical modelling environment

License:	Proprietary
URL:		http://simulistics.com
source:		simile_7.0.0.tar.gz

BuildRequires:  gcc-c++ >= 4.0, gprolog >= 1.4.0, tcl-devel >= 8.5, tk-devel >= 8.5, gdal-devel >= 1.5
# tk needed for building tkdnd and tktable
Requires:       tk >= 8.5, gcc-c++ >= 4.0, tcl-tclxml >= 3.2, tcllib >= 1.11, tklib >= 0.5, itcl >= 3.3, tcl-trf >= 2.1, tkimg >= 1.3

%description 
Multi-paradigm modelling and simulation software for complex dynamic
systems in the earth, environmental and life sciences. We use unique
logic-based declarative modelling technology to represent the
interactions in these systems in a clearly structured, visually
intuitive way.


%prep
%setup -q -n simile
# The above unpacks the file specified by "source" above. If CVS/Drupal/Exts
# have changed, unpack it manually, update and repack before building.

%build
make -j6
cd Extensions/tkdnd
%configure
make -j6
# this configures and makes the bundled tkdnd
cd ../Tktable2.10
./configure --with-tcl=%{_libdir} --with-tk=%{_libdir}
make -j6
cd ../tcl-gdal
make -j6
cd ../..


%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT LIBDIR=%{_libdir} install
cd Extensions/tkdnd
make DESTDIR=$RPM_BUILD_ROOT libdir=%{_libdir}/%{name}-%{version}/System/lib/Stubs install
cd ../Tktable2.10
make DESTDIR=$RPM_BUILD_ROOT libdir=%{_libdir}/%{name}-%{version}/System/lib/Stubs install
# path too long and 64 not xplat -- keep in Extensions?
cd -

%files
%{_bindir}/%{name}
%{_libdir}/%{name}-%{version}/*
/usr/share/%{name}-%{version}/*
/usr/share/applications/%{name}.desktop

%doc
%{_mandir}/man1/simile.1.gz
# %{_mandir}/mann/tkDND.n.gz
# removed to avoid conflict with real package


%changelog
* Mon Oct 11 2021 Simulistics Ltd <info@simulistics.com> - 7.0-0
- Initial version of the package
