# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass DataLogger20111205
oo::class create iotool::$newHelperClass {
    superclass iotool::Helper

    variable curFile useNodes winId modelInst

    self {
	method identify {} {
	    return "Data logger"
	}
    }

    constructor {modelInst winTitle {state {}}} {
	global SIMILE_PATH
	next $modelInst $winTitle

        set useNodes(removeImg) \
	    [image create photo -file "$SIMILE_PATH/Images/Toolbar/remove.gif"]
	set toolbarItems \
	    [list [list new.gif "Clear" [namespace code [list my Clear]]] \
                [list add.gif "Add variables" \
		     [namespace code [list my AddVariable]]] \
                [list slider.gif "Add all variables" \
		     [namespace code [list my AddAllVariables /]]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
	set useNodes(logged) {}
        set frameZone [DIYMakeFrames $winId]
	set f [MakeSubFrames $winId $frameZone {{} {}} {} 0]
	#	set f [join [lrange [split $f .] 0 end-1] .]
	# remove last level not needed as null leaf no longer made
	pack [::ttk::button $f.head.save -image $::iconImages(save) \
		  -command [namespace code [list my SetSaveFile]]] \
	    -before $f.head.label -side right
	pack [message $winId.message -text {}]
	BindPopup $f.head.label logs_[self]
	BindPopup $f.head.save [tr. {Select file or database for saving}]
	
	if {[string length $state]} { ;# we are restoring 
	    #puts $state
	    package require xml
	    set hsfParser [::xml::parser -ignorewhitespace true \
			       -elementstartcommand [namespace code [list my StartElement]] \
			       -characterdatacommand [namespace code [list my Stuff]]]
	    $hsfParser parse $state
	} else {
	    # new instance so request data from model
	    my SetSaveFile
	    $winId.message configure \
		-text "Use + button to add components for logging"
	}
	set useNodes(runCount) 0
    }

    destructor {
	my CloseAllFiles
	next
    }

    method Reset {} {
	if {[info exists useNodes(common_stm)]} {
	    incr useNodes(runCount)
	    if {[catch {$useNodes(common_stm) tables}]} { # not database
		# if filename can be incremented do so, otherwise prompt for new
		if {[regexp {(.*[^0-9])([0-9]*[0-8][0-9]*)(\.[^\.]*)$} \
			 $curFile all base seq ext]} {
		    my SetSaveFileTo [append nextFile $base [incr seq] $ext]
		} else {
		    my SetSaveFile
		}
	    }
	}
    }
    
    method click {path} {
        switch [GetState $winId] {
            adding_inputs {
                if {[string equal SUBMODEL [$modelInst getModelClass $path]]} {
                    set success [my AddAllVariables $path]
                } else {
                    set success [my InsertLogEntry $path 1]
                }
                if {[llength $success]} {
                    $winId.message configure -text {}
                    $modelInst releaseClicks
                }
	    }
	}
    }

    method display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	my UpdateCombined $time
    }

    method prepareSaveString {} {
	set State "<hsf simile_version=\"$::env(SIMILE_VERSION)\" helper_id=\"[self class]\">\n"
	set shfPath [GetPathChoice .shf [$modelInst getNode]]
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
	SetState $winId $State
    }
	
# end of methods called by simile
# start of methods defined in this helper
    method AddVariable {} {
        $winId.message configure -text "Click on a variable to allow its values to be logged."
        SetState $winId adding_inputs
        $modelInst grabClicks [self]
    }
    
    method InsertLogEntry {title nest} {
        set levels [split $title /]
        if {$nest} {
            set f [MakeSubFrames $winId $winId.c.canvas.frame $levels {} 0]
            if {[llength [winfo children $f]]>1} { # new one will have tree
                ScrollToSee $winId.c.canvas $f
                return $f
            }
	    set lbg [[winfo parent $f].head cget -bg]
	    #$f configure -bg $lbg
        } else {
            set f $winId
	    set lbg blue
        }

	lappend useNodes(logged) $title
	pack [label $f.caption -text [lindex $levels end]: -bg $lbg] -side left
	pack [::ttk::entry $f.value] -side left -fill x -expand 1
	set useNodes(ticker,$title) $f
	my FillTicker $title [$modelInst getValue $title]
	pack [::ttk::button $f.remove -image $useNodes(removeImg) \
		  -command [namespace code [list my Remove $title]]] -side right
	return yes
    }

    method AddAllVariables {prefix} {
        foreach node [GetObjectList] {
            set title [GetCaptionPathFromId $node]
            if {[string first $prefix $title]==0} {
		if {[$modelInst getModelClass $title] ne "SUBMODEL"} {
		    my InsertLogEntry $title 1
		}
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
	    my Remove $title
	}
    }

    method SetSaveFile {} {
	foreach same {1 0} {
	    if {([info exists curFile] && [IsBogusURL $curFile])==$same} {
		set newFile [ChooseDatabase $winId "MySQL log table"]
	    } else {
		set newFile [ChooseFile log.csv [tr. {Log file}] 1 \
				 [$modelInst getNode]]
	    }
	    if {$newFile ne {}} break
	}
	if {[info exists curFile] && [string equal $curFile $newFile] || \
		![string length $newFile]} return
	my SetSaveFileTo $newFile
    }

    method SetSaveFileTo {newFile} {
	my CloseAllFiles
	set curFile $newFile
	set ::msgs(logs_[self]) [format [tr. {Current data sink: %1$s}] $curFile]
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
	set brkr [PrefValue custom(columnSeparator) columnSeparator]
	if {[info exists useNodes(common_stm)]} {
	} else {
	    package require csv
	    if {[file extension $curFile] eq ".csv"} {
		set useNodes(common_stm) [open $curFile w]
		set hdrs Time
		foreach path $useNodes(logged) {
		    my PutIndexCombos hdrs [$modelInst getValue $path] "" \
			[file tail $path]
		}
		puts $useNodes(common_stm) [::csv::join $hdrs $brkr]
	    } else {
		set useNodes(common_stm) [DBHandleFor $curFile]
	    }		
	}
	if {[catch {$useNodes(common_stm) tables} tList]} { # writing csv
	    set vals $time
	    foreach path $useNodes(logged) {
		set toLog [$modelInst getValue $path]
		my FillTicker $path $toLog
		PutValsOnly vals $toLog
	    }
	    puts $useNodes(common_stm) [::csv::join $vals $brkr]
	    flush $useNodes(common_stm)
	} else {
	    set curTab "Run $useNodes(runCount)"
	    if {[lsearch $tList $curTab] == -1} {
		set sqlStr "CREATE TABLE `$curTab` (`Time"
		foreach path $useNodes(logged) {
		    my PutIndexCombos sqlStr [$modelInst getValue $path] \
			"` text, `" [file tail $path]
		}
		append sqlStr "` text)"
		$useNodes(common_stm) allrows $sqlStr
	    }
	    # now add a row of values
	    set sqlStr "INSERT INTO `$curTab` (`Time"
	    foreach path $useNodes(logged) {
		my PutIndexCombos sqlStr [$modelInst getValue $path] \
		    "`, `" [file tail $path]
	    }
	    append sqlStr "`) VALUES ("
	    set sqlSubStr $time
	    foreach path $useNodes(logged) {
		set toLog [$modelInst getValue $path]
		my FillTicker $path $toLog
		PutValsOnly sqlSubStr $toLog
	    }
	    append sqlStr [::csv::join $sqlSubStr $brkr] 
	    append sqlStr ")"
	    $useNodes(common_stm) allrows $sqlStr
	}
    }

    method PutIndexCombos {pstr val sep gone} {
	upvar 1 $pstr str
	if {[string is list $val] && [llength $val]>1} {
	    foreach {idx elt} $val {
		my PutIndexCombos str $elt $sep \
		    [join [concat [split $gone /] [list $idx]] /]
	    }
	} elseif {$sep ne ""} {
	    append str $sep$gone
	} else { ;# build a list for csv package
	    lappend str $gone
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
	if {[string trim $contents]==""} return ;# failure to ignore whitespace
	set node [$modelInst getNode]
	switch $useNodes(inElt) {
	    target_file {
		if {$useNodes(fileMode) eq "relative"} {
		    set shfPath [GetPathChoice .shf $node]
		    my SetSaveFileTo [file normalize \
				       [file join $shfPath $contents]]
		    #puts "joined $shfPath and $contents to get $curFolder"
		} else {
		    my SetSaveFileTo $contents
		}
	    } component {
		set updated [::gen3d1::VerifyVariables $node \
				 [[self class] identify] [list $contents]]
		if {[llength $updated]} {
		    my InsertLogEntry [lindex $updated 0] 1
		}
	    }
	}
    }
}
