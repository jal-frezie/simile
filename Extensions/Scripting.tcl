package require Itcl

# place all extensions in the ::ModelWindowExtn namespace to allow them
# to be found easily using itcl::find classes (used in window.tcl MainWindowDraw)
itcl::class ::ModelWindowExtn::ScriptingExtn {
    inherit ModelWindowExtn

    constructor {awinId} {
        ModelWindowExtn::constructor $awinId
    } {
        #ShowMessage debug info "class ScriptingExtn constructor $winId" ok
    }
    
    # hook into each model window this method is called window.tcl MainWindowDraw
    method MergeMenu {} {
        set fm [menu ${winId}top.scripting -tearoff 0]
        ${winId}top.tools add cascade -label Macros -underline 0 \
                -menu ${winId}top.scripting
        
        # $this is a built in variable for each object referencing that object
        $fm add command -label "Run ..." -command "$this Run"
        
    }
    
    method Run {} {
        ShowMessage debug info "ScriptingExtn Run $winId" ok
    }
    
}