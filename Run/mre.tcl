# Support for the Model Run Environment moved to a seperate source file mre.tcl
# this file must source the mre.tcl file and MakeMRE is called from proc ModelWindow
# Jonathan Massheder


# helpers must bind $canvas <Configure> resize $canvas

namespace eval RunEnv {
    
    package require BWidget

    variable mainframe
    variable status
    variable prgtext
    variable prgindic
    variable runControlFrame; # the widget id of the frame to hold the run control
    variable sliderControlFrame;
    variable variableListFrame;
    variable explorerPane
    variable runControlWindId
    variable dp0;    # display pane
    variable toolbars; # list of toolbar items
    variable CurrentContainer {}
    
    variable width 780; # window width  # should be an option
    variable height 580; #window height  # should be an option
    
    set helperTable(VariableList) ModelInspector63654; # should be an option
    set helperTable(ErrorDisplay) fun03040 ; # should be an option
    
    # list of toolbar items. The top level list contains separated lists of toolbuttons:
    # each toolbutton specification includes:
    # gif in $similepath/images/toolbar
    # pop-up message
    # command.
    # A separator is placed between the 
    set toolbars [list \
            [list \
            [list new.gif "New display configuration" RunEnv::KillDisplays] \
            [list open.gif "Load a configuation of displays" RunEnv::LoadView] \
            [list save.gif "Save the display configuation" RunEnv::SaveView] ]\
            [list \
            [list copyc.gif "Copy display" [list ::RunEnv::CopyHelper $::RunEnv::CurrentContainer]] \
            [list cut.gif "Cut display" [list ::RunEnv::CutHelper $::RunEnv::CurrentContainer"]] \
            [list paste.gif "Paste display" [list ::RunEnv::PasteHelper $::RunEnv::CurrentContainer"]] \
            [list delete.gif "Delete" "::RunEnv::DeleteHelperCurrentContainer" ]] \
            [list \
            [list splithoriz.gif "Split page horizontally" "::RunEnv::SplitCurrentContainer vertical" ] \
            [list splitvert.gif "Split page vertically" "::RunEnv::SplitCurrentContainer horizontal"]] \
            [list \
            [list notebookpage.gif "Add notebook page" "RunEnv::AddNotebookPageToCurrentContainer"] \
            [list notebook.gif "Add notebook" "RunEnv::AddNotebookToCurrentContainer"]] \
            [list \
            [list graph.gif "Create plotter" "::RunEnv::CreateHelperInCurrentContainer plotter1.25 {Plotter}"] \
            [list table.gif "Create table" "::RunEnv::CreateHelperInCurrentContainer tabular11510 {Table}"] \
            [list display.gif "Choose display to create" "::RunEnv::AllDisplaysPopupCurrentContainer"]] \
            [list \
            [list mainwin.gif "Go to Model Window" "RaiseModelWindow"]]]
        }

