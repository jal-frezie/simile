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
            [list open.gif "Load a configuration of displays" RunEnv::LoadView] \
            [list save.gif "Save the display configuration" RunEnv::SaveView] ]\
            [list \
            [list copyc.gif "Copy display" [list ::RunEnv::CopyHelper $::RunEnv::CurrentContainer]] \
            [list cut.gif "Cut display" [list ::RunEnv::CutHelper $::RunEnv::CurrentContainer"]] \
            [list paste.gif "Paste display" [list ::RunEnv::PasteHelper $::RunEnv::CurrentContainer"]] \
            [list delete.gif "Remove display or container" "::RunEnv::DeleteHelperCurrentContainer" ] \
            [list print.gif "Print display" ::RunEnv::PrintCurrentContainer]] \
            [list \
            [list splithoriz.gif "Split page horizontally" "::RunEnv::SplitCurrentContainer vertical" ] \
            [list splitvert.gif "Split page vertically" "::RunEnv::SplitCurrentContainer horizontal"]] \
            [list \
            [list notebookpage.gif "Add notebook page" "RunEnv::AddNotebookPageToCurrentContainer"] \
            [list notebook.gif "Add notebook" "RunEnv::AddNotebookToCurrentContainer"]] \
            [list \
            [list graph.gif "Create plotter" "CreateHelperWindow plotter1.25 {Plotter}"] \
            [list table.gif "Create table" "CreateHelperWindow tabular11510 {Table}"] \
            [list display.gif "Choose display to create" "::RunEnv::AllDisplaysPopupCurrentContainer"]] \
            [list \
            [list clear.gif "Clear all displays" "ClearView"]]\
            [list \
            [list mainwin.gif "Go to Model Window" "RaiseModelWindow"]]]
}

# A top level window to contain the helpers
proc RunEnv::Create { ModelWin } {
    global helperTable tcl_platform
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
    
    if {![winfo exists .mre]} then {
        #tk_messageBox -message MakeMRE -type ok
        toplevel .mre -width 200m -height 150m
        wm title .mre "Run-Time Environment - Simile"
       set descmenu {
            "&File" all file 0 {
                {command "&New configuration"    {} "Remove all display configuration" {} -command {::RunEnv::KillDisplays} }
                {command "&Load configuration..." {} "Load a configuration of displays" \
                            {} -command {::RunEnv::LoadView} }
                {command "&Save configuration..." {} "Save a configuration of displays" \
                            {} -command {::RunEnv::SaveView} }
                
                {separator}
                {command "&Print..." {} "Print display"  \
                            {} -command { ::RunEnv::PrintCurrentContainer } }
                {separator}
                {command "Pa&rameters..." {} "Modify file parameters"  \
                            {} -command { FileParamDialogue 1 .mre } }
                {separator}
                {command "&Close"    {} "Close the Run Environment window" \
                            {} -command {RunEnv::Destroy} }
            }
            "&Edit" all edit 0 {
                {command "Co&py"    {} "Copy display" {} -command "RunEnv::CopyHelper $::RunEnv::CurrentContainer" }
                {command "Cu&t"    {} "Cut display" {} -command "RunEnv::CutHelper $::RunEnv::CurrentContainer" }
                {command "&Paste"    {} "Paste display" {} -command "::RunEnv::PasteHelper $::RunEnv::CurrentContainer" }
                {separator}
                {command "&Remove"    {} "Remove display or container" {} -command {::RunEnv::DeleteHelperCurrentContainer}}
                {command "&Clear all"    {} "Clear all displays" {} -command {ClearView} }
            }
            "&Help" all help 0 {
                {command "&Contents..." {} "View the help file contents" {} -command {ContextSensitiveHelp .mre run/single.htm} }
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
                set newButton [$bbox add -image [image create photo  -file "../Images/Toolbar/$gif"] \
                        -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 -padx 1 -pady 1 \
                        -command $command]
                BindPopup $newButton $helptext
            }
            pack $bbox -side left -anchor w
            incr tbnum
            pack [Separator $tb1.sep$tbnum -orient vertical] -side left -fill y -padx 4
        }
        
        #from runmodel.tcl AddHelperSublist
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
        $hiercontrolpw add $runcontrolpane $explorerPane ;# -height 240
        
        # Add notebook for controls, explorer etc
        NoteBook $explorerPane.notebook
        $explorerPane.notebook insert end "Explorer" -text "Explorer"
        set variableListFrame [frame [$explorerPane.notebook getframe Explorer].variables]
        pack $explorerPane.notebook $variableListFrame -fill both -expand yes
        
#        $explorerPane.notebook insert end "InputSliders" -text "Input sliders"
#        set sliderControlFrame \
#                [frame [$explorerPane.notebook getframe "InputSliders"].sliders]
        
        #$explorerPane.notebook insert end "Output" -text "Output"
        #set outputFrame \
        #        [frame [$explorerPane.notebook getframe "Output"].sliders -container true]
        pack $variableListFrame -fill both -expand yes
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
        $containerId.notebook insert end $pageId -text "Page $i" \
                -raisecmd "::RunEnv::PageRaiseCmd $containerId.notebook $pageId"
        bind [$containerId.notebook getframe $pageId] <Button-3> \
                "+tk_popup .pageContextMenu %X %Y"
        set newContainer [$containerId.notebook getframe $pageId]
        panedwindow $newContainer.panedwindow -orient vertical
        pack $newContainer.panedwindow -expand yes -fill both
        frame $newContainer.panedwindow.pane0 -highlightcolor black -highlightthickness 1; # -relief ridge;# jmm
        bind $newContainer.panedwindow.pane0 <Button-1> "+::RunEnv::SetCurrentContainer %W"
        bind $newContainer.panedwindow.pane0 <Button-3> \
                "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
        $newContainer.panedwindow add $newContainer.panedwindow.pane0 -sticky nesw
    }
    
    $containerId.notebook bindtabs <Double-1> "::RunEnv::EditTabLabel $containerId.notebook"
    $containerId.notebook bindtabs <Button-3> "::RunEnv::EditTabLabel $containerId.notebook"
    
    $containerId.notebook raise [lindex [$containerId.notebook pages] 0]
    
    pack $containerId.notebook -fill both -expand yes
}

