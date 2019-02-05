extras: gdi.dll hdc.dll printer.dll wmf.dll
#TCLBASE = /usr/local32
TCLBASE = /usr/local
FLAGS = -mwindows -shared -D_MSC_VER
#GCCCMD = gcc
GCCCMD = x86_64-w64-mingw32-gcc

gdi.dll: gdi.c
	$(GCCCMD) -o gdi.dll gdi.c $(FLAGS) -DUSE_TCL_STUBS -DUSE_TK_STUBS -I$(TCLBASE)/include -L$(TCLBASE)/lib -ltclstub86 -ltkstub86

hdc.dll: hdc.c
	$(GCCCMD) -o hdc.dll hdc.c $(FLAGS) -DUSE_TCL_STUBS -I$(TCLBASE)/include -L$(TCLBASE)/lib -ltclstub86

printer.dll: printer.c
	$(GCCCMD) -o printer.dll printer.c $(FLAGS) -DUSE_TCL_STUBS -I$(TCLBASE)/include -lwinspool -L$(TCLBASE)/lib  -ltclstub86

wmf.dll: wmf.c
	$(GCCCMD) -o wmf.dll wmf.c $(FLAGS) -DUSE_TCL_STUBS -DUSE_TK_STUBS -I$(TCLBASE)/include -L$(TCLBASE)/lib -ltclstub86 -ltkstub86
