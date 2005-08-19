# Simple helper app designed for management
# Set position of window on screen JMM
set keyValue pest20050803

namespace eval $keyValue {
    
    # namespace is used to minimize name clashes
    
    proc identify {} {
        return "PEST interface"
    }
    
    proc initialize {winId} {
	global stopImg
	variable useNodes
	variable clevers
	variable inClevers1
	variable inClevers2

	label $winId.header -text "Interface to PEST parameter estimation tool"
	pack $winId.header -fill x
	pack [set nb [::ttk::notebook $winId.notebook]] -fill both -expand yes
	$nb add [set inpId [frame $nb.inputs]] -text Inputs:
	set useNodes($winId,input) $inpId
	$nb add [set outId [frame $nb.outputs]] -text Outputs:
	set useNodes($winId,output) $outId
	$nb add [set setId [frame $nb.settings]] -text Settings:
	set useNodes($winId,settings) $setId
	$nb add [set resId [frame $nb.results]] -text Results:
	set useNodes($winId,results) $resId

	menu $winId.slidervars -tearoff 0
	menu $winId.drivervars -tearoff 0
	set toolbarItems \
	    [list [list new.gif "Clear" [namespace code "Clear $winId"]] \
		 [list add.gif "Add variables" \
		      [namespace code "AddVariable $winId"]] \
		 [list remove.gif "Remove a variable" \
		      [namespace code "RemoveVariable $winId"]] \
		 [list slider.gif "Add all variables" \
		      [namespace code "AddAllVariables $winId /"]]]
	::graphtools::MakeToolBar $inpId $toolbarItems
	set toolbarItems \
	    [list [list new.gif "Clear" [namespace code "ClearOut $winId"]] \
		 [list add.gif "Add variables" \
		      [namespace code "AddVariableOut $winId"]] \
		 [list remove.gif "Remove a variable" \
		      [namespace code "RemoveVariableOut $winId"]]]
	::graphtools::MakeToolBar $outId $toolbarItems
	
	pack [message $inpId.intro -aspect 800] -fill x
	pack [message $outId.intro -aspect 800] -fill x

        MakeFrames $inpId
        MakeFrames $outId

	pack [checkbutton $outId.show -text "Show these on plots" \
		  -variable ::[namespace current]::useNodes($winId,scrogging)]

	set frameNo 0
	set clevers(list) {{rlambda1 5.0 rlamfac 2.0 phiratsuf 0.4 \
				phiredlam 0.03 numlam 10} \
			       {relparmax 3.0 facparmax 3.0 facorig 0.001} \
			       {phiredswh 0.1} \
			       {noptmax 30 phiredstp 0.01 nphistp 3 \
				    nphinored 3 nparstp 0.01 nrelpar 3} \
			       {icov 1 icor 1 ieig 1}} 
	pack [set lf [labelframe $setId.lbf \
		  -text {PEST control parameters -- see manual for details}]]
	foreach line $clevers(list) {
	    pack [set curFr [frame $lf.f[incr frameNo]]]
	    foreach {val def} $line {
		if {[llength [winfo children $curFr]]>=6} { ;# is frame full
		    pack [set curFr [frame $lf.f[incr frameNo]]]
		}
		set clevers($val) $def
		pack [label $curFr.l[incr frameNo] \
			  -text [string toupper $val]] -side left
		pack [entry $curFr.e$frameNo -width 8 \
			  -textvar [namespace current]::clevers($val)] \
		    -side left
	    }
	}

	pack [frame $setId.rl]
	pack [label $setId.rl.lab -text "Run length:"] -side left
	pack [entry $setId.rl.ent] -side left

        ::ttk::button $setId.rl.reset -image $stopImg -width 32 \
	    -command [namespace code [list Stop $winId]]
	pack $setId.rl.reset -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $setId.rl.reset "Stop PEST process"
        ::ttk::button $setId.rl.start -width 32
        pack $setId.rl.start -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $setId.rl.start "Run or pause PEST process"
	SetButtonAct $winId start

	ScrolledWindow $resId.c
	set canId $resId.c.text
	pack [text $canId] -fill both -expand true
	$resId.c setwidget $canId
	pack $resId.c -side top -fill both -expand true

	pack [button $resId.b -text "Save a PEST file" -state disabled \
		  -command [namespace code SaveResults]]
	set inClevers1 {inctype absolute derinc 0.001 derinclb 0.001 \
			   forcen switch derincmul 0.001 dermthd best_fit}
	set inClevers2 {partrans none parchglim factor scale 1 offset 0}
	set useNodes($winId,state) 1 ;# stopped, no data
    }

