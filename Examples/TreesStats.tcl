# Script to run the forestV4IP.sml model for 300 time units 
# and find descriptive stats on the number of trees during the run.
# (Not a very useful set of stats but this is just illustrative of the 
# scripting possiblities.)
# Uses the math::statistics package which provides commands to 
# calculate statistics of a list of numbers. Therefore, we need to get
# a Tcl list of values of the model variable we want to calculate 
# statistics for, during a simulation run. 
# The math::statistics package is part of tcllib http://www.tcl.tk/software/tcllib/

# Only needed when running from Wish shell in Unix; package must be put in
# auto_path if not using shell distributed with Simile
package require SimileAutoObj

# Create a Tcl object/command (modelWin) with which to control that instance of Simile
similescript::ModelWindow modelWin

# Tell Simile not to use the single window Model Run Environment
# We will are not going to use any helper anyway here.
# We then load the model and build it using C++
modelWin UseMRE false
modelWin Open "../Examples/forestV4IP.sml"
modelWin Run

# Create a runControl command/object with which to control
# (as you might expect) the run control.
similescript::RunControl runControl

# We - set the simulation to run for 1 time unit
#    - Initialise NumTrees as an empty list which will be used to contain 
#      the number of trees after each simulation run of 1 time unit
#    - create a loop to execute while the simulation time is <= 300 time units
#      the loop body runs the simulation for the number of time units 
#      set using runControl SetExecuteFor and appends the number of trees to 
#      the list (NumTrees) of values. 
#    - after the loop finishes we show the contents of the list on the console
runControl SetExecuteFor 1
set NumTrees {}             
while {[runControl GetCurrentTime]<=300} {
   runControl Start
   lappend NumTrees [runControl GetValue "/Number of Trees"]
}
set NumTrees

# We load the math::statistics package. 
# The lappend auto_path line makes the system look for the package
# in the given directory. It will still look in Simile's default Tcl lib directory
# Finally use  ::math::statistics commands to calculate statistics 
lappend auto_path {c:/program files/tcl/lib}
package require math::statistics 
::math::statistics::mean $NumTrees
::math::statistics::min $NumTrees
::math::statistics::max $NumTrees
puts "descriptive parameters: mean, minimum, maximum, number of data, standard deviation, variance"
puts [::math::statistics::basic-stats $NumTrees]

# now demonstrate that seeding the random generator produces reproducible 
# results -- do run twice more, seeding generator each time
for {set count 0} {$count<2} {incr count} {
    runControl Reset
    runControl SeedRandoms 1234
    set NumTrees {}             
    while {[runControl GetCurrentTime]<=300} {
	runControl Start
	lappend NumTrees [runControl GetValue "/Number of Trees"]
    }
    
    puts [::math::statistics::basic-stats $NumTrees]
}
