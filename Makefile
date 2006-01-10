# set the following as required for your system,
# some execs may be on the path
# Updating with a clean copy from CVS will overwrite!
# Normal updating (merging) from the CVS will conserve the
# customisation - though conflicts may, of course, occur.
# could require execs to be in PATH, sicstus, gplc, gcc/g++
# default *nix variables overwritten in special cases
WISHCMD = ~/Simile/System/bin/wish
GCCCMD = gcc

UNAME = $(shell uname)
ifeq ($(shell uname),CYGWIN_NT-5.1)
	UNAME = CYGWIN_NT
endif 
ifeq ($(shell uname),CYGWIN_NT-5.0)
	UNAME = CYGWIN_NT
endif 
ifeq ($(shell uname),MINGW32_NT-5.1)
	UNAME = MINGW32_NT
endif 
ifeq ($(shell uname),MINGW32_NT-5.0)
	UNAME = MINGW32_NT
endif 


# Default case: any Windows, any toolchain
	PROLOGSTATE = System/bin/main.sav
	WISHCMD = "$(shell pwd)/System/bin/wish"
	# GCCCMD = "$(shell pwd)/System/bin/g++" # can't find process.h
	SLDIR = bin
	SHAREDLIBPREFX = 
	VERS = 84
	SHAREDLIBEXTN = .dll
	EXECEXTN = .exe
	INSTLIB = Run/install.dll
ifeq ($(UNAME),Darwin)
	PROLOGSTATE = Run/xgsimile
	WISHCMD = ~/Desktop/CVS\ Simile.app/Contents/MacOS/Simile
	SLDIR = lib
	SHAREDLIBPREFX = lib
	VERS = 8.4
	SHAREDLIBEXTN = .dylib
	EXECEXTN =
	INSTLIB = 
endif 
ifeq ($(UNAME),Linux)
	PROLOGSTATE = Run/xgsimile
	SLDIR = lib
	SHAREDLIBPREFX = lib
	VERS = 8.4
	SHAREDLIBEXTN = .so
	EXECEXTN =
	INSTLIB = 
endif

simile: $(PROLOGSTATE) System/bin/relay$(EXECEXTN) \
	System/lib/Stubs/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN) \
	System/$(SLDIR)/$(SHAREDLIBPREFX)5d$(SHAREDLIBEXTN) $(INSTLIB)

vpath %.pl Prolog

# Windows release, Prolog is Sicstus
System/bin/main.sav: ame_gen.pl backup.pl build.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl smain.pl graphics.pl image.pl \
		input.pl instance.pl inters.pl language.pl library.pl link.pl \
		main.pl m_class.pl menu.pl m_struct.pl m_update.pl node.pl \
		output.pl render.pl smain.pl sp_only.pl ss_import.pl state.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl
	cd Prolog; sicstus -l buildmainsav.pl; cd ..


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

ifeq ($(UNAME),MINGW32_NT)
# MSYS cannot execute Wish: libraries? Try compiler direct
DEFNS=-DUSE_TCL_STUBS -DSIM_FINAL_EXPIRY=0 -DSIM_DAYS_AFTER_INSTALL=0 \
-DSIM_STANDARD -DSIM_LICENSED

System/lib/Stubs/ame_dll84.dll: ame_cmx.cpp dllcalls.h System/bin/5d.dll
	cd Run; g++ -c $(DEFNS) -I. -I../System/include ame_cmx.cpp; g++ -shared -o ../System/lib/Stubs/ame_dll84.dll ame_cmx.o ../System/lib/tclstub84.lib -L../System/lib -l5ddll; cd ..

System/bin/5d.dll: shank.cpp dllcalls.h
	cd Run; g++ -c -DSHARELIB -I. shank.cpp; g++ -shared -o 5d.dll -Wl,--out-implib,lib5ddll.a shank.o; mv 5d.dll ../System/bin; mv lib5ddll.a ../System/lib; cd ..

Run/install.dll: install.cpp
	cd Run; g++ -c $(DEFNS) -I. -I../System/include install.cpp; g++ -shared -o install.dll install.o -L../System/lib -lcrypto -lssl; cd ..

else

# CYGWIN and non-Windows
System/lib/Stubs/$(SHAREDLIBPREFX)ame_dll$(VERS)$(SHAREDLIBEXTN): \
	ame_cmx.cpp dllcalls.h shank.cpp makedlls.tcl
	cd Run; $(WISHCMD) makedlls.tcl; cd ..

# Is there a rule for System/lib/lib5d$(SHAREDLIBEXTN)
# I guess that would be System/bin/5d.dll for Windows 
System/$(SLDIR)/$(SHAREDLIBPREFX)5d(SHAREDLIBEXTN): ame_cmx.cpp dllcalls.h \
		shank.cpp makedlls.tcl
	cd Run; $(WISHCMD) makedlls.tcl; cd ..
endif

System/bin/relay$(EXECEXTN): Run/relay.c
	cd Run; $(GCCCMD) -o ../System/bin/relay$(EXECEXTN) relay.c; cd ..