proc RunEnv::EditTabLabel { notebook tabId } {
    variable TabEditText
    set TabEditText [$notebook itemcget $tabId -text]
    #based on equationRight
    #ShowMessage debug info "TabRight tabId $tabId; label [$notebook itemcget $tabId -text]" ok
    catch {destroy .notebookTabTextEdit}
    Dialog .notebookTabTextEdit -parent .mre  -cancel 1 -title {Edit tab label} \
            -transient true
    .notebookTabTextEdit add -text OK; # draw result 0
    .notebookTabTextEdit add -text Cancel; # draw result 1
    set ebox [entry .notebookTabTextEdit.ebox -width 20 -textvariable ::RunEnv::TabEditText]
    pack $ebox -pady 10 -padx 10
    bind $ebox <Return> {.notebookTabTextEdit invoke 0}
    $ebox selection range 0 end
    focus $ebox
    if {[.notebookTabTextEdit draw] == 0} then {
        # OK button selected
        $notebook itemconfigure $tabId -text $TabEditText
    }
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
        $ParentContainer insert end $pageId -text "Page $pageIndex" \
                -raisecmd "::RunEnv::PageRaiseCmd $ParentContainer $pageId"
        set newContainer [$ParentContainer getframe $pageId]
        panedwindow $newContainer.panedwindow -orient vertical
        pack $newContainer.panedwindow -expand yes -fill both
        frame $newContainer.panedwindow.pane0 -highlightcolor black -highlightthickness 1
        bind $newContainer.panedwindow.pane0 <Button-1> "+::RunEnv::SetCurrentContainer %W"
        bind $newContainer.panedwindow.pane0 <Button-3> \
                "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
        $newContainer.panedwindow add $newContainer.panedwindow.pane0
        return $newContainer.panedwindow.pane0
    } else  {
        return [AddNotebookPage $ParentContainer]
    }
    
}

proc RunEnv::AddNotebookPageToCurrentContainer {} {
    AddNotebookPage $::RunEnv::CurrentContainer
}

