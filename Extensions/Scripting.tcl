package require Itcl

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
        ${winId}top.tools add cascade -label Scripting -underline 0 \
                -menu ${winId}top.scripting
        
        $fm add command -label "Run ..." -command "$this Run"
        
    }
    
    method Run {} {
        ShowMessage debug info "ScriptingExtn Run $winId" ok
    }
    
}