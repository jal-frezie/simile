# this is the instructions to build an RPM binary package. Put it in
# the SPECS directory of an rpmbuild tree, put a tarball of the Simile
# source in the SOURCES directory, and build with "rpmbuild -ba
# simile.spec"

Name:		simile
Version:	7.4
Release:	0%{?dist}
Summary:	Multi-paradigm graphical modelling environment

License:	Proprietary
URL:		http://simulistics.com
source:		simile_7.4.0.tar.gz

BuildRequires:  gcc-c++ >= 4.0, gprolog >= 1.4.0, redhat-lsb, tcl-devel >= 9.0, tk-devel >= 9.0, tcllib >= 2.0, libXcursor-devel >= 1.0, portaudio-devel >= 19
# tk needed for building tktable, tcllib for dtplite
Requires:       tk >= 8.5, gcc-c++ >= 4.0, tcl-tclxml >= 3.2, tcllib >= 1.11, tklib >= 0.5, tkimg >= 1.3, portaudio >= 19, tkdnd >= 2.8

%description 
Multi-paradigm modelling and simulation software for complex dynamic
systems in the earth, environmental and life sciences. We use unique
logic-based declarative modelling technology to represent the
interactions in these systems in a clearly structured, visually
intuitive way.

%define debug_package %{nil}

%prep
%setup -q -n simile
# The above unpacks the file specified by "source" above. If CVS/Drupal/Exts
# have changed, unpack it manually, update and repack before building.

%build
make -j8
# cd Extensions/tkdnd
# Fedora has had good tktable since f24 so no longer needed
# %configure
# make -j8
# this configures and makes the bundled tkdnd
cd Extensions/tktable
./configure --with-tcl=%{_libdir} --with-tk=%{_libdir}
make -j8
cd ../tcl-gdal
make -j8
cd ../..


%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT LIBDIR=%{_libdir} install
# cd Extensions/tkdnd
# make DESTDIR=$RPM_BUILD_ROOT libdir=%{_libdir}/%{name}-%{version}/System/lib/Stubs install
# rm %{_mandir}/mann/tkDND.n.gz
# untested -- remove docs after installing rather than adjusting makefile
cd Extensions/tktable
make DESTDIR=$RPM_BUILD_ROOT libdir=%{_libdir}/%{name}-%{version}/System/lib/Stubs install
# rm %{_mandir}/mann/tkTable.n.gz
# path too long and 64 not xplat -- keep in Extensions?
cd ..
cp -R tablelist* ${RPM_BUILD_ROOT}%{_libdir}/%{name}-%{version}/System/lib/Stubs
cd -

%files
%{_bindir}/%{name}
%{_libdir}/%{name}-%{version}/*
/usr/share/%{name}-%{version}/*
/usr/share/applications/%{name}.desktop

%doc
%{_mandir}/man1/simile.1.gz
# %%{_mandir}/mann/tkDND.n.gz
%{_mandir}/mann/tkTable.n.gz
# last two should be removed to avoid conflict with real package


%changelog
* Tue Mar 24 2026 Simulistics Ltd <info@simulistics.com> - 7.4-0
- Minor release

* Mon Dec 29 2025 Simulistics Ltd <info@simulistics.com> - 7.3-6
- Patch release

* Fri Oct 17 2025 Simulistics Ltd <info@simulistics.com> - 7.3-5
- Patch release

* Sun Aug 10 2025 Simulistics Ltd <info@simulistics.com> - 7.3-4
- Patch release

* Sun Jul 13 2025 Simulistics Ltd <info@simulistics.com> - 7.3-3
- Patch release

* Sun Jun 22 2025 Simulistics Ltd <info@simulistics.com> - 7.3-1
- Patch release

* Thu Jun 12 2025 Simulistics Ltd <info@simulistics.com> - 7.3-0
- Minor release

* Fri Apr 11 2025 Simulistics Ltd <info@simulistics.com> - 7.2-9
- Patch release

* Wed Mar 26 2025 Simulistics Ltd <info@simulistics.com> - 7.2-8
- Patch release

* Wed Mar 12 2025 Simulistics Ltd <info@simulistics.com> - 7.2-7
- Patch release

* Mon Feb 10 2025 Simulistics Ltd <info@simulistics.com> - 7.2-6
- Patch release

* Fri Jan 10 2025 Simulistics Ltd <info@simulistics.com> - 7.2-5
- Patch release

* Sat Nov 30 2024 Simulistics Ltd <info@simulistics.com> - 7.2-4
- Patch release

* Mon Nov 25 2024 Simulistics Ltd <info@simulistics.com> - 7.2-3
- Patch release

* Thu Oct 10 2024 Simulistics Ltd <info@simulistics.com> - 7.2-2
- Patch release

* Fri Sep 13 2024 Simulistics Ltd <info@simulistics.com> - 7.2-1
- Patch release

* Thu Aug 01 2024 Simulistics Ltd <info@simulistics.com> - 7.2-0
- Minor release

* Tue Jun 11 2024 Simulistics Ltd <info@simulistics.com> - 7.1-7
- Patch release

* Mon May 20 2024 Simulistics Ltd <info@simulistics.com> - 7.1-6
- Patch release

* Thu May 09 2024 Simulistics Ltd <info@simulistics.com> - 7.1-5
- Patch release

* Thu Apr 25 2024 Simulistics Ltd <info@simulistics.com> - 7.1-4
- Patch release

* Fri Apr 05 2024 Simulistics Ltd <info@simulistics.com> - 7.1-3
- Patch release

* Mon Feb 26 2024 Simulistics Ltd <info@simulistics.com> - 7.1-2
- Patch release

* Wed Jan 24 2024 Simulistics Ltd <info@simulistics.com> - 7.1-1
- Patch release

* Fri Oct 06 2023 Simulistics Ltd <info@simulistics.com> - 7.1-0
- Minor release

* Thu Sep 21 2023 Simulistics Ltd <info@simulistics.com> - 7.0-11
- Patch release

* Fri Sep 08 2023 Simulistics Ltd <info@simulistics.com> - 7.0-10
- Patch release

* Mon Aug 07 2023 Simulistics Ltd <info@simulistics.com> - 7.0-9
- Patch release

* Sun Jul 16 2023 Simulistics Ltd <info@simulistics.com> - 7.0-8
- Patch release

* Tue Jun 27 2023 Simulistics Ltd <info@simulistics.com> - 7.0-7
- Patch release

* Tue Jun 06 2023 Simulistics Ltd <info@simulistics.com> - 7.0-6
- Patch release

* Wed May 17 2023 Simulistics Ltd <info@simulistics.com> - 7.0-5
- Patch release

* Mon Apr 24 2023 Simulistics Ltd <info@simulistics.com> - 7.0-4
- Patch release

* Thu Mar 02 2023 Simulistics Ltd <info@simulistics.com> - 7.0-3
- Patch release

* Tue Jan 24 2023 Simulistics Ltd <info@simulistics.com> - 7.0-1
- Initial version of the package
