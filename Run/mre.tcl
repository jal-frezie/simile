# Support for the Model Run Environment moved to a seperate source file mre.tcl
# this file must source the mre.tcl file and MakeMRE is called from proc ModelWindow
# Jonathan Massheder


# helpers must bind $canvas <Configure> resize $canvas

namespace eval RunEnv {
    
    package require BWidget
    
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
    variable CurrentContainer
    
    variable width 780; # window width  # should be an option
    variable height 580; #window height  # should be an option
    
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
            [list graph.gif "Create plotter" "CreateHelperWindow plotter1.25 {Plotter}"] \
            [list table.gif "Create table" "CreateHelperWindow tabular11510 {Table}"] \
            [list slider.gif "Create input sliders" "CreateHelperWindow slide139 {Sliders}"] \
            [list display.gif "Choose display to create" "::RunEnv::AllDisplaysPopupCurrentContainer"]] \
            [list \
            [list clear.gif "Clear all displays" "ClearView"]]\
            [list \
            [list mainwin.gif "Go to Model Window" "::RunEnv::RaiseModelWindow"]]]
    
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
            toplevel $mreId -width 200m -height 150m
            wm title $mreId "[GetExecTitle $node] execution - Simile"
            set currentNode $node
            bind $mreId <FocusIn> [namespace code "InMreFor $node"]
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
                    {command "&Export PostScript..." {} "Export display as PostScript"  \
                                {} -command { ::RunEnv::ExportCurrentContainer } }
                    {separator}
                    {command "Pa&rameters..." {} "Modify file parameters"  \
                                {} -command { ::RunEnv::InvokeFPDialogue } }
                    {separator}
                    {command "&Close"    {} "Close the Run Environment window" \
                                {} -command RunEnv::Destroy }
                }
                "&Edit" all edit 0 {
                    {command "Co&py"    {} "Copy display" {} \
                                -command RunEnv::CopyHelper }
                    {command "Cu&t"    {} "Cut display" {} \
                                -command RunEnv::CutHelper }
                    {command "&Paste"    {} "Paste display" {} \
                                -command ::RunEnv::PasteHelper }
                    {separator}
                    {command "&Remove"    {} "Remove display or container" {} -command {::RunEnv::DeleteHelperCurrentContainer}}
                    {command "&Clear all"    {} "Clear all displays" {} -command {ClearView} }
                }
                "&Help" all help 0 {
                    {command "&Contents..." {} "View the help file contents" {} -command ::RunEnv::ShowMreHelp}
                }
            }
            
            set mainframe [MainFrame $mreId.mainframe -width 200m -height 150m \
			       -menu         $descmenu \
			       -textvariable RunEnv::status \
			       -progressvar  RunEnv::prgindic]
            
            if [string match "Darwin" $tcl_platform(os)] {
		set dummy [$mreId cget -menu]
		set fm [menu $dummy.apple -tearoff 0]
		$fm add command -label "About Simile..." -command "ShowAbout $mreId"
		$fm add separator
		$dummy add cascade -menu $fm
	    }
	    
            set tb1  [::ttk::frame [$mainframe getframe].tbar -class Toolbar]
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
                    pack $newButton -padx 1 -pady 1  -side left -anchor w
                    BindPopup $newButton $helptext
                    incr i
                }
                pack $tb1 -side top -anchor w -fill x
                incr tbnum
                pack [Separator $tb1.sep$tbnum -orient vertical] -side left -fill y -padx 4
            }
            
            #from runmodel.tcl AddHelperSublist
            set mreMenu [winfo parent [$mainframe getmenu help]]
            $mreMenu insert 2 cascade -label "Add" -underline 0 -menu .helpers.sub2
	    if {[info exists runHow(where)]} {
		$mreMenu insert 3 cascade -label "Window" -underline 0 \
		    -menu .windowchoice
	    }
            # Add a PanedWindow for the hierrachical/run control view and main display window
            set mainpw [panedwindow [$mainframe getframe].mainpw  -orient horizontal]
            set controlPane [frame $mainpw.controlPane]; # made by runmodel.tcl AddHelperSublist
            set dp0 [frame $mainpw.mainDisplayPane]
            set dp0s($node) $dp0
            
            $mainpw add $controlPane $dp0 -width 270; # must be wide enough (270ish) for the sliders
            
            # Add a panedwindow to split the hier/contol pane into hierrachical pane and control pane
            set hiercontrolpw [panedwindow $controlPane.panedwindow -orient vertical]
            set runcontrolpane [frame $hiercontrolpw.runcontrolPane]
            set explorerPane [frame $hiercontrolpw.explorerPane]
            $hiercontrolpw add $runcontrolpane $explorerPane ;# -height 240
            
            # Add notebook for controls, explorer etc
            set variableListFrame($node) [frame $explorerPane.variables]
            pack $variableListFrame($node) -fill both -expand yes
            
            #        $explorerPane.notebook insert end "InputSliders" -text "Input sliders"
            #        set sliderControlFrame \
            #                [frame [$explorerPane.notebook getframe "InputSliders"].sliders]
            #        $explorerPane.notebook insert end "Output" -text "Output"
            #        set outputFrame \
            #                [frame [$explorerPane.notebook getframe "Output"].sliders -container true]

            pack $variableListFrame($node) -fill both -expand yes
            
            set runControlFrame($node) [frame $runcontrolpane.variables]
            pack $runControlFrame($node) -fill both -expand yes
            
            AddNotebook $dp0
            
            pack $mainframe -fill both -expand yes
            pack $mainpw -fill both -expand yes
            
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

    proc ListWindows {fm} {
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
        catch {set CurrentContainer $CurrentContainers($node)}
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
	    AddNotebookPage $containerId.notebook
        }
        
        bind $containerId.notebook <Double-1> "::RunEnv::EditTabLabel %W"
        bind $containerId.notebook <Button-3> "::RunEnv::EditTabLabel %W"
        
        $containerId.notebook select [lindex [$containerId.notebook tabs] 0]
        pack $containerId.notebook -fill both -expand yes
    }
    
    proc EditTabLabel { notebook } {
	global helperTable
        variable TabEditText
	variable currentNode
        set TabEditText [$notebook tab current -text]
        #based on equationRight
        #ShowMessage debug info "TabRight tabId $tabId; label [$notebook itemcget $tabId -text]" ok
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
	set pageF [lindex [$notebook tabs] [$notebook index current]]
        if {[winfo exists $pageF.panedwindow]} {
	    set firstPane [lindex [$pageF.panedwindow panes] 0]
	    #     ShowMessage debug info "PageRaiseCmd firstPane $firstPane" ok
	    SetCurrentContainer $firstPane
	}
    }
    
    proc AddNotebookToCurrentContainer {} {
        variable CurrentContainer
        AddNotebook $CurrentContainer
    }
    
    proc AddNotebookPage {containerId} {
        if {[string match notebook [winfo name $containerId]]} {
            set ParentContainer $containerId
        } else  {
            set ParentContainer [FindParentpanedwindowOrNotebook $containerId]
        }
        #ShowMessage debug info "containerId $containerId\nParentContainer $ParentContainer" ok
        if {[string match notebook [winfo name $ParentContainer]]} {
            set pageId [UniqueId $ParentContainer.fpage [$ParentContainer tabs]]
            set pageIndex [expr {[llength [$ParentContainer tabs]]+1}]
            set newContainer [frame $pageId]
            $ParentContainer add $newContainer -text "Page $pageIndex"
            panedwindow $newContainer.panedwindow -orient vertical
            pack $newContainer.panedwindow -expand yes -fill both
            frame $newContainer.panedwindow.pane0 -highlightcolor black -highlightthickness 1
            bind $newContainer.panedwindow.pane0 <Button-1> "+::RunEnv::SetCurrentContainer %W"
            bind $newContainer.panedwindow.pane0 <Button-3> \
                    "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
            $newContainer.panedwindow add $newContainer.panedwindow.pane0 -sticky nesw
	    $ParentContainer select $newContainer
            return $newContainer.panedwindow.pane0
        } else  {
            return [AddNotebookPage $ParentContainer]
        }
        
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
    
    # Not used - possibly never will be but is skeleton to use the selection for transfer
    # of copied helper
    proc SelectionHandler {offset maxChars} {
        global helperTable
        variable CurrentContainer
        set SelStr [StripCrs $helperTable($CurrentContainer.container,status)]
        set last [expr {$offset + $maxChars}]
        return [string range $SelStr $offset $last]
    }
    
    proc PrintCurrentContainer {} {
        global helperTable env tcl_platform
        variable CurrentContainer
        variable canvasId
        
        if {[winfo exists $CurrentContainer.container]} {
            set CurrentHelperId $helperTable($CurrentContainer.container,whichHelper)
            if {![string match "" [info commands ::${CurrentHelperId}::Print]]} {
                ::${CurrentHelperId}::Print $CurrentContainer.container
            } elseif {![string match "" [info commands ::${CurrentHelperId}::GetCanvas]]} {
                set canvasId [$helperTable($CurrentContainer.container,whichHelper)::GetCanvas $CurrentContainer.container]
                PrintRandomCanvas $canvasId
            } else {
                ShowMessage Warning warning \
                        "[${CurrentHelperId}::identify] does not support printing." ok
            }
            
        }
    }
    
    proc ExportCurrentContainer {} {
        global helperTable env tcl_platform
        variable CurrentContainer
        variable canvasId
        
        if {[winfo exists $CurrentContainer.container]} {
            set CurrentHelperId $helperTable($CurrentContainer.container,whichHelper)
            if {![string match "" [info commands ::${CurrentHelperId}::GetCanvas]]} {
                set canvasId [$helperTable($CurrentContainer.container,whichHelper)::GetCanvas $CurrentContainer.container]
                PostScrog $canvasId
            } else {
                ShowMessage Warning warning \
                        "[${CurrentHelperId}::identify] does not support PostScript export." ok
            }
            
        }
    }
    
    proc CopyHelper {} {
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
                    CopyCanvasToWindowsClipboard $canvasId 0
                } else {
                    ShowMessage Warning warning \
                            "[${CurrentHelperId}::identify] does not support copying" ok
                }
                set copyfile $simtmpdir/mrecopy.txts
# If helper includes a PrepareSaveString command, call it
		namespace eval ::$CurrentHelperId  set winId $winId {;
		    if {[llength [info procs PrepareSaveString]]} {
			PrepareSaveString $winId
		    }
		}
                set stream [NetOpen $copyfile w]
                catch {puts $stream [StripCrs $helperTable($CurrentContainer.container,status)]}
                close $stream
            }
        }
    }
    
    proc CutHelper {} {
        CopyHelper
        DeleteHelperCurrentContainer
    }
    
    proc PasteHelper {} {
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
    
    proc DeleteHelperContainer {containerId page} {
        global helperTable
        # container is the frame a helper would be displayed in
        # a parent is the notebook or panedwindow the container belongs to
        #ShowMessage debug info "container $containerId; page $page; \
        #            parent [::RunEnv::FindParentpanedwindowOrNotebook $containerId]" ok
        if {![winfo exists $containerId]} {
            return
        }
        set parentPath [FindParentpanedwindowOrNotebook $containerId]
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
    
    proc DeleteHelperCurrentContainer {} {
        variable CurrentContainer
        DeleteHelperContainer $CurrentContainer {}
    }
    
    proc DeleteNotebookPage {notebook page} {
        set pages [$notebook tabs]
        set page [$notebook index current]
        set n [llength $pages]
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
#        $notebook forget $page
	destroy [lindex $pages $page]
	update
        set pages [$notebook tabs]
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
# why bother? Doesnt work anyway 
#            set pages [$notebook tabs]
#            set i 0
#            foreach item $pages {
#                set label [$notebook tab $item -text]
#		ShowMessage debug info "set $label to [expr {$i+1}] ?" ok
#                if {$label==$i+2} {
#                    $notebook tab $item -text [expr {$i+1}]
#                }
#                incr i
#            }
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
    
    proc DeletePane {parentPath containerId} {
        #ShowMessage debug info "DeletePane\n parentPath $parentPath\n \
        #        containerId $containerId\n \
        #        panes [$parentPath panes]" ok;
        set greatgrandparent [winfo parent [winfo parent $parentPath]]
        #puts "DeletePane greatgrandparent $greatgrandparent; class [winfo class $greatgrandparent]"
        if {[string match TNotebook [winfo class $greatgrandparent]]} {
            if {([llength [$greatgrandparent tabs]] ==1) && ([llength [$parentPath panes]] == 1)} {
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
            #                pages [$parentNoteBook tabs]\n \
            #                current page [$parentNoteBook tab current]" ok;
            destroy $parentPath
            if {[string match TNotebook [winfo class $parentNoteBook]]} {
                DeleteNotebookPage $parentNoteBook [$parentNoteBook tab current]; #current page
            }
        }
    }
    
    proc SplitPage {containerId orientation} {
        set parentPath [FindParentpanedwindowOrNotebook $containerId]
        if {[string match notebook [winfo name $parentPath]]} {
            ShowMessage debug info "SplitPage Addpanedwindow $containerId $orientation" ok;
            Addpanedwindow $containerId $orientation
        } elseif {(![string match $orientation [$parentPath cget -orient]])} {
            ShowMessage debug info "SplitPage diff orientn container $containerId $orientation\n\
            parentPath $parentPath" ok;
            Addpanedwindow $containerId $orientation
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
                    set sashy [expr {$conty+$height}]
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
        set parentPath [winfo parent $containerId]
        set parentName [winfo name $parentPath]
        switch $parentName {
            notebook { return $parentPath }
            "" { return ""}
            default {FindParentNotebook $parentPath}
        }
    }
    
    proc FindParentNotebookPage {containerId} {
        set parentPath [winfo parent $containerId]
        set parentName [winfo name $parentPath]
        switch -glob $parentName {
            fpage* { return $parentPath }
            "" { return ""}
            default {FindParentNotebookPage $parentPath}
        }
    }
    
    proc ShowMreHelp {} {
        variable currentNode
        global helperTable
        
        ContextSensitiveHelp $helperTable($currentNode,whichRunEnv) run/single.htm
    }
    
    proc Destroy {args} {
        global helperTable window_info model_id
        variable runControlWindId
        variable currentNode
        
        if {[llength $args]} {
            set node $args
        } else {
            set node $currentNode
        }
        # stop the run -- this is now done by killing the run control
        #    upvar 0 runControlWindId($node) rcw
        #    if {[info exists rcw]} {
        #        set ControlSpace $helperTable($rcw,whichHelper)
        #        ::${ControlSpace}::Terminate $rcw
        #    }
        
        destroy .helpPopup
        KillHelpers $node
        foreach winData [array names window_info *,parent] {
            upvar 0 window_info([string range $winData 0 end-7],whichModel) model
            if {[info exists model]} {
                if {[string equal $node $model]} {
                    set navBar $window_info($winData).toolSlot.navbar
                    $navBar.runenv configure -state disable
                }
            }
        }
        destroy $helperTable($node,whichRunEnv)
        unset helperTable($node,whichRunEnv)
	start_in_editor TryToKill $node
    }
    
    proc Addpanedwindow {containerId orientation} {
        set pwidth  [winfo width $containerId]
        set pheight [winfo height $containerId]
        ShowMessage debug info "RunEnv::Addpanedwindow $containerId $orientation\n \
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
        ShowMessage debug info "RunEnv::Addpanedwindow width $width; height $height" ok
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
    
    proc SetCurrentContainer {win} {
        global helperTable
        variable currentNode
        variable CurrentContainer
        variable CurrentContainers
        if {![string match pane* [winfo name $win]]} {
	    ShowMessage debug info "failed SetCurrentContainer $win" ok
            return
        }
        set mainframe $helperTable($currentNode,whichRunEnv).mainframe
        set mreMenu [winfo parent [$mainframe getmenu help]]
        set pw [FindParentPanedwindow $win]
        #ShowMessage debug info "RunEnv::SetCurrentContainer pw $pw" ok
#        set tb1 [$mainframe gettoolbar 0]
	set tb1 [$mainframe getframe].tbar
        if {[winfo exists $win.container]} {
            $mreMenu entryconfigure Add -state disable
            [$mainframe getmenu edit] entryconfigure Copy -state normal
            [$mainframe getmenu edit] entryconfigure Cut -state normal
            [$mainframe getmenu edit] entryconfigure Paste -state disable
            $tb1.b12 configure -state disabled; # paste button
            $tb1.b31 configure -state disabled; # Add Notebook button
            $tb1.b40 configure -state disabled; # add helper buttons
            $tb1.b41 configure -state disabled
            $tb1.b42 configure -state disabled
            
            .pageContextMenu entryconfigure 0 -state disabled
            .pageContextMenu entryconfigure 1 -state disabled
            .pageContextMenu entryconfigure 3 -state disabled
            .pageContextMenu entryconfigure 7 -state disabled
            .pageContextMenu entryconfigure 12 -state disabled; # add notebook
            #.pageContextMenu entryconfigure 13 -state disabled; # add notebook p0age
            
            if {[string match vertical [$pw cget -orient]]} {
                #ShowMessage debug info "vert $tb1.bbox2" ok
                $tb1.b21 configure -state disabled
                $tb1.b20 configure -state normal
                .pageContextMenu entryconfigure 10 -state disabled
                .pageContextMenu entryconfigure 9 -state normal
            } else  {
                #ShowMessage debug info "horiz $tb1.bbox2" ok
                $tb1.b20 configure -state disabled
                $tb1.b21 configure -state normal
                .pageContextMenu entryconfigure 9 -state disabled
                .pageContextMenu entryconfigure 10 -state normal
            }
        } else  {
            $mreMenu entryconfigure Add -state normal
            [$mainframe getmenu edit] entryconfigure Copy -state disable
            [$mainframe getmenu edit] entryconfigure Cut -state disable
            [$mainframe getmenu edit] entryconfigure Paste -state normal
            $tb1.b12 configure -state normal; # paste button
                $tb1.b20 configure -state normal
                $tb1.b21 configure -state normal
            $tb1.b31 configure -state normal; # Add Notebook button
            $tb1.b40 configure -state normal; # add helper buttons
            $tb1.b41 configure -state normal
            $tb1.b42 configure -state normal
            
            .pageContextMenu entryconfigure 0 -state normal
            .pageContextMenu entryconfigure 1 -state normal
            .pageContextMenu entryconfigure 3 -state normal
            .pageContextMenu entryconfigure 7 -state normal
            .pageContextMenu entryconfigure 10 -state normal
            .pageContextMenu entryconfigure 9 -state normal
            .pageContextMenu entryconfigure 12 -state normal
            #.pageContextMenu entryconfigure 13 -state normal
        }
        focus $win
        set CurrentContainers($currentNode) $win
        set CurrentContainer $win
#        ShowMessage debug info "done SetCurrentContainer $win" ok
    }
    
    # Return a list of all children, found recursively, of a widget
    proc GetChildren { widget } {
        #ShowMessage debug info "GetChildren" ok
        set allChildren [winfo children $widget]
        foreach child $allChildren {
            set allChildren [concat $allChildren [GetChildren $child]]
        }
        return $allChildren
    }
    
    # Return a list of all widgets in an input list of a certain widget class
#    proc GetWidgetClass {widgetList widgetClass} {
#        set classList []
#        foreach widget $widgetList {
#            if {[string match [winfo class $widget] $widgetClass]} {
#                lappend classList $widget
#            }
#        }
#        return $classList
#    }
#    
    # Return a list of all widgets in an input list with a certain name
    # at the end of its path
#    proc GetWidgetsWithName {widgetList name} {
#        set nameList []
#        foreach widget $widgetList {
#            #ShowMessage debug info "$widget\n[lindex [split $widget .] end]" ok
#            if {[string match $name [lindex [split $widget .] end]]} {
#                lappend nameList $widget
#            }
#        }
#        return $nameList
#    }
    
    proc CreateDisplayPageContextMenu {} {
        if  {![winfo exists .pageContextMenu]} {
            set m [menu .pageContextMenu -tearoff 0]
            .helpers.sub2 clone .pageContextMenu.sub2
            $m add command -label "Create plotter" -command "CreateHelperWindow plotter1.25 {Plotter}"
            $m add command -label "Create table" -command "CreateHelperWindow tabular11510 {Table}"
            $m add command -label "Create input sliders" -command "CreateHelperWindow slide139 {Sliders}"
            $m add cascade -label "Choose display to create ..." -menu .pageContextMenu.sub2
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
    
    proc KillDisplays {} {
        global helperTable
        variable dp0
        
        destroy $dp0.notebook
        AddNotebook $dp0
    }
    
    proc ChildrenFocusParent {parent} {
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
    
    proc NewHelperInWindow {containerId helperId helperTitle} {
        global helperTable
        variable currentNode
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
        set helperTable($winId,whichModel) $currentNode
        bind $winId <Destroy>  "kill_helper_window $winId"
        SetCurrentContainer [winfo parent $winId]
        return $winId
    }
    
    #  nameOfHelperStateFile is global because helpers might want to save names of
    # other files they need relative to it, e.g., file param helper
    
    proc SaveView {} {
        global helperTable nameOfHelperStateFile simtmpdir
        variable dp0
        variable currentNode
        
        set nameOfHelperStateFile($currentNode) \
                [ChooseFile Displays.shf "Save display configuration" 1]
        if {[llength $nameOfHelperStateFile($currentNode)]} {
	    do_in_editor AttackGlobalVariable nameOfHelperStateFile \
		($currentNode) $nameOfHelperStateFile($currentNode)
            set mainframe $helperTable($currentNode,whichRunEnv).mainframe
            set tempFile [file join $simtmpdir temp_out.shf]
            set stream [NetOpen $tempFile w]
            
            set mreId $helperTable($currentNode,whichRunEnv)
            # save skeleton mre config
            puts $stream "[winfo x $mreId] [winfo y $mreId] \
                    [winfo width $mreId] [winfo height $mreId]"
            puts $stream "[[$mainframe getframe].mainpw sash coord 0]"
            puts $stream "[[$mainframe getframe].mainpw.controlPane.panedwindow sash coord 0]"
            SaveNotebookConfig $dp0.notebook [string length $dp0.] $stream
            
            close $stream
            MimifySHF $tempFile $nameOfHelperStateFile($currentNode) mre
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
            foreach child [winfo children $page]  {
                #            puts $stream \
                #		"$nb $page [string range $child $loss end]"
                switch [winfo name $child] {
                    container {
                        SaveContainer $child $loss $stream
                    }
                    panedwindow {
                        SavePanedwindowConfig $child $loss $stream
                    }
                    notebook {
                        SaveNotebookConfig $child $loss $stream
                    }
                    default {
                        #puts $stream "Unhandled Notebook page child: $child"
                    }
                }
            }
        }
    }
    
    proc SavePanedwindowConfig {panedwindow loss stream} {
        puts $stream "panedwindow [string range $panedwindow $loss end] [$panedwindow cget -orient]"
        foreach pane [$panedwindow panes] {
            puts $stream "pane [string range $pane $loss end]"
            foreach child [winfo children $pane] {
                switch [winfo name $child] {
                    container {
                        SaveContainer $child $loss $stream
                    }
                    panedwindow {
                        SavePanedwindowConfig $child $loss $stream
                    }
                    notebook {
                        SaveNotebookConfig $child $loss $stream
                    }
                    default {
                        # puts $stream "Unhandled Notebook page child: $child"
                    }
                }
            }
        }
        for {set index 0} {$index < [expr [llength [$panedwindow panes]]-1]} \
                {incr index} {
                    puts $stream "sash [string range [winfo parent $pane] $loss end] $index [$panedwindow sash coord $index]"
                }
    }
    
    proc SaveContainer {winId loss stream} {
        global helperTable
        set helperId $helperTable($winId,whichHelper)
        puts $stream "container [string range [winfo parent $winId] $loss end]"
        puts $stream $helperId
        # substitute <cr>s so entry goes on one line
        # not a toplevel #puts $stream [StripCrs [wm title $winId]]
        # not a toplevel #puts $stream [wm geometry $winId]
	
# If helper includes a PrepareSaveString command, call it. 1st arg is 
# expanded before executing helper namespace so window Id is copied from local 
# variable.
	namespace eval ::$helperId set winId $winId {;
	    if {[llength [info procs PrepareSaveString]]} {
		PrepareSaveString $winId
	    }
	}
        if {[info exists helperTable($winId,status)]} {
            puts $stream [StripCrs $helperTable($winId,status)]
        } else {
            puts $stream {}
        }
    }
    
    proc LoadView {} {
	variable currentNode
        set HelperStateFileName [ChooseFile Displays.shf \
                "Open view specification file" 0]
        if {[llength $HelperStateFileName]} {
            LoadSHF $currentNode $HelperStateFileName
        }
    }
    
    proc LoadSHF {currentNode oldPath} {
        global mimeSquirter simtmpdir
        global helperTable nameOfHelperStateFile errorInfo
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
        
        set nameOfHelperStateFile($currentNode) $oldPath
        do_in_editor AttackGlobalVariable nameOfHelperStateFile($currentNode) \
	    ($currentNode) $oldPath
        set stream [NetOpen $metaFile r]
        
        if {[string equal mre $origin]} {
            LoadViewFile $currentNode $stream $origVersion
        } elseif {[string equal many_windows $origin]}  {
            # assume that it is an shf made by the multiple window run env
            destroy $dp0.notebook; #what if there is an error in the file delete MRE, rebuild
            AddNotebook $dp0
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
                if {$origVersion<4.0} {
                    set oldStatus [LoseDTRef $oldStatus]
                }
                set helperTable($winId,status) [RestoreCrs $oldStatus]
                if {[catch {SystemHelperCall $helperId $currentNode \
				Restore $winId}]} {
                    DeleteHelperCurrentContainer
                    ShowMessage "Problem restoring helper" warning $errorInfo \
                            ok
                } else {
                    ChildrenFocusParent $winId
                }
            }
            $dp0.notebook raise [lindex [$dp0.notebook pages] 0]
            
        } else  {
            ShowMessage Error error "Unknown display configuration file format $origin" ok
        }
        close $stream
    }
    
    proc LoadViewFile {currentNode stream origVersion} {
        global helperTable
        variable dp0
        
        destroy $dp0.notebook
        set mainframe $helperTable($currentNode,whichRunEnv).mainframe
        # read and set .mre position and size
        gets $stream line
        scan $line "%i %i %i %i" x y width height
        wm geometry $helperTable($currentNode,whichRunEnv) \
                ${width}x${height}+${x}+${y}
        
        gets $stream line
        scan $line "%i %i" x y;
        [$mainframe getframe].mainpw sash place  0 $x $y
        
        gets $stream line
        scan $line "%i %i" x y
        [$mainframe getframe].mainpw.controlPane.panedwindow sash place  0 $x $y
        
        while {[gets $stream line] >= 0} {
            switch [scan $line %s] {
                container {
                    LoadContainer $currentNode $stream $line $origVersion
                }
                panedwindow {
                    #%puts $stream "panedwindow $panedwindow [$panedwindow cget -orient]"
                    scan $line "%s %s %s" widget path orient
                    if {$origVersion<4.0} {
                        set path [LoseTLRef $path]
                    }
                    panedwindow $dp0.$path -orient $orient
                    #set containerId [winfo parent $path]
                    #ShowMessage debug info "containerId $containerId" ok
                    #$notebook raise $pageId; # or $panedwindow sash place won't work
                    pack $dp0.$path -expand yes -fill both
                }
                pane {
                    #%puts $stream "pane $pane"
                    scan $line "%s %s" widget tail
                    if {$origVersion<4.0} {
                        set tail [LoseTLRef $tail]
                    }
                    set path $dp0.$tail
                    frame $path -highlightcolor black  -highlightthickness 1
                    set panedwindow [winfo parent $path]
                    $panedwindow add $path
                    bind $path <Button-1> "+::RunEnv::SetCurrentContainer %W"
                    bind $path <Button-3> \
                            "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
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
                    [winfo parent $pageId] select $pageId
                    update
                    #ShowMessage debug info "$panedwindow sash place $index $sashx $sashy \n\
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
		    bind $path <<NotebookTabChanged>> \
			[list ::RunEnv::PageRaiseCmd $path]
        
                    set containerId [winfo parent $path]
                    #ShowMessage debug info "containerId $containerId" ok
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
                    
                    #ShowMessage debug info "$widget $notebook $pageId $pagecaption" ok
		    set newFr [frame $notebook.f$pageId]
                    $notebook add $newFr -text $pagecaption \
			;#-raisecmd [list ::RunEnv::PageRaiseCmd $containerId.notebook $pageId]
                    # page raised below before any panes so that must be moved todo                 -raisecmd [list ::RunEnv::PageRaiseCmd $notebook $pageId]
                    bind $newFr <Button-1> "+::RunEnv::SetCurrentContainer %W"
                    bind $newFr <Button-3> \
                            "+::RunEnv::SetCurrentContainer %W; tk_popup .pageContextMenu %X %Y"
                    #$notebook raise $pageId
                    #catch {$notebook raise $pageId}; # or $panedwindow sash place won't work but panes nonexistant
                    
                }
                default {
                    # puts $stream "Unhandled mre element"
                }
            }
        }
        $dp0.notebook select [lindex [$dp0.notebook tabs] 0]
    }
    
    proc LoseTLRef {path} {
        if {[string last .mre.mainframe.frame.mainpw.mainDisplayPane. $path 43]} {
            return $path
        } else {
            return [string range $path 44 end]
        }
    }
    
    proc LoadContainer {node stream line origVersion} {
        global helperTable
        variable dp0
        
        #ShowMessage debug info "LoadContainer: stream $stream, line $line" ok
        scan $line "%s %s" item containerId
        if {$origVersion<4.0} {
            set containerId [LoseTLRef $containerId]
        }
        
        gets $stream helperId
        #ShowMessage debug info "LoadContainer: $item $containerId; helperId $helperId" ok
        set winId [NewHelperInWindow $dp0.$containerId $helperId ""]
        gets $stream oldStatus
        if {$origVersion<4.0} {
            set oldStatus [LoseDTRef $oldStatus]
        }
        set helperTable($winId,status) [RestoreCrs $oldStatus]
        SystemHelperCall $helperId $node Restore $winId
        #bind $winId <Destroy>  "kill_helper_window $winId"
        ChildrenFocusParent $winId
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
    
    proc UniqueId {basename pagenames} {
        # basename is the root of the Id, numbers after / are appended to it
        # pagenames is the list of existing names
        set i 1
        while {[lsearch -regexp $pagenames $basename$i] > -1} {
            incr i
        }
        return $basename$i
    }
} ;# end of namespace RunEnv

proc NewMreHelperWindow {node helperId helperTitle} {
    global helperTable
    variable ::RunEnv::dp0;    # display pane
    
    #ShowMessage debug info "NewMreHelperWindow: helperId $helperId; helperTitle $helperTitle" ok
    
    # if it is a $helperTable(VariableList) usu ModelInspector and one already
    # exists, destroy the existing (())don't make a new one, as only one is allowed
    if {[string match $helperTable(VariableList) $helperId]} {
        foreach winIdHelper [array name helperTable *,whichHelper] {
            if {[string match $helperTable($winIdHelper) $helperId]} {
                scan $winIdHelper {%[^,]} winId
                if {[string equal $node $helperTable($winId,whichModel)]} {
                    kill_helper_window $winId
                }
            }
        }
    }
    
    # put the RunControl in its own pane
    set def 0
    
    ## Mods my Jasper: Because of quirky behaviour under linux, the standard tools
    ## must each get a new frame (bag) whenever they are rebuilt
    switch $helperId \
            $helperTable(RunControl) {
                set bag $RunEnv::runControlFrame($node).bag
                if {[winfo exists $bag]} {
                    destroy $bag
                }
                pack [frame $bag] -fill both -expand on
                set winId $bag
                set ::RunEnv::runControlWindId($node) $bag
            } \
            $helperTable(VariableList) {
                set bag $RunEnv::variableListFrame($node).bag
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
    }
    
    return $winId
}

proc RaiseMREFor {node} {
    global helperTable

    MyRaise $helperTable($node,whichRunEnv)
}

proc MyRaise {top} {
    global tcl_platform

    wm deiconify $top
    raise $top
    if [string match Darwin $tcl_platform(os)] {
       tclAE::send -s misc actv
    }
}
# A top level window to contain the helpers
# overrides mre.tcl Makemre
proc Makemre { node } {
    return [RunEnv::Create $node]
}