    proc SetButtonAct {winId what} {
	global pauseImg playImg
	variable useNodes
	set btn $useNodes($winId,settings).rl.start
	if {[string equal start $what]} {
	    $btn configure -command [namespace code [list Go $winId]] \
		-image $playImg
	} else {
	    $btn configure -command [namespace code [list Pause $winId]] \
		-image $pauseImg
	}
    }

    proc SaveResults {} {
	global simtmpdir

	set typeList [list {{Run record} .rec} \
			  {{Parameter Value File} .par} \
			  {{Parameter Sensitivity File} .sen} \
			  {{Observation Sensitivity File} .seo} \
			  {{Residuals File} .res} \
			  {{Interim Residuals File} .rei} \
			  {{Matrix File} .mtt} \
			  {{Condition Number File} .cnd}]
	set ignoreTypes [list .inp .tpl .out .ins .pst .log]
	foreach other [glob [file join $simtmpdir model.*]] {
	    set extn [file extension $other]
	    if {[lsearch $typeList *$extn]==-1 && \
		    [lsearch $ignoreTypes $extn]==-1} {
		lappend exes $extn
	    }
	}
	lappend typeList [list {Other files} $exes]
	set initDir [do_in_editor GetPathChoice .rec]
	set tgt [tk_getSaveFile -title "Save PEST file" -initialdir $initDir \
		     -defaultextension .rec -filetypes $typeList]
	if {[llength $tgt]} {
	    file copy [file join $simtmpdir model[file extension $tgt]] $tgt
	}
    }

    proc clear {winId} {
    }

    proc Clear {winId} {
	variable useNodes
	foreach current [winfo children $useNodes($winId,input).sliderframe] {
	    destroy $current
	}
	$winId.slidervars delete 0 end
    }

    proc ClearOut {winId} {
	variable useNodes
	foreach current [winfo children $useNodes($winId,output).sliderframe] {
	    destroy $current
	}
	$winId.drivervars delete 0 end
    }

    proc Restore {winId} {
    }

    proc AddVariable {winId} {
	variable useNodes
	$useNodes($winId,input).intro configure -text "Click on an input parameter to allow PEST to write it, or on a submodel border to allow PEST to write all input variables inside it."
	SetState $winId adding_inputs
	GrabClicks $winId
    }

    proc AddVariableOut {winId} {
	variable useNodes
	$useNodes($winId,output).intro configure -text "Click on a model value to allow PEST to read it."
	SetState $winId adding_outputs
	GrabClicks $winId
    }

    proc RemoveVariable { winId } {
        tk_popup $winId.slidervars \
	    [winfo pointerx $winId] [winfo pointery $winId]
    }

    proc RemoveVariableOut { winId } {
        tk_popup $winId.drivervars \
	    [winfo pointerx $winId] [winfo pointery $winId]
    }

    proc click {winId node caption} {
	variable useNodes
	
	set fullCapt [GetCaptionPathFromId $node]

	switch [GetState $winId] {
	    adding_inputs {
		if {[string equal SUBMODEL [GetModelClass $node]]} {
		    set success [AddAllVariables $winId $fullCapt]
		} else {
		    set success [InsertSlider $winId $node $fullCapt 1]
		}
		if {$success} {
		    $useNodes($winId,input).intro configure -text {}
		    ReleaseClicks $winId
		}
	    } adding_outputs {
		set success [InsertDriver $winId $node $fullCapt 1]
		if {$success} {
		    $useNodes($winId,output).intro configure -text {}
		    ReleaseClicks $winId
		}
	    }
	}
    }

