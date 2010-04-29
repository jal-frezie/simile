# Support for the Model Run Environment moved to a seperate source file mre.tcl
# this file must source the mre.tcl file and MakeMRE is called from proc ModelWindow
# Jonathan Massheder


# helpers must bind $canvas <Configure> resize $canvas

namespace eval RunEnv {
    global helperTable

    variable status
    variable prgtext
    variable prgindic
    variable runControlFrame; # the widget id of the frame to hold the run control
    variable sliderControlFrame;
    variable variableListFrame;
    variable explorerPane
    variable runControlWindId
    variable dp0;    # identifies top-level display window
    variable toolbars; # list of toolbar items
    variable CurrentContainer
    
    variable width 780; # window width  # should be an option
    variable height 580; #window height  # should be an option
    
    # list of toolbar items. The top level list contains separated lists of toolbuttons:
    # each toolbutton specification includes:
    # gif in $similepath/images/toolbar
    # pop-up message
    # command.
    # A separator is placed between the
    #    package require BWidget

set toolbars [list \
   [list \
	[list new.gif "New display configuration" RunEnv::InitializeDisplays] \
	[list open.gif "Load a configuration of displays" RunEnv::LoadView] \
	[list save.gif "Save the display configuration" {RunEnv::SaveView 0}] ]\
   [list \
	[list copyc.gif "Copy display" ::RunEnv::CopyHelper] \
        [list cut.gif "Cut display" ::RunEnv::CutHelper] \
        [list paste.gif "Paste display" ::RunEnv::PasteHelper] \
        [list delete.gif "Remove display or container" "::RunEnv::DeleteHelperCurrentContainer" ] \
        [list print.gif "Print display" ::RunEnv::PrintCurrentContainer]] \
   [list \
        [list splithoriz.gif "Split page horizontally" "::RunEnv::SplitCurrentContainer vertical" ] \
        [list splitvert.gif "Split page vertically" "::RunEnv::SplitCurrentContainer horizontal"]] \
   [list \
        [list notebookpage.gif "Add notebook page" "RunEnv::AddNotebookPageToCurrentContainer"] \
        [list notebook.gif "Add notebook" "RunEnv::AddNotebookToCurrentContainer"]] \
   [list \
        [list graph.gif "Create plotter" "::RunEnv::InsertHelperWindow plotter1_dot_25 {}"] \
        [list table.gif "Create table" "::RunEnv::InsertHelperWindow tabular11510 {}"] \
        [list slider.gif "Create input sliders" "::RunEnv::InsertHelperWindow slide139 {}"] \
        [list display.gif "Choose display to create" "::RunEnv::AllDisplaysPopupCurrentContainer"]] \
   [list \
        [list clear.gif "Clear all displays" "ClearView"]]\
   [list \
	[list property.gif "Modify file parameters" ::RunEnv::InvokeFPDialogue]] \
   [list \
        [list mainwin.gif "Go to Model Window" "::RunEnv::RaiseModelWindow"]] \
		 ]
    
