# Support for the Model Run Environment moved to a seperate source file mre.tcl
# this file must source the mre.tcl file and MakeMRE is called from proc ModelWindow
# Jonathan Massheder

# todo
# page and panes must have automatic ids - program can't control pages and panes by id but by index
# Use display page unique id code for pages and panes
# Make proc to access page and pane by index (index to id, use list and lindex)

namespace eval RunEnv {
    
#    package require -exact BWidget 1.2.1
    #namespace import ::BWidget::*
    
    #    variable notebook
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
    set toolbarItems {
        {new.gif "New display configuration" RunEnv::KillDisplays}
        {open.gif "Load a configuation of displays" RunEnv::LoadView}
        {save.gif "Save the display configuation" RunEnv::SaveView }
        {graph.gif "Plotter"\
                    "CreateHelperWindow plotter1.25 {Plotter}"}
        {table.gif "Data table"\
                    "CreateHelperWindow tabular11508 {Data table}" }
        {mainwin.gif "Go to Model Window" "RaiseModelWindow"}
    }
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
    variable ::RunEnv::mainframe
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
        
        $explorerPane.notebook insert end "Output" -text "Output"
        set outputFrame \
                [frame [$explorerPane.notebook getframe "Output"].sliders -container true]
        pack $variableListFrame $sliderControlFrame $outputFrame  -fill both -expand yes
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
        
        #        CreateDisplayPageContextMenu
        
        # Model variable explorer is created automatically elsewhere
        # run control is automatically created when model is run
        # input slider helper is automatically created if needed when model is run
        
        wm geometry .mre ${width}x${height}; # should be changeable, option? todo
        wm protocol .mre WM_DELETE_WINDOW RunEnv::Destroy
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
    NoteBook $containerId.notebook
    set pageId [UniqueId page [$containerId.notebook pages]]
    $containerId.notebook insert end $pageId -text "1" \
            -createcmd  "::RunEnv::AddNewPageToolBar [$containerId.notebook getframe $pageId] $pageId"
    set pageId [UniqueId page [$containerId.notebook pages]]
    $containerId.notebook insert end $pageId -text "2"\
            -createcmd  "::RunEnv::AddNewPageToolBar [$containerId.notebook getframe $pageId] $pageId"
    set pageId [UniqueId page [$containerId.notebook pages]]
    $containerId.notebook insert end $pageId -text "3"\
            -createcmd  "::RunEnv::AddNewPageToolBar [$containerId.notebook getframe $pageId] $pageId"
    set pageId [UniqueId page [$containerId.notebook pages]]
    $containerId.notebook insert end $pageId -text "4" \
            -createcmd  "::RunEnv::AddNewPageToolBar [$containerId.notebook getframe $pageId] $pageId"
    $containerId.notebook raise [lindex [$containerId.notebook pages] 0]
    pack $containerId.notebook -fill both -expand yes
}

proc RunEnv::AddNotebookPage {containerId} {
    set ParentContainer [FindParentpanedwindowOrNotebook $containerId]
    if {[string match notebook [winfo name $ParentContainer]]} {
        set pageId [UniqueId page [$ParentContainer pages]]
        set pageIndex [expr {[llength [$ParentContainer pages]]+1}]
        $ParentContainer insert end $pageId -text $pageIndex \
                -createcmd  "::RunEnv::AddNewPageToolBar [$ParentContainer getframe $pageId] $pageId"
    } else  {
        AddNotebookPage $ParentContainer
    }
}

