MINREL = 9

# days after install: 0 for no installation expiry
REL_EXP = 0

# What kind of system are we on
PLATFORM = $(shell uname -s)
ifndef MY_CPU
	MY_CPU=$(shell uname -m)
endif

# Prolog implementation to use -- GNU for Windows releases, GNU otherwise
# (currently GNU for everything)
ifneq (,$(filter $(MY_CPU),armv7l aarch64))
# result of filter is strings that match, test if not empty
    PROLOG = SWI
else
    PROLOG = GNU
endif

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

ifneq (,$(filter $(MY_CPU),x86_64 aarch64))
BITEXTN = 64
endif

# Default case: Linux
TCLDIR = /usr
TCLREF = $(TCLDIR)

SYSDIR = System
ifdef BITEXTN
	CFLAGS += $(OPT)
else
ifeq ($(MY_CPU),armv7l) # 32-bit but -m32 unrecognized
	CFLAGS += $(OPT)
else
	CFLAGS += $(OPT) -m32
endif
endif
SHAREDLIBPREFX = lib
MAKEPIC = -fPIC
MAKESL = -shared
VERS = $(shell echo "puts [info tclversion]" | $(TCLDIR)/bin/tclsh)
# 8.5 stubs work in 8.6 better than vice versa
PT = .

EXECDIR = $(SYSDIR)/bin
RESDIR = $(SYSDIR)/lib
SLDIR = $(RESDIR)
# Builds against Tcl included in distribution
# USETCL = -DUSE_TCL_STUBS -I$(TCLREF)/include/tcl$(VERS) -L$(TCLREF)/lib -ltclstub$(VERS)

# Next builds against system Tcl for Prolog debugging with Sicstus/dll
USETCL = -DUSE_TCL_STUBS -I$(TCLDIR)/include/tcl$(VERS) -ltclstub$(VERS)
LOCALIZE_TCL_REFS = ls # placebo command
CHECK_LOCAL_LIBS = -Wl,-rpath,'$$ORIGIN/..'
SHAREDLIBEXTN = .so

ifeq ($(PLATFORM),Darwin)
	SYSDIR = System$(BITEXTN)
	VERS = 8.6
	OSNUMBER = $(shell uname -r)
	TCLFW = /Library/Frameworks
ifeq ($(MY_CPU),x86_64)
	CFLAGS = $(OPT)
	export MACOSX_DEPLOYMENT_TARGET=10.13
else
	CFLAGS = $(OPT) -arch i386
	export MACOSX_DEPLOYMENT_TARGET=10.4
	LOCALIZE_TCL_REFS = install_name_tool -change \
		$(TCLFW)/Tcl.framework/Versions/$(VERS)/Tcl \
		@executable_path/../Frameworks/Tcl.framework/Tcl
# install_name_tool with fail silently if the new path is longer than the path it's replacing. Always verify with 'otool -L' that the path was changed as expected.
endif
	ARCHEXTN = _mac
# build for everything unless I am on Barbie
	ifeq ($(OSNUMBER),8.11.0)
		CFLAGS = $(OPT)
	        ARCHEXTN = _ppc
	endif
	EXECEXTN = $(ARCHEXTN)
	MAKEPIC = -fPIC
	MAKESL = -dynamiclib
# make sure Current is set to right version
	USETCL =  -DUSE_TCL_STUBS -F$(TCLFW) -framework Tcl -ltclstub$(VERS)
	CHECK_LOCAL_LIBS =
	SHAREDLIBEXTN = $(ARCHEXTN).dylib
else
	PLATFORM = $(shell uname -o)
endif 

ifeq ($(PLATFORM),Msys) # any Windows, any toolchain
        # GCCCMD = "$(shell pwd)/System/bin/g++" # can't find process.h
	SYSDIR = System$(BITEXTN)
ifeq ($(MY_CPU),x86_64)
	TCLDIR =  /usr/local
	SWIPLDIR = "/c/Program files/swipl"
	GCCCMD = x86_64-w64-mingw32-gcc
	GPPCMD = x86_64-w64-mingw32-g++
	RESCMD = x86_64-w64-mingw32-windres