# A top level window to contain the helpers
proc RunEnv::Create { ModelWin } {
    global helperTable tcl_platform modelWin
    variable mainframe
    variable runControlFrame
    variable sliderControlFrame;
    variable variableListFrame;
    variable ::RunEnv::mainframe; ## duplicate?
    variable explorerPane
    variable dp0;    # display pane
    variable toolbars; # list of toolbar items
    variable width
    variable height
    
    destroy .helpPopup
    if {![winfo exists .mre]} then {
        #    tk_messageBox -message MakeMRE -type ok
        toplevel .mre -width 200m -height 150m
        wm title .mre "Run-Time Environment - Simile"
        # Menu description
                    #"&Add" all add 0 {
                    #    {separator}
                    #}
                    
        set descmenu {
            "&File" all file 0 {
                {command "&Load configuration..." {} "Load a configuation of displays" \
                            {} -command {::RunEnv::LoadView} }
                {command "&Save configuration..." {} "Save a configuation of displays" \
                            {} -command {::RunEnv::SaveView} }
                {separator}
                {command "&Print..." {} "Print display"  \
                            {} -command { PrintCurrentContainer } }
                {separator}
                {command "Pa&rameters..." {} "Modify file parameters"  \
                            {} -command { FileParamDialogue 1 .mre } }
                {separator}
                {command "&Close"    {} "Close the Run Environment window" \
                            {} -command {RunEnv::Destroy} }
            }
            "&Edit" all edit 0 {
                {command "&Remove..."    {} "Remove a sheet" {} -command {::RunEnv::RemoveHelperPageDlg} }
                {separator}
                {command "&Clear all"    {} "Clear all sheets" {} -command {ClearView} }
                {command "Cl&ose all"    {} "Close all sheets" {} -command {::RunEnv::KillDisplays} }
            }
            "&Help" all help 0 {
                {command "&Contents..." {} "View the help file contents" {} -command {LaunchHelp} }
            }
        }
        
        set mainframe [MainFrame .mre.mainframe -width 200m -height 150m \
                -menu         $descmenu \
                -textvariable RunEnv::status \
                -progressvar  RunEnv::prgindic]
        
        set tb1  [$mainframe addtoolbar]
        #set sep [Separator $tb1.sep -orient vertical]
        #pack $sep -fill y -padx 4
        
        # build the toolbar  from the toolbarItems list
        set tbnum 0
        foreach toolbar $toolbars {
            set bbox [ButtonBox $tb1.bbox$tbnum -spacing 0 -padx 1 -pady 1]
            foreach item $toolbar {
                set gif [lindex $item 0]
                set helptext [lindex $item 1]
                set command [lindex $item 2]
                $bbox add -image [image create photo  -file "../Images/Toolbar/$gif"] \
                        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 -padx 1 -pady 1 \
                        -helptext $helptext -command $command
            }
            pack $bbox -side left -anchor w
            incr tbnum
            pack [Separator $tb1.sep$tbnum -orient vertical] -side left -fill y -padx 4
        }
        
        set mreMenu [winfo parent [$mainframe getmenu help]]
        $mreMenu insert 2 cascade -label "Add" -underline 0 -menu .helpers.sub2
        
        # Add a PanedWindow for the hierrachical/run control view and main display window
        set mainpw [panedwindow [$mainframe getframe].mainpw  -orient horizontal]
        set controlPane [frame $mainpw.controlPane]; # made by runmodel.tcl AddHelperSublist
            
        set dp0 [frame $mainpw.mainDisplayPane]
        $mainpw add $controlPane $dp0 -width 270; # must be wide enough (270ish) for the sliders
        
        # Add a panedwindow to split the hier/contol pane into hierrachical pane and control pane
        set hiercontrolpw [panedwindow $controlPane.panedwindow -orient vertical]
        set runcontrolpane [frame $hiercontrolpw.runcontrolPane]
        set explorerPane [frame $hiercontrolpw.explorerPane]
        $hiercontrolpw add $runcontrolpane $explorerPane -height 170
        
        # Add notebook for controls, explorer etc
        NoteBook $explorerPane.notebook
        $explorerPane.notebook insert end "Explorer" -text "Explorer"
        set variableListFrame [frame [$explorerPane.notebook getframe Explorer].variables]
        pack $explorerPane.notebook $variableListFrame -fill both -expand yes
        
        $explorerPane.notebook insert end "InputSliders" -text "Input sliders"
        set sliderControlFrame \
                [frame [$explorerPane.notebook getframe "InputSliders"].sliders]
        
        #$explorerPane.notebook insert end "Output" -text "Output"
        #set outputFrame \
        #        [frame [$explorerPane.notebook getframe "Output"].sliders -container true]
        pack $variableListFrame $sliderControlFrame -fill both -expand yes
        $explorerPane.notebook raise Explorer
        
        NoteBook $runcontrolpane.notebook
        $runcontrolpane.notebook insert end "RunControl" -text "Run Control"
        set runControlFrame  [frame [$runcontrolpane.notebook getframe RunControl].variables]
        pack $runcontrolpane.notebook -fill both -expand yes
        pack $runControlFrame -fill both -expand yes
        $runcontrolpane.notebook raise RunControl
        
        RunEnv::AddNotebook $dp0
        
        pack $mainframe -fill both -expand yes
        pack $mainpw -fill both -expand yes
        
        pack $hiercontrolpw -fill both -expand yes
        
        CreateDisplayPageContextMenu
        
        # Model variable explorer is created automatically elsewhere
        # run control is automatically created when model is run
        # input slider helper is automatically created if needed when model is run
        
        wm geometry .mre ${width}x${height}
        if {[string match unix $tcl_platform(platform)]} {
            wm iconbitmap .mre @../Images/dribble.xbm
        }; # on Windows uses default icon set in Runmodel.tcl
        wm protocol .mre WM_DELETE_WINDOW ::RunEnv::Destroy       
    } ; # if .mre exists
    return .mre
}

proc RunEnv::AddNotebook {containerId} {
    destroy $containerId.abovebox
    destroy $containerId.bbox
    destroy $containerId.belowbox
    NoteBook $containerId.notebook
    
    for  {set i 1} {$i<=4} {incr i} {
        set pageId [UniqueId page [$containerId.notebook pages]]
        $containerId.notebook insert end $pageId -text $i \
                -raisecmd "::RunEnv::PageRaiseCmd $containerId.notebook $pageId"
        set newContainer [$containerId.notebook getframe $pageId]
        panedwindow $newContainer.panedwindow -orient vertical
        pack $newContainer.panedwindow -expand yes -fill both
        frame $newContainer.panedwindow.pane0 -highlightcolor black -highlightthickness 1
        bind $newContainer.panedwindow.pane0 <Button-1> "::RunEnv::SetCurrentContainer %W"
        bind $newContainer.panedwindow.pane0 <Button-3> \
                "::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
        $newContainer.panedwindow add $newContainer.panedwindow.pane0 -sticky nesw
    }
    
    $containerId.notebook raise [lindex [$containerId.notebook pages] 0]
    
    pack $containerId.notebook -fill both -expand yes
}

proc RunEnv::PageRaiseCmd {notebook pageId} {
        set pageF [$notebook getframe $pageId]
        set firstPane [lindex [$pageF.panedwindow panes] 0]
        #ShowMessage debug info "PageRaiseCmd firstPane $firstPane" ok
        SetCurrentContainer $firstPane
}

proc RunEnv::AddNotebookToCurrentContainer {} {
    AddNotebook $::RunEnv::CurrentContainer
}

