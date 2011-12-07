# This is a dead simple helper designed to test the object-oriented helper app
# interface.

namespace import itcl::*
set newHelperClass DataLogger20111205
class similescript::$newHelperClass {
    inherit Helper

    variable curFolder
    variable useNodes

    proc Identify {} {
	return "Data logger"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
        set useNodes(removeImg) \
	    [image create photo -file "../Images/Toolbar/remove.gif"]
	set toolbarItems \
                [list [list new.gif "Clear" [namespace code "Clear $winId"]] \
                [list add.gif "Add variables" \
                [code $this AddVariable]] \
                [list slider.gif "Add all variables" \
                [code $this AddAllVariables /]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
        MakeFrames $winId
	set f [MakeSubFrames $winId $winId.c.canvas.frame {{} {}} {} 0]
	set f [join [lrange [split $f .] 0 end-1] .] ;# remove last level
	pack [::ttk::button $f.head.save -image $::iconImages(save) \
		  -command [code $this SetSavePath]] \
	    -before $f.head.label -side right
	BindPopup $f.head.label logs_$this
	BindPopup $f.head.save [tr. {Choose folder for logs}]
	
	if {[string length $state]} { ;# we are restoring 
	    #puts $state
	    package require xml
	    set hsfParser [::xml::parser -ignorewhitespace true \
				-elementstartcommand [code $this StartElement] \
				-characterdatacommand [code $this Stuff]]
	    $hsfParser parse $state
	} else {
	    # new instance so request data from model
	    SetSavePathTo [GetPathChoice .csv [GetNode]]
	    pack [message $winId.message \
		      -text "Use + button to add components for logging"]
	}
    }

    destructor {
	CloseAllFiles
    }

    public method Click {path} {
        switch [GetState $winId] {
            adding_inputs {
                if {[string equal SUBMODEL [$modelInst GetModelClass $path]]} {
                    set success [AddAllVariables $winId $fullCapt]
                } else {
                    set success [InsertLogEntry $path 1]
                }
                if {[llength $success]} {
                    $winId.message configure -text {}
                    $modelInst ReleaseClicks
                }
	    }
	}
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	foreach path $useNodes(logged) {
	    UpdateFile $path $time
	}	    
    }

    public method PrepareSaveString {} {
	set State "<hsf simile_version=\"$::env(SIMILE_VERSION)\" helper_id=\"[$this info class]\">\n"
	append State "<target_dir mode=\"absolute\">$curFolder</target_dir>\n"
	append State <components>\n
	foreach item $useNodes(logged) {
	    append State <component>$item</component>\n
	}
	append State </components>\n</hsf>\n
    }
	
# end of methods called by simile
# start of methods defined in this helper
    method AddVariable {} {
        $winId.message configure -text "Click on a variable to allow its values to be logged."
        SetState $winId adding_inputs
        $modelInst GrabClicks $this
    }
    
    method InsertLogEntry {title nest} {
        set levels [split $title /]
        if {$nest} {
            set f [MakeSubFrames $winId $winId.c.canvas.frame $levels {} 0]
            if {[winfo exists $f]} {
                $winId.c.canvas see $f
                return $f
            } else {
                pack [frame $f] -fill x -expand true
            }
	    set lbg [[winfo parent $f].head cget -bg]
	    $f configure -bg $lbg
        } else {
            set f $winId
	    set lbg blue
        }

	lappend useNodes(logged) $title
	pack [label $f.caption -text [lindex $levels end]: -bg $lbg] -side left
	pack [::ttk::button $f.remove -image $useNodes(removeImg) \
		  -command [code $this Remove $title]] -side right
	UpdateFile $title [$modelInst GetCurrentTime]
	return yes
    }

    method Remove {title} {
        set levels [split $title /]
        set f [MakeSubFrames {} $winId.c.canvas.frame $levels {} 0]
        pest20050803::Prune $winId $f
	set index [lsearch $useNodes(logged) $title]
	close $useNodes($title.stm)
	unset useNodes($title.stm)
	set useNodes(logged) \
	    [lreplace $useNodes(logged) $index $index]
    }
    
    method SetSavePath {} {
	set newFolder [tk_chooseDirectory -title [tr. {Folder for log files:}] \
			   -initialdir $curFolder -parent $winId]
	if {![string length $newFolder] || \
		[string equal $curFolder $newFolder]} return
	SetSavePathTo $newFolder
    }

    method SetSavePathTo {newFolder} {
	CloseAllFiles
	set curFolder $newFolder
	if {![file isdir $curFolder]} {
	    file mkdir $curFolder
	}
	set ::msgs(logs_$this) [format [tr. {Current folder: %1$s}] $curFolder]
	if {[info exists useNodes(logged)]} {
	    Display [$modelInst GetCurrentTime] 1 1 ;# write current vals
	}
    }

    method UpdateFile {path time} {
	set val [lindex [$modelInst GetValue $path] 0]
	if {![info exists useNodes($path.stm)]} {
	    set name [file join $curFolder [file tail $path].csv]
	    set useNodes($path.stm) [set out [open $name w]]
	    
# code to write indices lifted from snap tool
	    set nst 0
	    set v1 $val
	    while {[llength $v1]>1} {
		incr nst
		set v1 [lindex $v1 1]
	    }
	    set lh time
	    for {set idx 1} {$idx<=$nst} {incr idx} {
		puts -nonewline $out $lh
		set lh {}
		PutIndNo $out -$idx $val
		puts $out {}
	    }
	} else {
	    set out $useNodes($path.stm)
	}
	puts -nonewline $out $time
	PutValsOnly $out $val
	puts $out {}
    }

    method CloseAllFiles {} {
	foreach stmName [array names useNodes *.stm] {
	    close $useNodes($stmName)
	    unset useNodes($stmName)
	}
    }

    # for parsing XML status
    method StartElement {name attList args} {
	set useNodes(inElt) $name
    }

    method Stuff {contents} {
	switch $useNodes(inElt) {
	    target_dir {
		SetSavePathTo $contents
	    } component {
		InsertLogEntry $contents 1
	    }
	}
    }
}