    # A top level window to contain the helpers
    proc Create { node } {
        global helperTable tcl_platform runHow
        variable runControlFrame
        variable sliderControlFrame;
        variable variableListFrame;
        variable explorerPane
        variable dp0;    # display pane
        variable dp0s;    # display panes for all models
        variable toolbars; # list of toolbar items
        variable width
        variable height
        variable currentNode
        
        if {[info exists helperTable($node,whichRunEnv)]} {
            return $helperTable($node,whichRunEnv)
        } else {
            set mreId .mre[newInt]
            set helperTable($node,whichRunEnv) $mreId
            CreateDisplayPageContextMenu
            
            #tk_messageBox -message MakeMRE -type ok
            toplevel $mreId -width 200m -height 150m -menu ${mreId}top
# following is the answer to all those pesky bgerrors on stdout
#	    pack [button $mreId.reveal -text "Reveal all" -command {puts $errorInfo}]
            wm title $mreId [format $::msgs(exec_title) [GetExecTitle $node]]
            set currentNode $node
            bind $mreId <FocusIn> [namespace code "InMreFor $node"]
            set descmenu {
                "File" all file 0 {
                    {command "New configuration"    {} "Remove all display configuration" {} -command {::RunEnv::InitializeDisplays} }
                    {command "Load configuration..." {} "Load a configuration of displays" \
                                {} -command {::RunEnv::LoadView} }
                    {command "Save configuration" {} "Save configuration of displays" \
			 {} -command {::RunEnv::SaveView 0} }
                    {command "Save configuration as..." {} "Save configuration of displays as a new file" \
                                {} -command {::RunEnv::SaveView 1} }
                    
                    {separator}
                    {command "Print..." {} "Print display"  \
                                {} -command { ::RunEnv::PrintCurrentContainer } }
                    {command "Export PostScript..." {} "Export display as PostScript"  \
                                {} -command { ::RunEnv::ExportCurrentContainer } }
                    {separator}
                    {command "Parameters..." {} "View or modify file parameters"  \
                                {} -command { ::RunEnv::InvokeFPDialogue } }
                    {separator}
                    {command "Close"    {} "Close the Run Environment window" \
                                {} -command RunEnv::Destroy }
                }
                "Edit" all edit 0 {
                    {command "Copy"    {} "Copy display to clipboard" {} \
                                -command RunEnv::CopyHelper }
                    {command "Cut"    {} "Cut display to clipboard" {} \
                                -command RunEnv::CutHelper }
                    {command "Paste"    {} "Paste display from clipboard" {} \
                                -command ::RunEnv::PasteHelper }
                    {separator}
                    {command "Remove"    {} "Remove display or container" {} -command {::RunEnv::DeleteHelperCurrentContainer}}
                    {command "Clear all"    {} "Clear all saved data from displays" {} -command {ClearView} }
                }
                "Help" all help 0 {
                    {command "Contents..." {} "View the help file contents" {} -command ::RunEnv::ShowMreHelp}
                }
            }
            
#            set mainframe [MainFrame $mreId.mainframe -width 200m -height 150m \
#			       -menu         $descmenu \
#			       -textvariable RunEnv::status \
#			       -progressvar  RunEnv::prgindic]
#...err, what for?
#            $mainframe showstatusbar none
	    set mreMenu [$mreId cget -menu]
	    menu $mreMenu
	    foreach {header tags id tear spec} $descmenu {
		set sub [menu $mreMenu.$id -tearoff $tear]
		set pops {}
		foreach item $spec {
		    if {[llength $item]>1} {
			eval [list $sub add [lindex $item 0] \
				  -label [tr. [lindex $item 1]]] [lrange $item 5 end]
			lappend pops [tr. [lindex $item 3]]
		    } else {
			$sub add $item
			lappend pops {}
		    }
		}
		UnderlineUniquely $sub
		$mreMenu add cascade -label [tr. $header] -menu $sub
		MenuBindPopup $sub $pops
	    }
            set mainframe [GetFrame $mreId]
	    
            if [string match "Darwin" $tcl_platform(os)] {
		set dummy [$mreId cget -menu]
		set fm [menu $dummy.apple -tearoff 0]
		$fm add command -label "About Simile..." -command "ShowAbout $mreId"
		$fm add separator
		$dummy add cascade -menu $fm
	    }
	    
            set tb1  [::ttk::frame $mainframe.tbar -class Toolbar]
            # build the toolbar  from the toolbarItems list
            set tbnum 0
            foreach toolbar $toolbars {
                set i 0
                foreach item $toolbar {
                    set gif [lindex $item 0]
                    set helptext [lindex $item 1]
                    set command [lindex $item 2]
                    set newButton [::ttk::button $tb1.b$tbnum$i -style Toolbutton -image [image create photo  -file "../Images/Toolbar/$gif"] \
				       -command $command]
		    FixDisabledImgBug $newButton
                    pack $newButton -padx 1 -pady 1  -side left -anchor w
                    BindPopup $newButton [tr. $helptext]
                    incr i
                }
                pack $tb1 -side top -anchor w -fill x
                incr tbnum
                pack [ttk::separator $tb1.sep$tbnum -orient vertical] -side left -fill y -padx 4
            }
            
            #from runmodel.tcl AddHelperSublist
	    #            set mreMenu [winfo parent [$mainframe getmenu help]]
            $mreMenu insert 2 cascade -label [tr. "Add"] -menu .helpers.sub2
	    if {[info exists runHow(where)]} {
		$mreMenu insert 3 cascade -label [tr. "Window"] -menu .windowchoice
	    }
	    UnderlineUniquely $mreMenu

            # Add a PanedWindow for the hierrachical/run control view and main display window
            set mainpw [panedwindow $mainframe.mainpw  -orient horizontal]
            set controlPane [AddPane $mainpw.controlPane]; # made by runmodel.tcl AddHelperSublist
            set dp0 [AddPane $mainpw.mainDisplayPane]
            set dp0s($node) $dp0
            
            
            # Add a panedwindow to split the hier/contol pane into hierrachical pane and control pane
            set hiercontrolpw [panedwindow $controlPane.panedwindow -orient vertical]
            set runcontrolpane [AddPane $hiercontrolpw.runcontrolPane]
            set explorerPane [AddPane $hiercontrolpw.explorerPane]
            
            # Add notebook for controls, explorer etc
            set variableListFrame($node) [frame $explorerPane.variables]
            pack $variableListFrame($node) -fill both -expand yes
            set runControlFrame($node) [frame $runcontrolpane.variables]
            pack $runControlFrame($node) -fill both -expand yes
            
	    array unset helperTable $currentNode,keepSetup
# it was set by adding explorer etc panes but we do not want save dialogue here
	    InitializeDisplays
            
#            pack $mainframe -fill both -expand yes
            pack $mainpw -fill both -expand yes
            update ;# needed for sash place to work
	    $mainpw sash place 0 270 0; # must be wide enough (270ish) for the sliders
            
            pack $hiercontrolpw -fill both -expand yes
            
            # Model variable explorer is created automatically elsewhere
            # run control is automatically created when model is run
            # input slider helper is automatically created if needed when model is run
            
            wm geometry $mreId ${width}x${height}
            if {[string match unix $tcl_platform(platform)]} {
                wm iconbitmap $mreId @../Images/dribble.xbm
            }; # on Windows uses default icon set in Runmodel.tcl
            wm protocol $mreId WM_DELETE_WINDOW ::RunEnv::Destroy
            return $mreId
        } ; # if .mre exists
    }

    proc InMreFor {node} {
        variable currentNode
        variable CurrentContainer
        variable CurrentContainers
        variable dp0
        variable dp0s

        set currentNode $node
        SetNodeForHelper $node
# Problem with $CurrentContainers(node) not set for first use: ignore potential error
# ALD 28 Feb 2005 - not thoroughly tested; patching up MacVersion
# JAT 25 Apr 2006 - patch caused nasty in Tile 0.7.5 (and probably Mac too, check) - reversed to enable find of real bug
        set CurrentContainer $CurrentContainers($node)
        set dp0 $dp0s($node)
    }

    proc RaiseModelWindow {} {
	variable currentNode
	do_in_editor RaiseModelWindow $currentNode
    }

    proc InvokeFPDialogue {} {
        global helperTable runState
        variable currentNode
        MessFileParams $currentNode $helperTable($currentNode,whichRunEnv)
    }
    
    proc AddNotebook {containerId} {
        destroy $containerId.abovebox
        destroy $containerId.bbox
        destroy $containerId.belowbox
        
        ::ttk::notebook $containerId.notebook
	bind $containerId.notebook <<NotebookTabChanged>> \
	    [list ::RunEnv::PageRaiseCmd $containerId.notebook]
        
        for  {set i 1} {$i<=4} {incr i} {
	    set pane$i [AddNotebookPage $containerId.notebook]
        }
        
        bind $containerId.notebook <Double-1> "::RunEnv::EditTabLabel %W"
        bind $containerId.notebook <Button-3> "::RunEnv::EditTabLabel %W"
        
        $containerId.notebook select [lindex [$containerId.notebook tabs] 0]
        pack $containerId.notebook -fill both -expand yes
	return $pane1
    }
    
