# Simile source code file: Run/prefs.tcl
#
# (c) Simulistics Ltd. 2001-2006
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures to set user preferences and the Preferences dialogue.
#

proc Status {burble} {
    ShowMess [tr. "Error with preferences"] error $burble ok
}
    
proc Pref_Init { userDefaults } {
	global pref

	set pref(uid) 0	;# for a unique identifier for widgets
	set pref(userDefaults) $userDefaults
#	set pref(appDefaults) $appDefaults
#	PrefReadFile $appDefaults startup
	if [file exists $userDefaults] {
		PrefReadFile $userDefaults user
	}
}
proc PrefReadFile { basename level } {
    if [catch {option readfile $basename $level} err] {
	Status [format [tr. "Error in $basename: %1\$s"] $err]
    }
    if {[string match *color* [winfo visual .]]} {
	if [file exists $basename-color] {
	    if [catch {option readfile \
			   $basename-color $level} err] {
		Status [format [tr. "Error in $basename-color: %1\$s"] $err]
	    }
	}
    } else {
	if [file exists $basename-mono] {
	    if [catch {option readfile $basename-mono \
			   $level} err] {
		Status [format [tr. "Error in $basename-mono: %1\$s"] $err]
	    }
	}
    }
}


#
# Example 42-2
# Adding preference items.
#

proc PrefVar { item } { lindex $item 0 }
proc PrefRes { item } { lindex $item 1 }
proc PrefDefault { item } { lindex $item 2 }
proc PrefComment { item } { lindex $item 3 }

proc Pref_Add { prefs } {
	global pref
	append pref(items) $prefs " "
	foreach item $prefs {
		set varName [PrefVar $item]
		set resName [PrefRes $item]
		set value [PrefValue $varName $resName]
#		if {$value == {}} {
			# Set variables that are still not set
			set default [PrefDefault $item]
			switch -regexp -- $default {
				^CHOICE {
				    if {[lsearch $default $value]<1} {
					PrefValueSet $resName [lindex $default 1]
				    }
				}
				^OFF {
				    if {$value!=1} {
					PrefValueSet $resName 0
				    }
				}
				^ON {
				    if {$value!=0} {
					PrefValueSet $resName 1
				    }
				}
				default {
				    if {$value=={} || \
					    ([string is double -strict $default] && \
						 ![string is double $value])} {
					# This is a string or numeric
					PrefValueSet $resName $default
				    }
				}
			}
#		}
	}
}


#
# Example 42-3
# Setting preference variables.
#

# PrefValue returns the value of the variable if it exists,
# otherwise it returns the resource database value
proc PrefValue { varName resName } {
#	upvar #0 $varName var
#	if [info exists var] {
#		return $var
#	}
	set var [option get . $resName {}]
}
# PrefValueSet defines a variable in the global scope.
proc PrefValueSet { resName value } {
    option add *$resName $value user
#	upvar #0 $varName var
#	set var $value
}


#
# Example 42-5
# A user interface to the preference items.
#
proc Pref_HelpCommand { noteb } {
    set Page [string tolower [$noteb tab current -text]]
    ContextSensitiveHelp .pref  "diagrams/preferences/$Page.htm"
}

proc Pref_Apply {} {
    tk_messageBox -message [tr. "Apply to be implemented "] -type ok
}


