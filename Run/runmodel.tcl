# Simile source code file: Run/runmodel.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file loads all procedures, and sets up the model execution environment.
#

source ../Run/graphs.tcl
source ../Run/utility.tcl
source ../Run/params.tcl
source ../Run/hai2mmii.tcl

# mre.tcl has to be loaded after the other Tcl procedures are defined

source ../Run/mre.tcl

proc MakeHelperMenu {} {
    global custom tcl_platform SIMILE_PATH
    set fm [menu .helpers -tearoff 0]

    $fm add command -label "Load" -command LoadView
    $fm add command -label "Save" -command SaveView
    $fm add command -label "Clear" -command ClearView
    $fm add command -label "Close" -command KillHelpers
    $fm add command -label "Parameters..." -command MessCurrentFileParams
    set oldDir [pwd]
    cd $SIMILE_PATH/IOTools
    AddHelperSublist $fm "Add tool" 2
    set ioDir [file join $custom(prefDir) IOTools]
#do_in_editor puts "locals in $ioDir"
# test for version file tells us if user dir is same as installation dir --
# cannot compare strings as different strings may mean same dir.
# If it is, do not load IO tools again as redefinition errors will arise
    if {[file exists $ioDir] && ![file exists ../version]} {
	cd $ioDir
	AddHelperSublist $fm.sub2 "Local" l
    }
    cd $oldDir
    MakeScriptHelpers
}

proc ListMenuContents {menu} {
    set mList {}
    for {set item 0} {$item <= [$menu index last]} {incr item} {
	set type [$menu type $item]
	set entry [list $type [$menu entrycget $item -label]]
	switch $type {
	    command {
		lappend entry [$menu entrycget $item -command]
	    } cascade {
		set subMenu [$menu entrycget $item -menu]
		lappend entry [ListMenuContents $subMenu]
	    }
	}
	lappend mList $entry
    }
    return $mList
}

proc MessFileParams {topNode parent} {
    global runState
    switch -exact -- [FileParamDialogue $topNode $parent 1] {
	-1 {
#	    StartNow $topNode stop
	    set runState($topNode,modelRunning) 1
	} 1 {
	    set needsAReset [expr $runState($topNode,modelRunning)<3]
	    if {$needsAReset} {
		set runState($topNode,modelRunning) 2
		StartNow $topNode reset
	    }
	}
	
    }
    $runState($topNode,cnvs) itemconfigure 1 -fill [RestingColour $topNode]
}

proc MessCurrentFileParams {} {
    MessFileParams $::myNode {}
}

proc RestingColour {node} {
    global runState
    return [lindex "white grey red black purple" $runState($node,modelRunning)]
}
    
proc GetNodeFromFocus {} {
    global myNode
    return $myNode
}

proc ClassFromKey {kv} {
    return [regsub -all \\. $kv _dot_]
}

# OK I have been having problems with people duplicating IO tool programs
# and not changing the key values, thus allowing one to overwrite the other.
# So one day, IO tools will not include a namespace spec, but this code
# will load them into one, so they should still use [namespace code ...] to
# make callbacks.

proc AddHelperSublist {fm title ct} {
    global helperTable
#puts "Adding helpers in [pwd]"
    set m [menu $fm.sub$ct -tearoff 0]
    set nct 0
    set helperList [glob -nocomplain *.tcl]
    foreach helperApp [lsort $helperList] {
        if {[catch {source $helperApp} wibble]} {
            # done at startup -- make sure dialog is not concealed
            wm withdraw .
# do it after idle so this process is not hung till user responds
	    if {[string equal abort \
		 [Query [list iotool_load_fail [pwd]/$helperApp $::errorInfo] \
		      warning helpers {} abort]]} {
		return abort
	    }
	    continue
        }
	if {[info exists keyValue]} {
# This is an old-style helper, so create object wrapper for it
	    set newHelperClass [ClassFromKey $keyValue]
	    set ::gKeyValue $keyValue ;# make global so decl picks it up
	    itcl::class similescript::$newHelperClass {
		inherit OldStyleHelper
		proc KeyValue {} [list return $gKeyValue]
		public proc Identify {} {return [[KeyValue]::identify]}
		constructor {modelWin winTitle {state {}}} {
# perverse extra body because base class constructor has args
		    OldStyleHelper::constructor $modelWin $winTitle $state
		} {}
		if {[llength [namespace which ${gKeyValue}::clear]]} {
		    # override do-nothing clear in base class defn
		    public method Clear {} {
			::[KeyValue]::clear $winId
		    }
		}
		if {[llength [namespace which ${gKeyValue}::GetCanvas]]} {
		    public method GetCanvas {} {
			::[KeyValue]::GetCanvas $winId
		    }
		    public method Print {} {
			PrintRandomCanvas [GetCanvas]
		    }
		    public method CopyToClipboard {} {
#			if {[string match windows $tcl_platform(platform)]} {
			    CopyCanvasToWindowsClipboard [GetCanvas] 0
#			}
		    }
		} ;# else use inherited warning message
		if {[llength [namespace which ${gKeyValue}::Print]]} {
		    # override canvas-based print above
		    public method Print {} {
			::[KeyValue]::Print $winId
		    }
		}
		if {[llength [namespace which ${gKeyValue}::CopyToClipboard]]} {
		    # override canvas-based copy above
		    public method CopyToClipboard {} {
			::[KeyValue]::CopyToClipboard $winId
		    }
		}
		if {[llength [namespace which \
				  ${gKeyValue}::PrepareSaveString]]} {
		    public method PrepareSaveString {} {
			::[KeyValue]::PrepareSaveString $winId
		    }
		}
	    }
	    unset keyValue
	}
	if {[info exists newHelperClass]} {
	    set action [similescript::${newHelperClass}::Identify]
	    set actions [list {Run control} {Explorer (Tile version)} \
		    {PEST interface} {Plotter} {Slider control} {Data table}]
	    if {[set posn [lsearch $actions $action]]>-1} {
		set classIdx [lindex {RunControl VariableList pestInterface \
			       Plotter SliderControl TableViewer} $posn]
		set helperTable($classIdx) $newHelperClass
	    }
	    lappend entries [list $newHelperClass $action [tr. $action]]
	    unset newHelperClass
	}
    }
    if {[info exists entries]} {
	foreach pair [lsort -nocase -index 2 $entries] {
	    $m add command -label [lindex $pair 2] \
		-command [concat CreateHelperWindow [lrange $pair 0 1]]
	}
    }
    foreach subDir [lsort -nocase [glob -nocomplain *]] {
        if [file isdirectory $subDir] {
            cd $subDir
            if {[string equal abort [AddHelperSublist $m $subDir $nct]]} {
		return abort
	    }
            cd ..
            incr nct
        }
    }
    if {[string equal none [$m index 0]]} {
	destroy $m
    } else {
	$fm add cascade -label $title -menu $m
    }
}

