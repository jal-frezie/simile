# Simile source code file: Run/forms.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for all dialogues except the equation,
# preferences and customise dialogues.
#
proc Disaggregate {parent title colour image imgpos type fatness icount step \
            comment enumLists eqnunit hide separate} {
    global disaggregate tcl_platform
    foreach varName {colour image imgpos type fatness \
                icount eqnunit hide separate} {
        set disaggregate($varName) [set $varName]
    }
    if [llength $icount]>0 {
        set disaggregate(icount) [join $icount ,]
    } else  {
        set disaggregate(icount) 1
    }
    #puts $disaggregate(icount)
    switch -- $step {
        -1 {
            set disaggregate(step) "Initialize only"
        } 0 {
            set disaggregate(step) "Reset only"
        } default {
            set disaggregate(step) $step
        }
    }
    set t [PutItThere .disaggregation $parent]
    wm resizable $t 0 1
    wm protocol $t WM_DELETE_WINDOW {set disaggregate(done) 0}
    wm title $t "Properties of [BlankCrs $title]"
    
    frame $t.simple
    frame $t.simple.left
    
    TitleFrame $t.simple.left.count -text "Control of number of instances:"
    set countf [$t.simple.left.count getframe]
    
    frame $countf.radio
    foreach rbutton {{population "Using population symbols"} {records "Using number of data records in file"} {generated "Using specified dimensions:"}} {
        radiobutton $countf.radio.$rbutton -text [lindex $rbutton 1] \
                -value [lindex $rbutton 0] \
                -variable disaggregate(type) \
                -command "SetHighlights $countf"
        pack $countf.radio.$rbutton -anchor w
    }
    pack $countf.radio -anchor w -side left
    
    ::ttk::entry $countf.value -textvariable disaggregate(icount) -width 10
    pack $countf.value -side left -anchor s -pady 4
    pack $t.simple.left.count -expand 0;# -fill both
    
    TitleFrame $t.simple.left.colour -text "Background shade"
    set colourf [$t.simple.left.colour getframe]
    set posRBs [frame $colourf.imageposns]
    pack [button $colourf.clear -text "Clear" -width 7 \
            -command "ClearBG $posRBs"] -padx 2 -pady 4 -side left
    pack [button $colourf.fixcolour -text "Colour..." \
            -width 7 -command "UpdateColour $colourf"]  \
            -padx 2 -pady 4 -side left
    $colourf.fixcolour configure -bg $disaggregate(colour)
    set disaggregate(defColour) $disaggregate(colour)
    pack [button $colourf.setimage -text "Image..." \
            -width 7 -command "ChooseImage $posRBs"] \
            -padx 2 -pady 4 -side left
    pack $posRBs -padx 2 -pady 4 -side left
    set rbState [ChooseText [string equal $disaggregate(image) none] \
            disabled normal]
    foreach rbutton {Tiled Centred Scaled} {
        pack [radiobutton $posRBs.ip$rbutton -text $rbutton -state $rbState \
                -value $rbutton -variable disaggregate(imgpos)] -anchor w
    }
    pack $t.simple.left.colour -anchor w -pady 4 -fill both -expand true
    pack $t.simple.left -side left; # -expand 1 -fill both
    
    frame $t.simple.right
    button $t.simple.right.ok -text "OK" -width 10 -default active \
            -command {set disaggregate(done) 1}
    pack $t.simple.right.ok  -padx 2 -pady 4
    button $t.simple.right.cancel -text "Cancel" -width 10 \
            -command {set disaggregate(done) 0}
    pack $t.simple.right.cancel -padx 2 -pady 4
    button $t.simple.right.help -text "Help" -width 10 \
            -command {ContextSensitiveHelp .disaggregation submodels/dialogue.htm}
    pack $t.simple.right.help -padx 2 -pady 4
    button $t.simple.right.more -text "More" -width 10 -command "ShowComplexity $t"
    pack $t.simple.right.more -padx 2 -pady 4
    pack $t.simple.right -anchor ne -padx 4 -pady 4
    
    pack $t.simple -anchor nw -fill both; # -expand 1 -fill both
    
    
    label $t.commentlabel -text Comments:
    pack $t.commentlabel -padx 2 -pady 4 -anchor w
    # ScrolledWindow causes crash under Linux so replaced with ordinary frame
    #    frame $t.commentsSW
    ScrolledWindow $t.commentsSW
    text $t.commentsSW.comment -height 4 -width 40 -relief sunken -bd 2 -highlightthickness 0 -wrap word
    $t.commentsSW setwidget $t.commentsSW.comment
    $t.commentsSW.comment insert 1.0 $comment
    pack $t.commentsSW -anchor nw -fill both -expand true
    
    frame $t.complex
    
    TitleFrame $t.complex.enumtypes -text "Enumerated types"
    set enumtypef [$t.complex.enumtypes getframe]
    pack [set canId [frame $enumtypef.listpair]] -side left -fill both \
            -expand true
    #    pack [frame $windowId.buttonframe] -side bottom
    # types (list box to keep selection highlighted when lost focus, -exportselection 0)
    set typef [frame $canId.typef]
    label $typef.lbl -text "Types" -anchor w
    listbox $typef.scrf -yscrollcommand [list AdjustCanvas $typef scrf y] \
            -exportselection 0
                
    foreach enumList $enumLists {
        set newType [lindex $enumList 0]
        set disaggregate(enumtype,$newType) [lrange $enumList 1 end]
        $typef.scrf insert end $newType
    }                
    # members (list box to keep selection highlighted when lost focus)
    set memf [frame $canId.memf]
    label $memf.lbl -text "Members" -anchor w
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
    
    pack [set btnId [frame $enumtypef.btns]] -side left
    pack [::ttk::entry $btnId.e -textvariable enumTypeMPEntry] -padx 2
    bind $btnId.e <ButtonRelease-1> "EnableTypeOps $enumtypef"
    pack [button $btnId.addtype -text "Add type" -command "AddEnumType $canId"] \
            -padx 2 -pady 4 -fill x
    pack [button $btnId.remtype -text "Remove type" -state disabled -command "RemoveEnumType $enumtypef"] \
            -padx 2 -pady 4 -fill x
    pack [button $btnId.addmems -text "Add member" -state disabled -command "AddEnumMem $enumtypef"] \
            -padx 2 -pady 4 -fill x
    pack [button $btnId.remmem -text "Remove member" -state disabled -command "RemoveEnumMem $enumtypef"] \
            -padx 2 -pady 4 -fill x
    pack [button $btnId.getmem -text "Get from file" -state disabled -command "GetEnumMems $enumtypef"] \
            -padx 2 -pady 4 -fill x
    pack $t.complex.enumtypes -anchor nw -side bottom -padx 4 -pady 4 -fill both -expand true
    
    TitleFrame $t.complex.appearance -text Appearance
    set appearancef [$t.complex.appearance getframe]
    checkbutton $appearancef.hide -text "Hide contents" \
            -variable disaggregate(hide)
    pack $appearancef.hide -anchor w
    frame $appearancef.scale
    scale $appearancef.scale.value -from .01 -to 1 -length 150 -orient horizontal \
            -resolution 0.01 -variable disaggregate(fatness)
    pack $appearancef.scale.value
    label $appearancef.scale.caption -text "Relative scale"
    pack $appearancef.scale.caption
    pack $appearancef.scale -anchor w
    pack $t.complex.appearance -anchor nw -side left -padx 4 -pady 4 -fill both -expand true
    
    TitleFrame $t.complex.math -text Calculation
    set mathf [$t.complex.math getframe]
    checkbutton $mathf.separate -text "Build submodel in separate dll" \
            -variable disaggregate(separate)
    pack $mathf.separate -anchor w
    #    checkbutton $mathf.matherror -text "Ignore math errors during calculation" \
    #            -variable disaggregate(matherror)
    #    pack $mathf.matherror -anchor w
    frame $mathf.eqnunit
    label $mathf.eqnunit.caption -text "Use units in math:"
    pack $mathf.eqnunit.caption -side left
    #tk_optionMenu $mathf.step.pulldown disaggregate(step) Default -1 0 1 2 3 4 5 6 7
    #::ttk::combobox $mathf.eqnunit.pulldown -textvariable disaggregate(eqnunit) \
    #        -values [list Default Yes No] \
    #        -width 10 -state readonly
    ::ttk::menubutton $mathf.eqnunit.pulldown -width 10 -textvariable disaggregate(eqnunit)
    set m [menu $mathf.eqnunit.pulldown.menu]
    foreach item [list Default Yes No] {
      $m add command -label $item -command "set disaggregate(eqnunit) $item"
    }
    $mathf.eqnunit.pulldown configure -menu $m
    pack $mathf.eqnunit.pulldown
    pack $mathf.eqnunit -anchor w -padx 4 -pady 6
    frame $mathf.step
    label $mathf.step.caption -text "Time step index:"
    pack $mathf.step.caption -side left
    #tk_optionMenu $mathf.step.pulldown disaggregate(step) Default -1 0 1 2 3 4 5 6 7
    #ComboBox $mathf.step.pulldown -textvariable disaggregate(step) \
    #        -values [list Default "Initialize only" "Reset only" 1 2 3 4 5 6 7] \
    #        -width 10 -state readonly
    ::ttk::menubutton $mathf.step.pulldown -width 10 -textvariable disaggregate(step)
    set m [menu $mathf.step.pulldown.menu] 
    foreach item [list Default {Initialize only} {Reset only} 1 2 3 4 5 6 7] {
      $m add command -label $item -command "set disaggregate(step) \"$item\""
    }
    $mathf.step.pulldown configure -menu $m
    pack $mathf.step.pulldown
    pack $mathf.step -anchor w -padx 4 -pady 6
    pack $t.complex.math -side left -padx 4 -pady 4 -fill both -expand true
    
    # The above "complex" frame has been constructed, but is not packed until the "More" button is pressed
    # unless, conditional expressions indicate that one of the complex attributes does not have its default
    # value
    #    pack $t.complex -anchor w
    if (![string match $disaggregate(step) Default]) {
        ShowComplexity $t
    } elseif (![string match $disaggregate(eqnunit) Default]) {
        ShowComplexity $t
    } elseif ($disaggregate(separate)) {
        ShowComplexity $t
    } elseif ($disaggregate(fatness)!=1.0) {
        ShowComplexity $t
    } elseif ($disaggregate(hide)) {
        ShowComplexity $t
    } elseif [info exists enumList] {
        ShowComplexity $t
    }
    
    SetHighlights $countf
    
    LetItShow $t
    grab $t
    tkwait variable disaggregate(done)
    grab release $t
    set disaggregate(comment) [string trimright [$t.commentsSW.comment get 1.0 end]]
    PackItUp $t

    set icount {}
    if [string compare $disaggregate(icount) 1] {
        foreach newIndex [split $disaggregate(icount) ,] {
            if {[string is double $newIndex] || \
                        [string match size(*) $newIndex]} {
                lappend icount $newIndex
            } else {
                lappend icount \"$newIndex\"
            }
        }
        set icount [join $icount ,]
    }
    if {$disaggregate(done)} {
        switch $disaggregate(step) {
            "Initialize only" {
                set step -1
            } "Reset only" {
                set step 0
            } default {
                set step $disaggregate(step)
            }
        }
        set enumTypes {}
        foreach {typename members} [array get disaggregate enumtype,*] {
            lappend enumTypes [concat [list [string range $typename 9 end]] \
                    $members]
        }
        set result [list $disaggregate(colour) $disaggregate(image) \
                $disaggregate(imgpos) $disaggregate(type) \
                $disaggregate(fatness) $icount \
                $step $disaggregate(comment) \
                $disaggregate(eqnunit) $disaggregate(hide) \
                $disaggregate(separate) $enumTypes]
    } else {
        set result {}
    }
    unset disaggregate
    return $result
}