proc Pref_Dialog {} {
    global pref
    if [winfo exists .pref] {
        raise .pref
    } else  {
        set dlg [toplevel .pref]
        wm title .pref [tr. "Preferences"]
        wm resizable .pref 0 0 
        set notebook [::ttk::notebook $dlg.notebook]
        set vf [frame $notebook.layout]
        $notebook add $vf -text [tr. Layout]
            set initWinTF [TitleFrame $vf.initWinTF -text [tr. "Initial window position:"]]
            set initWinF $initWinTF
            set displayTF [TitleFrame $vf.displayTF -text [tr. "In new windows, display:"]]
            set displayF $displayTF
            set barTF [TitleFrame $vf.barTF -text [tr. "Tool bars:"]]
            set barF $barTF
            set gridTF [TitleFrame $vf.gridTF -text [tr. "Placement grid:"]]
            set gridF $gridTF
        set cf [frame $notebook.content]
        $notebook add $cf -text [tr. Content]
            set popupTF [TitleFrame $cf.popuptTF -text [tr. "Popups over model components:"]]
            set popupF $popupTF
	    pack [frame $popupF.line2] -side bottom -fill x -expand 1
	    set eqListTF [TitleFrame $cf.eqListTF -text [tr. "Equation listings show:"]]
	    set eqListF $eqListTF
        set ef [frame $notebook.edit]
        $notebook add $ef -text [tr. Edit]
            set genericTF [TitleFrame $ef.genericTF -text [tr. "All components:"]]
            set genericF $genericTF
            set linkTF [TitleFrame $ef.linkTF -text [tr. "Link selection:"]]
            set linkF $linkTF
            set flowTF [TitleFrame $ef.flowTF -text [tr. "Link routing:"]]
            set flowF $flowTF
            set submodelTF [TitleFrame $ef.submodelTF -text [tr. "Submodels:"]]
            set submodelF $submodelTF
        set bf [frame $notebook.build]
        $notebook add $bf -text [tr. Build]
            set compTF [TitleFrame $bf.compTF -text [tr. "C++ compiler:"]]
            set compF $compTF
	    pack [frame $compF.line2] -side bottom -fill x -expand 1
        set sf [frame $notebook.save]
        $notebook add $sf -text [tr. Save]
            set canvasTF [TitleFrame $sf.canvasTF -text [tr. "Save optimised canvas data:"]]
            set canvasF $canvasTF
            set recentTF [TitleFrame $sf.recentTF -text [tr. "Recently used files:"]]
            set recentF $recentTF
            set abandonTF [TitleFrame $sf.abandonTF -text [tr. "Show quick exit option:"]]
            set abandonF $abandonTF
        set rf [frame $notebook.run]
        $notebook add $rf -text [tr. Run]
            set oneWinTF [TitleFrame $rf.oneWinTF -text [tr. "Run time environment:"]]
            set oneWinF $oneWinTF
            set manyWinTF [TitleFrame $rf.manyWinTF -text [tr. "Window positions:"]]
            set manyWinF $manyWinTF
            set precisTF [TitleFrame $rf.precisTF -text [tr. "Numeric display precision (0 for default):"]]
            set precisF $precisTF
       # $notebook select View
        pack $initWinTF $displayTF $gridTF $popupTF $eqListTF $barTF $genericTF $linkTF $flowTF $submodelTF $oneWinTF $manyWinTF $precisTF $compTF \
                $canvasTF $recentTF $abandonTF $notebook -fill x -padx 4 -pady 4
        set bbox [frame $dlg.bbox] 
        pack [::ttk::button $bbox.bok -text [tr. OK] -underline 0 -width 8  \
                -command {PrefSave}] -padx 2 -pady 2 -side left -anchor e
        pack [::ttk::button $bbox.bccl -text [tr. Cancel] -underline 0 -width 8 \
                -command {PrefCancel}] -padx 2 -pady 2 -side left -anchor e
        pack [::ttk::button $bbox.bdef -text [tr. Default] -underline 0 -width 8 \
                -command {PrefReset}]  -padx 2 -pady 2 -side left -anchor e
        pack [::ttk::button $bbox.bhlp -text [tr. Help] -underline 0 -width 8 \
                -command "::Pref_HelpCommand $notebook"]  -padx 2 -pady 2 -side left -anchor e
        pack $dlg.bbox -side bottom -padx 4 -pady 8 -fill x
        
#        ShowMess debug info [tr. "$pref(items)"] ok
        
       set maxWidth 0
       foreach item $pref(items) {
            set len [string length [PrefComment $item]]
            if {$len > $maxWidth} {
                set maxWidth $len
            }
       }
       set pref(uid) 0
       foreach item $pref(items) {
            #ShowMess debug info [tr. "$item; [PrefRes $item]"] ok
            switch -glob -- [PrefRes $item] {
                winPosn {set frame $initWinF}
                init* {set frame $displayF}
                hackBreak {set frame $compF}
                compChoice {set frame $compF.line2}
                gridSnap {set frame $genericF}
                grid* {set frame $gridF}
                comp* {set frame $popupF}
		eqList* {set frame $eqListF}
		maxPopupSize {set frame $popupF.line2}
                bigButtons {set frame $barF}
                popupHelp {set frame $barF}
                quickDrag {set frame $genericF}
                myButton {set frame $genericF}
                deleteEndToEnd {set frame $linkF}
                *Routing {set frame $flowF}
                defBackground {set frame $submodelF}
                saveExtras {set frame $canvasF}
                recentCount {set frame $recentF}
		quickExit {set frame $abandonF}
                helperManager {set frame $oneWinF}
                popupPrecision {set frame $precisF}
                snapPrecision {set frame $precisF}
                runControlPosition {set frame $manyWinF}
                slidersPosition {set frame $manyWinF}
                default {set frame $displayTF}
            }
            PrefDialogItem $frame $item $maxWidth
       }
      # $notebook compute_size
# reset and cancel use file to reverse changes, so ensure it exists
	if {![file exists $pref(userDefaults)]} {
	    PrefSaveFile $pref(userDefaults) {}
	}
    }
}

