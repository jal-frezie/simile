# this is the instructions to build an RPM binary package. Put it in
# the SPECS directory of an rpmbuild tree, put a tarball of the Simile
# source in the SOURCES directory, and build with "rpmbuild -ba
# simile.spec"

Name:		simile
Version:	6.10
Release:	14%{?dist}
Summary:	Multi-paradigm graphical modelling environment

License:	Proprietary
URL:		http://simulistics.com
source:		simile_6.10.14.tar.gz

BuildRequires:  gcc-c++ >= 4.0, gprolog >= 1.4.0, tcl-devel >= 8.5, tk-devel >= 8.5, gdal-devel >= 1.5
# tk needed for building tkdnd and tktable
Requires:       tk >= 8.5, gcc-c++ >= 4.0, tcl-tclxml >= 3.2, tcllib >= 1.11, tklib >= 0.5, itcl >= 3.3, tcl-trf >= 2.1, tkimg >= 1.3, sox >= 14.0

%description 
Multi-paradigm modelling and simulation software for complex dynamic
systems in the earth, environmental and life sciences. We use unique
logic-based declarative modelling technology to represent the
interactions in these systems in a clearly structured, visually
intuitive way.


%prep
%setup -q -n simile-%{version}
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
* Sun Jun 07 2020 Simulistics Ltd <info@simulistics.com> - 6.10-14
- Patch release

* Thu May 28 2020 Simulistics Ltd <info@simulistics.com> - 6.10-13
- Patch release

* Thu May 21 2020 Simulistics Ltd <info@simulistics.com> - 6.10-12
- Patch release

* Fri Apr 03 2020 Simulistics Ltd <info@simulistics.com> - 6.10-9
- Patch release

* Mon Mar 09 2020 Simulistics Ltd <info@simulistics.com> - 6.10-8
- Patch release

* Fri Jan 31 2020 Simulistics Ltd <info@simulistics.com> - 6.10-7
- Patch release

* Fri Dec 20 2019 Simulistics Ltd <info@simulistics.com> - 6.10-6
- Patch release

* Fri Nov 29 2019 Simulistics Ltd <info@simulistics.com> - 6.10-5
- Patch release

* Fri Sep 06 2019 Simulistics Ltd <info@simulistics.com> - 6.10-4
- Patch release

* Thu Jul 25 2019 Simulistics Ltd <info@simulistics.com> - 6.10-3
- Patch release

* Fri Jun 21 2019 Simulistics Ltd <info@simulistics.com> - 6.10-1
- Patch release

* Mon Jun 10 2019 Simulistics Ltd <info@simulistics.com> - 6.10-0
- Minor release

* Tue Apr 23 2019 Simulistics Ltd <info@simulistics.com> - 6.9-13
- Patch release

* Wed Mar 06 2019 Simulistics Ltd <info@simulistics.com> - 6.9-12
- Patch release

* Thu Dec 13 2018 Simulistics Ltd <info@simulistics.com> - 6.9-11
- Patch release

* Mon Nov 26 2018 Simulistics Ltd <info@simulistics.com> - 6.9-10
- Patch release

* Thu Aug 23 2018 Simulistics Ltd <info@simulistics.com> - 6.9-9
- Patch release

* Wed Jun 27 2018 Simulistics Ltd <info@simulistics.com> - 6.9-8
- Patch release

* Thu May 24 2018 Simulistics Ltd <info@simulistics.com> - 6.9-7
- Patch release

* Mon Apr 30 2018 Simulistics Ltd <info@simulistics.com> - 6.9-5
- Patch release

* Mon Mar 19 2018 Simulistics Ltd <info@simulistics.com> - 6.9-4
- Patch release

* Tue Mar 06 2018 Simulistics Ltd <info@simulistics.com> - 6.9-3
- Patch release

* Thu Feb 15 2018 Simulistics Ltd <info@simulistics.com> - 6.9-2
- Patch release

* Tue Jan 09 2018 Simulistics Ltd <info@simulistics.com> - 6.9-0
- Minor release