    proc EditTabLabel { notebook } {
	global helperTable
        variable TabEditText
	variable currentNode
        set TabEditText [$notebook tab current -text]
        #based on equationRight
        #ShowMess debug info "TabRight tabId $tabId; label [$notebook itemcget $tabId -text]" ok
        catch {destroy .notebookTabTextEdit}
        Dialog .notebookTabTextEdit -parent [winfo toplevel $notebook] \
		-cancel 1 -title {Edit tab label} -transient true
        .notebookTabTextEdit add -text OK; # draw result 0
        .notebookTabTextEdit add -text Cancel; # draw result 1
        set ebox [entry .notebookTabTextEdit.ebox -width 20 -textvariable ::RunEnv::TabEditText]
        pack $ebox -pady 10 -padx 10
        bind $ebox <Return> {.notebookTabTextEdit invoke 0}
        $ebox selection range 0 end
        focus $ebox
	if {[.notebookTabTextEdit draw] == 0} then {
            # OK button selected
            $notebook tab current -text $TabEditText
        }
    }
    
    proc PageRaiseCmd {notebook} {
	if {[llength [$notebook tabs]]} {
            SetLeafCurrent [$notebook select]
        }
    }
    
    proc AddNotebookToCurrentContainer {} {
        variable CurrentContainer

        SetCurrentContainer [AddNotebook $CurrentContainer]
    }
    
    proc AddNotebookPage {containerId} {
	set ParentContainer [FindParentNotebook $containerId]
	set pageId [UniqueId $ParentContainer.fpage [$ParentContainer tabs]]
	set pageIndex [expr {[llength [$ParentContainer tabs]]+1}]
	set newContainer [frame $pageId]
	$ParentContainer add $newContainer \
	    -text [format [tr. "Page %1\$d"] $pageIndex]
	set parentPath [Addpanedwindow $newContainer vertical]
	$ParentContainer select $newContainer
	return [lindex [$parentPath panes] 0]
    }
    
    proc AddNotebookPageToCurrentContainer {} {
        variable CurrentContainer
        AddNotebookPage $CurrentContainer
    }
    
    proc AllDisplaysPopupCurrentContainer {} {
        # .helpers.sub2 made by runmodel.tcl AddHelperSublist
        variable CurrentContainer
        set mre [winfo toplevel $CurrentContainer]
        tk_popup .helpers.sub2 [winfo pointerx $mre] [winfo pointery $mre]
    }
    
    proc PrintCurrentContainer {} {
        global helperTable
        variable CurrentContainer

	set inst $helperTable($CurrentContainer.container,whichInstance)
	$inst Print
    }
    
    proc ExportCurrentContainer {} {
        global helperTable
        variable CurrentContainer
	variable currentNode
        
	set inst $helperTable($CurrentContainer.container,whichInstance)
	PostScrog [$inst GetCanvas] $currentNode
    }
    
    proc CopyHelper {} {
        global helperTable simtmpdir
        variable CurrentContainer

	set inst $helperTable($CurrentContainer.container,whichInstance)
# need to test, still called from cut if not available
	if {![catch {$inst info function CopyToClipboard}]} {
	    $inst CopyToClipboard
	}

	set copyfile $simtmpdir/mrecopy.txts
# If helper includes a PrepareSaveString command, call it
	$inst PrepareSaveString
	set stream [NetOpen $copyfile w]
	puts $stream [namespace tail [$inst info class]]
	puts $stream [StripCrs [$inst cget -State]]
	close $stream
    }
    
    proc CutHelper {} {
        CopyHelper
        DeleteHelperCurrentContainer
    }
    
    proc PasteHelper {} {
        global simtmpdir
        
        set copyfile $simtmpdir/mrecopy.txts
        if {[file exists $copyfile]} {
            set stream [NetOpen $copyfile r]
	    gets $stream oldClass
            gets $stream oldStatus
	    InsertHelperWindow $oldClass [RestoreCrs $oldStatus]
            close $stream
        }
    }

    proc InsertHelperWindow {class status} {
	CreateHelperWindow $class {} $status
	PreserveSetup 1
    }
    
    proc DeleteHelperContainer {containerId page} {
        global helperTable
        # container is the frame a helper would be displayed in
        # a parent is the notebook or panedwindow the container belongs to
        #ShowMess debug info "container $containerId; page $page; \
        #            parent [::RunEnv::FindParentpanedwindowOrNotebook $containerId]" ok
        if {![winfo exists $containerId]} {
            return
        }
        #ShowMess debug info "DeleteHelperContainer: $containerId\n \
        #        children $children\n \
        #        parentType $parentType" ok; ##################
	set children [winfo children $containerId]
        if {[lsearch $children *.container]>-1} {
	    set oldObj $helperTable($containerId.container,whichInstance)
	    itcl::delete object $oldObj ;# this deletes widget
        } else {
	    set parentPath [FindParentpanedwindowOrNotebook $containerId]
	    set parentType [winfo class $parentPath]
            switch $parentType {
                Notebook {DeleteNotebookPage $parentPath $page}
                Panedwindow {DeletePane $parentPath $containerId}
            }
        }
	PreserveSetup 1
        if {[winfo exists $containerId]} {SetCurrentContainer $containerId }
    }
    
    proc DeleteHelperCurrentContainer {} {
        variable CurrentContainer
        DeleteHelperContainer $CurrentContainer {}
    }
    
