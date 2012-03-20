# These are the settings for the particular version we want to make
# edition: evaluation, teaching, standard or enterprise
ifndef EDN
EDN = ENTERPRISE
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

# Prolog implementation to use -- GNU for Windows releases, GNU otherwise
# (currently GNU for everything)
PROLOG = GNU

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
OPT =
# build on included tcl -- deprecated but needed for selectable bitness
TCLDIR = /usr
endif
SYSDIR = System$(BITEXTN)

# Default case: Linux
FLAGS = $(OPT)
SHAREDLIBPREFX = lib
MAKEPIC = -fPIC
MAKESL = -shared
MAJ = 8
MIN = 5
VERS = $(MAJ).$(MIN)

EXECDIR = $(SYSDIR)/bin
LIBDIR = $(SYSDIR)/lib
SLDIR = $(LIBDIR)
USETCL = -DUSE_TCL_STUBS -I$(TCLDIR)/include/tcl$(VERS) -L$(TCLDIR)/lib -ltclstub$(VERS)

# Next builds against system Tcl for Prolog debugging with Sicstus/dll
# USETCL = -DUSE_TCL_STUBS -I/usr/include/tcl$(VERS) -L/usr/lib/tcl$(VERS) -ltclstub$(VERS)
LOCALIZE_TCL_REFS = ls # placebo command
CHECK_LOCAL_LIBS = -Wl,-rpath,'../$(LIBDIR)'
SHAREDLIBEXTN = .so

ifeq ($(PLATFORM),Darwin)
#	VERS = 8.6
	OSNUMBER = $(shell uname -r)
ifeq ($(MY_CPU),x86_64)
	FLAGS = $(OPT)
	TCLFW = /System/Library/Frameworks
else
	FLAGS = $(OPT) -arch i386
	TCLFW = /Library/Frameworks
endif
	ARCHEXTN = _ppc
# build for everything unless I am on Barbie
	ifneq ($(OSNUMBER),7.9.0)
		FLAGS = $(OPT) -mmacosx-version-min=10.4
	        ARCHEXTN = _mac
	endif
	EXECEXTN = $(ARCHEXTN)
	MAKEPIC = -fPIC
	MAKESL = -dynamiclib
# make sure Current is set to right version
	USETCL =  -DUSE_TCL_STUBS -F$(TCLFW) -framework Tcl -I$(TCLFW)/Tcl.framework/Headers -L$(TCLFW)/Tcl.framework -ltclstub$(VERS)
	LOCALIZE_TCL_REFS = install_name_tool -change \
		$(TCLFW)/Tcl.framework/Versions/$(VERS)/Tcl \
		@executable_path/../Frameworks/Tcl.framework/Tcl
	CHECK_LOCAL_LIBS =
	SHAREDLIBEXTN = $(ARCHEXTN).dylib
else
	PLATFORM = $(shell uname -o)
endif 

ifeq ($(PLATFORM),Msys) # any Windows, any toolchain
        # GCCCMD = "$(shell pwd)/System/bin/g++" # can't find process.h
ifeq ($(MY_CPU),x86_64)
	TCLDIR = /c/Tcl
	SWIPLDIR = "/c/Program files/swipl"
	TCLREF = $(TCLDIR)
	GCCCMD = x86_64-w64-mingw32-gcc
	GPPCMD = x86_64-w64-mingw32-g++
	RESCMD = x86_64-w64-mingw32-windres
else
#	TCLDIR = "/c/Program files (x86)/Tcl"
# Actually, use local TclTk as above dir not exist on 32bit machines --
	TCLDIR = $(SYSDIR)
	TCLREF = ../$(TCLDIR)
	RESCMD = windres
	INSTLIB = Run/install.dll
# must be 32-bit because installer is
endif
	FLAGS = $(OPT)
	SHAREDLIBPREFX = 
	MAKEPIC = 
	MAKESL = -shared
	VERS = $(MAJ)$(MIN)
#	VERS = 86
#
	SLDIR = $(EXECDIR)
# to be used after CDing to Run -- assume all refs are from a subdirectory
	USETCL = -DUSE_TCL_STUBS -I$(TCLREF)/include/tcl$(MAJ).$(MIN) -L$(TCLREF)/lib $(TCLREF)/lib/tclstub$(VERS).lib
	LOCALIZE_TCL_REFS =  ls # placebo command
	CHECK_LOCAL_LIBS =
	SHAREDLIBEXTN = .dll
	ARCHEXTN = _win
	EXECEXTN = .exe
	MAIN = $(EXECDIR)/Simile.exe
	SCRIPT = $(EXECDIR)/SimileScript.exe
endif

PROLOGSTATE = xgsimile$(EXECEXTN)
ifeq ($(PROLOG),SWI)
	PROLOGSTATE = xssimile$(EXECEXTN)
endif

STUBS_DIR = $(LIBDIR)/Stubs
SHIM = $(STUBS_DIR)/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN)
UNPK = $(STUBS_DIR)/$(SHAREDLIBPREFX)unpacker$(VERS)$(SHAREDLIBEXTN)
SHANK = $(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN)

# shank before shims in dependencies because some Make utilities build them
# in order, and while changed shank does not require shim rebuild, it must
# be present...
simile: $(EXECDIR)/$(PROLOGSTATE) $(EXECDIR)/relay$(EXECEXTN) \
	$(SLDIR)/$(SHANK) $(SHIM) $(UNPK) $(INSTLIB) $(MAIN) $(SCRIPT)