proc RunEnv::AddNotebookPage {containerId} {
    if {[string match notebook [winfo name $containerId]]} {
        set ParentContainer $containerId
    } else  {
        set ParentContainer [FindParentpanedwindowOrNotebook $containerId]
    }
    #ShowMessage debug info "containerId $containerId\nParentContainer $ParentContainer" ok
    if {[string match notebook [winfo name $ParentContainer]]} {
        set pageId [UniqueId page [$ParentContainer pages]]
        set pageIndex [expr {[llength [$ParentContainer pages]]+1}]
        $ParentContainer insert end $pageId -text $pageIndex \
            -raisecmd "::RunEnv::PageRaiseCmd $ParentContainer $pageId"
        set newContainer [$ParentContainer getframe $pageId]
        panedwindow $newContainer.panedwindow -orient vertical
        pack $newContainer.panedwindow -expand yes -fill both
        frame $newContainer.panedwindow.pane0 -highlightcolor black -highlightthickness 1
        bind $newContainer.panedwindow.pane0 <Button-1> "::RunEnv::SetCurrentContainer %W"
        bind $newContainer.panedwindow.pane0 <Button-3> \
                "::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
        $newContainer.panedwindow add $newContainer.panedwindow.pane0
        return $newContainer.panedwindow.pane0
    } else  {
        return [AddNotebookPage $ParentContainer]
    }

}

proc RunEnv::AddNotebookPageToCurrentContainer {} {
    AddNotebookPage $::RunEnv::CurrentContainer
}

proc RunEnv::AddNewPageToolBar {containerId page} {
    #    pack [frame $containerId.f] -fill both
    #    pack [frame $containerId.f.tb -relief raised] -pady 3 -padx 3
    variable PageToolbarItems
    set PageToolbarItems [list \
            [list splithoriz.gif "Split page horizontally" "::RunEnv::SplitPage $containerId vertical" ] \
            [list splitvert.gif "Split page vertically" "::RunEnv::SplitPage $containerId horizontal"] \
            [list notebookpage.gif "Add notebook page" "RunEnv::AddNotebookPage $containerId"] \
            [list notebook.gif "Add notebook" "RunEnv::AddNotebookPageToCurrentContainer"] \
            [list graph.gif "Create plotter here" "::RunEnv::CreateHelperInWindow $containerId plotter1.25 {Plotter}"] \
            [list table.gif "Create plotter here" "::RunEnv::CreateHelperInWindow $containerId tabular11510 {Table}"] \
            [list display.gif "Choose display to create here" "::RunEnv::AllDisplaysPopup $containerId \
            [winfo pointerx $containerId] [winfo pointery $containerId]"] \
            [list copy.gif "Copy display" "::RunEnv::CopyHelper $containerId"] \
            [list cut.gif "Cut display" "::RunEnv::CutHelper $containerId"] \
            [list paste.gif "Paste display" "::RunEnv::PasteHelper $containerId"] \
            [list delete.gif "Delete pane or page" "::RunEnv::DeleteHelperContainer $containerId $page" ]]
    ::graphtools::MakeToolBar $containerId $PageToolbarItems
    #    $containerId.bbframe configure -relief groove
    #    pack configure $containerId -expand on -fill both
    #    pack configure $containerId.bbframe -expand on -fill both -anchor center
    #    pack configure $containerId.bbframe.buttonBox -anchor center
    # bug : popup menu doesn't go in the correct place
}

proc ::RunEnv::AllDisplaysPopup {containerId} {   
    variable CurrentContainer $containerId
    tk_popup .helpPopup [winfo pointerx .mre] [winfo pointery .mre]
}

proc RunEnv::AllDisplaysPopupCurrentContainer {} {
    # .helpers.sub2 made by runmodel.tcl AddHelperSublist
    tk_popup .helpers.sub2 [winfo pointerx .mre] [winfo pointery .mre]
}

proc RunEnv::SelectionHandler {offset maxChars} {
    global helperTable
    variable CurrentContainer
    set SelStr [StripCrs $helperTable($CurrentContainer.container,status)]
    set last [expr {$offset + $maxChars}]
    return [string range $SelStr $offset $last]
}

proc ::RunEnv::PrintCurrentContainer {} {
    global helperTable env tcl_platform
    variable CurrentContainer
    variable canvasId
    return
    
    if [winfo exists $CurrentContainer.container] {
            set canvasId [$helperTable($CurrentContainer.container,whichHelper)::GetCanvas $CurrentContainer.container]
            PrintNow $::RunEnv::canvasId
    }
}

proc ::RunEnv::CopyHelper {containerId} {
    global helperTable env tcl_platform
    variable CurrentContainer
    variable CurrentHelperId
    variable canvasId
        
    #ShowMessage debug info "CopyHelper container: $containerId; \n\
    #        CurrentContainer $CurrentContainer\n \
    #        selection owner: [selection own]\n\
    #        focus owner [focus]" ok
    if [winfo exists $CurrentContainer.container] {
        
        #ShowMessage debug info "CopyHelper $containerId.container exists " ok
        #UpdateState $helperTable($containerId.container)
        if {[string match windows $tcl_platform(platform)]} {
            set canvasId [$helperTable($CurrentContainer.container,whichHelper)::GetCanvas $CurrentContainer.container]
            #ShowMessage debug info "CopyHelper canvasId $canvasId \n\
            #        namespace [namespace current]" ok
                    #namespace eval :: { }
                #ShowMessage debug info "namespace [namespace current]" ok
               CopyCanvasToWindowsClipboard $::RunEnv::canvasId
            #{}
        }
        set CurrentHelperId $helperTable($CurrentContainer.container,whichHelper)
        set copyfile $env(SIMTMPDIR)/mrecopy.txts
        set stream [open $copyfile w]
        #ShowMessage debug info "$copyfile" ok
        puts $stream [StripCrs $helperTable($CurrentContainer.container,status)]
        close $stream
    }
}