    proc DeleteNotebookPage {notebook page} {
        set pages [$notebook tabs]
        set page [$notebook index current]
        #puts "DeleteNotebookPage  $notebook; $page\n \
        #            page $page; n pages: $n; \n \
        #            parent [winfo parent $notebook]"
	destroy [lindex $pages $page]
	update
        set pages [$notebook tabs]
        set n [llength $pages]
        #ShowMess debug info "DeleteNotebookPage after delete page pages $n" ok; #########
        if {$n==0} {
            set containerId [winfo parent $notebook]
            #ShowMess debug info "DeleteNotebookPage n==0; new container $containerId" ok; ########
            destroy $notebook
            SetCurrentContainer $containerId
            #ShowMess debug info \
            "DeleteNotebookPage  destroy notebook\n \
                    new container $containerId" ok; ########
        } else  {
            #ShowMess debug info "DeleteNotebookPage default" ok
	    set pages [$notebook tabs]
	    set n [llength $pages]
            if {$page >= $n} {
		set newSeln [expr {$n-1}]
	    } else {
		set newSeln $page
	    }
	    $notebook select $newSeln
	    PageRaiseCmd $notebook
        }
    }

    proc AddPane {paneId {containerId {}}} {
	frame $paneId -highlightcolor black -highlightthickness 1
	bind $paneId <Button-1> "+::RunEnv::SetCurrentContainer %W"
	bind $paneId <Button-3> \
	    "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
	set parentPath [winfo parent $paneId]
	if {[string length $containerId]} {
	    $parentPath add $paneId -after $containerId
	} else {
	    $parentPath add $paneId ;# at end
	}
	PreserveSetup 1
	return $paneId
    }
    
    proc DeletePane {parentPath containerId} {
        #ShowMess debug info "DeletePane\n parentPath $parentPath\n \
        #        containerId $containerId\n \
        #        panes [$parentPath panes]" ok;
        $parentPath forget $containerId
        destroy $containerId
	set parentPage [winfo parent $parentPath]	
        if {[llength [$parentPath panes]] > 0} {
	    SetLeafCurrent [lindex [$parentPath panes] 0]
        } else {
            # all remaining panedwindows are in a notebook parent
            set parentNoteBook [winfo parent $parentPage]
            #ShowMess debug info "DeletePane page\n parentPath $parentPath\n \
            #                parentPage $parentPage; parentNoteBook $parentNoteBook\n \
            #                pages [$parentNoteBook tabs]\n \
            #                current page [$parentNoteBook tab current]" ok;
            destroy $parentPath
            if {[string match TNotebook [winfo class $parentNoteBook]]} {
                DeleteNotebookPage $parentNoteBook [$parentNoteBook tab current]; #current page
            }
        }
    }
    
    proc SplitPage {containerId orientation} {
	variable dp0

        set parentPath [winfo parent $containerId]
	set pwidth  [winfo width $containerId]
	set pheight [winfo height $containerId]
#puts "old pane ${pwidth}x$pheight"
        if {![string match $orientation [$parentPath cget -orient]] || \
		[string equal $dp0 $containerId]} {
#ShowMess debug info "SplitPage diff orientn container $containerId $orientation\n\
#parentPath $parentPath" ok;
	    $containerId configure -highlightthickness 0 ;# no longer a leaf
	    set parentPath [Addpanedwindow $containerId $orientation]
	    set containerId [lindex [$parentPath panes] 0]
	    update idletasks ;# so splitting new pane works
        }
            # now it's a pane to be split in the same orientation
            # add a new pane
	set paneId [UniqueId $parentPath.pane [$parentPath panes]]
	AddPane $paneId $containerId
	###############################################################################
	set sash [expr {[lsearch [$parentPath panes] $containerId]}]
	set sashCoord [$parentPath sash coord $sash]
	set contx [winfo x $containerId]
	set conty [winfo y $containerId]
	# new settings
	switch $orientation {
	    vertical {
		set height [expr {int(0.9*$pheight/2)}]
		set sashx [lindex $sashCoord 0]
		set sashy [expr {$conty+$height}]
	    }
	    horizontal {
		set width [expr {int(0.9*$pwidth/2)}]
		set sashx [expr {$contx+$width}]
		set sashy [lindex $sashCoord 1]
	    }
	}
            ###############################################################################
            
#puts "$parentPath sash place $sash $sashx $sashy"
	update idletasks ;# needed for sash place to work
	$parentPath sash place $sash $sashx $sashy
	SetCurrentContainer $paneId
    }
    
    proc SplitCurrentContainer {orientation} {
        variable CurrentContainer
        SplitPage $CurrentContainer $orientation
    }
    
    proc FindParentpanedwindowOrNotebook {containerId} {
        # Added two more [winfo parent]s to accommodate Tile notebook layout
	# -- cant see why cos it recurses anyway
        set parentPath [winfo parent $containerId]
        set parentName [winfo name $parentPath]
        switch $parentName {
            notebook { return $parentPath }
            panedwindow { return $parentPath }
            "" { return ""}
            default {FindParentpanedwindowOrNotebook $parentPath}
        }
    }
    
    proc FindParentPanedwindow {containerId} {
        set parentPath [winfo parent $containerId]
        set parentName [winfo name $parentPath]
        switch $parentName {
            panedwindow { return $parentPath }
            "" { return ""}
            default {FindParentPanedwindow $parentPath}
        }
    }
    
    proc FindParentNotebook {containerId} {
	variable dp0

	if {![string first $containerId $dp0]} {
	    return {}
	} elseif {[string equal TNotebook [winfo class $containerId]]} {
	    return $containerId
	} else {
	    return [FindParentNotebook [winfo parent $containerId]]
        }
    }
    
    proc FindParentNotebookPage {containerId} {
	variable dp0

	if {[string equal $dp0 $containerId]} {
	    return {}
	} elseif {[string match fpage* [winfo name $containerId]]} {
	    return $containerId
	} else {
	    return [FindParentNotebookPage [winfo parent $containerId]]
        }
    }
    
    proc ShowMreHelp {} {
        variable currentNode
        global helperTable
        
        ContextSensitiveHelp $helperTable($currentNode,whichRunEnv) run/single.htm
    }
    
    proc ForgetHelperState {} {
	global helperTable
        variable currentNode
	
	array unset helperTable $currentNode,stateName
    }