* Mon Dec 04 2017 Simulistics Ltd <info@simulistics.com> - 6.8-10
- Patch release

* Mon Nov 06 2017 Simulistics Ltd <info@simulistics.com> - 6.8-9
- Patch release

* Thu Oct 05 2017 Simulistics Ltd <info@simulistics.com> - 6.8-8
- Patch release

* Tue Sep 12 2017 Simulistics Ltd <info@simulistics.com> - 6.8-7
- Patch release

* Fri Aug 25 2017 Simulistics Ltd <info@simulistics.com> - 6.8-6
- Patch release

* Mon Aug 14 2017 Simulistics Ltd <info@simulistics.com> - 6.8-5
- Patch release

* Tue Jul 04 2017 Simulistics Ltd <info@simulistics.com> - 6.8-4
- Patch release

* Tue May 30 2017 Simulistics Ltd <info@simulistics.com> - 6.8-3
- Patch release

* Tue Apr 04 2017 Simulistics Ltd <info@simulistics.com> - 6.8-2
- Patch release

* Fri Mar 17 2017 Simulistics Ltd <info@simulistics.com> - 6.8-1
- Patch release

* Tue Feb 14 2017 Simulistics Ltd <info@simulistics.com> - 6.8-0
- Minor release

* Wed Jan 25 2017 Simulistics Ltd <info@simulistics.com> - 6.7-7
- Patch release

* Wed Dec 14 2016 Simulistics Ltd <info@simulistics.com> - 6.7-6
- Patch release

* Mon Oct 17 2016 Simulistics Ltd <info@simulistics.com> - 6.7-5
- Patch release

* Thu Sep 08 2016 Simulistics Ltd <info@simulistics.com> - 6.7-4
- Patch release

* Sun Jul 17 2016 Simulistics Ltd <info@simulistics.com> - 6.7-2
- Patch release

* Tue Jul 05 2016 Simulistics Ltd <info@simulistics.com> - 6.7-1
- Patch release

* Thu Jun 09 2016 Simulistics Ltd <info@simulistics.com> - 6.7-0
- Minor release

* Fri Feb 26 2016 Simulistics Ltd <info@simulistics.com> - 6.6-3
- Patch release

* Sat Feb 06 2016 Simulistics Ltd <info@simulistics.com> - 6.6-2
- Patch release

* Tue Feb 02 2016 Simulistics Ltd <info@simulistics.com> - 6.6-1
- Patch release

* Tue Dec 22 2015 Simulistics Ltd <info@simulistics.com> - 6.6-0
- Minor release

* Fri Aug 21 2015 Simulistics Ltd <info@simulistics.com> - 6.5-1
- Patch release

* Wed Jul 01 2015 Simulistics Ltd <info@simulistics.com> - 6.5-0
- Minor release

* Wed Apr 29 2015 Simulistics Ltd <info@simulistics.com> - 6.4-1
- Patch release

* Tue Apr 07 2015 Simulistics Ltd <info@simulistics.com> - 6.4-0
- Minor release

* Mon Jan 19 2015 Simulistics Ltd <info@simulistics.com> - 6.3-2
- Patch release

* Fri Nov 07 2014 Simulistics Ltd <info@simulistics.com> - 6.3-1
- Patch release

* Mon Oct 20 2014 Simulistics Ltd <info@simulistics.com> - 6.3-0
- Minor release

* Wed Aug 13 2014 Simulistics Ltd <info@simulistics.com> - 6.2-0
- Minor release

* Fri May 23 2014 Simulistics Ltd <info@simulistics.com> - 6.1-3
- Patch release

* Thu Mar 27 2014 Simulistics Ltd <info@simulistics.com> - 6.1-2
- rebuilt

* Thu Feb 06 2014 Simulistics Ltd <info@simulistics.com> - 6.1-1
- Patch release

* Tue Nov 05 2013 Simulistics Ltd <info@simulistics.com> - 6.1-0
- Initial version of the package
