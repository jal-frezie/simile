# Only needed when running from Wish shell in Unix; package must be put in
# auto_path if not using shell distributed with Simile
package require SimileAutoObj

similescript::ModelWindow modelWin
modelWin Open "../Examples/forestV4IP.sml"
modelWin Run

# Create a runControl command/object with which to control
# (as you might expect) the run control.
similescript::RunControl runControl
set rc runControl

# set execution parameters
$rc SetIntegrationMethod Euler
$rc SetTimeStep 1 0.1
$rc SetExecuteFor 50
$rc SetDisplayInterval 1

# put headers in result list
lappend results [join [list r total final] ,]
# start the loop
for {set i 5} {$i < 15} {set i [expr {$i+0.5}]} {

# set the file parameter
    $rc SetValue /r $i

# reset the model so new param value takes effect, then run it
    $rc Reset
    $rc Start

# attach the results to the log, comma separated
    set total [lindex [$rc GetValue /Tree] 0 end-1]
    set final [$rc GetValue {/Number of Trees}]
    lappend results [join [list $i $total $final] , ]
}

# Now write the data, with line breaks
puts [join $results \n]

# this is an example of what to do to write the data to a file

# set stm [open ../../Test/results.csv w]
# puts $stm [join $results \n]
# close $stm
