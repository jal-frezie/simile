Set ModelWindow = CreateObject("SimileAutoObj.ModelWindow")

ModelWindow.Show
ModelWindow.Open "../Examples/forestV4IP.sml"
ModelWindow.Run
MsgBox "Close Simile?"
ModelWindow.Exit
' Script to run the forestV4IP.sml model, set a parameter, and run the model
' storing the values of "Number of Trees" in the table "display" which is then
' used to store those values in a csv file

' Create a Tcl object/command (modelWin) with which to control that instance of Simile
similescript::ModelWindow modelWin

' The mode is expected to have the model window not visible, however,
' at present Simile lock up if the model window is not visible, so:-
modelWin Show 

' Tell Simile not to use the single window Model Run Environment
' We will are not going to use any helper anyway here.
' We then load the model and build it using C++
modelWin UseMRE false
modelWin Open "../Examples/forestV4IP.sml"
modelWin Run

' Run (and Debug) returns runControl a command/object with which to control
' (as you might expect) the run control.

' Get the value of model variable r just to show how
runControl GetValue "/r"

' Set the value of model variable r to 15
runControl SetValue "/r" 15

' Make the run control visible for this demonstration
runControl Show

' create a Table to to save a CSV file of variable values
' similescript::TableHelper <object/command name> <model window to get values from> <window title (not very useful usually)>
similescript::TableHelper th modelWin Table

' Make the table visible for this demonstration
th Show

' find whether the table is set to update display at the run control display interval
th GetUpdateAtDisplayInterval

' set the table not to update its display at the run control display interval
' it is faster not to 
th SetUpdateAtDisplayInterval 0

' add the variable Number of Trees to the table
th AddVariable "/Number of Trees"


' add the variable r to the table and then remove it after 1000 ms
th AddVariable "/r"
after 1000
th RemoveVariable "/r"

' add the variable Tree Size in the Tree submodel to the table and 
' then remove it after 1000 ms
th AddVariable "/Tree/Tree Size"
after 1000
th RemoveVariable "/Tree/Tree Size"

' set the simulation to run for 300 time units
runControl SetExecuteFor 300

' start the simulation 
runControl Start

' tell the table to update with values for the whole run
th Update

' save the variables values in the table to the file results.csv
' by default the file will be saved in the current working directory
' one could give a full path for the file to save to
th SaveToFile results.csv

' get the present working directory in which results.csv will be found
' pwd is a standard Tcl command
pwd

' use standard Tcl to open, read and then close the file (and show the results)
set file [open results.csv]
read $file
close $file

' wait 10 seconds (10000 ms) and then close Simile and the Tcl console
exit