proc ::RunEnv::AllDisplaysPopup {containerId} {
    variable CurrentContainer $containerId
    tk_popup .helpPopup [winfo pointerx .mre] [winfo pointery .mre]
}

proc RunEnv::AllDisplaysPopupCurrentContainer {} {
    # .helpers.sub2 made by runmodel.tcl AddHelperSublist
    tk_popup .helpers.sub2 [winfo pointerx .mre] [winfo pointery .mre]
}

# Not used - possibly never will be but is skeleton to use the selection for transfer
# of copied helper
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
    
    if [winfo exists $CurrentContainer.container] {
        set CurrentHelperId $helperTable($CurrentContainer.container,whichHelper)
        if {![string match "" [info commands ::${CurrentHelperId}::Print]]} {
            ::${CurrentHelperId}::Print $CurrentContainer.container
        } elseif {![string match "" [info commands ::${CurrentHelperId}::GetCanvas]]} {
            set canvasId [$helperTable($CurrentContainer.container,whichHelper)::GetCanvas $CurrentContainer.container]
            namespace eval :: {
                PrintNow $::RunEnv::canvasId
            }
        } else {
            ShowMessage Warning warning \
                    "[${CurrentHelperId}::identify] does not support printing." ok
        }
        
    }
}

proc ::RunEnv::CopyHelper {containerId} {
    global helperTable simtmpdir tcl_platform
    variable CurrentContainer
    variable CurrentHelperId
    variable canvasId
    
    #ShowMessage debug info \
	"CopyHelper container: $containerId; \n\
    CurrentContainer $CurrentContainer\n \
            selection owner: [selection own]\n\
            focus owner [focus]\n\
            container children [winfo children $CurrentContainer]\n\
            CurrentHelperId $helperTable($CurrentContainer.container,whichHelper)" ok
    if {[winfo exists $CurrentContainer.container]} {
        set CurrentHelperId $helperTable($CurrentContainer.container,whichHelper)
        
        #UpdateState $helperTable($containerId.container)
        if {[string match windows $tcl_platform(platform)]} {
            if {![string match "" [info commands ::${CurrentHelperId}::CopyToClipboard]]} {
                ${CurrentHelperId}::CopyToClipboard $CurrentContainer.container
            } elseif {![string match "" [info commands ::${CurrentHelperId}::GetCanvas]]} {
                set canvasId [::${CurrentHelperId}::GetCanvas $CurrentContainer.container]
                namespace eval :: {
                    CopyCanvasToWindowsClipboard $::RunEnv::canvasId
                }
            } else {
                ShowMessage Warning warning \
                        "[${CurrentHelperId}::identify] does not support copying" ok
            }
            set copyfile $simtmpdir/mrecopy.txts
            set stream [NetOpen $copyfile w]
            catch {puts $stream [StripCrs $helperTable($CurrentContainer.container,status)]}
            close $stream
        }
    }
}

proc ::RunEnv::CutHelper {containerId} {
    CopyHelper $containerId
    DeleteHelperCurrentContainer
}