proc ::RunEnv::CutHelper {containerId} {
    CopyHelper $containerId
    DeleteHelperCurrentContainer
}

proc ::RunEnv::PasteHelper {containerId} {
    global helperTable env
    variable CurrentContainer
    variable CurrentHelperId

    set copyfile $env(SIMTMPDIR)/mrecopy.txts
    if {[file exists $copyfile]} { 
        set stream [open $copyfile r]
        set winId [NewHelperInWindow $CurrentContainer $CurrentHelperId ""]
        gets $stream oldStatus
        set helperTable($winId,status) [RestoreCrs $oldStatus]
        ${CurrentHelperId}::Restore $winId
        bind $winId <Destroy>  "kill_helper_window $winId"
        ChildrenFocusParent $winId
        close $stream
     }
}

proc ::RunEnv::DeleteHelperContainer {containerId page} {
    global helperTable
    # container is the frame a helper would be displayed in
    # a parent is the notebook or panedwindow the container belongs to
    #ShowMessage debug info "container $containerId; page $page; \
    #            parent [::RunEnv::FindParentpanedwindowOrNotebook $containerId]" ok
    set parentPath [::RunEnv::FindParentpanedwindowOrNotebook $containerId]
    set parentType [winfo name $parentPath]
    set children [winfo children $containerId]
    #ShowMessage debug info "DeleteHelperContainer: $containerId\n \
    #        children $children\n \
    #        parentType $parentType" ok; ##################
    if {[lsearch $children *.container]>-1} {
        kill_helper_window $containerId.container
    } else {
        switch $parentType {
            notebook {DeleteNotebookPage $parentPath $page}
            panedwindow {DeletePane $parentPath $containerId}
        }
    }
}

proc ::RunEnv::DeleteHelperCurrentContainer {} {
    DeleteHelperContainer $::RunEnv::CurrentContainer {}
}

proc RunEnv::DeleteNotebookPage {notebook page} {
    set pages [$notebook pages]
    set n [llength $pages]
    set index [lsearch $pages $page]
    #ShowMessage debug info "DeleteNotebookPage  $notebook; $page\n \
#            page $page; n pages: $n; \n \
#            parent [winfo parent $notebook]" ok; ########
    if {$n==1} {
#ShowMessage debug info "DeleteNotebookPage n==1" ok
        if {[string match mainDisplayPane [winfo name [winfo parent $notebook]]]} {
            ShowMessage Information info "Cannot delete this page. The main notebook must have at least one page." ok
            return
        }
    }
    $notebook delete $page 1
    set pages [$notebook pages]
    set n [llength $pages]
     #ShowMessage debug info "DeleteNotebookPage after delete page pages $n" ok; #########
    if {$n==0} {
        set containerId [winfo parent $notebook]
    #ShowMessage debug info "DeleteNotebookPage n==0; new container $containerId" ok; ########
        destroy $notebook
        SetCurrentContainer $containerId
        #ShowMessage debug info "DeleteNotebookPage  destroy notebook\n \
                new container $containerId" ok; ########
    } else  {
        #ShowMessage debug info "DeleteNotebookPage default" ok
        # adjust any labels that should be = to index + 1
        set pages [$notebook pages]
        set i 0
        foreach item $pages {
            set label [$notebook itemcget $item -text]
            if {$label==$i+2} {
                $notebook itemconfigure $item -text [expr {$i+1}]
            }
            incr i
        }
        set pages [$notebook pages]
        set n [llength $pages]
        if {$index >= $n} {
            $notebook raise [lindex $pages [expr {$n-1}]]
        } else  {
            $notebook raise [lindex $pages $index]
        }
    }
}

proc RunEnv::DeletePane {parentPath containerId} {
    #ShowMessage debug info "DeletePane\n parentPath $parentPath\n \
#            containerId $containerId\n \
#            panes [$parentPath panes]" ok; ###########
    $parentPath forget $containerId
    destroy $containerId
    # all panedwindows are in a notebook parent
    if {[llength [$parentPath panes]]==0} {
        set parentPage [winfo parent $parentPath]
        set parentNoteBook [winfo parent $parentPage]
    #ShowMessage debug info "DeletePane page\n parentPath $parentPath\n \
#                parentPage $parentPage; parentNoteBook $parentNoteBook\n \
#                pages [$parentNoteBook pages]\n \
#                current page [$parentNoteBook raise]" ok; ###########
        destroy $parentPath
        DeleteNotebookPage $parentNoteBook [$parentNoteBook raise]; #current page
    }
}