else
#	TCLDIR = "/c/Program files (x86)/Tcl"
# Actually, use local TclTk as above dir not exist on 32bit machines --
#	TCLDIR = "$(shell pwd)/$(SYSDIR)"
	TCLDIR = /usr/local32
	RESCMD = windres
	INSTLIB = Run/install.dll
# must be 32-bit because installer is
endif
	VERSION = $(shell echo "puts [info tclversion]" | $(TCLDIR)/bin/tclsh)
	PT =
	VERS = $(subst .,,$(VERSION))

	TCLREF = $(TCLDIR)
	TCLINC = $(TCLREF)/include
	CFLAGS = $(OPT)
	SHAREDLIBPREFX = 
	MAKEPIC = 
	MAKESL = -shared
# This really just tests that tcldir is right

	SLDIR = $(EXECDIR)
# to be used after CDing to Run -- assume all refs are from a subdirectory
# for linking with stubs
	USETCL = -DUSE_TCL_STUBS -I$(TCLINC) -L$(TCLREF)/lib -ltclstub$(VERS)
	USETK = -DUSE_TK_STUBS -ltkstub$(VERS)
# for direct linking
#	USETCL = -I$(TCLINC) -L$(TCLREF)/lib -ltcl$(VERS)
#	USETK = -ltk$(VERS)
	CHECK_LOCAL_LIBS =
	SHAREDLIBEXTN = .dll
	ARCHEXTN = _win
	EXECEXTN = .exe
	MAIN = $(EXECDIR)/Simile.exe
	SCRIPT = $(EXECDIR)/SimileScript.exe
endif

PROLOGSTATE = $(EXECDIR)/xssimile$(EXECEXTN)
PROLOG_DB = $(RESDIR)/struct_db
# $(SHAREDLIBEXTN) not needed
ifeq ($(PROLOG),GNU)
	PROLOGSTATE = $(EXECDIR)/xgsimile$(EXECEXTN)
	PROLOG_OBJ = $(EXECDIR)/gmain$(ARCHEXTN).o
	PROLOG_DB = $(EXECDIR)/struct_db$(ARCHEXTN).o
endif

STUBS_DIR = $(RESDIR)/Stubs
SHIM = $(STUBS_DIR)/$(SHAREDLIBPREFX)ame_dll6$(PT)$(MINREL)$(SHAREDLIBEXTN)
UNPK = $(STUBS_DIR)/$(SHAREDLIBPREFX)unpacker6$(PT)$(MINREL)$(SHAREDLIBEXTN)
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
UINFO_TPL = userinfo.swi
$(PROLOGSTATE): $(PROLOG_FILES)  Prolog/smain.pl $(PROLOG_DB)
	cd Prolog; swipl --goal=main --stand_alone=true -o ../$(PROLOGSTATE) -c smain.pl; cd ..
$(PROLOG_DB): Prolog/struct_db.c
# for old SWI, or if building with mingw when swipl built with msvc
#	cd Prolog; gcc -c -I$(SWIPLDIR)/include -D__SWI_PROLOG__ \
#		$(MAKEPIC) struct_db.c; \
#		gcc $(MAKESL) -o struct_db$(SHAREDLIBEXTN) \
#		struct_db.o $(SWIPLDIR)/bin/swipl.dll; cd ..
# for new SWI
	cd Prolog; swipl-ld -o ../$(PROLOG_DB) struct_db.c \
		-cc-options,$(MAKEPIC) \
		-ld-options,$(MAKESL); cd ..
# note that libxml2 includes and libs are not needed
endif
ifeq ($(PROLOG),GNU)
UINFO_TPL=userinfo.gnu
# All-in-one without database
# $(PROLOGSTATE): $(PROLOG_FILES)
# 	cd Prolog; gplc --no-top-level -o ../$(PROLOGSTATE) gmain.pl \
# 		-L '$(OPT)'; cd ..
# In separate steps with database
$(PROLOGSTATE): $(PROLOG_OBJ) $(PROLOG_DB)
	gplc --no-top-level -o $(PROLOGSTATE) $(PROLOG_OBJ) $(PROLOG_DB) \
		-L '$(CFLAGS)'