proc ::RunEnv::PasteHelper {containerId} {
    global helperTable simtmpdir
    variable CurrentContainer
    variable CurrentHelperId
    
    set copyfile $simtmpdir/mrecopy.txts
    if {[file exists $copyfile]} {
        set stream [NetOpen $copyfile r]
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
    if {![winfo exists $containerId]} {
        return
    }
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
    if {[winfo exists $containerId]} {SetCurrentContainer $containerId }
}

proc ::RunEnv::DeleteHelperCurrentContainer {} {
    DeleteHelperContainer $::RunEnv::CurrentContainer {}
}

proc RunEnv::DeleteNotebookPage {notebook page} {
    set pages [$notebook pages]
    #puts "$notebook has pages $pages"
    set n [llength $pages]
    set index [lsearch $pages $page]
    #puts "DeleteNotebookPage  $notebook; $page\n \
    #            page $page; n pages: $n; \n \
    #            parent [winfo parent $notebook]"
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
        #ShowMessage debug info \
	    "DeleteNotebookPage  destroy notebook\n \
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
    #        containerId $containerId\n \
    #        panes [$parentPath panes]" ok;
    set greatgrandparent [winfo parent [winfo parent $parentPath]]
    #puts "DeletePane greatgrandparent $greatgrandparent; class [winfo class $greatgrandparent]"
    if {[string match NoteBook [winfo class $greatgrandparent]]} {
        if {([llength [$greatgrandparent pages]] ==1) && ([llength [$parentPath panes]] == 1)} {
            if {[string match mainDisplayPane [winfo name [winfo parent $greatgrandparent]]]} {
                ShowMessage Information info "Cannot delete this page. The main notebook must have at least one page." ok
                return
            }
        }
    }
    $parentPath forget $containerId
    destroy $containerId
    if {[llength [$parentPath panes]] > 0} {
        SetCurrentContainer [lindex [$parentPath panes] 0]
    } elseif {[llength [$parentPath panes]]==0} {
        # all panedwindows are in a notebook parent
        set parentPage [winfo parent $parentPath]
        set parentNoteBook [winfo parent $parentPage]
        #ShowMessage debug info "DeletePane page\n parentPath $parentPath\n \
        #                parentPage $parentPage; parentNoteBook $parentNoteBook\n \
        #                pages [$parentNoteBook pages]\n \
        #                current page [$parentNoteBook raise]" ok;
        destroy $parentPath
        if {[string match NoteBook [winfo class $parentNoteBook]]} {
            DeleteNotebookPage $parentNoteBook [$parentNoteBook raise]; #current page
        }
    }
}

proc RunEnv::SplitPage {containerId orientation} {
    set parentPath [FindParentpanedwindowOrNotebook $containerId]
    if {[string match notebook [winfo name $parentPath]]} {
        #ShowMessage debug info "SplitPage Addpanedwindow $containerId $orientation" ok;
        Addpanedwindow $containerId $orientation
    } elseif {(![string match $orientation [$parentPath cget -orient]])} {
        #ShowMessage debug info "SplitPage diff orientn container $containerId $orientation\n\
        #parentPath $parentPath" ok;
        Addpanedwindow $containerId $orientation
        #ShowMessage debug info "newpw $newpw" ok
    } else  {
        # it's a pane to be split in the same orientation 
        # add a new pane
        set paneId [UniqueId $parentPath.pane [$parentPath panes]]
        frame $paneId -highlightcolor black -highlightthickness 1
        bind $paneId <Button-1> "+::RunEnv::SetCurrentContainer %W"
        bind $paneId <Button-3> \
                "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
        $parentPath add $paneId -after $containerId
        ###############################################################################
        set pwidth  [winfo width $containerId]
        set pheight [winfo height $containerId]
        set sash [expr {[lsearch [$parentPath panes] $containerId]}]
        set sashCoord [$parentPath sash coord $sash]
        set contx [winfo x $containerId]
        set conty [winfo y $containerId]
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
        ###############################################################################
        
        update idletasks; # or sash place won't work
        $parentPath sash place $sash $sashx $sashy
    }
}

proc RunEnv::SplitCurrentContainer {orientation} {
    SplitPage $::RunEnv::CurrentContainer $orientation
}

proc ::RunEnv::FindParentpanedwindowOrNotebook {containerId} {
    #puts "Finding parent for $containerId"
    set parentPath [winfo parent $containerId]
    set parentName [winfo name $parentPath]
    switch $parentName {
        notebook { return $parentPath }
        panedwindow { return $parentPath }
        "" { return ""}
        default {::RunEnv::FindParentpanedwindowOrNotebook $parentPath}
    }
}

proc ::RunEnv::FindParentPanedwindow {containerId} {
    set parentPath [winfo parent $containerId]
    set parentName [winfo name $parentPath]
    switch $parentName {
        panedwindow { return $parentPath }
        "" { return ""}
        default {::RunEnv::FindParentpanedwindowOrNotebook $parentPath}
    }
}

proc ::RunEnv::FindParentNotebook {containerId} {
    set parentPath [winfo parent $containerId]
    set parentName [winfo name $parentPath]
    switch $parentName {
        notebook { return $parentPath }
        "" { return ""}
        default {::RunEnv::FindParentpanedwindowOrNotebook $parentPath}
    }
}

proc ::RunEnv::FindParentNotebookPage {containerId} {
    set parentPath [winfo parent $containerId]
    set parentName [winfo name $parentPath]
    switch -glob $parentName {
        fpage* { return $parentPath }
        "" { return ""}
        default {::RunEnv::FindParentpanedwindowOrNotebook $parentPath}
    }
}

proc RunEnv::Destroy {} {
    global helperTable window_info model_id
    variable runControlWindId
    variable mainframe
    
    # stop the run
    if {[info exists runControlWindId]} {
        set ControlSpace $helperTable($runControlWindId,whichHelper)
        ::${ControlSpace}::Terminate
    }
    
    destroy .helpPopup
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
    bind $containerId.panedwindow.pane0 <Button-1> "+::RunEnv::SetCurrentContainer %W"
    bind $containerId.panedwindow.pane1 <Button-1> "+::RunEnv::SetCurrentContainer %W"
    bind $containerId.panedwindow.pane0 <Button-3> \
            "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
    bind $containerId.panedwindow.pane1 <Button-3> \
            "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
    $containerId.panedwindow add $containerId.panedwindow.pane0 $containerId.panedwindow.pane1 \
            -width $width -height $height
    SetCurrentContainer $containerId.panedwindow.pane0
    return $containerId.panedwindow
}

proc RunEnv::SetCurrentContainer {win} {
    #ShowMessage debug info "SetCurrentContainer $win" ok
    variable mainframe
    if {![string match pane* [winfo name $win]]} {
        return
    }
    set mreMenu [winfo parent [$mainframe getmenu help]]
    set pw [FindParentPanedwindow $win]
    #ShowMessage debug info "RunEnv::SetCurrentContainer pw $pw" ok
    set tb1 [$mainframe gettoolbar 0]
    if {[winfo exists $win.container]} {
#        $mreMenu entryconfigure Add -state disable
        [$mainframe getmenu edit] entryconfigure Copy -state normal
        [$mainframe getmenu edit] entryconfigure Cut -state normal
        [$mainframe getmenu edit] entryconfigure Paste -state disable
        $tb1.bbox1 itemconfigure 2 -state disabled; # paste button
        $tb1.bbox3 itemconfigure 1 -state disabled; # Add Notebook button
        $tb1.bbox4 itemconfigure 0 -state disabled; # add helper buttons
        $tb1.bbox4 itemconfigure 1 -state disabled
        $tb1.bbox4 itemconfigure 2 -state disabled
        if {[winfo exists .pageContextMenu]} {
            .pageContextMenu entryconfigure 0 -state disabled
            .pageContextMenu entryconfigure 1 -state disabled
            .pageContextMenu entryconfigure 2 -state disabled
            .pageContextMenu entryconfigure 6 -state disabled
            .pageContextMenu entryconfigure 11 -state disabled; # add notebook
            #.pageContextMenu entryconfigure 12 -state disabled; # add notebook p0age
        }
        if {[string match vertical [$pw cget -orient]]} {
            #ShowMessage debug info "vert $tb1.bbox2" ok
            $tb1.bbox2 itemconfigure 1 -state disabled
            $tb1.bbox2 itemconfigure 0 -state normal
            .pageContextMenu entryconfigure 9 -state disabled
            .pageContextMenu entryconfigure 8 -state normal
        } else  {
            #ShowMessage debug info "horiz $tb1.bbox2" ok
            $tb1.bbox2 itemconfigure 0 -state disabled
            $tb1.bbox2 itemconfigure 1 -state normal
            .pageContextMenu entryconfigure 8 -state disabled
            .pageContextMenu entryconfigure 9 -state normal
        }
    } else  {
        $mreMenu entryconfigure Add -state normal
        [$mainframe getmenu edit] entryconfigure Copy -state disable
        [$mainframe getmenu edit] entryconfigure Cut -state disable
        [$mainframe getmenu edit] entryconfigure Paste -state normal
        $tb1.bbox1 itemconfigure 2 -state normal; # paste button
        $tb1.bbox2 itemconfigure 1 -state normal
        $tb1.bbox2 itemconfigure 0 -state normal
        $tb1.bbox3 itemconfigure 1 -state normal; # Add Notebook button
        $tb1.bbox4 itemconfigure 0 -state normal; # add helper buttons
        $tb1.bbox4 itemconfigure 1 -state normal
        $tb1.bbox4 itemconfigure 2 -state normal
        if {[winfo exists .pageContextMenu]} {
            .pageContextMenu entryconfigure 0 -state normal
            .pageContextMenu entryconfigure 1 -state normal
            .pageContextMenu entryconfigure 2 -state normal
            .pageContextMenu entryconfigure 6 -state normal
            .pageContextMenu entryconfigure 9 -state normal
            .pageContextMenu entryconfigure 8 -state normal
            .pageContextMenu entryconfigure 11 -state normal
            #.pageContextMenu entryconfigure 12 -state normal
        }
    }
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
        $m add command -label "Create plotter" -command "CreateHelperWindow plotter1.25 {Plotter}"
        $m add command -label "Create table" -command "CreateHelperWindow tabular11510 {Table}"
        $m add cascade -label "Choose display to create ..." -menu .helpers.sub2
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
        $m add command -label "Delete" -command "::RunEnv::DeleteHelperCurrentContainer"
    }
}