proc SystemHelperCall {inst node act args} {
    global myNode helperTable
    if {[info exists myNode]} {
	set nodeForFocus $myNode
    }
    set myNode $node
    set helperTable(beingCalled) $inst
    eval $inst $act $args
    set helperTable(beingCalled) {}
    unset myNode
    if {[info exists nodeForFocus]} {
	set myNode $nodeForFocus
    }
}

proc CreateHelperWindow {helperId helperTitle {state {}}} {
    global classTable helperTable

    set modelObj $classTable(run,[GetNodeFromFocus])
    set inst [UniqueId helper]
    set helperTable(beingCalled) $inst
    similescript::$helperId $inst $modelObj $helperTitle $state
    set helperTable(beingCalled) {}
    if {[PrefValue custom(helperManager) helperManager]} {
	set winId [$inst cget -winId]
	::RunEnv::SetCurrentContainer [winfo parent $winId]
	::RunEnv::ChildrenFocusParent $winId
    }
    return $inst
#rest should be done by constructor
}

# This is only called by old-style helpers now
proc GrabClicks {winId} {
    global helperTable

    set inst $helperTable($winId,whichInstance)
    set helperTable([$inst GetNode],current) $inst
}

# This is only called by old-style helpers now
proc ReleaseClicks {winId} {
    global helperTable

    set inst $helperTable($winId,whichInstance)
    unset helperTable([$inst GetNode],current)
}

# Two more old-style wrapper funx
proc GetState {winId} {
    global helperTable
    $helperTable($winId,whichInstance) cget -State
}

proc SetState {winId newState} {
    global helperTable custom

    $helperTable($winId,whichInstance) configure -State $newState
    if {[PrefValue custom(helperManager) helperManager]} {
	::RunEnv::PreserveSetup 1
    }
}

proc ProdObj {topNode nodeId caption} {
    global helperTable
    if {![catch {set inst $helperTable($topNode,current)}]} {
# Supplied caption is submodel hierarchy from diagram (unless I get rid of that)
# -- however we need hierarchy of base component if this is a ghost, so...
	set useCapt [GetCompProperty $topNode Caption $nodeId]
# allow all components to be clicked as helpers might want other info
# than just values
#	switch -regexp [GetCompProperty $topNode Type $nodeId] {
#	    REAL|INTEGER|FLAG|ENUMERATED {
	MyRaise [winfo toplevel [$inst cget -winId]]
	SystemHelperCall $inst $topNode Click $useCapt
#	    } default {
#		ShowMess "Clicked on $caption" error \
#                    "This component cannot be selected for an I/O tool because it has no associated value." ok
#	    }
#	}
# Now record helper's interest so values can be saved from execution thread
	return 1
    } else {
	return 0
    }
}

# This is used for items on IO tool canvases -- model components have eqnpopups
proc CanvasBindPopup {canvas widget keywd} {
    $canvas bind $widget <Enter> [list QueuePopup AddWidgetPopup %X %Y $keywd]
    $canvas bind $widget <Leave> RemovePopup
}

# args are not used -- when binding to a table wigdet we cannot avoid getting
# the item name on the end of the call

proc ExDestroyHelpers {node} {
    global helperTable
    if {[info exists helperTable($node,whichRunEnv)]} {
        ::RunEnv::Destroy $node
    } else {
        KillHelpers $node
    }
    set runState($node,modelRunning) 0
}

proc KillHelpers {node} {
    global helperTable
    foreach helperInst [array names helperTable *,whichInstance] {
	if {[string equal $node [$helperTable($helperInst) GetNode]]} {
	    itcl::delete object $helperTable($helperInst)
	}
    }
}

proc ClearView {} {
    global helperTable myNode

    foreach {name inst} [array get helperTable *,whichInstance] {
	if {[string equal $myNode [$inst GetNode]]} { 
	    $inst Clear
	}
    }
}

proc SaveView {} {
    global helperTable simtmpdir runState

    set topNode [GetNodeFromFocus]
    set helperTable($topNode,stateName) \
	[ChooseFile iotools.shf [tr. "Save view specification file"] 1 $topNode]
    if {[llength $helperTable($topNode,stateName)]} {
	set metaList {}
        foreach displayBox [array name helperTable *,whichInstance] {
            set helperId $helperTable($displayBox)
	    set winId [$helperId cget -winId]
            if {[string equal $topNode [$helperId GetNode]] && \
		    ![string match $winId $runState($topNode,helperId)]} {
                lappend metaList [namespace tail [$helperId info class]]
                lappend metaList [wm title $winId]
                lappend metaList [wm geometry $winId]
                set clickedPaths {}
		$helperId PrepareSaveString
		lappend metaList [$helperId cget -State]
            }
        }
	MimifySHF $metaList $helperTable($topNode,stateName) many_windows
    } else {
	unset helperTable($topNode,stateName)
    }
}

if {![info exists simplify]} {
package require mime
}

