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
ifndef MY_CPU
	MY_CPU=$(shell uname -m)
endif

# Prolog implementation to use -- GNU for Windows releases, GNU otherwise
# (currently GNU for everything)
PROLOG = GNU

DEFNS=-DSIM_BUILT=$(shell date $(DATESPEC) +%s)

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
TCLDIR = /usr
TCLREF = $(TCLDIR)
else
BITEXTN = 
# build on included tcl -- deprecated but needed for selectable bitness
TCLDIR = System
TCLREF = ../$(TCLDIR)
endif

# Default case: Linux
SYSDIR = System
FLAGS = $(OPT) -m32
ifeq ($(MY_CPU),x86_64)
	FLAGS = $(OPT)
endif
ifeq ($(MY_CPU),armv7l) # 32-bit but -m32 unrecognized
	FLAGS = $(OPT)
endif
SHAREDLIBPREFX = lib
MAKEPIC = -fPIC
MAKESL = -shared
MAJ = 8
MIN = 5
VERS = $(MAJ).$(MIN)

EXECDIR = $(SYSDIR)/bin
RESDIR = $(SYSDIR)/lib
SLDIR = $(RESDIR)
# Builds against Tcl included in distribution
# USETCL = -DUSE_TCL_STUBS -I$(TCLREF)/include/tcl$(VERS) -L$(TCLREF)/lib -ltclstub$(VERS)

# Next builds against system Tcl for Prolog debugging with Sicstus/dll
USETCL = -DUSE_TCL_STUBS -I/usr/include/tcl$(VERS) -L/usr/lib/tcl$(VERS) -ltclstub$(VERS)
LOCALIZE_TCL_REFS = ls # placebo command
CHECK_LOCAL_LIBS = -Wl,-rpath,'$$ORIGIN/..'
SHAREDLIBEXTN = .so

ifeq ($(PLATFORM),Darwin)
	SYSDIR = System$(BITEXTN)
#	VERS = 8.6
	OSNUMBER = $(shell uname -r)
ifeq ($(MY_CPU),x86_64)
	FLAGS = $(OPT) -mmacosx-version-min=10.6
	TCLFW = /System/Library/Frameworks
else
	FLAGS = $(OPT) -arch i386 -mmacosx-version-min=10.4
	TCLFW = /Library/Frameworks
endif
	ARCHEXTN = _mac
# build for everything unless I am on Barbie
	ifeq ($(OSNUMBER),8.11.0)
		FLAGS = $(OPT)
	        ARCHEXTN = _ppc
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
	SYSDIR = System$(BITEXTN)
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
	TCLINC = $(TCLREF)/include/tcl$(MAJ).$(MIN)
	USETCL = -DUSE_TCL_STUBS -I$(TCLINC) -L$(TCLREF)/lib $(TCLREF)/lib/tclstub$(VERS).lib
	CHECK_LOCAL_LIBS =
	SHAREDLIBEXTN = .dll
	ARCHEXTN = _win
	EXECEXTN = .exe
	MAIN = $(EXECDIR)/Simile.exe
	SCRIPT = $(EXECDIR)/SimileScript.exe
endif

PROLOGSTATE = $(EXECDIR)/xssimile$(EXECEXTN)
PROLOG_DB = Prolog/struct_db$(SHAREDLIBEXTN)
ifeq ($(PROLOG),GNU)
	PROLOGSTATE = $(EXECDIR)/xgsimile$(EXECEXTN)
	PROLOG_OBJ = $(EXECDIR)/gmain$(ARCHEXTN).o
	PROLOG_DB = $(EXECDIR)/struct_db$(ARCHEXTN).o
endif

STUBS_DIR = $(RESDIR)/Stubs
SHIM = $(STUBS_DIR)/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN)
UNPK = $(STUBS_DIR)/$(SHAREDLIBPREFX)unpacker$(VERS)$(SHAREDLIBEXTN)
SHANK = $(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN)
RELAY =  $(EXECDIR)/relay$(EXECEXTN)

# shank before shims in dependencies because some Make utilities build them
# in order, and while changed shank does not require shim rebuild, it must
# be present...
simile: $(PROLOGSTATE) $(RELAY) \
	$(SLDIR)/$(SHANK) $(SHIM) $(UNPK) $(INSTLIB) $(MAIN) $(SCRIPT)

vpath %.pl Prolog

PROLOG_FILES = ame_gen.pl backup.pl build.pl code.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl forms.pl graphics.pl image.pl \
		imexport.pl input.pl instance.pl inters.pl language.pl \
		library.pl link.pl m_class.pl menu.pl m_struct.pl m_update.pl \
		node.pl output.pl render.pl ss_import.pl state.pl struct_db.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl

# Prolog is not Sicstus
ifeq ($(PROLOG),SWI)
$(PROLOGSTATE): $(PROLOG_FILES)  Prolog/smain.pl $(PROLOG_DB)
	cd Prolog; swipl --goal=main --stand_alone=true \
		-o ../$(PROLOGSTATE) -c smain.pl; cd ..
$(PROLOG_DB): Prolog/struct_db.c
# for old SWI, or if building with mingw when swipl built with msvc
#	cd Prolog; gcc -c -I$(SWIPLDIR)/include -D__SWI_PROLOG__ \
#		$(MAKEPIC) struct_db.c; \
#		gcc $(MAKESL) -o struct_db$(SHAREDLIBEXTN) \
#		struct_db.o $(SWIPLDIR)/bin/swipl.dll; cd ..
# for new SWI
	cd Prolog; swipl-ld -cc-options,$(MAKEPIC) \
		-ld-options,$(MAKESL) \
		-o ../$(PROLOG_DB) struct_db.c; cd ..
endif
ifeq ($(PROLOG),GNU)
$(PROLOGSTATE): $(PROLOG_OBJ) $(PROLOG_DB)
	gplc --no-top-level -o $(PROLOGSTATE) -L $(OPT) \
		$(PROLOG_OBJ) $(PROLOG_DB)
$(PROLOG_OBJ): $(PROLOG_FILES) Prolog/gmain.pl Prolog/gstr_db.pl
	cd Prolog; gplc -o ../$(PROLOG_OBJ) -c gmain.pl; cd ..
$(PROLOG_DB): Prolog/struct_db.c
	cd Prolog; gplc -c -C '$(OPT) -D_GNU_PROLOG' \
		-o ../$(PROLOG_DB) struct_db.c; cd ..
endif

#ifeq ($(UNAME),MINGW32_NT)
# MSYS cannot execute Wish: libraries? Try compiler direct

$(SHIM): $(SLDIR)/$(SHANK) Run/ame_cmx.c Run/dllcalls.h
	cd Run; $(GCCCMD) $(FLAGS) -I. $(MAKEPIC) $(MAKESL) -o ../$(SHIM) \
		ame_cmx.c $(USETCL) -L../$(RESDIR) -l5d$(ARCHEXTN) \
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
		mv lib5d$(ARCHEXTN).a ../$(RESDIR); cd ..

# Unix: not needed for Linux as it can build at run time
$(RESDIR)/$(SHANK): Run/shank.cpp Run/dllcalls.h Run/6d.h Run/backend.h
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
		-L../$(RESDIR) -lcrypto -lssl; cd ..

# the rc objects from windres are ommitted from linking below becaise they
# do strange things to dll dependencies causing c000007b errors
$(EXECDIR)/Simile.exe: Interp/Simile.c Interp/Simile.rc
	cd Interp; $(RESCMD) -o rc.o Simile.rc; \
	$(GCCCMD) $(FLAGS) -I$(TCLINC) -o ../$(EXECDIR)/Simile.exe Simile.c \
		$(TCLREF)/lib/tcl$(VERS).lib $(TCLREF)/lib/tk$(VERS).lib \
		-mwindows; cd ..

$(SCRIPT): Interp/script.c Interp/script.rc
	cd Interp; $(RESCMD) -o scriptrc.o script.rc; \
	$(GCCCMD) $(FLAGS) -I$(TCLINC) -o ../$(SCRIPT) script.c \
		$(TCLREF)/lib/tcl$(VERS).lib $(TCLREF)/lib/tk$(VERS).lib \
		-mwindows; cd ..
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

$(RELAY): Run/relay.c
	cd Run; $(GCCCMD) $(FLAGS) -o ../$(RELAY) relay.c; cd ..

