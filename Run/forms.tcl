# Simile source code file: Run/forms.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for all dialogues except the equation,
# preferences and customise dialogues.
#
proc Disaggregate {parent title colour image imgpos type interp \
		       fatness icount step desc comment enumLists \
		       xproc xinc xlibs eqnunit hide separate} {
    global disaggregate tcl_platform window_info

    set mdl $window_info($parent,top_node)
    foreach varName {colour image imgpos type interp fatness \
                icount xproc xinc xlibs eqnunit hide separate} {
        set disaggregate($varName) [set $varName]
    }
    set new 1

    if {!$new} {
	if [llength $icount]>0 {
	    set disaggregate(icount) [join $icount ,]
	} else  {
	    set disaggregate(icount) 1
	}
    }
    #puts $disaggregate(icount)
    foreach stepId [list {Initialize only} {New params only} {Reset only} \
			1st 2nd 3rd 4th 5th 6th 7th] {
	lappend stepNames [tr. $stepId]
# TRANSLATOR: see list above for values of $stepId -- include cardinals
    }
    if {[string is integer -strict $step]} {
	set disaggregate(step) [lindex $stepNames [expr $step+2]]
    } else {
	set disaggregate(step) $step
    }

    set tt .disaggregation
    set tf [::ttk::frame [PutItThere $tt $parent].all]
    set t [::ttk::notebook $tf.notebook]
    wm resizable $tt 0 1
    wm protocol $tt WM_DELETE_WINDOW {set disaggregate(done) 0}
    wm title $tt [format $::msgs(props_title) [BlankCrs $title]]
    set okCmd {set disaggregate(done) 1}
    
    $t add [ttk::frame $t.simple] -text [tr. Basic]
    TitleFrame $t.simple.notes -text [tr. Notes:]
    set notesf [GetFrame $t.simple.notes]
    set descf [ttk::frame $notesf.desc]
    ttk::label $descf.desclabel -text [tr. Description:]
    entry $descf.text -width 20 -relief sunken -bd 2 -highlightthickness 0
    bind $descf.text <Return> $okCmd
    pack $descf.desclabel -side left -padx 2 -pady 2
    pack $descf.text -side left  -fill x -expand true -padx 2 -pady 2
    $descf.text insert 0 $desc
    pack $descf -side top  -fill x -expand off
    ttk::label $notesf.commentlabel -text [tr. Comments:]
    pack $notesf.commentlabel -padx 2 -pady 4 -anchor w
    # ScrolledWindow causes crash under Linux so replaced with ordinary frame
    #    frame $t.commentsSW
    set cmtf [frame $notesf.commentsSW]
    pack [scrollbar $cmtf.y -orient v -command [list $cmtf.comment yview]] \
	-side right -fill y
    pack [text $cmtf.comment -height 4 -width 40 -relief sunken -wrap word \
	      -highlightthickness 0 -bd 2 -yscrollcommand [list $cmtf.y set]] \
	-fill both -expand 1
    AllowTextDrags $cmtf.comment
    bind $cmtf.comment <Return> {expr 1}
    $cmtf.comment insert 1.0 $comment
    pack $cmtf -padx 2 -pady 2 -fill both -expand true
    pack $t.simple.notes -side bottom -padx 4 -pady 4 -fill both -expand true

    frame $t.simple.left
    if {$new} {
	TitleFrame $t.simple.left.count \
	    -text [tr. "Instances:"]
	set disaggregate(countf) [GetFrame $t.simple.left.count]
	foreach interpType {Single {Fixed array} {For data records} \
				Population {Rectangular grid} \
			    {Hexagonal grid}} {
	    lappend disaggregate(labels) [tr. $interpType]
	}
	pack [ttk::combobox $disaggregate(countf).mb -state readonly \
	      -textvariable disaggregate(cbxv) -values $disaggregate(labels)] \
	    -anchor w -side left -padx 4 -pady 4
	
	set exFrame [frame $disaggregate(countf).detail]
	pack $exFrame -side left -anchor s -pady 4 -fill both -expand 1
	pack [ttk::label $exFrame.l -wraplength 400]
	ShowDisagSetup ;# Set current type
	bind $disaggregate(countf).mb <<ComboboxSelected>> \
	    [list SetupDisagExtras $exFrame]
	SetupDisagExtras $exFrame
    } else {
    TitleFrame $t.simple.left.count \
	-text [tr. "Control of number of instances:"]
    set countf [GetFrame $t.simple.left.count]

    ttk::frame $countf.radio
    foreach rbutton {{population "Using population symbols"} {records "Using number of data records in file"} {generated "Using specified dimensions:"}} {
        ttk::radiobutton $countf.radio.$rbutton \
	    -text [tr. [lindex $rbutton 1]] -value [lindex $rbutton 0] \
	    -variable disaggregate(type) -command "SetHighlights $countf"
# TRANSLATOR: These are the second strings in each pair of braces after rbutton
        pack $countf.radio.$rbutton -anchor w
    }
    pack $countf.radio -anchor w -side left
    ::ttk::entry $countf.value -textvariable disaggregate(icount) -width 10
    pack $countf.value -side left -anchor s -pady 4 -fill x -expand 1
    bind $countf.value <Return> $okCmd
    }

    pack $t.simple.left.count -padx 4 -pady 4 -fill both -expand true
    
    TitleFrame $t.simple.left.colour -text [tr. "Background shade:"]
    set colourf [GetFrame $t.simple.left.colour]
    set posRBs [frame $colourf.imageposns]
    pack [ttk::button $colourf.clear -text [tr. Clear] -width 7 \
            -command "ClearBG $posRBs"] -padx 2 -pady 4 -side left
    pack [ttk::button $colourf.fixcolour -text [tr. Colour...] \
            -width 7 -command "UpdateColour $t $colourf"]  \
            -padx 2 -pady 4 -side left
#    $colourf.fixcolour configure -bg $disaggregate(colour)
    set disaggregate(defColour) $disaggregate(colour)
    pack [ttk::button $colourf.setimage -text [tr. Image...] -width 7 -command "ChooseImage $posRBs $mdl $window_info($parent,is_top_level)"] \
            -padx 2 -pady 4 -side left
    pack $posRBs -padx 2 -pady 4 -side left
    set rbState [ChooseText [string equal $disaggregate(image) none] \
            disabled normal]
    foreach rbutton {Tiled Centred Scaled} {
        pack [ttk::radiobutton $posRBs.ip$rbutton -state $rbState \
		  -value $rbutton -text [tr. $rbutton] \
		  -variable disaggregate(imgpos)] -anchor w -fill x
# TRANSLATOR: See list after rbutton
    }
    pack $t.simple.left.colour -padx 4 -pady 4 -fill both -expand true
    pack $t.simple.left -side left -fill both -expand 1
    
    $t add [frame $t.complex] -text [tr. Advanced]
    TitleFrame $t.complex.enumtypes -text [tr. "Enumerated types"]
    set enumtypef [GetFrame $t.complex.enumtypes]
    pack [set canId [frame $enumtypef.listpair]] -side left -fill both \
            -expand true
    #    pack [frame $windowId.buttonframe] -side bottom
    # types (list box to keep selection highlighted when lost focus, -exportselection 0)
    set typef [frame $canId.typef]
    label $typef.lbl -text [tr. Types] -anchor w
    listbox $typef.scrf -yscrollcommand [list AdjustCanvas $typef scrf y] \
            -exportselection 0
                
    foreach enumList $enumLists {
        set newType [lindex $enumList 0]
        set disaggregate(enumtype,$newType) [lrange $enumList 1 end]
        $typef.scrf insert end $newType
    }                
    # members (list box to keep selection highlighted when lost focus)
    set memf [frame $canId.memf]
    label $memf.lbl -text [tr. Members] -anchor w
    listbox $memf.mem -exportselection 0 \
            -yscrollcommand [list AdjustCanvas $memf mem y]
    scrollbar $memf.yscroll -orient v -command [list $memf.mem yview]
    
    # select first type in the list
    $typef.scrf selection set 0
    set togo [$typef.scrf get 0]
    if {$togo ne {} } {
        $memf.mem configure -listvariable disaggregate(enumtype,$togo)
    }
    
    bind $typef.scrf <ButtonRelease-1> "EnableTypeOps $enumtypef"
    set PopCmd [list QueuePopup AddEnumTypePopup %W %y %X %Y]
    bind $typef.scrf <Enter> $PopCmd
    bind $typef.scrf <Motion> "RemovePopup;$PopCmd"
    bind $typef.scrf <Leave> RemovePopup
    scrollbar $typef.yscroll -orient v -command [list $typef.scrf yview]
    menu $enumtypef.curmembers -tearoff 0 \
            -postcommand [list AddEnumTypeMems $enumtypef]
    
    pack $typef -side left -fill both -expand true   
    pack $typef.yscroll -side right -fill y
    pack $typef.lbl 
    pack $typef.scrf -side left -fill both -expand true
    # members
    pack $memf -side right -fill both -expand true
    pack $memf.lbl -side top
    pack $memf.mem -fill both -expand true
    #pack $canId.memyscroll -side right -fill y
    #pack $canId.mem -side left -fill both -expand true
    
    pack [set btnId [ttk::frame $enumtypef.btns]] -side left
    pack [::ttk::entry $btnId.e -textvariable enumTypeMPEntry] -padx 2
    bind $btnId.e <ButtonRelease-1> "EnableTypeOps $enumtypef"
    pack [ttk::button $btnId.addtype -text [tr. "Add type"] \
	      -command "AddEnumType $canId"] -padx 2 -pady 4 -fill x
    pack [ttk::button $btnId.remtype -text [tr. "Remove type"] \
	      -state disabled -command "RemoveEnumType $enumtypef"] \
	-padx 2 -pady 4 -fill x
    pack [ttk::button $btnId.addmems -text [tr. "Add member"] -state disabled \
	      -command "AddEnumMem $enumtypef"] \
	-padx 2 -pady 4 -fill x
    pack [ttk::button $btnId.remmem -text [tr. "Remove member"] \
	      -state disabled -command "RemoveEnumMem $enumtypef"] \
	-padx 2 -pady 4 -fill x
    pack [ttk::button $btnId.getmem -text [tr. "Get from file"] \
	  -state disabled -command "GetEnumMems $enumtypef $mdl"] \
	-padx 2 -pady 4 -fill x
    pack $t.complex.enumtypes -anchor nw -side bottom -padx 4 -pady 4 \
	-fill both -expand true
    
    TitleFrame $t.complex.appearance -text [tr. Appearance]
    set appearancef [GetFrame $t.complex.appearance]
    ttk::checkbutton $appearancef.hide -text [tr. "Hide contents"] \
            -variable disaggregate(hide)
    pack $appearancef.hide -anchor w
    ttk::frame $appearancef.scale
    scale $appearancef.scale.value -from .01 -to 1 -length 150 -orient horizontal \
            -resolution 0.01 -variable disaggregate(fatness)
    pack $appearancef.scale.value
    ttk::label $appearancef.scale.caption -text [tr. "Relative scale"]
    pack $appearancef.scale.caption
    pack $appearancef.scale -anchor w
    pack $t.complex.appearance -anchor nw -side left -padx 4 -pady 4 -fill both -expand true
    
    TitleFrame $t.complex.math -text [tr. Calculation]
    set mathf [GetFrame $t.complex.math]
#    checkbutton $mathf.separate -text "Build submodel in separate dll" \
#            -variable disaggregate(separate)
#    pack $mathf.separate -anchor w
    pack [ttk::frame $mathf.extcode] -anchor w -pady 6
    set disaggregate(useOwnCode) [expr {![string eq none $disaggregate(xinc)]}]
    pack [ttk::checkbutton $mathf.extcode.whether -text [tr. "Use own code"] \
	      -variable disaggregate(useOwnCode) -command "AbleSetup $mathf"] \
	-side left -anchor w
    pack [ttk::button $mathf.extcode.how -text Setup -command "ExtCodeSetup $mdl"]
    AbleSetup $mathf
    #    checkbutton $mathf.matherror -text "Ignore math errors during calculation" \
    #            -variable disaggregate(matherror)
    #    pack $mathf.matherror -anchor w
    ttk::frame $mathf.eqnunit
    ttk::label $mathf.eqnunit.caption -text [tr. "Use units in math:"]
    pack $mathf.eqnunit.caption -side left
    #tk_optionMenu $mathf.step.pulldown disaggregate(step) Default -1 0 1 2 3 4 5 6 7
    ::ttk::combobox $mathf.eqnunit.pulldown -textvariable disaggregate(eqnunit) \
	-values [list [tr. Default] [tr. Yes] [tr. No]] \
            -width 10 -state readonly
#    ::ttk::menubutton $mathf.eqnunit.pulldown -width 10 -textvariable disaggregate(eqnunit)
#    set m [menu $mathf.eqnunit.pulldown.menu]
#    foreach item [list Default Yes No] {
#      $m add command -label $item -command "set disaggregate(eqnunit) $item"
#    }
#    $mathf.eqnunit.pulldown configure -menu $m
    pack $mathf.eqnunit.pulldown
    pack $mathf.eqnunit -anchor w -padx 4 -pady 6
    ttk::frame $mathf.step
    ttk::label $mathf.step.caption -text [tr. "Time step index:"]
    pack $mathf.step.caption -side left
    #tk_optionMenu $mathf.step.pulldown disaggregate(step) Default -1 0 1 2 3 4 5 6 7
    #ComboBox $mathf.step.pulldown -textvariable disaggregate(step) \
    #        -values [list Default "Initialize only" "Reset only" 1 2 3 4 5 6 7] \
    #        -width 10 -state readonly
    ::ttk::combobox $mathf.step.pulldown -textvariable disaggregate(step) \
	-width 10 -values [concat Default $stepNames] -state readonly
    set m [menu $mathf.step.pulldown.menu] 
    foreach item [concat Default $stepNames] {
      $m add command -label $item -command "set disaggregate(step) \"$item\""
    }
    pack $mathf.step.pulldown
    pack $mathf.step -anchor w -padx 4 -pady 6
    pack $t.complex.math -side left -padx 4 -pady 4 -fill both -expand true
    
    # The above "complex" frame has been constructed, but is not packed until the "More" button is pressed
    # unless, conditional expressions indicate that one of the complex attributes does not have its default
    # value
    #    pack $t.complex -anchor w
#    if {![string match $disaggregate(step) Default] || \
#	    ![string match $disaggregate(eqnunit) Default] || \
#	    $disaggregate(separate) || \
#	    $disaggregate(fatness)!=1.0 || \
#	    $disaggregate(hide) || \
#	    $disaggregate(useOwnCode)} {
#        ShowComplexity $t
#    } elseif [info exists enumList] {
#        ShowComplexity $t
#    }
#   

# Context frame for metadata
# do not display fttb    
    frame $t.metadata
#    $t add [frame $t.metadata] -text Context
    TitleFrame $t.metadata.summary -text "Model summary"
    set summaryf [GetFrame $t.metadata.summary]

    grid [label $summaryf.namelabel -text "Model name:"] -row 0 -column 0 -sticky w
    grid [entry $summaryf.nameentry] -row 0 -column 1 -sticky ew
    grid [label $summaryf.purposelabel -text "Aim/Purpose of the Model"] \
	-row 1 -column 0 -sticky w
    grid [text $summaryf.purposetext -width 60 -height 4] -row 1 -column 1
    grid [label $summaryf.desclabel -text "Description of the Model"] \
	-row 2 -column 0 -sticky w
    grid [text $summaryf.desctext -width 60 -height 4] -row 2 -column 1
    grid [label $summaryf.origlabel -text "Description of Original Model"] \
	-row 3 -column 0 -sticky w
    grid [text $summaryf.origtext -width 60 -height 4] -row 3 -column 1

    pack $t.metadata.summary -padx 4 -pady 4 -fill both -expand 1
    TitleFrame $t.metadata.publications -text "Publications"
    set publicatf [GetFrame $t.metadata.publications]
    pack [listbox $publicatf.list -height 4] -fill x -expand 1
    pack [button $publicatf.addb -text "Add Publication" \
	      -command "AddPub $mdl"] -side left
    pack [button $publicatf.removeb -text "Remove Publication"] -side left
    pack $t.metadata.publications -padx 4 -pady 4 -fill both -expand 1

    $t select 0
    pack $t -fill both -expand true

    ttk::button $tf.ok -text [tr. OK] -width 10 -default active \
            -command $okCmd
    pack $tf.ok -side left -padx 2 -pady 4
    ttk::button $tf.cancel -text [tr. Cancel] -width 10 \
            -command {set disaggregate(done) 0}
    pack $tf.cancel -side left -padx 2 -pady 4
    ttk::button $tf.help -text [tr. Help] -width 10 \
            -command {ContextSensitiveHelp .disaggregation submodels/dialogue.htm}
    pack $tf.help -side left -padx 2 -pady 4
    pack $tf
#    button $tf.more -text "More" -width 10 -command "ShowComplexity $t"
#    pack $tf.more -padx 2 -pady 4
    
#    pack $t.simple -anchor nw -fill both; # -expand 1 -fill both
    
    LetItShow $tt disaggregate(done)
    set disaggregate(desc) [string trimright [$notesf.desc.text get]]
    set disaggregate(comment) [string trimright \
				   [$notesf.commentsSW.comment get 1.0 end]]
    if {!$disaggregate(useOwnCode)} {
	set disaggregate(xproc) none
	set disaggregate(xinc) none
	set disaggregate(xlibs) {}
    }
    UpdateDisagInfo
    PackItUp $tt

    if {$new} {
	set icount $disaggregate(icount)
    } else {
    set icount {}
    if [string compare $disaggregate(icount) 1] {
        foreach newIndex [split $disaggregate(icount) ,] {
#            if {[string is double $newIndex] || \
#                        [string match size(*) $newIndex] || \
#                        [string match value(*) $newIndex]} {
                lappend icount $newIndex
#            } else {
#                lappend icount \"$newIndex\"
# enquoting removed as gave error with enum type -- only time used?
#            }
        }
        set icount [join $icount ,]
    }
    }

    if {$disaggregate(done)} {
	set stepIndx [lsearch $stepNames $disaggregate(step)]
	if {$stepIndx == -1} {
	    set step $disaggregate(step)
	} else {
	    set step [expr $stepIndx-2]
	}
        set enumTypes {}
        foreach {typename members} [array get disaggregate enumtype,*] {
            lappend enumTypes [concat [list [string range $typename 9 end]] \
                    $members]
        }
        set result [list $disaggregate(colour) $disaggregate(image) \
                $disaggregate(imgpos) $disaggregate(type) \
			$disaggregate(interp) \
                $disaggregate(fatness) $icount \
                $step $disaggregate(desc) $disaggregate(comment) \
                $disaggregate(eqnunit) $disaggregate(hide) \
                $disaggregate(separate) $disaggregate(xproc) \
		$disaggregate(xinc) $disaggregate(xlibs) $enumTypes]
    } else {
        set result {}
    }
    unset disaggregate
    return $result
}