proc MimifySHF {inString outFile origin} {
    global env
    set PartType "application/x-simile"
    set Description "Simile I/O tool configuration file"
    set style attachment
# for compatibility with earlier versions we replace nl's with \n and put each
# item on a new line -- this messes real \ns in annotation texts etc. Do
# something else as of v6.
    set preppedString [join [StripCrs $inString] \n]
    set newMime [mime::initialize -canonical $PartType \
		     -param {charset "utf-8"} \
		     -header [list "Content-Disposition" $style] \
		     -header [list "Content-Description" $Description] \
		     -header [list "Simile-Version" $env(SIMILE_VERSION)] \
		     -header [list "Simile-Origin" $origin] \
		     -string [encoding convertto utf-8 $preppedString]]
    set stream [NetOpen $outFile w]
    fconfigure $stream -translation binary
    mime::copymessage $newMime $stream
    # clean everything up
    close $stream
    mime::finalize $newMime
#    file delete $inFile
}

proc LoadView {} {
    global helperTable errorInfo
    set topNode [GetNodeFromFocus]
    set helperTable($topNode,stateName) \
	[ChooseFile iotools.shf [tr. "Open view specification file"] 0 $topNode]
    if {[llength $helperTable($topNode,stateName)]} {
	CreateView $topNode $helperTable($topNode,stateName)
    }
}

proc SHFtoList {oldPath} {
    global mimeSquirter simtmpdir

    if {[catch {
	set multiT [mime::initialize -file $oldPath]
	set origVersion [mime::getheader $multiT Simile-Version]
	set origin [mime::getheader $multiT Simile-Origin]
#	if {$origVersion<5.7} {
	    set metaFile [file join $simtmpdir temp_in.shf]
	    set mimeSquirter [NetOpen $metaFile w]
	    fconfigure $mimeSquirter -translation binary
	    mime::getbody $multiT -command SquirtMime -blocksize 256
	    set stream [NetOpen $metaFile r]
	    fconfigure $stream -encoding utf-8
	    set metaList [RestoreCrs [split [read $stream] \n]]
	    close $stream
#	} else {
# this much simpler version has problems, perhaps with os-specific line ends
#	    set metaList [RestoreCrs [split [encoding convertfrom utf-8 \
						 [mime::getbody $multiT]] \n]]
#	}
    } syndrome]} {
	#do_in_editor puts "MIME open failed: $syndrome"
	set metaFile $oldPath
	set origVersion 0.0
	set stream [NetOpen $metaFile r]
	# check for run env that made the shf
	set metaList [RestoreCrs [split [read $stream] \n]]
	if {[llength [lindex $metaList 0]]==4} {
	    set origin mre
	} else {
	    set origin many_windows
	}
	close $stream
    }
    return [concat [list $origin $origVersion] $metaList]
}

proc PullMember {tgtRef} {
    upvar 1 $tgtRef tgt

    upvar 1 metaList listRef
    if {![llength $listRef]} {
	return -1
    }
    set tgt [lindex $listRef 0]
    set listRef [lrange $listRef 1 end]
    return [string length $tgt]
}

proc CreateView {node oldPath} {
    global mimeSquirter simtmpdir errorInfo helperTable
    set SHFContents [SHFtoList $oldPath]
    set origin [lindex $SHFContents 0]
    set origVersion [lindex $SHFContents 1]
    set metaList [lrange  $SHFContents 2 end]
    if {[string equal mre $origin]} {
	set response [Query wrong_layout question helpers {} {yes no cancel}]
	switch $response {
	    yes {
		raise [Makemre $node]
		RunEnv::LoadViewFile $node $metaList $origVersion
	    } no {
		LoadMREFormatView $node $metaList $origVersion
	    } cancel {
	    }
	}
	return
    }
    
    while {[PullMember helperId] >= 0} {
	PullMember helperTitle
	PullMember geometry
	PullMember oldStatus

	set inst [ReinstateHelper $origVersion $oldStatus \
		      $helperId $helperTitle]
	if {[string equal abort $inst]} {
	    break
	} elseif {![string equal more $inst]} {
	    wm geometry [$inst cget -winId] $geometry
	}
    }
    close $stream
}

proc ReinstateHelper {origVersion oldStatus helperId helperTitle} {
    if {$origVersion<4.0} {
	set oldStatus [LoseDTRef $oldStatus]
    } 
    if {$origVersion<5.0} {
	set helperId [ClassFromKey $helperId]
    }
    set addClass [itcl::find class ::similescript::$helperId]
    if {![llength $addClass]} {
	return [Query [list missing_iotool_type $helperId] \
		    warning helpers {} abort]
    }
    if {[catch {CreateHelperWindow $helperId $helperTitle $oldStatus} inst]} {
	if {[string equal aborted $inst]} {
	    return abort
	}
	return [Query [list iotool_restore_fail [${addClass}::Identify] \
			   $::errorInfo] warning helpers {} abort]
    } else {
	return $inst
    }
}

proc LoadMREFormatView {node metaList origVersion} {
    global helperTable
    while {[PullMember helperId] >= 0} {
        PullMember oldStatus
	set inst [ReinstateHelper $origVersion $oldStatus $helperId {}]
	if {[string equal abort $inst]} {
	    break
	}
    }
}

proc LoseDTRef {statusLine} {
    foreach elt $statusLine {
	if {[llength $elt]>1} {
	    lappend result [LoseDTRef $elt]
	} elseif {[string last /Desktop/ $elt 8]} {
	    lappend result $elt
	} else {
	    lappend result [string range $elt 8 end]
	}
    }
    return $result
}

proc UpdateIfFreezy {} {
    global updateLastDone
    if {$updateLastDone < [clock clicks -milliseconds]-40} {
	update
	set updateLastDone [clock clicks -milliseconds]
    }
}

proc ShiftDisplays {node payload current display} {
    global helperTable runState sendvars

    if {[catch {
	$helperTable(RunControl)::UpdateBar $node $current blue
	UpdateIfFreezy
	set result [TellAllHelpers $node $payload Display $current $display 1]
	
	if {$runState($node,splimit)} {
	    set minStep [expr {1000/$runState($node,speedLimit)}]
	    set extraDelay [expr {$minStep-([clock clicks -milliseconds]-$runState(pacer))}]
	    after $extraDelay [list set sendvars($node,busy) 1]
	    set sendvars($node,busy) 0
	    vwait sendvars($node,busy)
	    set runState(pacer) [clock clicks -milliseconds]
	}
    }]} {
	puts $::errorInfo
	return 1
    } else {
	return $result
    }
}

