# Support for the Model Run Environment moved to a seperate source file mre.tcl
# this file must source the mre.tcl file and MakeMRE is called from proc ModelWindow
# Jonathan Massheder

# todo
# page and panes must have automatic ids - program can't control pages and panes by id but by index
# Use display page unique id code for pages and panes
# Make proc to access page and pane by index (index to id, use list and lindex)

# helpers must biind $canvas <Configure> resize $canvas

namespace eval RunEnv {
    
    package require BWidget    
    
    variable data; # array of persistent data, saved/restored using SaveState/GetState
    variable mainframe
    variable status
    variable prgtext
    variable prgindic
    variable pwside; # array of side values for PanedWindows
    variable runControlFrame; # the widget id of the frame to hold the run control
    variable sliderControlFrame;
    variable variableListFrame;
    variable explorerPane
    variable dp0;    # display pane
    variable toolbarItems; # list of toolbar items
    variable PageToolbarItems
    variable CurrentContainer {}
    variable CurrentPage {}
    
    #    set data(width) 780; # window width  # should be an option
    #    set data(height) 580; #window height  # should be an option
    variable width 780; # window width  # should be an option
    variable height 580; #window height  # should be an option
    
    set helperTable(VariableList) ModelInspector63654; # should be an option
    set helperTable(ErrorDisplay) fun03040 ; # should be an option
    
    # list of toolbar items. Each item is a list of:
    # gif in $similepath/images/toolbar
    # pop-up message
    # command
    # make a config file. Try to load config file, if fails load default list
    #{graph.gif "Plotter"\
    #            "CreateHelperWindow plotter1.25 {Plotter}"}
    #{table.gif "Data table"\
    #            "CreateHelperWindow tabular11508 {Data table}" }
    set toolbarItems [list \
            [list new.gif "New display configuration" RunEnv::KillDisplays] \
            [list open.gif "Load a configuation of displays" RunEnv::LoadView] \
            [list save.gif "Save the display configuation" RunEnv::SaveView] \
            [list copy.gif "Copy display" "::RunEnv::CopyHelper $CurrentContainer"] \
            [list cut.gif "Cut display" "::RunEnv::CutHelper $CurrentContainer"] \
            [list paste.gif "Paste display" "::RunEnv::PasteHelper $CurrentContainer"] \
            [list delete.gif "Delete pane or page" "::RunEnv::DeleteHelperCurrentContainer" ] \
            [list splithoriz.gif "Split page horizontally" "::RunEnv::SplitCurrentContainer vertical" ] \
            [list splitvert.gif "Split page vertically" "::RunEnv::SplitCurrentContainer horizontal"] \
            [list NoteBookPage.GIF "Add notebook page" "RunEnv::AddNotebookPageToCurrentContainer"] \
            [list NoteBook.GIF "Add notebook" "RunEnv::AddNotebookToCurrentContainer"] \
            [list graph.gif "Create plotter" "::RunEnv::CreateHelperInCurrentContainer plotter1.25 {Plotter}"] \
            [list table.gif "Create table" "::RunEnv::CreateHelperInCurrentContainer tabular11510 {Table}"] \
            [list display.gif "Choose display to create" "::RunEnv::AllDisplaysPopupCurrentContainer"] \
            [list mainwin.gif "Go to Model Window" "RaiseModelWindow"]]
        }