proc ShowComplexity {t} {
    if {[string match [$t.simple.right.more cget -text] More]} {
        pack $t.complex -anchor sw -side bottom
        wm geometry $t {}; # resize to size requested internally by its widgets
        $t.simple.right.more configure -text Less
    } else  {
        pack forget $t.complex
        $t.simple.right.more configure -text More
    }
}

proc ClearBG {posRBs} {
    global disaggregate
    set disaggregate(colour) {}
    set disaggregate(image) {}
    set disaggregate(imgpos) none
    foreach button [winfo children $posRBs] {
        $button configure -state disabled
    }
}

proc OldAddEnumType {fr} {
    global addenumtype tcl_platform
    PutItThere .typeadder $fr
    pack [frame .typeadder.what]
    pack [label .typeadder.what.l -text Name:] -side left
    pack [entry .typeadder.what.e -textvariable addenumtype(name)] -side left
    pack [frame .typeadder.btns]
    pack [button .typeadder.btns.ok -text OK \
            -command "set addenumtype(done) 1"] -side left
    pack [button .typeadder.btns.cancel -text Cancel \
            -command "set addenumtype(done) 0"] -side left
    grab .typeadder
    tkwait variable addenumtype(done)
    grab release .typeadder
    if {$addenumtype(done)} {
        $fr.scrf insert end $addenumtype(name)
    }
    PackItUp .typeadder
}

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
        EnableTypeOps [[winfo parent [winfo parent $fr]]  getframe]
        set disaggregate(enumtype,$enumTypeMPEntry) {}
        [winfo parent $fr].btns.e delete 0 end
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
    }
}

