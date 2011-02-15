# These are the settings for the particular version we want to make
# edition: evaluation, teaching, standard or enterprise
ifndef EDN
EDN = STANDARD 
endif
# (this now defined externally for scripting)

ifeq ($(EDN), EVALUATION)
# License code required to verify name/corp/edition: 0 for no
	LICENSED = 0
# date of final expiry: "hh:mm D M Y" or "" for permanent
	MONTHS_TO_RUN = 9
else
	LICENSED = 1
	MONTHS_TO_RUN = 0
endif
ifeq ($(EDN), TEACHING)
	MONTHS_TO_RUN = 21
endif

# days after install: 0 for no installation expiry
REL_EXP = 0

# What kind of system are we on
PLATFORM = $(shell uname -s)

# Prolog implementation to use -- SICSTUS for Windows releases, GNU otherwise
# (currently GNU for everything)
PROLOG = GNU

# Set this to '-fopenmp' to include v6 parallelism
PARALLEL =

ifeq ($(MONTHS_TO_RUN),0)
	EXP_TICKS = 0
else
ifeq ($(PLATFORM),Darwin)
	DATESPEC = -v+$(MONTHS_TO_RUN)m -v1d -v0H -v0M -v0S
else
	DATESPEC = -d `date -d "$(MONTHS_TO_RUN) months" +%Y-%m-01`
endif
EXP_TICKS = $(shell date $(DATESPEC) +%s)
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

ifeq ($(MY_CPU),x86_64)
BITEXTN = 64
OPT =
TCLDIR = /usr
else
BITEXTN = 
OPT = -m32
# build on included tcl -- deprecated but needed for selectable bitness
TCLDIR = "/home/jaspert/Documents/My Simile files/Source/System"
endif
SYSDIR = System$(BITEXTN)

# Default case: Linux
FLAGS = $(OPT)
SHAREDLIBPREFX = lib
MAKESL = -fPIC -shared
VERS = 8.5

EXECDIR = $(SYSDIR)/bin
LIBDIR = $(SYSDIR)/lib
SLDIR = $(LIBDIR)
USETCL = -DUSE_TCL_STUBS -I$(TCLDIR)/include/tcl$(VERS) -L$(TCLDIR)/lib -ltclstub$(VERS)

# Next builds against system Tcl for Prolog debugging with Sicstus/dll
# USETCL = -DUSE_TCL_STUBS -I/usr/include/tcl$(VERS) -L/usr/lib/tcl$(VERS) -ltclstub$(VERS)
LOCALIZE_TCL_REFS = ls # placebo command
SHAREDLIBEXTN = .so

ifeq ($(PLATFORM),Darwin)
#	VERS = 8.6
	OSNUMBER = $(shell uname -r)
	FLAGS = $(OPT)
	ARCHEXTN = _ppc
# build for everything unless I am on Barbie
	ifneq ($(OSNUMBER),7.9.0)
		FLAGS = $(OPT) -arch i386 -mmacosx-version-min=10.4
	        ARCHEXTN = _mac
	endif
	EXECEXTN = $(ARCHEXTN)
	MAKESL = -fPIC -dynamiclib
#	TCLFW = /System/Library/Frameworks
# for tcl8.5
	TCLFW = /Library/Frameworks
# for tcl8.6
# make sure Current is set to right version
	USETCL =  -DUSE_TCL_STUBS -F$(TCLFW) -framework Tcl -I$(TCLFW)/Tcl.framework/Headers -L$(TCLFW)/Tcl.framework -ltclstub$(VERS)
	LOCALIZE_TCL_REFS = install_name_tool -change \
		$(TCLFW)/Tcl.framework/Versions/$(VERS)/Tcl \
		@executable_path/../Frameworks/Tcl.framework/Tcl
	SHAREDLIBEXTN = $(ARCHEXTN).dylib
else
	PLATFORM = $(shell uname -o)
endif 

ifeq ($(PLATFORM),Msys) # any Windows, any toolchain
        # GCCCMD = "$(shell pwd)/System/bin/g++" # can't find process.h
ifeq ($(MY_CPU),x86_64)
	TCLDIR = "/c/Tcl"
	GCCCMD = x86_64-w64-mingw32-gcc
	GPPCMD = x86_64-w64-mingw32-g++
	RESCMD = x86_64-w64-mingw32-windres