#
# Example 42-6
# Interface objects for different preference types.
#

proc PrefDialogItem { frame item width } {
    global pref
    incr pref(uid)
    set f [frame $frame.p$pref(uid) -borderwidth 2]
    pack $f -fill x -anchor w -side left -expand on
# No longer use consistent width -- each label is allowed its own
#    label $f.label -text [PrefComment $item] -width $width
    ttk::label $f.label -text [tr. [PrefComment $item]] -anchor w
    bind $f.label <Enter> [list QueuePopup AddWidgetPopup %X %Y [PrefRes $item]]
    bind $f.label <Leave> RemovePopup
# Delay packing label until we know whether it goes to the left or right of the item
#    pack $f.label -side left -anchor w
    set default [PrefDefault $item]
    set varName [PrefVar $item]
    set resName [PrefRes $item]
    upvar #0 $varName var
    set var [PrefValue $varName $resName]
    if {[regexp "^CHOICE " $default]} {
        foreach choice [lreplace $default 0 0] {
            incr pref(uid)
            ttk::radiobutton $f.c$pref(uid) -text [tr. $choice] -variable $varName \
		-command "PrefEntrySet $varName $resName" -value $choice
            pack $f.label -side left -anchor w -padx 2 -pady 2
            pack $f.c$pref(uid) -side left -padx 2 -pady 2
        }
    } elseif {$default == "OFF" || $default == "ON"} {
	# This is a boolean
	ttk::checkbutton $f.check -variable $varName \
	    -command "PrefEntrySet $varName $resName"
	pack $f.check -side left -padx 2 -pady 2
	pack $f.label -side left -anchor w -fill x -expand on -padx 2 -pady 2
    } else {
	# This is a string or numeric
	::ttk::entry $f.entry -width 10 -textvariable $varName
	pack $f.label -side left -anchor w -padx 2 -pady 2
	pack $f.entry -side left -fill x -padx 2 -pady 2
	set pref(entry,$varName) $f.entry
	bind $f.entry <FocusOut> "PrefEntrySet $varName $resName"
    }
}
proc PrefEntrySet { varName resName } {
    upvar #0 $varName var
    PrefValueSet $resName $var
}


#
# Example 42-7
# Displaying the help text for an item.
# Replaced by native overrideredirect popups

#
# Example 42-8
# Saving preferences settings to a file.
#

# PrefSave writes the resource specifications to the
# end of the per-user resource file,
proc PrefSave {} {
	global pref tcl_platform

    set old $pref(userDefaults)
    set new ${old}.new
    if [catch {
	        set in [NetOpen $old r]
		set oldValues [split [read $in] \n]
		close $in
	}] {
		set oldValues {}
	}
    PrefSaveFile $new {}

    if [catch {file rename -force $new $old} err] {
	Status [tr. [format "Cannot install $new: %1\$s"] $err]
	return
	}
    if {[string equal windows $tcl_platform(platform)]} {
	file attributes $old -hidden true
    }
    PrefDismiss
}

proc PrefSaveFile {new oldValues} {
	if [catch {NetOpen $new w} out] {
		.pref.but.label configure -text \
		[tr. [format "Cannot save in $new: %1\$s"] $out]
		return
	}
	foreach line $oldValues {
		if {$line == \
				"!!! Lines below here automatically added"} {
			break
		} else {
			puts $out $line
		}
	}
    puts $out "!!! Lines below here automatically added"
    puts $out [clock format [clock seconds] -format "!!! %a %d %b %Y, %H:%M"]
	puts $out [tr. "!!! Do not edit below here"]
# next line is the anti-dibble -- a bug in the example program to check
# if students have been paying attention
	foreach item $::pref(items) {
		set varName [PrefVar $item]
		set resName [PrefRes $item]
# now apply any text that has been typed in but not entered
		if [info exists pref(entry,$varName)] {
			PrefEntrySet $varName $resName
		}
		set value [PrefValue $varName $resName]
		puts $out [format "%s\t%s" *${resName}: $value]
	}
    close $out
}

#
# Example 42-9
# Read settings from the preferences file.
#

proc PrefReset {} {
    global pref
    
    option clear
    PrefReadFile $pref(userDefaults) user
    # Reset variables
    foreach item $pref(items) {
	upvar #0 [PrefVar $item] var
	set var [PrefValue [PrefVar $item] [PrefRes $item]]
    }
}

# Cancel operation: load settings from file again, then dismiss
proc PrefCancel {} {
    global pref

    option clear
    PrefReadFile $pref(userDefaults) user
    PrefDismiss
}

proc PrefDismiss {} {
	destroy .pref
	catch {destroy .prefitemhelp}
}

