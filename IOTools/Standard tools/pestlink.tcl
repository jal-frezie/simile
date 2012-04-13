# Simple helper app designed for management
# Set position of window on screen JMM
set keyValue pest20050803

namespace eval $keyValue {
    
    # namespace is used to minimize name clashes
    
    proc identify {} {
        return "PEST interface"
    }
    
    proc initialize {winId} {
        global stopImg runState myNode
        variable useNodes
        variable runData
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
        $nb add [set resId [frame $nb.results]] -text Actions:
        set useNodes($winId,results) $resId
        $nb add [set setId [frame $nb.settings]] -text Settings:
        set useNodes($winId,settings) $setId
        
        menu $winId.slidervars -tearoff 0 -postcommand \
	    [namespace code [list AddVarsToSliderMenu $winId]]
        menu $winId.drivervars -tearoff 0 -postcommand \
	    [namespace code [list AddVarsToDriverMenu $winId]]
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
                [list add.gif "Add end-of-run measurement" \
                [namespace code "AddVariableOut $winId"]] \
                [list graph.gif "Add time series of measurements" \
                [namespace code "AddTimeSeries $winId"]] \
                [list remove.gif "Remove a variable" \
                [namespace code "RemoveVariableOut $winId"]]]
        ::graphtools::MakeToolBar $outId $toolbarItems
        
        pack [message $inpId.intro -aspect 800] -fill x
        pack [message $outId.intro -aspect 800] -fill x
        pack [message $resId.intro -aspect 800] -fill x
        
        MakeFrames $inpId; Clear $winId
        MakeFrames $outId; ClearOut $winId
        
        pack [checkbutton $inpId.gather -text "Use current data as estimates" \
                -variable ::[namespace current]::useNodes($winId,gathering) \
                -command [namespace code [list AbleEstimateFields $winId]]]
	set scrogVar ::[namespace current]::useNodes($winId,scrogging)
        pack [checkbutton $outId.show -text "Show these on plots" \
		  -variable $scrogVar \
		  -command [namespace code [list LoadMeasurements $winId]]]
	bind $outId.show <Destroy> [list unset $scrogVar] ;# tidy up
        # Actions frame
        # Control buttons
        pack [set lf [labelframe $resId.lbf -text {Parameter estimation}]] \
                -fill x -padx 4 -pady 4
        pack [frame $lf.upper] -side top -fill x -expand true
        ::ttk::button $lf.upper.reset -image $stopImg -width 32 \
                -command [namespace code [list Stop $winId]]
        pack $lf.upper.reset -side left  -padx 1 -pady 2
        BindPopup $lf.upper.reset "Stop PEST process"
        ::ttk::button $lf.upper.start -width 32
        pack $lf.upper.start -side left  -padx 1 -pady 2
        BindPopup $lf.upper.start "Run or pause PEST process"
        SetButtonAct $winId start
        # progress bar
        pack [set runData($myNode,progressBar) \
                [::ttk::progressbar $lf.upper.bar -maximum 100]] \
                -fill x -expand true -side top -padx 4 -pady 4
        # Run length entry field
        pack [frame $lf.rl] -side top
        pack [label $lf.rl.lab -text "Run length:"] -side left
        pack [entry $lf.rl.ent -width 10] -side left
        $lf.rl.ent insert 0 $runState($myNode,execTime)
        pack [label $lf.rl.lab2 -textvar runState($myNode,timeUnit)] \
                -side left
        # prediction specs
        pack [set pf [labelframe $resId.pbf \
                -text {Predictive analysis:}]] -fill x -padx 4 -pady 4
        pack [frame $pf.pknobs]
        pack [checkbutton $pf.pknobs.ck -text Predict \
                -command [namespace code [list AblePrediction $winId]] \
                -variable [namespace current]::useNodes($winId,preds)] \
                -side left
        pack [ttk::combobox $pf.pknobs.mm -values {minimum maximum} -state readonly \
                -textvariable [namespace current]::useNodes($winId,way) \
                -width 8] -side left
        set useNodes($winId,way) maximum
        pack [label $pf.pknobs.valof -text "value of"] -side left
        pack [label $pf.pknobs.nm -text (none) \
                -textv [namespace current]::useNodes($winId,pred)] -side left
        pack [label $pf.pknobs.wth -text "within"] -side left
        pack [entry $pf.pknobs.fit -width 8 \
                -textv [namespace current]::useNodes($winId,pfit)] -side left
        set useNodes($winId,pfit) 2.5
        pack [label $pf.pknobs.xp -text "X best fit"] -side left
        # times for predictions
        pack [frame $pf.tknobs]
        pack [label $pf.tknobs.ev -text "every"] -side left
        pack [entry $pf.tknobs.tint -width 8 \
                -textv [namespace current]::useNodes($winId,predint)] \
                -side left
        set useNodes($winId,predint) 1.0
        pack [label $pf.tknobs.un -textvar runState($myNode,timeUnit)] \
                -side left
        pack [label $pf.tknobs.fr -text "from"] -side left
        pack [entry $pf.tknobs.tgo -width 8 \
                -textv [namespace current]::useNodes($winId,pgo)] -side left
        set useNodes($winId,pgo) $runState($myNode,execTime)
        pack [label $pf.tknobs.to -text "to"] -side left
        pack [entry $pf.tknobs.tstp -width 8 \
                -textv [namespace current]::useNodes($winId,pstp)] -side left
        set useNodes($winId,pstp) $runState($myNode,execTime)
        # prediction results
        pack [frame $pf.rknobs] -fill x -expand true
        pack [label $pf.rknobs.ev -text "Results:"] -side left
        pack [entry $pf.rknobs.tstp -width 8 \
                -textv [namespace current]::useNodes($winId,predall)] \
                -fill x -expand true -side left
        pack [button $pf.rknobs.btn -text View... \
		  -command [namespace code [list TabPreds $winId]]] -side left
        # data from run in progress
        pack [set df [labelframe $resId.dbf -text {Execution monitor:}]] \
                -fill both -expand true -padx 4 -pady 4
        pack [frame $df.numeric]
        pack [label $df.numeric.sqlab -text "PEST execution:"] -side left
        pack [label $df.numeric.sqnum -textvariable \
                [namespace current]::useNodes($winId,rnum)] -side left
        pack [label $df.numeric.iclab -text "Iteration number:"] -side left
        pack [label $df.numeric.icnum -textvariable \
                [namespace current]::runData($myNode,itCount)] -side left
        pack [label $df.numeric.mrlab -text "Model runs:"] -side left
        pack [label $df.numeric.mrnum -textvariable \
                [namespace current]::runData($myNode,rollCount)] -side left
        pack [frame $df.outputs]
        pack [label $df.outputs.cplab -text "Current PHI:"] -side left
        pack [label $df.outputs.cpnum -textvariable \
                [namespace current]::runData($myNode,curPhi)] -side left
        pack [label $df.outputs.prlab -text "Prediction:"] -side left
        pack [label $df.outputs.prnum -textvariable \
                [namespace current]::runData($myNode,curPred)] -side left
        # Commentary window
        ScrolledWindow $df.c
        set canId $df.c.text
        text $canId -height 4
        $df.c setwidget $canId
        pack $df.c -side top -fill both -expand true
        
