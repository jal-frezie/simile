ifeq ($(shell uname),Darwin)
	WISHCMD = ~/Desktop/CVS\ Simile.app/Contents/MacOS/Simile
	SHAREDLIBEXTN = .dylib
else
	WISHCMD = ~/Simile/System/bin/wish
	SHAREDLIBEXTN = .so
endif

simile: Run/xgsimile System/lib/Stubs/libame_dll8.4$(SHAREDLIBEXTN) \
	System/lib/lib5d$(SHAREDLIBEXTN)

vpath %.pl Prolog

Run/xgsimile: ame_gen.pl backup.pl build.pl compile.pl database.pl \
		dialogue.pl draw.pl event.pl gmain.pl graphics.pl image.pl \
		input.pl instance.pl inters.pl language.pl library.pl link.pl \
		main.pl m_class.pl menu.pl m_struct.pl m_update.pl node.pl \
		output.pl render.pl smain.pl sp_only.pl ss_import.pl state.pl \
		submodel.pl tcltk.pl text.pl units.pl utility.pl
	cd Prolog; gplc --no-top-level -o ../Run/xgsimile gmain.pl; cd ..

vpath 	%.cpp 	Run
vpath 	%.h 	Run
vpath 	%.tcl 	Run

System/lib/Stubs/libame_dll8.4$(SHAREDLIBEXTN): ame_cmx.cpp dllcalls.h \
		makedlls.tcl
	cd Run; $(WISHCMD) makedlls.tcl; cd ..

System/lib/lib5d$(SHAREDLIBEXTN): shank.cpp dllcalls.h
	cd Run;	$(WISHCMD) makedlls.tcl; cd ..