    proc AddAllVariables {winId prefix} {
	variable useNodes
        set done 0
	foreach node [GetObjectList] {
	    set title [GetCaptionPathFromId $node]
	    if {[string first $prefix $title]} {
		continue
	    }
	    if {[InsertSlider $winId $node $title 1]} {
		set done 1
	    }
	}
        if {!$done} {
            $useNodes($winId,input).intro configure -text "There are no more input parameters in this model which can be set by PEST. Note that this tool can only be used on REAL (floating-point) parameters."
        } else {
	    $useNodes($winId,input).intro configure -text {}
	}
	return $done
    }

    proc InsertSlider {winId node title nest} {
	variable useNodes
	variable inClevers1
	variable inClevers2
	variable inGrpData

	set inpId $useNodes($winId,input)

	set mode [GetModelEval $node]
	if {[lsearch {TABLE INPUT} $mode]==-1} {
	    $inpId.intro configure -text "This component cannot be set by PEST because it is not a fixed or variable parameter."
	    return 0
	}
	set datatype [GetModelType $node]
	if {![string equal REAL $datatype]} {
	    $inpId.intro configure -text "This component cannot be esimated by PEST because its datatype is $datatype. Only parameters of type REAL can be estimated."
	    return 0
	}
	set levels [split $title /]
	if {$nest} {
	    set f [MakeSubFrames $inpId $inpId.sliderframe \
				    $levels [namespace current] 0]
	    if {[winfo exists $f]} {
		$inpId.c.canvas see $f
		return 0
	    } else {
		pack [frame $f] -fill x -expand true
		bind $f <Double-1> [namespace code \
					[list DoInpDlg $node $f $title]]
		bind $f <Button-3> [namespace code \
					[list DoInpDlg $node $f $title]]
	    }
	} else {
	    set f $inpId
	}
	$winId.slidervars add command -label $title \
	    -command [namespace code [list Remove $winId $title]]
	foreach {val def} $inClevers1 {
	    set inGrpData($node,$val) $def
	}
	foreach {val def} $inClevers2 {
	    set inGrpData($node,$val) $def
	}
	
	set ::timeInfo($node) start
	if {[string equal INPUT $mode]} {
	pack [label $f.caption -text "Set [lindex $levels end]:"] -side left
	pack [radiobutton $f.start -text "At start" -variable timeInfo($node) \
		  -value start -command \
		  [namespace code [list AbleTimeData $node $f]]] -side left
	pack [radiobutton $f.ints -text "Every" -variable timeInfo($node) \
		  -value ints -command \
		  [namespace code [list AbleTimeData $node $f]]] -side left
	pack [entry $f.int -textvariable regularInt($node) -width 8 \
		  -state disabled] -side left
	pack [label $f.mid1 -text units] -side left
	} else {
	    pack [label $f.caption -text "Range for [lindex $levels end]:"] \
		-side left
	    pack [label $f.mid2 -text Min:] -side left
	    pack [entry $f.min -textvariable minForOpt($node) -width 8] \
		-side left
	    pack [label $f.mid3 -text Max:] -side left
	    pack [entry $f.max -textvariable maxForOpt($node) -width 8] \
		-side left
	}
	set ::minForOpt($node) [GetMinValue $node]
	set ::maxForOpt($node) [GetMaxValue $node]
	set ::initialEstimate($node) \
	    [expr ($::minForOpt($node)+$::maxForOpt($node))/2]
	pack [entry $f.est -textvariable initialEstimate($node) -width 8] \
		-side right
	pack [label $f.estlbl -text Estimate:] -side right
	foreach widjo [winfo children $f] {
	    bind $widjo <Double-1> [namespace code \
					[list DoInpDlg $node $f $title]]
	    bind $widjo <Button-3> [namespace code \
					[list DoInpDlg $node $f $title]]
	}
	return 1
    }