        pack [button $resId.b -text "Save a PEST file" -state disabled \
		  -command [namespace code [list SaveResults $myNode]]]
        
        set frameNo 0
        set clevers(list) {{rlambda1 5.0 rlamfac 2.0 phiratsuf 0.4 \
                        phiredlam 0.03 numlam 10} \
                    {relparmax 3.0 facparmax 3.0 facorig 0.001} \
                    {phiredswh 0.1} \
                    {noptmax 30 phiredstp 0.01 nphistp 3 \
                        nphinored 3 nparstp 0.01 nrelpar 3}}
        set clevers(pred) {{pd0 0.0 pd1 0.0 pd2 0.0} \
                    {abspredlam 0 relpredlam 0.005 initschfac 1.0 \
                        mulschfac 2.0 nsearch 8} \
                    {abspredswh 0 relpredswh 0.05} \
                    {nprednored 4 abspredstp 0 relpredstp 0.005 \
                        npredstp 4}}
        pack [set lf [labelframe $setId.lbf \
                -text {Parameter estimation}]] \
                -fill x -padx 4 -pady 4
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
        
        pack [set pf [labelframe $setId.pbf \
                -text {Predictive analysis:}]] -fill x -padx 4 -pady 4
        foreach line $clevers(pred) {
            pack [set curFr [frame $pf.f[incr frameNo]]]
            foreach {val def} $line {
                if {[llength [winfo children $curFr]]>=6} { ;# is frame full
                    pack [set curFr [frame $pf.f[incr frameNo]]]
                }
                set clevers($val) $def
                pack [label $curFr.l[incr frameNo] \
                        -text [string toupper $val]] -side left
                pack [entry $curFr.e$frameNo -width 8 \
                        -textvar [namespace current]::clevers($val)] \
                        -side left
            }
        }
        