# A top level window to contain the helpers
proc RunEnv::Create { ModelWin } {
    global helperTable tcl_platform modelWin
    variable data
    variable pwside
    variable mainframe
    variable runControlFrame
    variable sliderControlFrame;
    variable variableListFrame;
    variable ::RunEnv::mainframe; ## duplicate?
    variable explorerPane
    variable dp0;    # display pane
    variable toolbarItems; # list of toolbar items
    variable width
    variable height
    
    destroy .helpPopup
    if {![winfo exists .mre]} then {
        #    tk_messageBox -message MakeMRE -type ok
        toplevel .mre -width 200m -height 150m
        wm title .mre "Run-Time Environment - Simile"
        # Menu description
        set descmenu {
            "&File" all file 0 {
                {command "&Load configuration..." {} "Load a configuation of displays" \
                            {} -command {::RunEnv::LoadView} }
                {command "&Save configuration..." {} "Save a configuation of displays" \
                            {} -command {::RunEnv::SaveView} }
                {separator}
                {command "&Parameters..." {} "Modify file parameters"  \
                            {} -command { FileParamDialogue 1 .mre } }
                {separator}
                {command "&Close"    {} "Close the Run Environment window" \
                            {} -command {RunEnv::Destroy} }
            }
            "&Edit" all edit 0 {
                {command "&Remove..."    {} "Remove a sheet" {} -command {::RunEnv::RemoveHelperPageDlg} }
                {separator}
                {command "&Clear all"    {} "Clear all sheets" {} -command {::RunEnv::ClearDisplays} }
                {command "Cl&ose all"    {} "Close all sheets" {} -command {::RunEnv::KillDisplays} }
            }
            "&Add" all add 0 {
                {separator}
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
        set bbox [ButtonBox $tb1.bbox1 -spacing 0 -padx 1 -pady 1]
        set sep [Separator $tb1.sep -orient vertical]
        pack $sep -fill y -padx 4
        
        # build the toolbar  from the toolbarItems list
        foreach item $toolbarItems {
            set gif [lindex $item 0]
            set helptext [lindex $item 1]
            set command [lindex $item 2]
            $bbox add -image [image create photo  -file "../Images/Toolbar/$gif"] \
                    -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 -padx 1 -pady 1 \
                    -helptext $helptext -command $command
        }
        pack $bbox -side left -anchor w
        
        # load the display helpers
        set oldDir [pwd]
        cd ../IOTools; #Displays todo
        [$mainframe getmenu add] delete 0
        AddHelperSublist [$mainframe getmenu add ] {} "Add" 0 true
        cd $oldDir
        
        # Add a PanedWindow for the hierrachical/run control view and main display window
        set mainpw [panedwindow [$mainframe getframe].mainpw  -orient horizontal]
        set controlPane [frame $mainpw.controlPane]
        #bind $mainpw.controlPane <Button-1> "::RunEnv::SetCurrentContainer {}"
            
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
        #        bind $runControlFrame <Activate> "::RunEnv::ResizePane %W %w %h"
        
        CreateDisplayPageContextMenu
        
        # Model variable explorer is created automatically elsewhere
        # run control is automatically created when model is run
        # input slider helper is automatically created if needed when model is run
        
        wm geometry .mre ${width}x${height}; # should be changeable, option? todo
        #wm protocol .mre WM_DELETE_WINDOW RunEnv::Destroy
        if {[string match unix $tcl_platform(platform)]} {
            wm iconbitmap .mre @../Images/dribble.xbm
        }; # on Windows uses default icon set in Runmodel.tcl
    } ; # if .mre exists
    return .mre
}

proc RunEnv::ResizePane {window width height} {
    ShowMessage debug info "$window $width $height" ok
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
        bind $newContainer.panedwindow.pane0 <Button-1> "::RunEnv::SetCurrentContainer %W {}"
        bind $newContainer.panedwindow.pane0 <Button-3> \
                "::RunEnv::SetCurrentContainer %W {}; tk_popup .pageContextMenu %X %Y"
        $newContainer.panedwindow add $newContainer.panedwindow.pane0 
    }
    
    $containerId.notebook raise [lindex [$containerId.notebook pages] 0]
    
    pack $containerId.notebook -fill both -expand yes
}

proc RunEnv::PageRaiseCmd {notebook pageId} {
    set pageF [$notebook getframe $pageId]
    set firstPane [lindex [$pageF.panedwindow panes] 0]
    SetCurrentContainer $firstPane {}
}

proc RunEnv::AddNotebookToCurrentContainer {} {
    AddNotebook $::RunEnv::CurrentContainer
}

proc RunEnv::AddNotebookPage {containerId} {
    set ParentContainer [FindParentpanedwindowOrNotebook $containerId]
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
        bind $newContainer.panedwindow.pane0 <Button-1> "::RunEnv::SetCurrentContainer %W {}"
        bind $newContainer.panedwindow.pane0 <Button-3> \
                "::RunEnv::SetCurrentContainer %W {}; tk_popup .pageContextMenu %X %Y"
        $newContainer.panedwindow add $newContainer.panedwindow.pane0
    } else  {
        AddNotebookPage $ParentContainer
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
            [list NoteBookPage.GIF "Add notebook page" "RunEnv::AddNotebookPage $containerId"] \
            [list NoteBook.GIF "Add notebook" "RunEnv::AddNotebookPageToCurrentContainer"] \
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
    tk_popup .helpPopup [winfo pointerx .mre] [winfo pointery .mre]
}

proc ::RunEnv::CopyHelper {containerId} {
    global helperTable
    if [winfo exists $containerId.container] {
        #UpdateState $helperTable($containerId.container)
        # set helperTable($frameid) $winId
        # set helperTable($winId,frameid) $frameid
        set winId $helperTable($containerId.container)
        set canvasId [$helperTable($winId,whichHelper)::GetCanvas $helperTable($containerId.container)]
        CopyCanvasToWindowsClipboard $canvasId
    }
}

proc ::RunEnv::CutHelper {containerId} {
    global helperTable
    if [winfo exists $containerId.container] {
        ::UpdateState $helperTable($containerId.container)
    }
}

proc ::RunEnv::PasteHelper {containerId} {
    global helperTable
    
}

proc ::RunEnv::DeleteHelperContainer {containerId page} {
    global helperTable
    # container is the frame a helper would be displayed in
    # a parent is the notebook or panedwindow the container belongs to
    #    ShowMessage debug info "container $containerId; page $page; \
    #            parent [::RunEnv::FindParentpanedwindowOrNotebook $containerId]" ok
    set parentPath [::RunEnv::FindParentpanedwindowOrNotebook $containerId]
    set parentType [winfo name $parentPath]
    set children [winfo children $containerId]
    ShowMessage debug info "DeleteHelperContainer: $containerId\n \
            children $children\n \
            parentType $parentType" ok; ##################
    if {[lsearch $children *.container]>-1} {
        #kill_helper_window $helperTable($containerId.container)
        destroy $containerId.container
    } else {
        switch $parentType {
            notebook {DeleteNotebookPage $parentPath $page}
            panedwindow {DeletePane $parentPath $containerId}
        }
    }
}

proc ::RunEnv::DeleteHelperCurrentContainer {} {
    DeleteHelperContainer $::RunEnv::CurrentContainer $::RunEnv::CurrentPage
}

proc RunEnv::DeleteNotebookPage {notebook page} {
    set pages [$notebook pages]
    set n [llength $pages]
    set index [lsearch $pages $page]
    #ShowMessage debug info "notebook $notebook; page $page; n pages: $n; parent" ok
    if {$n==1} {
        if {[string match mainDisplayPane [winfo name [winfo parent $notebook]]]} {
            ShowMessage Information info "Cannot delete this page. The main notebook must have at least one page." ok
            return
        }
    }
    $notebook delete $page 1
    if {$n==0} {
        set containerId [winfo parent $notebook]
        destroy $notebook
        
    } else  {
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
    ShowMessage debug info "DeletePane\n parentPath $parentPath\n \
            containerId $containerId\n \
            panes [$parentPath panes]" ok; ###########
    $parentPath forget $containerId
    destroy $containerId
    if {[llength [$parentPath panes]]==0} {
        destroy $parentPath
    }
}

proc RunEnv::SplitPage {containerId orientation} {
    ShowMessage debug info "SplitPage $containerId $orientation" ok
    
    set parentPath [FindParentpanedwindowOrNotebook $containerId]
    if {[string match notebook [winfo name $parentPath]]} {
        Addpanedwindow $containerId $orientation
    } elseif {(![string match $orientation [$parentPath cget -orient]])} {
        Addpanedwindow $containerId $orientation
    } else  {
        set n [expr {[llength [$parentPath panes]]+1}]
        frame $parentPath.pane$n -highlightcolor black -highlightthickness 1
        bind $parentPath.pane$n <Button-1> "::RunEnv::SetCurrentContainer %W {}"
        bind $parentPath.pane$n <Button-3> \
                "::RunEnv::SetCurrentContainer %W {}; tk_popup .pageContextMenu %X %Y"
        $parentPath add $parentPath.pane$n
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

proc ::RunEnv::FindParentWidth {widget} {
    set parent [winfo parent $widget]
    set width [$parent cget -width]
    if {($width == 0) || ([string match "" $width])} {
        ::RunEnv::FindParentWidth $parent
    } else  {
        #ShowMessage debug info "FindParentWidth parent $parent" ok
        return $width
    }
}

proc ::RunEnv::FindParentHeight {widget} {
    set parent [winfo parent $widget]
    set height [$parent cget -height]
    if {($height == 0) || ([string match "" $height])} {
        ::RunEnv::FindParentHeight $parent
    } else  {
        #ShowMessage debug info "FindParentHeight parent $parent" ok
        return $height
    }
}

proc RunEnv::Destroy {} {
    global helperTable modelWin
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
    ShowMessage debug info "RunEnv::Addpanedwindow $containerId $orientation\n \
            pwidth $pwidth; pheight $pheight" ok
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
            ShowMessage debug info "Addpanedwindow: incorrect value for orientation: $orientation;\
                    must be  must vertical or horizontal" ok
        }
    }
    #ShowMessage debug info "RunEnv::Addpanedwindow width $width; height $height" ok
    frame $containerId.panedwindow.pane0 -highlightcolor black -highlightthickness 1
    frame $containerId.panedwindow.pane1 -highlightcolor black  -highlightthickness 1
    bind $containerId.panedwindow.pane0 <Button-1> "::RunEnv::SetCurrentContainer %W {}"
    bind $containerId.panedwindow.pane1 <Button-1> "::RunEnv::SetCurrentContainer %W {}"
    bind $containerId.panedwindow.pane0 <Button-3> \
            "::RunEnv::SetCurrentContainer %W {}; tk_popup .pageContextMenu %X %Y"
    bind $containerId.panedwindow.pane1 <Button-3> \
            "::RunEnv::SetCurrentContainer %W {}; tk_popup .pageContextMenu %X %Y"
    $containerId.panedwindow add $containerId.panedwindow.pane0 $containerId.panedwindow.pane1 \
            -width $width -height $height
}

proc RunEnv::SetCurrentContainer {win page} {
    focus $win
    set ::RunEnv::CurrentContainer $win
    set ::RunEnv::CurrentPage $page
}

# Return a list of all children, found recursively, of a widget
proc RunEnv::GetChildren { widget } {
    #    ShowMessage debug info "GetChildren" ok
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
        #        ShowMessage debug info "$widget\n[lindex [split $widget .] end]" ok
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

proc RunEnv::OnDestroyHelper {winId} {
    #    ShowMessage debug info "RunEnv::DestroyHelper [FindHelperPage $winId]" ok
    #    ShowMessage debug info "RunEnv::DestroyHelper [wm title $winId]" ok
    #    unset helperTable($winId,frameid))
    #    if {[exists helperTable($winId,frameid)]} {
    #        unset helperTable($winId,frameid)
    #    }
    ################################################################################
    #     set notebookPage [FindHelperPage $winId]
    #     set notebook [lindex $notebookPage 0]
    #     if {![string match "" $notebook]} {
    #         set page [lindex $notebookPage 1]
    #         while {[winfo exists $winId]} { after 10 }; # don't delete until the helper has gone
    #         $notebook delete $page 1; # delete the page and associated frame
    #         if {[llength [$notebook pages]] > 0} {
    #             $notebook raise [lindex [$notebook pages] 0]
    #         }
    #     }
    ################################################################################
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

# Based on Runmodel.tcl AddHelperSublist but loads the root helper directory
# helpers directly into the given menu not an "Add" cascade menu item.
# Menu items for helpers in subdirs are added in cascade sub menus
# Added the root parameter which should be given as true when a user calls
# RunEnv::AddHelperSublist. Internally for subdirectories false is passed
# for root. Original behaviour should be exhibited if user calls
# RunEnv::AddHelperSublist with false passed for root. JMM.
proc RunEnv::AddHelperSublist {fm pm title ct root} {
    global custom helperTable
    # Create a menu for the menu bar (original)
    # Craete a popup menu for Create in window
    set nct 0
    # do not make a cascade menu for the helper root directory
    if {$root} {
        set m $fm
        set pm [menu .helpPopup -tearoff 0]
    } else  {
        $fm insert $ct cascade -label $title... -menu $fm.sub$ct
        set m [menu $fm.sub$ct -tearoff 0]
        set pm [menu $pm.sub$ct -tearoff 0]
    }
    set i 0
    set helperList [glob -nocomplain *.tcl]
    foreach helperApp [lsort $helperList] {
        if {[catch {source $helperApp} wibble]} {
            ShowMessage "Error loading I/O tool" warning \
                    "Helper [pwd]/$helperApp had a $wibble" ok
        } else {
            if {[info exists keyValue]} {
                set action [${keyValue}::identify]
                if {[string match {Run control} $action]} {
                    set helperTable(RunControl) $keyValue
                }
                if {[string match {Slider control} $action]} {
                    set helperTable(SliderControl) $keyValue
                }
                $m insert $i command -label $action \
                        -command [list CreateHelperWindow $keyValue $action]
                $pm insert $i command -label $action \
                        -command [list ::RunEnv::CreateHelperInCurrentContainer $keyValue $action]
                unset keyValue
                incr i
            }
        }
    }
    foreach subDir [glob -nocomplain *] {
        if {[file isdirectory $subDir]} {
            cd $subDir
            AddHelperSublist $m $pm $subDir $nct false
            cd ..
            incr nct
        }
    }
}

# Returns a list: index 0 is the Notebook and index 1 is the page
proc RunEnv::FindHelperPage { winId } {
    variable ::RunEnv::dp0;    # display pane
    variable ::RunEnv::mainframe
    
    set allChildren [::RunEnv::GetChildren $mainframe]; # shd b $dp0
    #    ShowMessage debug info "$allChildren [string range $winId 1 end ]" ok
    set notebookPath [::RunEnv::GetWidgetsWithName $allChildren f[string range $winId 1 end ]]
    set page [string range $winId 1 end]
    regsub .f$page $notebookPath "" notebookPath
    #    ShowMessage debug info "$notebookPath; $page" ok
    return [list $notebookPath $page]
}

proc RunEnv::CreateDisplayPageContextMenu {} {
    if  {![winfo exists .pageContextMenu]} {
        set m [menu .pageContextMenu -tearoff 0]
        $m add command -label "Create plotter" -command "::RunEnv::CreateHelperInCurrentContainer plotter1.25 {Plotter}"
        $m add command -label "Create table" -command "::RunEnv::CreateHelperInCurrentContainer tabular11510 {Table}"
        $m add command -label "Choose display to create" -command "::RunEnv::AllDisplaysPopupCurrentContainer"
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

proc RunEnv::ClearDisplays {} {
    global helperTable
    global ::RunEnv::dp0
    
    set allChildren [::RunEnv::GetChildren $dp0]; # shd b $dp0
    set allDisplaynotebooks [::RunEnv::GetWidgetsWithName $allChildren notebook]
    foreach notebook $allDisplaynotebooks {
        if {[llength [$notebook pages]] > 0 } {
            set pages [$notebook pages]
            foreach page $pages {
                ::$helperTable(.$page,whichHelper)::clear .$page
            }
        }
    }
}

proc RunEnv::KillDisplays {} {
    global helperTable
    global ::RunEnv::dp0
    
    set allChildren [::RunEnv::GetChildren $dp0]; # shd b $dp0
    set allDisplaynotebooks [::RunEnv::GetWidgetsWithName $allChildren notebook]
    foreach notebook $allDisplaynotebooks {
        if {[llength [$notebook pages]] > 0 } {
            set pages [$notebook pages]
            foreach page $pages {
                kill_helper_window .$page
            }
        }
    }
}

proc RunEnv::CreateHelperInWindow {containerId helperId helperTitle} {
    global helperTable
    variable PageToolbarItems
    
    set frameid $containerId.container
    frame $frameid
    pack $frameid -fill both -expand yes
    set winId $frameid
    set helperTable($helperTitle) $winId
    set helperTable($winId,whichHelper) $helperId
    
    ${helperId}::initialize $winId
    bind $winId <Destroy>  "RunEnv::OnDestroyHelper $winId"
}

proc RunEnv::CreateHelperInCurrentContainer {helperId helperTitle} {
    variable CurrentContainer
    CreateHelperInWindow $CurrentContainer $helperId $helperTitle
}

proc RunEnv::SaveViewOld {} {
    global helperTable
    set savedView [ChooseFile Displays.shf "Save view specification file" 1]
    if {[llength $savedView]} {
        set stream [open $savedView w]
        foreach displayBox [array name helperTable *,whichHelper] {
            scan $displayBox {%[^,]} winId
            set helperId $helperTable($displayBox)
            if {!([string match $helperId $helperTable(RunControl)] || \
                        [string match $helperId $helperTable(SliderControl)])} {
                puts $stream $helperId
                # substitute <cr>s so entry goes on one line
                puts $stream [StripCrs [wm title $winId]]
                puts $stream [wm geometry $winId]
                set clickedPaths {}
                if {[info exists helperTable($winId,status)]} {
                    puts $stream [StripCrs $helperTable($winId,status)]
                } else {
                    puts $stream {}
                }
            }
        }
        close $stream
    }
}

proc RunEnv::SaveView {} {
    global helperTable
    variable dp0
    set savedView [ChooseFile Displays.shf "Save display configuration" 1]
    if {[llength $savedView]} {
        set stream [open $savedView w]
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
            #puts $stream "$notebook $page $child"
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
}

proc RunEnv::SaveContainer {child stream} {
    global helperTable
    set winId $helperTable($child)
    set helperId $helperTable($winId,whichHelper)
    puts $stream "container $child"
    puts $stream $helperId
    # substitute <cr>s so entry goes on one line
    puts $stream [StripCrs [wm title $winId]]
    puts $stream [wm geometry $winId]
    if {[info exists helperTable($winId,status)]} {
        puts $stream [StripCrs $helperTable($winId,status)]
    } else {
        puts $stream {}
    }
}

proc RunEnv::LoadViewOld {} {
    global helperTable
    set savedView [ChooseFile Displays.shf "Open view specification file" 0]
    if {[llength $savedView]} {
        set stream [open $savedView r]
        while {[gets $stream helperId] >= 0} {
            gets $stream helperTitle
            set winId [NewHelperWindow $helperId [RestoreCrs $helperTitle]]
            gets $stream geometry
            wm geometry $winId $geometry
            gets $stream oldStatus
            set helperTable($winId,status) [RestoreCrs $oldStatus]
            ${helperId}::Restore $winId
        }
        close $stream
    }
}

proc RunEnv::LoadView {} {
    global helperTable
    set savedView [ChooseFile Displays.shf "Open view specification file" 0]
    if {[llength $savedView]} {
        destroy $RunEnv::dp0.notebook; #what if there is an error in the file delete MRE, rebuild
        set stream [open $savedView r]
        while {[gets $stream line] >= 0} {
            switch [scan $line %s] {
                container {
                    LoadContainer $stream $line
                }
                panedwindow {
                    #%puts $stream "panedwindow $panedwindow [$panedwindow cget -orient]"
                    scan $line "%s %s %s" widget path orient
                    panedwindow $path -orient $orient
                    set containerId [winfo parent $path]
                    ShowMessage debug info "containerId $containerId" ok
                    destroy $containerId.abovebox
                    destroy $containerId.bbframe
                    destroy $containerId.belowbox
                    pack $path -expand yes -fill both
                }
                pane {
                    #%puts $stream "pane $pane"
                    scan $line "%s %s" widget path
                    frame $path -highlightcolor black  -highlightthickness 1
                    set panedwindow [winfo parent $path]
                    $panedwindow add $path
                    bind $path <Button-1> "::RunEnv::SetCurrentContainer %W {}"
                    bind $path <Button-3> \
                            "::RunEnv::SetCurrentContainer %W {}; tk_popup .pageContextMenu %X %Y"
                    AddNewPageToolBar $path 0
                }
                notebook {
                    #puts $stream "notebook $notebook"
                    scan $line "%s %s" widget path
                    NoteBook $path
                    set containerId [winfo parent $path]
                    ShowMessage debug info "containerId $containerId" ok
                    pack $path -fill both -expand yes
                }
                page {
                    #puts $stream "page $notebook $page $pagecaption"
                    scan $line "%s %s %s %s" widget notebook pageId pagecaption
                    #ShowMessage debug info "$widget $notebook $pageId $pagecaption" ok
                    $notebook insert end $pageId -text $pagecaption
                    [$notebook getframe $pageId] configure -highlightcolor black  -highlightthickness 1
                    bind [$notebook getframe $pageId] <Button-1> "::RunEnv::SetCurrentContainer %W $pageId"
                    bind [$notebook getframe $pageId] <Button-3> \
                            "::RunEnv::SetCurrentContainer %W &pageId; tk_popup .pageContextMenu %X %Y"
                    
                }
                default {
                    # puts $stream "Unhandled Notebook page child: $child"
                }
            }
                    }
        close $stream
    }
}

proc RunEnv::LoadContainer {stream line} {
    #gets $stream helperTitle
    #set winId [NewHelperWindow $helperId [RestoreCrs $helperTitle]]
    #gets $stream geometry
    #wm geometry $winId $geometry
    #gets $stream oldStatus
    #set helperTable($winId,status) [RestoreCrs $oldStatus]
    #${helperId}::Restore $winId
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
                
                set allChildren [::RunEnv::GetChildren $dp0]; # shd b $dp0
                set allDisplaynotebooks [::RunEnv::GetWidgetsWithName $allChildren notebook]
                
                set sizeSmallestnotebook 1e32
                foreach notebook $allDisplaynotebooks {
                    set sizenotebook [llength [$notebook pages]]
                    if { $sizenotebook < $sizeSmallestnotebook} then {
                        set sizeSmallestnotebook $sizenotebook
                        set smallestnotebook $notebook
                    }
                }
                # build a list of current page names in all notebooks
                set pagenames {}
                foreach notebook $allDisplaynotebooks {
                    if {[llength [$notebook pages]] > 0 } {
                        set pages [$notebook pages]
                        foreach page $pages {
                            lappend pagenames [$notebook itemcget $page -text]
                        }
                    }
                }
                
                if {[lsearch -exact $pagenames $helperTitle] > -1} then {
                    set i 2
                    while {[lsearch -exact $pagenames $helperTitle/$i] > -1} {
                        incr i
                    }
                    set title $helperTitle/$i
                } else {
                    set title $helperTitle
                }
                
                #ShowMessage debug info [::RunEnv::MainNotebookEmptyPage] ok
                # todo deal with toolbar
                set EmptyPage [::RunEnv::MainNotebookEmptyPage]
                if {$EmptyPage==-1} {
                    $dp0.notebook insert end  helper$index -text $title; # todo
                    set frameid [$dp0.notebook getframe helper$index].container
                    set page helper$index
                } else  {
                    set frameid [$dp0.notebook getframe $EmptyPage].container
                    $dp0.notebook itemconfigure $EmptyPage -text $title
                    set page $EmptyPage
                }
                pack [frame $frameid] -fill both -expand true
                #ShowMessage debug info "winId $frameid" ok
                set winId $frameid
                $dp0.notebook raise $page
                set helperTable($frameid) $winId
                set helperTable($winId,frameid) $frameid
            }
    bind $winId <Destroy>  "RunEnv::OnDestroyHelper $winId"
    set helperTable($helperTitle) $winId
    set helperTable($winId,whichHelper) $helperId
    
    return $winId
}

proc RunEnv::MainNotebookEmptyPage {} {
    variable dp0
    foreach page [$dp0.notebook pages] {
        if {![winfo exists [$dp0.notebook getframe $page].container] & \
                    ![winfo exists [$dp0.notebook getframe $page].panedwindow]} {
            return $page
        }
    }
    return -1
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