    proc DoInpDlg {node win title} {
	variable inGrpData
	set t [PutItThere .pestinpdlg $win]
	wm protocol .pestinpdlg  WM_DELETE_WINDOW [namespace code DoneInpDlg]
	wm title $t "Set properties for $title"

	pack [set f [labelframe $t.grp -text "Group properties:"]]
	set ns [namespace current]
	pack [frame $f.inctype]
	pack [label $f.inctype.l -text INCTYPE] -side left
	pack [ComboBox $f.inctype.c -values {relative absolute rel_to_max} \
		  -editable 0 -textvariable ${ns}::inGrpData($node,inctype)] \
	    -side left

	pack [frame $f.derinc]
	pack [label $f.derinc.l -text DERINC] -side left
	pack [entry $f.derinc.e -width 8 \
		  -textvar ${ns}::inGrpData($node,derinc)] \
	    -side left

	pack [frame $f.derinclb]
	pack [label $f.derinclb.l -text DERINCLB] -side left
	pack [entry $f.derinclb.e -width 8 \
		  -textvar ${ns}::inGrpData($node,derinclb)] \
	    -side left

	pack [frame $f.forcen]
	pack [label $f.forcen.l -text FORCEN] -side left
	pack [ComboBox $f.forcen.c -values {always_2 always_3 switch} \
		  -editable 0 -textvariable ${ns}::inGrpData($node,forcen)] \
	    -side left

	pack [frame $f.derincmul]
	pack [label $f.derincmul.l -text DERINCMUL] -side left
	pack [entry $f.derincmul.e -width 8 \
		  -textvar ${ns}::inGrpData($node,derincmul)] \
	    -side left
	      
	pack [frame $f.dermthd]
	pack [label $f.dermthd.l -text DERMTHD] -side left
	pack [ComboBox $f.dermthd.c -values {parabolic best_fit outside_pts} \
		  -editable 0 -textvariable ${ns}::inGrpData($node,dermthd)] \
	    -side left

	pack [set f [labelframe $t.inp -text "Value transformations:"]]
	pack [frame $f.partrans]
	pack [label $f.partrans.l -text PARTRANS] -side left
	pack [ComboBox $f.partrans.c -values {none log} \
		  -editable 0 -textvariable ${ns}::inGrpData($node,partrans)] \
	    -side left

	pack [frame $f.parchglim]
	pack [label $f.parchglim.l -text PARCHGLIM] -side left
	pack [ComboBox $f.parchglim.c -values {relative factor} \
		 -editable 0 -textvariable ${ns}::inGrpData($node,parchglim)] \
	    -side left

	pack [frame $f.scale]
	pack [label $f.scale.l -text SCALE] -side left
	pack [entry $f.scale.e -width 8 \
		  -textvar ${ns}::inGrpData($node,scale)] \
	    -side left
	      
	pack [frame $f.offset]
	pack [label $f.offset.l -text OFFSET] -side left
	pack [entry $f.offset.e -width 8 \
		  -textvar ${ns}::inGrpData($node,offset)] \
	    -side left
	      
	pack [button $t.done -text Done -command [namespace code DoneInpDlg]]
        LetItShow $t
        grab $t
        tkwait variable [namespace current]::inGrpData(done)
        grab release $t
	PackItUp $t
    }
	
    proc DoneInpDlg {} {
	set [namespace current]::inGrpData(done) 1
    }

    proc InsertDriver {winId node title nest} {
	global targetData
	variable useNodes
	set outId $useNodes($winId,output)

	set mode [GetModelEval $node]
	if {[lsearch {TABLE INPUT} $mode]>-1} {
	    $outId.intro configure -text "This component cannot be optimized by PEST because it is a fixed or variable parameter."
	    return 0
	}
	set datatype [GetModelType $node]
	if {![string equal REAL $datatype]} {
	    $outId.intro configure -text "This component cannot be optimized by PEST because its datatype is $datatype. Only parameters of type REAL can be optimized."
	    return 0
	}

	set f [MakeSubFrames $::myNode $outId.sliderframe \
		   [split $title /] [namespace current] 0]
	if {[winfo exists $f]} { 
	    $outId.c.canvas see $f
	} else {
	    lappend targetData(needed) $title
	    AddEntry $outId $::myNode $node 1 -1
	    $winId.drivervars add command -label $title \
		-command [namespace code [list RemoveOut $winId $title]]

	    set ::readMany($node) 0
	    pack [checkbutton $f.end -variable paramDims($title,readMany) \
		      -command [namespace code \
				    [list AbleTimeSampling $node $title $f]]] \
		-side left
	    BindPopup $f.end "Set values at time points"
	}
	return 1
    }

