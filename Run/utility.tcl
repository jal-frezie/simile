# utility.tcl
# ===========

# This file contains general purpose utilities in Tcl, which are
# likely to be used both in the AME editor interface and the
# stand-alone run time environment.

#############################################################################

# Just so I know where this is...
# Thanks to tk_abandon, I sometimes put several dialogues up at once, which,
# thanks to a bug in tcltk, gets the wrong results for the lower ones...

proc ShowMessage { title icon string resps {parent {}}} {
    set mBoxCmd [list tk_messageBox -title $title -icon $icon \
		     -message $string -type $resps]
    set active [focus]
    if {[llength $active]} {
	lappend mBoxCmd -parent $active
    }
    set act [eval $mBoxCmd]
    update
    return $act
}

# ChooseFile -- this is a wrapper for the Tcl file dialog, which sets
# the path name to start looking in explicitly as use of the
# -initialdir switch under Linux causes horrible misbehaviour if the
# filename has spaces in it.

proc ChooseFile { preferred title canbenew } {
    global __tk_filedialog chosenPaths custom

    set fileType [file extension $preferred]

    if {[info exists chosenPaths($fileType)]} {
	set __tk_filedialog(selectPath) $chosenPaths($fileType)
    } else {
    if {[info exists chosenPaths(latest)]} {
	set __tk_filedialog(selectPath) $chosenPaths(latest)
    } else {
    if {[info exists $custom(prefDir)/Examples]} {
	set __tk_filedialog(selectPath) $custom(prefDir)/Examples
    } else {
	set __tk_filedialog(selectPath) [pwd]
}   }   }

# __tk_etc should set starting directory, but just in case...
    set prevDir [pwd]
    cd $__tk_filedialog(selectPath)
    switch $fileType {
	.sml {
	    set typeList [list .sml .sim .ame]
	    set desc Models
	    set recordEntry 1
	} .gif {
	    set typeList [list .gif .jpg .jpeg]
	    set desc Images
	    set recordEntry 0
	} {} {
	    set typeList {}
	    set desc Directories
	    set recordEntry 0
	} default {
	    set typeList [list $fileType]
	    set desc "$fileType files"
	    set recordEntry 0
	}
    }
    set typeList [list [list $desc $typeList]]
    set switches [list -title $title -defaultextension $fileType \
		      -filetypes $typeList]
    set active [focus]
    if {[llength $active]} {
	lappend switches -parent $active
    }
    if {$canbenew} {
        set cmd tk_getSaveFile
	lappend switches  -initialfile $preferred
    } else {
        set cmd tk_getOpenFile
    }
    set chosenFile [eval $cmd $switches]
    cd $prevDir
    if {[string compare $chosenFile {}]} {
	RecordPathChoice $fileType $chosenFile $recordEntry
    }
    return $chosenFile
}

proc RecordPathChoice {fileType chosenFile recordEntry} {
    global chosenPaths custom
    set chosenPaths($fileType) \
	    [set chosenPaths(latest) [file dirname $chosenFile]]
    if {$recordEntry} {
	set custom(hotlist) [linsert $custom(hotlist) 0 $chosenFile]
    }
}

# This deals with the quirk of Netware file systems that if the user has
# read/write access to a file it cannot be opened readonly, or something...

proc NetOpen {name way} {
    if {[catch {open $name $way} stream]} {
	if {[catch {open $name r+} stream]} {
	    error "Could not open $name $way or r/w"
	}
    }
    return $stream
}
