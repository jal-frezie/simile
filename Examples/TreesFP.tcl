# Script to run the forestV4IP.sml model, set a parameter, and run the model
# storing the values of "Number of Trees" in the table "display" which is then
# used to store those values in a csv file

# Only needed when running from Wish shell in Unix; package must be put in
# auto_path if not using shell distributed with Simile
package require SimileAutoObj

# Create a Tcl object/command (modelWin) with which to control that instance of Simile
similescript::ModelWindow modelWin
#modelWin Show 

# Tell Simile not to use the single window Model Run Environment
# We will are not going to use any helper anyway here.
# We then load the model and build it using C++
modelWin UseMRE false
modelWin Open "../Examples/forestV4FP.sml"

# In order to run a model with file parameters you execute: 
# modelWin LoadParams <ParamFile> <SubmodelPath> before running the model. 
# <SubmodelPath> can be omitted if the parameter variables in the file are relative to the top level of the model. 
modelWin LoadParams "../Examples/forestV4FP.spf"
modelWin Run; # now returns the run control

# Create a runControl command/object with which to control
# (as you might expect) the run control.
similescript::RunControl runControl

# Get the value of model variable r which was set by the parameter file
# "../Examples/forestV4FP.sml"
runControl GetValue "/r"

# overwrite the current file parameters
# NB the parameter will not be read until the model is reset
# NB if this file does not set all required parameters 
# the parameters missing from this file will retain the original values
runControl MergeParams "../Examples/forestV4FPb.spf"
runControl Reset

# Get the value of model variable r which was set by the parameter file 
# "../Examples/forestV4FPb.sml"
runControl GetValue "/r"

