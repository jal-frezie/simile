#!/usr/local/ActiveTcl/bin/tclsh

# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

# These are the settings for the particular version we want to make
# Compiler that will be used to make the stub for Windows
set compiler_for_windows gnu
# edition: evaluation, teaching, standard or enterprise
set edition standard
# date of final expiry: {hh:mm D M Y} or {} for permanent
set final_expiry {3 Oct 2004}
# days after install: 0 for no installation expiry
set days_after_install 0
# License code required to verify name/corp/edition: 0 for no
set needs_license 0

if {[llength $final_expiry]} {
    set expiry_ticks [clock scan $final_expiry]
} else {
    set expiry_ticks 0
}

set defns [list -DSIM_FINAL_EXPIRY=$expiry_ticks \
	       -DSIM_DAYS_AFTER_INSTALL=$days_after_install]
lappend defns -DSIM_[string toupper $edition]
if {$needs_license} {
    lappend defns -DSIM_LICENSED
}
if {[string match Darwin $tcl_platform(os)]} {
     lappend defns -DSIM_OPSYS_Darwin
}

scan [info tclversion] {%d.%d} MAJ MIN
set onUnix [string match unix $tcl_platform(platform)]
#	To build for Tcl dll included under distribution directory...
set TCL [file dirname [file dirname [info library]]]
set STUBS ../System/lib/Stubs
#ShowMessage debug info "TCL $TCL" ok

if $onUnix {
    # You may be asking yourself why I need to explicitly specify a location for
    # the Tcl library files, since they should be in LD_LIBRARY_PATH. It is because
    # some people find it easier to build the stub from exec_only.tcl, which gives
    # them error messages to the console but does not set LD_LIBRARY_PATH.
    set TARGET ${STUBS}/libame_dll$MAJ.$MIN[info sharedlibextension]
    if {[string match Darwin $tcl_platform(os)]} {
        eval {exec g++ -c -O -fPIC} $defns {-I. -I$TCL/Headers ./ame_cmx.cpp}
        exec g++ -dynamiclib -o $TARGET ame_cmx.o -ldl -framework Tcl
    } else {
        eval {exec g++ -c -O -fPIC} $defns {-I. -I$TCL/include ./ame_cmx.cpp}
        exec g++ -shared -o $TARGET ame_cmx.o -L$TCL/lib -ltcl$MAJ.$MIN
    }
} else {
    set TCL [file attributes $TCL -shortname]
    set TARGET ${STUBS}/ame_dll$MAJ$MIN.dll
    set dll tcl${MAJ}${MIN}
    
    # Older TclTks may have a special library for Visual C, which is also used by mingw
    set tclLib $TCL/lib/${dll}vc.lib
    if {![file exists $tclLib]} {
	set tclLib $TCL/lib/$dll.lib
    }
    
    # Method using MingW32 gcc: Dlls refuse to load into tcl when
    # it is running under Prolog. However it seems to work OK in WinNT.
    if {[string match gnu $compiler_for_windows]} {
	eval {exec g++ -c -o obj.o} $defns \
	    {-I. -I$TCL/include ./ame_cmx.cpp}	
	exec dllwrap --dllname=$TARGET --def=stub.def --driver-name=g++ obj.o $tclLib
	
	# Do the install dll as well
	eval {exec g++ -c -o obj.o} $defns \
	    {-I. -I$TCL/include ./install.cpp}	
	exec dllwrap --dllname=install.dll --def=install.def --driver-name=g++ obj.o
	
	# Method using command line calls to MSVC 4.0 or later -- works well
    } else {
	set TOOLS32 [file dir [file dir [lindex [auto_execok cl.exe] 0]]]
	eval {exec $TOOLS32/bin/cl.exe -Ox -c -W3 -nologo \
		  -DWIN32 -D_WIN32 -D_DLL -D_X86_=1} $defns \
	    {-I. -I$TOOLS32/include -I$TCL/include ./ame_cmx.cpp}
	exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO -align:0x1000 /MACHINE:IX86 -entry:_DllMainCRTStartup@12 -dll -out:$TARGET $tclLib $TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib $TOOLS32/lib/oldnames.lib ./ame_cmx.obj
	eval {exec $TOOLS32/bin/cl.exe -Ox -c -W3 -nologo \
		  -DWIN32 -D_WIN32 -D_DLL -D_X86_=1} $defns \
	    {-I. -I$TOOLS32/include ./install.cpp}
	exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO -align:0x1000 /MACHINE:IX86 -entry:_DllMainCRTStartup@12 -dll -out:install.dll $TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib $TOOLS32/lib/oldnames.lib ./install.obj
    }
    
    # Also if in Windows we need to prepare a way for gcc to link the
    # tcl dll into the model program. The MSVC compiler is used to
    # build the stub (for now) because it makes life easier, but users
    # should not have to buy it...
    #	    exec impdef /windows/system/tcl80.dll >tcl80.def
    #	    exec dlltool --dllname tcl80.dll --def tcltk.def \
        #		--output-lib libtcl80.a
    # and likewise to link the model dll into the stub...
    #	    exec dlltool --dllname ame_dll.dll --def ame_dll.def \
        #		--output-lib libame_dll.a
}

pkg_mkIndex $STUBS *[info sharedlibextension]
exit
