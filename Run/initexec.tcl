set runHow process
source ../Run/runmodel.tcl
eval KickOff $argv
do_in_editor set runState($myNode,modelReady) 1
