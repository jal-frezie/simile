ifeq ($(shell uname),Darwin)
	WISHCMD = ~/Desktop/CVS\ Simile.app/Contents/MacOS/Simile
	SHAREDLIBEXTN = .dylib
else
	ifeq ($(shell uname),CYGWIN_NT-5.1)
		WISHCMD = "$(shell pwd)/System/bin/wish"
		SICSTUSCMD = "/cygdrive/c/Program Files/SICStus Prolog 3.10.1/bin/sicstus"
		SHAREDLIBEXTN = .dll
		GCCCMD = gcc
	else
		ifeq ($(shell uname),CYGWIN_NT-5.0)
			WISHCMD = "$(shell pwd)/System/bin/wish"
			SICSTUSCMD = "/cygdrive/c/Program Files/SICStus Prolog 3.10.1/bin/sicstus"
			SHAREDLIBEXTN = .dll
			GCCCMD = ../System/bin/g++ 
		else
			WISHCMD = ~/Simile/System/bin/wish
			SHAREDLIBEXTN = .so
			GCCCMD = gcc
		endif
	endif
endif

ifeq ($(shell uname),CYGWIN_NT-5.1)
simile: System/bin/main.sav System/lib/Stubs/ame_dll8.4$(SHAREDLIBEXTN) \
	System/bin/5d$(SHAREDLIBEXTN) System/bin/relay
else
ifeq ($(shell uname),CYGWIN_NT-5.0)
simile: System/bin/main.sav System/lib/Stubs/ame_dll8.4$(SHAREDLIBEXTN) \
	System/bin/5d$(SHAREDLIBEXTN) System/bin/relay
endif
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
