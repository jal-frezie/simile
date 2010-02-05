# These are the settings for the particular version we want to make
# edition: evaluation, teaching, standard or enterprise
EDN = ENTERPRISE
# date of final expiry: "hh:mm D M Y" or "" for permanent
ABS_EXP = ""
# days after install: 0 for no installation expiry
REL_EXP = 0
# License code required to verify name/corp/edition: 0 for no
LICENSED = 1
# Prolog implementation to use -- SICSTUS for Windows releases, GNU otherwise
PROLOG = GNU
# Set this to '-fopenmp' to include v6 parallelism
PARALLEL =

ifeq ($(ABS_EXP),"")
	EXP_TICKS = 0
else
	EXP_TICKS = $(shell date +%s -d $(ABS_EXP))
endif

DEFNS=-DSIM_FINAL_EXPIRY=$(EXP_TICKS) -DSIM_DAYS_AFTER_INSTALL=$(REL_EXP) -DSIM_$(EDN)

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
OPT = 

UNAME = $(shell uname)
PLATFORM = $(UNAME)
ifeq ($(UNAME),CYGWIN_NT-5.1)
	PLATFORM = Windows
endif 
ifeq ($(UNAME),CYGWIN_NT-5.0)
	PLATFORM = Windows
endif 
ifeq ($(UNAME),MINGW32_NT-5.1)
	PLATFORM = Windows
endif 
ifeq ($(UNAME),MINGW32_NT-5.0)
	PLATFORM = Windows
endif 

# Default case: Linux
FLAGS = $(OPT) -m32
SLDIR = lib
SHAREDLIBPREFX = lib
MAKESL = -fPIC -shared
VERS = 8.4
TCLDIR = ../System
# VERS = 8.6
# TCLDIR = /usr/local/lib/ActiveTcl-$(VERS)
USETCL = -DUSE_TCL_STUBS -I$(TCLDIR)/include -L$(TCLDIR)/lib -ltclstub$(VERS)
LOCALIZE_TCL_REFS = ls # placebo command
SHAREDLIBEXTN = .so

ifeq ($(PLATFORM),Darwin)
	OSNUMBER = $(shell uname -r)
	FLAGS = $(OPT)
	ARCHEXTN = _ppc
# build for everything unless I am on Barbie
	ifneq ($(OSNUMBER),7.9.0)
		FLAGS = $(OPT) -arch i386 -arch ppc -mmacosx-version-min=10.3
	        ARCHEXTN = _mac
	endif
	EXECEXTN = $(ARCHEXTN)
	MAKESL = -fPIC -dynamiclib
	USETCL =  -DUSE_TCL_STUBS -F~/Desktop/CVS\ Simile\ v5.x.app/Contents/Frameworks -framework Tcl -I../System/include -L../System/lib
	LOCALIZE_TCL_REFS = install_name_tool -change \
		/System/Library/Frameworks/Tcl.framework/Versions/$(VERS)/Tcl \
		@executable_path/../Frameworks/Tcl.framework/Tcl
	SHAREDLIBEXTN = $(ARCHEXTN).dylib
endif 

ifeq ($(PLATFORM),Windows) # any Windows, any toolchain
        # GCCCMD = "$(shell pwd)/System/bin/g++" # can't find process.h
	FLAGS = $(OPT)
	SLDIR = bin
	SHAREDLIBPREFX = 
	MAKESL = -shared
	VERS = 84
#	VERS = 86
#	TCLDIR = c:/Tcl
	USETCL = -DUSE_TCL_STUBS -I$(TCLDIR)/include -L$(TCLDIR)/lib $(TCLDIR)/lib/tclstub$(VERS).lib
	LOCALIZE_TCL_REFS =  ls # placebo command
	SHAREDLIBEXTN = .dll
	ARCHEXTN = _win
	EXECEXTN = .exe
	INSTLIB = Run/install.dll
	MAIN = System/bin/Simile.exe
endif

PROLOGSTATE = Run/xgsimile$(EXECEXTN)
ifeq ($(PROLOG),SICSTUS)
	PROLOGSTATE = System/bin/main.sav
endif

SHIM = System/lib/Stubs/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN)
UNPK = System/lib/Stubs/$(SHAREDLIBPREFX)unpacker$(VERS)$(SHAREDLIBEXTN)
SHANK = $(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN)