proc AddPub {mdl} {
    global disaggregate

    set t [PutItThere .addpublication .disaggregation]
    wm title $t "Add Publication"
    pack [TitleFrame $t.online -text "Online publication"] \
	-padx 4 -pady 4 -fill x
    set onlinef [GetFrame $t.online]
    pack [label $onlinef.l -text "ID of Primary Publication:"] -side left
    pack [entry $onlinef.e] -side left
    foreach indexer {PUBMED DOI URL OFFLINE} {
	pack [radiobutton $onlinef.rb$indexer -variable disaggregate(md_idxr) \
		  -value $indexer -text $indexer] -side left
    }

    pack [TitleFrame $t.paper -text "Paper publication"] \
	-padx 4 -pady 4 -fill x
    set paperf [GetFrame $t.paper]

    grid [label $paperf.jlabel -text "Journal:"] -row 0 -column 0 -sticky w
    grid [entry $paperf.jentry] -row 0 -column 1 -sticky ew
    grid [label $paperf.tlabel -text "Title:"] \
	-row 1 -column 0 -sticky w
    grid [entry $paperf.tentry] -row 1 -column 1 -sticky ew
    grid [label $paperf.alabel -text "Authors:"] \
	-row 2 -column 0 -sticky w
    grid [entry $paperf.aentry] -row 2 -column 1 -sticky ew
    grid [label $paperf.slabel -text "Abstract:"] \
	-row 3 -column 0 -sticky w
    grid [text $paperf.stext -width 60 -height 4] -row 3 -column 1


    pack [frame $t.btnfr]
    pack [button $t.btnfr.ok -text [tr. OK] \
	      -command "set disaggregate(pdone) 1"] -side right
    pack [button $t.btnfr.cancel -text [tr. Cancel] \
	      -command "set disaggregate(pdone) 0"] -side right
    LetItShow $t disaggregate(pdone)
#    if {$disaggregate(xdone)} {
# transfer data back to variables
#	set disaggregate(xproc) [[GetFrame $t.procnamfr].ent get]
#	set disaggregate(xinc) [string trimright [$incFileTxt get 1.0 end]]
#	set disaggregate(xlibs) [${LibListFr}.box get 0 end]
#    }
    PackItUp $t
}

proc AbleSetup {mathf} {
    global disaggregate
    
    $mathf.extcode.how configure -state \
	[ChooseText $disaggregate(useOwnCode) normal disabled]
}

proc ExtCodeSetup {mdl} {
    global disaggregate

    set t [PutItThere .extcodesetup .disaggregation]
    wm title $t [tr. "External code interaction"]
    pack [TitleFrame $t.procnamfr -text [tr. "Procedure name:"]] \
	-padx 4 -pady 4 -fill x
    pack [entry [GetFrame $t.procnamfr].ent] -fill x
    [GetFrame $t.procnamfr].ent insert 0 $disaggregate(xproc)

    pack [TitleFrame $t.incfilefr -text [tr. "Include file:"]] \
	-padx 4 -pady 4 -fill x
    set incFileTxt [GetFrame $t.incfilefr].txt
    pack [text $incFileTxt -width 32 -height 1] \
	-side left -fill x
    $incFileTxt insert 1.0 $disaggregate(xinc)
    $incFileTxt configure -state disabled
    pack [button [GetFrame $t.incfilefr].btn -text [tr. Browse] \
	      -command "ChangeIncFile $incFileTxt $mdl"] -anchor e -side right

    pack [TitleFrame $t.liblistfr -text [tr. "Library files:"]] \
	-padx 4 -pady 4 -fill x
    set LibListFr [GetFrame $t.liblistfr]
    pack [listbox ${LibListFr}.box] -side left -fill x -expand true
    foreach libFile $disaggregate(xlibs) {
	${LibListFr}.box insert end $libFile
    }
    pack [button ${LibListFr}.badd -text [tr. Add] \
	      -command "AddLibF $LibListFr $mdl"] -anchor w -side top
    pack [button ${LibListFr}.bdel -text [tr. Delete] \
	     -command "RemoveLibF $LibListFr"] -anchor w -side top

    pack [frame $t.btnfr]
    pack [button $t.btnfr.ok -text [tr. OK] \
	      -command "set disaggregate(xdone) 1"] -side right
    pack [button $t.btnfr.cancel -text [tr. Cancel] \
	      -command "set disaggregate(xdone) 0"] -side right
    LetItShow $t disaggregate(xdone)
    if {$disaggregate(xdone)} {
# transfer data back to variables
	set disaggregate(xproc) [[GetFrame $t.procnamfr].ent get]
	set disaggregate(xinc) [string trimright [$incFileTxt get 1.0 end]]
	set disaggregate(xlibs) [${LibListFr}.box get 0 end]
    }
    PackItUp $t
}    

proc SetupDisagExtras {exFrame} {
    global disaggregate

    set selIdx [lsearch [$disaggregate(countf).mb cget -values] \
		    $disaggregate(cbxv)]
# converted this to a panel in the main dialogue
#    set t [PutItThere .disagExtra .disaggregation]
#    wm resizable $t 0 0
#    wm protocol $t WM_DELETE_WINDOW {set disaggregate(exdone) 0}
#    wm title $t [format [tr. "Extra info for %s"] \
#		     $disaggregate(cbxv)]
#    pack [ttk::label .disagExtra.l -wraplength 400]
    if {[winfo exists $exFrame.dims]} {
	destroy $exFrame.dims
    }
    switch $selIdx {0 {
	$exFrame.l configure -text [tr. {Single-instance submodel. This can denote a functionally distinct part of the parent model, or denote the set of components to which some other special feature applies, e.g., a different time step.}]
    } 1 {
	$exFrame.l configure -text [tr. {Single- or multi-dimensional array of instances. Dimensions can be either numerical, or the names of enumerated types where there is one element for each member of the type. Enter the dimension(s) below, with commas between them if more than one.}]
	set disaggregate(newdims) [join $disaggregate(icount) ,]
	pack [ttk::entry $exFrame.dims -textvariable disaggregate(newdims)]
    } 2 {
	$exFrame.l configure -text [tr. {Submodel with one instance per value of a file parameter. It must contain at least one file parameter variable to set its membership.}]
    } 3 {
	$exFrame.l configure -text [tr. {Population submodel. Membership is controlled by the population channel symbols. It must contain at least one creation or immigration channel for the population to have some members.}]
    } 4 {
	$exFrame.l configure -text [tr. {Submodel representing a rectangular grid. Both dimensions must be numerical.
To access values from neighbouring squares in an equation, open the properties dialoge of an incoming influence and select "Use values from all neighbours", or heighbours to a particular direction, as appropriate.}]
	pack [frame $exFrame.dims]
	pack [ttk::label $exFrame.dims.rows -text [tr. Rows:]] -side left
	pack [ttk::entry $exFrame.dims.y -textvariable disaggregate(y)] \
	    -side left
	pack [ttk::entry $exFrame.dims.x -textvariable disaggregate(x)] \
	    -side right
	pack [ttk::label $exFrame.dims.cols -text [tr. Columns:]] \
	    -side right
    } 5 {
	$exFrame.l configure -text [tr. {Submodel representing a hexagonal grid. Both dimensions must be numerical.
Hexagons cover a roughly rectangular area and have vertical edges to left and right. To fit them together, the left sides of hexagons in odd numbered rows are vertically aligned with the centres of those in even numbered rows.}]
 	pack [frame $exFrame.dims]
	pack [ttk::label $exFrame.dims.rows -text [tr. Rows:]] -side left
	pack [ttk::entry $exFrame.dims.y -textvariable disaggregate(y)] \
	    -side left
	pack [ttk::entry $exFrame.dims.x -textvariable disaggregate(x)] \
	    -side right
	pack [ttk::label $exFrame.dims.cols -text [tr. Columns:]] \
	    -side right
    } 6 {
    }
    }
}
#    frame $exFrame.bottom
#    pack [button $exFrame.bottom.bdone -text [tr. OK] -width 10 \
#	      -command {set disaggregate(exdone) 1}] -side left -padx 4 -pady 4
#    pack [button $exFrame.bottom.bc -text [tr. Cancel] -width 10 \
#	      -command {set disaggregate(exdone) 0}] -side right -padx 4 -pady 4
#    pack $exFrame.bottom -side left
#    LetItShow $t disaggregate(exdone)
#    PackItUp $t
#    if {$disaggregate(exdone)} {...}

