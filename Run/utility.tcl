# utility.tcl
# ===========

# This file contains general purpose utilities in Tcl, which are
# likely to be used both in the AME editor interface and the
# stand-alone run time environment.

#############################################################################

# Just so I know where this is...
# Thanks to tk_abandon, I sometimes put several dialogues up at once, which,
# thanks to a bug in tcltk, gets the wrong results for the lower ones...

proc ShowMessage { title icon string resps {parent .}} {
    return [tk_messageBox -title $title -icon $icon \
	-message $string -type $resps -parent $parent]
}

# ChooseFile -- this is a wrapper for the Tcl file dialog, which sets
# the path name to start looking in explicitly as use of the
# -initialdir switch under Linux causes horrible misbehaviour if the
# filename has spaces in it.

proc ChooseFile { preferred title canbenew } {
    global __tk_filedialog chosenPaths env

    set fileType [file extension $preferred]

    if {[info exists chosenPaths($fileType)]} {
	set __tk_filedialog(selectPath) $chosenPaths($fileType)
    } else {
    if {[info exists chosenPaths(latest)]} {
	set __tk_filedialog(selectPath) $chosenPaths(latest)
    } else {
    if {[info exists env(START_DIR)]} {
	set __tk_filedialog(selectPath) $env(START_DIR)
    } else {
	set __tk_filedialog(selectPath) [pwd]
}   }   }

# __tk_etc should set starting directory, but just in case...
    set prevDir [pwd]
    cd $__tk_filedialog(selectPath)
    switch $fileType {
	.sml {
	    set typeList [list .sml .sim .ame]
	    set recordEntry 1
	} .gif {
	    set typeList [list .gif .jpg .jpeg]
	    set recordEntry 0
	} default {
	    set typeList [list $fileType]
	    set recordEntry 0
	}
    }
    set typeList [list [list "$fileType files" $typeList]]
    set chosenFile [[expr $canbenew?{tk_getSaveFile}:{tk_getOpenFile}] \
	    -title $title -defaultextension $fileType -filetypes $typeList \
	    -initialfile $preferred]
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
