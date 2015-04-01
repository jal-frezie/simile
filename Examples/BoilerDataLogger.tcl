# Only needed when running from Wish shell in Unix; package must be put in
# auto_path if not using shell distributed with Simile
package require SimileAutoObj

# Create a Tcl object/command (modwin) with which to control that instance of Simile
similescript::ModelWindow modwin

modwin Open control.sml
modwin Run

# Create a runControl command/object with which to control
# (as you might expect) the run control.
similescript::RunControl runctl
runctl Hide

# create a Data Logger to to save a CSV file of variable values
# similescript::DataLogger <object/command name> <execution window to get values from> <window title (not very useful usually)>
similescript::DataLogger20111205 datlog runctl "Hello World!"

# log all the variables in the controller
datlog AddAllVariables {/PID controller}
datlog SetSavePathTo Logs

# Get the directory which the data logger is writing files to and report
puts "Writing files to [datlog cget -curFolder]"

# now run the model, we will have a separate file for each variable 
# in the submodel
runctl SetExecuteFor 75
runctl Start

# changing the mode will cause the old files to be closed
datlog ColumnMode

# now run the model, we will have a single file (log.csv) for each variables
runctl Reset
runctl Start

# finished, close the file so data is flushed
datlog CloseAllFiles
