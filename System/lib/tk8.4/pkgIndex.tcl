if {[package vcompare [package provide Tcl] 8.4] != 0} { return }
proc FindTkExec {dir} {
    global tcl_platform
    if {[string equal unix $tcl_platform(platform)]} {
	return [list load [file join $dir .. libtk8.4.so] Tk]
    } else {
	return [list load [file join $dir .. .. bin tk84.dll] Tk]
    }
}
package ifneeded Tk 8.4 [FindTkExec $dir]
