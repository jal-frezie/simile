# Support for the Model Run Environment moved to a seperate source file mre.tcl
# this file must source the mre.tcl file and MakeMRE is called from proc ModelWindow
# Jonathan Massheder

# $Log: mre.tcl,v $
# Revision 1.2  2002/05/30 17:20:29  jmm
# Added Parameters ( "Modify file parameters" ) to File menu as this was missing
#
# Revision 1.35  2002-05-16 15:12:21+01  jmm
# Mods my Jasper: Because of quirky behaviour under linux
#
# Revision 1.33  2002-05-09 15:00:51+01  jmm
# Fixed problem opening more than one Model Explorer (Variable Lister) previous one(s) is(are) destroyed.
# Raise first remaing page in a notebook after deleting a page
#
# Revision 1.32  2002-05-09 11:36:13+01  jmm
# Changed PanedWindow sizes
# Stop Notebook Page being deleted twice
# Problem creating ModelInspector more than once

# Revision 1.31  2002-05-09 11:36:13+01  jmm
# ClearDisplays and KillDisplays -- new procs - called from menu so menu now works
# New toolbar button "New" to KillDisplays
# NewMREHelperWindow now call wm title so save/restore can find a title
#
# Revision 1.30  2002-05-08 12:31:33+01  jmm
# Close menu item and X button call KillHelpers and destroy .mre - hope this fixes the close bugs
# CreateDisplayPageContextMenu is no longer called in create so no bug with creating it twice.
#
# Revision 1.29  2002-05-03 18:56:20+01  jmm
# Fixed finding notebook (tabset) page to a helper is displayed in.
#
# Revision 1.28  2002-05-03 10:24:51+01  jmm
# Using BWidgets Notebook instead of BLT::tabset -- no jump up to large window though
#
# Revision 1.26  2002-04-29 19:09:26+01  jmm
# Back to version 1.24
#
# Revision 1.24  2002-04-29 14:57:51+01  jmm
# put if and expr expresions in curly brackets for efficiency (and to stop procheck complaining about it).
#

# Load/Save config -- need menu called procs to SaveState/GetState

namespace eval RunEnv {
    
    package require BWidget
    namespace import ::BWidget::*
    
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
        {open.gif "Load a configuation of displays" LoadView}
        {save.gif "Save the display configuation" SaveView }
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
    variable runControlFrame
    variable sliderControlFrame;
    variable variableListFrame;
    variable ::RunEnv::mainframe
    variable explorerPane
    variable dp0;    # display pane
    variable toolbarItems; # list of toolbar items
    variable width 
    variable height
    