proc TellAllHelpers {node payload fun args} {
    global helperTable myNode subbedPlots runState

    if {[info exists myNode]} {
	set nodeForFocus $myNode
    }
    set handlesForFocus [array get subbedPlots]
    array unset subbedPlots
    array set subbedPlots $payload
    set myNode $node
    set failure 0
    set doScrog [expr [string equal Display $fun] && \
		     [info exists helperTable(pestInterface)]]
    if {$doScrog} {
	$helperTable(pestInterface)::ScrogOutputs [lindex $args 0]
    }
    foreach helperInst [array names helperTable *,whichInstance] {
	set inst $helperTable($helperInst)
	if {[string equal $node [$inst GetNode]]} {
	    set helperTable(beingCalled) $inst
	    if {[catch {eval $inst $fun $args} HelpErr]} {
		puts $::errorInfo
		Query [list iotool_run_fail [[$inst info class]::Identify] \
			   $fun $::errorInfo [$inst cget -State]] \
		    warning helpers {} ok
		set failure 1
	    }
	    set helperTable(beingCalled) {}
	}
    }
# pre-object version
#    foreach displayBox [array name helperTable *,whichHelper] {
#        scan $displayBox {%[^,]} winId
#	if {[string equal $node $helperTable($winId,whichModel)]} {
#	    set helperTable(beingCalled) $winId
#	    set helperId $helperTable($displayBox)
#	    if {[catch {eval {${helperId}::$fun $winId} $args} HelpErr]} {
#		start_in_editor BuildProblem "Error running I/O tool" warning \
                    "I/O tool \"[${helperId}::identify]\" raised a problem during model execution. This occurred while doing the $fun operation. The model has been paused. To continue running it you may have to kill this helper's display.\nHere is the error log for debugging:\n$::errorInfo" \
		    helpers none none
#		set success 0
#	    }
#	}
#    }
#    set helperTable(beingCalled) {}
    if {$doScrog} {
	eval WriteLogs $node $args

	foreach {callback nodes} [array get runState *,scriptReqs] {
	    set runControlID [string range $callback 0 end-11]
	    set cbCmd [list ReceiveValues $runControlID [lindex $args 0]]
	    # 2nd arg should be time
	    foreach datum $nodes {
		lappend cbCmd [GetModelValue $datum]
	    }
	    eval $cbCmd
	}
    }
    if {[info exists nodeForFocus]} {
	set myNode $nodeForFocus
    }
    array unset subbedPlots
    array set subbedPlots $handlesForFocus
    return $failure
}

# Other stuff related to reorganization. This only used if in a separate process
#proc KickOff {nMyNode nSimtmpdir nSender nRunHow readPipe} {
#    global myNode ;# a stopgap, we shouldn't need it
#    global custom runState simtmpdir sender tcl_platform runHow
#
#    set myNode $nMyNode
#    set simtmpdir $nSimtmpdir
#    set sender $nSender
#    set runHow(return) $nRunHow
#
#    if {[string equal windows $tcl_platform(platform)]} {
#	source ../System/lib/Extras/prntcanv.tcl
#	# needed to copy helper canvasses
#	package require dde
#	dde servername exec_for_$myNode
#	wm iconbitmap . -default ../Run/simile16.ico
#    } else {
#	tk appname exec_for_$myNode
#    }
#    set custom(prefDir) [file dirname $nSimtmpdir]
##    set env(LD_LIBRARY_PATH) [file dirname [info library]]
##    ShowMess debug info $env(LD_LIBRARY_PATH) ok
#    load_c_stub_1
#    load_c_stub_2
#
#    set runState($nMyNode,modelRunning) 0
#    LoadIconImages
#    if {![info exists runHow(where)]} {
#	MakeHelperMenu
#    }
#    wm withdraw .
#
#    if {[string equal get_data $readPipe]} {
#	fileevent stdin readable EatInput
#    }
#    do_in_editor set runState($myNode,modelReady) 1
#}
#
proc EatInput {} {
    gets stdin blether
    eval [join $blether \n]
}

proc GetShortVals {topNode plName limit} {
    if {[RunningInC $topNode]} {
	if {[catch {GetHandle $topNode $plName} hdl]} {
	    set text novalue
	    set count 0
	} else {
	    set count [count_values $hdl]
	    if {$count<$limit/5} {
		set text [extract_list $hdl $count]
	    } else {
		set tail [expr {$limit/10}]
		set text [concat [extract_list $hdl $tail] \
			      [extract_list $hdl -$tail]]
	    }
	    ReleaseHandle $topNode $hdl
	}
    } else {
	set text [lindex [GetCompExecData $topNode Value $plName] 0]
	set count [ShrinkValueList text $limit]
    }
    catch {GetCompProperty $topNode Type $plName} iType
    if {[string equal REAL $iType]} {
	set precis [PrefValue custom(popupPrecision) popupPrecision]
	if {$precis} {
	    set text [FormatVals %.${precis}g $text]
	}
    }
    if {![string equal novalue $text]} {
	set text [PrettifyValList [TransEnums [GetCompProperty $topNode Trans \
						   $plName] $text]]
    }
    return [list $count $text]
}

proc FormatVals {fmt list} {
    if {[llength $list]==1} {
	return [SafeFormat $fmt $list]
    } else {
	set res {}
	foreach {ind elt} $list {
	    lappend res $ind [FormatVals $fmt $elt]
	}
	return $res
    }
}

proc SafeFormat {fmt val} {
    if {$val==$val} {
# nan raises error on format and is only real value that does not equal itself
	return [format $fmt $val]
    } else {
	return $val
    }
}
    
############################## snap: start ###################################
proc MakeSnapText {w} {
    text $w.text -yscrollcommand "$w.yscroll set" -setgrid true \
            -xscrollcommand "$w.xscroll set" \
            -width 30 -height 20 -wrap none\
            -tabs {5c right 6.8c right 8.6c right 10.4c right}
    $w.text tag configure colour1 -background #ff9090 -foreground black
    $w.text tag configure colour2 -background #ffffff -foreground blue \
            -font {arial 10 bold}
    $w.text tag configure colour3 -font {arial 9 bold}
    $w.text tag configure colour4 -background #ffffff -foreground red \
            -font {arial 10 bold}
}