proc UpdateDisagInfo {} {
    global disaggregate

    set selIdx [lsearch [$disaggregate(countf).mb cget -values] \
		    $disaggregate(cbxv)]
    set disaggregate(interp) none
    set disaggregate(icount) {}
    switch $selIdx {
	0 {
	    set disaggregate(type) generated
	} 1 {
	    set disaggregate(type) generated
	    set disaggregate(interp) none
	    set disaggregate(icount) {}
	    foreach newIndex [split $disaggregate(newdims) ,] {
		if {[string is double $newIndex]} {
		    lappend disaggregate(icount) $newIndex
		} elseif {[string first \( $newIndex]>=1} { 
		    # arg is atom, enquote
		    lappend disaggregate(icount) \
			[string map {( (' ) ')}  $newIndex]
		} else { ;# index is atom
		    lappend disaggregate(icount) \'$newIndex\'
		}
	    }
	    set disaggregate(icount) [join $disaggregate(icount) ,]
	} 2 {
	    set disaggregate(type) records
	} 3 {
	    set disaggregate(type) population
	} 4 {
	    set disaggregate(type) generated
	    set disaggregate(interp) \
		rect_grid($disaggregate(y),$disaggregate(x))
	    set disaggregate(icount) $disaggregate(y),$disaggregate(x)
	} 5 {
	    set disaggregate(type) generated
	    set disaggregate(interp) \
		hex_grid($disaggregate(y),$disaggregate(x))
	    set disaggregate(icount) $disaggregate(y),$disaggregate(x)
	}
    }
#    ShowDisagSetup
}

proc ShowDisagSetup {} {
    global disaggregate

    set sides {}
    set interp $disaggregate(interp)
    array set disaggregate [list x {} y {}]
    switch -glob $interp {
	rect_grid* {
	    set interpIdx 4
	    scan $disaggregate(interp) rect_grid(%d,%d) y x
	    set sides ${y}x${x}
	    array set disaggregate [list x $x y $y]
	} hex_grid* {
	    set interpIdx 5
	    scan $disaggregate(interp) hex_grid(%d,%d) y x
	    set sides ${y}x${x}
	    array set disaggregate [list x $x y $y]
	} default {
    # get from type and value only
	    switch $disaggregate(type) {
		generated {
		    if {[llength $disaggregate(icount)]} {
			set interpIdx 1
			set sides [join [split $disaggregate(icount) ,] x]
		    } else {
			set interpIdx 0
		    }
		} records {
		    set interpIdx 2
		} population {
		    set interpIdx 3
		}
	    }
	}
    }
    set disaggregate(cbxv) [lindex [$disaggregate(countf).mb cget -values] \
				$interpIdx]
#    $disaggregate(countf).detail configure -text $sides
}

proc ChangeIncFile {incFileTxt mdl} {
    set newFile [ChooseFile external.cpp [tr. "External source/header file:"] \
		     0 $mdl]
    if {[string length $newFile]} {
	$incFileTxt configure -state normal
	$incFileTxt delete 1.0 end
	$incFileTxt insert 1.0 $newFile
	$incFileTxt configure -state disabled
    }
}

proc AddLibF {LibListFr mdl} {
    set newFile [ChooseFile library[linkableExt [info sharedlibextension]] \
		     [tr. "External library file:"] 0 $mdl]
    if {[string length $newFile]} {
	if {[string match lib* [file tail $newFile]]} {
	    ${LibListFr}.box insert end $newFile
	} else {
	    Query dodgy_lib warning ext_code {} ok
	}
    }
}

proc RemoveLibF {LibListFr} {
    if {[set togo [${LibListFr}.box curselection]] ne {} } {
	${LibListFr}.box delete $togo
    }
}

#proc ShowComplexity {t} {
#    if {[string match [$tf.more cget -text] More]} {
#        pack $t.complex -anchor sw -side bottom
#        wm geometry $t {}; # resize to size requested internally by its widget
#        $tf.more configure -text Less
#    } else  {
#        pack forget $t.complex
#        $tf.more configure -text More
#    }
#}
#
proc ClearBG {posRBs} {
    global disaggregate
    set disaggregate(colour) {}
    set disaggregate(image) {}
    set disaggregate(imgpos) none
    foreach button [winfo children $posRBs] {
        $button configure -state disabled
    }
}

#proc OldAddEnumType {fr} {
#    global addenumtype tcl_platform
#    PutItThere .typeadder $fr
#    pack [frame .typeadder.what]
#    pack [label .typeadder.what.l -text Name:] -side left
#    pack [entry .typeadder.what.e -textvariable addenumtype(name)] -side left
#    pack [frame .typeadder.btns]
#    pack [button .typeadder.btns.ok -text OK \
#            -command "set addenumtype(done) 1"] -side left
#    pack [button .typeadder.btns.cancel -text Cancel \
#            -command "set addenumtype(done) 0"] -side left
#    grab .typeadder
#    tkwait variable addenumtype(done)
#    grab release .typeadder
#    if {$addenumtype(done)} {
#        $fr.scrf insert end $addenumtype(name)
#    }
#    PackItUp .typeadder
#}
#
proc AddEnumTypeMems {fr} {
    global disaggregate
    set togo [$fr.listpair.typef.scrf curselection]
    set enumEntry [list [$fr.listpair.typef.scrf get $togo $togo]]
    $fr.curmembers delete 0 end
    foreach mem $disaggregate(enumtype,$enumEntry) {
        $fr.curmembers add command -label $mem \
                -command [list snipET $enumEntry $mem]
    }
}

proc AddEnumType {fr} {
    global disaggregate enumTypeMPEntry
    if {[CheckForETDuplicates {enumerated type}]} {
        $fr.typef.scrf insert end $enumTypeMPEntry
        $fr.typef.scrf selection clear 0 end
        $fr.typef.scrf selection set end
        EnableTypeOps [winfo parent $fr]
        set disaggregate(enumtype,$enumTypeMPEntry) {}
        [winfo parent $fr].btns.e delete 0 end
	focus [winfo parent $fr].btns.e
    }
}

proc RemoveEnumType {fr} {
    global disaggregate
    if {[$fr.listpair.typef.scrf curselection] ne {} } {
        set togo [$fr.listpair.typef.scrf curselection]
        set type [$fr.listpair.typef.scrf get $togo]
        # empty $fr.listpair.memf.mem by emptying its -listvariable
        set disaggregate(enumtype,$type) {}
        # must move -listvariable from disaggregate(enumtype,$type)
        # or it cannot be unset
        $fr.listpair.memf.mem configure -listvariable {}
        unset disaggregate(enumtype,$type)
        $fr.listpair.typef.scrf delete $togo
        EnableTypeOps $fr
        # select first type in the list
        $fr.listpair.typef.scrf selection set 0
        set togo [$fr.listpair.typef.scrf get 0]
        if {$togo ne {} } {
            $fr.listpair.memf.mem configure -listvariable disaggregate(enumtype,$togo)
        }
    }
}

proc AddEnumMem {fr} {
    global disaggregate enumTypeMPEntry
    if {[CheckForETDuplicates member]} {
        set togo [$fr.listpair.typef.scrf get [$fr.listpair.typef.scrf curselection]]
        lappend disaggregate(enumtype,$togo) $enumTypeMPEntry
        $fr.listpair.memf.mem configure -listvariable disaggregate(enumtype,$togo)
        $fr.listpair.memf.mem selection clear 0 end
        $fr.btns.e delete 0 end
	focus $fr.btns.e
    }
}

proc AddEnumTypePopup {lb y X Y} {
    global disaggregate
    set popLine [$lb get [$lb nearest $y]]
    set memList disaggregate(enumtype,$popLine)
    if {[info exists $memList]} {
        AddWidgetPopup $X $Y "members: [set $memList]"
    }
}

# Changed reporting from list to single error as I can't see how you could get
# more than one of these
proc CheckForETDuplicates {new} {
    global disaggregate enumTypeMPEntry

    if {![info exists enumTypeMPEntry] || ![string length $enumTypeMPEntry]} {
	set query [list no_et_member $new]
    } elseif {[lsearch {NULL novalue none noitem} $enumTypeMPEntry]>-1} {
	set query [list bad_et_member $new $enumTypeMPEntry]
    } else {
	set def [GetFromProlog tk_get_info({},'$enumTypeMPEntry',is_unit)]
	if {![string equal none $def]} {
	    set query [list member_is_unit $new $enumTypeMPEntry $def]
	} else {
	    foreach {type members} [array get disaggregate enumtype,*] {
		set oldType [string range $type 9 end]
		if {[string equal $enumTypeMPEntry $oldType]} {
		    set query [list duplicate_et $new $oldType]
		}
		if {[lsearch $members $enumTypeMPEntry] != -1} {
		    set query [list duplicate_et_mem $new $oldType \
					 $enumTypeMPEntry]
		}
	    }
	}
    }
    if {[info exists query]} {
	Query $query warning enumtype {} ok
	return 0
    }
    return 1
}

proc RemoveEnumMem {fr} {
    #    tk_popup $fr.curmembers [winfo pointerx $fr] [winfo pointery $fr]
    global disaggregate
    
    if {[$fr.listpair.memf.mem curselection] ne {} } {
        set togo [$fr.listpair.typef.scrf get [$fr.listpair.typef.scrf curselection]]
        #ShowMess debug info "togo $togo $disaggregate(enumtype,$togo)" ok
        set index [lsearch $disaggregate(enumtype,$togo) \
                [$fr.listpair.memf.mem get [$fr.listpair.memf.mem curselection] ] ]
        set disaggregate(enumtype,$togo) \
                [lreplace $disaggregate(enumtype,$togo) $index $index]
        $fr.listpair.memf.mem configure -listvariable disaggregate(enumtype,$togo)
    }
}

proc GetEnumMems {fr mdl} {
    global table_entry
    set togo [$fr.listpair.typef.scrf get [$fr.listpair.typef.scrf curselection]]
    upvar \#0 disaggregate(enumtype,$togo) memList
    set table_entry(data) {} ;# dont try to keep file origins
    set table_entry(values) {}
    for {set pos 0} {$pos < [llength $memList]} {incr pos} {
        lappend table_entry(values) [expr $pos+1] \
                [list [lindex $memList $pos]]
    }
    if {[equationDoTable .disaggregation $mdl "enumerated type" \
	     "(defined by values)" no]} {
        set fileState [list $table_entry(fileName) $table_entry(dataField)]
        set fileData $table_entry(values)
	ListDiscrete memList $fileData
    }
    EnableTypeOps $fr
}

proc ListDiscrete {memList fileData} {
    upvar 1 $memList inList
    if {[llength $fileData]!=1} {
	foreach {pos mem} $fileData {
	    ListDiscrete inList $mem
	}
    } else {
	set fileData [lindex $fileData 0]
	if {[lsearch $inList $fileData]==-1} {
	    lappend inList $fileData
	}
    }
}

proc snipET {enumEntry mem} {
    global disaggregate
    set tgt [lsearch $disaggregate(enumtype,$enumEntry) $mem]
    set disaggregate(enumtype,$enumEntry) \
            [lreplace $disaggregate(enumtype,$enumEntry) $tgt $tgt]
}

proc EnableTypeOps {fr} {
    if {[llength [$fr.listpair.typef.scrf curselection]]} {
        set haveSeln normal
    } else {
        set haveSeln disabled
    }
    foreach btn {remtype addmems remmem getmem} {
        $fr.btns.$btn config -state $haveSeln
    }
    if {[$fr.listpair.typef.scrf curselection] ne ""} {
        set togo [$fr.listpair.typef.scrf get [$fr.listpair.typef.scrf curselection]]
        $fr.listpair.memf.mem configure -listvariable disaggregate(enumtype,$togo)
        $fr.listpair.memf.mem selection clear 0 end        
    }
}

proc UpdateColour {parent f} {
    global disaggregate
    
    set new [tk_chooseColor -parent $parent \
            -initialcolor $disaggregate(defColour)]
    if {[llength $new]} {
        set disaggregate(colour) $new
        set disaggregate(defColour) $new
#        $f.fixcolour configure -bg $new
    }
}

if {!$::headless && ![info exists simplify]} {
# try to be choosy rather than support everything
    if {[catch {
	if {[info tclversion]<8.6} {
	    package require img::png ;# for internal image storage
	}
	package require img::bmp ;# for grid helper (could use ppm)
	package require img::jpeg ;# support this popular format
    } imgFail]} {
	puts "Error loading image formats: $imgFail"
    }
}

proc ChooseImage {posRBs mdl noCentred} {
    global disaggregate
    
    set uid 0
    set newImage backgnd$uid
    while {![catch {image type $newImage}]} {
        incr uid
        set newImage backgnd$uid
    }
    image create photo $newImage
    set choosing 1
    while {$choosing} {
        set new [ChooseFile image.gif [tr. {Image for model background}] 0 $mdl]
        if {[llength $new]} {
            if {![catch {$newImage read $new -shrink} readFlop]} {
                if {![llength $readFlop]} {
                    set readFlop [string range [file extension $new] 1 end]
                }
                set disaggregate(image) $newImage
                PutSize $newImage
                set choosing 0
                foreach button [winfo children $posRBs] {
                    $button configure -state normal
                }
		if {$noCentred} {
		    $posRBs.ipCentred configure -state disabled
		}
                if {[string equal none $disaggregate(imgpos)]} {
                    set disaggregate(imgpos) Tiled
                }
            } else {
		Query [list read_image_failed $readFlop] warning top {} ok
                # prevent crasho if reading fails
                #       $newImage config -width 100 -height 100
            }
        } else {
            image delete $newImage
            set choosing 0
        }
    }
}

proc PutSize {img} {
    set width 0
    while {![catch {$img get $width 0}]} {
        incr width
    }
    set height 0
    while {![catch {$img get 0 $height}]} {
        incr height
    }
    # set them so I can read later
    $img config -width $width -height $height
}

proc SetHighlights {t} {
    global disaggregate
    
    switch -regexp $disaggregate(type) {
        none|population|records {
            $t.value configure -state disabled
        }
        simple|generated {
            $t.value configure -state normal
        }
    }
}

set progressBoxCount 0
proc OpenProgressBox {winId} {
    global progressBoxCount

    if {!$::headless && !$progressBoxCount} {
	PutItThere .progress $winId
	wm title .progress [tr. "Progress with current operation"]
	wm protocol .progress WM_DELETE_WINDOW {set done 1}
	# do not allow delete
	pack [frame .progress.filler -width 400 -height 100]
	if {[LetItShow .progress]} {
	    grab .progress
	}
	destroy .progress.filler
	wm geometry .progress 400x100
	message .progress.message -aspect 400 -text [tr. "Please wait"]
	pack .progress.message -fill both -expand true
	update
	incr progressBoxCount ;# update can cause AbandonEqn and ResetProgress
    }
    return $progressBoxCount
}

proc FillProgressBox {key lits} {
    global msgs

    set word [eval [list format $msgs($key)] $lits]
    if {$::headless} {
	puts "Progress message: $word"
    } else {
	.progress.message configure -text [eval [list format $msgs($key)] $lits]
	update
    }
}

proc CloseProgressBox {} {
    global progressBoxCount

    if {!$::headless && ![incr progressBoxCount -1]} {
	grab release .progress
	PackItUp .progress
    }
    return $progressBoxCount
}

proc ResetProgressBox {} {
    global progressBoxCount

    if {!$::headless && [winfo exists .progress]} {
	CloseProgressBox
    }
    set progressBoxCount 0
}

proc TextCheckAndSet {parent title state} {
    global text_props

    set t [PutItThere .relcheck $parent]
    wm resizable $t 0 0
    wm protocol $t WM_DELETE_WINDOW {set text_props(done) 0}
    wm title $t [format $::msgs(props_title) [BlankCrs $title]]
    frame .relcheck.top
    TitleFrame .relcheck.top.left -text [tr. {Text options:}]
    set f [GetFrame .relcheck.top.left]
    pack [frame $f.width -bd 4]
    pack [ttk::label $f.width.lab -text [tr. {Width (in columns): }]] \
	-side left
    pack [ttk::entry $f.width.ent -textvariable text_props(columns)]
    pack [frame $f.relsize -bd 4] -fill x -expand true
    pack [ttk::label $f.relsize.lab -text [tr. {Relative size: }]] \
        -side left
    pack [ttk::scale $f.relsize.ent -from 20 -to 500 -orient h \
	      -variable text_props(rel_size)] -fill x -expand true
    set text_props(rel_size) [lindex $state 0]
    set text_props(columns) [lindex $state 1]
    pack .relcheck.top.left -expand on -fill both
    pack .relcheck.top -expand on -fill both

    frame .relcheck.bottom
    pack [button .relcheck.bottom.bdone -text [tr. OK] -width 10 \
	      -command {set text_props(done) 1}] -padx 4 -pady 4
    pack [button .relcheck.bottom.bc -text [tr. Cancel] -width 10 \
	      -command {set text_props(done) 0}] -padx 4 -pady 4
    pack .relcheck.bottom -side left

    LetItShow $t text_props(done)
    PackItUp $t
    set results $text_props(done)
    lappend results $text_props(rel_size) $text_props(columns)
    return $results
}

proc RelationCheck {parent title type entries state init_comment} {
    global msgs relation tcl_platform
    
    set t [PutItThere .relcheck $parent]
    wm resizable $t 0 0
    wm protocol $t WM_DELETE_WINDOW {set relation(done) 0}
    wm title $t [format $msgs(props_title) [BlankCrs $title]]
    frame .relcheck.top
    TitleFrame .relcheck.top.left \
	-text [format [tr. {%1$s options:}] [string toupper $type]]
    set f [GetFrame .relcheck.top.left]
    
    switch $type {
        influence {
	    set helpPage concepts/sd/influence.htm
        } relation {
	    set helpPage submodels/association/dialogue.htm
        } default {
	    set helpPage index.htm
	}
    }
    foreach attr $entries val $state {
	set capt [format $msgs([lindex $attr 0]) [lrange $attr 1 end]]
        pack [checkbutton $f.$attr -text $capt -wraplength 160 \
                -variable relation($attr) -offvalue 0 -onvalue 1] -anchor w
        set relation($attr) $val
        if {$relation($attr)==-1} {
            $f.$attr configure -state disabled
        }
    }
    pack .relcheck.top.left -side left -padx 4 -pady 4 -expand on -fill both -anchor nw
    frame .relcheck.top.right
    pack [button .relcheck.top.right.bdone -text [tr. OK] -width 10 \
	      -command {set relation(done) 1}] -padx 4 -pady 4
    pack [button .relcheck.top.right.bc -text [tr. Cancel] -width 10 \
	      -command {set relation(done) 0}] -padx 4 -pady 4
    pack [button .relcheck.top.right.help -text [tr. Help] -width 10 \
	  -command "ContextSensitiveHelp .relcheck $helpPage"] -padx 4 -pady 4
    pack .relcheck.top.right -side left
    pack .relcheck.top -expand on -fill both
    TitleFrame .relcheck.bottom -text [tr. Comments:]
    set f [GetFrame .relcheck.bottom]
    pack [text $f.comment -width 40 -height 4 -relief sunken -bd 2 -highlightthickness 0 -wrap word] \
            -anchor w -expand on -fill both -padx 2 -pady 2
    $f.comment delete 1.0 end
    $f.comment insert 1.0 $init_comment
    pack .relcheck.bottom
    
    LetItShow .relcheck relation(done)
    set newComment [string trimright [$f.comment get 1.0 end]]
    PackItUp .relcheck
    set results [list $relation(done) $newComment]
    foreach attr $entries {
        lappend results $relation($attr)
    }
    return $results
}

set find(prevs) {}

proc GetFindText {canvas} {
    global find tcl_platform
    set t [PutItThere .findentry $canvas]
    wm protocol $t WM_DELETE_WINDOW {set find(done) 0}
    wm title $t "Find"
    wm resizable $t 0 0
    TitleFrame .findentry.follow -text "Follow influences "
    set follow [GetFrame .findentry.follow]
    pack [ttk::label $follow.to -text [tr. Components...]] -anchor w
    pack [ttk::label $follow.from -text [tr. ...selection]] \
	-side bottom -anchor e
    pack [ttk::button $follow.back -text [tr. "influencing"] \
	      -command "set find(done) 10"] \
	-padx 2 -pady 4 -side left
    pack [ttk::button $follow.forward -text [tr. "influenced by"] \
	      -command "set find(done) 12"] \
	-padx 2 -pady 4 -side right
    pack [ttk::button $follow.here -text [tr. "equivalent to"] \
	      -command "set find(done) 11"] \
	-padx 2 -pady 4
    pack .findentry.follow -anchor nw -fill both

    set ft [frame .findentry.ft]
    pack [message $ft.m -text "Find text:" -width 300] \
	-padx 4 -pady 6 -anchor nw -side left
    pack [ttk::combobox $ft.e -width 40 -values $find(prevs)] \
        -padx 4 -pady 6 -anchor nw -side left

    bind $ft.e <Return> "set find(done) 1"
    pack .findentry.ft -anchor nw -fill both
    TitleFrame .findentry.rbs -text "Search for text in "
    set rbs [GetFrame .findentry.rbs]
    set find(where) caption
    ttk::radiobutton $rbs.r1 -text "Captions" -variable find(where) \
	-value caption
    ttk::radiobutton $rbs.r2 -text "Equations" -variable find(where) \
	-value equation
    ttk::radiobutton $rbs.r3 -text "Descriptions and comments" \
            -variable find(where) -value description
    pack $rbs.r1 -anchor nw
    pack $rbs.r2 -anchor nw
    pack $rbs.r3 -anchor nw
    pack $rbs -anchor nw -fill both -padx 4 -pady 4
    pack .findentry.rbs -anchor nw -fill both
    pack [set bs [frame .findentry.buttframe]]
    #pack [button $bs.clear -text Clear -width 10 -command ".findentry.e delete 0 end"] -padx 2 -pady 2 -side left
    pack [button $bs.ok -text [tr. OK] -default active -width 10 \
	      -command "set find(done) 1"] -padx 2 -pady 4 -side left
    pack [button $bs.cancel -text [tr. Cancel] -width 10 \
	      -command "set find(done) 0"] -padx 2 -pady 4 -side left
    pack [button $bs.help -text [tr. Help] -width 10 \
	      -command "ContextSensitiveHelp .findentry diagrams/search.htm"] \
	-padx 2 -pady 4 -side left
    
    focus $ft.e
    LetItShow .findentry find(done)
    set result [$ft.e get]
    PackItUp .findentry
    if {$find(done)==1} {
    set find(prevs) [AddIfAbsent $result $find(prevs)]
        return $result
    }
}

# to stop more than 5 chars going in each half of the licence field
# and auto tab between them
proc LimitChars {field result} {
    switch [string length $result] {
	0 - 1 - 2 - 3 - 4 {
	} 5 {
	    if {[$field index insert]>=4} {
		event generate $field <Key-Tab>
	    }
	} default {
	    return 0
	}
    }
    return 1
}

proc DoUserDialogue {} {
    global userinfo
    set t [PutItThere .userdata .splash]
    wm title $t [tr. "Enter your details (not required for evaluation edition)"]
    pack [label $t.mess -text "Please enter your name, organization and license code if required."]
    pack [frame $t.head]

    grid [label $t.head.nmess -text Name:] [entry $t.head.nentry -width 40] -sticky w
    grid [label $t.head.cmess -text Organization:] [entry $t.head.centry -width 40] -sticky w
    grid [label $t.head.lmess -text "License code:"] [frame $t.head.lfield] -sticky w

    pack [entry $t.head.lfield.entryl -width 5 -validate key \
	      -validatecommand [list LimitChars %W %P]] -side left
    pack [label $t.head.lfield.hyphen -text {-}] -side left
    pack [entry $t.head.lfield.entryr -width 5 -validate key \
	      -validatecommand [list LimitChars %W %P]] -side left
    pack [label $t.head.lfield.free -text [tr. {(not required for evaluation edition)}]] -side left -fill x

    pack [message $t.mess2 -aspect 1000 -text [tr. "Now carefully read the following End User License Agreement, and click 'ACCEPT' to indicate that you have read and understood it and that you agree to the terms set out in it."]]
    pack [frame $t.agree -bd 4 -relief groove] -fill x
    pack [scrollbar $t.agree.y -orient v -command "$t.agree.t yview"] \
	-side right -fill y
    pack [text $t.agree.t -wrap word -yscrollcommand "$t.agree.y set"] -fill x
    set licStr [NetOpen ../eula.txt r]
    $t.agree.t insert end [read $licStr]
    close $licStr
    $t.agree.t config -state disabled
    pack [frame $t.buttons] -fill x
    pack [button $t.buttons.ok -text ACCEPT \
	      -command "set userinfo(entrydone) 1"] -side left
    pack [button $t.buttons.ex -text "DO NOT ACCEPT" \
	      -command "set userinfo(entrydone) 0"] -side right
    
    LetItShow $t userinfo(entrydone)
    focus $t.head.nentry
    wm withdraw .splash
    if {$userinfo(entrydone)} {
	set userinfo(name) [$t.head.nentry get]
	set userinfo(corp) [$t.head.centry get]
	set userinfo(license_code) [format %5s-%5s [$t.head.lfield.entryl get] [$t.head.lfield.entryr get]]
    }
    wm deiconify .splash
    PackItUp $t
    return $userinfo(entrydone)
}

proc DoWelcomeDialog {dtId} {
    global userinfo custom welcomeDone tcl_platform SimileAutoObjLoaded
    
    if {[info exists SimileAutoObjLoaded]} {
        return
    }
#    set whatCalled [file rootname [file tail [info nameofexecutable]]]
#    if {[string equal SimileScript $whatCalled]} {
#        return
#    }

    # OK, we used to show this dialogue when we had just loaded a new
    # version.  Now, we want to show it when a new version is
    # available...

    set newVers [GetLatestVers]
    if {$newVers == 0} {set newVers $userinfo(oldVersion)}
    if {$newVers==$userinfo(oldVersion) && $userinfo(done)} {
	return
    } else {
        file mkdir $custom(prefDir)/Examples
        foreach egFile [glob [pwd]/../Examples/*] {
            # next condition only matters in development environment
            if {![file isdirectory $egFile]} {
                catch {file copy -force $egFile $custom(prefDir)/Examples}
            }
        }
        if {![llength $custom(hotlist)]} {
            set custom(hotlist) [glob $custom(prefDir)/Examples/*.sml]
        }
    }
    set t [PutItThere .register $dtId]
    wm title $t "Welcome to Simile version $userinfo(Version)"
    wm protocol $t WM_DELETE_WINDOW {set userinfo(done) 0}
    set welcomeDone 0
    image create photo welcome
    welcome read "../Images/Welcome.gif"
    image create photo wopen
    wopen read "../Images/Toolbar/open.gif"
    image create photo wnew
    wnew read "../Images/Toolbar/new.gif"
    pack [label .register.welcome -image welcome] -anchor w
    
    TitleFrame .register.create -text "Creating a model: "
    set create [GetFrame .register.create]
    set msgtxt "Select compartments and flows from the toolbar\
                to add to the diagram. Use the select (pointer) tool to edit captions\
                and values. Run your model using the Run command of the Model menu."
    switch [tk windowingsystem] {
        win32 {
            pack [message $create.m -text $msgtxt -width 400 -font {-family helvetica -size 8}]
        } default {
            pack [message $create.m -text $msgtxt -width 400]
        }
    }
    pack $create -expand on -fill x
    #   pack [frame $create.buttons]
    #   pack [button $create.buttons.new -text "New model" -command {set userinfo(done) $welcomeDone}] -padx 4 -side left
    #   pack [button $create.buttons.open -text "Open model" -command "MenuSelect $dtId.canvas file open; set userinfo(done) \$welcomeDone"] -padx 4 -side left
    
    pack .register.create -expand on -fill x -padx 4 -pady 2
    
    TitleFrame .register.tasks -text "Choose a model: "
    set tasks [GetFrame .register.tasks]
    
    frame $tasks.b
    # MacVersion does not display compound (image + text) buttons at all well.
    switch [tk windowingsystem] {
        aqua {
            pack [button $tasks.b.new -text "New" -width 10  \
                -command {set userinfo(done) $welcomeDone}] \
                -padx 8 -pady 8 -side left
            pack [button $tasks.b.open -text "Open..." -width 10 \
                -command "MenuSelect $dtId.canvas local open_all; set userinfo(done) \$welcomeDone" ] \
                -padx 8 -pady 8 -side left
            pack [button $tasks.b.reopen -text "Recent..." -width 10 \
                -command "PopReopen $dtId"] \
                -padx 8 -pady 8 -side left
        } default  {
            pack [button $tasks.b.new -text "New" -width 65 -compound left -image wnew \
                -command {set userinfo(done) $welcomeDone}] \
                -padx 8 -pady 8 -side left
            pack [button $tasks.b.open -text "Open..." -width 65 -compound left -image wopen \
                -command "MenuSelect $dtId.canvas local open_all; set userinfo(done) \$welcomeDone" ] \
                -padx 8 -pady 8 -side left
            pack [button $tasks.b.reopen -text "Recent..." -width 10 \
                -command "PopReopen $dtId"] \
                -padx 8 -pady 8 -side left
        }
    }
    pack $tasks.b
    pack $tasks -fill x -expand on
    pack .register.tasks -fill x -padx 4 -pady 2
    
    TitleFrame .register.links -text "Useful links: "
    set links [GetFrame .register.links]
    
    frame $links.m1
    if {$newVers > $userinfo(oldVersion)} {
	pack [frame $links.m0] -anchor w
        pack [label $links.m0.left -text " * " -font {-family helvetica -size 12}] \
                -anchor w -side left
	pack [set www0 [label $links.m0.centre -text "Simile v$newVers" \
                -font {-underline true -family helvetica -size 12} -fg blue \
                -cursor hand2]] -anchor w -side left
	pack [label $links.m0.right -text " is available" -font {-family helvetica -size 12}]\
	    -anchor w -side left
	bind $www0 <Button-1> {VisitUrl http://simulistics.com/products/simile.php}
    }
    switch [tk windowingsystem] {
        win32 {
            pack [label $links.m1.left -text " *  Show " -font {-family helvetica -size 8}] \
                -anchor w -side left
            pack [set www1 [label $links.m1.centre -text "Getting Started" \
                -font {-underline true -family helvetica -size 8} -fg blue \
                -cursor hand2]] -anchor w -side left
            pack [label $links.m1.right -text " help pages" -font {-family helvetica -size 8}]\
                -anchor w -side left
        } default {
            pack [label $links.m1.left -text " *  Show " ] \
                -anchor w -side left
            pack [set www1 [label $links.m1.centre -text "Getting Started" \
                -fg blue \
                -cursor hand2]] -anchor w -side left
            pack [label $links.m1.right -text " help pages" ] \
                -anchor w -side left
        }
    }
    bind $www1 <Button-1> {ContextSensitiveHelp .register start/index.htm}
    pack $links.m1 -anchor w
# Removed ALD 25Feb2005 - non-functional at present due to missing Help pages
#    frame $links.m2
#    if {[string match Windows $tcl_platform(platform)]} {
#        pack [label $links.m2.left -text " *  Show " -font {-family helvetica -size 8}] \
#                -anchor w -side left
#        pack [set www2 [label $links.m2.centre -text "Example models" \
#                -font {-underline true -family helvetica -size 8} -fg blue \
#                -cursor hand2]] -anchor w -side left
#        pack [label $links.m2.right -text " help pages" -font {-family helvetica -size 8}] \
#                -anchor w -side left
#    } else {
#        pack [label $links.m2.left -text " *  Show " ] \
#                -anchor w -side left
#        pack [set www2 [label $links.m2.centre -text "Example models" \
#                -fg blue \
#                -cursor hand2]] -anchor w -side left
#        pack [label $links.m2.right -text " help pages" ] \
#                -anchor w -side left
#    }
#    pack $links.m2 -anchor w
    pack $links -expand on -fill x
    pack .register.links -expand on -fill x -padx 4 -pady 2
    
    pack [frame .register.checkframe] -padx 4 -pady 4
    pack [checkbutton .register.checkframe.cb -variable welcomeDone] -side left
    pack [label .register.checkframe.l -text "Do not show this welcome screen again"] \
            -side left
    #    pack [button .register.ok -text OK -width 10 -default active -command {set userinfo(done) $welcomeDone}]
    LetItShow .register userinfo(done)
    
# Removed ALD 25Feb2005 - non-functional at present due to missing Help pages
#    bind $www2 <Button-1> {ContextSensitiveHelp .register examples/index.htm}
    
    # now put it in the middle of the desktop
    scan [ wm geometry $dtId] {%dx%d+%d+%d} a s d f
    scan [ wm geometry .register] {%dx%d} g h
    #ShowMess debug info "Desktop $a x $s + $d + $f Welcome $g x $h" ok
    # if window is fullsize, offset info is garbage
    if {[string match zoomed [wm state $dtId]]} {
        set d 0
        set f 0
    }
    wm geometry .register +[expr $d+($a-$g)/2]+[expr $f+($s-$h)/2]
    
    if {$userinfo(done)} {
	set UserStream [NetOpen $custom(prefDir)/.version w]
	puts $UserStream $userinfo(name)
	puts $UserStream $userinfo(corp)
	puts $UserStream $newVers
	puts $UserStream 1 ;# not read as of v6.2
	close $UserStream
	switch [tk windowingsystem] {
	    win32 {file attributes $custom(prefDir)/.version -hidden true}
	}
    }
    
    # this never happens with welcome version
    if {$userinfo(done) == 2} {
        if {[catch {package require http
                set regData [::http::formatQuery Name $userinfo(name) \
                        Organisation $userinfo(corp) Email $userinfo(email) \
                        Version $userinfo(Version) OS $tcl_platform(os)]
                ::http::geturl http://www.simulistics.com/products/SendMail.asp \
                        -query $regData}]} {
            set userinfo(done) 1
        }
    }
    PackItUp .register
}

proc PopReopen {win} {
    FillReopen $win
    tk_popup .openrecent [winfo pointerx .register] [winfo pointery .register]
}

proc ContextSensitiveHelp {context page} {
    global tcl_platform helphtml env
    switch [tk windowingsystem] {
        win32 {
            package require winhelp
            winhelp $context ../help/simile_book.chm $page
        } aqua {
# try Snow Leopard location first
	    set helpPage [file join [file dirname $env(SYSDIR)] help $page]
	    if {[catch {exec open -a "HelpViewer.app" $helpPage}]} {
		exec open -a "Help Viewer.app" $helpPage
	    }
        } x11 {
            set url file://[file dirname [pwd]]/help/$page
            if {![info exists env(BROWSER)]} {
                foreach possBrowser {firefox mozilla netscape konqueror lynx} {
                    set env(BROWSER) [lindex [auto_execok $possBrowser] 0]
                    if {[llength $env(BROWSER)]} {
                        break
                    }
                }
            }
        # lynx can also output formatted text to a variable
        # with the -dump option, as a last resort:
        # set formatted_text [ exec lynx -dump $url ] - PSE
            if {[catch {exec $env(BROWSER) -remote $url}]} {
                # perhaps browser doesn't understand -remote flag
                if {[catch {exec $env(BROWSER) $url &} emsg]} {
                    error "Error displaying $url in browser\n$emsg"
                # Another possibility is to just pop a window up
                # with the URL to visit in it. - DKF
                }
            }
        }
    }
}

# Provide multipart/form-data for http

 package provide form-data 1.0
 namespace eval form-data {}

 proc form-data::compose {partv {type multipart/form-data}} {
     upvar 1 $partv parts

     set mime [mime::initialize -canonical $type -parts $parts]
     set packaged [mime::buildmessage $mime]
     foreach part $parts {
 	mime::finalize $part
     }
     mime::finalize $mime

     return $packaged
 }

 proc form-data::add_binary {partv name filename value type} {
     upvar 1 $partv parts
     set disposition "form-data; name=\"${name}\"; filename=\"$filename\""
     lappend parts [mime::initialize -canonical $type \
 		   -string $value \
 		   -encoding binary \
 		   -header [list Content-Disposition $disposition]]
 }

 proc form-data::add_field {partv name value} {
     upvar 1 $partv parts
     set disposition "form-data; name=\"${name}\""
     lappend parts [mime::initialize -canonical text/plain -string $value \
 		       -header [list Content-Disposition $disposition]]
 }

 proc form-data::format {name filename value type args} {
     set parts {}
     foreach {n v} $args {
 	add_field parts $n $v
     }
     add_binary parts $name $filename $value $type
     return [compose parts]
 }

# This opens the file selctor to get a model description in XML format, then
# sends it to the WebFlow service to convert it to Prolog and puts that in a
# temporary file. What about ttfn conversion? None done yet.
proc TradeXML {c exp} {
    global window_info simtmpdir preSelect

    package require http
    set mdl $window_info($c,top_node)
    if {$exp} {
	set service pl_to_xml
	set srcFile [set preSelect [file join $simtmpdir temp_out.pl]]
	MenuSelect $c file export_prolog
	set appTail simile
    } else {
	set service xml_to_pl
	set srcFile [ChooseFile model.xml \
			 [tr. "XML model description to import:"] 0 $mdl]
	if {![string length $srcFile]} {return 0}
	set appTail xml
    }
    set strm [NetOpen $srcFile r]
    set content [read $strm]
    close $strm

# ...what follows owes much to http://wiki.tcl.tk/13675
     # format the file and form
     set message [form-data::format in_file [file tail $srcFile] \
			    $content application/x-$appTail]

     # parse the headers out of the message body because http get url wants
     # them as a separate parameter
     set headerEnd [string first "\r\n\r\n" $message]
     incr headerEnd 1
     set bodystart [expr $headerEnd + 3]
     set headers_raw [string range $message 0 $headerEnd]
     set body [string range $message $bodystart end]
     set headers_raw [string map {"\r\n " " " "\r\n" "\n"} $headers_raw]
     regsub {  +} $headers_raw " " headers_raw

     foreach line [split $headers_raw "\n"] {
         regexp {^([^:]+): (.*)$} $line all label value
         lappend headers $label $value
     }

     # get the content-type
     array set ha $headers
     set content_type $ha(Content-Type)
     unset ha(Content-Type)
     set headers [array get ha]

     # POST it
    OpenProgressBox $c
    FillProgressBox wait_for_web {}
    set url http://webflow.simileweb.com/processes/$service/
    if {[catch {::http::geturl $url -type $content_type -binary true \
		    -headers $headers -query $body} token]} {
	CloseProgressBox
	Query [list web_fail $token] warning top $c ok
	return
    }
    ::http::wait $token
    CloseProgressBox

    upvar #0 $token foo
    if {![string equal "HTTP/1.1 200 OK" $foo(http)]} {
	Query xml_trade_fail warning top $c ok
	return
    }
    if {$exp} {
	set destFile [ChooseFile model.xml \
			 [tr. "XML model description to export:"] 1 $mdl]
	if {![string length $destFile]} {return 0}
    } else {
	set destFile [set preSelect [file join $simtmpdir temp_in.pl]]
    }
    set strm [NetOpen $destFile w]
    puts $strm $foo(body)
    close $strm
    if {$exp} {return 0}
    MenuSelect $c file import
}

proc CheckHyper {ywhat} {
    return 0
}

proc GoHyper {ywhat} {
    ShowMess debug info $ywhat ok
}

proc ResolveHyper {args} {
    ShowMess debug info "Resolving $args" ok
    return {}
}

proc ErrorHelp {diagnostic} {
    global diagno url help tcl_platform
    set parent [focus]
    PutItThere .diag $parent

    wm title .diag {Error diagnostics}
    wm protocol .diag WM_DELETE_WINDOW {set diagno(done) 0}
    labelframe .diag.errorf -text [tr. "Diagnostics:"]
    message .diag.errorf.errorm -text [tr. "Full text of the error report, as generated by the TclTk interpreter:"] -aspect 5000
    pack .diag.errorf.errorm -side top
    text .diag.errorf.e -yscrollcommand [list .diag.errorf.y set] -width 20 -height 8 -relief sunken -bd 2 -highlightthickness 0
    .diag.errorf.e insert 1.0 $diagnostic
    scrollbar .diag.errorf.y -command [list .diag.errorf.e yview]
    pack .diag.errorf.e -fill both -expand true -side left  -padx 4 -pady 4
    pack .diag.errorf.y -side left -fill y
    pack .diag.errorf -fill both -expand true -padx 4 -pady 4
    
    labelframe .diag.topicsf -text [tr. "Help:"]
    message .diag.topicsf.errorm -text [tr. "The following relevant help topics were found.  Double-click a page title to view it."] -aspect 5000
    pack .diag.topicsf.errorm -side top -padx 4 -pady 4
    pack [listbox .diag.topicsf.l -width 20 -height 8] -fill both -expand on  -padx 4 -pady 4
    bind .diag.topicsf.l <ButtonRelease-1> {GetHelp}
    pack [button .diag.b -text [tr. OK] -width 10 \
	      -command {set diagno(done) 0}] -pady 4
    set diagno(keys) {}
    foreach key [array names help] {
        if {[regexp $key $diagnostic]} {
            lappend diagno(keys) $key
            .diag.topicsf.l insert end $url($help($key))
            pack .diag.topicsf -fill both -expand on  -padx 4 -pady 4
        }
    }
    LetItShow .diag diagno(done)
    unset diagno(done)
    PackItUp .diag
}

proc GetHelp {} {
    global SIMILE_PATH diagno help
    cd $SIMILE_PATH/help
    ContextSensitiveHelp .diag \
            $help([lindex $diagno(keys) [.diag.topicsf.l curselection]])
}

proc VisitUrl {x} {
    global env
    switch [tk windowingsystem] {
        win32 {
            set x [regsub -all -nocase {htm} $x {ht%6D}]
            exec rundll32 url.dll,FileProtocolHandler $x & 
        } aqua {
            exec open $x 
        } x11 {
            set url $x
            if {![info exists env(BROWSER)]} {
                foreach possBrowser {firefox konqueror mozilla netscape iexplorer lynx opera} {
                    set env(BROWSER) [lindex [auto_execok $possBrowser] 0]
                    if {[llength $env(BROWSER)]} {
                        break
                    }
                }
            }
            if {[catch {exec $env(BROWSER) -remote $url}]} {
                # perhaps browser doesn't understand -remote flag
                if {[catch {exec $env(BROWSER) $url &} emsg]} {
                    error "Error displaying $url in browser\n$emsg"
                }
            }
        }
    }
}

proc ShowAbout {winId} {
    global SIMILE_PATH sendvars userinfo interface tcl_platform graph
    PutItThere .about $winId
    wm title .about About\ Simile
    image create photo dripu
#    image create photo dripl
    dripu read "$SIMILE_PATH/Images/HelpAboutUpper.gif"
#    dripl read "../Images/HelpAboutLower.gif"
    label .about.upper -image dripu
    pack .about.upper -pady 4
    frame .about.fr -relief sunken -borderwidth 2
    switch [tk windowingsystem] {
        aqua {
            set fSize 12; set fsSize 12
        } default {
            set fSize 8; set fsSize 8
        }
    }
    set fullVers $sendvars(simV)$sendvars(simP)
    pack [label .about.fr.lab1 -font "-family helvetica -size $fSize" \
	      -text "[tr. Simile] v$fullVers [tr. $userinfo(edn)], $::tclBitness-bit"]
# TRANSLATOR: $userinfo(edn) is one of:
# evaluation, teaching, standard, enterprise
    set platform [frame .about.fr.platform]
    pack [label $platform.prolog -text "Prolog: $sendvars(proV)" \
            -font "-family helvetica -size $fsSize"] -side left
    pack [label $platform.tcl -text "TclTk: [info patchlevel]" \
            -font "-family helvetica -size $fsSize"] -side left
    switch [tk windowingsystem] {
        win32 {
	    set gppVers [exec [file join $::execDir g++] -dumpversion]
            pack [label $platform.g++ \
		      -text "MinGW g++: $gppVers" \
		      -font "-family helvetica -size $fsSize"] -side left
        } aqua {
	    if {[package vcompare 14.0.0 $tcl_platform(osVersion)] > 0} {
		set gppVers [exec [file join $::execDir g++] -dumpversion]
	    } else {
		catch {exec g++ -dumpversion} gppVers
	    }
            pack [label $platform.g++ \
		      -text "XCode g++: $gppVers" \
		      -font "-family helvetica -size $fsSize"] -side left
	}
    }
    pack $platform
    if [info exists userinfo(exp_time)] {
        set edate [clock format $userinfo(exp_time) -format {%d %h %Y}]
        set expf [frame .about.fr.expf]
        pack [label $expf.lab1 -text [tr. "This product expires on"] \
            -font "-family helvetica -size $fsSize"] -side left
        pack [label $expf.lab2 -text $edate -font "-family helvetica -size $fsSize"] -side left
        pack $expf
    }
    set curVers [GetLatestVers]
    if {$curVers} {
	pack [label .about.fr.lab3 -text [format [tr. {Latest available version is %1$s}] $curVers]]
    }
    pack [label .about.fr.lab4 -text "[tr. {This product is registered to}]\
            $userinfo(name), $userinfo(corp)" \
            -font "-family helvetica -size $fsSize"]
    
    set gen [frame .about.fr.gen]
    switch -regexp $userinfo(edn) {
        evaluation {
	    set service [tr. {For upgrade to Standard, please visit}]
        } standard|teaching {
	    set service [tr. {For support or to upgrade, please visit}]
        } enterprise {
            set service [tr. {For support, please visit}]
        }
    }
    pack [label $gen.visit -text $service \
	      -font "-family helvetica -size $fsSize"] -side left
    pack [label $gen.www -text www.simulistics.com -relief flat \
            -font "-underline true -family helvetica -size $fsSize" -fg blue -cursor hand2] -pady 2 -side left
    bind $gen.www <Button-1> "VisitUrl http://www.simulistics.com/"
    pack $gen -padx 4 -pady 2
    pack .about.fr -expand on -fill x -padx 8 -pady 2
    
#    label .about.lower -image dripl
#    pack .about.lower
    
    pack [label .about.low1 -text [tr. Simile] -font $graph(megafont)]
    pack [label .about.low2 -text $graph(anality) -font $graph(font)]
    pack [button .about.b -text [tr. OK] -width 10 -default active \
            -command "set sendvars(doneAbout) 1"] -pady 2
    pack [label .about.l16]
    LetItShow .about sendvars(doneAbout)
    PackItUp .about
}

proc GetLatestVers {} {
    package require http
    if {[catch {::http::geturl http://www.simulistics.com/cgi-bin/products/current-version.php -timeout 2500} token]} {
	return 0
    }
    upvar #0 $token versReq
    if {$versReq(status) eq "ok"} {
	array set versInfo $versReq(body)
	return $versInfo(simileVerNo)
    } else {
	return 0
    }
}
# images must be global because if building a c++ program we may be in a different directory
#set bwVers [package require BWidget]

proc ShowExpiryImminent {expTime left} {
    toplevel .expiry
    #    wm transient .expiry $winId
    if {$left<0} {
	wm title .expiry "Expiry passed"
    } else {
	wm title .expiry "Expiry imminent"
    }
    wm protocol .expiry WM_DELETE_WINDOW {set ack 1}

    global tcl_platform
    switch [tk windowingsystem] {
        win32 {wm attributes .expiry -toolwindow true}
    }
    
    set labf1 [frame .expiry.labf1]
    pack [label $labf1.img -image $::iconImages(warning)] -side left
    pack [label $labf1.lab1 -text "Warning:" \
            -font {-weight bold -family helvetica -size 10}] -side left
    if {$left<0} {
	set predicament "has expired."
    } else {
	set predicament "will shortly expire."
    }
    pack [label $labf1.lab2 -text "This product $predicament" \
            -font {-family helvetica -size 10}] -side left
    pack $labf1 -padx 8 -pady 2
    
    set curVers [GetLatestVers]
    if {$curVers} {
	pack [label .expiry.lab2a -text [format [tr. {Latest available version is %1$s}] $curVers]]
    }

    set labf2 [frame .expiry.labf2]
    pack [label $labf2.lab1 -text "Please visit" -font {-family helvetica -size 10}] -side left
    pack [set www [label $labf2.lab2 -text "www.simulistics.com" \
            -fg blue -cursor hand2 -font {-underline true -family helvetica -size 10}]] -side left
    bind $www <Button-1> {VisitUrl "http://www.simulistics.com/"}
    if {$left<0} {
    } else {
    pack [label $labf2.lab3 -text "before" -font {-family helvetica -size 10}] -side left
    pack [label $labf2.lab4 -text [clock format $expTime -format {%d %h %Y}] \
            -font {-family helvetica -size 10}] -side left
    }
    pack [label $labf2.lab5 -text "to upgrade." -font {-family helvetica -size 10}] -side left
    pack $labf2 -padx 8 -pady 2
    
    set buttons [frame .expiry.buttons]
    pack [button $buttons.ok -text [tr. OK] -width 10 \
            -command {set ack 1}] \
            -side left -padx 4 -pady 4
    pack [button $buttons.help -text [tr. Help] -width 10 \
            -command {ContextSensitiveHelp .expiry coviewexpiry.htm}] \
            -side left -padx 4 -pady 8
    pack $buttons
    
    set height [winfo reqheight .expiry]
    set width [winfo reqwidth .expiry]
    set sheight [winfo screenheight .expiry]
    set swidth [winfo screenwidth .expiry]
    wm geometry .expiry +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    wm withdraw .splash
    update
    
    tkwait variable ack
    destroy .expiry
}

proc TrackSize {canvas item} {
    $canvas itemconfig $item -width [winfo width $canvas]
    $canvas itemconfig $item -height [winfo height $canvas]
}

############################################## Equation listing
proc equationlisting_start {DefEquationListingFileName topNode} {
    global equationlist tcl_platform DefaultEquationListingFileName
    set DefaultEquationListingFileName $DefEquationListingFileName
    set w .equations
    catch {destroy $w}
    toplevel $w -height 600 -width 800
    wm title $w [tr. {Equation listing}]
    
    if [string match "Darwin" $tcl_platform(os)] {
        set accKey Cmd
        set accSym Command
        #set fm [menu ${winid}top.apple -tearoff 0]
        #$fm delete 0 7
        #$fm add command -label "About Simile..." -command "ShowAbout $winid"
        #${winid}top add cascade -menu $fm
    } else {
        set accKey Ctrl
        set accSym Control
    }
    set m [menu $w.topMenu -tearoff 0]
    
    set fm [menu $w.fileMenu -tearoff 0]
    $m add cascade -label [tr. File] -underline 0 -menu $fm
    $fm add command -label [tr. Save] -command "EquationListingSave $w $topNode" \
            -accelerator "$accKey+S"
    $fm add separator
#    if {[string match windows $tcl_platform(platform)]} {
        $fm add command -label [tr. Print] -command "EquationListingPrint $w" \
                -accelerator "$accKey+P"
#    }
    $fm add separator
    $fm add command -label [tr. Close] -command "destroy $w"
    UnderlineUniquely $fm
    
    set fm [menu $w.editMenu -tearoff 0]
    $m add cascade -label [tr. Edit] -underline 0 -menu $fm
    $fm add command -label [tr. "Select All"] \
            -command {EquationListingSelectAll $equationlist(textbox)} \
            -accelerator "$accKey+A"
    $fm add command -label [tr. Copy] -command {tk_textCopy $equationlist(textbox)} \
            -accelerator "$accKey+C"
    #        $fm add command -label "Find" \
    #                -command "EquationListingFindPopup $w" \
    #        -accelerator "$accKey+F"
    UnderlineUniquely $fm
    UnderlineUniquely $m
    $w configure -menu $m    
    
    frame $w.mainframe
    pack $w.mainframe -fill both -expand true

    set wrapper [canvas $w.mainframe.c]
    set equationlist(textbox) [text $w.mainframe.textbox \
            -tabs {1c} -relief sunken -bd 2 -highlightthickness 0 \
	    -yscrollcommand [list $w.mainframe.scrl set]]
    scrollbar $w.mainframe.scrl -command [list $equationlist(textbox) yview]
    pack $w.mainframe.scrl -side right -fill y
    pack $wrapper -side right -fill both -expand true
    set ww [$wrapper create window 0 0 -anchor nw \
		-window $equationlist(textbox)]
    bind $wrapper <Configure> [list TrackSize $wrapper $ww]
    
    $equationlist(textbox) tag configure bigtag \
            -font {Helvetica 12 bold} -wrap word -spacing3 5 -lmargin1 10 -lmargin2 10
    $equationlist(textbox) tag configure descrtag \
            -font {Helvetica 10} -wrap word -lmargin1 10 -lmargin2 45
    $equationlist(textbox) tag configure cmttag \
            -font {Helvetica 10} -wrap word -lmargin1 0 -lmargin2 75
    $equationlist(textbox) tag configure whrtag \
            -font {Helvetica 10 italic} -wrap word -lmargin1 0 -lmargin2 75
    $equationlist(textbox) tag configure eqntag \
            -font {Helvetica 10 bold} -wrap char -lmargin1 5 -lmargin2 45
    $equationlist(textbox) tag configure typtag \
            -font {Helvetica 10} -wrap word -lmargin1 5 -lmargin2 45
    $equationlist(textbox) tag configure initag \
            -font {Helvetica 10} -wrap char -lmargin1 10 -lmargin2 10
    $equationlist(textbox) tag configure dummytag \
            -font {Helvetica 5}
    
    bind $w <Control-a>  {EquationListingSelectAll $equationlist(textbox)}
    $w configure -height 600 -width 800
    focus $equationlist(textbox)
}

# unused for now
proc EquationListingFindPopup {winId} {
    
    global seltxt repltxt
    
    set t [toplevel .equationListingFindpop -width 10c -height 4c]
    
    grab $t
    wm title $t "Find Text"
    
    
    label $t.lab1 -text "Find :           "
    place $t.lab1 -in $t -x 2 -y 6
    entry $t.en1 -width 20 -relief sunken -textvariable seltxt
    place $t.en1 -in $t -x 72  -y 6
    
    menubutton $t.finb -text "Find" -menu $t.finb.menu
    place $t.finb -in $t -x 2 -y 90
    menu $t.finb.menu
    $t.finb.menu add command -label Forward -command {FindWord  -forwards $seltxt}
    $t.finb.menu add command -label Backward -command {FindWord -backwards $seltxt}
    
    button $t.tagall -text "Find next" -command {Find}
    place $t.tagall -in $t -x 250 -y 36
    
    button $t.dismis -text Cancel -command [namespace code "destroy $t"]
    place $t.dismis -in $t -x 250 -y 90
    
    
    focus $t.en1
}

proc EquationListingSelectAll {winId} {
    $winId tag add sel 1.0 end
}


proc equationlisting_addsubmodel {node isub submodel_label timestep type} {
    global equationlist custom
    $equationlist(textbox) configure  -state normal
    
    set widget $equationlist(textbox)
    
    # toplevel
    if {$isub == 1} {
        $widget insert end "\n"
        $widget insert end [format [tr. {Model %1$s}] \
				[BlankCrs $submodel_label]] bigtag
    } else  {
        $widget insert end "\n"
        $widget insert end [format [tr. {Submodel %1$s}] \
				[BlankCrs $submodel_label]] bigtag
    }
    
    # Label and Description, if any
    set description [GetFromProlog tk_get_info(dummy,$node,desc)]
    if [string match null $description] {
    } else  {
        $widget insert end " : ${description}\n" descrtag
    }
    $widget insert end "\n"
    
    # type of submodel and dimensions if approp
    if {![string match "" $type]} {
        $widget insert end "\t$type\n" cmttag
    }
    
    AddComments $widget $node
    
    # time step index
    if {![string match null $timestep]} {
        $widget insert end "\t[tr. {Time step index:}] $timestep\n" cmttag
    }
    
    # enumerated types
################################################################################
#     if {[llength $enumtypes] > 0} {
#         foreach {et} [lindex $enumtypes 0] {
#             $widget insert end "\tEnumerated types: $et\n" cmttag
#        }
#     }
################################################################################
    if {[PrefValue custom(eqListETDefns) eqListETDefns]} {
	set enumtypes [GetFromProlog tk_get_info(dummy,$node,enum_type_defns)]
	if {![string match {} $enumtypes]} {
	    $widget insert end "\t[tr. {Enumerated types:}] ${enumtypes}\n" cmttag
	}
    }
    $equationlist(textbox) configure -state disabled
    update idletasks
}


proc equationlisting_addvariable {node vartype varlabel expression minmax \
            inflows outflows} {
    #puts "inflows $inflows outflows $outflows"
    # tabs (\t) used as well as margins to provide some formatting to text copied and pasted to other apps
    global equationlist custom
    #ShowMess debug info "$comments" ok
    
    set widget $equationlist(textbox)
    $equationlist(textbox) configure  -state normal
    $widget insert end " \n" dummy
    
    #puts "equationlisting_addvariable $varlabel $vartype $inflows $outflows $where"
    
    $widget insert end "[tr. [string totitle ${vartype}]] " typtag
# TRANSLATOR: see note at definition of imgType above
    $widget insert end " " descrtag
    $widget image create end -image $::iconImages($vartype)
    $widget insert end " " descrtag
    
    set tidy_varlabel [regsub -all "\n" $varlabel " "]
    if {[lsearch -exact {{Fixed parameter} {Variable parameter}} \
	     $expression]>-1} {
	set tidy_expression [tr. $expression]
# TRANSLATOR: $expression is one of {Fixed parameter} {Variable parameter}
    } else {
	set tidy_expression [regsub -all "\n" $expression "\n\t\t\t"]
    }
    set description [GetFromProlog tk_get_info(dummy,$node,description)]
    set tidy_description [regsub -all {\n} $description { }]

    # Label and Description, if any
    if [string match null $description] {
        $widget insert end "${tidy_varlabel}\n" eqntag
    } else  {
        $widget insert end "${tidy_varlabel}" eqntag
        $widget insert end " : ${tidy_description}\n" descrtag
        
    }
    
    if {[string match compartment $vartype]} {
        # Compartment
        set inflows [string trim $inflows {[]}]
        set inflows [split $inflows ,]
        set outflows [string trim $outflows {[]}]
        set outflows [split $outflows ,]
        
        # intial value
        
        $widget insert end "\t[tr. {Initial value}]" eqntag
        $widget insert end " = " eqntag
        $widget insert end $tidy_expression eqntag
        $widget insert end "\n" eqntag
        
	AddWhereClauses $widget $node $minmax
        if {![string match {null} $minmax]} {
            $widget insert end "\t$minmax\n"
    }
        # ...rate equation
        if {[llength $outflows]>0 | [llength $inflows]>0} {
            set text_string "[tr. {Rate of change}] = "; #"d(${tidy_varlabel})/dt = "
            
            foreach inflow $inflows {
                set text_string "$text_string + $inflow"
            }
            foreach outflow $outflows {
                set text_string "$text_string - $outflow"
            }
            $widget insert end "\t$text_string\n" eqntag
        }
        
    } else  {
        # Everything except compartments
        $widget insert end "\t$tidy_varlabel = \t\t$tidy_expression \n" eqntag
        #$widget insert end "\t$tidy_varlabel = $expression \n" eqntag
        
	AddWhereClauses $widget $node $minmax
    }
    
    # Comments
    AddComments $widget $node
    $widget configure  -state disabled    
}

proc AddComments {widget node} {
    global custom
    if {![PrefValue custom(eqListComments) eqListComments]} {
	return
    }
    set commentText [GetFromProlog tk_get_info(dummy,$node,comment)]
    if {[string equal {} $commentText]} {
	return
    }
    set commentTidy [regsub -all "\n" $commentText "\n\t\t"]
    # keep line breaks but allign new lines with start of text
    $widget insert end "\t[tr. Comments:]\n\t\t$commentTidy \n" cmttag; 
    # should be empty if comments null
}

proc AddWhereClauses {widget node minmax} {
    global custom
    if {![PrefValue custom(eqListWhere) eqListWhere]} {
	return
    }
# old version got pre-built text and did this:
#        if ![string match {null} $where] {
#            $widget insert end "\tWhere:\n\t\t$tidy_where \n" whrtag; # tidy where should be empty if where null
            #add_text "Where:\n$tidy_where" {Helvetica 9 italic} 20 0 #008800
#        }
#        if {![string match {null} $minmax]} {
#            $widget insert end "\t$minmax\n"
#	}
    set paramData [GetFromProlog tk_get_params(dummy,$node)]
    if {[string length $paramData]} {
	$widget insert end "\t[tr. Where:]\n" whrtag
	foreach paramList $paramData {
	    set paramName [lindex $paramList 1]
	    $widget insert end "\t\t$paramName = [DescribeInputParam [lindex $paramList 0]]\n" whrtag
	}
    }
    if {![string match {null} $minmax]} {
	$widget insert end "\t$minmax\n"
    }
}

proc EquationListingSave {winId topNode} {
    global equationlist DefaultEquationListingFileName

    set fname [ChooseFile $DefaultEquationListingFileName \
		   [tr. "Save equation listing as:"] 1 $topNode]
    if {![string match "" $fname]} {
        set f [open $fname w]
        puts $f [$equationlist(textbox) get 1.0 end]
        close $f
    }
}

proc EquationListingPrint {winId} {
    global env tcl_platform
    global printargs equationlist
    
    if {[string match windows $tcl_platform(platform)]} {
        set oldDir [pwd] ;# apparently printing can change directory
        package require gdi
        package require printer
        
        set hdc [printer dialog select]
        if { [lindex $hdc 1] == 0 } {
            # User has canceled printing
            return
        }
        set printargs(hDC) [ lindex $hdc 0 ]
        
        print_data [$equationlist(textbox) get 1.0 end]
        cd $oldDir
    } else {
	PrintRandomCanvas [winfo parent $equationlist(textbox)].c
	# cant do this under Windows cos the prntcanv cmd doesnt support
	# embedded windows
    }
}

proc add_text {text font across down colour} {
    global equationlist
    set ydown [expr [lindex [$equationlist(canvas) bbox textitem] 3] + $down]
    $equationlist(canvas) create text [expr $across+3] $ydown -text $text \
            -anchor nw -font $font -tags {textitem} -width 500 -fill $colour
}

############################################## End equation listing

# general error handling -- note that only user errors will be raised from
# execution interps, so the reporting stuff can be kept in the editor interp

proc NotifyOverLimit {win edn limit} {
    wm title [PutItThere .notify $win] "Over Limit For Edition"
    wm protocol .notify WM_DELETE_WINDOW {set ack 1}
    global tcl_platform
    switch [tk windowingsystem] {
    win32 {wm attributes .notify -toolwindow true}
    }
    
    set labf1 [frame .notify.labf1]
    pack [label $labf1.img -image $::iconImages(warning)] -side left
    pack [label $labf1.lab1 -text "Warning:" \
            -font {-weight bold -family helvetica -size 10}] -side left
    pack [label $labf1.lab2 -text "The $edn edition is limited to $limit functions. \n\
            You can continue to build and run this model, but\n\
            you will not be able to save it. " \
            -font {-family helvetica -size 10} -justify left] -side left
    pack $labf1 -padx 8 -pady 2
    
    set labf2 [frame .notify.labf2]
    pack [label $labf2.lab1 -text "Please visit" -font {-family helvetica -size 10}] -side left
    pack [set www [label $labf2.lab2 -text "www.simulistics.com" \
            -fg blue -cursor hand2 -font {-underline true -family helvetica -size 10}]] -side left
    bind $www <Button-1> {VisitUrl "http://www.simulistics.com/"}
    pack [label $labf2.lab5 -text "to upgrade." -font {-family helvetica -size 10}] -side left
    pack $labf2 -padx 8 -pady 2
    
    set buttons [frame .notify.buttons]
    pack [button $buttons.ok -text [tr. OK] -width 10 \
            -command {set ack 1}] \
            -side left -padx 4 -pady 4
    pack [button $buttons.help -text [tr. Help] -width 10 \
            -command {ContextSensitiveHelp .notify files/limit.htm}] \
            -side left -padx 4 -pady 8
    pack $buttons
    
    set height [winfo reqheight .notify]
    set width [winfo reqwidth .notify]
    set sheight [winfo screenheight .notify]
    set swidth [winfo screenwidth .notify]
    wm geometry .notify +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    LetItShow .notify ack
    PackItUp .notify
}

proc TtkLikeDialogue {dlg args} {
    upvar #0 $dlg D
    variable Config
    variable ButtonOptions
    variable DialogTypes

    # 
    # Option processing:
    #
    array set defaults {
	-title 		""
    	-message	""
	-detail		""
	-command	ttk::dialog::nop
	-icon 		""
	-buttons 	{}
	-labels 	{}
	-default 	{}
	-cancel		{}
	-parent		#AUTO
    }
    array set options [array get defaults]

    foreach {option value} $args {
	if {$option eq "-type"} {
	    array set options $DialogTypes($value)
	} elseif {![info exists options($option)]} {
	    set validOptions [join [lsort [array names options]] ", "]
	    return -code error \
	    	"Illegal option $option: must be one of $validOptions"
	}
    }
    array set options $args

    # ...
    #
#    array set buttonOptions [array get ::ttk::dialog::ButtonOptions]
    foreach {button label} $options(-labels) {
	lappend buttonOptions($button) -text $label
    }

    #
    # Initialize dialog private data:
    #
    foreach option {-command -message -detail} {
	set D($option) $options($option)
    }

#    toplevel $dlg -class Dialog; wm withdraw $dlg

    #
    # Determine default transient parent.
    #
    # NB: menus (including menubars) are considered toplevels,
    # so skip over those. 
    #
    if {$options(-parent) eq "#AUTO"} {
	set parent [winfo toplevel [winfo parent $dlg]]
	while {[winfo class $parent] eq "Menu" && $parent ne "."} {
	    set parent [winfo toplevel [winfo parent $parent]]
	}
	set options(-parent) $parent
    }

    #
    # Build dialog:
    #
 #   if {$options(-parent) ne ""} {
 #   	wm transient $dlg $options(-parent)
 #   }
PutItThere $dlg $options(-parent)

    wm title $dlg $options(-title)
    wm protocol $dlg WM_DELETE_WINDOW { }

    set f [ttk::frame $dlg.f] 

    ttk::label $f.icon 
    if {$options(-icon) ne ""} {
	$f.icon configure -image $::iconImages($options(-icon))
    }
    ttk::label $f.message -textvariable ${dlg}(-message) \
    	-font TkCaptionFont -wraplength 400 -anchor w -justify left
    ttk::label $f.detail -textvariable ${dlg}(-detail) \
    	-font TkTextFont -wraplength 400 -anchor w -justify left

    #
    # Command buttons:
    #
    set cmd [ttk::frame $f.cmd]
    set column 0
    grid columnconfigure $f.cmd 0 -weight 1

    foreach button $options(-buttons) {
	incr column
	eval [linsert $buttonOptions($button) 0 ttk::button $cmd.$button]
        $cmd.$button configure -command [list SetDlgRes $button]
    	grid $cmd.$button -row 0 -column $column \
	    -padx [list 6 0] -sticky ew
	grid columnconfigure $cmd $column -uniform buttons
    }

    if {$options(-default) ne ""} {
# global option invokes button with focus
#	bind $dlg <Return> [list $cmd.$options(-default) invoke]
	focus $cmd.$options(-default)
    }
    if {$options(-cancel) ne ""} {
	bind $dlg <KeyPress-Escape> \
	    [list event generate $cmd.$options(-cancel) <<Invoke>>]
	wm protocol $dlg WM_DELETE_WINDOW \
	    [list event generate $cmd.$options(-cancel) <<Invoke>>]
    }

    #
    # Assemble dialog.
    #
    pack $f.cmd -side bottom -expand false -fill x \
    	-pady [list 24 12] -padx 12

    if {0} {
	# GNOME and Apple HIGs say not to use separators.
	# But in case we want them anyway:
	#
	pack [ttk::separator $f.sep -orient horizontal] \
	    -side bottom -expand false -fill x \
	    -pady [list 24 0] \
	    -padx 12
    }

    if {$options(-icon) ne ""} {
	pack $f.icon -side left -anchor n -expand false \
	    -pady 12 -padx 12
    }

    pack $f.message -side top -expand false -fill x \
    	-padx 12 -pady 12
    if {$options(-detail) != ""} {
	pack $f.detail -side top -expand false -fill x \
	    -padx 12
    }

    # Client area goes here.

    pack $f -expand true -fill both
    wm deiconify $dlg
}

proc ChooseParent  {parent active} {
    if {[llength $active]} {set active [winfo toplevel $active]}
    if {![string length $parent] && [string length $active]>1 && \
	    [winfo viewable $active]} {
	set parent $active ;# window . is hidden so must not
    }
    return $parent
}

# New unified issue handler; use for any unexpected occurrence
proc Query {specifics icon helpRef parent opts} {
    global dialogues

    set defButton [lindex $opts 0]
    set defCapt $::msgs(${defButton}_button)
    switch $defButton {
	ok {set moreCapt [tr. "More info..."]}
	abort {set moreCapt [tr. "See all..."]}
	default {set moreCapt [tr. "More options..."]}
    }
    set key [lindex $specifics 0]
    set mBoxCmd [list TtkLikeDialogue .shortDlg -icon $icon -command SetDlgRes \
		     -buttons [list $defButton more] \
		     -default $defButton -cancel $defButton \
		     -labels [list $defButton $defCapt more $moreCapt]]
    foreach txtBit {title message detail full} {
	upvar #0 msgs(${key}_$txtBit) trans
	if {[info exists trans]} {
	    set $txtBit [eval format [list $trans] [lrange $specifics 1 end]]
	    if {![string equal full $txtBit]} {
		lappend mBoxCmd -$txtBit [set $txtBit]
	    }
	    if {$icon eq "error"} {
		append txtNotes " *** " [set $txtBit]
	    }
	}
    }
    if {![info exists title]} {
	set title [tr. "Internal error"]
	set message [tr. "Simile encountered an unexpected internal condition."]
	lappend mBoxCmd -title $title -message $message
	append message \n\n$specifics
    }

    if {[info exists dialogues(logText)]} { ;# messages skipped
	AddMsgsToLog
	if {[string equal abort $defButton]} {
	    return more
	} else {
	    return $defButton
	}
    }

    if {[info exists ::SimileAutoObjLoaded] || [winfo exists .shortDlg]} {
# Scripted execution or dialogue already displayed: return with no fuss
# (headless should get response from command line?)
# ...unless it's an error, in which case, throw and stop script.
	if {$icon eq "error" && \
		[lsearch {unhandled_tcl_error too_much_data} $key]==-1} {
	    error [list slip-up $txtNotes]
	} else {
	    puts $specifics
	    return $defButton
	}
    }
# not sure what this does, headles is always scripted
    if {$::headless} {
	foreach txtBit {title message detail full} {
	    if {[info exists $txtBit]} {
		puts [set $txtBit]
	    }
	}
	puts -nonewline "([join $opts /]): "
	flush stdout
	gets stdin resp
	if {$resp eq {}} {
	    set resp $defButton
	} 
	return $resp
    } 
    if {[winfo exists .splash]} {
	wm withdraw .splash ;# ensure mess is not obscured by splash screen
    }
    if {[winfo exists .popup]} {
	destroy .popup ;# avoid weird hang under Aqua, or at least try
    }
# This creates no end of trouble, e.g., re-creating the box does an update
# which breaks a 'see all', try just re-parenting the dialogues...
#    HideProgressBox

    set useParent [ChooseParent $parent [set oldFocus [focus]]] 
    lappend mBoxCmd -parent $useParent
    eval $mBoxCmd

# (in case Mac version siezes)
    if {[string equal abandon $key] && \
	    [string equal [tr. {Full dialogue}] \
		 [PrefValue custom(quickExit) quickExit]]} {
	set dialogues(done) more
    } else {
	LetItShow .shortDlg dialogues(done)
    }
    if {[string equal more $dialogues(done)]} {
	if {![string equal abort $defButton]} { ;# add more detail now
	    wm withdraw .shortDlg
	    set result [ExpandQuery $specifics $title $icon \
			    $message $helpRef $useParent $opts]
	} else { ;# "see all": display remaining messages together
	    AddMsgsToLog
	    set result $dialogues(done)
	    after idle [list StopMsgLogging $specifics $title $icon \
			    $helpRef $useParent ok]
	}
    } else {
	set result $dialogues(done)
    }
#    ReplaceProgressBox
    destroy .shortDlg
    unset dialogues(done)

    focus -force $oldFocus
#    update idletasks
    return $result
}


proc AddMsgsToLog {} {
    global dialogues

    upvar 1 message message
    lappend dialogues(logText) $message
    upvar 1 full full
    if {[info exists full]} {
	lappend dialogues(logText) ($full)
    }
    lappend dialogues(logText) {}
}

proc SetDlgRes {val} {
    global dialogues

    set dialogues(done) $val
}

# tweaked to cover any type of modal box -- remove progress box to stop Prolog
# calls clearing it
proc HideProgressBox {} {
    global dialogues

    set dialogues(progressUp) [grab current]
    if {[string length $dialogues(progressUp)]} {
	if {[string equal .progress $dialogues(progressUp)]} {
	    set dialogues(progBag) [wm transient .progress]
	    set dialogues(progMess) [.progress.message cget -text]
	    CloseProgressBox
	} else {
	    # avoid yet another potential MacOS stuffup
	    grab release $dialogues(progressUp)
	}
    }
    update ;# avoids Mac hang
}

proc ReplaceProgressBox {} {
    global dialogues

    if {[string length $dialogues(progressUp)]} {
	if {[string equal .progress $dialogues(progressUp)]} {
	    OpenProgressBox $dialogues(progBag)
	    .progress.message configure -text $dialogues(progMess)
	} else {
	    grab $dialogues(progressUp)
	}
    }
}

proc ExpandQuery {specifics Title errLevel msg context parent opts} {
    global help tcl_platform dialogues

    set ProbWin .bprob[clock clicks]
    PutItThere $ProbWin [ChooseParent $parent [set oldFocus [focus]]]

#    switch $fault {
#        user {
#            set Title "Problem with model"
#            set errLevel warning
#            set buttonCmd {ContextSensitiveHelp $ProbWin run/index.htm}
#        } system {
#            set Title "Build failure"
#            set errLevel error
#            set buttonCmd {ContextSensitiveHelp $ProbWin files/problem.htm}
#        } tcl {
#            set Title "User interface problem"
#            set errLevel error
#            set buttonCmd {ContextSensitiveHelp $ProbWin files/problem.htm}
#        }
#    }
    wm title $ProbWin $Title
    wm protocol $ProbWin WM_DELETE_WINDOW {set dialogues(ack) 1}
    switch [tk windowingsystem] {
        win32 {wm attributes $ProbWin -toolwindow true}
    }

    set labf1 [frame $ProbWin.labf1]
    pack [label $labf1.img -image $::iconImages($errLevel)] -side left 
#    pack [label $labf1.lab1 -text "Warning:" \
#            -font {-weight bold -family helvetica -size 10}] -side left
    pack [scrollbar $labf1.yscroll -orient v \
            -command [list $labf1.lab2 yview]] -side right -fill y
    pack [text $labf1.lab2 -width 80 -height 24 -relief sunken -bd 2 -highlightthickness 0 -wrap word -yscrollcommand [list AdjustCanvas $labf1 img y]] -fill both -expand on

    $labf1.lab2 insert 1.0 [tr. {Press "Help" to display a relevant page from Simile's documentation.}]

# boxes left up for now
#    if {[string equal .progress $dialogues(progressUp)]} {
#	$labf1.lab2 insert 1.0 \
#	    "Message in progress box was:\n$dialogues(progMess)\n\n"
#    }

    $labf1.lab2 insert 1.0 \n\n
    set key [lindex $specifics 0]
    foreach extra {full detail} {
	upvar #0 msgs(${key}_$extra) trans
	if {[info exists trans]} {
	    $labf1.lab2 insert 1.0 \n\n[eval format [list $trans] \
					    [lrange $specifics 1 end]]
	}
    }
    
    $labf1.lab2 insert 1.0 $msg
    $labf1.lab2 config -state disabled
    #    pack [label $labf1.lab2 -text $msg -wraplength 320 \
    #            -font {-family helvetica -size 10} -justify left] -side left
    pack $labf1 -padx 8 -pady 2 -fill both -expand on
    
    set buttons [frame $ProbWin.buttons]
    set ack1 -1
    set defButton [lindex $opts 0]
    set defCapt $::msgs(${defButton}_button)
    pack [button $buttons.bn$defButton -text $defCapt -width 20 \
	    -default active -command [list set dialogues(ack) [incr ack1]]] \
            -side left -padx 4 -pady 4
# global option invokes button with focus
#    bind $ProbWin <Return> [list $buttons.bn$defButton invoke]
    foreach extra [lrange $opts 1 end] {
        pack [button $buttons.bn$extra -text $::msgs(${extra}_button) \
	      -width 20 -command [list set dialogues(ack) [incr ack1]]] \
	    -side left -padx 4 -pady 4
    }
    pack [button $buttons.help -text Help -width 10 \
           -command "ContextSensitiveHelp $ProbWin $help($context)"] \
           -side right -padx 4 -pady 8
    pack $buttons -fill x
    
#    set height [winfo reqheight $ProbWin]
#    set width [winfo reqwidth $ProbWin]
#    set sheight [winfo screenheight $ProbWin]
#    set swidth [winfo screenwidth $ProbWin]
#    wm geometry $ProbWin +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    focus $ProbWin.labf1.lab2
    LetItShow $ProbWin dialogues(ack)
#    update
    PackItUp $ProbWin
    return [lindex $opts $dialogues(ack)]
}

proc StopMsgLogging {specifics title icon helpRef parent opts} {
    global dialogues

#    HideProgressBox
    ExpandQuery show_all "$title -- showing all" $icon \
		    [join $dialogues(logText) \n] $helpRef $parent $opts
    unset dialogues(logText)
#    ReplaceProgressBox
}