ifeq ($(PLATFORM),GNU/Linux)
# install used for packaging for distributions
LIBDIR = /usr/lib
# overridden by rpm build on Fedora 64-bit
INSTALL_TGT = $(LIBDIR)/simile-6.0
install:
	mkdir -p $(DESTDIR)$(INSTALL_TGT); \
	tar cf $(DESTDIR)$(INSTALL_TGT)/payload.tar \
		Examples/BallBerry4a.shf \
		Examples/BallBerry4a.sml \
		Examples/control.shf \
		Examples/control.sml \
		Examples/forest.shf \
		Examples/forest.sml \
		Examples/forestV4FP.spf \
		Examples/forestV4FPb.spf \
		Examples/forestV4FP.sml \
		Examples/forestV4IP.sml \
		Examples/spiro.shf \
		Examples/spiro.sml \
		Examples/bat.spf \
		Examples/dancer.spf \
		Extensions/Scripting.tcl \
		Functions/Arithmetic.pl \
		Functions/Hidden.pl \
		Functions/List\ handling.pl \
		Functions/Model\ properties.pl \
		Functions/Statistics.pl \
		Functions/Trigonometry.pl \
		Functions/new_units.pl \
		Functions/procs.cpp \
		Functions/procs.tcl \
		help/data/* \
		help/diagrams/* \
		help/elements/* \
		help/equations/* \
		help/files/* \
		help/index.htm \
		help/new/index.htm \
		help/run/* \
		help/scripting/* \
		help/start/* \
		help/submodels/* \
		Images/Control/pause.gif \
		Images/Control/play.gif \
		Images/Control/stop.gif \
		Images/HelpAboutUpper.gif \
		Images/Icons/* \
		Images/Welcome.gif \
		Images/alarm.cnv \
		Images/bigsimile.gif \
		Images/cond.cnv \
		Images/creation.cnv \
		Images/dribble.xbm \
		Images/ghost.mask.xbm \
		Images/ghost.xbm \
		Images/immig.cnv \
		Images/loss.cnv \
		Images/repro.cnv \
		Images/weegraph.xbm \
		Images/Eqnbar/cross.gif \
		Images/Eqnbar/function.gif \
		Images/Eqnbar/inputs.gif \
		Images/Eqnbar/tick.gif \
		Images/Toolbar/Large/Initial.gif \
		Images/Toolbar/Large/alarm.gif \
		Images/Toolbar/Large/compartment.gif \
		Images/Toolbar/Large/condition.gif \
		Images/Toolbar/Large/copy.gif \
		Images/Toolbar/Large/creation.gif \
		Images/Toolbar/Large/delete.gif \
		Images/Toolbar/Large/event.gif \
		Images/Toolbar/Large/find.gif \
		Images/Toolbar/Large/findmore.gif \
		Images/Toolbar/Large/flip_h.gif \
		Images/Toolbar/Large/flip_v.gif \
		Images/Toolbar/Large/flow.gif \
		Images/Toolbar/Large/ghost.gif \
		Images/Toolbar/Large/graph.gif \
		Images/Toolbar/Large/immigration.gif \
		Images/Toolbar/Large/influence.gif \
		Images/Toolbar/Large/loss.gif \
		Images/Toolbar/Large/move.gif \
		Images/Toolbar/Large/new.gif \
		Images/Toolbar/Large/open.gif \
		Images/Toolbar/Large/print.gif \
		Images/Toolbar/Large/redo.gif \
		Images/Toolbar/Large/relation.gif \
		Images/Toolbar/Large/reproduction.gif \
		Images/Toolbar/Large/rerun.gif \
		Images/Toolbar/Large/runenv.gif \
		Images/Toolbar/Large/save.gif \
		Images/Toolbar/Large/select.gif \
		Images/Toolbar/Large/snap.gif \
		Images/Toolbar/Large/squirt.gif \
		Images/Toolbar/Large/state.gif \
		Images/Toolbar/Large/submodel.gif \
		Images/Toolbar/Large/text.gif \
		Images/Toolbar/Large/tog_grid.gif \
		Images/Toolbar/Large/undo.gif \
		Images/Toolbar/Large/variable.gif \
		Images/Toolbar/Large/zoomfit.gif \
		Images/Toolbar/Large/zoomin.gif \
		Images/Toolbar/Large/zoomout.gif \
		Images/Toolbar/Large/zoomsel.gif \
		Images/Toolbar/Large/reel.gif \
		Images/Toolbar/add.gif \
		Images/Toolbar/alarm.gif \
		Images/Toolbar/clear.gif \
		Images/Toolbar/colourrcontr.gif \
		Images/Toolbar/colourrexp.gif \
		Images/Toolbar/compartment.gif \
		Images/Toolbar/condition.gif \
		Images/Toolbar/copy.gif \
		Images/Toolbar/copyc.gif \
		Images/Toolbar/creation.gif \
		Images/Toolbar/cut.gif \
		Images/Toolbar/delete.gif \
		Images/Toolbar/display.gif \
		Images/Toolbar/edit.gif \
		Images/Toolbar/event.gif \
		Images/Toolbar/find.gif \
		Images/Toolbar/findmore.gif \
		Images/Toolbar/flip_h.gif \
		Images/Toolbar/flip_v.gif \
		Images/Toolbar/flow.gif \
		Images/Toolbar/ghost.gif \
		Images/Toolbar/graph.gif \
		Images/Toolbar/greater.gif \
		Images/Toolbar/immigration.gif \
		Images/Toolbar/influence.gif \
		Images/Toolbar/less.gif \
		Images/Toolbar/loss.gif \
		Images/Toolbar/lprec.gif \
		Images/Toolbar/mainwin.gif \
		Images/Toolbar/move.gif \
		Images/Toolbar/mprec.gif \
		Images/Toolbar/new.gif \
		Images/Toolbar/noreel.gif \
		Images/Toolbar/notebook.gif \
		Images/Toolbar/notebookpage.gif \
		Images/Toolbar/open.gif \
		Images/Toolbar/paste.gif \
		Images/Toolbar/pause.gif \
		Images/Toolbar/print.gif \
		Images/Toolbar/property.gif \
		Images/Toolbar/redo.gif \
		Images/Toolbar/reel.gif \
		Images/Toolbar/refresh.gif \
		Images/Toolbar/relation.gif \
		Images/Toolbar/remove.gif \
		Images/Toolbar/reproduction.gif \
		Images/Toolbar/rerun.gif \
		Images/Toolbar/runenv.gif \
		Images/Toolbar/save.gif \
		Images/Toolbar/select.gif \
		Images/Toolbar/slider.gif \
		Images/Toolbar/snap.gif \
		Images/Toolbar/splithoriz.gif \
		Images/Toolbar/splitvert.gif \
		Images/Toolbar/squirt.gif \
		Images/Toolbar/state.gif \
		Images/Toolbar/submodel.gif \
		Images/Toolbar/table.gif \
		Images/Toolbar/text.gif \
		Images/Toolbar/tog_grid.gif \
		Images/Toolbar/undo.gif \
		Images/Toolbar/variable.gif \
		Images/Toolbar/zap.gif \
		Images/Toolbar/zoomfit.gif \
		Images/Toolbar/zoomin.gif \
		Images/Toolbar/zoomout.gif \
		Images/Toolbar/zoomsel.gif \
		Images/Toolbar/reel.gif \
		Images/Toolbar/noreel.gif \
		IOTools/DisplayFormats.tcl \
		IOTools/Grid5.tcl \
		IOTools/Logger.tcl \
		IOTools/Lollipop.tcl \
		IOTools/New3d.tcl \
		IOTools/Plotter.tcl \
		IOTools/PlotterXY.tcl \
		IOTools/Polygons.tcl \
		IOTools/Setrand.tcl \
		IOTools/Timeplot.tcl \
		IOTools/canvasnotes.tcl \
		IOTools/dxf.tcl \
		IOTools/graphtools.tcl \
		IOTools/maps2.tcl \
		IOTools/threedtools.tcl \
		IOTools/timeprofiles.tcl \
		IOTools/Standard\ tools/Control.tcl \
		IOTools/Standard\ tools/Sketch.tcl \
		IOTools/Standard\ tools/Slider.tcl \
		IOTools/Standard\ tools/TileInspector.tcl \
		IOTools/Standard\ tools/pestlink.tcl \
		IOTools/two_table.tcl \
		Licence.txt \
		README \
		Run/6d.h \
		Run/backend.h \
		Run/dllcalls.h \
		Run/equation.tcl \
		Run/exec.tcl \
		Run/forms.tcl \
		Run/graphs.tcl \
		Run/hai2mmii.tcl \
		Run/language.tcl \
		Run/toolbox.tcl \
		Run/userinfo.tpl \
		Run/messages.tcl \
		Run/mre.tcl \
		Run/params.tcl \
		Run/prefs.tcl \
		Run/prolog.tcl \
		Run/runmodel.tcl \
		Run/setup.tcl \
		Run/shank.cpp \
		Run/shapes.tcl \
		Run/simile.tcl \
		Run/simile128.ico \
		Run/simile16.ico \
		Run/simile32.ico \
		Run/simile64.ico \
		Run/support.tcl \
		Run/support1.cpp \
		Run/support2.cpp \
		Run/utility.tcl \
		Run/window.tcl \
		Run/simdoc32.ico \
		Run/Simile.desktop \
		$(SYSDIR)/bin/relay \
		$(SYSDIR)/bin/simile \
		$(SYSDIR)/bin/xgsimile \
		$(SYSDIR)/lib/SimileAutoObj/SimileAutoObj.itcl \
		$(SYSDIR)/lib/SimileAutoObj/pkgIndex.tcl \
		$(SYSDIR)/lib/Stubs/pkgIndex.tcl \
		$(SYSDIR)/lib/Stubs/libame_dll8.5.so \
		$(SYSDIR)/lib/Stubs/libunpacker8.5.so \
		$(SYSDIR)/lib/lib5d.so; \
	cd $(DESTDIR)$(INSTALL_TGT); \
	tar xf payload.tar; \
	mv Run/userinfo.tpl Run/userinfo.txt; \
	rm payload.tar; cd -; \
	mkdir -p $(DESTDIR)/usr/bin; \
	cd $(DESTDIR)/usr/bin; \
	ln -s ../..$(INSTALL_TGT)/$(SYSDIR)/bin/simile; cd -
endif

# call clean after changing license info in this file
clean:
	rm -f $(PROLOGSTATE) $(PROLOG_OBJ) $(PROLOG_DB) $(RELAY) \
	$(SLDIR)/$(SHANK) $(SHIM) $(UNPK) $(INSTLIB) $(MAIN) $(SCRIPT) \
