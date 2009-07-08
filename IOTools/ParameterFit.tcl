# Simple helper app designed for management
# Set position of window on screen JMM
package require math::optimize
set keyValue parameterFit20070520

namespace eval $keyValue {
    
    # namespace is used to minimize name clashes
    
    proc identify {} {
        return "Parameter fit"
    }
    
    proc initialize {winId} {
        global stopImg runState myNode
        variable useNodes
        variable runData
        variable clevers
        variable inClevers1
        variable inClevers2
        
        set useNodes($winId,modelY) {}; # empty the list of model result values
        
        label $winId.header -text "Parameter fit"
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
                [list add.gif "Add variables" \
                [namespace code "AddVariableOut $winId"]] \
                [list remove.gif "Remove a variable" \
                [namespace code "RemoveVariableOut $winId"]]]
        ::graphtools::MakeToolBar $outId $toolbarItems
        
        pack [message $inpId.intro -aspect 800] -fill x
        pack [message $outId.intro -aspect 800] -fill x
        pack [message $resId.intro -aspect 800] -fill x
        
        MakeFrames $inpId
        MakeFrames $outId
        
        pack [checkbutton $inpId.gather -text "Use current data as estimates" \
                -variable ::[namespace current]::useNodes($winId,gathering) \
                -command [namespace code [list AbleEstimateFields $winId]]]
        pack [checkbutton $outId.show -text "Show these on plots" \
                -variable ::[namespace current]::useNodes($winId,scrogging)]
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
        BindPopup $lf.upper.start "Run or pause process"
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
        pack [text $canId -height 4] -fill both -expand true
        $df.c setwidget $canId
        pack $df.c -side top -fill both -expand true
        