proc RunEnv::SplitPage {containerId orientation} {
    #ShowMessage debug info "SplitPage container $containerId $orientation" ok; ##############
    
    set parentPath [FindParentpanedwindowOrNotebook $containerId]
    if {[string match notebook [winfo name $parentPath]]} {
        Addpanedwindow $containerId $orientation
    } elseif {(![string match $orientation [$parentPath cget -orient]])} {
        Addpanedwindow $containerId $orientation
    } else  {
        # it's a pane
        # existing panes original settings
        set pwidth  [winfo width $containerId]
        set pheight [winfo height $containerId]
        set sash [lsearch [$parentPath panes] $containerId]
        set sashCoord [$parentPath sash coord $sash]
        set contx [winfo x $containerId]
        set conty [winfo y $containerId]
        #ShowMessage debug info "SplitPage pane to be split \
        #        width $pwidth height $pheight \n \
        #        sash index $sash coord $sashCoord\n\
        #        x [winfo x $containerId]; y [winfo y $containerId]" ok; ##############
        
       
        # new settings
        switch $orientation {
            vertical {
                set width [expr {int(0.9*$pwidth)}]
                set height [expr {int(0.9*$pheight/2)}]
                set sashx [lindex $sashCoord 0]
                set sashy [expr $conty+$height]
            }
            horizontal {
                set width [expr {int(0.9*$pwidth/2)}]
                set height [expr {int(0.9*$pheight)}]
                set sashx [expr {$contx+$width}]
                set sashy [lindex $sashCoord 1]
            }
        }
        
        
        #ShowMessage debug info "SplitPage new sash setting for existing pane (split)\
        #        width $width height $height \n \
        #        sash index $sash $sashx $sashy" ok; ##############
        
        
        # add a new pane
        set paneId [UniqueId $parentPath.pane [$parentPath panes]]
        frame $paneId -highlightcolor black -highlightthickness 1
        bind $paneId <Button-1> "::RunEnv::SetCurrentContainer %W"
        bind $paneId <Button-3> \
                "::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
        $parentPath add $paneId -after $containerId
        
        update; # or sash place won't work
        $parentPath sash place $sash $sashx $sashy
        
        #ShowMessage debug info "SplitPage $parentPath $containerId \n\
        #        paneId $paneId" ok; ##############
        
    }
}

proc RunEnv::SplitCurrentContainer {orientation} {
    SplitPage $::RunEnv::CurrentContainer $orientation
}

proc ::RunEnv::FindParentpanedwindowOrNotebook {containerId} {
    set parentPath [winfo parent $containerId]
    set parentName [winfo name $parentPath]
    switch $parentName {
        notebook { return $parentPath }
        panedwindow { return $parentPath }
        "" { return ""}
        default {::RunEnv::FindParentpanedwindowOrNotebook $parentPath}
    }
}

proc RunEnv::Destroy {} {
    global helperTable modelWin window_info
    variable runControlWindId
    
    #ShowMessage debug info "RunEnv::Destroy RunContol $runControlWindId" ok
    
    # 
    # stop the model running by invoking the Run Control Stop button    
    # helperId of runcontrol $helperTable(RunControl).
    $helperTable(RunControl)::SetMode $runControlWindId reset
    #update
    #after 100        
    #set $helperTable(RunControl)::sendvars(currentMode) stop
    #tkwait variable $helperTable(RunControl)::sendvars
    # debug info "$helperTable(RunControl)::sendvars(currentMode)" ok

    foreach helper [array name helperTable *,whichHelper] {
        scan $helper {%[^,]} winId
        bind $winId <Destroy> {}; # so the helper notebook pages are not destroyed 2ce - bomb!
    }
    destroy .pageContextMenu
    KillHelpers
    foreach winData [array name window_info *,parent] {
        set navBar $window_info($winData).toolSlot.navbar
        $navBar.runenv configure -state disable
    }
    destroy .mre
}

proc RunEnv::Addpanedwindow {containerId orientation} {
    set pwidth  [winfo width $containerId]
    set pheight [winfo height $containerId]
    #ShowMessage debug info "RunEnv::Addpanedwindow $containerId $orientation\n \
    #        pwidth $pwidth; pheight $pheight" ok; ################
    panedwindow $containerId.panedwindow -orient $orientation
    pack $containerId.panedwindow -expand yes -fill both
    # todo the 0.9 is a hack to compensate for borders
    switch $orientation {
        vertical {
            set width [expr {0.9*$pwidth}]
            set height [expr {0.9*$pheight/2}]
        }
        horizontal {
            set width [expr {0.9*$pwidth/2}]
            set height [expr {0.9*$pheight}]
        }
        default {
            ShowMessage Error error "Addpanedwindow: incorrect value for orientation: $orientation;\
                    must be  must vertical or horizontal" ok
        }
    }
    #ShowMessage debug info "RunEnv::Addpanedwindow width $width; height $height" ok
    frame $containerId.panedwindow.pane0 -highlightcolor black -highlightthickness 1
    frame $containerId.panedwindow.pane1 -highlightcolor black  -highlightthickness 1
    bind $containerId.panedwindow.pane0 <Button-1> "::RunEnv::SetCurrentContainer %W"
    bind $containerId.panedwindow.pane1 <Button-1> "::RunEnv::SetCurrentContainer %W"
    bind $containerId.panedwindow.pane0 <Button-3> \
            "::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
    bind $containerId.panedwindow.pane1 <Button-3> \
            "::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
    $containerId.panedwindow add $containerId.panedwindow.pane0 $containerId.panedwindow.pane1 \
            -width $width -height $height
}

proc RunEnv::SetCurrentContainer {win} {
    #ShowMessage debug info "SetCurrentContainer $win" ok
    focus $win
    set ::RunEnv::CurrentContainer $win
}

# Return a list of all children, found recursively, of a widget
proc RunEnv::GetChildren { widget } {
    #ShowMessage debug info "GetChildren" ok
    set allChildren [winfo children $widget]
    foreach child $allChildren {
        set allChildren [concat $allChildren [GetChildren $child]]
    }
    return $allChildren
}