proc RunEnv::AddNewPageToolBar {containerId page} {
    #    pack [frame $containerId.f] -fill both
    #    pack [frame $containerId.f.tb -relief raised] -pady 3 -padx 3
    variable PageToolbarItems
    set PageToolbarItems [list \
            [list splithoriz.gif "Split page horizontally" "::RunEnv::SplitPage $containerId vertical" ] \
            [list splitvert.gif "Split page vertically" "::RunEnv::SplitPage $containerId horizontal"] \
            [list NoteBookPage.gif "Add notebook page" "RunEnv::AddNotebookPage $containerId"] \
            [list NoteBook.gif "Add notebook" "RunEnv::AddNotebook $containerId"] \
            [list graph.gif "Create plotter here" "::RunEnv::CreateHelperInWindow $containerId plotter1.25 {Plotter}"] \
            [list table.gif "Create plotter here" "::RunEnv::CreateHelperInWindow $containerId tabular11509 {Table}"] \
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

proc ::RunEnv::AllDisplaysPopup {containerId x y} {
    
    variable CurrentContainer $containerId
    tk_popup .helpPopup $x $y
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
    ShowMessage debug info "DeleteHelperContainer: $containerId children: $children;\
            parentType $parentType" ok
    if {[lsearch $children *.container]>-1} {
        kill_helper_window $helperTable($containerId.container)
        destroy $containerId.container
    } else {
        switch $parentType {
            notebook {DeleteNotebookPage $parentPath $page}
            panedwindow {$parentPath forget $containerId; destroy $containerId}
        }
    }
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

proc RunEnv::SplitPage {containerId orientation} {
    
    set parentPath [FindParentpanedwindowOrNotebook $containerId]
    if {[string match notebook [winfo name $parentPath]]} {
        Addpanedwindow $containerId $orientation
    } elseif {(![string match $orientation [$parentPath cget -orient]])} {
        Addpanedwindow $containerId $orientation
    } else  {
        set n [expr {[llength [$parentPath panes]]+1}]
        frame $parentPath.pane$n
        AddNewPageToolBar $parentPath.pane$n 0
        $parentPath add $parentPath.pane$n
    }
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
    #    ShowMessage debug info "$containerId [FindParentpanedwindowOrNotebook $containerId]" ok
    #    ShowMessage debug info "FindParentWidth [FindParentWidth $containerId]; height [FindParentHeight $containerId]" ok
    set pwidth  [FindParentWidth $containerId]
    set pheight [FindParentHeight $containerId]
    #    ShowMessage debug info "$pwidth $pheight" ok
    destroy $containerId.bbframe
    panedwindow $containerId.panedwindow -orient $orientation
    pack $containerId.panedwindow -expand yes -fill both
    if {[string match $orientation vertical]} {
        set width [expr {$pwidth}]
        set height [expr {$pheight/2}]
    } else  {
        set width [expr {$pwidth/2}]
        set height [expr {$pheight}]
    }
    frame $containerId.panedwindow.pane0
    frame $containerId.panedwindow.pane1
    AddNewPageToolBar $containerId.panedwindow.pane0 0
    AddNewPageToolBar $containerId.panedwindow.pane1 0
    $containerId.panedwindow add $containerId.panedwindow.pane0 $containerId.panedwindow.pane1 \
            -width $width -height $height
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
                        -command [list ::RunEnv::CreateHelperInWindowCurrentContainer $keyValue $action]
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
        $m add command -label "Add Display" -command ""
        $m add command -label "Remove Display" -command ""
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
    
    destroy $containerId.bbframe
    destroy $containerId.abovebbox
    destroy $containerId.belowbbox
    set frameid $containerId.container
    frame $frameid -container true
    pack $frameid -fill both -expand yes
    set index [newInt]
    set winId .helper$index
    toplevel $winId -use [winfo id $frameid]
    set helperTable($helperTitle) $winId
    set helperTable($winId,whichHelper) $helperId
    
    ${helperId}::initialize $winId
    wm title $winId $helperTitle
    bind $winId <Destroy>  "RunEnv::OnDestroyHelper $winId"
    
    #append page toolbar, seperator first
    pack [Separator $winId.bbframe.sep_page -orient vertical] -side left -fill y -padx 4 -anchor w
    ButtonBox $winId.bbframe.pageButtonBox -spacing 0 -padx 1 -pady 1
    foreach item $PageToolbarItems {
        set gif [lindex $item 0 ]
        set helptext [lindex $item 1]
        set command [lindex $item 2]
        $winId.bbframe.pageButtonBox add -image [image create photo  -file "../Images/Toolbar/$gif"] \
                -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 -padx 1 -pady 1 \
                -helptext $helptext -command $command
    }
    pack $winId.bbframe.pageButtonBox -side left
    set helperTable($frameid) $winId
    set helperTable($winId,frameid) $frameid
    ShowMessage debug info "NewHelper: $helperTable($frameid)" ok
}

proc RunEnv::CreateHelperInWindowCurrentContainer {helperId helperTitle} {
    variable CurrentContainer
    CreateHelperInWindow $CurrentContainer $helperId $helperTitle
}

proc RunEnv::SaveView {} {
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

proc RunEnv::LoadView {} {
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
    #tk_messageBox -message NewMreHelperWindow -type ok
    set index [newInt]
    set winId .helper$index
    set helperTable($helperTitle) $winId
    set helperTable($winId,whichHelper) $helperId
    
    # put the RunControl in its own pane
    
    ## Mods my Jasper: Because of quirky behaviour under linux, the standard tools
    ## must each get a new frame (bag) whenever they are rebuilt
    switch $helperId \
            $helperTable(RunControl) {
                set bag $RunEnv::runControlFrame.bag
                if {[winfo exists $bag]} {
                    destroy $bag
                }
        pack [frame $bag -container true]
        toplevel $winId -use [winfo id $bag]
    } \
            $helperTable(SliderControl) {
                set bag $RunEnv::sliderControlFrame.bag
                if {[winfo exists $bag]} {
                    destroy $bag
                }
        pack [frame $bag -container true] -fill both -expand true
        toplevel $winId -use [winfo id $bag]
    } \
            $helperTable(ErrorDisplay) {
                toplevel $winId ; #put in own window
            } \
                    $helperTable(VariableList) {
                        set bag $RunEnv::variableListFrame.bag
                        if {[winfo exists $bag]} {
                            destroy $bag
                        }
        pack [frame $bag -container true] -fill both -expand true
        toplevel $winId -use [winfo id $bag]
        wm title $winId $helperTitle
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
            $dp0.notebook insert end  helper$index -text $title
            set frameid [$dp0.notebook getframe helper$index].container
            set page helper$index
        } else  {
            set frameid [$dp0.notebook getframe $EmptyPage].container
            $dp0.notebook itemconfigure $EmptyPage -text $title
            set page $EmptyPage
        }
        frame $frameid -container true
        pack $frameid -fill both -expand yes
        toplevel $winId -use [winfo id $frameid]
        wm title $winId $helperTitle
        
        $dp0.notebook raise $page
        set helperTable($frameid) $winId
        set helperTable($winId,frameid) $frameid
    }
    bind $winId <Destroy>  "RunEnv::OnDestroyHelper $winId"
    
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