        pack [button $resId.b -text "Save a PEST file" -state disabled \
                -command [namespace code SaveResults]]
        
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
        foreach current [winfo children $useNodes($winId,input).sliderframe] {
            destroy $current
        }
        set useNodes($winId,sliders) {}
    }
    
    proc ClearOut {winId} {
        variable useNodes
        foreach current [winfo children $useNodes($winId,output).sliderframe] {
            destroy $current
        }
        set useNodes($winId,drivers) {}
    }
    
    proc Restore {winId} {
        global paramDims
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
                    AbleTimeData $node $f
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
                                set paramDims($title,readMany) $val
                            }
                        }
                    }
                    set f [InsertDriver $winId $node $title 1]
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
                if {[llength $success]} {
                    $useNodes($winId,input).intro configure -text {}
                    ReleaseClicks $winId
                }
            } adding_outputs {
                set success [InsertDriver $winId $node $fullCapt 1]
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
            set f [MakeSubFrames $inpId $inpId.sliderframe \
                    $levels [namespace current] 0]
            if {[winfo exists $f]} {
                $inpId.c.canvas see $f
                return $f
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
    
    proc InsertDriver {winId node title nest} {
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
        set f [MakeSubFrames $myNode $outId.sliderframe \
                [split $title /] [namespace current] 0]
        if {[winfo exists $f]} {
            $outId.c.canvas see $f
        } else {
            lappend targetData(needed) $title
            AddEntry $outId $myNode $node 1 -1
            lappend useNodes($winId,drivers) $title
            
            pack [checkbutton $f.end -variable paramDims($title,readMany) \
                    -command [namespace code \
                    [list AbleTimeSampling $node $title $f]]] \
                    -side left
            BindPopup $f.end "Set values at time points"
            # do command now in case it was selected last time
            AbleTimeSampling $node $title $f
            foreach widjo [concat [list $f] [winfo children $f]] {
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
    
    proc AbleTimeSampling {node title f} {
        global paramDims
        
        set trans [GetTransTable $node]
        if {$paramDims($title,readMany)} {
            set paramDims($title) [linsert $paramDims($title) 0 TIME]
            set trans [linsert $trans 0 {}]
        } elseif {[string equal TIME [lindex $paramDims($title) 0]]} {
            set paramDims($title) [lrange $paramDims($title) 1 end]
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
        set f [MakeSubFrames {} $inpId.sliderframe \
                $levels [namespace current] 0]
        Prune $inpId $f
        set index [lsearch $useNodes($winId,sliders) $title]
        set useNodes($winId,sliders) \
                [lreplace $useNodes($winId,sliders) $index $index]
    }
    
    proc RemoveOut {winId title} {
        variable useNodes
        set outId $useNodes($winId,output)
        set levels [split $title /]
        set f [MakeSubFrames {} $outId.sliderframe \
                $levels [namespace current] 0]
        Prune $outId $f
        set index [lsearch $useNodes($winId,drivers) $title]
        set useNodes($winId,drivers) \
                [lreplace $useNodes($winId,drivers) $index $index]
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
        
        set useNodes($winId,modelY) {}
        set observedVals {}
        
        if {$useNodes($winId,scrogging)} {
            ShowMess {Substituting measured values} warning \
                    "You have selected to display the measured values supplied to the PEST interface helper for the output components, rather than their actual values from the model." ok
        }
    }
    
    proc display {winId time display remainder} {
        variable useNodes
        
        # have to stop it appending on every reset or other time 
        #TraceOut $winId "time $time"; # remove todo
        set resultNode [GetIdFromCaptionPath $useNodes($winId,drivers)]
        lappend useNodes($winId,modelY) [GetModelValue $resultNode]
    }
    
    proc Stop {winId} {
        global myNode
        variable runData
        
        #        PokeStopFile $winId 2
        $runData($myNode,progressBar) set 0
    }
    
    proc Pause {winId} {
        variable useNodes
        set useNodes($winId,state) 3
        #        PokeStopFile $winId 3
        SetButtonAct $winId start
    }
    
    proc Go {winId} {
        variable useNodes
        
        #ShowMess debug info "Go" ok
        
        if {$useNodes($winId,state)==3} { ;# it was paused
            SetButtonAct $winId pause
            set useNodes($winId,state) 0
            #WaitTillDone $winId
            return
        }
        set useNodes($winId,rnum) 1
        set useNodes($winId,numRuns) 1
        Optimize $winId
    }
    
    proc Run {} {
        global myNode
        #what if not using mre??? todo
        $::RunEnv::runControlWindId($myNode).nb.rcf.upper.topbuttons.start invoke
    }
    
    
    proc sumSqrDev  {args} {
        global myNode
        variable useNodes
        variable w
        variable observedVals
        
        
        #ShowMess debug info "useNodes(\$w,sliders) = $useNodes($w,sliders)\
        #        args $args" ok
        
        # model values useNodes($w,modelY)
        # observed values ????
        set a {}
        foreach {param} $useNodes($w,sliders) {val} $args {
            set node [GetIdFromCaptionPath $param]
            
            #SetModelValue $node $val
            c_setparamelement $node {} $val
            do_for_node $myNode set ::runState($myNode,reloadParams) -1 ;# this makes sure the value is propagated in the model
            do_for_node $myNode runcontrol33857::SetMode $myNode reset
            #end SetModelValue $node $val
            
            #ShowMess debug info "$param = $val\
            #    GetModelEval  [GetModelEval $node]" ok
            lappend a [GetModelValue $node]
        }
        #ShowMess debug info "args = $args; a $a" ok
        
        Run
        #ShowMess debug info "useNodes(\$w,modelY) = $useNodes($w,modelY)\
        #        useNodes($w,drivers) $useNodes($w,drivers)" ok
        # what's the observed y?
        #proc display builds modelled and observed value lists
        # or observed is loaded in directly?
        set sumsqrdev 0.0
        TraceOut $w "[llength $observedVals], [llength $useNodes($w,modelY)]; "
        foreach {modelled} $useNodes($w,modelY) {observed} $observedVals {
            #set onode [GetIdFromCaptionPath $observed_path]
            if {$observed=={} || $modelled=={}} {
                break
            }
            #TraceOut $w "observed $observed,  modelled $modelled; "
            
            set sumsqrdev [expr {$sumsqrdev + \
                        pow(($observed - $modelled),2)}]
        }
        TraceOut $w "sumsqrdev $sumsqrdev"
        return $sumsqrdev
    }
    
    proc TraceOut {winId msg} {
        variable useNodes
        #ShowMess debug info "$winId \n$msg" ok
        $useNodes($winId,results).dbf.c.text configure -state normal
        $useNodes($winId,results).dbf.c.text insert end "${msg}\n"
        $useNodes($winId,results).dbf.c.text yview moveto 1
        $useNodes($winId,results).dbf.c.text configure -state disabled
    }
    
    proc Optimize_pf {winId} {
        global simtmpdir initialEstimate minForOpt maxForOpt paramDims
        global myNode
        variable useNodes
        variable w
        variable outGrpData
        set w $winId
        ShowMess debug info "Optimize" ok
        #ShowMess debug info "outGrpData [array get outGrpData]" ok
        #ShowMess debug info "array names outGrpData *,mems [array names outGrpData *,mems]" ok
        
        global targetData
        array unset spitLists
        set usedHangers 0
        array unset outGrpData *,mems
        
        # Descend hierarchically through the frames to get the data? No, use kill menu
        
        ShowMess debug info "Optimize2" ok
        
        ShowMess debug info "* observation data\
                array names outGrpData *,mems [array names outGrpData *,mems]" ok
        
        
        ##################################
        TraceOut $w {* observation groups}
        foreach obsGrp [array names outGrpData *,mems] {
            set node [string range $obsGrp 0 end-5]
            puts $control $node
        }
        
        ShowMess debug info "Optimize2" ok
        set outGrpData(predict,weight) 1 ;# this is ignored if used
        ShowMess debug info "* observation data\
                array names outGrpData *,mems [array names outGrpData *,mems]" ok
        # [array names outGrpData *,mems] EMPTY
        #TraceOut $w {* observation data}
        foreach obsGrp [array names outGrpData *,mems] {
            # doesn't get here
            ShowMess debug info "Optimize3" ok
            set node [string range $obsGrp 0 end-5]
            foreach combo $outGrpData($obsGrp) {
                ShowMess debug info "Optimize4" ok
                #TraceOut $w  [concat [split $combo =] \
                [list $outGrpData($node,weight) $node]]
                ShowMess debug info "[concat [split $combo =] \
                        [list $outGrpData($node,weight) $node]]" ok
            }
        }
        
        
        # guessed values
        set initialEstimates {}
        foreach {param} $useNodes($winId,sliders) {
            set node [GetIdFromCaptionPath $param]
            lappend initialEstimates $initialEstimate($node)
        }
        TraceOut $w "initialEstimates = $initialEstimates"; # remove todo
        TraceOut $w "useNodes(\$w,modelY) $useNodes($w,modelY)"; # remove todo
        
        
        TraceOut $w "array get targetData [array get targetData]"; # remove todo
        #TraceOut $w "$targetData($eTitle) $targetData($eTitle)"; # remove todo
        TraceOut $w "array names targetData * [array names targetData *]"; # remove todo
        ###############################################################################
        array set results  \
                [::math::optimize::nelderMead [namespace current]::sumSqrDev \
                $initialEstimates -trace on \
                -traceCommand [namespace code "TraceOut $winId"]]
        #ShowMess debug info "[namespace current]::func [array get results]" ok
        $useNodes($winId,results).dbf.c.text insert end "[array get results]\n"
        ###############################################################################
        
    }
    
    proc Optimize {winId} {
        
        global simtmpdir initialEstimate minForOpt maxForOpt paramDims
        global tcl_platform sender paramData myNode execExtn
        variable useNodes
        variable clevers
        variable usedHangers
        variable inGrpData
        variable outGrpData
        variable inClevers1
        variable ptList
        variable spitLists
        variable runData
        
        variable observedVals
        variable w
        
        set w $winId
        
        
        # First, look at the outputs required at times before the end
        # of the run and create an array holding lists of nodes whose
        # values will be written at each time...
        
        global targetData
        array unset spitLists
        set usedHangers 0
        array unset outGrpData *,mems
        
        set observedVals {}
        
        # Descend hierarchically through the frames to get the data? No, use kill menu
        
        foreach eTitle $useNodes($winId,drivers) {
            AcceptData $myNode $eTitle -1 1
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
                set useEndTime 1
            }
        }
        if {[llength $targetData(needed)]} {
            return
        }
        
        # needed ptList
        set ptList [lsort -real [array names spitLists]]
        TraceOut $winId "ptList $ptList"; # remove todo
        
        set lastPt [lindex $ptList end]
        if {[info exists useEndTime]} {
            if {$runLength<$lastPt} {
                ShowMess "Run length too short" warning \
                        "You have specified a run length of $runLength time units. This is not long enough to record all the model outputs, which are required at times up until $lastPt units." ok
                return
            }
        }
        TraceOut $winId "::runState(\$myNode,execTime) $lastPt"; # remove todo
        set ::runState($myNode,execTime) $lastPt
        set ::runState($myNode,progressToDate) \
                [expr ($useNodes($winId,rnum)-1)*$clevers(noptmax)]
        
        
        # right, now to make the instruction file for reading the outputs
        # AddChoppers needed for observed
        set usedHangers 0
        set instruct [NetOpen [file join $simtmpdir model.ins] w]
        #puts $instruct "pif \\"
        foreach brkPt $ptList {
            foreach entry $spitLists($brkPt) {
                set pair [split $entry =]
                set node [lindex $pair 0]
                puts -nonewline $instruct "\\$node at $brkPt is\\ "
                if {[string equal what [lindex $pair 1]]} { ;# prediction
                    AddChoppers predict $instruct 1.0
                    set runData($myNode,predictTag) o$usedHangers
                } else {
                    AddChoppers $node $instruct [lindex $pair 1]
                }
                #puts $instruct {}
            }
        }
        close $instruct
        
        set outGrpData(predict,weight) 1 ;# this is ignored if used
        #puts $control {* observation data}
        #TraceOut $winId  [array names outGrpData *,mems]
        foreach obsGrp [array names outGrpData *,mems] {
            set node [string range $obsGrp 0 end-5]
            foreach combo $outGrpData($obsGrp) {
                TraceOut $winId   "[concat [split $combo =] \
                        [list $outGrpData($node,weight) $node]]"
                set coList [concat [split $combo =]]
                lappend observedVals "[lindex $coList 1]"; #$coList [lindex $coList 0]
            }
        }
        ###########################
        # guessed values
        set initialEstimates {}
        foreach {param} $useNodes($winId,sliders) {
            set node [GetIdFromCaptionPath $param]
            lappend initialEstimates $initialEstimate($node)
        }
        TraceOut $winId "initialEstimates = $initialEstimates"; # remove todo
        TraceOut $winId "useNodes(\$winId,modelY) $useNodes($winId,modelY)"; # remove todo
        
        
        TraceOut $winId "array get targetData [array get targetData]"; # remove todo
        #TraceOut $winId "$targetData($eTitle) $targetData($eTitle)"; # remove todo
        TraceOut $winId "array names targetData * [array names targetData *]"; # remove todo
        
        TraceOut $winId "observedVals $observedVals"; # remove todo
        
        ###############################################################################
        # -scale xScaleVector? ?-ftol epsilon? ?-maxiter count? ??-trace? flag?
        set maxiter 1000
        #If xScaleVector is not supplied, the co-ordinates will be varied by a
        #factor of 1.0001 (if the co-ordinate is non-zero) or by a constant
        #0.0001 (if the co-ordinate is zero).
        
        #epsilon is the desired relative error in the value of the function evaluated
        # at the minimum. The default is 1.0e-7, which usually gives three
        # significant digits of accuracy in the values of the x's.
        set epsilon 1.0e-7
                
                array set results  \
                        [::math::optimize::nelderMead [namespace current]::sumSqrDev \
                        $initialEstimates -maxiter $maxiter -trace on -ftol $epsilon \
                -traceCommand [namespace code "TraceOut $winId"]]
        #ShowMess debug info "[namespace current]::func [array get results]" ok
        #$useNodes($winId,results).dbf.c.text insert end "[array get results]\n"
        TraceOut $winId "results [array get results]"; # remove todo
        ###############################################################################
        
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
    
    # Next bit will actually be executed by command supplied to PEST
    
    proc pestificate {cmd} {
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
                        [file nativename [file join $simtmpdir model.inp]]
                
                set widget $runState($topNode,helperId).nb.rcf
                $widget.upper.topbuttons.reset invoke
                
                set execLog [NetOpen [file nativename [file join $simtmpdir model.out]] w]
                set current 0
                foreach breakPt $ptList {
                    set runState($topNode,pause) $breakPt
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
                StartRelay $cmd
            }]} {
            ShowMess "Problem executing from PEST" warning $errorInfo ok
        }
        incr runData($topNode,rollCount)
        #	set runData($topNode,recSize) [file size \
        #					   [file join $simtmpdir model.rec]]
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
    
    proc ScrogOutputs {subTime} {
        variable useNodes
        variable ptList
        variable spitLists
        
        foreach activeSub [array names useNodes *,scrogging] {
            if {$useNodes($activeSub)} {
                set winId [string range $activeSub 0 end-10]
                
                foreach eTitle $useNodes($winId,drivers) {
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
                        #; 0.0 fixes bloody Tcl arithmetic that thinks 1/2 = 0
                        set progFrack [expr (0.0+$subTime-[lindex $lo 0])/ \
                                ([lindex $hi 0]-[lindex $lo 0])]
                        set mid [Interpo $progFrack [lindex $lo 1] [lindex $hi 1]]
                        unset lo
                    } else {
                        set mid [lindex $hi 1]
                    }
                    SetModelValue $node $mid
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
    
    proc RestoreOutputs {} {
        variable useNodes
        
        foreach storedVal [array names useNodes *,modelVal] {
            set node [string range $storedVal 0 end-9]
            SetModelValue $node $useNodes($storedVal)
            unset useNodes($storedVal)
            # avoid 'array unset' where possible, it hides bugs!
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
    
    proc AddHangers {node str est dms brs} {
        variable usedHangers
        variable inGrpData
        
        if {[lindex $dms 0]>0} {
            if {[llength $est]>1} {
                array set arrEst $est
            }
            if {$brs==1} {
                puts -nonewline $str \{
            }
            for {set n 1} {$n <= [lindex $dms 0]} {incr n} {
                puts -nonewline $str "$n "
                if {[info exists arrEst]} {
                    set est $arrEst($n)
                }
                AddHangers $node $str $est [lrange $dms 1 end] 1
                puts -nonewline $str " "
            }
            if {$brs==1} {
                puts -nonewline $str \}
            }
        } else {
            puts -nonewline $str [format \\%10s\\ i[incr usedHangers]]
            lappend inGrpData($node,mems) i$usedHangers $est
        }
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
                lappend line when $::timeInfo($node) \
                        period $::regularInt($node)
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
                    sampled $::paramDims($eTitle,readMany)]
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