# shank before shims in dependencies because some Make utilities build them
# in order, and while changed shank does not require shim rebuild, it must
# be present...
simile: $(PROLOGSTATE) System/bin/relay$(EXECEXTN) \
	System/$(SLDIR)/$(SHANK) $(SHIM) $(UNPK) $(INSTLIB) $(MAIN)

vpath %.pl Prolog

PROLOG_FILES = ame_gen.pl backup.pl build.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl forms.pl graphics.pl image.pl \
		input.pl instance.pl inters.pl language.pl library.pl link.pl \
		m_class.pl menu.pl m_struct.pl m_update.pl node.pl \
		output.pl render.pl ss_import.pl state.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl

# Prolog is Sicstus
System/bin/main.sav: $(PROLOG_FILES) smain.pl sp_only.pl System/bin/struct_db.dll
	cd Prolog; sicstus -l buildmainsav.pl; cd ..

System/bin/struct_db.dll: struct_db.pl Prolog/struct_db.c
	cd Prolog; splfr struct_db.pl struct_db.c; mv struct_db.dll ../System/bin; cd ..

Run/xgsimile$(EXECEXTN): Prolog/gmain$(ARCHEXTN).o Prolog/struct_db.c
	cd Prolog; gplc --no-top-level -o ../$(PROLOGSTATE) -C '-D_GNU_PROLOG' gmain$(ARCHEXTN).o struct_db.c; cd ..
Prolog/gmain$(ARCHEXTN).o: $(PROLOG_FILES) Prolog/gmain.pl
	cd Prolog; gplc -o gmain$(ARCHEXTN).o -c gmain.pl; cd ..

vpath 	%.cpp 	Run
vpath 	%.c 	Run
vpath 	%.h 	Run
vpath 	%.tcl 	Run

#ifeq ($(UNAME),MINGW32_NT)
# MSYS cannot execute Wish: libraries? Try compiler direct

$(SHIM): ame_cmx.c dllcalls.h
	cd Run; $(GCCCMD) $(FLAGS) -I. $(MAKESL) -o ../$(SHIM) ame_cmx.c \
		$(USETCL) -L../System/lib -l5d$(ARCHEXTN); cd ..; \
	$(LOCALIZE_TCL_REFS) $(SHIM)

$(UNPK): unpacker.c dllcalls.h Makefile
	cd Run; $(GCCCMD) $(FLAGS) $(DEFNS) -I. $(MAKESL) -o ../$(UNPK) \
		unpacker.c $(USETCL) -L../System/lib -l5d$(ARCHEXTN); cd ..; \
	$(LOCALIZE_TCL_REFS) $(UNPK)

# literal SLDIR allows different SHANK clauses for Windows vs Unix

# Windows: idiosyncratic stuff allows dynamic loader to work
System/bin/$(SHANK): shank.cpp dllcalls.h
	cd Run; $(GPPCMD) -DSHARELIB $(FLAGS) -I. $(MAKESL) $(PARALLEL) \
		-o $(SHANK) -Wl,--out-implib,lib5d_win.a shank.cpp; \
		mv $(SHANK) ../System/$(SLDIR); \
		mv lib5d_win.a ../System/lib; cd ..

# Unix: not needed for Linux as it can build at run time
System/lib/$(SHANK): shank.cpp dllcalls.h
	cd Run; $(GPPCMD) $(FLAGS) -I. $(MAKESL) $(PARALLEL) \
		-o ../System/$(SLDIR)/$(SHANK) shank.cpp; cd ..

Run/install.dll: install.c Makefile
	cd Run; $(GCCCMD) $(FLAGS) $(DEFNS) -I. -I../System/include $(MAKESL) \
		-o install.dll install.c -L../System/lib -lcrypto -lssl; \
		cd ..

System/bin/Simile.exe: Interp/Simile.c Interp/Simile.rc
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

System/bin/relay$(EXECEXTN): Run/relay.c
	cd Run; $(GCCCMD) $(FLAGS) -o ../System/bin/relay$(EXECEXTN) relay.c; \
		cd ..

# call clean after changing license info in this file
clean:
	rm System/lib/Stubs/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN) \
		System/$(SLDIR)/$(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN) \
		Run/install.dll