proc AddEnumTypePopup {lb y X Y} {
    global disaggregate
    set popLine [$lb get [$lb nearest $y]]
    set memList disaggregate(enumtype,$popLine)
    if {[info exists $memList]} {
        AddWidgetPopup "members: [set $memList]" $X $Y
    }
}

proc CheckForETDuplicates {new} {
    global disaggregate enumTypeMPEntry
    if {![info exists enumTypeMPEntry] || ![llength $enumTypeMPEntry]} {
        ShowMessage "No $new name" error \
                "You must enter a name for the new $new in the box." ok
        return 0
    }
    if {[string equal NULL $enumTypeMPEntry]} {
        ShowMessage "Bad $new name" error \
                "NULL is reserved for the value of a variable when it is not equal to any member of its type." ok
        return 0
    }
    set def [GetFromProlog tk_get_info({},'$enumTypeMPEntry',is_unit)]
    if {![string equal none $def]} {
        ShowMessage "Bad $new name" error \
                "This name corresponds to a physical unit (defined as $def)." ok
        return 0
    }
    foreach {type members} [array get disaggregate enumtype,*] {
        set oldType [string range $type 9 end]
        if {[string equal $enumTypeMPEntry $oldType]} {
            ShowMessage "Bad $new name" error \
                    "This submodel already has an enumerated type of this name." ok
            return 0
        }
        if {[lsearch $members $enumTypeMPEntry] != -1} {
            ShowMessage "Bad $new name" error \
                    "The enumerated type $oldType in this submodel already contains a member of this name." ok
            return 0
        }
    }
    return 1
}

proc RemoveEnumMem {fr} {
    #    tk_popup $fr.curmembers [winfo pointerx $fr] [winfo pointery $fr]
    global disaggregate
    
    if {[$fr.listpair.memf.mem curselection] ne {} } {
        set togo [$fr.listpair.typef.scrf get [$fr.listpair.typef.scrf curselection]]
        #ShowMessage debug info "togo $togo $disaggregate(enumtype,$togo)" ok
        set index [lsearch $disaggregate(enumtype,$togo) \
                [$fr.listpair.memf.mem get [$fr.listpair.memf.mem curselection] ] ]
        set disaggregate(enumtype,$togo) \
                [lreplace $disaggregate(enumtype,$togo) $index $index]
        $fr.listpair.memf.mem configure -listvariable disaggregate(enumtype,$togo)
    }
}