    proc Destroy {args} {
        global helperTable window_info model_id
        variable runControlWindId
        variable currentNode
        

        if {[llength $args]} {
            InMreFor [lindex $args 0]
        }
	set node $currentNode

	set mreId $helperTable($node,whichRunEnv)
	KillTransients $mreId
        destroy .helpPopup
	if {![EmptyDisplays]} {
	    return
	}
	PreserveSetup 0
	ForgetHelperState
        foreach winData [array names window_info *,parent] {
            upvar 0 window_info([string range $winData 0 end-7],top_node) model
            if {[info exists model]} {
                if {[string equal $node $model]} {
                    set navBar $window_info($winData).toolSlot.navbar
                    $navBar.runenv configure -state disable
                }
            }
        }
        destroy $mreId
        unset helperTable($node,whichRunEnv)
	TryToKill $node
    }
    
    proc Addpanedwindow {containerId orientation} {
#ShowMess debug info "RunEnv::Addpanedwindow $containerId $orientation\n \
        #        pwidth $pwidth; pheight $pheight" ok; ################
	set pwId $containerId.panedwindow
	panedwindow $pwId  -orient $orientation
        pack $pwId -expand yes -fill both
	AddPane [UniqueId $pwId.pane [$pwId panes]]

#ShowMess debug info "RunEnv::Addpanedwindow width $width; height $height" ok
        return $pwId
    }

# SetLeafCurrent: when the curent frame is deleted, the next thing in
# line might be a composite widget, e.g., notebook or panedwindow, but
# the code only works if the current container is a leaf, so this goes
# down the tree till it finds one
    proc SetLeafCurrent {widget} {
#puts "SetLeafCurrent $widget"
	set collection [lindex [winfo children $widget] 0]
        if {[lsearch [list {} $widget.container] $collection]>=0} {
	    SetCurrentContainer $widget
	} else {
	    switch [winfo class $collection] {
		TNotebook {
		    SetLeafCurrent [$collection select] ;# use current page
		} Panedwindow {
		    SetLeafCurrent [lindex [$collection panes] 0]
		} default {
		    puts "Found unexpected widget $collection"
		}
	    }
	}
    }
    
    proc SetCurrentContainer {win} {
        global helperTable
        variable currentNode
        variable CurrentContainer
        variable CurrentContainers
	variable dp0

#puts "SetCurrentContainer $win"
        set mainframe $helperTable($currentNode,whichRunEnv)
        set mreMenu [$mainframe cget -menu]
        set pw [winfo parent $win]
        #ShowMess debug info "RunEnv::SetCurrentContainer pw $pw" ok
	set tb1 [GetFrame $mainframe].tbar
        if {[winfo exists $win.container]} {
            if {[string equal $dp0 $win]} {
                $tb1.b20 configure -state disabled
                $tb1.b21 configure -state disabled
	    } elseif {[string match vertical [$pw cget -orient]]} {
                #ShowMess debug info "vert $tb1.bbox2" ok
                $tb1.b20 configure -state normal
                $tb1.b21 configure -state disabled
            } else  {
                #ShowMess debug info "horiz $tb1.bbox2" ok
                $tb1.b20 configure -state disabled
                $tb1.b21 configure -state normal
            }
 	    set useSpaceAbility disabled
	    set copyAbility normal

	    set inst $helperTable($win.container,whichInstance)
	    if {[catch {$inst info function CopyToClipboard}]} {
		set exportAbility disabled
	    } else {
		set exportAbility normal
	    }
	    if {[catch {$inst info function Print}]} {
		set printAbility disabled
	    } else {
		set printAbility normal
	    }
	} else {
	    $tb1.b20 configure -state normal
	    $tb1.b21 configure -state normal
	    set useSpaceAbility normal
	    set copyAbility disabled
	    set exportAbility disabled
	    set printAbility disabled
	}
	$mreMenu entryconfigure [tr. Add] -state $useSpaceAbility
	set mreMenu [$mainframe cget -menu]
	set fileMenu [$mreMenu entrycget [tr. File] -menu]
	$fileMenu entryconfigure [tr. Print...] -state $printAbility
	$fileMenu entryconfigure [tr. {Export PostScript...}] \
	    -state $exportAbility
	set editMenu [$mreMenu entrycget [tr. Edit] -menu]
	$editMenu entryconfigure [tr. Copy] -state $copyAbility
	$editMenu entryconfigure [tr. Cut] -state $copyAbility
	$editMenu entryconfigure [tr. Paste] -state $useSpaceAbility

###############################################################################
$tb1.b10 configure -state $copyAbility ;# copy button
$tb1.b11 configure -state $copyAbility ;# cut button
$tb1.b12 configure -state $useSpaceAbility; # paste button
$tb1.b14 configure -state $printAbility; # print button
$tb1.b31 configure -state $useSpaceAbility; # Add Notebook button
$tb1.b40 configure -state $useSpaceAbility; # add helper buttons
$tb1.b41 configure -state $useSpaceAbility
$tb1.b42 configure -state $useSpaceAbility
$tb1.b43 configure -state $useSpaceAbility

###############################################################################
################################################################################
# jmm added a modify params button and this stuff above broke
# ShowMessage debug info "RunEnv::SetCurrentContainer pw $pw" ok
#     $tb1.b12 configure -state $copyAbility ;# copy button
#     $tb1.b12 configure -state $copyAbility ;# cut button
#     $tb1.b13 configure -state $useSpaceAbility; # paste button
#     $tb1.b15 configure -state $printAbility; # print button
#     $tb1.b32 configure -state $useSpaceAbility; # Add Notebook button
#     $tb1.b41 configure -state $useSpaceAbility; # add helper buttons
#     $tb1.b42 configure -state $useSpaceAbility
#     $tb1.b43 configure -state $useSpaceAbility
#     $tb1.b44 configure -state $useSpaceAbility
################################################################################

	set win2 [winfo parent $pw]
	set pw2 [winfo parent $win2]
	if {[string equal $dp0 $win] && ![winfo exists $win.container]} {
	    set killability disabled ;# it's the last pane
	} elseif {[string equal Panedwindow [winfo class $pw2]] && \
		[llength [$pw panes]]==1 && ![winfo exists $win.container]} {
	    destroy $pw ;# redundant orientation change
	    $win2 configure -highlightthickness 1
	    SetCurrentContainer $win2
	    return
	} else {
	    set killability normal
	}
	.pageContextMenu entryconfigure 15 -state $killability
	$tb1.b13 configure -state $killability

	if {[string length [FindParentNotebook $win]]} {
	    set newPageAbility normal
	} else {
	    set newPageAbility disabled
	}
	.pageContextMenu entryconfigure 13 -state $newPageAbility
	$tb1.b30 configure -state $newPageAbility; # Add Notebook Page button

        focus $win
        set CurrentContainers($currentNode) $win
        set CurrentContainer $win
#        ShowMess debug info "done SetCurrentContainer $win" ok
    }
    