else
	TCLDIR = "/c/Program files (x86)/Tcl"
	RESCMD = windres
	INSTLIB = Run/install.dll
# must be 32-bit because installer is
endif
	FLAGS = $(OPT)
	SHAREDLIBPREFX = 
	MAKESL = -shared
	VERS = 85
#	VERS = 86
#
	SLDIR = $(EXECDIR)
# to be used after CDing to Run
	TCLREF = $(TCLDIR)
	USETCL = -DUSE_TCL_STUBS -I$(TCLREF)/include -L$(TCLREF)/lib $(TCLREF)/lib/tclstub$(VERS).lib
	LOCALIZE_TCL_REFS =  ls # placebo command
	SHAREDLIBEXTN = .dll
	ARCHEXTN = _win$(BITEXTN)
	EXECEXTN = .exe
	MAIN = $(EXECDIR)/Simile.exe
	SCRIPT = $(EXECDIR)/SimileScript.exe
endif

PROLOGSTATE = $(EXECDIR)/xgsimile$(EXECEXTN)
ifeq ($(PROLOG),SICSTUS)
	PROLOGSTATE = $(EXECDIR)/main.sav
endif

STUBS_DIR = $(LIBDIR)/Stubs
SHIM = $(STUBS_DIR)/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN)
UNPK = $(STUBS_DIR)/$(SHAREDLIBPREFX)unpacker$(VERS)$(SHAREDLIBEXTN)
SHANK = $(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN)

# shank before shims in dependencies because some Make utilities build them
# in order, and while changed shank does not require shim rebuild, it must
# be present...
simile: $(PROLOGSTATE) $(EXECDIR)/relay$(EXECEXTN) \
	$(SLDIR)/$(SHANK) $(SHIM) $(UNPK) $(INSTLIB) $(MAIN) $(SCRIPT)

vpath %.pl Prolog

PROLOG_FILES = ame_gen.pl backup.pl build.pl code.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl forms.pl graphics.pl image.pl \
		input.pl instance.pl inters.pl language.pl library.pl link.pl \
		m_class.pl menu.pl m_struct.pl m_update.pl node.pl \
		output.pl render.pl ss_import.pl state.pl struct_db.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl

# Prolog is Sicstus
$(EXECDIR)/main.sav: $(PROLOG_FILES) smain.pl sp_only.pl $(EXECDIR)/struct_db.dll
	cd Prolog; sicstus -l buildmainsav.pl; cd ..

$(EXECDIR)/struct_db.dll: Prolog/struct_db.pl Prolog/struct_db.c
	cd Prolog; splfr struct_db.pl struct_db.c; mv struct_db.dll ../$(EXECDIR); cd ..

$(EXECDIR)/xgsimile$(EXECEXTN): Prolog/gmain$(ARCHEXTN).o Prolog/struct_db.c
	cd Prolog; gplc --no-top-level -o ../$(PROLOGSTATE) -C '$(OPT) -D_GNU_PROLOG' -L $(OPT) gmain$(ARCHEXTN).o struct_db.c; cd ..
Prolog/gmain$(ARCHEXTN).o: $(PROLOG_FILES) Prolog/gmain.pl Prolog/gstr_db.pl 
	cd Prolog; gplc -o gmain$(ARCHEXTN).o -c gmain.pl; cd ..

#ifeq ($(UNAME),MINGW32_NT)
# MSYS cannot execute Wish: libraries? Try compiler direct

$(SHIM): Run/ame_cmx.c Run/dllcalls.h
	cd Run; $(GCCCMD) $(FLAGS) -I. $(MAKESL) -o ../$(SHIM) ame_cmx.c \
		$(USETCL) -L../$(LIBDIR) -l5d$(ARCHEXTN); cd ..; \
	$(LOCALIZE_TCL_REFS) $(SHIM)

$(UNPK): Run/unpacker.c Run/dllcalls.h Makefile
	cd Run; $(GCCCMD) $(FLAGS) $(DEFNS) -I. $(MAKESL) -o ../$(UNPK) \
		unpacker.c $(USETCL); cd ..; \
	$(LOCALIZE_TCL_REFS) $(UNPK)

# literal SLDIR allows different SHANK clauses for Windows vs Unix

