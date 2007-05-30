# Helper Optimize a model variable

package require math::optimize

set keyValue nelderMead20070518

namespace eval $keyValue {
    
    # namespace is used to minimize name clashes
    
    proc identify {} {
        return "Optimize"
    }
    
    proc initialize {winId} {
        global stopImg runState myNode
        variable useNodes
        variable runData
        variable clevers; #PEST options? JMM
        variable inClevers1
        variable inClevers2
        
        variable modelnode
        
        label $winId.header -text "Model optimization tool"
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
        
        pack [frame $winId.footer ] -side bottom -fill x
        button $winId.footer.prevbtn -text "previous"
        button $winId.footer.nextbtn -text "next"
        pack $winId.footer.prevbtn $winId.footer.nextbtn -side left
        
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
        # data from run in progress
        pack [set df [labelframe $resId.dbf -text {Execution monitor:}]] \
                -fill both -expand true -padx 4 -pady 4
        pack [frame $df.numeric]
        # Commentary window
        ScrolledWindow $df.c
        set canId $df.c.text
        pack [text $canId -height 4 -wrap none] -fill both -expand true
        $df.c setwidget $canId
        pack $df.c -side top -fill both -expand true
        
################################################################################
#         pack [button $resId.b -text "Save a PEST file" -state disabled \
#                 -command [namespace code SaveResults]]
################################################################################
        
        
        set useNodes($winId,state) 1 ;# stopped, no data
    }
    
    proc reset {winId} {
    }
    