proc snap {topNode node} {
    global runState
    
    set full_label [GetCompProperty $topNode Caption $node]
    set w .snap$node
    set last_slash [string last / $full_label]
    set start_label [expr $last_slash+1]
    set end_submodels [expr $last_slash-1]
    set submodels [string range $full_label 0 $end_submodels]
    set label [string range $full_label $start_label end]
    if {[winfo exists $w]} { ;# do not allow two on same component
	UpdateSnap $w $label $submodels $topNode $node
	raise $w
	return $w
    }
    toplevel $w
    wm protocol $w WM_DELETE_WINDOW "unset runState(nst$w); unset runState(val$w); destroy $w"
    wm title $w "[BlankCrs $label] at time $runState($topNode,currentTime)"
    set tbItems [list \
		 [list save.gif "Save to file" \
		      [list SaveSnap $w $label $topNode]] \
		 [list refresh.gif "Update" \
		      [list UpdateSnap $w $label $submodels $topNode $node]] \
		 [list reel.gif "Log to file" \
		      [list LogSnap $w $label $submodels $topNode $node]]]
    ::graphtools::MakeToolBar $w $tbItems
    MakeSnapText $w
    scrollbar $w.yscroll -command "$w.text yview"
    pack $w.yscroll -side right -fill y
    scrollbar $w.xscroll -orient horiz -command "$w.text xview"
    pack $w.xscroll -side bottom -fill x
    pack $w.text -expand yes -fill both
    
    if {[UpdateSnap $w $label $submodels $topNode $node]} { ;# raised error
	destroy $w
	return 
    }
    return $w ;# for scripting
}

proc UpdateSnap {w label submodels topNode node} {
    global runState

#    $w.text delete 1.0 end
# very slow for some reason! try deleting and making anew...
    set oldX [lindex [$w.text xview] 0]
    set oldY [lindex [$w.text yview] 0]
    destroy $w.text
    MakeSnapText $w
    pack $w.text -expand yes -fill both

    set rawVals [GetCompExecData $topNode Value $node]
    if {[string equal novalue $rawVals]} {
	return 1
    }
    set v1 [set runState(val$w) [TransEnums [GetCompProperty $topNode Trans \
						 $node] [lindex $rawVals 0]]]
    catch {GetCompProperty $topNode Type $node} iType
    if {[string equal REAL $iType]} {
	set precis [PrefValue custom(snapPrecision) snapPrecision]
	if {$precis} {
	    set runState(val$w) [FormatVals %.${precis}g $v1]
	}
    }
    set runState(nst$w) 0
    while {[llength $v1]>1} {
	incr runState(nst$w)
	set v1 [lindex $v1 1]
    }
    
    $w.text insert end "Variable "
    $w.text insert end "$label\n" colour3
    if {[string length $submodels]>0} then {
        $w.text insert end "in submodel "
        $w.text insert end "$submodels\n" colour3
    }
    $w.text insert end "at time "

    $w.text insert end "$runState($topNode,currentTime)\n" colour3
    $w.text insert end "[clock format [clock seconds]]\n"
    $w.text insert end "Maxlevel=$runState(nst$w)\n"
    # check size
    set hdl [GetHandle $topNode $node]
    set count [count_values $hdl]
    ReleaseHandle $topNode $hdl
    if {$count>=262144} {
	$w.text insert end [tr. {There are too many values to display, but you can still save them to file or log them.}]\n
	return 0
    }
    if {$runState(nst$w)==0} then {
        $w.text insert end $runState(val$w)
    } elseif {$runState(nst$w)==1} then {
        snap_down1 $w $runState(val$w)
    } elseif {$runState(nst$w)==2} then {
        snap_down2 $w $runState(val$w)
    } else {
        snap_down3 $w $runState(val$w)
    }
    $w.text yview moveto $oldY
    $w.text xview moveto $oldX
    wm title $w "[BlankCrs $label] at time $runState($topNode,currentTime)"
    return 0
}

proc snap_down1 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            $w.text insert end $value colour2
        } else {
            $w.text insert end {   }
            $w.text insert end $value
            $w.text insert end \n
        }
        incr i
        if {$i==2} then {set i 0}
    }
}


proc snap_down2 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            $w.text insert end $value colour2
        } else {
            if {[llength $value]>1} then {
                $w.text insert end {    }
                set j 0
                foreach val $value {
                    if {$j==0} then {
                        $w.text insert end $val colour3
                    } else {
                        $w.text insert end { }
                        $w.text insert end $val
                        $w.text insert end {   }
                    }
                    incr j
                    if {$j==2} then {set j 0}
                }
                $w.text insert end \n
            } else {
                $w.text insert end {   }
                $w.text insert end $value
                $w.text insert end \n
            }
        }
        incr i
        if {$i==2} then {set i 0}
    }
}

proc snap_down3 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            set first_value $value
        } else {
            set j 0
            foreach val $value {
                if {$j==0} then {
                    $w.text insert end $first_value colour2
                    $w.text insert end {  }
                    $w.text insert end $val colour4
                    $w.text insert end {    }
                } else {
                    set k 0
                    foreach v $val {
                        if {$k==0} then {
                            $w.text insert end $v colour3
                        } else {
                            $w.text insert end { }
                            $w.text insert end $v
                            $w.text insert end {   }
                        }
                        incr k
                        if {$k==2} then {set k 0}
                    }
                    $w.text insert end \n
                }
                incr j
                if {$j==2} then {set j 0}
            }
        }
        incr i
        if {$i==2} then {
            $w.text insert end \n
            set i 0
        }
    }
}

proc SaveSnap {w vname topNode} {
    set filename [ChooseFile snap.csv [tr. "Save snapshot data as.."] 1 \
		      $topNode]
    if {![llength $filename]} return
    SaveSnapToFile $w $vname $filename
}

