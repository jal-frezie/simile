#
# Example 42-1
# Preferences initialization.
#
# proc PrefSave {} modified to use Windows short filenames 

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

proc Pref_Dialog {} {
	global pref
	if [catch {toplevel .pref}] {
		raise .pref
	} else {
		wm title .pref "Preferences"
		set buttons [frame .pref.but -bd 5]
		pack .pref.but -side top -fill x
		button $buttons.quit -text Dismiss \
			-command {PrefDismiss}
		button $buttons.save -text Save \
			-command {PrefSave}
		button $buttons.reset -text Reset \
			-command {PrefReset ; PrefDismiss}
		label $buttons.label \
			 -text "Mouse over labels for info on each item"
		pack $buttons.label -side left -fill x
		pack $buttons.quit $buttons.save $buttons.reset \
			-side right -padx 4

		frame .pref.b -borderwidth 2 -relief raised
		pack .pref.b -fill both
		set body [frame .pref.b.b -bd 10]
		pack .pref.b.b -fill both

		set maxWidth 0
		foreach item $pref(items) {
			set len [string length [PrefComment $item]]
			if {$len > $maxWidth} {
				set maxWidth $len
			}
		}
		set pref(uid) 0
		foreach item $pref(items) {
			PrefDialogItem $body $item $maxWidth
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
	pack $f -fill x
	label $f.label -text [PrefComment $item] -width $width
	bind $f.label <Enter> [list QueuePopup \
		"AddWidgetPopup [PrefRes $item] %X %Y"]
	bind $f.label <Leave> RemovePopup
	pack $f.label -side left
	set default [PrefDefault $item]
	if {[regexp "^CHOICE " $default]} {
		foreach choice [lreplace $default 0 0] {
			incr pref(uid)
			radiobutton $f.c$pref(uid) -text $choice \
				-variable [PrefVar $item] -value $choice
			pack $f.c$pref(uid) -side left
		}
	} else {
		if {$default == "OFF" || $default == "ON"} {
			# This is a boolean
			set varName [PrefVar $item]
			checkbutton $f.check -variable $varName \
				-command [list PrefFixupBoolean $f.check $varName]
			PrefFixupBoolean $f.check $varName
			pack $f.check -side left
		} else {
			# This is a string or numeric
			entry $f.entry -width 10 -relief sunken
			pack $f.entry -side left -fill x -expand true
			set pref(entry,[PrefVar $item]) $f.entry
			set varName [PrefVar $item]
			$f.entry insert 0 [uplevel #0 [list set $varName]]
			bind $f.entry <Return> "PrefEntrySet %W $varName"
		}
	}
}
proc PrefFixupBoolean {check varname} {
	upvar #0 $varname var
	# Update the checkbutton text each time it changes
	if {$var} {
		$check config -text On
	} else {
		$check config -text Off
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
	global pref
    global tcl_platform
    if [catch {
		set old [open $pref(userDefaults) r]
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
	puts $out "!!! <put date here>"
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
	PrefDismiss
}


#
# Example 42-9
# Read settings from the preferences file.
#

proc PrefReset {} {
	global pref
	# Re-read user defaults
	option clear
	PrefReadFile $pref(appDefaults) startup
	PrefReadFile $pref(userDefaults) user
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
