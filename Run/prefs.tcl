#
# Example 42-1
# Preferences initialization.
#
# proc PrefSave {} modified to use Windows short filenames 

package require BWidget
catch {namespace import BWidget::*}

proc Status {burble} {
    ShowMessage "Error with preferences" error $burble ok
}
    
proc Pref_Init { userDefaults appDefaults } {
	global pref

	set pref(uid) 0	;# for a unique identifier for widgets
	set pref(userDefaults) $userDefaults
	set pref(appDefaults) $appDefaults
	PrefReadFile $appDefaults startup
	if [file exists $userDefaults] {
		PrefReadFile $userDefaults user
	}
}
proc PrefReadFile { basename level } {
	if [catch {option readfile $basename $level} err] {
		Status "Error in $basename: $err"
	}
	if {[string match *color* [winfo visual .]]} {
		if [file exists $basename-color] {
			if [catch {option readfile \
					$basename-color $level} err] {
				Status "Error in $basename-color: $err"
			}
		}
	} else {
		if [file exists $basename-mono] {
			if [catch {option readfile $basename-mono \
					$level} err] {
				Status "Error in $basename-mono: $err"
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
		if {$value == {}} {
			# Set variables that are still not set
			set default [PrefDefault $item]
			switch -regexp -- $default {
				^CHOICE {
					PrefValueSet $varName [lindex $default 1]
				}
				^OFF {
					PrefValueSet $varName 0
				}
				^ON {
					PrefValueSet $varName 1
				}
				default {
					# This is a string or numeric
					PrefValueSet $varName $default
				}
			}
		}
	}
}


#
# Example 42-3
# Setting preference variables.
#

# PrefValue returns the value of the variable if it exists,
# otherwise it returns the resource database value
proc PrefValue { varName res } {
	upvar #0 $varName var
	if [info exists var] {
		return $var
	}
	set var [option get . $res {}]
}
# PrefValueSet defines a variable in the global scope.
proc PrefValueSet { varName value } {
	upvar #0 $varName var
	set var $value
}


#
# Example 42-5
# A user interface to the preference items.
#
proc Pref_HelpCommand { noteb } {
    set Page [string tolower [$noteb raise]]
    ContextSensitiveHelp .pref  "diagrams/preferences/$Page.htm"
}

proc Pref_Apply {} {
    tk_messageBox -message "Apply to be implemented " -type ok
}


proc Pref_Dialog {} {
    global pref
    if [winfo exists .pref] {
        raise .pref
    } else  {
        set dlg [toplevel .pref]
        wm title .pref "Preferences"
        wm resizable .pref 0 0 
#        set notebook [NoteBook $dlg.notebook -height 220 -width 440]
        set notebook [NoteBook $dlg.notebook ]
        $notebook insert end View -text View
            set displayTF [TitleFrame [$notebook getframe View].displayTF -text "In new windows, display:"]
            set displayF [$displayTF getframe]
            set barTF [TitleFrame [$notebook getframe View].barTF -text "Tool bars:"]
            set barF [$barTF getframe]
            set popupTF [TitleFrame [$notebook getframe View].popuptTF -text "Popups over model components:"]
            set popupF [$popupTF getframe]
        $notebook insert end Edit -text Edit
            set genericTF [TitleFrame [$notebook getframe Edit].genericTF -text "All components:"]
            set genericF [$genericTF getframe]
            set linkTF [TitleFrame [$notebook getframe Edit].linkTF -text "All links:"]
            set linkF [$linkTF getframe]
            set flowTF [TitleFrame [$notebook getframe Edit].flowTF -text "Flows:"]
            set flowF [$flowTF getframe]
            set submodelTF [TitleFrame [$notebook getframe Edit].submodelTF -text "Submodels:"]
            set submodelF [$submodelTF getframe]
        $notebook insert end Build -text Build
            set manyWinTF [TitleFrame [$notebook getframe Build].manyWinTF -text "Window positions:"]

            set manyWinF [$manyWinTF getframe]

            set compTF [TitleFrame [$notebook getframe Build].compTF -text "C++ compiler:"]
            set compF [$compTF getframe]
        $notebook insert end Save -text Save
            set canvasTF [TitleFrame [$notebook getframe Save].canvasTF -text "Save optimised canvas data:"]
            set canvasF [$canvasTF getframe]
            set recentTF [TitleFrame [$notebook getframe Save].recentTF -text "Recently used files:"]
            set recentF [$recentTF getframe]
        $notebook insert end Run -text Run
            set oneWinTF [TitleFrame [$notebook getframe Run].oneWinTF -text "Run time environment:"]

            set oneWinF [$oneWinTF getframe]

        $notebook raise View
        pack $displayTF $popupTF $barTF $genericTF $linkTF $flowTF $submodelTF $oneWinTF $manyWinTF $compTF \
                $canvasTF $recentTF $notebook -fill x -padx 4 -pady 4
        ButtonBox $dlg.bbox -default 0
        $dlg.bbox add -name ok -text OK -underline 0 -width 8  \
                -command {PrefSave}
        $dlg.bbox add -name cancel -text Cancel -underline 0 -width 8 \
                -command {PrefDismiss}
        $dlg.bbox add -name default -text Default -underline 0 -width 8 \
                -command {PrefReset}
        #        $dlg.bbox add -name default -text Default -underline 0 -width 8 \
        #                -command {PrefReset ; PrefDismiss}
        $dlg.bbox add -name help -text Help -underline 0 -width 8 \
                -command "::Pref_HelpCommand $notebook"
        #        pack $dlg.bbox -side bottom -anchor e -padx 4 -pady 4
        pack $dlg.bbox -side bottom -padx 4 -pady 8
        
#        ShowMessage debug info "$pref(items)" ok
        
       set maxWidth 0
       foreach item $pref(items) {
            set len [string length [PrefComment $item]]
            if {$len > $maxWidth} {
                set maxWidth $len
            }
       }
       set pref(uid) 0
       foreach item $pref(items) {
#            ShowMessage debug info "$item; [PrefRes $item]" ok
            switch -glob -- [PrefRes $item] {
                init* {set frame $displayF}
                hackBreak {set frame $compF}
                compChoice {set frame $compF}
                comp* {set frame $popupF}
                bigButtons {set frame $barF}
                popupHelp {set frame $barF}
                gridSnap {set frame $genericF}
                deleteEndToEnd {set frame $linkF}
                flowRouting {set frame $flowF}
                defBackground {set frame $submodelF}
                saveExtras {set frame $canvasF}
                recentCount {set frame $recentF}
                helperManager {set frame $oneWinF}
                runControlPosition {set frame $manyWinF}
                slidersPosition {set frame $manyWinF}
                default {set frame $displayTF}
            }
            PrefDialogItem $frame $item $maxWidth
       }
       $notebook compute_size     
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
    label $f.label -text [PrefComment $item] -anchor w
    bind $f.label <Enter> [list QueuePopup AddWidgetPopup [PrefRes $item] %X %Y]
    bind $f.label <Leave> RemovePopup
# Delay packing label until we know whether it goes to the left or right of the item
#    pack $f.label -side left -anchor w
    set default [PrefDefault $item]
    if {[regexp "^CHOICE " $default]} {
        foreach choice [lreplace $default 0 0] {
            incr pref(uid)
            radiobutton $f.c$pref(uid) -text $choice \
                    -variable [PrefVar $item] -value $choice
            pack $f.label -side left -anchor w -padx 2 -pady 2
            pack $f.c$pref(uid) -side left -padx 2 -pady 2
        }
    } else {
        if {$default == "OFF" || $default == "ON"} {
            # This is a boolean
            set varName [PrefVar $item]
# Don't display on or off labels next to checkboxes
#            checkbutton $f.check -variable $varName -command [list PrefFixupBoolean $f.check $varName]
            checkbutton $f.check -variable $varName 
            pack $f.check -side left -padx 2 -pady 2
            pack $f.label -side left -anchor w -fill x -expand on -padx 2 -pady 2
        } else {
            # This is a string or numeric
            entry $f.entry -width 10 -relief sunken
            pack $f.label -side left -anchor w -padx 2 -pady 2
            pack $f.entry -side left -fill x -padx 2 -pady 2
			set pref(entry,[PrefVar $item]) $f.entry
			set varName [PrefVar $item]
			$f.entry insert 0 [uplevel #0 [list set $varName]]
			bind $f.entry <Return> "PrefEntrySet %W $varName"
		}
	}
}
proc PrefFixupBoolean {check varname} {
    upvar #0 $varname var
    # This routine is not called
	# Update the checkbutton text each time it changes
	if {$var} {
        $check config -text "On"
    } else {
        $check config -text "Off"
    }
}
proc PrefEntrySet { entry varName } {
	PrefValueSet $varName [$entry get]
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
    global tcl_platform
    if [catch {
		set old [NetOpen $pref(userDefaults) r]
		set oldValues [split [read $old] \n]
		close $old
	}] {
		set oldValues {}
	}
	if [catch {open $pref(userDefaults).new w} out] {
		.pref.but.label configure -text \
		"Cannot save in $pref(userDefaults).new: $out"
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
	puts $out "!!! Do not edit below here"
# next line is the anti-dibble -- a bug in the example program to check
# if students have been paying attention
	foreach item $pref(items) {
		set varName [PrefVar $item]
		set resName [PrefRes $item]
		if [info exists pref(entry,$varName)] {
			PrefEntrySet $pref(entry,$varName) $varName
		}
		set value [PrefValue $varName $resName]
		puts $out [format "%s\t%s" *${resName}: $value]
	}
    close $out

    # On Windows paths with spaces glob returns a list
    # join makes a string from the list. jmm  15/03/02
    set new [join [glob $pref(userDefaults).new]] 
    set old [file root $new]
#    ShowMessage debug info "new: $new; old $old" ok
    if [catch {file rename -force $new $old} err] {
		Status "Cannot install $new: $err"
		return
	}
    if {[string equal windows $tcl_platform(platform)]} {
	file attributes $old -hidden true
    }
    PrefDismiss
}


#
# Example 42-9
# Read settings from the preferences file.
#

proc PrefReset {} {
	global pref
    # Re-read user defaults
    # This isn't quite right...
	option clear
	PrefReadFile $pref(appDefaults) startup
#	PrefReadFile $pref(userDefaults) user
	# Clear variables
	set items $pref(items)
	set pref(items) {}
	foreach item $items {
		uplevel #0 [list unset [PrefVar $item]]
	}
	# Restore values
	Pref_Add $items
}
proc PrefDismiss {} {
	destroy .pref
	catch {destroy .prefitemhelp}
}