proc SaveSnapToFile {w vname filename} {
    global runState
    set out [NetOpen $filename w]
    for {set idx 1} {$idx<=$runState(nst$w)} {incr idx} {
	puts -nonewline $out index${idx},
    }
    puts $out $vname
    SquirtLine $out {} $runState(val$w)
    close $out
}

proc LogSnap {w vname tree topNode node} {
    global runState

    if {[info exists runState(log$node)]} {
	StopLogging $w $topNode $node
    } else {
	set filename [ChooseFile snap.csv \
			  [format [tr. {Log data for %1$s as...}] $vname] 1 \
			       $topNode]
	if {![llength $filename]} return
	StartLogging $w $topNode $node $filename
    }
}

proc StopLogging {w topNode node} {
    global runState iconImages

    $w.bbframe.buttonBox itemconfigure 2 -image $iconImages(reel)
    close [lindex $runState(log$node) 1]
    unset runState(log$node)
}

proc StartLogging {w topNode node filename} {
    global runState iconImages

    $w.bbframe.buttonBox itemconfigure 2 -image $iconImages(noreel)
    set out [NetOpen $filename w]
    set lh time
    for {set idx 1} {$idx<=$runState(nst$w)} {incr idx} {
	puts -nonewline $out $lh
	set lh {}
	PutIndNo $out -$idx $runState(val$w)
	puts $out {}
    }
    set runState(log$node) [list $topNode $out]
}

proc WriteLogs {topNode time vname step} {
    global runState
    foreach logger [array names runState log*] {
	if {[string equal $topNode [lindex $runState($logger) 0]]} {
	    set curVals [GetModelValue [string range $logger 3 end]]
	    set str [lindex $runState($logger) 1]
	    puts -nonewline $str $time
	    PutValsOnly $str [lindex $curVals 0]
	    puts $str {}
	}
    }
}

proc PutValsOnly {str val} {
    if {[llength $val]==1} {
	puts -nonewline $str ,$val
    } else {
	foreach {idx sub} $val {
	    PutValsOnly $str $sub
	}
    }
}

proc PutIndNo {str deep val} {
    if {$deep<0} {
	set deep [expr $deep+1]
    }
    set newDeep $deep
    if {[llength $val]==1} {
	puts -nonewline $str ,$deep
    } else {
	foreach {idx sub} $val {
	    if {!$deep} {
		set newDeep $idx
	    }
	    PutIndNo $str $newDeep $sub
	}
    }
}

proc SquirtLine {str idcs val} {
    if {[llength $val]>1} {
	foreach {idx sub} $val {
	    SquirtLine $str $idcs$idx, $sub
	}
    } else {
	puts $str $idcs$val
    }
}

proc RecordRunParams {node} {
    global runState

    set runParams [list execTime [expr {$runState($node,expected_end) - \
				    $runState($node,remembered_start)}] \
		       timeUnit $runState($node,timeUnit) \
		       displayInt $runState($node,displayInt) \
		       intMethod $runState($node,intMethod)]
    foreach {value checkstate} {errLimit adapt speedLimit splimit \
				resetTo resetTo evtpause evtpause} {
	if {$runState($node,$checkstate)} {
	    lappend runParams $value $runState($node,$value)
	}
    }
# Keep all available phase info, we may have edited the model without runing it
    for {set phase 1} {$phase <= 8} {incr phase} {
	if {![info exists runState($node,update$phase)]} {
	    break
	}
	lappend params $runState($node,update$phase)
    }
    if {[info exists params]} {
	lappend runParams phaseList $params
    }
    set runState($node,runParams) $runParams
    prolog tk_run_settings_tweaked($node)
}

proc SetRunParams {node runParams} {
    global runState
    
    # some old ones omitted timeUnit etc so set defaults
    foreach {feature value} \
	{currentTime 0.0 timeUnit unit errLimit 0 speedLimit 0 \
	     resetTo 0 evtpause 0} {
	set runState($node,$feature) $value
    }
    set runState($node,timeUnit) unit
    set runState($node,currentTime) 0.0
    #ShowMess debug info set ok
    if {[string match execTime [lindex $runParams 0]]} {
	# no longer as simple as "array set runState $runParams"
	foreach {feature value} $runParams {
	    set runState($node,$feature) $value
	}
	set runState($node,phases) 0
	if {[info exists runState($node,phaseList)]} {
	    foreach phase $runState($node,phaseList) {
		incr runState($node,phases)
		set runState($node,update$runState($node,phases)) $phase
		set runState($node,prev_update$runState($node,phases)) $phase
	    }
	}
    } else { ;# old style
	set runState($node,execTime) [lindex $runParams 0]
	set runState($node,displayInt) [lindex $runParams 1]
	for {set others 2} {$others < [llength $runParams]} {incr others} {
	    set runState($node,update[expr $others-1]) [lindex $runParams $others]
	    set runState($node,prev_update[expr $others-1]) \
		[lindex $runParams $others]
	}
	set runState($node,phases) [expr $others-2]
	set runState($node,intMethod) Euler
    }
    foreach {value checkstate} {errLimit adapt speedLimit splimit} {
	if {$runState($node,$value)==0} {
	    unset runState($node,$value)
	}
	set runState($node,$checkstate) [info exists runState($node,$value)]
    }
    #puts [array get runState]
}

# modelRunning is a global variable that indicates the status of the model
# program: 0 = none, 1 = awaiting fixed params, 2 awaiting initialization,
# 3 = up to date, 4 = out of date