    proc AbleTimeData {node f} {
	global timeInfo
	if {[string equal ints $timeInfo($node)]} {
	    set st normal
	} else {
	    set st disabled
	}
	$f.int config -state $st
    }

    proc AbleTimeSampling {node title f} {
	global paramDims

	set trans [GetTransTable $node]
	if {$paramDims($title,readMany)} {
	    set paramDims($title) [linsert $paramDims($title) 0 TIME]
	    set trans [linsert $trans 0 {}]
	} else {
	    set paramDims($title) [purge $paramDims($title) TIME]
	}
	set nodeDims [TransBounds $trans $paramDims($title)]
	set dimList [MakeDimsLegible $nodeDims REAL]
	$f.l2 config -text ($dimList)
	ColourCaptions $f red
	if {[llength $nodeDims]>1} {
	    pack $f.b -after $f.l2 -side right
	} else {
	    pack forget $f.b
	}  
    }

    proc Remove {winId title} {
	variable useNodes
	set inpId $useNodes($winId,input)
        set levels [split $title /]
	set f [MakeSubFrames {} $inpId.sliderframe \
		   $levels [namespace current] 0]
	Prune $inpId $f
	$winId.slidervars delete $title
    }

    proc RemoveOut {winId title} {
	variable useNodes
	set outId $useNodes($winId,output)
        set levels [split $title /]
	set f [MakeSubFrames {} $outId.sliderframe \
		   $levels [namespace current] 0]
	Prune $outId $f
	$winId.drivervars delete $title
    }

    proc Prune {winId tree} {
	set up [winfo parent $tree]
	destroy $tree
	if {![string equal ${winId}.sliderframe $up]} {
	    foreach remain [winfo children $up] {
		set box [winfo name $remain]
		if {[string match box* $box] || [string match frame* $box]} {
		    return
		}
	    }
	    Prune $winId $up
	}
    }

    proc reset {winId} {
	variable useNodes

	if {$useNodes($winId,scrogging)} {
	    ShowMessage {Substituting measured values} warning \
		"You have selected to display the measured values supplied to the PEST interface helper for the output components, rather than their actual values from the model." ok
	}
    }

    proc display {winId time display remainder} {

# Check if the model is being run by PEST, and if it is, write data
# for any model outputs for which we have reached recording time
# points...nah, we are only running it between recording points.

    }

    proc Stop {winId} {
	PokeStopFile $winId 2
    }

    proc Pause {winId} {
	variable useNodes
	set useNodes($winId,state) 3
	PokeStopFile $winId 3
	SetButtonAct $winId start
    }

