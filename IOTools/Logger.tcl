# This is a dead simple helper designed to test the object-oriented helper app
# interface.

namespace import itcl::*
set newHelperClass DataLogger20111205
class similescript::$newHelperClass {
    inherit Helper

    public variable curFile
    variable useNodes

    proc Identify {} {
	return "Data logger"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	global SIMILE_PATH
        set useNodes(removeImg) \
	    [image create photo -file "$SIMILE_PATH/Images/Toolbar/remove.gif"]
	set toolbarItems \
                [list [list new.gif "Clear" [code $this Clear]] \
                [list add.gif "Add variables" \
                [code $this AddVariable]] \
                [list slider.gif "Add all variables" \
                [code $this AddAllVariables /]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
	set useNodes(logged) {}
        set frameZone [DIYMakeFrames $winId]
	set f [MakeSubFrames $winId $frameZone {{} {}} {} 0]
	set f [join [lrange [split $f .] 0 end-1] .] ;# remove last level
	pack [::ttk::button $f.head.save -image $::iconImages(save) \
		  -command [code $this SetSaveFile]] \
	    -before $f.head.label -side right
	pack [message $winId.message -text {}]
	BindPopup $f.head.label logs_$this
	BindPopup $f.head.save [tr. {Select file or database for saving}]
	
	if {[string length $state]} { ;# we are restoring 
	    #puts $state
	    package require xml
	    set hsfParser [::xml::parser -ignorewhitespace true \
				-elementstartcommand [code $this StartElement] \
				-characterdatacommand [code $this Stuff]]
	    $hsfParser parse $state
	} else {
	    # new instance so request data from model
	    SetSaveFile
	    $winId.message configure \
		-text "Use + button to add components for logging"
	}
	set useNodes(runCount) 0
    }

    destructor {
	CloseAllFiles
    }

    public method Reset {} {
	if {[info exists useNodes(common_stm)]} {
	    incr useNodes(runCount)
	    if {[catch {$useNodes(common_stm) tables}]} { # not database
		# if filename can be incremented do so, otherwise prompt for new
		if {[regexp {(.*[^0-9])([0-9]*[0-8][0-9]*)(\.[^\.]*)$} \
			 $curFile all base seq ext]} {
		    SetSaveFileTo [append nextFile $base [incr seq] $ext]
		} else {
		    SetSaveFile
		}
	    }
	}
    }
    
    public method Click {path} {
        switch [GetState $winId] {
            adding_inputs {
                if {[string equal SUBMODEL [$modelInst GetModelClass $path]]} {
                    set success [AddAllVariables $path]
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
	UpdateCombined $time
    }

    public method PrepareSaveString {} {
	set State "<hsf simile_version=\"$::env(SIMILE_VERSION)\" helper_id=\"[$this info class]\">\n"
	set shfPath [GetPathChoice .shf [$modelInst cget -modelNode]]
	if {[catch {::fileutil::relative $shfPath $curFile} relFile]} {
	    #puts $relFile
	    set tdLine "<target_file mode=\"absolute\">$curFile</target_file>\n"
	} else {
	    set tdLine "<target_file mode=\"relative\">$relFile</target_file>\n"
	    # will be wrong if modeller changes directory when saving .shf
	}
	append State $tdLine
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
                ScrollToSee $winId.c.canvas $f
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
	pack [::ttk::entry $f.value] -side left -fill x -expand 1
	set useNodes(ticker,$title) $f
	FillTicker $title [$modelInst GetValue $title]
	pack [::ttk::button $f.remove -image $useNodes(removeImg) \
		  -command [code $this Remove $title]] -side right
	return yes
    }

    method AddAllVariables {prefix} {
        foreach node [GetObjectList] {
            set title [GetCaptionPathFromId $node]
            if {[string first $prefix $title]==0} {
		InsertLogEntry $title 1
            }
	}
    }

    method Remove {title} {
        set f $useNodes(ticker,$title)
        pest20050803::Prune $winId $f
	set index [lsearch -exact $useNodes(logged) $title]
	set useNodes(logged) \
	    [lreplace $useNodes(logged) $index $index]
    }
    
    method Clear {} {
	foreach title $useNodes(logged) {
	    Remove $title
	}
    }

    method SetSaveFile {} {
	foreach same {1 0} {
	    if {([info exists curFile] && [IsBogusURL $curFile])==$same} {
		set newFile [ChooseDatabase $winId "MySQL log table"]
	    } else {
		set newFile [ChooseFile log.csv [tr. {Log file}] 1 \
				 [$modelInst cget -modelNode]]
	    }
	    if {$newFile ne {}} break
	}
	if {[info exists curFile] && [string equal $curFile $newFile] || \
		![string length $newFile]} return
	SetSaveFileTo $newFile
    }

    method SetSaveFileTo {newFile} {
	CloseAllFiles
	set curFile $newFile
	set ::msgs(logs_$this) [format [tr. {Current data sink: %1$s}] $curFile]
# don't write current values, reset does this anyway
#	if {[llength $useNodes(logged)]} {
#	    Display [$modelInst GetCurrentTime] 1 1 ;# write current vals
#	}
    }

    method FillTicker {path value} {
	set entry $useNodes(ticker,$path).value
	$entry config -state normal
	$entry delete 0 end
	$entry insert 0 $value
	$entry config -state readonly
    }
    
    method UpdateCombined {time} {
	if {[info exists useNodes(common_stm)]} {
	} else {
	    if {[file extension $curFile] eq ".csv"} {
		set useNodes(common_stm) [open $curFile w]
		set hdrs Time
		foreach path $useNodes(logged) {
		    PutIndexCombos hdrs [$modelInst GetValue $path] \
			, [file tail $path]
		}
		puts $useNodes(common_stm) $hdrs
	    } else {
		set useNodes(common_stm) [DBHandleFor $curFile]
	    }		
	}
	if {[catch {$useNodes(common_stm) tables} tList]} { # writing csv
	    puts -nonewline $useNodes(common_stm) $time
	    foreach path $useNodes(logged) {
		set toLog [$modelInst GetValue $path]
		FillTicker $path $toLog
		PutValsOnly vals $toLog
	    }
	    puts $useNodes(common_stm) $vals
	    flush $useNodes(common_stm)
	} else {
	    set curTab "Run $useNodes(runCount)"
	    if {[lsearch $tList $curTab] == -1} {
		set sqlStr "CREATE TABLE `$curTab` (`Time"
		foreach path $useNodes(logged) {
		    PutIndexCombos sqlStr [$modelInst GetValue $path] \
			"` text, `" [file tail $path]
		}
		append sqlStr "` text)"
		$useNodes(common_stm) allrows $sqlStr
	    }
	    # now add a row of values
	    set sqlStr "INSERT INTO `$curTab` (`Time"
	    foreach path $useNodes(logged) {
		PutIndexCombos sqlStr [$modelInst GetValue $path] \
		    "`, `" [file tail $path]
	    }
	    append sqlStr "`) VALUES ($time"
	    foreach path $useNodes(logged) {
		set toLog [$modelInst GetValue $path]
		FillTicker $path $toLog
		PutValsOnly sqlStr $toLog
	    }
	    append sqlStr ")"
	    $useNodes(common_stm) allrows $sqlStr
	}
    }

    method PutIndexCombos {pstr val sep gone} {
	upvar 1 $pstr str
	if {[llength $val]>1} {
	    foreach {idx elt} $val {
		PutIndexCombos str $elt $sep \
		    [join [concat [split $gone /] [list $idx]] /]
	    }
	} else {
	    append str $sep$gone
	}
    }

    method TableWithHeaders {$curTab} {
    }
    
    method CloseAllFiles {} {
	if {[info exists useNodes(common_stm)]} {
	    if {[catch {$useNodes(common_stm) close}]} { # was database
		close $useNodes(common_stm) ;# was file
	    }
	    unset useNodes(common_stm)
	}
    }

    # for parsing XML status
    method StartElement {name attList args} {
	set useNodes(inElt) $name
	switch [lindex $attList 0] {
	    whether { ;# to separate files -- no longer used
		if {![lindex $attList 1]} {
		    #ColumnMode
		} else {
		    #MultiFileMode
		}
	    } mode {
		set useNodes(fileMode) [lindex $attList 1]
	    }
	}
    }

    method Stuff {contents} {
	switch $useNodes(inElt) {
	    target_file {
		if {$useNodes(fileMode) eq "relative"} {
		    set node [$modelInst cget -modelNode]
		    set shfPath [GetPathChoice .shf $node]
		    SetSaveFileTo [file normalize \
				       [file join $shfPath $contents]]
		    #puts "joined $shfPath and $contents to get $curFolder"
		} else {
		    SetSaveFileTo $contents
		}
	    } component {
		InsertLogEntry $contents 1
	    }
	}
    }
}
