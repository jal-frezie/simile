# These are the settings for the particular version we want to make
# edition: evaluation, teaching, standard or enterprise
EDN = STANDARD
# date of final expiry: "hh:mm D M Y" or "" for permanent
ABS_EXP = ""
# days after install: 0 for no installation expiry
REL_EXP = 0
# License code required to verify name/corp/edition: 0 for no
LICENSED = 1
# Prolog implementation to use -- SICSTUS for Windows releases, GNU otherwise
PROLOG = GNU

ifeq ($(ABS_EXP),"")
	EXP_TICKS = 0
else
	EXP_TICKS = $(shell date +%s -d $(ABS_EXP))
endif

DEFNS=-DUSE_TCL_STUBS -DSIM_FINAL_EXPIRY=$(EXP_TICKS) -DSIM_DAYS_AFTER_INSTALL=$(REL_EXP) -DSIM_$(EDN)

ifeq ($(LICENSED),1)
	DEFNS += -DSIM_LICENSED
endif

# set the following as required for your system,
# some execs may be on the path
# Updating with a clean copy from CVS will overwrite!
# Normal updating (merging) from the CVS will conserve the
# customisation - though conflicts may, of course, occur.
# could require execs to be in PATH, sicstus, gplc, gcc/g++
# default *nix variables overwritten in special cases
GCCCMD = gcc
GPPCMD = g++
OPT = -O3

UNAME = $(shell uname)
ifeq ($(UNAME),CYGWIN_NT-5.1)
	UNAME = CYGWIN_NT
endif 
ifeq ($(UNAME),CYGWIN_NT-5.0)
	UNAME = CYGWIN_NT
endif 
ifeq ($(UNAME),MINGW32_NT-5.1)
	UNAME = MINGW32_NT
endif 
ifeq ($(UNAME),MINGW32_NT-5.0)
	UNAME = MINGW32_NT
endif 

# Default case: any Windows, any toolchain
	# GCCCMD = "$(shell pwd)/System/bin/g++" # can't find process.h
	FLAGS = $(OPT)
	SLDIR = bin
	SHAREDLIBPREFX = 
	VERS = 84
	SHAREDLIBEXTN = .dll
	ARCHEXTN = .exe
	INSTLIB = Run/install.dll
	MAIN = System/bin/Simile.exe
ifeq ($(UNAME),Darwin)
	FLAGS = $(OPT) -mmacosx-version-min=10.3
	ARCHEXTN = _$(shell uname -m)
	ifeq ($(ARCHEXTN),_Power Macintosh)
		ARCHEXTN = _ppc
	endif
	SLDIR = lib
	SHAREDLIBPREFX = lib
	VERS = 8.4
	SHAREDLIBEXTN = $(ARCHEXTN).dylib
	INSTLIB = 
	MAIN = 
endif 
ifeq ($(UNAME),Linux)
	FLAGS = $(OPT) -m32
	SLDIR = lib
	SHAREDLIBPREFX = lib
	VERS = 8.4
	SHAREDLIBEXTN = .so
	ARCHEXTN =
	INSTLIB = 
	MAIN = 
endif

PROLOGSTATE = Run/xgsimile$(ARCHEXTN)
ifeq ($(PROLOG),SICSTUS)
	PROLOGSTATE = System/bin/main.sav
endif

SHIM = System/lib/Stubs/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN)

simile: $(PROLOGSTATE) System/bin/relay$(ARCHEXTN) $(SHIM) \
	System/$(SLDIR)/$(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN) $(INSTLIB) $(MAIN)

ifeq ($(ARCHEXTN),_i386)
# this saves going on the ppc mac to make the object files for each edition --
# still need it to make Gnu Prolog executable though
PPCSHIM = System/lib/Stubs/libame_dll$(VERS)_ppc.dylib
PPCSHANK = System/lib/lib5d_ppc.dylib
PPCRELAY = System/bin/relay_ppc
ppcbits: $(PPCSHIM) $(PPCSHANK) $(PPCRELAY)
$(PPCSHIM): ame_cmx.c dllcalls.h System/lib/lib5d_ppc.dylib Makefile
	cd Run; \
	$(GCCCMD) -arch ppc -fPIC $(FLAGS) $(DEFNS) \
		-I. -I../../Frameworks/Tcl.framework/Headers \
		-dynamiclib -o ../$(PPCSHIM) ame_cmx.c -F../../Frameworks \
		-framework Tcl -L../System/lib -l5d_ppc; cd ..; \
	install_name_tool -change \
		/Library/Frameworks/Tcl.framework/Versions/$(VERS)/Tcl \
		@executable_path/../Frameworks/Tcl.framework/Tcl $(PPCSHIM)
$(PPCSHANK): shank.cpp dllcalls.h Makefile
	cd Run; $(GPPCMD) -arch ppc -O -fPIC $(FLAGS) -I. -dynamiclib \
		-o ../$(PPCSHANK) shank.cpp; cd ..
$(PPCRELAY): Run/relay.c
	cd Run; $(GCCCMD) -arch ppc $(FLAGS) -o ../$(PPCRELAY) relay.c; cd ..

endif

vpath %.pl Prolog

PROLOG_FILES = ame_gen.pl backup.pl build.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl graphics.pl image.pl \
		input.pl instance.pl inters.pl language.pl library.pl link.pl \
		m_class.pl menu.pl m_struct.pl m_update.pl node.pl \
		output.pl render.pl ss_import.pl state.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl

# Prolog is Sicstus
System/bin/main.sav: $(PROLOG_FILES) smain.pl sp_only.pl System/bin/struct_db.dll
	cd Prolog; sicstus -l buildmainsav.pl; cd ..

System/bin/struct_db.dll: struct_db.pl Prolog/struct_db.c
	cd Prolog; splfr struct_db.pl struct_db.c; mv struct_db.dll ../System/bin; cd ..

Run/xgsimile$(ARCHEXTN): Prolog/gmain$(ARCHEXTN).o Prolog/struct_db.c
	cd Prolog; gplc --no-top-level -o ../$(PROLOGSTATE) -C '$(FLAGS) -D_GNU_PROLOG' gmain$(ARCHEXTN).o struct_db.c; cd ..
Prolog/gmain$(ARCHEXTN).o: $(PROLOG_FILES) Prolog/gmain.pl
	cd Prolog; gplc -o gmain$(ARCHEXTN).o -c -C '$(FLAGS)' gmain.pl; cd ..

vpath 	%.cpp 	Run
vpath 	%.c 	Run
vpath 	%.h 	Run
vpath 	%.tcl 	Run

#ifeq ($(UNAME),MINGW32_NT)
# MSYS cannot execute Wish: libraries? Try compiler direct

System/lib/Stubs/ame_dll84.dll: ame_cmx.c dllcalls.h System/bin/5d.dll
	cd Run; $(GCCCMD) $(FLAGS) $(DEFNS) -I. -I../System/include/tcl \
		-shared -o ../$(SHIM) ame_cmx.c \
		../System/lib/tclstub84.lib -L../System/lib -l5ddll; cd ..

System/lib/Stubs/libame_dll$(VERS).so: \
		ame_cmx.c dllcalls.h System/lib/lib5d.so
	cd Run; $(GCCCMD) -fPIC $(FLAGS) $(DEFNS) -I. -I../System/include/tcl \
		-shared -o ../$(SHIM) -L../System/lib -ltclstub$(VERS) -l5d \
		./ame_cmx.c; cd ..

# 'before' arg of install_name_tool should be some gung-ho sed regexp on output
# of otool but it did not work (why was this not needed for ppc?)
System/lib/Stubs/libame_dll$(VERS)$(ARCHEXTN).dylib: \
		ame_cmx.c dllcalls.h System/lib/lib5d$(ARCHEXTN).dylib
	cd Run; \
	$(GCCCMD) -fPIC $(FLAGS) $(DEFNS) -I. \
		-I../../Frameworks/Tcl.framework/Headers \
		-dynamiclib -o ../$(SHIM) ame_cmx.c -F../../Frameworks \
		-framework Tcl -L../System/lib -l5d$(ARCHEXTN); cd ..; \
	install_name_tool -change \
		/Library/Frameworks/Tcl.framework/Versions/$(VERS)/Tcl \
		@executable_path/../Frameworks/Tcl.framework/Tcl $(SHIM)

System/bin/5d.dll: shank.cpp dllcalls.h Makefile
	cd Run; $(GPPCMD) -DSHARELIB $(FLAGS) -I. -shared -o 5d.dll \
		-Wl,--out-implib,lib5ddll.a shank.cpp; \
		mv 5d.dll ../System/bin; mv lib5ddll.a ../System/lib; cd ..

# not needed for Linux; Simile builds it when first run
System/lib/lib5d.so: shank.cpp dllcalls.h Makefile
	cd Run; $(GPPCMD) -fPIC $(FLAGS) -I. -shared \
		-o ../System/lib/lib5d.so shank.cpp; cd ..

# gcc cannot build universal binary libraries for loading via ld
# directly; build separately and load appropriate one at run time

System/lib/lib5d$(ARCHEXTN).dylib: shank.cpp dllcalls.h Makefile
	cd Run; $(GPPCMD) -O -fPIC $(FLAGS) -I. -dynamiclib \
	-o ../System/lib/lib5d$(SHAREDLIBEXTN) shank.cpp; cd ..

Run/install.dll: install.cpp Makefile
	cd Run; $(GPPCMD) $(FLAGS) $(DEFNS) -I. -I../System/include -shared \
		-o install.dll install.cpp -L../System/lib -lcrypto -lssl; \
		cd ..

System/bin/Simile.exe: Interp/Simile.c Interp/Simile.rc Makefile
	cd Interp; windres -I../System/include/tcl -o rc.o Simile.rc; \
	$(GCCCMD) $(FLAGS) -I../System/include/tcl \
		-o ../System/bin/Simile.exe Simile.c rc.o \
		../System/lib/tcl84.lib ../System/lib/tk84.lib -mwindows; cd ..

#else

# CYGWIN and non-Windows
#System/lib/Stubs/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN): \
#	ame_cmx.cpp dllcalls.h shank.cpp makedlls.tcl
#	cd Run; $(WISHCMD) makedlls.tcl; cd ..

# Is there a rule for System/lib/lib5d$(SHAREDLIBEXTN)
# I guess that would be System/bin/5d.dll for Windows 
#System/$(SLDIR)/$(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN): ame_cmx.cpp dllcalls.h \
#		shank.cpp makedlls.tcl
#	cd Run; $(WISHCMD) makedlls.tcl; cd ..
#endif

System/bin/relay$(ARCHEXTN): Run/relay.c
	cd Run; $(GCCCMD) $(FLAGS) -o ../System/bin/relay$(ARCHEXTN) relay.c; \
		cd ..

# call clean after changing license info in this file
clean:
	rm System/lib/Stubs/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN) \
		System/$(SLDIR)/$(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN) \
		Run/install.dll