proc RunEnv::KillDisplays {} {
    global helperTable
    global ::RunEnv::dp0
    
    destroy $RunEnv::dp0.notebook
    RunEnv::AddNotebook $dp0
}

proc RunEnv::ChildrenFocusParent {parent} {
    # despite the inner frame being called the container its the pane
    # could clean up the naming sometime
    set Container [winfo parent $parent]
    #ShowMessage debug info "ChildrenFocusParent:\n\
    #        parent : $parent; container $Container\n\
    #        children [winfo children $parent]" ok
    foreach child [winfo children $parent] {
        bind $child <Button-1> "+::RunEnv::SetCurrentContainer $Container"
    }
}

proc RunEnv::NewHelperInWindow {containerId helperId helperTitle} {
    global helperTable
    #ShowMessage debug info "NewHelperInWindow: \
    #        containerId $containerId helperId $helperId helperTitle $helperTitle\n \
    #        containers children: [winfo children $containerId]" ok
    
    set winId $containerId.container
    if {[catch {frame $winId}]} {
        error "Cannot create a display in the selected pane \
                because it already contains one.\nPlease select an empty pane and try again."; #return
    }
    pack $winId -fill both -expand yes
    set helperTable($helperTitle) $winId
    set helperTable($winId,whichHelper) $helperId
    bind $winId <Destroy>  "kill_helper_window $winId"
    RunEnv::SetCurrentContainer [winfo parent $winId]
    return $winId
}