proc StartRun {node} {
    global runState window_info helperTable classTable projectParams sendvars
    # ShowMess debug info enter(start_run) ok
#    set runState($node,currentWin) $winId ;# enables rebuild from run control

    if {[info exists helperTable($node,whichRunEnv)]} {
	set fpParent $helperTable($node,whichRunEnv)
    } else {
	set fpParent [FindNodeTopWin $node]
#	set fpParent {}
    }
    set runState($node,modelRunning) 1
    set topCapt [GetExecTitle $node]
    foreach {smPath spFile} [array get projectParams] {
	unset projectParams($smPath)
	if {[file exists $spFile]} {
	    MergeParams $node /$node$smPath $spFile 0 0
	} else {
	    if {[string equal abort [Query [list no_spf_for_project $spFile] \
					 warning top {} abort]]} {
		break
	    }
	}
    }
    update idletasks ;# 'see all' missing spfs if that option was selected
    # otherwise query tangles with fp dialogue and hangs under windows
    if {[FileParamDialogue $node $fpParent 0]<1} {
	if {[info exists runState($node,cnvs)]} {
	    $runState($node,cnvs) itemconfigure 1 -fill [RestingColour $node]
	}
	return 0
    }
    foreach {var defVal} {adapt 0 errLimit 1e-6 splimit 0 speedLimit 50 \
			      resetTo 0 evtpause 0} {
	if {![info exists runState($node,$var)]} {
	    set runState($node,$var) $defVal
	}
    }
    if {[info exists runState($node,currentTime)]} {
#        if {$runState($node,execTime) != $runState($node,currentTime)} {
#            set runState($node,execTime) [expr $runState($node,execTime) + \
#					      $runState($node,currentTime)]


#        }
# above is done by reset phase
	set sendvars($node,unitLength) [InDays $runState($node,timeUnit)]
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
            if {![info exists runState($node,prev_update$phase)]} {
                set runState($node,update$phase) 0.1
                set runState($node,prev_update$phase) 0.1
	    }
	    SetStep $node [expr $runState($node,prev_update$phase) * \
			       $sendvars($node,unitLength)] $phase
	}
    } else {
	set runState($node,currentTime) 0.0
        set runState($node,execTime) 100
        set runState($node,displayInt) 1
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
            set runState($node,update$phase) 0.1
	    set runState($node,time$phase) 0
            set runState($node,prev_update$phase) 0.1
            SetStep $node 0.1 $phase
#	    SetStep $node 0 -$phase
        }
    }

    set runState($node,timeAtEval) 0.0

    if {[PrefValue custom(helperManager) helperManager]} {
        #    ShowMess debug info "About to make MRE [array name window_info *,parent]" ok
        raise [set topWin [Makemre $node]]
    }
#    Now have to do this in Prolog so only running windows change
#    foreach winData [array name window_info *,parent] {
#        set toolBar $window_info($winData).toolSlot.toolbar
#        $toolBar.snap configure -state active
#        set navBar $window_info($winData).toolSlot.navbar
#        $navBar.runenv configure -state active
#        $window_info($winData)top.tools entryconfigure {Inspect elements} -state active
#    }
    set runState($node,reloadParams) -2 ;# the initialize phase
    set runState($node,modelRunning) 2
#    EnableTools Fix

    # MakeSlidersForInputs is currently done after initializing the
    # model, so default values calculated from eqns can be loaded to the
    # sliders. Here we must clear any old input tool values so they are not used.
#    UnMakeSlidersForInputs

    set runClass $classTable(run,$node)
    set defHelper $helperTable(RunControl)
    if {![info exists runState($node,helperId)]} {
    
#    if {[regexp "(.helper\[0-9\]+),whichHelper $defHelper" \
#                [array get helperTable] spare helperId]} {
#       kill_helper_window $helperId
#   }
#	set helperId [NewHelperWindow $node $defHelper \
#			  "Run control for [GetExecTitle $node]"]
#	${defHelper}::initialize $helperId
	if {[PrefValue custom(helperManager) helperManager]} {
	    set ::RunEnv::CurrentContainer $RunEnv::runControlFrame($node)
	}
	set hlp [UniqueId helper]
	similescript::$defHelper $hlp $runClass "Run control for $topCapt"
	set runState($node,helperId) [$hlp cget -winId]
    }
# Do not put up mre, sliders, etc if model has failed to start
#    if {![info exists running_c]} {
#	return
#    }

# remake notebook page for sliders if earlier deleted
#    if {[PrefValue custom(helperManager) helperManager]} {
#	set sliderBook ${::RunEnv::explorerPane}.notebook
#	if {![info exists ::RunEnv::sliderControlFrame]} {
#	    $sliderBook insert end "InputSliders" -text "Input sliders"
#	    pack [set ::RunEnv::sliderControlFrame [frame [$sliderBook getframe "InputSliders"].sliders]] -fill both -expand yes
#	    $sliderBook raise InputSliders
#	}
#    }

#    MakeSlidersForInputs
    
    if {[PrefValue custom(helperManager) helperManager]} {
	set ::RunEnv::CurrentContainer $RunEnv::variableListFrame($node)
	if {![catch {set oldInsp $helperTable($::RunEnv::CurrentContainer.container,whichInstance)}]} {
	    itcl::delete object $oldInsp ;# model components may have changed
	}
 	set hlp [UniqueId helper]
	set helperId $helperTable(VariableList)
	similescript::$helperId $hlp $runClass Variables
#	if {![winfo exists $helperTable(autosliders)]} {
# No sliders in model, so delete notebook page
#	    $sliderBook delete InputSliders
#	    $sliderBook raise Explorer
#	    unset ::RunEnv::sliderControlFrame
#	}
	set ::RunEnv::CurrentContainer $RunEnv::dp0 ;# back to default
	set ctrlPane [winfo parent [winfo parent $::RunEnv::runControlFrame($node)]]
	update ;# so reqheight works next
#	tkwait visibility $runState($node,helperId)
	set aimPane [expr {[winfo reqheight $ctrlPane.runcontrolPane]+10}]
# this sometimes fails to work, so keep trying till it does!
	while {[lindex [$ctrlPane sash coord 0] 1]!=$aimPane} {
	    $ctrlPane sash place 0 10 $aimPane
	    update
	}
	::RunEnv::InMreFor $node ;# in case it has been focussed since creation
    } else {
	wm protocol $runState($node,helperId) WM_DELETE_WINDOW \
	    [list ${defHelper}::AbortFromMenu $node]
    }