    # Return a list of all children, found recursively, of a widget
    proc GetChildren { widget } {
        #ShowMess debug info "GetChildren" ok
        set allChildren [winfo children $widget]
        foreach child $allChildren {
            set allChildren [concat $allChildren [GetChildren $child]]
        }
        return $allChildren
    }
    
    proc CreateDisplayPageContextMenu {} {
        if  {![winfo exists .pageContextMenu]} {
            set m [menu .pageContextMenu -tearoff 0]
#           .helpers.sub2 clone .pageContextMenu.sub2
            $m add command -label "Create plotter" -command "::RunEnv::InsertHelperWindow plotter1_dot_25 {}"
            $m add command -label "Create table" -command "::RunEnv::InsertHelperWindow tabular11510 {}"
            $m add command -label "Create input sliders" -command "::RunEnv::InsertHelperWindow slide139 {}"
            $m add cascade -label "Choose display to create ..." -menu .helpers.sub2
            $m add separator
            $m add command -label "Copy display" -command ::RunEnv::CopyHelper
            $m add command -label "Cut display" -command ::RunEnv::CutHelper
            $m add command -label "Paste display" -command ::RunEnv::PasteHelper
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
    
    proc PreserveSetup {needSaving} {
	global helperTable
	variable currentNode
	
	if {$needSaving} {
	    set saveAbility normal
	} else {
	    set saveAbility disabled
	}

	set mainframe $helperTable($currentNode,whichRunEnv)
	set mreMenu [$mainframe cget -menu]
	set fileMenu [$mreMenu entrycget [tr. File] -menu]
	$fileMenu entryconfigure [tr. {Save configuration}] -state $saveAbility
	set tb1 [GetFrame $mainframe].tbar
	$tb1.b02 configure -state $saveAbility
	
	set helperTable($currentNode,keepSetup) $needSaving
    }

    proc EmptyDisplays {} {
        global helperTable
	variable currentNode
	variable dp0
        
	if {[info exists helperTable($currentNode,keepSetup)] && \
		$helperTable($currentNode,keepSetup)} {
	    set helperAction [Query save_helper_setup question top {} \
				  {abandon update_shf cancel}]
	    switch $helperAction {
		update_shf {
		    SaveView 0
		} cancel {
		    return 0
		}
	    }
	}
	foreach child [winfo children $dp0] {
	    destroy $child
	}
	return 1
    }
    
    proc InitializeDisplays {} {
        variable dp0
        
	if {![EmptyDisplays]} {
	    return
	}
        SetCurrentContainer $dp0
	AddNotebookToCurrentContainer
	ForgetHelperState
	PreserveSetup 0
    }
    
    proc ChildrenFocusParent {parent} {
        # despite the inner frame being called the container its the pane
        # could clean up the naming sometime
        set Container [winfo parent $parent]
        #ShowMess debug info "ChildrenFocusParent:\n\
        #        parent : $parent; container $Container\n\
        #        children [winfo children $parent]" ok
        foreach child [winfo children $parent] {
            bind $child <Button-1> "+::RunEnv::SetCurrentContainer $Container"
        }
    }
    
    proc SaveView {newName} {
        global helperTable simtmpdir
        variable dp0
        variable currentNode
        
	if {[info exists helperTable($currentNode,stateName)]} {
	    set saveName $helperTable($currentNode,stateName)
	} else {
	    set saveName [GetExecTitle $currentNode].shf
	    set newName 1
	}
	if {$newName} {
	    set saveName [ChooseFile [file tail $saveName] \
			      "Save display configuration" 1 $currentNode]
	}
        if {![llength $saveName]} { ;# operation cancelled
	    return
	} else {
            set mainframe $helperTable($currentNode,whichRunEnv)
            set tempFile [file join $simtmpdir temp_out.shf]
            set stream [NetOpen $tempFile w]
            
            set mreId $helperTable($currentNode,whichRunEnv)
            # save skeleton mre config
            puts $stream "[winfo x $mreId] [winfo y $mreId] \
                    [winfo width $mreId] [winfo height $mreId]"
            puts $stream "[[GetFrame $mainframe].mainpw sash coord 0]"
            puts $stream "[[GetFrame $mainframe].mainpw.controlPane.panedwindow sash coord 0]"
            SaveChildrenConfig $dp0 [string length $dp0.] $stream
            
            close $stream
            MimifySHF $tempFile $saveName mre
	    do_in_editor AttackGlobalVariable helperTable \
		($currentNode,stateName) $saveName
	    PreserveSetup 0
	}
    }
    
    proc SaveChildrenConfig {page loss stream} {
	switch [winfo class $page] {
	    Panedwindow {
		SavePanedwindowConfig $page $loss $stream
	    }
	    TNotebook {
		SaveNotebookConfig $page $loss $stream
	    }
	    default {
		#puts $stream "Unhandled Notebook page child: $child"
		if {[string equal container [winfo name $page]]} {
		    SaveContainer $page $loss $stream
		} else {
		    foreach child [winfo children $page]  {
			SaveChildrenConfig $child $loss $stream
                    }
                }
	    }
	}
    }

    proc SaveNotebookConfig {notebook loss stream} {
        set nb [string range $notebook $loss end]
        puts $stream "notebook $nb"
        foreach page [$notebook tabs] {
            set pagecaption [$notebook tab $page -text]
            regsub -all " " $pagecaption _ noSpcpagecaption
	    set pageId [string range [winfo name $page] 1 end]
            puts $stream "page $nb $pageId $noSpcpagecaption"
	    SaveChildrenConfig $page $loss $stream
        }
    }
    
    proc SavePanedwindowConfig {panedwindow loss stream} {
        puts $stream "panedwindow [string range $panedwindow $loss end] [$panedwindow cget -orient]"
        foreach pane [$panedwindow panes] {
            puts $stream "pane [string range $pane $loss end]"
	    SaveChildrenConfig $pane $loss $stream
	}
        for {set index 0} {$index < [expr [llength [$panedwindow panes]]-1]} \
	    {incr index} {
		puts $stream "sash [string range [winfo parent $pane] $loss end] $index [$panedwindow sash coord $index]"
	    }
    }
    
    proc SaveContainer {winId loss stream} {
        global helperTable

	set inst $helperTable($winId,whichInstance)
        set helperId [$inst info class]
        puts $stream "container [string range [winfo parent $winId] $loss end]"
        puts $stream [namespace tail $helperId]
        # substitute <cr>s so entry goes on one line
        # not a toplevel #puts $stream [StripCrs [wm title $winId]]
        # not a toplevel #puts $stream [wm geometry $winId]
	
# If helper includes a PrepareSaveString command, call it. 1st arg is 
# expanded before executing helper namespace so window Id is copied from local 
# variable.
#	namespace eval ::$helperId set winId $winId {;
#	    if {[llength [info procs PrepareSaveString]]} {
#		PrepareSaveString $winId
#	    }
#	}
	$inst PrepareSaveString
	puts $stream [StripCrs [$inst cget -State]]
    }
    
    proc LoadView {} {
	variable currentNode
        set HelperStateFileName [ChooseFile Displays.shf \
                "Open view specification file" 0 $currentNode]
        if {[llength $HelperStateFileName]} {
            LoadSHF $currentNode $HelperStateFileName
        }
    }
    
    proc LoadSHF {currentNode oldPath} {
        global mimeSquirter simtmpdir
        global helperTable errorInfo
        variable dp0 
        if {[catch {
                set multiT [mime::initialize -file $oldPath]
                set origVersion [mime::getheader $multiT Simile-Version]
                set origin [mime::getheader $multiT Simile-Origin]
                set metaFile [file join $simtmpdir temp_in.shf]
                set mimeSquirter [NetOpen $metaFile w]
                fconfigure $mimeSquirter -translation binary
                mime::getbody $multiT -command SquirtMime -blocksize 256
	} syndrome]} {
#do_in_editor puts "MIME open failed: $syndrome"
            set metaFile $oldPath
            set origVersion 0.0
            set stream [NetOpen $metaFile r]
            # check for run env that made the shf
            gets $stream line
            if {[llength $line]==4} {
                set origin mre
            } else {
                set origin many_windows
            }
            close $stream
        }
        
        set helperTable($currentNode,stateName) $oldPath
        set stream [NetOpen $metaFile r]
       
        if {[string equal mre $origin]} {
            LoadViewFile $currentNode $stream $origVersion
        } elseif {[string equal many_windows $origin]}  {

            # assume that it is an shf made by the multiple window run env
	    # and just open each helper in a toplevel notebook page
	    # THIS PROBABLY DOES NOT WORK

            if {![EmptyDisplays]} {
		return
	    }; #what if there is an error in the file delete MRE, rebuild
            AddNotebook $dp0
            while {[gets $stream helperId] >= 0} {
                set emptyPage [MainNotebookEmptyPage]
                if {![string match none $emptyPage]} {
                    set containerId [MainNotebookEmptyPage]
                } else  {
                    set containerId [AddNotebookPage $dp0.notebook]
                }
                #ShowMess debug info "LoadView winId $containerId" ok
                gets $stream helperTitle
                set winId [NewHelperInWindow $containerId $helperId [RestoreCrs $helperTitle]]
                gets $stream geometry
                #wm geometry $winId $geometry # not a toplevel
                gets $stream oldStatus
                if {$origVersion<4.0} {
                    set oldStatus [LoseDTRef $oldStatus]
                }
                set helperTable($winId,status) [RestoreCrs $oldStatus]
                if {[catch {SystemHelperCall $winId $currentNode \
				Restore $winId} prang]} {
		    if {[string equal aborted $prang]} {
			break
		    }
                    DeleteHelperCurrentContainer
		    if {[string equal abort \
			     [Query [list iotool_restore_fail $helperTitle \
				     $errorInfo] warning helpers {} abort]]} {
			break
		    }
                } else {
                    ChildrenFocusParent $winId
                }
            }
            $dp0.notebook raise [lindex [$dp0.notebook pages] 0]
            
        } else  {
	    Query not_an_shf error execution {} ok
        }
        close $stream
# allow helper windows to configure themselves
	update
	PreserveSetup 0
    }
    
    proc LoadViewFile {currentNode stream origVersion} {
        global helperTable
        variable dp0
        

	if {![EmptyDisplays]} {
	    return
	}
        set win $helperTable($currentNode,whichRunEnv)
	set mainframe $win
        # read and set .mre position and size
        gets $stream line
        scan $line "%i %i %i %i" x y width height
	if {$x>=0 && $x+$width<[winfo screenwidth $win] && \
		$y>=0 && $y+$height<[winfo screenheight $win]} {
	    wm geometry $win ${width}x${height}+${x}+${y}
        } else {
	    wm geometry $win ${width}x${height}
	}

        gets $stream line
        scan $line "%i %i" x y;
        [GetFrame $mainframe].mainpw sash place  0 $x $y
        
        gets $stream line
        scan $line "%i %i" x y
        [GetFrame $mainframe].mainpw.controlPane.panedwindow sash place  0 $x $y

        set newNotebooks {}
        while {[gets $stream line] >= 0} {
            switch [scan $line %s] {
                container {
                    if {[scan $line "%s %s" widget tail]==1} {
			set tail {}
		    }
                    if {$origVersion<4.0} {
                        set tail [LoseTLRef $tail]
                    }
                    if {[string equal abort [LoadContainer $currentNode \
						 $stream $tail $origVersion]]} {
			break
		    }
                }
                panedwindow {
                    #%puts $stream "panedwindow $panedwindow [$panedwindow cget -orient]"
                    scan $line "%s %s %s" widget path orient
                    if {$origVersion<4.0} {
                        set path [LoseTLRef $path]
                    }
                    panedwindow $dp0.$path -orient $orient
		    [winfo parent $dp0.$path] configure -highlightthickness 0
                    pack $dp0.$path -expand yes -fill both
                }
                pane {
                    #%puts $stream "pane $pane"
                    scan $line "%s %s" widget tail
                    if {$origVersion<4.0} {
                        set tail [LoseTLRef $tail]
                    }
                    set path $dp0.$tail
		    AddPane $path
                }
                sash {
                    scan $line "%s %s %i %i %i" sash windowtail index sashx sashy
                    if {$origVersion<4.0} {
                        set windowtail [LoseTLRef $windowtail]
                    }
                    set panedwindow $dp0.$windowtail
                    # the page this pane is in must be raised and update called!
                    # or $panedwindow sash place won't work
                    set pageId [FindParentNotebookPage $panedwindow]
		    if {[string length $pageId]} {
			[winfo parent $pageId] select $pageId
		    }
		    update idletasks
                    #ShowMess debug info "$panedwindow sash place $index $sashx $sashy \n\
                    #        page [$notebook pages]\n\
                    #        FindParentNotebook $notebook \n\
                    #        FindParentNotebookPage $pageId" ok
                    $panedwindow sash place $index $sashx $sashy
                }
                notebook {
                    #puts $stream "notebook $notebook"
                    scan $line "%s %s" widget tail
                    if {$origVersion<4.0} {
                        set tail [LoseTLRef $tail]
                    }
                    set path $dp0.$tail
                    ::ttk::notebook $path
		    lappend newNotebooks $path
		    bind $path <<NotebookTabChanged>> \
			[list ::RunEnv::PageRaiseCmd $path]
        
                    set containerId [winfo parent $path]
                    #ShowMess debug info "containerId $containerId" ok
                    bind $path <Double-1> "::RunEnv::EditTabLabel %W"
                    bind $path <Button-3> "::RunEnv::EditTabLabel %W"
                    pack $path -fill both -expand yes
                }
                page {
                    #puts $stream "page $notebook $page $pagecaption"
                    scan $line "%s %s %s %s" widget nbtail pageId noSpcpagecaption
                    if {$origVersion<4.0} {
                        set nbtail [LoseTLRef $nbtail]
                    }
                    set notebook $dp0.$nbtail
                    regsub -all _ $noSpcpagecaption " " pagecaption
                    
                    #ShowMess debug info "$widget $notebook $pageId $pagecaption" ok
		    set newFr [frame $notebook.f$pageId]
                    $notebook add $newFr -text $pagecaption \
			;#-raisecmd [list ::RunEnv::PageRaiseCmd $containerId.notebook $pageId]
                    # page raised below before any panes so that must be moved todo                 -raisecmd [list ::RunEnv::PageRaiseCmd $notebook $pageId]
                    bind $newFr <Button-1> "+::RunEnv::SetCurrentContainer %W"
                    bind $newFr <Button-3> \
                            "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
                }
                default {
                    # puts $stream "Unhandled mre element"
                }
            }
        }
	foreach nb $newNotebooks {
	    $nb select [lindex [$nb tabs] 0]
	}
    }
    
    proc LoseTLRef {path} {
        if {[string last .mre.mainframe.frame.mainpw.mainDisplayPane. $path 43]} {
            return $path
        } else {
            return [string range $path 44 end]
        }
    }
    
    proc LoadContainer {node stream containerId origVersion} {
        global helperTable
        variable dp0
	variable CurrentContainer

        #ShowMess debug info "LoadContainer: stream $stream, line $line" ok
        if {[string length $containerId]} {
	    set CurrentContainer $dp0.$containerId
        } else {
	    set CurrentContainer $dp0
	}
        
        gets $stream helperId
        #ShowMess debug info "LoadContainer: $item $containerId; helperId $helperId" ok
        gets $stream oldStatus
	return [ReinstateHelper $origVersion $oldStatus $helperId {}]
    }
    
    proc MainNotebookEmptyPage {} {
        variable dp0
        foreach page [$dp0.notebook pages] {
            if {![winfo exists \
                        [$dp0.notebook getframe $page].panedwindow.pane0.container]} {
                return [$dp0.notebook getframe $page].panedwindow.pane0
            }
        }
        return none
    }
    
#    proc UniqueId {basename pagenames} {
        # basename is the root of the Id, numbers after / are appended to it
        # pagenames is the list of existing names
#        set i 1
#        while {[lsearch -regexp $pagenames $basename$i] > -1} {
#            incr i
#        }
#       return $basename$i
#    }
} ;# end of namespace RunEnv

proc RaiseMREFor {node} {
    global helperTable

    MyRaise $helperTable($node,whichRunEnv)
}

proc MyRaise {top} {
    wm deiconify $top
#    if {[string equal x11 [tk windowingsystem]]} {
# work around mind-boggling KDE bug: lower works, raise does not
# removed as did not necessarily help
#	set allWins [wm stackorder .]
#	foreach hiWin [lrange $allWins [expr [lsearch $allWins $top]+1] end] {
#	    lower $hiWin $top
#	}
#    }
    raise $top

    if {[string equal aqua [tk windowingsystem]]} {
	catch {tclAE::send -s misc actv}
    }
}
# A top level window to contain the helpers
# overrides mre.tcl Makemre
proc Makemre { node } {
    return [RunEnv::Create $node]
}