    if {![winfo exists .mre]} then {
        #    tk_messageBox -message MakeMRE -type ok
        toplevel .mre -width 200m -height 150m
        wm title .mre "Run-Time Environment - Simile"
        # Menu description
         set descmenu {
            "&File" all file 0 {
                {command "&Load configuration..." {} "Load a configuation of displays" \
                            {Ctrl-O} -command {LoadView} }
                {command "&Save configuration..." {} "Save a configuation of displays" \
                            {Crtl-S} -command {SaveView} }
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
            $bbox add -image [image create photo  -file "../images/Toolbar/$gif"] \
                    -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 -padx 1 -pady 1 \
                    -helptext $helptext -command $command
        }
        pack $bbox -side left -anchor w

        # load the display helpers
        set oldDir [pwd]
        cd ../IOTools; #Displays todo
        [$mainframe getmenu add] delete 0
        AddHelperSublist [$mainframe getmenu add ] "Add" 0 true
        cd $oldDir
                
        # Add a PanedWindow for the hierrachical/run control view and main display window
        set mainpw [PanedWindow [$mainframe getframe].mainpw  -side top]
        set controlPane [$mainpw add -weight 5]; # add a pane for the hierrachical view/run control
        set dp0 [$mainpw add -weight 9];             # add a pane for the display pane
        
        # Add a PanedWindow to split the hier/contol pane into hierrachical pane and control pane
        set hiercontrolpw [PanedWindow $controlPane.pw -side right]
        set runcontrolpane [$hiercontrolpw add -weight 1]; # add a pane for the runcontrol
        set explorerPane [$hiercontrolpw add -weight 4]; # add a pane for the hierrachical view
        
        # Added notebook
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
        pack $variableListFrame $sliderControlFrame $outputFrame
        $explorerPane.notebook raise Explorer
        
        NoteBook $runcontrolpane.notebook
        $runcontrolpane.notebook insert end "RunControl" -text "Run Control"
        set runControlFrame  [frame [$runcontrolpane.notebook getframe RunControl].variables]
        pack $runcontrolpane.notebook -fill both -expand yes
        pack $runControlFrame
        $runcontrolpane.notebook raise RunControl

        # Add a PanedWindow to split the main display window
        set pwside(dpw0) top
        #        set dpw0 [PanedWindow $dp0.pw -side $pwside(dpw0)]; # vertical split first
        set dpw0 [AddPanedWindow $dp0 $pwside(dpw0)]; # vertical split first
        set dp0_1 [$dpw0 add -weight 1]; # add a pane for the
        set dp0_2 [$dpw0 add -weight 1]; # add a pane for the
        
        set pwside(dpw0_1) right
        set dpw0_1 [PanedWindow $dp0_1.pw -side $pwside(dpw0_1)]
        # make a proc to do this
        set dp0_1_1 [$dpw0_1 add -weight 1]; # add a pane for the
        NoteBook $dp0_1_1.notebook
        
        set dp0_1_2 [$dpw0_1 add -weight 1]; # add a pane for the
        NoteBook $dp0_1_2.notebook
        pack $dp0_1_1.notebook $dp0_1_2.notebook -fill both -expand yes
        
        set pwside(dpw0_2) right
        set dpw0_2 [PanedWindow $dp0_2.pw -side $pwside(dpw0_2)]
        set dp0_2_1 [$dpw0_2 add -weight 1]; # add a pane for the
        NoteBook $dp0_2_1.notebook
        
        set dp0_2_2 [$dpw0_2 add -weight 1]; # add a
        NoteBook $dp0_2_2.notebook
        pack $dp0_2_1.notebook $dp0_2_2.notebook -fill both -expand yes
        
        
        pack $mainframe -fill both -expand yes
        pack $mainpw -fill both -expand yes
        pack $hiercontrolpw -fill both -expand yes
        
        pack $dpw0 -fill both -expand yes
        pack $dpw0_1 -fill both -expand yes
        pack $dpw0_2 -fill both -expand yes
        
#        CreateDisplayPageContextMenu
        
        # run control is automatically created when model is run
        # input slider helper is automatically created if needed when model is run
        
        # create a model variable list/treeview helper
        #        CreateHelperWindow $helperTable(VariableList) "Variables"
        # $helperTable(VariableList)::initialize [toplevel .helper[newInt] -use [winfo id $variableListFrame]]
        
#        wm geometry .mre ${data(width)}x${data(height)}; # should be changeable, option? todo
        wm geometry .mre ${width}x${height}; # should be changeable, option? todo
        wm protocol .mre WM_DELETE_WINDOW RunEnv::Destroy
    } ; # if .mre exists
    return .mre
}

proc RunEnv::Destroy {} {
    global helperTable
    foreach helper [array name helperTable *,whichHelper] {
        scan $helper {%[^,]} winId
        bind $winId <Destroy> {}; # so the helper notebook pages are not destroyed 2ce - bomb!
    }
    destroy .pageContextMenu
    KillHelpers
    destroy .mre
}

proc RunEnv::AddPanedWindow { parent side} {
    # could have some winfo code to allow more than 1 PanedWindow in a parent
    return [PanedWindow ${parent}.pw -side $side]
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
    set notebookPage [FindHelperPage $winId]
    set notebook [lindex $notebookPage 0]
    if {![string match "" $notebook]} {
        set page [lindex $notebookPage 1]
        while {[winfo exists $winId]} { after 10 }; # don't delete until the helper has gone
        $notebook delete $page 1; # delete the page and associated frame
        if {[llength [$notebook pages]] > 0} {
            $notebook raise [lindex [$notebook pages] 0]
        }
    }
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
proc RunEnv::AddHelperSublist {fm title ct root} {
    global custom helperTable
    
    set nct 0
    # do not make a cascade menu for the helper root directory
    if {$root} {
        set m $fm
    } else  {
        $fm insert $ct cascade -label $title... -menu $fm.sub$ct
        set m [menu $fm.sub$ct -tearoff 0]
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
                unset keyValue
                incr i
            }
        }
    }
    foreach subDir [glob -nocomplain *] {
        if {[file isdirectory $subDir]} {
            cd $subDir
            AddHelperSublist $m $subDir $nct false
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

proc NewMreHelperWindow {helperId helperTitle} {
    global helperTable
    variable ::RunEnv::dp0;    # display pane
    
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
              $smallestnotebook insert end  helper$index -text $title
              set frameid [$smallestnotebook getframe helper$index].container    
              frame $frameid -container true
              pack $frameid -fill both -expand yes
              toplevel $winId -use [winfo id $frameid]
              wm title $winId $helperTitle
              
              $smallestnotebook raise helper$index
        }
    bind $winId <Destroy>  "RunEnv::OnDestroyHelper $winId"
    return $winId
}

# A top level window to contain the helpers
# overrides mre.tcl Makemre
proc Makemre { ModelWin } {
    return [RunEnv::Create $ModelWin]
}




