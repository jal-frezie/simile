# set the following as required for your system,
# some execs may be on the path
# Updating with a clean copy from CVS will overwrite!
# Normal updating (merging) from the CVS will conserve the
# customisation - though conflicts may, of course, occur.
# could require execs to be in PATH, sicstus, gplc, gcc/g++
SICSTUSCMD = "/cygdrive/c/Program Files/SICStus Prolog 3.10.1/bin/sicstus"
GCCCMD = gcc

UNAME = $(shell uname)
ifeq ($(shell uname),CYGWIN_NT-5.1)
	UNAME = CYGWIN_NT
endif 
ifeq ($(shell uname),CYGWIN_NT-5.0)
	UNAME = CYGWIN_NT
endif 

# default *nix variables overwritten in special cases
WISHCMD = ~/Simile/System/bin/wish
GCCCMD = gcc
SHAREDLIBEXTN = .so
# SICSTUSCMD not used, for Linux release
# but is for Windows, set in the CYGWIN_NT section

ifeq ($(UNAME),Darwin)
	WISHCMD = ~/Desktop/CVS\ Simile.app/Contents/MacOS/Simile
	SHAREDLIBEXTN = .dylib
endif 
ifeq ($(UNAME),CYGWIN_NT)
	WISHCMD = "$(shell pwd)/System/bin/wish"
	GCCCMD = ../System/bin/g++ 
	SICSTUSCMD = "/cygdrive/c/Program Files/SICStus Prolog 3.10.1/bin/sicstus"
	SHAREDLIBEXTN = .dll
endif
	
ifeq ($(UNAME),CYGWIN_NT)
simile: System/bin/main.sav System/lib/Stubs/ame_dll8.4$(SHAREDLIBEXTN) \
	System/bin/5d$(SHAREDLIBEXTN) System/bin/relay
else
simile: Run/xgsimile System/lib/Stubs/libame_dll8.4$(SHAREDLIBEXTN) \
	System/lib/lib5d$(SHAREDLIBEXTN) System/bin/relay
endif

vpath %.pl Prolog

# Windows release, Prolog is Sicstus
System/bin/main.sav: ame_gen.pl backup.pl build.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl smain.pl graphics.pl image.pl \
		input.pl instance.pl inters.pl language.pl library.pl link.pl \
		main.pl m_class.pl menu.pl m_struct.pl m_update.pl node.pl \
		output.pl render.pl smain.pl sp_only.pl ss_import.pl state.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl
	cd Prolog; $(SICSTUSCMD) -l buildmainsav.pl; cd ..


Run/xgsimile: ame_gen.pl backup.pl build.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl gmain.pl graphics.pl image.pl \
		input.pl instance.pl inters.pl language.pl library.pl link.pl \
		main.pl m_class.pl menu.pl m_struct.pl m_update.pl node.pl \
		output.pl render.pl smain.pl sp_only.pl ss_import.pl state.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl
	cd Prolog; gplc --no-top-level -o ../Run/xgsimile gmain.pl; cd ..

vpath 	%.cpp 	Run
vpath 	%.c 	Run
vpath 	%.h 	Run
vpath 	%.tcl 	Run

System/lib/Stubs/libame_dll8.4$(SHAREDLIBEXTN): ame_cmx.cpp dllcalls.h \
		shank.cpp makedlls.tcl
	cd Run; $(WISHCMD) makedlls.tcl; cd ..
	
# Windows 
System/lib/Stubs/ame_dll8.4$(SHAREDLIBEXTN): ame_cmx.cpp dllcalls.h \
		shank.cpp makedlls.tcl
	cd Run; $(WISHCMD) makedlls.tcl; cd ..
	
# Is there a rule for System/lib/lib5d$(SHAREDLIBEXTN)
# I guess that would be System/bin/5d.dll for Windows 
System/bin/5d(SHAREDLIBEXTN): ame_cmx.cpp dllcalls.h \
		shank.cpp makedlls.tcl
	cd Run; $(WISHCMD) makedlls.tcl; cd ..


System/bin/relay: relay.c
	cd Run; $(GCCCMD) -o ../System/bin/relay relay.c; cd ..
