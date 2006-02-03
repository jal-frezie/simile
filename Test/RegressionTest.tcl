# Simile/Test/RegressionTest.tcl

lappend auto_path {../System/lib}
append env(PATH) {../System/bin}
package require SimileAutoObj

cd ../Test
#tk_messageBox -message "RT [glob *.tcl]"


set thisScript [info script]
set datetime [clock format [clock seconds] -format "%y%m%d%H%M%S"]
set ch [open "RegrTest${datetime}.txt" w]
foreach script [glob *.tcl] {
    if {[string match $thisScript $script]} {
        continue
    }
    tk_messageBox -message "RegressionTest pwd [pwd]; \n\
            thisScript $thisScript\n\
            Test script $script"
    set t [time [list source $script]]
}
puts $ch "$script $t"
close $ch

