simile: Run/xgsimile System/lib/Stubs/libame_dll8.4.so System/lib/lib5d.so

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

System/lib/Stubs/libame_dll8.4.so: ame_cmx.cpp dllcalls.h
	cd Run;	../System/bin/wish makedlls.tcl; cd ..

System/lib/lib5d.so: shank.cpp dllcalls.h
	cd Run;	../System/bin/wish makedlls.tcl; cd ..