    proc display {args} {
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
                        ShowMessage "Problem restoring PEST settings" warning \
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
                        ShowMessage "Problem restoring PEST settings" warning \
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
                    ShowMessage {Problem with PEST saved state} info \
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
        variable inGrpData
        
        set inpId $useNodes($winId,input)
        
        set mode [GetModelEval $node]
        if {[lsearch {TABLE INPUT} $mode]==-1} {
            $inpId.intro configure -text "This component cannot be set by the optimization tool because it is not a fixed or variable parameter."
            return {}
        }
        set datatype [GetModelType $node]
        if {![string equal REAL $datatype]} {
            $inpId.intro configure -text "This component cannot be esimated by the optimization tool because its datatype is $datatype. Only parameters of type REAL can be estimated."
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
        set ::initialEstimate($node) [GetModelValue $node]
        # [expr ($::minForOpt($node)+$::maxForOpt($node))/2]
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
    
    proc AbleEstimateFields {winId} {
        # later: use MakeSubFrames to find
        # and able all estimate entry boxes (not needed if using parameter
        # data)
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
    
    proc display {winId time display remainder} {
        
        # Check if the model is being run by PEST, and if it is, write data
        # for any model outputs for which we have reached recording time
        # points...nah, we are only running it between recording points.
        
    }
    
    proc Stop {winId} {
        global myNode
        variable runData
        
        PokeStopFile $winId 2
        $runData($myNode,progressBar) set 0
    }
    
    proc Pause {winId} {
        variable useNodes
        set useNodes($winId,state) 3
        PokeStopFile $winId 3
        SetButtonAct $winId start
    }
    
    proc Go {winId} {
        variable useNodes
        
        #ShowMessage debug info "Go" ok
        
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
    
    proc ResetModelOpt {} {
        # WRONG RESET, FIXED PARAMS NOT CHANGED
        global myNode
        #what if not using mre??? todo
        $::RunEnv::runControlWindId($myNode).nb.rcf.upper.topbuttons.reset invoke
    }
    
    proc func {args} {
        global myNode
        variable useNodes
        variable w
        #$useNodes($winId,sliders) params # var paths
        #$useNodes($winId,drivers) variable to optimize
        #set the parameter values
        set a {}
        foreach {param} $useNodes($w,sliders) {val} $args {
            set node [GetIdFromCaptionPath $param]
            
            #SetModelValue $node $val
            c_setparamelement $node {} $val
            do_for_node $myNode set ::runState($myNode,reloadParams) -1 ;# this makes sure the value is propagated in the model
            do_for_node $myNode runcontrol33857::SetMode $myNode reset
            #end SetModelValue $node $val
            
            #ShowMessage debug info "$param = $val\
            #    GetModelEval  [GetModelEval $node]" ok
            lappend a [GetModelValue $node]
        }
        #ShowMessage debug info "args = $args; a $a" ok
        
        set resultNode [GetIdFromCaptionPath $useNodes($w,drivers)]
        
        # big values outside range!! todo
        
        #reset and then run the model (start the run, it will then run to SetExecuteFor time)
        #ShowMessage debug info "Before reset result = [GetModelValue $resultNode]" ok
        ##ResetModel $myNode -1; # WRONG RESET, FIXED PARAMS NOT CHANGED http://twiki.simulistics.com/twiki/bin/view/Simile/ParametersNotUpdated
        # -1 for a fixed parameter or 0 for a time series
        # no -1 no good -2?
        #do_for_node $myNode runcontrol33857::SetMode $myNode reset
        #runcontrol33857::SetMode $myNode reset; # no good
        #ShowMessage debug info "After reset result = [GetModelValue $resultNode]" ok
        
        Run
        #ShowMessage debug info "After run result = [GetModelValue $resultNode]" ok
        
        #[GetCaptionPathFromId $node]
        # get the output value
        #ShowMessage debug info "node = $node" ok
        set y [GetModelValue $resultNode]
        #return [expr $y]; # +1.0
        #ShowMessage debug info "func: $useNodes($w,drivers) = $y" ok
        return $y; #[expr {$y}]
    }
    
    proc TraceOut {winId msg} {
        variable useNodes
        #ShowMessage debug info "$winId \n$msg" ok
        $useNodes($winId,results).dbf.c.text configure -state normal
        $useNodes($winId,results).dbf.c.text insert end "${msg}\n"
        $useNodes($winId,results).dbf.c.text yview moveto 1
        $useNodes($winId,results).dbf.c.text configure -state disabled
    }
    
    proc Optimize {winId} {
        global simtmpdir initialEstimate minForOpt maxForOpt paramDims
        global myNode
        variable useNodes
        variable w
        set w $winId
                        
        $useNodes($winId,results).dbf.c.text delete 1.0 end
        $useNodes($winId,results).dbf.c.text configure -state disabled
        
        #ShowMessage debug info "Var to optimise $useNodes($winId,drivers)" ok
        #ShowMessage debug info "Param? $useNodes($winId,sliders)" ok;
        #
        # # pred predictive ?
        #
        # redirect output
        
        #$minForOpt($node) $maxForOpt($node)
        #ShowMessage debug info "useNodes($w,sliders) = $useNodes($w,sliders)" ok
        
        # guessed values
        set initialEstimates {}
        foreach {param} $useNodes($w,sliders) {
            set node [GetIdFromCaptionPath $param]
            lappend initialEstimates $initialEstimate($node)
        }
        #ShowMessage debug info "initialEstimates = $initialEstimates" ok
        
################################################################################
#         xScaleVector is an initial guess at the problem scale; the first function
#         evaluations will be made by varying the co-ordinates in xVector by the
#         amounts in xScaleVector. If xScaleVector is not supplied, the co-ordinates
#         will be varied by a factor of 1.0001 (if the co-ordinate is non-zero) or
#         by a constant 0.0001 (if the co-ordinate is zero).
#         
#         epsilon is the desired relative error in the value of the function evaluated
#         at the minimum. The default is 1.0e-7, which usually gives three significant
#         digits of accuracy in the values of the x's.
#         
#         pp count is a limit on the number of trips through the main loop of the
#         optimizer. The number of function evaluations may be several times this
#         number. If the optimizer fails to find a minimum to within ftol in maxiter
#         iterations, it returns its current best guess and an error status. Default
#         is to allow 500 iterations.
#         
#         flag is a flag that, if true, causes a line to be written to the standard
#         output for each evaluation of the objective function, giving the arguments
#         presented to the function and the value returned. Default is false.
#         
#         The nelderMead procedure returns a list of alternating keywords and values
#         suitable for use with array set. The meaning of the keywords is:
#         
#         x is the approximate location of the minimum.
#         
#         y is the value of the function at x.
#         
#         yvec is a vector of the best N+1 function values achieved, where N is the
#         dimension of x
#         
#         vertices is a list of vectors giving the function arguments corresponding
#         to the values in yvec.
#         
#         nIter is the number of iterations required to achieve convergence or
#         fail.
#         
#         status is 'ok' if the operation succeeded, or 'too-many-iterations' if the
#         maximum iteration count was exceeded.
#         
#         nelderMead minimizes the given function using the downhill simplex method
#         of Nelder and Mead. This method is quite slow - much faster methods for
#         minimization are known - but has the advantage of being extremely robust
#         in the face of problems where the minimum lies in a valley of complex
#         topology.
################################################################################
        
        # nelderMead options
        # ?-scale xScaleVector? ?-ftol epsilon? ?-maxiter count? ??-trace? flag?
        
        array set results  \
                [::math::optimize::nelderMead [namespace current]::func \
                $initialEstimates -trace on \
                -traceCommand [namespace code "TraceOut $winId"]]
        #ShowMessage debug info "[namespace current]::func [array get results]" ok
        $useNodes($winId,results).dbf.c.text configure -state normal
        $useNodes($winId,results).dbf.c.text insert end "[array get results]\n"
        $useNodes($winId,results).dbf.c.text configure -state disabled
    }
    
    proc PESTOptimize {winId} {
        
        # Time to invoke PEST. First we must make a template file that allows
        # PEST to create a .spf file that will parameterize the model. Usually
        # a .spf file is MIME-encoded and contains references to other files,
        # but neither of these need be done here.
        
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
        
        set runLength [$useNodes($winId,results).lbf.rl.ent get]
        $useNodes($winId,results).dbf.c.text delete 1.0 end
        $useNodes($winId,results).b configure -state disabled
        
        # First, look at the outputs required at times before the end
        # of the run and create an array holding lists of nodes whose
        # values will be written at each time...
        
        global targetData
        array unset spitLists
        set usedHangers 0
        array unset outGrpData *,mems
        
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
        set numOutputs [llength $useNodes($winId,drivers)]
        if {$useNodes($winId,preds)} {
            set mode prediction
            incr numOutputs
            lappend spitLists($useNodes($winId,ptim)) \
                    $useNodes($winId,npred)=what
        } else {
            set mode estimation
        }
        
        set ptList [lsort -real [array names spitLists]]
        
        set lastPt [lindex $ptList end]
        if {[info exists useEndTime]} {
            if {$runLength<$lastPt} {
                ShowMessage "Run length too short" warning \
                        "You have specified a run length of $runLength time units. This is not long enough to record all the model outputs, which are required at times up until $lastPt units." ok
                return
            }
        }
        set ::runState($myNode,execTime) $lastPt
        set ::runState($myNode,progressToDate) \
                [expr ($useNodes($winId,rnum)-1)*$clevers(noptmax)]
        
        # Have a look at the inputs
        
        set template [NetOpen [file join $simtmpdir model.tpl] w]
        puts $template "ptf \\"
        
        array unset inGrpData *,mems
        $useNodes($winId,results).dbf.c.text insert end \
                "PEST indentifiers for Simile model input values:\n"
        foreach eTitle $useNodes($winId,sliders) {
            set node [GetIdFromCaptionPath $eTitle]
            set levels [split $eTitle /]
            set inpId $useNodes($winId,input)
            set f [MakeSubFrames {} $inpId.sliderframe \
                    $levels [namespace current] 0]
            
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
            puts -nonewline $template $eTitle=
            if {[winfo exists $f.int]} {
                if {$useNodes($winId,gathering)} {
                    foreach {timePt vList} $defCons {
                        puts -nonewline $template "$timePt "
                        AddHangers $node $template $vList $nodeDims 1
                        puts -nonewline $template " "
                    }
                } elseif {[string equal normal [$f.int cget -state]]} {
                    set int [$f.int get]
                    
                    # Only try to calculate inputs up to and including the time
                    # at which the last output is read
                    
                    for {set setTime 0} {$setTime <= $lastPt} \
                            {set setTime [expr {$setTime+$int}]} {
                                puts -nonewline $template "$setTime "
                                AddHangers $node $template $defCons $nodeDims 1
                                puts -nonewline $template " "
                            }
                } else {
                    puts -nonewline $template "NOW "
                    AddHangers $node $template $defCons $nodeDims 1
                }
            } else {
                AddHangers $node $template $defCons $nodeDims 0
            }
            puts $template {}
            if {$usedHangers==$startHanger} {
                set hangerRange "is i$usedHangers"
            } else {
                set hangerRange "from $startHanger to $usedHangers"
            }
            $useNodes($winId,results).dbf.c.text insert end \
                    "$eTitle $hangerRange\n"
        }
        close $template
        
        set control [NetOpen [file join $simtmpdir model.pst] w]
        puts $control pcf
        puts $control {* control data}
        puts $control [list restart $mode]
        puts -nonewline $control $usedHangers
        
        # right, now to make the instruction file for reading the outputs
        
        set usedHangers 0
        set instruct [NetOpen [file join $simtmpdir model.ins] w]
        puts $instruct "pif \\"
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
                puts $instruct {}
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
        if {[string match windows $tcl_platform(platform)]} {
            set oldDir [file attributes $oldDir -shortname]
        }
        puts $control {* model command line}
        set ourWish [ShellFileRef [file join [file dirname $oldDir] System bin relay$execExtn]]
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
        StartRelay $ourWish
        
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
    
    proc StartRelay {cmd} {
        global simtmpdir
        variable relayProc
        
        set oldDir [pwd]
        cd $simtmpdir
        
        set relayProc [open |$cmd r]
        # was [SilentRun $cmd]
        #ShowMessage debug info "started $hanger" ok
        fconfigure $relayProc -blocking 0
        fileevent $relayProc readable [namespace code [list pestificate $cmd]]
        cd $oldDir
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