$(PROLOG_OBJ): $(PROLOG_FILES) Prolog/gmain.pl Prolog/gstr_db.pl
	cd Prolog; gplc -o ../$(PROLOG_OBJ) -c -C '$(CFLAGS)' gmain.pl; cd ..
$(PROLOG_DB): Prolog/struct_db.c
	cd Prolog; gplc -c -C '$(CFLAGS) -D_GNU_PROLOG' \
		-o ../$(PROLOG_DB) struct_db.c; cd ..
endif

#ifeq ($(UNAME),MINGW32_NT)
# MSYS cannot execute Wish: libraries? Try compiler direct

ifeq ($(PLATFORM), none)
$(SHIM): $(SLDIR)/$(SHANK) Run/ame_cmx.c Run/shank.cpp Run/dllcalls.h
	cd Run; $(GPPCMD) $(CFLAGS) -I. $(MAKEPIC) $(MAKESL) -o ../$(SHIM) \
		ame_cmx.c shank.cpp $(USETCL) -L../$(RESDIR); cd ..; \
	$(LOCALIZE_TCL_REFS) $(SHIM)
else
$(SHIM): $(SLDIR)/$(SHANK) Run/ame_cmx.c Run/dllcalls.h
	cd Run; $(GCCCMD) $(CFLAGS) -I. $(MAKEPIC) $(MAKESL) -o ../$(SHIM) \
		ame_cmx.c $(USETCL) -L../$(RESDIR) -l5d$(ARCHEXTN) \
		$(CHECK_LOCAL_LIBS); cd ..; \
	$(LOCALIZE_TCL_REFS) $(SHIM)
endif

$(UNPK): Run/unpacker.c Run/dllcalls.h Makefile
	cd Run; $(GCCCMD) $(CFLAGS) $(DEFNS) -I. $(MAKEPIC) $(MAKESL) \
		-o ../$(UNPK) unpacker.c $(USETCL); cd ..; \
	$(LOCALIZE_TCL_REFS) $(UNPK)

# literal SLDIR allows different SHANK clauses for Windows vs Unix

# Windows: idiosyncratic stuff allows dynamic linker to work
# (even with gcc 4.5.0)...static stops exit error in win32/tcl8.6
$(EXECDIR)/$(SHANK): Run/shank.cpp Run/dllcalls.h Run/6d.h Run/backend.h
	cd Run; $(GPPCMD) -DSHARELIB $(CFLAGS) $(MAKEPIC) $(MAKESL) -static \
		-I. -Wl,--out-implib,lib5d$(ARCHEXTN).a -o $(SHANK) shank.cpp; \
		mv $(SHANK) ../$(SLDIR); \
		mv lib5d$(ARCHEXTN).a ../$(RESDIR); cd ..

# Unix: not needed for Linux as it can build at run time
$(RESDIR)/$(SHANK): Run/shank.cpp Run/dllcalls.h Run/6d.h Run/backend.h
	cd Run; $(GPPCMD) $(CFLAGS) -I. $(MAKEPIC) $(MAKESL) \
		-o ../$(SLDIR)/$(SHANK) shank.cpp; cd ..

# Build a .dll to check licence code during Windows installation
# Version for GPInstall by QSC
#Run/install.dll: Run/install.c Makefile
#	cd Run; $(GCCCMD) $(CFLAGS) $(DEFNS) -I. -I../System/include $(MAKESL) \
#		-o install.dll install.c -L../System/lib -lcrypto -lssl; \
#		cd ..
# Version for MakeMSI
#Run/install.dll: Run/install_msi.cpp Run/install_msi.rc Makefile
#	cd Run; windres -i install_msi.rc -o resource_msi.o; \
#		$(GPPCMD) $(CFLAGS) $(DEFNS) -I../System/include \
#		-I/c/MsiIntel.SDK/include $(MAKESL) -o install.dll \
#		install_msi.c resource_msi.o /c/MsiIntel.SDK/lib/msi.lib \
#		-L../System/lib -lcrypto -lssl; cd ..
# Version for Advanced Installer
# -static-libgcc is neeeded because this also used for 64bit install (and 32bit
# install on 64bit systems) where 32bit libraries maybe missing
MSI = "/c/MsiIntel.sdk"
$(INSTLIB): Run/install_adv.c Makefile
	cd Run; $(GCCCMD) -static -m32 $(CFLAGS) $(DEFNS) \
		-I$(MSI)/include $(MAKEPIC) $(MAKESL) \
		-o ../$(INSTLIB) install_adv.c -L$(MSI)/lib -lmsi \
		-lcrypto -lssl; cd ..