proc GetEnumMems {fr} {
    global table_entry
    set togo [$fr.listpair.scrf get [$fr.listpair.scrf curselection]]
    upvar \#0 disaggregate(enumtype,$togo) memList
    set table_entry(data) {} ;# dont try to keep file origins
    set table_entry(values) {}
    for {set pos 0} {$pos < [llength $memList]} {incr pos} {
        lappend table_entry(values) [expr $pos+1] \
                [list [lindex $memList $pos]]
    }
    if {[equationDoTable .disaggregation "enumerated type" 1]} {
        set fileState [list $table_entry(fileName) $table_entry(dataField)]
        set fileData $table_entry(values)
        foreach {pos mem} $fileData {
            set mem [lindex $mem 0]
            if {[lsearch $memList $mem]==-1} {
                lappend memList $mem
            }
        }
    }
    EnableTypeOps $fr
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

proc UpdateColour {f} {
    global disaggregate
    
    set new [tk_chooseColor \
            -initialcolor $disaggregate(defColour)]
    if {[llength $new]} {
        set disaggregate(colour) $new
        set disaggregate(defColour) $new
        $f.fixcolour configure -bg $new
    }
}

package require Img

proc ChooseImage {posRBs} {
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
        set new [ChooseFile image.gif {Image for model background} 0]
        if {[llength $new]} {
            if {![catch {$newImage read $new -shrink} readFlop]} {
                if {![llength $readFlop]} {
                    set readFlop [string range [file extension $new] 1 end]
                }
                $newImage config -format $readFlop
                set disaggregate(image) $newImage
                PutSize $newImage
                set choosing 0
                foreach button [winfo children $posRBs] {
                    $button configure -state normal
                }
                if {[string equal none $disaggregate(imgpos)]} {
                    set disaggregate(imgpos) Tiled
                }
            } else {
                ShowMessage {Problem loading file} error $errorInfo ok
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
        none|population {
            $t.value configure -state disabled
        }
        simple|generated {
            $t.value configure -state normal
        }
    }
}

proc OpenProgressBox {winId} {
    PutItThere .progress $winId
    wm title .progress "Progress with current operation"
    pack [frame .progress.filler -width 400 -height 100]
    if {[LetItShow .progress]} {
    grab .progress
    }
    destroy .progress.filler
    wm geometry .progress 400x100
    message .progress.message -aspect 400 -text "Please wait"
    pack .progress.message -fill both -expand true
    update
}

proc CloseProgressBox {} {
    grab release .progress
    PackItUp .progress
}

proc RelationCheck {parent title type state init_comment} {
    global relation tcl_platform
    
    set t [PutItThere .relcheck $parent]
    wm resizable $t 0 0
    wm protocol $t WM_DELETE_WINDOW {set relation(done) 0}
    wm title $t "Properties of [BlankCrs $title]"
    frame .relcheck.top
    TitleFrame .relcheck.top.left -text "[string toupper $type 0 0] options:"
    set f [.relcheck.top.left getframe]
    
    switch $type {
        influence {
            set entries {"Use values made\nin same time step" use_sofar}
        set helpPage elements/influence.htm
        } relation {
            set entries {"Exclusive role" exclusive \
                        "Allow base\ninstance lookup" can_lookup}
        set helpPage submodels/association/dialogue.htm
        }
    }
    foreach {text attr} $entries {
        pack [checkbutton $f.$attr -text $text \
                -variable relation($attr) -offvalue 0 -onvalue 1] -anchor w
        set relation($attr) [lindex $state 0]
        set state [lrange $state 1 end]
        if {$relation($attr)==-1} {
            $f.$attr configure -state disabled
        }
    }
    pack .relcheck.top.left -side left -padx 4 -pady 4 -expand on -fill both -anchor nw
    frame .relcheck.top.right
    pack [button .relcheck.top.right.bdone \
            -text OK -width 10 -command {set relation(done) 1}] -padx 4 -pady 4
    pack [button .relcheck.top.right.bc \
            -text Cancel -width 10 -command {set relation(done) 0}] -padx 4 -pady 4
    pack [button .relcheck.top.right.help \
            -text Help -width 10 -command "ContextSensitiveHelp .relcheck $helpPage"] -padx 4 -pady 4
    pack .relcheck.top.right -side left
    pack .relcheck.top -expand on -fill both
    TitleFrame .relcheck.bottom -text "Comments:"
    set f [.relcheck.bottom getframe]
    pack [text $f.comment -width 40 -height 4 -relief sunken -bd 2 -highlightthickness 0 -wrap word] \
            -anchor w -expand on -fill both -padx 2 -pady 2
    $f.comment delete 1.0 end
    $f.comment insert 1.0 $init_comment
    pack .relcheck.bottom
    
    LetItShow .relcheck
    grab .relcheck
    tkwait variable relation(done)
    grab release .relcheck
    set newComment [string trimright [$f.comment get 1.0 end]]
    PackItUp .relcheck
    set results [list $relation(done) $newComment]
    foreach {text attr} $entries {
        lappend results $relation($attr)
    }
    return $results
}

set find(prevs) {}

proc GetFindText {parent} {
    global find tcl_platform
    set t [PutItThere .findentry $parent]
    wm protocol $t WM_DELETE_WINDOW {set find(done) 0}
    wm title $t "Find"
    wm resizable $t 0 0
    set ft [frame .findentry.ft]
    pack [message $ft.m -text "Find text:" -width 300] -padx 4 -pady 6 -anchor nw -side left
    pack [ComboBox $ft.e -width 40 -values $find(prevs) -editable 1] \
    -padx 4 -pady 6 -anchor nw -side left
    $ft.e bind <Return> "set find(done) 1"
    pack .findentry.ft -anchor nw -fill both
    TitleFrame .findentry.rbs -text "Search for text in"
    set rbs [.findentry.rbs getframe]
    set find(where) caption
    radiobutton $rbs.r1 -text "Captions" -variable find(where) -value caption
    radiobutton $rbs.r2 -text "Equations" -variable find(where) -value equation
    radiobutton $rbs.r3 -text "Descriptions and comments" \
            -variable find(where) -value description
    pack $rbs.r1 -anchor nw
    pack $rbs.r2 -anchor nw
    pack $rbs.r3 -anchor nw
    pack $rbs -anchor nw -fill both -padx 4 -pady 4
    pack .findentry.rbs -anchor nw -fill both
    pack [set bs [frame .findentry.buttframe]]
    #pack [button $bs.clear -text Clear -width 10 -command ".findentry.e delete 0 end"] -padx 2 -pady 2 -side left
    pack [button $bs.ok -text OK -default active -width 10 -command "set find(done) 1"] -padx 2 -pady 4 -side left
    pack [button $bs.cancel -text Cancel -width 10 -command "set find(done) 0"] -padx 2 -pady 4 -side left
    pack [button $bs.help -text Help -width 10 -command "ContextSensitiveHelp .findentry diagrams/search.htm"] -padx 2 -pady 4 -side left
    
    LetItShow .findentry
    grab .findentry
    focus $ft.e
    tkwait variable find(done)
    grab release .findentry
    set result [$ft.e get]
    PackItUp .findentry
    if {$find(done)} {
    set find(prevs) [AddIfAbsent $result $find(prevs)]
        return $result
    }
}

proc DoUserDialogue {} {
    global env userinfo
    set t [PutItThere .userdata .]
    wm title $t "Enter your details"
    pack [label $t.mess -text "Please enter your name, organization and license code if required."]
    pack [frame $t.name] -fill x
    pack [label $t.name.mess -text Name:] -side left
    pack [entry $t.name.entry -width 40 -text userinfo(name)] -side right
    pack [frame $t.corp] -fill x
    pack [label $t.corp.mess -text Organization:] -side left
    pack [entry $t.corp.entry -width 40 -text userinfo(corp)] -side right
    pack [frame $t.code] -fill x
    if {![string equal evaluation $userinfo(edn)]} {
	pack [label $t.code.mess -text "License code:"] -side left
	pack [entry $t.code.entry -width 40 -text userinfo(license_code)] \
	    -side right
    } else {
	set userinfo(license_code) "<none needed>"
    }
    pack [frame $t.buttons] -fill x
    pack [button $t.buttons.ok -text OK \
	      -command "set userinfo(entrydone) 1"] -side left
    pack [button $t.buttons.ex -text Exit \
	      -command "set userinfo(entrydone) 0"] -side right
    
    LetItShow $t
    grab $t
    focus $t.name.entry
    wm withdraw .splash
    while {![info exists userinfo(entrydone)]} {
	tkwait variable userinfo(entrydone)
	if {$userinfo(entrydone)} {
	    if {![c_testlicense]} {
		BuildProblem "Wrong license code" warning "You have entered the wrong license code for your name, organization and Simile version. Please try again, ensuring you have the correct license code." license
		unset userinfo(entrydone)
	    }
	}
    }
    wm deiconify .splash
    grab release $t
    PackItUp $t
    return $userinfo(entrydone)
}

proc DoRegDialog {dtId} {
    global userinfo custom welcomeDone tcl_platform SimileAutoObjLoaded
    
    if {[info exists SimileAutoObjLoaded]} {
        return
    }
#    set whatCalled [file rootname [file tail [info nameofexecutable]]]
#    if {[string equal SimileScript $whatCalled]} {
#        return
#    }
    
    if {$userinfo(Version)==$userinfo(oldVersion)} {
        if {$userinfo(done)} {
            return
        }
    } else {
        file mkdir $custom(prefDir)/Examples
        foreach egFile [glob [pwd]/../Examples/*] {
            # next condition only matters in development environment
            if {![file isdirectory $egFile]} {
                file copy -force $egFile $custom(prefDir)/Examples
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
    set create [.register.create getframe]
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
    set tasks [.register.tasks getframe]
    
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
    set links [.register.links getframe]
    
    frame $links.m1
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
    LetItShow .register
    
    grab .register
    bind $www1 <Button-1> {ContextSensitiveHelp .register start/index.htm}
# Removed ALD 25Feb2005 - non-functional at present due to missing Help pages
#    bind $www2 <Button-1> {ContextSensitiveHelp .register examples/index.htm}
    
    # now put it in the middle of the desktop
    scan [ wm geometry $dtId] {%dx%d+%d+%d} a s d f
    scan [ wm geometry .register] {%dx%d} g h
    #ShowMessage debug info "Desktop $a x $s + $d + $f Welcome $g x $h" ok
    # if window is fullsize, offset info is garbage
    if {[string match zoomed [wm state $dtId]]} {
        set d 0
        set f 0
    }
    wm geometry .register +[expr $d+($a-$g)/2]+[expr $f+($s-$h)/2]
    tkwait variable userinfo(done)
    
    set UserStream [NetOpen $custom(prefDir)/.version w]
    puts $UserStream $userinfo(name)
    puts $UserStream $userinfo(corp)
    puts $UserStream $userinfo(Version)
    puts $UserStream $userinfo(done)
    close $UserStream
    switch [tk windowingsystem] {
        win32 {file attributes $custom(prefDir)/.version -hidden true}
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
    
    grab release .register
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
            winhelp $context ../Help/simile.chm $page
        } aqua {
            exec open -a "Help Viewer.app" ../Help/$page
        } x11 {
            set url [pwd]/../Help/$page
            if {![info exists env(BROWSER)]} {
                foreach possBrowser {mozilla netscape iexplorer lynx} {
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

proc CheckHyper {ywhat} {
    return 0
}

proc GoHyper {ywhat} {
    ShowMessage debug info $ywhat ok
}

proc ResolveHyper {args} {
    ShowMessage debug info "Resolving $args" ok
    return {}
}

proc ErrorHelp {diagnostic} {
    global diagno url help tcl_platform
    set parent [focus]
    PutItThere .diag $parent

    wm title .diag {Error diagnostics}
    wm protocol .diag WM_DELETE_WINDOW {set diagno(done) 0}
    labelframe .diag.errorf -text "Diagnostics:"
    message .diag.errorf.errorm -text "Full text of the error report, as generated by the TclTk interpreter:" -aspect 5000
    pack .diag.errorf.errorm -side top
    text .diag.errorf.e -yscrollcommand [list .diag.errorf.y set] -width 20 -height 8 -relief sunken -bd 2 -highlightthickness 0
    .diag.errorf.e insert 1.0 $diagnostic
    scrollbar .diag.errorf.y -command [list .diag.errorf.e yview]
    pack .diag.errorf.e -fill both -expand true -side left  -padx 4 -pady 4
    pack .diag.errorf.y -side left -fill y
    pack .diag.errorf -fill both -expand true -padx 4 -pady 4
    
    labelframe .diag.topicsf -text "Help:"
    message .diag.topicsf.errorm -text "The following relevant help topics were found.  Double-click a page title to view it." -aspect 5000
    pack .diag.topicsf.errorm -side top -padx 4 -pady 4
    pack [listbox .diag.topicsf.l -width 20 -height 8] -fill both -expand on  -padx 4 -pady 4
    bind .diag.topicsf.l <ButtonRelease-1> {GetHelp}
    pack [button .diag.b -text OK -width 10 -command {set diagno(done) 0}] -pady 4
    set diagno(keys) {}
    foreach key [array names help] {
        if {[regexp $key $diagnostic]} {
            lappend diagno(keys) $key
            .diag.topicsf.l insert end $url($help($key))
            pack .diag.topicsf -fill both -expand on  -padx 4 -pady 4
        }
    }
    LetItShow .diag
    grab .diag
    tkwait variable diagno(done)
    unset diagno(done)
    grab release .diag
    PackItUp .diag
}

proc GetHelp {} {
    global SIMILE_PATH diagno help
    cd $SIMILE_PATH/Help
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
                foreach possBrowser {mozilla netscape iexplorer lynx} {
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
    global sendvars userinfo interface tcl_platform
    PutItThere .about $winId
    wm title .about About\ Simile
    image create photo dripu
    image create photo dripl
    dripu read "../Images/HelpAboutUpper.gif"
    dripl read "../Images/HelpAboutLower.gif"
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
    pack [label .about.fr.lab1 -text "Simile v$sendvars(simV) $userinfo(edn)" \
            -font "-family helvetica -size $fSize"]
    set platform [frame .about.fr.platform]
    pack [label $platform.prolog -text "Prolog: $sendvars(proV)" \
            -font "-family helvetica -size $fsSize"] -side left
    pack [label $platform.tcl -text "TclTk: [info patchlevel]" \
            -font "-family helvetica -size $fsSize"] -side left
    switch [tk windowingsystem] {
        win32 {
            pack [label $platform.g++ -text "MinGW g++: [exec ../System/bin/g++ -dumpversion]" \
                -font "-family helvetica -size $fsSize"] -side left
        }
    }
    pack $platform
    if [info exists userinfo(exp_time)] {
        set edate [clock format $userinfo(exp_time) -format {%d %h %Y}]
        set expf [frame .about.fr.expf]
        pack [label $expf.lab1 -text "This product expires on" \
            -font "-family helvetica -size $fsSize"] -side left
        pack [label $expf.lab2 -text $edate -font "-family helvetica -size $fsSize"] -side left
        pack $expf
    }
    pack [label .about.fr.lab4 -text "This product is registered to\
            $userinfo(name), $userinfo(corp)" \
            -font "-family helvetica -size $fsSize"]
    
    set gen [frame .about.fr.gen]
    switch -regexp $userinfo(edn) {
        evaluation {
            set info [label $gen.info -text "For upgrade to Standard\
                    or Enterprise Editions," -font "-family helvetica -size $fSize"]
        } standard|teaching {
            set info [label $gen.info -text "For support or to upgrade\
                    to Enterprise Edition," -font "-family helvetica -size $fSize"]
        } enterprise {
            set info [label $gen.info -text "For support," \
                    -font "-family helvetica -size $fsSize"]
        }
    }
    pack $info -side left
    pack [label $gen.visit -text "please visit" -font "-family helvetica -size $fsSize"]\
            -side left
    pack [label $gen.www -text www.simulistics.com -relief flat \
            -font "-underline true -family helvetica -size $fsSize" -fg blue -cursor hand2] -pady 2 -side left
    bind $gen.www <Button-1> "VisitUrl http://www.simulistics.com/"
    pack $gen -padx 4 -pady 2
    pack .about.fr -expand on -fill x -padx 8 -pady 2
    
    label .about.lower -image dripl
    pack .about.lower
    
    pack [button .about.b -text OK -width 10 -default active \
            -command "set sendvars(doneAbout) 1"] -pady 2
    pack [label .about.l16]
    wm geometry .about +[expr [winfo screenwidth .]/2-200]+[expr [winfo screenheight .]/2-250]
    grab .about
    
    tkwait variable sendvars(doneAbout)
    grab release .about
    PackItUp .about
}

# images must be global because if building a c++ program we may be in a different directory
set bwVers [package require BWidget]

proc ShowExpiryImminent {expTime} {
    global iconImages
    
    toplevel .expiry
    #    wm transient .expiry $winId
    wm title .expiry "Expiry Imminent"
    wm protocol .expiry WM_DELETE_WINDOW {set ack 1}
    global tcl_platform
    switch [tk windowingsystem] {
        win32 {wm attributes .expiry -toolwindow true}
    }
    
    set labf1 [frame .expiry.labf1]
    pack [label $labf1.img -image $iconImages(warning)] -side left
    pack [label $labf1.lab1 -text "Warning:" \
            -font {-weight bold -family helvetica -size 10}] -side left
    pack [label $labf1.lab2 -text "This product will shortly expire." \
            -font {-family helvetica -size 10}] -side left
    pack $labf1 -padx 8 -pady 2
    
    set labf2 [frame .expiry.labf2]
    pack [label $labf2.lab1 -text "Please visit" -font {-family helvetica -size 10}] -side left
    pack [set www [label $labf2.lab2 -text "www.simulistics.com" \
            -fg blue -cursor hand2 -font {-underline true -family helvetica -size 10}]] -side left
    bind $www <Button-1> {VisitUrl "http://www.simulistics.com/"}
    pack [label $labf2.lab3 -text "before" -font {-family helvetica -size 10}] -side left
    pack [label $labf2.lab4 -text [clock format $expTime -format {%d %h %Y}] \
            -font {-family helvetica -size 10}] -side left
    pack [label $labf2.lab5 -text "to upgrade." -font {-family helvetica -size 10}] -side left
    pack $labf2 -padx 8 -pady 2
    
    set buttons [frame .expiry.buttons]
    pack [button $buttons.ok -text OK -width 10 \
            -command {set ack 1}] \
            -side left -padx 4 -pady 4
    pack [button $buttons.help -text Help -width 10 \
            -command {ContextSensitiveHelp .expiry coviewexpiry.htm}] \
            -side left -padx 4 -pady 8
    pack $buttons
    
    set height [winfo reqheight .expiry]
    set width [winfo reqwidth .expiry]
    set sheight [winfo screenheight .expiry]
    set swidth [winfo screenwidth .expiry]
    wm geometry .expiry +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    update
    
    tkwait variable ack
    destroy .expiry
}

proc TrackSize {canvas item} {
    $canvas itemconfig $item -width [winfo width $canvas]
    $canvas itemconfig $item -height [winfo height $canvas]
}

############################################## Equation listing
proc equationlisting_start {DefEquationListingFileName} {
    global equationlist tcl_platform DefaultEquationListingFileName
    set DefaultEquationListingFileName $DefEquationListingFileName
    set w .equations
    catch {destroy $w}
    toplevel $w -height 600 -width 800
    wm title $w "Equation listing"
    
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
    $m add cascade -label File -underline 0 -menu $fm
    $fm add command -label Save -command "EquationListingSave $w" \
            -accelerator "$accKey+S"
    $fm add separator
#    if {[string match windows $tcl_platform(platform)]} {
        $fm add command -label Print -command "EquationListingPrint $w" \
                -accelerator "$accKey+P"
#    }
    $fm add separator
    $fm add command -label Close -command "destroy $w"
    
    set fm [menu $w.editMenu -tearoff 0]
    $m add cascade -label Edit -underline 0 -menu $fm
    $fm add command -label "Select All" \
            -command {EquationListingSelectAll $equationlist(textbox)} \
            -accelerator "$accKey+A"
    $fm add command -label Copy -command {tk_textCopy $equationlist(textbox)} \
            -accelerator "$accKey+C"
    #        $fm add command -label "Find" \
    #                -command "EquationListingFindPopup $w" \
    #        -accelerator "$accKey+F"
    
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
    
    foreach imgType [list compartment flow variable creation \
             immigration loss reproduction condition alarm] {
    image create photo equationlist(${imgType}img)
    equationlist(${imgType}img) read "../Images/Toolbar/${imgType}.gif"
    }
    
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
}

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
    focus $winId 
    $winId tag add sel 1.0 end
}


proc equationlisting_addsubmodel {isub submodel_label comments timestep enumtypes type} {
    global equationlist
    $equationlist(textbox) configure  -state normal
    
    set widget $equationlist(textbox)
    
    # toplevel
    if {$isub == 1} {
        $widget insert end "\n"
        $widget insert end "Model [regsub -all "\n" $submodel_label " "]" bigtag
        $widget insert end "\n"
        
    } else  {
        $widget insert end "\n"
        $widget insert end "Submodel [regsub -all "\n" $submodel_label " "] " bigtag
        $widget insert end "\n"
    }
    
    # type of submodel and dimensions if approp
    if {![string match "" $type]} {
        $widget insert end "\t$type\n" cmttag
    }
    
    # Comments
    if {![string match null $comments]} {
        $widget insert end "\t\t$comments \n" cmttag; # should be empty if comments null
    }
    
    # time step index
    if {![string match null $timestep]} {
        $widget insert end "\tTime step index: $timestep\n" cmttag
    }
    
    # enumerated types
################################################################################
#     if {[llength $enumtypes] > 0} {
#         foreach {et} [lindex $enumtypes 0] {
#             $widget insert end "\tEnumerated types: $et\n" cmttag
#        }
#     }
################################################################################
    if {![string match {[]} $enumtypes]} {
        $widget insert end "\tEnumerated types: ${enumtypes}\n" cmttag
    }
    $equationlist(textbox) configure  -state disabled
    update idletasks
}


proc equationlisting_addvariable {isub ivar vartype varlabel expression where minmax description comments \
            inflows outflows} {
    #puts "inflows $inflows outflows $outflows"
    # tabs (\t) used as well as margins to provide some formatting to text copied and pasted to other apps
    global equationlist
    #ShowMessage debug info "$comments" ok
    
    set widget $equationlist(textbox)
    $equationlist(textbox) configure  -state normal
    $widget insert end " \n" dummy
    
    #puts "equationlisting_addvariable $varlabel $vartype $inflows $outflows $where"
    
    $widget insert end "[string totitle ${vartype}] " typtag
    $widget insert end " " descrtag
    $widget image create end -image equationlist(${vartype}img)
    $widget insert end " " descrtag
    
    set tidy_varlabel [regsub -all "\n" $varlabel " "]
    set tidy_expression [regsub -all "\n" $expression "\n\t\t\t"]
    set tidy_description [regsub -all {\n} $description { }]
    set tidy_comments [regsub -all "\n" $comments " "]
    set where [regsub -all "\n" $where " "]
    set where [string range $where 1 end-1]
    set tidy_where [regsub -all "," $where "\n\t\t"]

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
        
        $widget insert end "\tInitial value" eqntag
        $widget insert end " = " eqntag
        $widget insert end $expression eqntag
        $widget insert end "\n" eqntag
        
        if ![string match {null} $where] {
            $widget insert end "\tWhere:\n\t\t$tidy_where \n" whrtag; # tidy where should be empty if where null
            #add_text "Where:\n$tidy_where" {Helvetica 9 italic} 20 0 #008800
        }
        if {![string match {null} $minmax]} {
            $widget insert end "\t$minmax\n"
    }
        # ...rate equation
        if {[llength $outflows]>0 | [llength $inflows]>0} {
            set text_string "Rate of change = "; #"d(${tidy_varlabel})/dt = "
            
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
        
        if ![string match {null} $where] {
            $widget insert end "\tWhere:\n\t\t$tidy_where \n" whrtag; # tidy where should be empty if where null
            #add_text "Where:\n$tidy_where" {Helvetica 9 italic} 20 0 #008800
        }
        if {![string match {null} $minmax]} {
            $widget insert end "\t$minmax\n"
    }
    }
    
    # Comments
    if ![string match null $comments] {
        $widget insert end "\tComments:\n\t\t$tidy_comments \n" cmttag; # should be empty if comments null
        #add_text "Comments: $tidy_comments" {Helvetica 9 italic} 20 0 #000088
    }
    $equationlist(textbox) configure  -state disabled
    
}

proc EquationListingSave {winId} {
    global equationlist DefaultEquationListingFileName
        
    set types {
        {{Text Files} {.txt} }
        {{All Files} * }
    }
    
    set fname [tk_getSaveFile\
            -defaultextension .txt \
            -filetypes $types \
            -initialdir [GetPathChoice .sml] \
            -initialfile $DefaultEquationListingFileName \
            -parent $winId ]
    if {![string match "" $fname]} {
        set f [open $fname w]
        puts $f [$equationlist(textbox) get 1.0 end]
        close $f
    }
}

proc EquationListingPrint {winId} {
    global simtmpdir env tcl_platform
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

proc BuildProblem {Title errLevel msg key args} {
    global iconImages help tcl_platform

    set ProbWin .bprob[clock clicks]
    PutItThere $ProbWin [focus]

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
    wm protocol $ProbWin WM_DELETE_WINDOW {set ack 1}
    switch [tk windowingsystem] {
        win32 {wm attributes $ProbWin -toolwindow true}
    }

    set labf1 [frame $ProbWin.labf1]
    pack [label $labf1.img -image $iconImages($errLevel)] -side left 
    pack [label $labf1.lab1 -text "Warning:" \
            -font {-weight bold -family helvetica -size 10}] -side left
    pack [scrollbar $labf1.yscroll -orient v \
            -command [list $labf1.lab2 yview]] -side right -fill y
    pack [text $labf1.lab2 -width 48 -height 10 -relief sunken -bd 2 -highlightthickness 0 -wrap word -yscrollcommand [list AdjustCanvas $labf1 lab1 y]] -fill both -expand on
    $labf1.lab2 insert 1.0 $msg
    $labf1.lab2 config -state disabled
    #    pack [label $labf1.lab2 -text $msg -wraplength 320 \
    #            -font {-family helvetica -size 10} -justify left] -side left
    pack $labf1 -padx 8 -pady 2 -fill both -expand on
    
    set buttons [frame $ProbWin.buttons]
    pack [button $buttons.ok -text OK -width 10 \
            -command {set ack 1}] \
            -side left -padx 4 -pady 4
    if {[llength $args]==2} {
        pack [button $buttons.report -text {Send bug report} -width 20 \
          -command [concat ReportProblem $args [list $msg]]] \
                -side left -padx 4 -pady 4
    }
    pack [button $buttons.help -text Help -width 10 \
           -command "set ack 1; ContextSensitiveHelp $ProbWin $help($key)"] \
           -side left -padx 4 -pady 8
    pack $buttons
    
#    set height [winfo reqheight $ProbWin]
#    set width [winfo reqwidth $ProbWin]
#    set sheight [winfo screenheight $ProbWin]
#    set swidth [winfo screenwidth $ProbWin]
#    wm geometry $ProbWin +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    LetItShow $ProbWin
#    update
    focus $ProbWin
    grab $ProbWin
    tkwait variable ack
    grab release $ProbWin
    PackItUp $ProbWin
}

proc ReportProblem {name autoName fault} {
    
    set mimes {}
    #    set unique [clock seconds].[pid]
    #    set bound "-----NEXT_PART_$unique"
    if {![string match unsaved $name]} {
        set Disposition "inline; filename=\"[file tail $name]\""
        lappend mimes [mime::initialize -canonical application/x-simile \
                -header [list Content-Disposition $Disposition] \
                -header [list Content-Description "Simile model"] \
                -file $name]
        #        set fid [open $name r]
        #        fconfigure $fid -translation binary
        #        if {[catch {read $fid [file size $name]} data]} {
        #            return -code error $data
        #        }
        #        close $fid
        #        append outputData "$bound\nContent-Disposition: form-data;\
        #            name=\"imagefile\"; filename=\"[file tail $name]\"\nContent-Type: text/plain\n\n$data\n"
    }
    if {![string match none $autoName]} {
        set Disposition "inline; filename=\"[file tail $autoName]\""
        lappend mimes [mime::initialize -canonical application/x-simile \
                -header [list Content-Disposition $Disposition] \
                -header [list Content-Description "Change log"] \
                -file $autoName]
    }
    lappend mimes [mime::initialize -canonical text/plain \
            -header [list Content-Disposition inline] \
            -header [list Content-Description "Error message"] \
            -string $fault]
    set multiT [mime::initialize -canonical multipart/mixed -parts $mimes]
    set data [mime::buildmessage $multiT]
    
    package require http
    upvar 0 [::http::geturl http://www.simulistics.com/cgi-bin/saveit.cgi \
            -type application/x-zip -query [zip -mode compress $data]] reply
    ShowMessage {Simile phone home!} info $reply(body) ok
}

proc NotifyOverLimit {edn limit} {
    global iconImages
    
    toplevel .notify
    wm title .notify "Over Limit For Edition"
    wm protocol .notify WM_DELETE_WINDOW {set ack 1}
    global tcl_platform
    switch [tk windowingsystem] {
    win32 {wm attributes .notify -toolwindow true}
    }
    
    set labf1 [frame .notify.labf1]
    pack [label $labf1.img -image $iconImages(warning)] -side left
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
    pack [button $buttons.ok -text OK -width 10 \
            -command {set ack 1}] \
            -side left -padx 4 -pady 4
    pack [button $buttons.help -text Help -width 10 \
            -command {ContextSensitiveHelp .notify files/limit.htm}] \
            -side left -padx 4 -pady 8
    pack $buttons
    
    set height [winfo reqheight .notify]
    set width [winfo reqwidth .notify]
    set sheight [winfo screenheight .notify]
    set swidth [winfo screenwidth .notify]
    wm geometry .notify +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    update
    
    tkwait variable ack
    destroy .notify
}