vpath %.pl Prolog

PROLOG_FILES = ame_gen.pl backup.pl build.pl code.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl forms.pl graphics.pl image.pl \
		imexport.pl input.pl instance.pl inters.pl language.pl \
		library.pl link.pl m_class.pl menu.pl m_struct.pl m_update.pl \
		node.pl output.pl render.pl ss_import.pl state.pl struct_db.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl

# Prolog is not Sicstus
#ifeq ($(PROLOG),SWI)
$(EXECDIR)/xssimile$(EXECEXTN): $(PROLOG_FILES)  Prolog/smain.pl \
		$(EXECDIR)/struct_db$(SHAREDLIBEXTN)
	cd Prolog; swipl --goal=main --stand_alone=true \
		-o ../$(EXECDIR)/$(PROLOGSTATE) -c smain.pl; cd ..
$(EXECDIR)/struct_db$(SHAREDLIBEXTN): Prolog/struct_db.c
# for old SWI, or if building with mingw when swipl built with msvc
#	cd Prolog; gcc -c -I$(SWIPLDIR)/include -D__SWI_PROLOG__ \
#		$(MAKEPIC) struct_db.c; \
#		gcc $(MAKESL) -o ../$(EXECDIR)/struct_db$(SHAREDLIBEXTN) \
#		struct_db.o $(SWIPLDIR)/bin/swipl.dll; cd ..
# for new SWI
	cd Prolog; swipl-ld -cc-options,$(MAKEPIC) \
		-ld-options,$(MAKESL) \
		-o ../$(EXECDIR)/struct_db$(SHAREDLIBEXTN) struct_db.c; cd ..
#endif
#ifeq ($(PROLOG),GNU)
$(EXECDIR)/xgsimile$(EXECEXTN): \
		$(EXECDIR)/gmain$(ARCHEXTN).o $(EXECDIR)/struct_db$(ARCHEXTN).o
	cd $(EXECDIR); gplc --no-top-level -o $(PROLOGSTATE) -L $(OPT) \
		gmain$(ARCHEXTN).o struct_db$(ARCHEXTN).o; cd ../..
$(EXECDIR)/gmain$(ARCHEXTN).o: $(PROLOG_FILES) Prolog/gmain.pl Prolog/gstr_db.pl
	cd Prolog; gplc -o ../$(EXECDIR)/gmain$(ARCHEXTN).o -c gmain.pl; cd ..
$(EXECDIR)/struct_db$(ARCHEXTN).o: Prolog/struct_db.c
	cd Prolog; gplc -c -C '$(OPT) -D_GNU_PROLOG' \
		-o ../$(EXECDIR)/struct_db$(ARCHEXTN).o struct_db.c; cd ..
#endif

#ifeq ($(UNAME),MINGW32_NT)
# MSYS cannot execute Wish: libraries? Try compiler direct

$(SHIM): Run/ame_cmx.c Run/dllcalls.h
	cd Run; $(GCCCMD) $(FLAGS) -I. $(MAKEPIC) $(MAKESL) -o ../$(SHIM) \
		ame_cmx.c $(USETCL) -L../$(LIBDIR) -l5d$(ARCHEXTN) \
		$(CHECK_LOCAL_LIBS); cd ..; \
	$(LOCALIZE_TCL_REFS) $(SHIM)

$(UNPK): Run/unpacker.c Run/dllcalls.h Makefile
	cd Run; $(GCCCMD) $(FLAGS) $(DEFNS) -I. $(MAKEPIC) $(MAKESL) \
		-o ../$(UNPK) unpacker.c $(USETCL); cd ..; \
	$(LOCALIZE_TCL_REFS) $(UNPK)

# literal SLDIR allows different SHANK clauses for Windows vs Unix

# Windows: idiosyncratic stuff allows dynamic linker to work
# (even with gcc 4.5.0)
$(EXECDIR)/$(SHANK): Run/shank.cpp Run/dllcalls.h Run/6d.h Run/backend.h
	cd Run; $(GPPCMD) -DSHARELIB $(FLAGS) -I. $(MAKEPIC) $(MAKESL) \
		-Wl,--out-implib,lib5d$(ARCHEXTN).a -o $(SHANK) shank.cpp; \
		mv $(SHANK) ../$(SLDIR); \
		mv lib5d$(ARCHEXTN).a ../$(LIBDIR); cd ..

# Unix: not needed for Linux as it can build at run time
$(LIBDIR)/$(SHANK): Run/shank.cpp Run/dllcalls.h Run/6d.h Run/backend.h
	cd Run; $(GPPCMD) $(FLAGS) -I. $(MAKEPIC) $(MAKESL) \
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
# -static-libgcc is neeeded because this also used for 64bit install (and 32bit
# install on 64bit systems) where 32bit libraries maybe missing
$(INSTLIB): Run/install_adv.cpp Makefile
	cd Run; $(GPPCMD) -static-libgcc -m32 $(FLAGS) $(DEFNS) \
		-I/c/MsiIntel.SDK/include $(MAKEPIC) $(MAKESL) \
		-o ../$(INSTLIB) install_adv.cpp /c/MsiIntel.SDK/lib/msi.lib \
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