    proc Go {winId} {

# Time to invoke PEST. First we must make a template file that allows
# PEST to create a .spf file that will parameterize the model. Usually
# a .spf file is MIME-encoded and contains references to other files,
# but neither of these need be done here.

	global simtmpdir initialEstimate minForOpt maxForOpt paramDims
	global tcl_platform sender
	variable useNodes
	variable clevers
	variable usedHangers
	variable inGrpData
	variable outGrpData
	variable inClevers1
	variable ptList
	variable spitLists

	PokeStopFile $winId 0
	SetButtonAct $winId pause
	if {$useNodes($winId,state)==3} { ;# it was paused
	    set useNodes($winId,state) 0
	    return
	}

	set usedHangers 0
	set runLength [$useNodes($winId,settings).rl.ent get]
	$useNodes($winId,results).c.text delete 1.0 end
	$useNodes($winId,results).b configure -state disabled

	set control [NetOpen [file join $simtmpdir model.pst] w]
	puts $control pcf
	puts $control {* control data}
	puts $control {restart estimation}

	set template [NetOpen [file join $simtmpdir model.tpl] w]
	puts $template "ptf \\"
	
# Descend hierarchically through the frames to get the data? No, use kill menu

	array unset inGrpData *,mems
	set numInputs [CountMenuCmds $winId.slidervars]
	for {set eNo 0} {$eNo < $numInputs} {incr eNo} {
	    set eTitle [$winId.slidervars entrycget $eNo -label]
	    set node [GetIdFromCaptionPath $eTitle]
	    set levels [split $eTitle /]
	    set inpId $useNodes($winId,input)
	    set f [MakeSubFrames {} $inpId.sliderframe \
		       $levels [namespace current] 0]

	    set nodeDims [GetModelDims $node]
	    set defVal [$f.est get]
	    puts -nonewline $template $eTitle=
	    if {[winfo exists $f.int]} {
		if {[string equal normal [$f.int cget -state]]} {
		    set int [$f.int get]
		    for {set setTime 0} {$setTime < $runLength} \
			{set setTime [expr {$setTime+$int}]} {
			    puts -nonewline $template "$setTime "
			    AddHangers $node $template $nodeDims 1
			    puts -nonewline $template " "
			}
		} else {
		    puts -nonewline $template "NOW "
		    AddHangers $node $template $nodeDims 1
		}
	    } else {
		AddHangers $node $template $nodeDims 0
	    }
	    puts $template {}
	}
	close $template

	puts -nonewline $control $usedHangers

	# next, look at the outputs required at times before the end
	# of the run and create an array holding lists of nodes whose
	# values will be written at each time...

	global targetData
	array unset spitLists
	set usedHangers 0
	array unset outGrpData *,mems
	set numOutputs [CountMenuCmds $winId.drivervars]
	for {set eNo 0} {$eNo < $numOutputs} {incr eNo} {
	    set eTitle [$winId.drivervars entrycget $eNo -label]
	    set node [GetIdFromCaptionPath $eTitle]
	    set levels [split $eTitle /]
	    set outId $useNodes($winId,output)
	    set f [MakeSubFrames {} $outId.sliderframe \
		       $levels [namespace current] 0]
	    if {$paramDims($eTitle,readMany)} {
		foreach {time defSet} $targetData($eTitle) {
		    lappend spitLists($time) $node=$defSet
		}
	    } else {
		lappend spitLists($runLength) $node=$targetData($eTitle)
	    }
	}
	set ptList [lsort -real [array names spitLists]]
    # right, now to make the instruction file for reading the outputs

	set instruct [NetOpen [file join $simtmpdir model.ins] w]
	puts $instruct "pif \\"
	foreach brkPt $ptList {
	    foreach entry $spitLists($brkPt) {
		set pair [split $entry =]
		set node [lindex $pair 0]
		puts -nonewline $instruct "\\$node at $brkPt is\\ "
		AddChoppers $node $instruct [lindex $pair 1]
		puts $instruct {}
	    }
	}
	close $instruct

	puts $control " $usedHangers $numInputs 0 $numOutputs"
	puts $control "1 1 single nopoint 1 0 0"
	foreach line $clevers(list) {
	    foreach {val spare} $line {
		puts -nonewline $control "$clevers($val) "
	    }
	    puts $control {}
	}

	puts $control {* parameter groups}
	foreach parmGrp [array names inGrpData *,mems] {
	    set node [string range $parmGrp 0 end-5]
	    puts -nonewline $control $node 
	    foreach {itm val} $inClevers1 {
		puts -nonewline $control " $inGrpData($node,$itm)"
	    }

	    puts $control {}
	}

	puts $control {* parameter data}
	foreach parmGrp [array names inGrpData *,mems] {
	    set node [string range $parmGrp 0 end-5]
	    foreach parmVal $inGrpData($parmGrp) {
		puts $control [list $parmVal $inGrpData($node,partrans) \
				   $inGrpData($node,parchglim) \
				   $initialEstimate($node) \
				   $minForOpt($node) \
				   $maxForOpt($node) $node \
				   $inGrpData($node,scale) \
				   $inGrpData($node,offset) 1]
	    }
	}
				   
	puts $control {* observation groups}
	foreach obsGrp [array names outGrpData *,mems] {
	    set node [string range $obsGrp 0 end-5]
	    puts $control $node
	}

	puts $control {* observation data}
	foreach obsGrp [array names outGrpData *,mems] {
	    set node [string range $obsGrp 0 end-5]
	    foreach combo $outGrpData($obsGrp) {
		puts $control [concat [split $combo =] [list 1.0 $node]]
	    }
	}

	set oldDir [pwd]
	puts $control {* model command line}
	puts $control "[file join [file dirname $oldDir] System bin wish] pestrun.tcl"
	puts $control {* model input/output}
	puts $control {model.tpl model.inp}
	puts $control {model.ins model.out}

	close $control
	
	set activator [NetOpen [file join $simtmpdir pestrun.tcl] w]
	if {[string match windows $tcl_platform(platform)]} {
	    puts $activator "package require dde 1.2" ;# must be easier way
	}
#	puts $activator "[do_in_editor set runHow(sendOp)] exec_for_$::myNode [namespace code pestificate]"
	puts $activator "eval $sender [list do_for_node $::myNode] [namespace code pestificate]"
	puts $activator exit
	close $activator

# ok, now we need to execute pest in immediate mode in order to get
# any error messages back from it. However, while doing that we can't
# run the model -- so get the editor process to call it when it has a
# moment. Sadly that don't work either, since the commands to execute
# the model call the editor process back to check for updates.

	cd $simtmpdir
        switch $tcl_platform(os) {
            {Windows NT} {
#		exec cmd /c start /min pest model.pst >& model.log
		set spout [open {|cmd /c start /min pest model.pst} r]
	    } {Windows 95} {
#		exec start /m pest model.pst >& model.log
		set spout [open {|start /m pest model.pst} r]
	    } default {
#		exec pest model.pst >& model.log &
		set spout [open {|pest model.pst} r]
	    }
	}
	cd $oldDir
	set useNodes($winId,state) 0 ;# rolling

	fconfigure $spout -blocking 0
	fileevent $spout readable [namespace code [list GrabMsgs $winId $spout]]
    }
    
