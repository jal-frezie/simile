UNAME = $(shell uname)
ifeq ($(MY_CPU),x86_64)
BITEXTN = 64
else
BITEXTN = 
endif

ifeq ($(UNAME),Msys)
	GCCCMD = gcc -O3
	GPPCMD = g++ -O3
	SHAREDLIBPREFX = 
	SHAREDLIBEXTN = .dll
	EXECEXTN = .exe
	TCLDIR = /usr/local$(BITEXTN)
else ifeq ($(UNAME),Darwin)
	GCCCMD = gcc -O3 -mmacosx-version-min=10.13 -arch x86_64 -arch arm64
	GPPCMD = g++ -O3 -mmacosx-version-min=10.13 -arch x86_64 -arch arm64
	SHAREDLIBPREFX = lib
	SHAREDLIBEXTN = .dylib
	EXECEXTN =
	TCLDIR = /usr
else # linux
	DISTRO = $(shell lsb_release -is)
	CC = gcc
	CXX = g++
ifneq (,$(filter $(DISTRO),Debian Ubuntu))
	CC = $(DEB_HOST_GNU_TYPE)-gcc
	CXX = $(DEB_HOST_GNU_TYPE)-g++
else
	NOVERS = 1
endif
	GCCCMD = $(CC) -O3
	GPPCMD = $(CXX) -O3
	SHAREDLIBPREFX = lib
	SHAREDLIBEXTN = .so
	EXECEXTN =
	TCLDIR = /usr
endif
VERSION = $(shell echo "puts [info tclversion]" | $(TCLDIR)/bin/tclsh)
ifeq ($(UNAME),Msys)
	VERS = $(subst .,,$(VERSION))
else
ifneq ($(NOVERS),1)
	VERS = $(VERSION)
endif
endif
USETCL = -DUSE_TCL_STUBS -I$(TCLDIR)/include/tcl$(VERSION) -L$(TCLDIR)/lib -ltclstub$(VERS)

gdal: $(SHAREDLIBPREFX)gdal_tcl$(SHAREDLIBEXTN)

libgdal_tcl.so: gdal_tcl.c gdal_tcl.h
	$(GCCCMD) -fPIC -shared -o libgdal_tcl.so gdal_tcl.c $(USETCL)

gdal_tcl.dll: gdal_tcl.c gdal_tcl.h
	$(GCCCMD) -shared -o gdal_tcl.dll gdal_tcl.c $(USETCL) -I/usr/local$(BITEXTN)/include -L/usr/local$(BITEXTN)/lib -lgdal_i

# Mac: Try to build a fattie (will fail to build for intel on ppc)
libgdal_tcl.dylib: gdal_tcl.c gdal_tcl.h
	$(GCCCMD) -fPIC -DMACOS -dynamiclib \
		-o libgdal_tcl.dylib gdal_tcl.c \
		-DUSE_TCL_STUBS -F/System/Library/Frameworks -framework Tcl

install:
	mkdir -p $(DESTDIR)$(libdir)/tcl-gdal; \
	cp libgdal_tcl.so pkgIndex.tcl $(DESTDIR)$(libdir)/tcl-gdal

clean:
	rm -f $(SHAREDLIBPREFX)gdal_tcl$(SHAREDLIBEXTN)
