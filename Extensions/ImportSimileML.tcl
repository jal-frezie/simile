package require Itcl

itcl::class ::ModelWindowExtn::ImportExportSimileMLExtn {
    inherit ModelWindowExtn

    constructor {awinId} {
        ModelWindowExtn::constructor $awinId
    } {
    }
    
    # hook into each model window this method is called window.tcl MainWindowDraw
    method MergeMenu {} {
        
        set importMenu ${winId}top.file.sub0
        set exportMenu ${winId}top.file.sub1
        
        # $this is a built in variable for each object referencing that object
        $importMenu add command -label "SimileML ..." -command "$this LoadSimileML"
        $exportMenu add command -label "SimileML ..." -command "$this SaveSimileML"       
        
    }
    
    method LoadSimileML {} {
        ShowMessage debug info "ImportExport LoadSimileML $winId" ok
    }
    
    method SaveSimileML {} {
        ShowMessage debug info "ImportExport SaveSimileML $winId" ok
    }
    
}