    # for now, just use pipe to tell when PEST has finished
    proc GrabMsgs {winId spout} {
	variable useNodes
	if {[gets $spout bilge]>-1} {
	    $useNodes($winId,results).c.text insert end "$bilge\n"
	} elseif {[eof $spout]} {
	    close $spout	    
	    SetButtonAct $winId start
	    set useNodes($winId,state) 2 ;# stopped, with data
	    $useNodes($winId,results).b configure -state normal
	}
    }

    proc PokeStopFile {winId n} {
	global simtmpdir
	variable useNodes
	set stpipe [open [file join $simtmpdir pest.stp] w]
	puts $stpipe $n
	close $stpipe
    }

    # Next bit will actually be executed by command supplied to PEST

    proc pestificate {} {
	global runState simtmpdir errorInfo
	variable ptList
	variable spitLists

	if {[catch {
	set topNode $::myNode

	# load the PEST-generated .spf file
	ZapParams $topNode {} [file join $simtmpdir model.inp]

	set widget $runState($topNode,helperId).nb.rcf
	$widget.upper.topbuttons.reset invoke

	set execLog [NetOpen [file join $simtmpdir model.out] w]
	set current 0
	foreach breakPt $ptList {
	    set runState($topNode,execTime) [expr $breakPt-$current]
	    $widget.upper.topbuttons.start invoke
	    if {$runState($topNode,currentTime)<$breakPt} {
		error "PEST tried to run this model up to time $breakPt but it was interrupted at time $runState($topNode,currentTime)"
		return
	    }
	    foreach pair $spitLists($breakPt) {
		set node [lindex [split $pair =] 0]
		# need to prettify so we can seek on indices
		set writable [PrettifyValList [lindex [GetModelValue $node] 0]]
		puts $execLog "$node at $breakPt is $writable"
	    }
	    set current $breakPt
	}
	close $execLog
	}]} {
	    ShowMessage "Problem executing from PEST" warning $errorInfo ok
	}
    }

    proc ShowMeasurements {} {

# This is to allow us to produce the 'killer graphic' of the field
# measurements superposed on a plot of the corresponding
# model-generated data. It runs the model up to the timepoints at
# which measurements have been entered, then it saves the values of
# the components corresponding to those measurements, inserts the
# measurements, and calls the display tools, which then hopefully read
# and display the measurement data. The model values are put back
# before running the model further.

# Sounds simple enough, but supposing we have different measurements
# at different times? We can't selectively display them, or 'blank'
# the model values we don't have measurements for...ideally we would
# interpolate between measurements we do have...OK what about the
# ends? X-trapolate nearest two points? Of course if we only have one
# point we just use it...

	global runState simtmpdir errorInfo
	variable ptList
	variable spitLists

# Turn off interval display? Why bother; displaying at irregular
# intervals will only mess up the other plots, and if we are
# interpolating anyway, why not do so at every time point? Just so
# long as we can scrog the values before the display tools get
# them...(and put them back after)...do by putting specials at
# beginning and end of helper list? Fine, except it's an array...

	set widget $runState($topNode,helperId).nb.rcf
	$widget.upper.topbuttons.reset invoke

    }