# Return a list of all widgets in an input list of a certain widget class
proc RunEnv::GetWidgetClass {widgetList widgetClass} {
    set classList []
    foreach widget $widgetList {
        if {[string match [winfo class $widget] $widgetClass]} {
            lappend classList $widget
        }
    }
    return $classList
}

# Return a list of all widgets in an input list with a certain name
# at the end of its path
proc RunEnv::GetWidgetsWithName {widgetList name} {
    set nameList []
    foreach widget $widgetList {
        #ShowMessage debug info "$widget\n[lindex [split $widget .] end]" ok
        if {[string match $name [lindex [split $widget .] end]]} {
            lappend nameList $widget
        }
    }
    return $nameList
}

proc RunEnv::RemoveHelperPageDlg {} {
    variable dp0;    # display pane
    variable listboxData {}
    global helperTable
    
    set dlg [Dialog .wset -title "Remove" -parent .mre -modal local\
            -default 0 -cancel 1]
    
    $dlg add -name ok -command [namespace code "RemoveHelperPageDlgOK $dlg"]
    $dlg add -name cancel
    listbox $dlg.listbox
    set allChildren [GetChildren $dp0]
    set allDisplaynotebooks [GetWidgetsWithName $allChildren notebook]
    foreach notebook $allDisplaynotebooks {
        foreach page [$notebook pages] {
            set label [$notebook itemcget $page -text]
            $dlg.listbox insert end $label
            lappend listboxData [list $notebook $page]
        }
    }
    pack $dlg.listbox -fill both -expand yes
    
    $dlg draw
    destroy $dlg
}

proc RunEnv::RemoveHelperPageDlgOK {dlg} {
    variable listboxData
    set selection [$dlg.listbox curselection]
    foreach item $selection {
        
        kill_helper_window .[lindex [lindex $listboxData $item] 1]
    }
    unset listboxData
    $dlg enddialog 0
}

proc RunEnv::CreateDisplayPageContextMenu {} {
    if  {![winfo exists .pageContextMenu]} {
        set m [menu .pageContextMenu -tearoff 0]
        $m add command -label "Create plotter" -command "::RunEnv::CreateHelperInCurrentContainer plotter1.25 {Plotter}"
        $m add command -label "Create table" -command "::RunEnv::CreateHelperInCurrentContainer tabular11510 {Table}"
        $m add cascade -label "Choose display to create ..." -menu .helpers.sub2; #from runmodel.tcl AddHelperSublist
        $m add separator
        $m add command -label "Copy display" -command "::RunEnv::CopyHelper $::RunEnv::CurrentContainer"
        $m add command -label "Cut display" -command "::RunEnv::CutHelper $::RunEnv::CurrentContainer"
        $m add command -label "Paste display" -command "::RunEnv::PasteHelper $::RunEnv::CurrentContainer"
        $m add separator
        $m add command -label "Split page horizontally" -command "::RunEnv::SplitCurrentContainer vertical"
        $m add command -label "Split page vertically" -command "::RunEnv::SplitCurrentContainer horizontal"
        $m add separator
        $m add command -label "Add notebook" -command "RunEnv::AddNotebookToCurrentContainer"
        $m add command -label "Add notebook page" -command "RunEnv::AddNotebookPageToCurrentContainer"
        $m add separator
        $m add command -label "Delete pane or page" -command "::RunEnv::DeleteHelperCurrentContainer"
    }
}

proc RunEnv::KillDisplays {} {
    global helperTable
    global ::RunEnv::dp0
    
    destroy $RunEnv::dp0.notebook
    RunEnv::AddNotebook $dp0
}

proc RunEnv::CreateHelperInWindow {containerId helperId helperTitle} {
    #ShowMessage debug info "CreateHelperInWindow: \
    #        containerId $containerId helperId $helperId helperTitle $helperTitle\n\
    #        children [winfo children $containerId]" ok
    set winId [NewHelperInWindow $containerId $helperId $helperTitle]
    ${helperId}::initialize $winId
    ChildrenFocusParent $winId
}

proc RunEnv::ChildrenFocusParent {parent} {
    # despite the inner frame being called the container its the pane
    # could clean up the naming sometime
    set Container [winfo parent $parent]
    #ShowMessage debug info "ChildrenFocusParent:\n\
    #        parent : $parent; container $Container\n\
    #        children [winfo children $parent]" ok
    foreach child [winfo children $parent] {
        bind $child <Button-1> "::RunEnv::SetCurrentContainer $Container"
    }
}

proc RunEnv::NewHelperInWindow {containerId helperId helperTitle} {
    global helperTable
    #variable PageToolbarItems
    #ShowMessage debug info "NewHelperInWindow: \
    #        containerId $containerId helperId $helperId helperTitle $helperTitle\n \
    #        containers children: [winfo children $containerId]" ok
    
    set winId $containerId.container
    frame $winId
    pack $winId -fill both -expand yes
    set helperTable($helperTitle) $winId
    set helperTable($winId,whichHelper) $helperId
    bind $winId <Destroy>  "kill_helper_window $winId"
    return $winId
}


proc RunEnv::CreateHelperInCurrentContainer {helperId helperTitle} {
    variable CurrentContainer
    CreateHelperInWindow $CurrentContainer $helperId $helperTitle
}

