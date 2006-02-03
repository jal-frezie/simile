namespace eval BuildCatalogueModels {
proc RunModel { WorkDir Dir } {
    modelWin New
    # rename the runControl command (if it exists) so we can make a new 
    # one to control the new models run control
    catch {rename runControl r[expr rand()]}
    # Tell Simile not to use the single window Model Run Environment
    # We will are not going to use any helper anyway here.
    # We then load the model and build it using C++
    #modelWin UseMRE false
    set ModelFile {}
    catch {set ModelFile [lindex \
                [glob ${WorkDir}/../../www/www/examples/catalogue/models/${Dir}/*.sml] 0]}
    if {[string match {} $ModelFile]} {
        return
    }
    #set Dir assoc_from_data1
    #tk_messageBox -message "BuildModel Dir $ModelFile"
    # ../../www/www/examples/catalogue/models/${Dir}/
    modelWin Open ${ModelFile}
    
    # In order to run a model with file parameters you execute:
    # modelWin LoadParams <ParamFile> <SubmodelPath> before running the model.
    # <SubmodelPath> can be omitted if the parameter variables in the file are relative to the top level of the model.
    
    # find if there is >0 spf, if > 1 load fist
    if {![catch {set SPF [lindex \
                    [glob ${WorkDir}/../../www/www/examples/catalogue/models/${Dir}/*.spf] 0]}]} {
        modelWin LoadParams $SPF
    }
    modelWin Run; # now returns the run control
    
    # Create a runControl command/object with which to control
    # (as you might expect) the run control.
    similescript::RunControl runControl
    runControl Show
    runControl Start
}

#########################
# Set up for and load SimileAutoObj package
# (This is done automatically by SimileScript.exe)
lappend auto_path {../System/lib}
append env(PATH) {../System/bin}
package require SimileAutoObj
#########################

#tk_messageBox -message "BuildCatModels  pwd [pwd]"

#cd ../../www/www/examples/catalogue/models
set datetime [clock format [clock seconds] -format "%y%m%d%H%M%S"]
set ch [open "../Test/CatalogueTest${datetime}.txt" w]

similescript::ModelWindow modelWin
modelWin Show

# not!! 3pg1
set IncompleteModels {3pg1 CVS cheeseman1 ArcieroAggressiveTumorModel}

# cannot cd while runing Simile from Simile/Run or Simile can't load Cond.cnv
# so cd temporarily to get the list of model names
set orig_dir [pwd]
cd ../../www/www/examples/catalogue/models
set ModelNames [glob *]
cd $orig_dir

foreach Name $ModelNames {
    # if model isn't in the list of incomplete models
    if {[lsearch $IncompleteModels $Name] == -1 } {
        #tk_messageBox -message "BuildCatModels Name $Name"
        puts -nonewline $ch "$Name, "
        set t 0
        catch {set t [time [list RunModel $Name]]}
        puts $ch "$t"
    }
}
puts $ch "end"
close $ch

}; # end namespace