    proc ScrogOutputs {} {
	variable useNodes
	variable ptList
	variable spitLists

	set subTime [GetModelTime]
	foreach activeSub [array names useNodes *,scrogging] {
	    if {$useNodes($activeSub)} {
		set winId [string range $activeSub 0 end-10]

	set numOutputs [CountMenuCmds $winId.drivervars]
	for {set eNo 0} {$eNo < $numOutputs} {incr eNo} {
	    set eTitle [$winId.drivervars entrycget $eNo -label]
	    set node [GetIdFromCaptionPath $eTitle]

	    set useNodes($node,modelVal) [lindex [GetModelValue $node] 0]
	    foreach time $ptList {
		set pt [lsearch $spitLists($time) $node=*]
		if {$pt>-1} {
		    set val [list $time [lindex [split \
				    [lindex $spitLists($time) $pt] =] 1]]
		    if {$time==$subTime} {
			set hi $val
			if {[info exists lo]} {unset lo}
			break
		    } else {
			if {[info exists hi]} {
			    set lo $hi
			}
			set hi $val
		    }
		    if {$time>$subTime && [info exists lo]} {
			break
		    }
		}
	    }
	    if {[info exists lo]} {
		set progFrack [expr ($subTime-[lindex $lo 0])/ \
				  ([lindex $hi 0]-[lindex $lo 0])]
		set mid [Interpo $progFrack [lindex $lo 1] [lindex $hi 1]]
	    } else {
		set mid [lindex $hi 1]
	    }
	    SetModelValue $node $mid
	}

	    }
	}
    }

    proc Interpo {fract v1 v2} {
	if {[llength $v1]==1} {
	    return [expr (1-$fract)*$v1+$fract*$v2]
	} else {
	    foreach {idx1 val1} $v1 {idx2 val2} $v2 {
		lappend result $idx1 [Interpo $fract $val1 $val2]
	    }
	    return $result
	}
    }

    proc RestoreOutputs {} {
	variable useNodes

	foreach storedVal [array names useNodes *,modelVal] {
	    set node [string range $storedVal 0 end-9]
	    SetModelValue $node $useNodes($storedVal)
	    array unset useNodes($storedVal)
	}
    }

    proc AddChoppers {node str data} {
	variable usedHangers
	variable outGrpData

	if {[llength $data]!=1} {
	    foreach {n val} $data {
		puts -nonewline $str "\\\#$n:\\ "
		AddChoppers $node $str $val
		puts -nonewline $str " "
	    }
	} else {
	    puts -nonewline $str !o[incr usedHangers]!
	    lappend outGrpData($node,mems) o$usedHangers=$data
	}
    }	

    proc AddHangers {node str dms brs} {
	variable usedHangers
	variable inGrpData

	if {[lindex $dms 0]>0} {
	    if {$brs==1} {
		puts -nonewline $str \{
	    }
	    for {set n 1} {$n <= [lindex $dms 0]} {incr n} {
		puts -nonewline $str "$n "
		AddHangers $node $str [lrange $dms 1 end] 1
	    }
	    puts -nonewline $str " "
	    if {$brs==1} {
		puts -nonewline $str \}
	    }
	} else {
	    puts -nonewline $str [format \\%10s\\ i[incr usedHangers]]
	    lappend inGrpData($node,mems) i$usedHangers
	}
    }	

    proc CountMenuCmds {m} {
	# if menu is tearoff first entry is 1
	# if not last entry is n-1 (we expect this)
	set r [$m index end]
	if {[string equal none $r]} {set r 0} else {incr r}
	return $r
    }

    proc Save {topNode smPath} {
	namespace eval ::fileparams [list Save $topNode $smPath -1]
    }

    proc Open {topNode smPath} {
	namespace eval ::fileparams [list Open $topNode $smPath -1]
    }
} ;# end of namespace