# Now list all the inputs in the model, so we can avoid running it until
# all have tools attached to provide their values
#    if {[info exists inputHelper]} {
#	array set oldInputHelper [array get inputHelper]
#	unset inputHelper
#    }
#    foreach node [GetObjectList] {
#	if {[string match TABLE [GetModelEval $node]]} {
#	    set name [GetCaptionPathFromId $node]
#	    if {[info exists oldInputHelper($name)]} {
#		set inputHelper($name) $oldInputHelper($name)
#		unset oldInputHelper($name)
#	    } else {
#		set inputHelper($name) {}
#	    }
#	}
#    }
#    foreach removedInput [array names oldInputHelper] {
#	TellHelperItsGone $oldInputHelper($removedInput) $removedInput
#    }
#    CheckFixedParamState

    StartNow $node reset
    return 1
}

proc StartNow {node action} {
    global runState

    set widget $runState($node,helperId).nb.rcf
    $widget.upper.topbuttons.$action invoke
}

proc AddLogEntry {node text} {
    global runState

    set widget $runState($node,helperId).nb.log.text
    $widget configure -state normal
    $widget insert end $text
    $widget insert end \n
    $widget see end
    $widget configure -state disabled
}

proc InDays {timeUnit} {
    if {[string equal unit $timeUnit]} {
	return 1.0
    }
    return [GetFromProlog tk_in_days('$timeUnit')]
}

proc TellHelperItsGone {helperWin captionPath} {
# for compatibility, call a helper proc and if the helper doesn't have it
# delete it
}

proc GetExecTitle {node} {
	set mDesc [do_in_editor GetFromProlog tk_get_info(_,$node,context)]
	set modelCapt [string range $mDesc 0 \
			   [expr [string first { : } $mDesc]-1]]
	return [BlankCrs $modelCapt]
}

proc AllTitles {} {
    set result {}
    foreach win [winfo children .] {
	if {[string equal Toplevel [winfo class $win]]} {
	    lappend result $win [wm title $win]
	}
    }
    return $result
}
	
#proc CheckFixedParamState {node} {
#    global inputHelper runState
#    if {$runState($node,modelRunning)==1 && \
#	    [lsearch [array get inputHelper] {}] == -1} { 
#	# fixed param with no src
#	set runState($node,modelRunning) 2
#	# this initializes the model
#        set widget [GetFrame $runState($node,helperId).rcf]
#        $widget.topbuttons.reset invoke
#	EnableTools IO
#    }
#}

proc EnableTools {group} {
    set tgt .helpers.sub2
    for {set entry 0} {$entry <= [$tgt index last]} {incr entry} {
	set text [$tgt entrycget $entry -label]
	if {[string match Fix $group]==[string match {Set fixed parameters...} $text]} {
	    $tgt entryconfigure $entry -state normal
	} else {
	    $tgt entryconfigure $entry -state disabled
	}
    }
}

# this gets rid of a c program that has been loaded into
# the interpreter, to allow a new one to replace it --
# loadmodel with no args unloads model (this crashes Windows)

proc remove_c_model {} {
    # The following is not done cos it removes the stub as well
    #    package forget ame_dll
    #
    #    foreach c_command {c_resetmodel c_evalmodel c_updatemodel c_exitmodel \
    #	    getvalue getnodeid listobjects} {
    #	rename $c_command {}
    #    }
}

# FindPhase tells us when a node in a separate submodel will be
# available. The submodel indicates this by its eval phase. If DERIVED, INPUT
# or TABLE it can be used any time; if EXOGENOUS we must wait till that
# submodel has been called. If it is in a nested submodel, then it is
# usable after the phase in which the submodel is executed, or after
# its own phase if that is SPLIT. -1 means node not found.

# Note that because the top level model dll may not yet be loaded, we have
# to set model_id to the model we are searching in (model_ids keeps track of
# dlls loaded so far)

# Out of use because v5 does not need separate submodels
# proc FindPhase {node submodel} {
#     global model_id myNode model_ids
# 
#     set model_id($myNode) $model_ids($submodel)
#     foreach subnode [listobjects $model_id($myNode)] {
# 	if {[string equal $subnode $submodel]} continue
#         set subtype [lindex {EXOGENOUS DERIVED TABLE INPUT SPLIT GHOST} \
# 			 [getvalue $model_id($myNode) $subnode 2]]
#         if {[string match $node $subnode]} {
#             if {[string match EXOGENOUS $subtype]} {
#                 return 1
#             } else {
#                 return 0
#             }
#         }
#         if {[getvalue $model_id($myNode) $subnode 1]==4} { ;# EXTERNAL
#             lappend subs [list $subnode $subtype]
#         }
#     }
#     foreach nodeTypePair $subs {
#         set subFind [FindPhase $node [lindex $subs 0]]
# 
#         if {$subFind != -1} {
#             switch [lindex $subs 1] {
#                 EXOGENOUS {
#                     return 1
#                 } DERIVED {
#                     return 0
#                 } SPLIT {
#                     return $subFind
#                 }
#             }
#         }
#     }
#     return -1
# }
# 
# procedures to handle graph data

#proc insert_graph_data {graph_data_pointer xlow xhigh xspan ylow yhigh yspan \
\#            xsize array_data} {
 #   variable graphdata
 #   set $graph_data_pointer [format "%f %f %d %f %f %d %d %s" \
 \#           $xlow $xhigh $xspan $ylow $yhigh $yspan $xsize $array_data]
#}


proc SampleFrom {a} {
    if {[llength $a] == 1} {
        return $a
    } else {
        array set fun $a
        foreach index [array names fun] {
            set b [SampleFrom $fun($index)]
            if {$b} {
                return $b
            }
        }
        return 0
    }
}

proc IsArray {a} {
    string compare $a [lindex $a 0]
}

set intCount 0

proc newInt {} {
    global intCount
    return [incr intCount]
}

# Ultra crappy random alg now replaced by c library version

#set randfoob [expr exp(-1)]
#proc random01 {} {
#	global randfoob
#	return [set randfoob [expr fmod(1/$randfoob,1)]]
#}

proc ModelDirectory {} {
    global custom
    return [file dirname [lindex $custom(hotlist) 0]]
}