#  nameOfHelperStateFile is global because helpers might want to save names of
# other files they need relative to it, e.g., file param helper

proc RunEnv::SaveView {} {
    global helperTable nameOfHelperStateFile
    variable dp0
    variable mainframe
    
    set nameOfHelperStateFile \
	[ChooseFile Displays.shf "Save display configuration" 1]
    if {[llength $nameOfHelperStateFile]} {
        set stream [NetOpen $nameOfHelperStateFile w]
        
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
        regsub -all " " $pagecaption _ noSpcpagecaption
        puts $stream "page $notebook $page $noSpcpagecaption"
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
    for {set index 0} {$index < [expr [llength [$panedwindow panes]]-1]} \
            {incr index} {
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
    set HelperStateFileName \
            [ChooseFile Displays.shf "Open view specification file" 0]
    LoadSHF $HelperStateFileName
}

proc RunEnv::LoadSHF {HelperStateFileName} {
    global helperTable nameOfHelperStateFile errorInfo
    variable mainframe
    variable dp0
    
    set nameOfHelperStateFile $HelperStateFileName
    if {[llength $nameOfHelperStateFile]} {
        set stream [NetOpen $nameOfHelperStateFile r]
        
        # check for run env that made the shf
        gets $stream line
        if {[llength $line]==4} {
            LoadViewFile $stream $line
        } elseif {[llength $line]==1}  {
            # assume that it is an shf made by the multiple window run env
            destroy $RunEnv::dp0.notebook; #what if there is an error in the file delete MRE, rebuild
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
                if {[catch {${helperId}::Restore $winId}]} {
		    DeleteHelperCurrentContainer
		    ShowMessage "Problem restoring helper" warning $errorInfo \
			ok
		} else {
		    ChildrenFocusParent $winId
		}
            }
            $RunEnv::dp0.notebook raise [lindex [$RunEnv::dp0.notebook pages] 0]
            
        } else  {
            ShowMessage Error error "Unknown display configuration file format" ok
        }
        close $stream
    }
}

proc RunEnv::LoadViewFile {stream line} {
    global helperTable
    variable mainframe
    variable dp0
    
    destroy $RunEnv::dp0.notebook
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
                bind $path <Button-1> "+::RunEnv::SetCurrentContainer %W"
                bind $path <Button-3> \
                        "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
            }
            sash {
                scan $line "%s %s %i %i %i" sash panedwindow index sashx sashy
                # the page this pane is in must be raised and update called!
                # or $panedwindow sash place won't work
                set $notebook [FindParentNotebook $panedwindow]
                set $pageId [winfo name [FindParentNotebookPage $panedwindow]]
                $notebook raise $pageId;
                update
                #ShowMessage debug info "$panedwindow sash place $index $sashx $sashy \n\
                #        page [$notebook pages]\n\
                #        FindParentNotebook $notebook \n\
                #        FindParentNotebookPage $pageId" ok
                $panedwindow sash place $index $sashx $sashy
            }
            notebook {
                #puts $stream "notebook $notebook"
                scan $line "%s %s" widget path
                NoteBook $path
                set containerId [winfo parent $path]
                #ShowMessage debug info "containerId $containerId" ok
                $path bindtabs <Double-1> "::RunEnv::EditTabLabel $containerId.notebook"
                $path bindtabs <Button-3> "::RunEnv::EditTabLabel $containerId.notebook"
                pack $path -fill both -expand yes
            }
            page {
                #puts $stream "page $notebook $page $pagecaption"
                scan $line "%s %s %s %s" widget notebook pageId noSpcpagecaption
                regsub -all _ $noSpcpagecaption " " pagecaption
                
                #ShowMessage debug info "$widget $notebook $pageId $pagecaption" ok
                $notebook insert end $pageId -text $pagecaption \
                        -raisecmd "::RunEnv::PageRaiseCmd $containerId.notebook $pageId"
                # page raised below before any panes so that must be moved todo                 -raisecmd "::RunEnv::PageRaiseCmd $notebook $pageId"
                bind [$notebook getframe $pageId] <Button-1> "+::RunEnv::SetCurrentContainer %W"
                bind [$notebook getframe $pageId] <Button-3> \
                        "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
                #$notebook raise $pageId
                #catch {$notebook raise $pageId}; # or $panedwindow sash place won't work but panes nonexistant
                
            }
            default {
                # puts $stream "Unhandled mre element"
            }
        }
    }
    $RunEnv::dp0.notebook raise [lindex [$RunEnv::dp0.notebook pages] 0]
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
    #bind $winId <Destroy>  "kill_helper_window $winId"
    ChildrenFocusParent $winId
}

proc NewMreHelperWindow {helperId helperTitle} {
    global helperTable
    variable ::RunEnv::dp0;    # display pane
    variable ::RunEnv::mainframe
    
    #ShowMessage debug info "NewMreHelperWindow: helperId $helperId; helperTitle $helperTitle" ok
    
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
    set def 0
    
    ## Mods my Jasper: Because of quirky behaviour under linux, the standard tools
    ## must each get a new frame (bag) whenever they are rebuilt
    switch $helperId \
	$helperTable(RunControl) {
	    set bag $RunEnv::runControlFrame.bag
	    if {[winfo exists $bag]} {
		destroy $bag
	    }
	    pack [frame $bag] -fill both -expand on
	    set winId $bag
	    set ::RunEnv::runControlWindId $bag
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
	    set def 1
	    set winId [::RunEnv::NewHelperInWindow $::RunEnv::CurrentContainer $helperId $helperTitle]
	}
    if {$def==0} {
        bind $winId <Destroy>  "kill_helper_window $winId"
        bind $winId <Button-1> "+::RunEnv::SetCurrentContainer $winId"
        set helperTable($helperTitle) $winId
        set helperTable($winId,whichHelper) $helperId
    }
    
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