# Windows: idiosyncratic stuff allows dynamic linker to work
# (even with gcc 4.5.0)
$(EXECDIR)/$(SHANK): Run/shank.cpp Run/dllcalls.h Run/6d.h Run/backend.h
	cd Run; $(GPPCMD) -DSHARELIB $(FLAGS) -I. $(MAKESL) $(PARALLEL) \
		-Wl,--out-implib,lib5d$(ARCHEXTN).a -o $(SHANK) shank.cpp; \
		mv $(SHANK) ../$(SLDIR); \
		mv lib5d$(ARCHEXTN).a ../$(LIBDIR); cd ..

# Unix: not needed for Linux as it can build at run time
$(LIBDIR)/$(SHANK): Run/shank.cpp Run/dllcalls.h Run/6d.h Run/backend.h
	cd Run; $(GPPCMD) $(FLAGS) -I. $(MAKESL) $(PARALLEL) \
		-o ../$(SLDIR)/$(SHANK) shank.cpp; cd ..

# Build a .dll to check licence code during Windows installation
# Version for GPInstall by QSC
#Run/install.dll: Run/install.c Makefile
#	cd Run; $(GCCCMD) $(FLAGS) $(DEFNS) -I. -I../System/include $(MAKESL) \
#		-o install.dll install.c -L../System/lib -lcrypto -lssl; \
#		cd ..
# Version for MakeMSI
#Run/install.dll: Run/install_msi.cpp Run/install_msi.rc Makefile
#	cd Run; windres -i install_msi.rc -o resource_msi.o; \
#		$(GPPCMD) $(FLAGS) $(DEFNS) -I../System/include \
#		-I/c/MsiIntel.SDK/include $(MAKESL) -o install.dll \
#		install_msi.c resource_msi.o /c/MsiIntel.SDK/lib/msi.lib \
#		-L../System/lib -lcrypto -lssl; cd ..
# Version for Advanced Installer
$(INSTLIB): Run/install_adv.cpp Makefile
	cd Run; $(GPPCMD) -m32 $(FLAGS) $(DEFNS) \
		-I/c/MsiIntel.SDK/include $(MAKESL) -o ../$(INSTLIB) \
		install_adv.cpp /c/MsiIntel.SDK/lib/msi.lib \
		-L../$(LIBDIR) -lcrypto -lssl; cd ..

# the rc objects from windres are ommitted from linking below becaise they
# do strange things to dll dependencies causing c000007b errors
$(EXECDIR)/Simile.exe: Interp/Simile.c Interp/Simile.rc
	$(RESCMD) -o rc.o Interp/Simile.rc;
	$(GCCCMD) $(FLAGS) -I$(TCLDIR)/include \
		-o $(EXECDIR)/Simile.exe Interp/Simile.c \
		$(TCLDIR)/lib/tcl$(VERS).lib $(TCLDIR)/lib/tk$(VERS).lib \
		-mwindows; cd ..

$(SCRIPT): Interp/script.c Interp/script.rc
	$(RESCMD) -o scriptrc.o Interp/script.rc;
	$(GCCCMD) $(FLAGS) -I$(TCLDIR)/include -o $(SCRIPT) Interp/script.c \
		$(TCLDIR)/lib/tcl$(VERS).lib $(TCLDIR)/lib/tk$(VERS).lib \
		-mwindows
#else

# CYGWIN and non-Windows
#$(STUBS_DIR)/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN): \
#	ame_cmx.cpp dllcalls.h shank.cpp makedlls.tcl
#	cd Run; $(WISHCMD) makedlls.tcl; cd ..

# Is there a rule for System/lib/lib5d$(SHAREDLIBEXTN)
# I guess that would be System/bin/5d.dll for Windows 
#System/$(SLDIR)/$(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN): ame_cmx.cpp dllcalls.h \
#		shank.cpp makedlls.tcl
#	cd Run; $(WISHCMD) makedlls.tcl; cd ..
#endif

$(EXECDIR)/relay$(EXECEXTN): Run/relay.c
	cd Run; $(GCCCMD) $(FLAGS) -o ../$(EXECDIR)/relay$(EXECEXTN) relay.c; \
		cd ..

# call clean after changing license info in this file
clean:
	rm $(STUBS_DIR)/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN) \
		$(STUBS_DIR)/$(SHAREDLIBPREFX)unpacker$(VERS)$(SHAREDLIBEXTN) \
		$(SLDIR)/$(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN) $(INSTLIB)