proc RunEnv::SaveView {} {
    global helperTable
    variable dp0
    variable mainframe
    
    set savedView [ChooseFile Displays.shf "Save display configuration" 1]
    if {[llength $savedView]} {
        set stream [open $savedView w]
        
        # save skeleton mre config
        puts $stream "[winfo x .mre] [winfo y .mre] [winfo width .mre] [winfo height .mre]"
        puts $stream "[[$mainframe getframe].mainpw sash coord 0]"
        puts $stream "[[$mainframe getframe].mainpw.controlPane.panedwindow sash coord 0]"
        SaveNotebookConfig $dp0.notebook $stream
        
        close $stream
    }
}

proc RunEnv::SaveNotebookConfig {notebook stream} {
    puts $stream "notebook $notebook"
    foreach page [$notebook pages] {
        set pagecaption [$notebook itemcget $page -text]
        puts $stream "page $notebook $page $pagecaption"
        foreach child [winfo children [$notebook getframe $page]]  {
            puts $stream "$notebook $page $child"
            switch [winfo name $child] {
                container {
                    SaveContainer $child $stream
                }
                panedwindow {
                    SavePanedwindowConfig $child $stream
                }
                notebook {
                    SaveNotebookConfig $child $stream
                }
                default {
                    #puts $stream "Unhandled Notebook page child: $child"
                }
            }
        }
    }
}

proc RunEnv::SavePanedwindowConfig {panedwindow stream} {
    puts $stream "panedwindow $panedwindow [$panedwindow cget -orient]"
    foreach pane [$panedwindow panes] {
        puts $stream "pane $pane"
        foreach child [winfo children $pane] {
            switch [winfo name $child] {
                container {
                    SaveContainer $child $stream
                }
                panedwindow {
                    SavePanedwindowConfig $child $stream
                }
                notebook {
                    SaveNotebookConfig $child $stream
                }
                default {
                    # puts $stream "Unhandled Notebook page child: $child"
                }
            }
        }
    }
    for {set index 0} {$index < [llength [$panedwindow panes]]} {incr index} {
        puts $stream "sash [winfo parent $pane] $index [$panedwindow sash coord $index]"
    }
}

proc RunEnv::SaveContainer {winId stream} {
    global helperTable
    set helperId $helperTable($winId,whichHelper)
    puts $stream "container [winfo parent $winId]"
    puts $stream $helperId
    # substitute <cr>s so entry goes on one line
    # not a toplevel #puts $stream [StripCrs [wm title $winId]]
    # not a toplevel #puts $stream [wm geometry $winId]
    if {[info exists helperTable($winId,status)]} {
        puts $stream [StripCrs $helperTable($winId,status)]
    } else {
        puts $stream {}
    }
}

proc RunEnv::LoadView {} {
    global helperTable
    variable mainframe
    variable dp0
    
    set savedView [ChooseFile Displays.shf "Open view specification file" 0]
    if {[llength $savedView]} {
        destroy $RunEnv::dp0.notebook; #what if there is an error in the file delete MRE, rebuild
        set stream [open $savedView r]
        
        # check for run env that made the shf
        gets $stream line
        if {[llength $line]==4} {
            
            # read and set .mre position and size
            scan $line "%i %i %i %i" x y width height
            wm geometry .mre ${width}x${height}+${x}+${y}
            
            gets $stream line
            scan $line "%i %i" x y;
            [$mainframe getframe].mainpw sash place  0 $x $y
            
            gets $stream line
            scan $line "%i %i" x y
            [$mainframe getframe].mainpw.controlPane.panedwindow sash place  0 $x $y
            
            while {[gets $stream line] >= 0} {
                switch [scan $line %s] {
                    container {
                        LoadContainer $stream $line
                    }
                    panedwindow {
                        #%puts $stream "panedwindow $panedwindow [$panedwindow cget -orient]"
                        scan $line "%s %s %s" widget path orient
                        panedwindow $path -orient $orient
                        #set containerId [winfo parent $path]
                        #ShowMessage debug info "containerId $containerId" ok
                        #$notebook raise $pageId; # or $panedwindow sash place won't work
                        pack $path -expand yes -fill both
                    }
                    pane {
                        #%puts $stream "pane $pane"
                        scan $line "%s %s" widget path
                        frame $path -highlightcolor black  -highlightthickness 1
                        set panedwindow [winfo parent $path]
                        $panedwindow add $path
                        bind $path <Button-1> "::RunEnv::SetCurrentContainer %W"
                        bind $path <Button-3> \
                                "::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
                    }
                    sash {
                        scan $line "%s %s %i %i %i" sash panedwindow index sashx sashy
                        # the page this pane is in must be raised and update called!
                        #ShowMessage debug info "$panedwindow sash place $index $sashx $sashy " ok
                        update
                        $panedwindow sash place $index $sashx $sashy
                    }
                    notebook {
                        #puts $stream "notebook $notebook"
                        scan $line "%s %s" widget path
                        NoteBook $path
                        set containerId [winfo parent $path]
                        #ShowMessage debug info "containerId $containerId" ok
                        pack $path -fill both -expand yes
                    }
                    page {
                        #puts $stream "page $notebook $page $pagecaption"
                        scan $line "%s %s %s %s" widget notebook pageId pagecaption
                        #ShowMessage debug info "$widget $notebook $pageId $pagecaption" ok
                        $notebook insert end $pageId -text $pagecaption \
                                -raisecmd "::RunEnv::PageRaiseCmd $containerId.notebook $pageId"
                        # page raised below before any panes so that must be moved todo                 -raisecmd "::RunEnv::PageRaiseCmd $notebook $pageId"
                        [$notebook getframe $pageId] configure -highlightcolor black  -highlightthickness 1
                        bind [$notebook getframe $pageId] <Button-1> "::RunEnv::SetCurrentContainer %W"
                        bind [$notebook getframe $pageId] <Button-3> \
                                "::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
                        catch {$notebook raise $pageId}; # or $panedwindow sash place won't work but panes nonexistant
                        
                    }
                    default {
                        # puts $stream "Unhandled mre element"
                    }
                }
            }
            close $stream
            $RunEnv::dp0.notebook raise [lindex [$RunEnv::dp0.notebook pages] 0]
        } elseif {[llength $line]==1}  {
            # assume that it is an shf made by the multiple window run env
            RunEnv::AddNotebook $dp0
            seek $stream 0 start
            while {[gets $stream helperId] >= 0} {
                set emptyPage [MainNotebookEmptyPage]
                if {![string match none $emptyPage]} {
                    set containerId [MainNotebookEmptyPage]
                } else  {
                    set containerId [AddNotebookPage $dp0.notebook]
                }
                #ShowMessage debug info "LoadView winId $containerId" ok
                gets $stream helperTitle
                #containerId helperId helperTitle
                #set winId $containerId
                set winId [NewHelperInWindow $containerId $helperId [RestoreCrs $helperTitle]]
                gets $stream geometry
                #wm geometry $winId $geometry # not a toplevel
                gets $stream oldStatus
                set helperTable($winId,status) [RestoreCrs $oldStatus]
                ${helperId}::Restore $winId
            }
            close $stream
            $RunEnv::dp0.notebook raise [lindex [$RunEnv::dp0.notebook pages] 0]
            
        } else  {
            ShowMessage Error error "Unknown display configuration file format" ok
        }
    }
}
    