# the rc objects from windres are ommitted from linking below becaise they
# do strange things to dll dependencies causing c000007b errors
$(EXECDIR)/Simile.exe: Interp/Simile.c Interp/Simile.rc
	cd Interp; $(RESCMD) -o rc.o Simile.rc; \
	$(GCCCMD) $(CFLAGS) -DTCL_BROKEN_MAINARGS -DUNICODE -D_UNICODE \
		-o ../$(EXECDIR)/Simile.exe Simile.c -I$(TCLINC) \
		-L$(TCLREF)/lib -ltcl$(VERS) -ltk$(VERS) -mwindows; cd ..

$(SCRIPT): Interp/script.c Interp/script.rc
	cd Interp; $(RESCMD) -o scriptrc.o script.rc; \
	$(GCCCMD) $(CFLAGS) -DTCL_BROKEN_MAINARGS -DUNICODE -D_UNICODE \
		-I$(TCLINC) -o ../$(SCRIPT) script.c -I$(TCLINC) \
		-L$(TCLREF)/lib -ltcl$(VERS) -ltk$(VERS) -mwindows; cd ..
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
	cd Run; $(GCCCMD) $(CFLAGS) -o ../$(RELAY) relay.c; cd ..

ifeq ($(PLATFORM),GNU/Linux)
# install used for packaging for distributions
SHAREDIR = /usr/share
INSTALL_TGT = $(SHAREDIR)/simile-6.$(MINREL)
LIBDIR = /usr/lib
# overridden by rpm build on Fedora 64-bit
EXEC_TGT = $(LIBDIR)/simile-6.$(MINREL)
install:
	mkdir -p $(DESTDIR)$(INSTALL_TGT); \
	tar cf $(DESTDIR)$(INSTALL_TGT)/payload.tar \
		eula.txt \
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
		Examples/ant.cnv \
		Examples/mouse.cnv \
		Examples/BoilerDataLogger.tcl \
		Examples/TreesMultiRun.tcl \
		Examples/TreesStats.tcl \
		Examples/TreesTableHelper.tcl \
		Extensions/Scripting.tcl \
		Functions/Arithmetic.pl \
		Functions/Hidden.pl \
		Functions/List\ handling.pl \
		Functions/Model\ properties.pl \
		Functions/Statistics.pl \
		Functions/Trigonometry.pl \
		Functions/Typed\ submodels.pl \
		Functions/new_units.pl \
		Functions/procs.cpp \
		Functions/procs.tcl \
		Functions/Fragments/*.sml \
		help/concepts \
		help/data \
		help/diagrams \
		help/equations \
		help/files \
		help/index.htm \
		help/new/index.htm \
		help/run \
		help/scripting \
		help/start \
		help/submodels \
		Images/Control/pause.gif \
		Images/Control/play.gif \
		Images/Control/stop.gif \
		Images/HelpAboutUpper.gif \
		Images/Icons/*.png \
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
		Images/Toolbar/Large/image.gif \
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
		Images/Toolbar/image.gif \
		Images/Toolbar/immigration.gif \
		Images/Toolbar/influence.gif \
		Images/Toolbar/less.gif \
		Images/Toolbar/loss.gif \
		Images/Toolbar/lprec.gif \
		Images/Toolbar/mainwin.gif \
		Images/Toolbar/move.gif \
		Images/Toolbar/mprec.gif \
		Images/Toolbar/multi.gif \
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
		IOTools/2-D\ Shapes/circle_layer.tcl \
		IOTools/2-D\ Shapes/ellipse_layer.tcl \
		IOTools/2-D\ Shapes/line_layer.tcl \
		IOTools/EventSounds.tcl \
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
		IOTools/edit_colour_key.tcl \
		IOTools/maps2.tcl \
		IOTools/threedtools.tcl \
		IOTools/textshow.tcl \
		IOTools/timeprofiles.tcl \
		IOTools/layers.tcl \
		IOTools/grid_layer.tcl \
		IOTools/polygon_layer.tcl \
		IOTools/photo_layer.tcl \
		IOTools/shape_layer.tcl \
		IOTools/animals.tcl \
		IOTools/ZooXYZ.tcl \
		IOTools/Standard\ tools/Control.tcl \
		IOTools/Standard\ tools/Sketch.tcl \
		IOTools/Standard\ tools/Slider.tcl \
		IOTools/Standard\ tools/TileInspector.tcl \
		IOTools/Standard\ tools/pestlink.tcl \
		IOTools/two_table.tcl \
		README \
		Run/6d.h \
		Run/backend.h \
		Run/client5d.tcl \
		Run/dllcalls.h \
		Run/equation.tcl \
		Run/exec.tcl \
		Run/forms.tcl \
		Run/graphs.tcl \
		Run/hai2mmii.tcl \
		Run/language.tcl \
		Run/toolbox.tcl \
		Run/$(UINFO_TPL) \
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
		simile.desktop
	cd $(DESTDIR)$(INSTALL_TGT); \
	tar xf payload.tar; \
	mv Run/$(UINFO_TPL) Run/userinfo.tpl; \
#	touch Run/userinfo.txt; \
# target only used in Linux which ignores this file \
	mkdir -p $(DESTDIR)$(SHAREDIR)/applications; \
	mv simile.desktop $(DESTDIR)$(SHAREDIR)/applications; \
	rm payload.tar
	mkdir -p $(DESTDIR)$(SHAREDIR)/man/man1
	mv simile.1 $(DESTDIR)$(SHAREDIR)/man/man1
	mkdir -p $(DESTDIR)$(EXEC_TGT)
	tar cf $(DESTDIR)$(EXEC_TGT)/payload.tar \
		$(SYSDIR)/bin/relay \
		$(SYSDIR)/bin/simile \
		$(PROLOGSTATE) \
		$(PROLOG_DB) \
		$(SYSDIR)/lib/SimileAutoObj/SimileAutoObj.itcl \
		$(SYSDIR)/lib/SimileAutoObj/pkgIndex.tcl \
		$(SYSDIR)/lib/Stubs/can2svg/can2svg.tcl \
		$(SYSDIR)/lib/Stubs/can2svg/pkgIndex.tcl \
		$(SYSDIR)/lib/Stubs/can2svg/uriencode.tcl \
		$(SYSDIR)/lib/Stubs/pkgIndex.tcl \
		$(SHIM) \
		$(UNPK) \
		$(SLDIR)/$(SHANK)
	cd $(DESTDIR)$(EXEC_TGT); \
	ln -s ../../..$(INSTALL_TGT)/Examples; \
	ln -s ../../..$(INSTALL_TGT)/Extensions; \
	ln -s ../../..$(INSTALL_TGT)/Functions; \
	ln -s ../../..$(INSTALL_TGT)/help; \
	ln -s ../../..$(INSTALL_TGT)/Images; \
	ln -s ../../..$(INSTALL_TGT)/IOTools; \
	ln -s ../../..$(INSTALL_TGT)/Run; \
	tar xf payload.tar; \
	rm payload.tar
	mkdir -p $(DESTDIR)/usr/bin
	cd $(DESTDIR)/usr/bin; \
	ln -s ../..$(EXEC_TGT)/$(SYSDIR)/bin/simile
endif

# call clean after changing license info in this file
clean:
	rm -f $(PROLOGSTATE) $(PROLOG_OBJ) $(PROLOG_DB) $(RELAY) \
	$(SLDIR)/$(SHANK) $(SHIM) $(UNPK) $(INSTLIB) $(MAIN) $(SCRIPT) \