        set inClevers1 {inctype absolute derinc 0.001 derinclb 0.001 \
                    forcen switch derincmul 0.001 dermthd best_fit}
        set inClevers2 {partrans none parchglim factor scale 1 offset 0}
        set useNodes($winId,state) 1 ;# stopped, no data
    }

    proc TabPreds {winId} {
	variable useNodes

	set tabData [UglifyValList $useNodes($winId,predall)]
	EditListAsTable $winId tabData
    }

    proc SetButtonAct {winId what} {
        global pauseImg playImg
        variable useNodes
        set btn $useNodes($winId,results).lbf.upper.start
        if {[string equal start $what]} {
            $btn configure -command [namespace code [list Go $winId]] \
                    -image $playImg
        } else {
            $btn configure -command [namespace code [list Pause $winId]] \
                    -image $pauseImg
        }
    }
    
    proc AddVarsToSliderMenu {winId} {
	variable useNodes

        $winId.slidervars delete 0 end
        foreach var $useNodes($winId,sliders) {
	    $winId.slidervars add command -label $var \
		-command [namespace code [list Remove $winId $var]]
        }
    }

    proc AddVarsToDriverMenu {winId} {
	variable useNodes

        $winId.drivervars delete 0 end
        foreach var $useNodes($winId,drivers) {
	    $winId.drivervars add command -label $var \
		-command [namespace code [list RemoveOut $winId $var]]
        }
    }

    proc SaveResults {context} {
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
        set initDir [do_in_editor GetPathChoice .rec $context]
        set tgt [tk_getSaveFile -title "Save PEST file" -initialdir $initDir \
                -defaultextension .rec -filetypes $typeList]
        if {[llength $tgt]} {
            file copy [file join $simtmpdir model[file extension $tgt]] $tgt
        }
    }
    
    proc AbleEstimateFields {winId} {
        # later: use MakeSubFrames to find
        # and able all estimate entry boxes (not needed if using parameter
        # data)
    }
    
    proc AblePrediction {winId} {
        variable useNodes
        if {$useNodes($winId,preds)} {
            SetState $winId adding_pred
            $useNodes($winId,results).intro configure -text "Click on a model value to instruct PEST to generate predictions for it."
            GrabClicks $winId
        } else {
            set useNodes($winId,pred) (none)
        }
    }
    
    proc clear {winId} {
    }
    
    proc Clear {winId} {
        variable useNodes
        foreach current [winfo children $useNodes($winId,input).c.canvas.frame] {
            destroy $current
        }
	set useNodes($winId,sliders) {}
    }
    
    proc ClearOut {winId} {
	global targetData
        variable useNodes
        foreach current [winfo children $useNodes($winId,output).c.canvas.frame] {
            destroy $current
        }
	set useNodes($winId,drivers) {}
	array unset targetData
    }
    
    proc Restore {winId} {
        global readMany
        variable inGrpData
        variable outGrpData
        variable useNodes
        variable clevers
        
        initialize $winId
        foreach action [GetState $winId] {
            switch [lindex $action 0] {
                input {
                    set title [lindex $action 1]
                    set node [GetIdFromCaptionPath $title]
                    if {[string equal nomatch $node]} {
                        ShowMess "Problem restoring PEST settings" warning \
                                "Could not add $title to PEST inputs because there is no component with this caption in the model" ok
                        continue
                    }
                    set f [InsertSlider $winId $node $title 1]
                    foreach {tgt val} [lrange $action 2 end] {
                        switch $tgt {
                            est {
                                set ::initialEstimate($node) $val
                            } min {
                                set ::minForOpt($node) $val
                            } max {
                                set ::maxForOpt($node) $val
                            } when {
                                set ::timeInfo($node) $val
                            } period {
                                set ::regularInt($node) $val
                            } default {
                                set inGrpData($node,$tgt) $val
                            }
                        }
                    }
                    if {[winfo exists $f.int]} {
# only exists if input is slider
			AbleTimeData $node $f
		    }
                } inSource {
                    set useNodes($winId,gathering) [lindex $action 1]
                } output {
                    set title [lindex $action 1]
                    set node [GetIdFromCaptionPath $title]
                    if {[string equal nomatch $node]} {
                        ShowMess "Problem restoring PEST settings" warning \
                                "Could not add $title to PEST outputs because there is no component with this caption in the model" ok
                        continue
                    }
                    foreach {tgt val} [lrange $action 2 end] {
                        switch $tgt {
                            weight {
				set outGrpData($node,weight) $val
			    } sampled {
                                set readMany($title) $val
                            }
                        }
                    }
                    set f [InsertDriver $winId $node $title]
                } outDest {
                    set useNodes($winId,scrogging) [lindex $action 1]
                } predict {
                    set useNodes($winId,preds) 1
                    foreach {tgt val} [lrange $action 1 end] {
                        switch $tgt {
                            way {
                                set useNodes($winId,way) $val
                            } item {
                                set useNodes($winId,pred) $val
                            } time {
                                set useNodes($winId,ptim) $val
                            }
                        }
                    }
                } clevers {
                    foreach {tgt val} [lrange $action 1 end] {
                        set clevers($tgt) $val
                    }
                } default {
                    ShowMess {Problem with PEST saved state} info \
                            "Could not use this line: $action" ok
                }
            }
        }
        AbleEstimateFields $winId
    }
    
    proc AddVariable {winId} {
        variable useNodes
        $useNodes($winId,input).intro configure -text "Click on an input parameter to allow PEST to write it, or on a submodel border to allow PEST to write all input variables inside it."
        SetState $winId adding_inputs
        GrabClicks $winId
    }
    
    proc AddVariableOut {winId} {
        variable useNodes
        $useNodes($winId,output).intro configure -text "Click on a model value to allow PEST to read it at the end of each model run for comparison with measured data."
        SetState $winId adding_outputs
        GrabClicks $winId
    }
    
    proc AddTimeSeries {winId} {
        variable useNodes
        $useNodes($winId,output).intro configure -text "Click on a model value to allow PEST to read it for comparison with a time series of measured data."
        SetState $winId adding_series
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
	global readMany
        variable useNodes
        
        set fullCapt [GetCaptionPathFromId $node]
        switch [GetState $winId] {
            adding_inputs {
                if {[string equal SUBMODEL [GetModelClass $node]]} {
                    set success [AddAllVariables $winId $fullCapt]
                } else {
                    set success [InsertSlider $winId $node $fullCapt 1]
                }
                if {[llength $success]} {
                    $useNodes($winId,input).intro configure -text {}
                    ReleaseClicks $winId
                }
            } adding_outputs {
		set readMany($fullCapt) 0
                set success [InsertDriver $winId $node $fullCapt]
                if {[llength $success]} {
                    $useNodes($winId,output).intro configure -text {}
                    ReleaseClicks $winId
                }
            } adding_series {
		set readMany($fullCapt) 1
                set success [InsertDriver $winId $node $fullCapt]
                if {[llength $success]} {
                    $useNodes($winId,output).intro configure -text {}
                    ReleaseClicks $winId
                }
             } adding_pred {
                set useNodes($winId,npred) $node
                set useNodes($winId,pred) $caption
                #		set success [SetPred $winId $node $fullCapt 1]
                #		if {[llength $success]} {
                $useNodes($winId,results).intro configure -text {}
                ReleaseClicks $winId
                #		}
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
            if {[llength [InsertSlider $winId $node $title 1]]} {
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
            return {}
        }
        set datatype [GetModelType $node]
        if {![string equal REAL $datatype]} {
            $inpId.intro configure -text "This component cannot be esimated by PEST because its datatype is $datatype. Only parameters of type REAL can be estimated."
            return {}
        }
        set levels [split $title /]
        if {$nest} {
            set f [MakeSubFrames $inpId $inpId.c.canvas.frame $levels {} 0]
            if {[winfo exists $f]} {
                $inpId.c.canvas see $f
                return $f
            } else {
                pack [frame $f] -fill x -expand true
		KoreanClick $f 1 {}
                bind $f <Double-1> [namespace code \
                        [list DoInpDlg $node $f $title]]
                bind $f <Button-3> [namespace code \
                        [list DoInpDlg $node $f $title]]
            }
        } else {
            set f $inpId
        }
	lappend useNodes($winId,sliders) $title
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
# min and max limits restricted cos pest is single precision
        set ::minForOpt($node) [max [GetMinValue $node] -1e10]
        set ::maxForOpt($node) [min [GetMaxValue $node] 1e10]
        set ::initialEstimate($node) \
                [expr ($::minForOpt($node)+$::maxForOpt($node))/2]
        pack [entry $f.est -textvariable initialEstimate($node) -width 8] \
                -side right
        pack [label $f.estlbl -text Estimate:] -side right
        foreach widjo [winfo children $f] {
	    KoreanClick $widjo 1 {}
            bind $widjo <Double-1> [namespace code \
                    [list DoInpDlg $node $f $title]]
            bind $widjo <Button-3> [namespace code \
                    [list DoInpDlg $node $f $title]]
        }
        return $f
    }
    
    proc DoInpDlg {node win title} {
        global minForOpt maxForOpt
        variable inGrpData
        set t [PutItThere .pestinpdlg $win]
        wm protocol .pestinpdlg  WM_DELETE_WINDOW [namespace code DoneInpDlg]
        wm title $t "Set properties for $title"
        
        pack [set f [labelframe $t.grp -text "Group properties:"]] \
                -padx 4 -pady 4
        set ns [namespace current]
        pack [frame $f.inctype]
        pack [label $f.inctype.l -text INCTYPE] -side left
        pack [ttk::combobox $f.inctype.c -values {relative absolute rel_to_max} \
                -state readonly -textvariable ${ns}::inGrpData($node,inctype)] \
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
        pack [ttk::combobox $f.forcen.c -values {always_2 always_3 switch} \
                -state readonly -textvariable ${ns}::inGrpData($node,forcen)] \
                -side left
        
        pack [frame $f.derincmul]
        pack [label $f.derincmul.l -text DERINCMUL] -side left
        pack [entry $f.derincmul.e -width 8 \
                -textvar ${ns}::inGrpData($node,derincmul)] \
                -side left
        
        pack [frame $f.dermthd]
        pack [label $f.dermthd.l -text DERMTHD] -side left
        pack [ttk::combobox $f.dermthd.c -values {parabolic best_fit outside_pts} \
                -state readonly -textvariable ${ns}::inGrpData($node,dermthd)] \
                -side left
        
        pack [set f [labelframe $t.inp -text "Value transformations:"]] \
                -padx 4 -pady 4
        pack [frame $f.partrans]
        pack [label $f.partrans.l -text PARTRANS] -side left
        pack [ttk::combobox $f.partrans.c -values {none log} \
                -state readonly -textvariable ${ns}::inGrpData($node,partrans)] \
                -side left
        
        # If the parameter can cross zero its change limit must default to relative
        if {$minForOpt($node)*$maxForOpt($node)<0} {
            set inGrpData($node,parchglim) relative
        }
        pack [frame $f.parchglim]
        pack [label $f.parchglim.l -text PARCHGLIM] -side left
        pack [ttk::combobox $f.parchglim.c -values {relative factor} \
                -state readonly -textvariable ${ns}::inGrpData($node,parchglim)] \
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
    
    proc InsertDriver {winId node title} {
        global targetData myNode
        variable useNodes
        variable outGrpData
        set outId $useNodes($winId,output)
        
        set mode [GetModelEval $node]
        if {[lsearch {TABLE INPUT} $mode]>-1} {
            $outId.intro configure -text "This component cannot be optimized by PEST because it is a fixed or variable parameter."
            return {}
        }
        set datatype [GetModelType $node]
        if {![string equal REAL $datatype]} {
            $outId.intro configure -text "This component cannot be optimized by PEST because its datatype is $datatype. Only parameters of type REAL can be optimized."
            return {}
        }
        
        set outGrpData($node,weight) 1.0
        set f [MakeSubFrames $myNode $outId.c.canvas.frame \
                [split $title /] [namespace current] 0]
        if {[winfo exists $f]} {
            $outId.c.canvas see $f
        } else {
            lappend targetData(needed) $title
            set mess [AddEntry $outId $myNode $node 1 -1]
	    if {[string length $mess]} {
		$useNodes($winId,output).intro configure -text $mess
		return {}
	    }
	    set targetData($title) {} ;# in case used before with different reqs
	    lappend useNodes($winId,drivers) $title
            
#            pack [checkbutton $f.end -variable ::readMany($title) \
#                    -command [namespace code \
#                    [list AbleTimeSampling $myNode $node $title $f]]] \
#                    -side left
#            BindPopup $f.end "Set values at time points"
# do command now in case it was selected last time
#            AbleTimeSampling $myNode $node $title $f
	    foreach widjo [concat [list $f] [winfo children $f]] {
		KoreanClick $widjo 1 {}
                bind $widjo <Double-1> [namespace code \
                        [list DoOutDlg $node $f $title]]
                bind $widjo <Button-3> [namespace code \
                        [list DoOutDlg $node $f $title]]
            }
        }
        return $f
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
    
# No longer used -- now have two buttons, one for each time setting
#    proc AbleTimeSampling {topNode node title f} {
#        global readMany
#        
#	set nodeDims [GetCompProperty $topNode Dims $node]
#        set trans [GetTransTable $node]
#        if {$readMany($title)} {
#            set $nodeDims [linsert $nodeDims 0 TIME]
#            set trans [linsert $trans 0 {}]
#        }
#        set nodeDims [TransBounds $trans $nodeDims]
#        set dimList [MakeDimsLegible $nodeDims REAL]
#        $f.l2 config -text ($dimList)
#        ColourCaptions $f red
#        if {[llength $nodeDims]>1} {
#            pack $f.b -after $f.l2 -side right
#        } else {
#            pack forget $f.b
#        }
#    }
#    
    proc DoOutDlg {node win title} {
        global minForOpt maxForOpt
        variable outGrpData
        set t [PutItThere .pestoutdlg $win]
        wm protocol .pestoutdlg  WM_DELETE_WINDOW [namespace code DoneOutDlg]
        wm title $t "Set properties for $title"
        
        pack [set f [labelframe $t.inp -text "Value interpretations:"]] \
                -padx 4 -pady 4
        pack [frame $f.weight]
        pack [label $f.weight.l -text WEIGHT] -side left
        pack [entry $f.weight.e -width 8 \
                -textvar [namespace current]::outGrpData($node,weight)] \
                -side left
        
        pack [button $t.done -text Done -command [namespace code DoneOutDlg]]
        LetItShow $t
        grab $t
        tkwait variable [namespace current]::outGrpData(done)
        grab release $t
        PackItUp $t
    }
    
    proc DoneOutDlg {} {
        set [namespace current]::outGrpData(done) 1
    }
    
    proc Remove {winId title} {
        variable useNodes
        set inpId $useNodes($winId,input)
        set levels [split $title /]
        set f [MakeSubFrames {} $inpId.c.canvas.frame $levels {} 0]
        Prune $inpId $f
	set index [lsearch $useNodes($winId,sliders) $title]
	set useNodes($winId,sliders) \
	    [lreplace $useNodes($winId,sliders) $index $index]
    }
    
    proc RemoveOut {winId title} {
        variable useNodes
	global targetData
        set outId $useNodes($winId,output)
        set levels [split $title /]
        set f [MakeSubFrames {} $outId.c.canvas.frame \
                $levels [namespace current] 0]
        Prune $outId $f
	array unset targetData $title
	set index [lsearch $useNodes($winId,drivers) $title]
	set useNodes($winId,drivers) \
	    [lreplace $useNodes($winId,drivers) $index $index]
	set index [lsearch $targetData(needed) $title]
	if {$index>-1} { ;# data was incomplete
	    set targetData(needed) \
			     [lreplace $targetData(needed) $index $index]
	}
    }
    
    proc Prune {winId tree} {
        set up [winfo parent $tree]
        destroy $tree
        if {![string equal ${winId}.c.canvas.frame $up]} {
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
            ShowMess {Substituting measured values} warning \
                    "You have selected to display the measured values supplied to the PEST interface helper for the output components, rather than their actual values from the model." ok
        }
    }
    
    proc display {winId time display remainder} {
        
        # Check if the model is being run by PEST, and if it is, write data
        # for any model outputs for which we have reached recording time
        # points...nah, we are only running it between recording points.
        
    }
    
    proc Stop {winId} {
        global myNode
        variable runData
        
        PokeStopFile $winId 2
        $runData($myNode,progressBar) configure -value 0
    }
    
    proc Pause {winId} {
        variable useNodes
        set useNodes($winId,state) 3
        PokeStopFile $winId 3
        SetButtonAct $winId start
    }
    
    proc Go {winId} {
        variable useNodes
        
	if {$::runState($::myNode,modelRunning)<3} {
	    Query no_model_to_start warning pest_setup $winId ok
	    return
	}
        PokeStopFile $winId 0
        if {$useNodes($winId,state)==3} { ;# it was paused
	    SetButtonAct $winId pause
            set useNodes($winId,state) 0
	    WaitTillDone $winId
	    return
        }        
        set useNodes($winId,rnum) 1
        if {$useNodes($winId,preds)} {
	    if {![info exists useNodes($winId,npred)]} {
		ShowMess "No value to predict" warning "Predictive analysis selected, but no model value chosen for prediction!" ok
		return
	    }
            set useNodes($winId,predall) {}
            set useNodes($winId,numRuns) [expr int(($useNodes($winId,pstp) \
                    -$useNodes($winId,pgo)) \
                    /$useNodes($winId,predint))+1]
	    set useNodes($winId,ptim) $useNodes($winId,pgo)
        } else {
	    set useNodes($winId,numRuns) 1
	}
	Optimize $winId
    }
    
    proc LoadMeasurements {winId} {
	global myNode readMany targetData

	variable useNodes
	variable spitLists
	variable ptList

        set runLength [$useNodes($winId,results).lbf.rl.ent get]
	foreach eTitle $useNodes($winId,drivers) {
            AcceptData $myNode $eTitle -1 1
            set node [GetIdFromCaptionPath $eTitle]
            set levels [split $eTitle /]
            set outId $useNodes($winId,output)
            set f [MakeSubFrames {} $outId.c.canvas.frame \
                    $levels [namespace current] 0]
            if {$readMany($eTitle)} {
                foreach {time defSet} $targetData($eTitle) {
                    lappend spitLists($time) $node=$defSet
                }
            } else {
                lappend spitLists($runLength) $node=$targetData($eTitle)
                set useEndTime 1
            }
        }
	if {[llength $targetData(needed)]} {
	    ShowMess "PEST setup incomplete" warning "Some measured data not specified: [join $targetData(needed) ", "]" ok
	    return
	}
        set ptList [lsort -real [array names spitLists]]   
	return runLength
    }

    proc Optimize {winId} {
        
        # Time to invoke PEST. First we must make a template file that allows
        # PEST to create a .spf file that will parameterize the model. Usually
        # a .spf file is MIME-encoded and contains references to other files,
        # but neither of these need be done here.
        
        global simtmpdir minForOpt maxForOpt
        global tcl_platform sender paramData myNode archExtn execExtn
        variable useNodes
        variable clevers
        variable usedHangers
        variable inGrpData
        variable outGrpData
        variable inClevers1
        variable ptList
        variable spitLists
        variable runData
        
        $useNodes($winId,results).dbf.c.text delete 1.0 end
        $useNodes($winId,results).b configure -state disabled
        
        # First, look at the outputs required at times before the end
        # of the run and create an array holding lists of nodes whose
        # values will be written at each time...
        
        array unset spitLists
        set usedHangers 0
        array unset outGrpData *,mems
        
	set numInputs [llength $useNodes($winId,sliders)]
	if {!$numInputs} {
	    ShowMess "No PEST Inputs" warning "You have not specified any model parameters for PEST to estimate" ok
	    return
	}
        # Descend hierarchically through the frames to get the data? No, use kill menu

	set numOutputs [llength $useNodes($winId,drivers)]
	if {!$numOutputs} {
	    ShowMess "No PEST Outputs" warning "You have not specified any model outputs for PEST to attempt to match with measurements" ok
	    return
	}
        if {$useNodes($winId,preds)} {
            incr numOutputs
            lappend spitLists($useNodes($winId,ptim)) \
                    $useNodes($winId,npred)=what
	    lappend ptList $useNodes($winId,ptim)
            set mode prediction
        } else {
            set mode estimation
        }
        set runLength [LoadMeasurements $winId]
        set lastPt [lindex $ptList end]
        if {[info exists useEndTime]} {
            if {$runLength<$lastPt} {
                ShowMess "Run length too short" warning \
                        "You have specified a run length of $runLength time units. This is not long enough to record all the model outputs, which are required at times up until $lastPt units." ok
                return
            }
        }
        set ::runState($myNode,execTime) $lastPt
	set ::runState($myNode,progressToDate) \
	    [expr ($useNodes($winId,rnum)-1)*$clevers(noptmax)]
        
        # Have a look at the inputs
        
        set template [NetOpen [file join $simtmpdir model.tpl] w]
# What to use for delimiter? 
# \ is needed to escape newlines in name
# / appears between submodel levels
# . may appear in a time point index
# newline would probably confuse PEST
# How about escaping some other character as well as newline and using that?
        puts $template "ptf \\"
        
        array unset inGrpData *,mems
	$useNodes($winId,results).dbf.c.text insert end \
	    "PEST indentifiers for Simile model input values:\n"

# new version that writes XML and uses the frame hierarchy to get the submodel
# hierarchy this requires
puts $template "<?xml version=\"1.0\"?>"
puts $template "<?xml-stylesheet type=\"text/xsl\" href=\"spf1.xsl\"?>"
puts $template "<spf simile_version=\"$::env(SIMILE_VERSION)\">"
puts $template "<submodel label=\"top\">"
	
	set inpId $useNodes($winId,input)
	WriteXMLTemplate $winId $template {} $inpId.c.canvas.frame.frame

puts $template "</submodel>"
puts $template "</spf>"

# end of new version

#	foreach eTitle $useNodes($winId,sliders) {
#            set node [GetIdFromCaptionPath $eTitle]
#            set levels [split $eTitle /]
#            set inpId $useNodes($winId,input)
#            set f [MakeSubFrames {} $inpId.c.canvas.frame \
#                    $levels [namespace current] 0]
#            
#            set nodeDims [GetModelDims $node]
#            if {$useNodes($winId,gathering)} {
#                #		set defCons $paramData($eTitle)
#                #		if {![string length $defCons]} {
#                set defCons [lindex [GetModelValue $node] 0]
#                if {[winfo exists $f.int]} {
#                    set defCons [list NOW $defCons]
#                }
#                #		}
#            } else {
#                set defCons $initialEstimate($node)
#            }
#            set defVal [$f.est get]
#	    set startHanger [expr $usedHangers+1]
#            puts -nonewline $template $eTitle=
#            if {[winfo exists $f.int]} {
#                if {$useNodes($winId,gathering)} {
#                    foreach {timePt vList} $defCons {
#                        puts -nonewline $template "$timePt "
#                        AddHangers $node $template $vList $nodeDims 1
#                        puts -nonewline $template " "
#                    }
#                } elseif {[string equal normal [$f.int cget -state]]} {
#                    set int [$f.int get]
#                    
#                    # Only try to calculate inputs up to and including the time
#                    # at which the last output is read
#                    
#                    for {set setTime 0} {$setTime <= $lastPt} \
#                            {set setTime [expr {$setTime+$int}]} {
#                                puts -nonewline $template "$setTime "
#                                AddHangers $node $template $defCons $nodeDims 1
#                                puts -nonewline $template " "
#                            }
#                } else {
#                    puts -nonewline $template "NOW "
#                    AddHangers $node $template $defCons $nodeDims 1
#                }
#            } else {
#                AddHangers $node $template $defCons $nodeDims 0
#            }
#            puts $template {}
#	    if {$usedHangers==$startHanger} {
#		set hangerRange "is i$usedHangers"
#	    } else {
#		set hangerRange "from $startHanger to $usedHangers"
#	    }
#	    $useNodes($winId,results).dbf.c.text insert end \
#		"$eTitle $hangerRange\n"
#        }
        close $template
        
        set control [NetOpen [file join $simtmpdir model.pst] w]
        puts $control pcf
        puts $control {* control data}
        puts $control [list restart $mode]
        puts -nonewline $control $usedHangers
        
        # right, now to make the instruction file for reading the outputs
        
	$useNodes($winId,results).dbf.c.text insert end \
	    "PEST indentifiers for Simile model output values:\n"
        set usedHangers 0
        set instruct [NetOpen [file join $simtmpdir model.ins] w]
        puts $instruct "pif \\"
        foreach brkPt $ptList {
            foreach entry $spitLists($brkPt) {
		set startHanger [expr $usedHangers+1]
                set pair [split $entry =]
                set node [lindex $pair 0]
		set dims [GetModelDims $node]
#                puts -nonewline $instruct "\\$node at $brkPt is\\ "
                if {[string equal what [lindex $pair 1]]} { ;# prediction
		    set warns [AddChoppers predict $brkPt $instruct {} $dims 1]
                    set runData($myNode,predictTag) o$usedHangers
                } else {
                    set warns [AddChoppers $node $brkPt $instruct {} $dims \
				   [lindex $pair 1]]
                }
                puts $instruct {}
		if {$usedHangers==$startHanger} {
		    set hangerRange "is o$usedHangers"
		} else {
		    set hangerRange "from o$startHanger to o$usedHangers"
		}
		$useNodes($winId,results).dbf.c.text insert end \
		    [join [concat [list "[GetCaptionPathFromId $node] $hangerRange"] $warns [list {}]] \n]
            }
        }
        close $instruct
        
        
        
        
        puts $control " $usedHangers [llength $useNodes($winId,sliders)] 0 \
$numOutputs"
        puts $control "1 1 single point 1 0 0"
        foreach line $clevers(list) {
            foreach {val spare} $line {
                puts -nonewline $control "$clevers($val) "
            }
            puts $control {}
        }
        puts $control "0 0 0" ;# ICOV, ICOR, IEIG
        
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
            foreach {parmVal initEst} $inGrpData($parmGrp) {
                puts $control [list $parmVal $inGrpData($node,partrans) \
                        $inGrpData($node,parchglim) $initEst \
                        $minForOpt($node) $maxForOpt($node) $node \
                        $inGrpData($node,scale) \
                        $inGrpData($node,offset) 1]
            }
        }
        
        puts $control {* observation groups}
        foreach obsGrp [array names outGrpData *,mems] {
            set node [string range $obsGrp 0 end-5]
            puts $control $node
        }
        
        set outGrpData(predict,weight) 1 ;# this is ignored if used
        puts $control {* observation data}
        foreach obsGrp [array names outGrpData *,mems] {
            set node [string range $obsGrp 0 end-5]
            foreach combo $outGrpData($obsGrp) {
                puts $control [concat [split $combo =] \
                        [list $outGrpData($node,weight) $node]]
            }
        }
        
        set oldDir [pwd]
	set sysDir $::env(SYSDIR)
        if {[string match windows $tcl_platform(platform)]} {
            set sysDir [file attributes $sysDir -shortname]
        }
        puts $control {* model command line}
        set ourWish \"[file join $sysDir bin relay$archExtn$execExtn]\"
        puts $control [file nativename $ourWish]
        puts $control {* model input/output}
        puts $control {model.tpl model.inp}
        puts $control {model.ins model.out}
        
        if {[string equal prediction $mode]} {
            if {[string length $useNodes($winId,pfit)]} {
                FixPredWindow $useNodes($winId,pfit)
            }
            puts $control {* predictive analysis}
            puts $control [string compare melge $useNodes($winId,way)]
            foreach line $clevers(pred) {
                foreach {val spare} $line {
                    puts -nonewline $control "$clevers($val) "
                }
                puts $control {}
            }
        }
        $runData($myNode,progressBar) config -maximum \
	    [expr $useNodes($winId,numRuns)*$clevers(noptmax)]
        close $control
        
        #	set activator [NetOpen [file join $simtmpdir pestrun.tcl] w]
        #	if {[string match windows $tcl_platform(platform)]} {
        #	    puts $activator "package require dde 1.2" ;# must be easier way
        #	}
        #	puts $activator "$sender [list do_for_node $::myNode] [namespace code pestificate]"
        #	puts $activator exit
        #	close $activator
        
        # That was the old way of getting PEST to run the model. Now
        # we just wait till it kills the relay process, then run it
        # for it and start another.
        
        SetButtonAct $winId pause
        cd $simtmpdir
        set pip [open pestmsgs.txt w]; puts $pip 0; close $pip
        StartRelay $winId $ourWish
        
        # ok, now we need to execute pest in immediate mode in order to get
        # any error messages back from it. However, while doing that we can't
        # run the model -- so get the editor process to call it when it has a
        # moment. Sadly that don't work either, since the commands to execute
        # the model call the editor process back to check for updates.
        
        set runData($myNode,rollCount) 0
        set runData($myNode,recSize) 0
        set runData($myNode,curPred) N/A
        set spout [SilentRun "pest model.pst"]
        cd $oldDir
        set useNodes($winId,state) 0 ;# rolling
        
        fconfigure $spout -blocking 0
        fileevent $spout readable [namespace code [list GrabMsgs $winId $spout]]
        # Problem is, if we are doing lots of PEST runs at once, we do not want to
        # start one before the previous one is finished so wait here
        
	WaitTillDone $winId
    }

    proc WaitTillDone {winId} {
	variable useNodes

        tkwait variable [namespace current]::useNodes($winId,state)

	if {$useNodes($winId,preds) && $useNodes($winId,state)==2} {
	    set useNodes($winId,ptim) \
		[expr $useNodes($winId,pgo) + \
		     $useNodes($winId,rnum)*$useNodes($winId,predint)]
	    incr useNodes($winId,rnum)
	    if {$useNodes($winId,rnum)<=$useNodes($winId,numRuns)} {
		Optimize $winId
	    }
	}
    }
    
    proc StartRelay {winId cmd} {
        global simtmpdir
        variable relayProc
        
        set oldDir [pwd]
        cd $simtmpdir

        set relayProc [open |$cmd r]
        # was [SilentRun $cmd]
        fconfigure $relayProc -blocking 0
        fileevent $relayProc readable \
	    [namespace code [list pestificate $winId $cmd]]
        cd $oldDir
    }
    
    proc SilentRun {cmd} {
        global tcl_platform
        switch $tcl_platform(os) {
            {Windows NT} {
                # previous versions

		# exec cmd /c start /min pest model.pst >& model.log

                # set spout [open "|cmd /c start /min $cmd" r]

		set batSt [open runpest.bat w]
		puts $batSt "type model.pst"
		puts $batSt $cmd
		close $batSt
                set spout [open |runpest.bat r]
            } {Windows 95} {
                # exec start /m pest model.pst >& model.log

                set spout [open "|start /m $cmd" r]
            } default {
                # exec pest model.pst >& model.log &
                set spout [open "|$cmd" r]
            }
        }
	return $spout
    }
    
    # for now, just use pipe to tell when PEST has finished
    proc GrabMsgs {winId spout} {
        global simtmpdir myNode
        variable useNodes
        variable runData
        variable relayProc
        
        if {[gets $spout bilge]>-1} {
            if {![string equal Bye $bilge]} { ;# from relay process
                $useNodes($winId,results).dbf.c.text insert end "$bilge\n"
            }
        } elseif {[eof $spout]} {
            set pip [open $simtmpdir/pestmsgs.txt r]; gets $pip pidl; close $pip
            #ShowMess debug info "Shrink...I wanna kill $pidl" ok
            c_killmodel $pidl
            close $relayProc
            unset relayProc
            SetButtonAct $winId start
            set useNodes($winId,state) 2 ;# stopped, with data
            $useNodes($winId,results).b configure -state normal
            close $spout
            
            # now grab final PHI value from .rec
            set recFile [file join $simtmpdir model.rec]
	    if {![file exists $recFile]} {
		Query no_pest_output warning pest_setup {} ok
		return
	    }
            set recReader [NetOpen $recFile r]
            seek $recReader $runData($myNode,recSize)
            while {![eof $recReader]} {
                gets $recReader recLin
                # if there is a prediction, grab it (win98 cannot find it in console output)
                if {$useNodes($winId,preds)} {
                    if {[scan $recLin " $runData($myNode,predictTag) %f \
                                predict" curPred]>0} {
                        set runData($myNode,curPred) $curPred
                        lappend useNodes($winId,predall) \
                                \#$useNodes($winId,ptim): $curPred
                    }
                }
                if {[scan $recLin {   Sum of squared weighted residuals (ie phi)                = %f} curPhi]>0} {
                    set runData($myNode,curPhi) $curPhi
                    if {!$useNodes($winId,preds)} {
                        set runData($myNode,bestPhi) $curPhi
                        FixPredWindow 2.5
                    }
                    break
                }
            }
            close $recReader
        }
    }
    
    proc FixPredWindow {fac} {
        global myNode
        variable clevers
        variable runData
        # make some clever-looking guesses at the prediction parameters
        set closish $runData($myNode,bestPhi)
        set clevers(pd0) [format %0.3g [expr $closish*pow($fac,0.2)]]
        set clevers(pd1) [format %0.3g [expr $closish*pow($fac,0.25)]]
        set clevers(pd2) [format %0.3g [expr $closish*$fac]]
    }
    
    proc PokeStopFile {winId n} {
        global simtmpdir
        variable useNodes
        set stpipe [open [file join $simtmpdir pest.stp] w]
        puts $stpipe $n
        close $stpipe
    }
    
    # Next bit will actually be executed by command supplied to PEST
    
    proc pestificate {winId cmd} {
        global runState simtmpdir errorInfo
        variable ptList
        variable spitLists
        variable runData
        variable relayProc

        if {![info exists relayProc]} {
            return ;# we have finished the run
        }
        close $relayProc
        set topNode $::myNode
        set recFile [file nativename [file join $simtmpdir model.rec]]
        #	if {[info exists $recFile]} {
        set newSize [file size $recFile]
        #	} else {
        #	    set newSize 0
        #	}
        #	puts "old $runData($topNode,recSize) new $newSize"
        if {$newSize>$runData($topNode,recSize)} {
            set recReader [NetOpen $recFile r]
            seek $recReader $runData($topNode,recSize)
            set runData($topNode,recSize) $newSize
            while {![eof $recReader]} {
                gets $recReader recLin
                if {[scan $recLin { OPTIMISATION ITERATION NO.        : %d} \
                            itCount]>0} {
                    set runData($topNode,itCount) $itCount
                    $runData($topNode,progressBar) configure -value \
			[expr $runState($topNode,progressToDate)+$itCount]
                }
                if {[scan $recLin {    Starting phi for this iteration : %f} \
                            curPhi]>0} {
                    set runData($topNode,curPhi) $curPhi
                }
                if {[scan $recLin {    M%*c%*cimum prediction so far for phi less than PD1 : %f} curPred]>0} {
                    set runData($topNode,curPred) $curPred
                }
            }
            close $recReader
        }
        
        if {[catch {
                
                # load the PEST-generated .spf file
                ZapParams $topNode {} \
                        [file nativename [file join $simtmpdir model.inp]] 0
                
                set widget $runState($topNode,helperId).nb.rcf
                $widget.upper.topbuttons.reset invoke
                
                set execLog [NetOpen [file nativename [file join $simtmpdir model.out]] w]
                set current 0
                foreach breakPt $ptList {
                    set runState($topNode,pause) $breakPt
                    $widget.upper.topbuttons.start invoke
                    if {$runState($topNode,currentTime)<$breakPt} {
			Pause $winId
			Query [list pause_in_pest_exec $breakPt \
				   $runState($topNode,currentTime)] \
			    warning pest_setup {} ok
                    }
                    foreach pair $spitLists($breakPt) {
                        set node [lindex [split $pair =] 0]
                        # need to prettify so we can seek on indices
                        #set writable [PrettifyValList [lindex [GetModelValue $node] 0]]
                        #puts $execLog "$node at $breakPt is $writable"
			# no more, each value now gets its own line
			WriteForPest $execLog $node $breakPt \
			    [lindex [GetModelValue $node] 0]
                    }
                    set current $breakPt
                }
                close $execLog
                StartRelay $winId $cmd
            }]} {
            ShowMess "Problem executing from PEST" warning $errorInfo ok
        }
        incr runData($topNode,rollCount)
        #	set runData($topNode,recSize) [file size \
        #					   [file join $simtmpdir model.rec]]
    }
    
    proc WriteForPest {log node timePt data} {
	if {[llength $data]==1} {
	    puts $log "$node at $timePt is $data"
	} else {
	    foreach {ind value} $data {
		WriteForPest $log $node.$ind $timePt $value
	    }
	}
    }

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
        
        # Turn off interval display? Why bother; displaying at irregular
        # intervals will only mess up the other plots, and if we are
        # interpolating anyway, why not do so at every time point? Just so
        # long as we can scrog the values before the display tools get
        # them...(and put them back after)...do by putting specials at
        # beginning and end of helper list? Fine, except it's an array...
            
    proc ScrogOutputs {subTime} {
	global subbedPlots

        variable useNodes
        variable ptList
        variable spitLists
        
        foreach activeSub [array names useNodes *,scrogging] {
            if {$useNodes($activeSub)} {
                set winId [string range $activeSub 0 end-10]
                
		foreach eTitle $useNodes($winId,drivers) {
                    set node [GetIdFromCaptionPath $eTitle]
                    
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
                        #; 0.0 fixes bloody Tcl arithmetic that thinks 1/2 = 0
                        set progFrack [expr (0.0+$subTime-[lindex $lo 0])/ \
                                ([lindex $hi 0]-[lindex $lo 0])]
                        set mid [Interpo $progFrack [lindex $lo 1] [lindex $hi 1]]
                        unset lo
                    } else {
                        set mid [lindex $hi 1]
                    }
                    set subbedPlots($node) $mid
                    unset hi
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
    
    proc AddChoppers {node brkPt str subs dims data} {
        variable usedHangers
        variable outGrpData
        
	set wobbles {}
        if {[llength $data]!=1} {
            foreach {n val} $data {
		if {$n>[lindex $dims 0]} {
		    lappend wobbles [format $::msgs(too_many_pest_pts) $subs]
		    break
		}
#                puts -nonewline $str "\\\#$n:\\ "
                set wobbles [concat $wobbles \
				 [AddChoppers $node $brkPt $str $subs.$n \
				      [lrange $dims 1 end] $val]]
#                puts -nonewline $str " "
            }
        } else {
	    puts $str "\\$node$subs at $brkPt is\\ !o[incr usedHangers]!"
#            puts -nonewline $str !o[incr usedHangers]!
            lappend outGrpData($node,mems) o$usedHangers=$data
        }
	return $wobbles
    }
    
#    proc AddHangers {node str est dms brs} {
#        variable usedHangers
#        variable inGrpData
#        
#        if {[lindex $dms 0]>0} {
#            if {[llength $est]>1} {
#                array set arrEst $est
#            }
#            if {$brs==1} {
#                puts -nonewline $str \{
#            }
#            for {set n 1} {$n <= [lindex $dms 0]} {incr n} {
#                puts -nonewline $str "$n "
#                if {[info exists arrEst]} {
#                    set est $arrEst($n)
#                }
#                AddHangers $node $str $est [lrange $dms 1 end] 1
#                puts -nonewline $str " "
#            }
#            if {$brs==1} {
#                puts -nonewline $str \}
#            }
#        } else {
#            puts -nonewline $str [format \\%10s\\ i[incr usedHangers]]
#            lappend inGrpData($node,mems) i$usedHangers $est
#        }
#    }
#    

# version for XML
    proc AddHangers {node stm est dms i} {
        variable usedHangers
        variable inGrpData
        
        if {[lindex $dms 0]>0} {
            if {[llength $est]>1} {
                array set arrEst $est
            }
            for {set n 1} {$n <= [lindex $dms 0]} {incr n} {
                if {[info exists arrEst]} {
                    set est $arrEst($n)
                }
		if {[lindex $dms 1]>0} {
		    puts $stm "<values index=[Entitize $n]>"
		}
                AddHangers $node $stm $est [lrange $dms 1 end] $n
		if {[lindex $dms 1]>0} {
		    puts $stm "</values>"
		}
            }
        } else {
	    puts $stm "<value index=[Entitize $i] value=\"[format \\%10s\\ i[incr usedHangers]]\"/>"
            lappend inGrpData($node,mems) i$usedHangers $est
        }
    }
    
    proc WriteXMLTemplate {winId stm path subFrame} {
	global initialEstimate
	variable useNodes
	variable ptList
	variable usedHangers
        variable inGrpData

	set descent [winfo children $subFrame]
	puts $stm "<variables>"
	foreach f [lsearch -inline -all $descent $subFrame.box*] {
	    set level [string range $f [expr {[string last . $f]+4}] end]
	    set node [GetIdFromCaptionPath $path/$level]

            set nodeDims [GetModelDims $node]
            if {$useNodes($winId,gathering)} {
                #		set defCons $paramData($eTitle)
                #		if {![string length $defCons]} {
                set defCons [lindex [GetModelValue $node] 0]
                if {[winfo exists $f.int]} {
                    set defCons [list NOW $defCons]
                }
                #		}
            } else {
                set defCons $initialEstimate($node)
            }
            set defVal [$f.est get]
	    set startHanger [expr $usedHangers+1]
            if {[winfo exists $f.int]} {
		puts $stm "<multi_value label=[Entitize $level]>"
                if {$useNodes($winId,gathering)} {
                    foreach {timePt vList} $defCons {
                        AddHangers $node $stm $vList $nodeDims $timePt
		    }
                } elseif {[string equal normal [$f.int cget -state]]} {
                    set int [$f.int get]
                    
                    # Only try to calculate inputs up to and including the time
                    # at which the last output is read
                    
                    for {set setTime 0} {$setTime <= [lindex $ptList end]} \
			{set setTime [expr {$setTime+$int}]} {
			    AddHangers $node $stm $defCons $nodeDims $setTime
			}
                } else {
                    AddHangers $node $stm $defCons $nodeDims NOW
		}
		puts $stm "</multi_value>"
            } else {
		if {![lindex $nodeDims 0]} {
		    puts $stm "<single_value label=[Entitize $level] val=\"[format \\%10s\\ i[incr usedHangers]]\"/>"
		    lappend inGrpData($node,mems) i$usedHangers $defCons
		} else {
		    puts $stm "<multi_value label=[Entitize $level]>"
		    AddHangers $node $stm $defCons $nodeDims unused
		    puts $stm "</multi_value>"
		}
	    }
	    if {$usedHangers==$startHanger} {
		set hangerRange "is i$usedHangers"
	    } else {
		set hangerRange "from i$startHanger to i$usedHangers"
	    }
	    $useNodes($winId,results).dbf.c.text insert end \
		"$path/$level $hangerRange\n"
	}
	puts $stm "</variables>"
	puts $stm "<submodels>"
	foreach f [lsearch -inline -all $descent $subFrame.frame*] {
	    set level [string range $f [expr {[string last . $f]+6}] end]
	    puts $stm "<submodel label=[Entitize $level]>"
	    WriteXMLTemplate $winId $stm $path/$level $f
	    puts $stm "</submodel>"
	}
	puts $stm "</submodels>"
    }

    proc Save {topNode smPath} {
        namespace eval ::fileparams [list Save $topNode $smPath -1]
    }
    
    proc Open {topNode smPath} {
        namespace eval ::fileparams [list Open $topNode $smPath -1]
    }
    
    proc PrepareSaveString {winId} {
        # first list the inputs...
        variable useNodes
        variable clevers
        variable inGrpData
        variable inClevers1
        variable inClevers2
        
	foreach eTitle $useNodes($winId,sliders) {
            set node [GetIdFromCaptionPath $eTitle]
            set line [list input $eTitle est $::initialEstimate($node) \
                    min $::minForOpt($node) max $::maxForOpt($node)]
            if {[info exists ::timeInfo($node)]} {
                lappend line when $::timeInfo($node)
	    }
	    if {[info exists ::regularInt($node)]} {
                lappend line period $::regularInt($node)
            }
            foreach {val def} $inClevers1 {
                lappend line $val $inGrpData($node,$val)
            }
            foreach {val def} $inClevers2 {
                lappend line $val $inGrpData($node,$val)
            }
            
            lappend state $line
        }
        lappend state [list inSource $useNodes($winId,gathering)]
        # now the outputs
	foreach eTitle $useNodes($winId,drivers) {
            set node [GetIdFromCaptionPath $eTitle]
            lappend state [list output $eTitle weight 1 \
                    sampled $::readMany($eTitle)]
        }
        lappend state [list outDest $useNodes($winId,scrogging)]
        set line clevers
        # prediction
        if {$useNodes($winId,preds)} {
            lappend state [list predict way $useNodes($winId,way) \
                    item $useNodes($winId,pred) \
                    time $useNodes($winId,ptim)]
        }
        foreach group [concat $clevers(list) $clevers(pred)] {
            foreach {val def} $group {
                lappend line $val $clevers($val)
            }
        }
        lappend state $line
        
        # include data from last run...? doubtful
        SetState $winId $state
    }
    
} ;# end of namespace