proc RunEnv::LoadContainer {stream line} {
    global helperTable
    
    #ShowMessage debug info "LoadContainer: stream $stream, line $line" ok
    scan $line "%s %s" item containerId    
    gets $stream helperId
    #ShowMessage debug info "LoadContainer: $item $containerId; helperId $helperId" ok
    set winId [NewHelperInWindow $containerId $helperId ""]        
    gets $stream oldStatus
    set helperTable($winId,status) [RestoreCrs $oldStatus]
    ${helperId}::Restore $winId
    bind $winId <Destroy>  "kill_helper_window $winId"
    ChildrenFocusParent $winId    
}

proc NewMreHelperWindow {helperId helperTitle} {
    global helperTable
    variable ::RunEnv::dp0;    # display pane
    variable ::RunEnv::mainframe
    
    # if it is a $helperTable(VariableList) usu ModelInspector and one already
    # exists, destroy the existing (())don't make a new one, as only one is allowed
    if {[string match $helperTable(VariableList) $helperId]} {
        foreach winIdHelper [array name helperTable *,whichHelper] {
            if {[string match $helperTable($winIdHelper) $helperId]} {
                scan $winIdHelper {%[^,]} winId
                kill_helper_window $winId
            }
        }
    }
    
    # put the RunControl in its own pane
    
    ## Mods my Jasper: Because of quirky behaviour under linux, the standard tools
    ## must each get a new frame (bag) whenever they are rebuilt
    switch $helperId \
            $helperTable(RunControl) {
                set bag $RunEnv::runControlFrame.bag
                if {[winfo exists $bag]} {
                    destroy $bag
                }
                pack [frame $bag]
                set winId $bag
                set ::RunEnv::runControlWindId $bag
            } \
            $helperTable(SliderControl) {
                set bag $RunEnv::sliderControlFrame.bag
                if {[winfo exists $bag]} {
                    destroy $bag
                }
                pack [frame $bag] -fill both -expand true
                set winId $bag
            } \
            $helperTable(ErrorDisplay) {
                toplevel $winId ; #put in own window
            } \
                    $helperTable(VariableList) {
                        set bag $RunEnv::variableListFrame.bag
                        if {[winfo exists $bag]} {
                            destroy $bag
                        }
                pack [frame $bag] -fill both -expand true
                set winId $bag
            } \
            default {
                
                set winId $::RunEnv::CurrentContainer
            }
    bind $winId <Destroy>  "kill_helper_window $winId"
    bind $winId <Button-1> "::RunEnv::SetCurrentContainer $winId"
    set helperTable($helperTitle) $winId
    set helperTable($winId,whichHelper) $helperId
    
    return $winId
}

proc RunEnv::MainNotebookEmptyPage {} {
    variable dp0
    foreach page [$dp0.notebook pages] {
        if {![winfo exists \
            [$dp0.notebook getframe $page].panedwindow.pane0.container]} {
            return [$dp0.notebook getframe $page].panedwindow.pane0
        }
    }
    return none
}

proc RunEnv::UniqueId {basename pagenames} {
    # basename is the root of the Id, numbers after / are appended to it
    # pagenames is the list of existing names
    set i 1
    while {[lsearch -exact $pagenames $basename/$i] > -1} {
        incr i
    }
    set title $basename/$i
}



# A top level window to contain the helpers
# overrides mre.tcl Makemre
proc Makemre { ModelWin } {
    return [RunEnv::Create $ModelWin]
}
