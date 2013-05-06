# Simile source code file: Run/support.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures that have to go in the same interpreter as
# the model, e.g., because they are called from it, or pass data using upvar.
# Actually none of them have to but it makes things more consistent with the
# c++ implementation.

# var containing namespace id called 'this' for compatibility with c++
set this ::AME_model<>

# searching through records like this is not the best way -- try and change
# the tcl model code so the node id is the index

proc FindRecord {node} {
    global nodedata

    foreach record [array names nodedata] {
	if {[string equal $node [lindex $nodedata($record) 0]]} {
	    return $nodedata($record)
	}
    }
    return {}
}

proc getinfo {node field} {
    return [lindex [FindRecord $node] [expr $field+1]]
}

# Graph handling stuff

proc setup_graph_data {args} {
    eval {graph_table 22} $args
}

proc release_graph_data {graph_data_pointer} {
    # no need to release in tcl
}

# this procedure takes the data describing a function entered as a graph, and a
# point on the x axis, and returns the y axis point. It is called from the
# procedure that executes the model.


proc graphpoint {xval index} {
    graph_table 23 $index $xval
}

# Stuff related to getting values

proc setup_enum_type_data {args} {
}

proc tcl_insert {node newVs} {
    global nodedata

    set line [FindRecord $node]
    if {[llength $line]} {
	set tree [lindex $line 8]
	set type [lindex $line 1]
	set dims [GetTclCompProperty dummy Dims $node]
	return [list [FillValue ::AME_model<> $tree $type $dims {} 0 $newVs]]
    }
    return novalue
}
proc ExplainError {myNode errList origError} {
    set severity -1
    set what [lindex $errList 0]
    set dest [lindex $errList 1]
    set mtime [lindex $errList 2]
    set mstep [lindex $errList 3]
    set whoopsie [lindex $errList 4]
    switch $what {
	evalmodel {set operation "calculating the value of"}
	updatemodel {set operation "updating the state"}
	resetmodel {set operation "resetting"}
	default {set operation "doing $what for"}
    }
#	advancemodel {set operation "advancing the time point for"}
    set target something
    if {[string is integer -strict $dest]} { ;# graph id (tcl only for now)
	foreach {n record} [array get ::nodedata] {
	    if {[lindex $record 9]==$dest} {
		set target "[GetFullCaption $record] (node [lindex $record 0])"
		break;
	    }
	}
    } elseif {[string first :: $dest]>-1} { ;# a Tcl namespace hierarchy
	set targetList [DescribeComponent $myNode $dest]
	if {![namespace exists [join [lrange [split $dest :] 0 end-2] :]]} {
	    set whoopsie dest_missing
# Just remind me, when does this happen? 
# Probably never, due to base index range checking
	}
	set target [lindex $targetList 0]
    } elseif {![string equal none $dest]} { ;# caption extracted by c++ error handling
	set target $dest
    }

    switch -glob -- $whoopsie {
	"can't read \"*\": no such element in array" - 
	"can't read \"*\": no such variable" {
	    set ref [lindex [split $whoopsie \"] 1]
	    set sourceList [DescribeComponent $myNode $ref] 
	    if {![namespace exists [join [lrange [split $ref :] 0 end-2] :]]} {
		set problem "it found that there was no submodel instance when trying to get [lindex $sourceList 0]"
	    } else {
		set problem "it found that there was no value for [lindex $sourceList 0]"
	    }
	} dest_missing {
	    set problem "it found there was no instance with these indices. This may mean that you have specified a base model instance by an index which is out of range"
	} "User-defined interruption code *" {
	    set code [lindex $whoopsie end]
	    set problem "there was a user-defined interruption: $code"
	    set severity 0
	} "abort request from the user" {
	    set problem "the user chose to abort a long operation"
	    set severity 0
	} discontinuity {
	    set problem "there was a discontinuity which could not be dealt with by adaptive step size control"
	    set severity 0
	} event {
	    set problem "there was a limit event, producing a pause"
	    set severity 0
	} "Illegal operation signal *" {
	    set code [lindex $whoopsie end]
	    set which [lindex {SIGEOF SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP 
		SIGIOT SIGEMT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE 
		SIGALRM SIGTERM SIGUSR1 SIGUSR2 SIGCHLD SIGPWR SIGWINCH 
		SIGURG SIGIO SIGSTOP SIGTSTP SIGCONT SIGTTIN
		SIGTTOU SIGVTALRM SIGPROF} $code]
	    set problem "there was an OS signal: $code ($which)"
	} "domain error: argument not in valid range" -
	"floating-point value too large to represent" -
	"divide by zero" {
	    set problem "there was a math error: $whoopsie"
	} default {
	    # could not get cause of error, raise again as general problem
	    set problem "there was a $whoopsie"
	}
    }
    
    switch -- $mstep {
	-2 {
	    set action initialization
	    set timing {}
	    #		ScrubRun $node 0
	} -1 {
	    set action parameterization
	    set timing {}
	    #		ScrubRun $node 0
	} 0 {
	    set action reset
	    set timing {}
	} default {
	    set action execution
	    set timing " at time $mtime"
	}
    }
    switch -- $severity {
	-1 {
	    set specifics [list model_crash $operation $target $action $timing \
		       $problem $origError]
	    set icon warning
	} 0 {
	    set specifics [list model_pause $operation $target $action $timing \
		       $problem]
	    set icon info
	}
    }
    ExecQuery $specifics $icon top {} ok
    AddLogEntry $myNode $specifics
    # do it after idle so this process is not hung till user responds
#    RaiseModelWindow $myNode
    return $severity
}

proc DescribeComponent {topNode ref} {
    set hierarchy [split $ref :] ;# joins actually :: so every other elt null
    set inds {} ;# inds no longer needed, kept as spare part
    set context [MakeContext $topNode [lrange $hierarchy 0 end-2]]
    set variable [lindex $hierarchy end]
    set br [string first \( $variable]
    if {$br == -1} {
	set captPath [NewCaptionIfAvail $topNode $hierarchy 1 $variable]
	set vdesc "variable [lindex $captPath 0]"
    } else {
	set locals [split [string range $variable [incr br 1] end-1] ,]
	eval {lappend inds} $locals
	set captPath [NewCaptionIfAvail $topNode $hierarchy \
			  [concat $locals [list 1]] \
			  [string range $variable 0 [incr br -2]]]
	set vdesc "element [join [lrange $captPath 1 end-1] ,] of variable [lindex $captPath 0]"
    }
# next turn last arg into node
    return [list $vdesc$context $inds]
}

proc NewCaptionIfAvail {topNode dest inds in_code} {
    global nodedata

    foreach record [array names nodedata] {
	set texts [lindex $nodedata($record) 13]
	if {[string equal $in_code [lindex $texts 4]]} {
	    set allETs [GetTclCompProperty $topNode Trans \
		      [lindex $nodedata($record) 0]]
	    set useETs [lrange $allETs end-[expr {[llength $inds]-1}] end]
	    return [concat [list [set ::[lindex $texts 0]]] \
			[TransEnums $useETs $inds]]
	}
    }
#    foreach record [array names nodedata] {
#	if {![catch {burrow_to ::AME_model<> \
#			 [lindex $nodedata($record) 8] $indices} ptr]} {
#	    if {[string equal $dest $ptr]} {
#		return [set ::[lindex $nodedata($record) end 0]]
#	    }
#	}
#    }
    return [concat [list $in_code] $inds] ;# no matching node for caption/ETs
}

proc MakeContext {topNode levels} {
    upvar 1 inds inds
    if {[llength $levels]<=4} {
	return {}
    } else {
	set rest [MakeContext $topNode [lrange $levels 0 end-2]]
	set this [lindex $levels end]
	set obr [string first < $this]
	set cbr [string first > $this]
	set handle [string range $this 0 [incr obr -1]]
	set locals [string range $this [incr obr 2] [incr cbr -1]]
	eval {lappend inds} $locals
	set levelCapt [NewCaptionIfAvail $topNode [join $levels :] \
			   $locals $handle]
	set submodel "submodel [lindex $levelCapt 0]"
	if {[llength $locals]} {
	    set submodel "instance [join [lrange $levelCapt 1 end] ,] of $submodel"
	}
	return " in $submodel$rest"
    }
}

proc collect {tgt index count args} {
    global paramLocns
    set val [BringParameter $tgt $paramLocns($index,arr) \
		 $paramLocns($index,nod) $args 0]
}

proc BringParameter {tgt array node inds up} {
#puts "looking for $array\($sub\)"
    upvar \#0 $array inputSrc
    if {$up} {
	set tmp [set $tgt]
    }
    for {set ind1 0} {$ind1<=[llength $inds]} {incr ind1} {
	set sub [join [concat $node [lrange $inds $ind1 end]] ,]
# Check that input source exists, it will not if model is being initialized
	if {[info exists inputSrc($sub)]} {
	    set $tgt $inputSrc($sub)
	    if {$up} {
		set inputSrc($sub) $tmp
	    }
	    return
	}
    }
    if {$up} {
	set inputSrc($sub) $tmp
    }
}

proc insert_to_pipe {ns_extras when what} {
    global event
    upvar \#0 $ns_extras extras

    set phase [expr {int([glob_element ts 0])}]
    set forReal [expr {$phase==5 || $phase==6}]
    if {$forReal && $what} {
	set then [expr {$when+[glob_element ts $::phasecount]}]
	set where [llength $extras]
	while {$where>0 && [lindex $extras $where-2]>$then} {
	    incr where -2
	}
	set extras [linsert $extras $where $then $what]
    }
# prediction must be checked here because it is done last and new item may
# be the predicted
    if {[llength $extras] && [lindex $extras 0]<$event(predict)} {
	set event(predict) [lindex $extras 0]
    }
}
    
proc retract_from_pipe {ns_extras id} {
    global event
    upvar \#0 $ns_extras extras

    if {[glob_element dts 0]<=0} {
	set extras {}
	return 0
    }
    set now [glob_element ts $::phasecount]
    set where 0
    set unload 0
    while {$where<[llength $extras] && [lindex $extras $where]<=$now} {
	set unload [lindex $extras [incr where]]
	incr where
    }
    set phase [expr {int([glob_element ts 0])}]
    set clear [expr {$phase==5 || $phase==6}]
    if {$clear} {
	set extras [lreplace $extras 0 $where-1]
	if {$unload} {
	    set event(culprit) $id
	}
    }
    return $unload
}	
    
proc ListToArray {topNode tgt subs numSubs trans dims list when useCppArray} {
#ShowMess debug info  "Go! tgt $tgt subs $subs trans $trans dims $dims list $list cpp $useCppArray" ok
    # skip over any vm arrays, their indices will not appear
    # in calls for values, but keep the translation list in sync
    # ... string match stops cleanly at end of list
#    global comboTypes
    
    if {[string equal ,bytes [lindex $list 1]]} {
	if {$useCppArray && [lsearch $dims {RECORDS *}]==-1} {
	    if {$when} {
		c_settimepointall $topNode $tgt [lindex $list end]
		SetWrapTime $topNode $useCppArray $tgt [lindex $list end-2]
		SetFillMethod $topNode $useCppArray $tgt [lindex $list end-1]
	    } else {
		c_setparamall $topNode $tgt [lindex $list end] \
		    [lrange $list 3 end-3]
	    }
	    return -1 ;# do nothing more, the data has now been loaded to c
	} else {
	    # DO THE fallback thing (inefficient placeholder version)
	    if {[string equal REAL [lindex $list 2]]} {
		set fieldChar d
		set fieldSize 8
	    } else {
		set fieldChar i
		set fieldSize 4
	    }
	    set offset 0
	    set newList [NumberElements \
			     [DoByteArrayToList $fieldChar $fieldSize \
				  [lrange $list 3 end-3] [lindex $list end]]]
	    if {$when} {
		lappend newList [lindex $list end-2] restart \
		    others [lindex $list end-1]
	    }
	    set list $newList
	}
    } elseif {[string equal ,gdal [lindex $list 1]]} {
	# transposition not yet handled
	if {$useCppArray && [lsearch $dims {RECORDS *}]==-1 && !$when} {
	    DoNotPassTcl $topNode $tgt $dims $list
	    return -1 ;# typical fixed parameter
	} else {
	    set list [concat [NumberElements [ReadGdalRefToList $list \
						  [lindex $dims 0] \
						  [lindex $dims 1]] \
				  [expr {!$when}]] [lrange $list 7 end]]
	}
    }
# do not do this, ve no longer allow params in VM submodels...
    while {[set specialId [lsearch {START_VM MEMBERS} [lindex $dims 0]]]!=-1} {
        if {$specialId} {
            set dims [lrange $dims 1 end]
            set trans [lrange $trans 1 end]
        } else {
            set endGap [lsearch $dims END_VM]
            set dims [lreplace $dims 0 $endGap]
            set trans [lrange $trans [expr $endGap-1] end]
        }
    }
    set nextDim [lindex $dims 0]
    
    set thisTrans [lindex $trans 0]
    if {![llength $dims]} { ;# no more dims, this should be a single value
        if {[llength $list]} {
	    if {![string last ,NOW [string toupper $subs] 3]} {
		# setting current value for var param
		set idAndSubs $tgt[string range $numSubs 4 end]
		if {[catch {EnumTypeToNumber $topNode $idAndSubs $list \
				$thisTrans 0 $useCppArray} woops]} {
		    return [AddErrorTo {} $woops $subs]
		} else {
		    return 1
		}
	    } else {
		# setting value for fixed param or time point
		if {[catch {EnumTypeToNumber $topNode $tgt$numSubs $list \
				$thisTrans $when $useCppArray} woops]} {
		    return [AddErrorTo {} $woops $subs]
		} else {
		    return -1 ;# should be 0 if a comp
		}
	    }
	} else {
	    return [AddErrorTo {} missing_param_data $subs]
        }
    }

    if {[llength $list]==1} {
        #puts "setting paramData($tgt) to $headNum"
        set userDims [join $dims { x }]
	return [AddErrorTo {} [list scalar_instead_of_array $list $userDims] \
		    $subs]
    }
    if {[llength $list]%2} {
	return [AddErrorTo {} odd_index_at_end $subs,[list [lindex $list end]]]
    }
    
    set redoStep 1
    #puts "dims remaining $dims"
    if {[string match TIME $nextDim]} {
        # If time, we can have as many or as few vals as we want, and
        # they can be any number, although negative ones may not take
        # effect at start of simulation.
	# array set sub $list ;# was this faster?

        # Next call removes old time series data from the system (no throws)
        EnumTypeToNumber $topNode $tgt {} {} 1 $useCppArray
	SetWrapTime $topNode $useCppArray $tgt 0 ;# clear old wraparound point
# do not allow OTHERS if an event series

	set tgtEval [GetCompProperty $topNode Eval $tgt]
	set tgtClass [GetCompProperty $topNode Class $tgt]

	if {[string equal DERIVED $tgtEval]} {
	    set specialPts {} ;# loading measurements for PEST
	} elseif {[string equal EVENT $tgtClass]} {
	    set specialPts [list NOW INTERVAL]
	} else {
	    set specialPts [list NOW INTERVAL OTHERS]
	    SetFillMethod $topNode $useCppArray $tgt use_last ;# and fill method
	}
	SetInterval $topNode $useCppArray $tgt unit 1
    
        foreach {indx subList} $list {
	    set nextSubs $subs,[list $indx]
            if {[set pt [lsearch $specialPts [string toupper $indx]]]>-1} {
# Following never happens, TIME is always outermost dimension
#		if {[llength $subs]} {
#		    FPError [format [tr. {"%1$s" must be outermost index.}] \
#					 $indx] $subs $errorData
#		}
		if {!$pt} { ;# NOW: mark param active so it clears after event
# active is set to 2 because the param updater will be called before the model
# collects the parameter, and must clear the value the following time
		    MarkEvtParamActive $topNode $tgt $useCppArray
		}
            } elseif {![string is double -strict $indx]} {
                set redoStep [AddErrorTo $redoStep \
				  [list bad_time_point_index $specialPts] \
				  $nextSubs]
            } elseif {[string equal RESTART [string toupper $subList]]} {
		SetWrapTime $topNode $useCppArray $tgt $indx
		continue
	    } elseif {$useCppArray} {
# If there are values other than NOW, do an init step
                c_settimepointarray $topNode $tgt $indx
            }
# check for fill method if one might be appropriate
	    if {[lsearch $specialPts OTHERS]>-1} {
		set noMtd [catch {SetFillMethod $topNode $useCppArray $tgt \
				      $subList} badFill]
		if {$pt==2} { ;# fill method expected
		    if {$noMtd} {
			set redoStep [AddErrorTo $redoStep $badFill $nextSubs]
		    }
		    continue
		} elseif {!$noMtd} { ;# fill method found but not expected
		    set redoStep [AddErrorTo $redoStep \
				      [list misplaced_fill_method $subList] \
				      $nextSubs]
		}
	    }
# do same for interval (units for time series index) -- trying to call Prolog 
# from here can only lead to trouble
	    if {[string is double -strict $subList]} { ;# save time by not going Prolog
		set TSI 0
	    } else {
		set TSI [lsearch {{} s second min minute hr hour day week month year} $subList] ;# not [InDays $subList]
	    }

	    if {$pt==1} { 
# units for time series index expected -- we cannot go Prolog to parse
# them from here, so raise an "error" which will try to parse them
# before alerting the modeller
		set redoStep [AddErrorTo $redoStep [list check_uftsi $subList] \
				  $nextSubs]
		continue
	    } elseif {$TSI>0} { ;# found but not expected
		set redoStep [AddErrorTo $redoStep \
				  [list misplaced_uftsi $subList] $nextSubs]
	    }
	    set redoStep [JoinSteps $redoStep \
			      [ListToArray $topNode $tgt $subs,$indx \
				   $numSubs,$indx $trans [lrange $dims 1 end] \
				   $subList $when $useCppArray]]
        }
        return $redoStep
    }
    
    # Not time points: check the indices are good
    foreach {indx sublist} $list {
        # was array set sub $list...above would allow us to check that all indices were
        # the right type if we could be bothered...OK then...
	if {[catch {UntransVal $thisTrans $indx index} poss]} {
	    set redoStep [AddErrorTo $redoStep $poss $subs]
	} ;# seems we do not need actual position!?
        if {[info exists sub($indx)]} {
	    set redoStep [AddErrorTo $redoStep \
			      [list repeated_index $indx] $subs]
        }
        set sub($indx) $sublist
    }
    if {$redoStep != 1} { ;# do not proceed with bad time step
	return $redoStep
    }

    if {[llength $nextDim]==2 && \
                [string match RECORDS [lindex $nextDim 0]]} {
        # by-record submodel; check up to biggest. OK hows this for branez...use
        # the number of elements, because if there is an element larger than the
        # number of elements, one the same or smaller will be missing!
        set last [array size sub]
        if {!$last} {
	    set redoStep [AddErrorTo $redoStep record_count_undefined $subs]
        }
        
	# Record counts do not need to be set in Tcl
        if {$useCppArray} {
	    if {$when} {
		set map [split $subs ,]
		c_settimepointrecords $topNode $tgt [lrange $map 2 end] \
		    [lindex $map 1] $last
		# if {[catch {c_settimepointrecords $tgt [lrange $map 2 end] \
		# 		[lindex $map 1] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    } else {
		c_setrecordlist $topNode $tgt [lrange [split $subs ,] 1 end] \
		    $last
		# if {[catch {c_setrecordlist $tgt [lrange [split $subs ,] \
		# 				      1 end] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    }
	} else { ;# use old system for Tcl
	    set recordNode [lindex $nextDim 1]
	    EnumTypeToNumber $topNode $recordNode$numSubs $last {} $when \
		     $useCppArray ;# cannot fail
	}

# Hopefully, with the universal data structure, once we have set the
# record count for the outer submodel level, we will be able to access
# its contents as if they were a fixed membership array, so this
# should be redundant
#            foreach nested [lrange $dims 1 end] {
#                if {[llength $nested]==2 && \
#                            [string match RECORDS [lindex $nested 0]]} {
##puts "c_setrecordlist [lindex $nested 1] $outers $last"
#                    c_setrecordlist [lindex $nested 1] $outers $last
#                }
#            }
# So should this
#        EnumTypeToNumber paramData [lindex $nextDim 1]$subs $last \
#                {} $useCppArray
        # probably wouldn't have worked anyway for time series
    } else {
        set last $nextDim
    }
    for {set arrayPt 1} {$arrayPt <= $last} {incr arrayPt} {
        set indx [NumberToEnumType $arrayPt $thisTrans]
	set newSubs $subs,[list $indx]
        if {![info exists sub($indx)]} {
            #puts "No $indx in [array names sub]"
            set redoStep [AddErrorTo $redoStep gap_in_data $newSubs]
        } else {
	    set redoStep [JoinSteps $redoStep \
			      [ListToArray $topNode $tgt $subs,$indx \
				   $numSubs,$arrayPt \
				   [lrange $trans 1 end] [lrange $dims 1 end] \
				   $sub($indx) $when $useCppArray]]
	}
    }
    return $redoStep
}

proc DoNotPassTcl {topNode node dims tableSpec} {
#puts "dims $dims spec $tableSpec"
    if {[string equal REAL [GetCCompProperty $topNode Type $node]]} {
	set gdalType GDT_Float64
    } else {
	set gdalType GDT_Int32
    }

    package require gdal
    set hg [gdal_open_read_only [lindex $tableSpec 0]]
    set hdl [gdal_get_raster_band $hg 1]
    set dataRows [expr 1+[lindex $tableSpec 3]-[lindex $tableSpec 2]]
    set dataCols [expr 1+[lindex $tableSpec 5]-[lindex $tableSpec 4]]
    set fillRows [lindex $dims 0]
    set fillCols [lindex $dims 1]
    set bytesFromGdal [gdal_get_raster_data $hdl \
		     [expr [lindex $tableSpec 4]-1] \
		     [expr [lindex $tableSpec 2]-1] \
		     $dataCols $dataRows $gdalType $fillCols $fillRows]
    gdal_close $hg
    
    c_setparamall $topNode $node $bytesFromGdal [list $fillRows $fillCols]
}

proc JoinSteps {stepA stepB} {
    switch \
	[string is integer -strict $stepA],[string is integer -strict $stepB] {
	    0,0 {
		return [concat $stepA $stepB]
	    } 0,1 {
		return $stepA
	    } 1,0 {
		return $stepB
	    } 1,1 {
		return [expr {$stepA<$stepB?$stepA:$stepB}]
	    }
	}
}

proc AddErrorTo {old woops subs} {
    set error [list [concat [lindex $woops 0] [list $subs] \
			 [lrange $woops 1 end]]]
    return [JoinSteps $old $error]
}

proc UntransVal {trans mem type} {
    if {[string compare {} $trans]} {
	if {[llength $mem]==1} {
	    set mem [lindex $mem 0]
	} ;# remove quotes or curlies
	set poss [lsearch $trans $mem]
	if {$poss == -1} {
	    if {[string equal {false true} $trans] && \
		    [string equal data $type]} {
		set trans [linsert $trans 0 boolean]
	    }
	    error [list bad_enum_type_mem $mem [lindex $trans 0] [lrange $trans 1 end] $type] 
	} else {
	    return $poss
	}
    } 
    if {[string equal index $type]} {
	if {![string is integer -strict $mem]} {
	    error [list non_integer_index $mem]
	} elseif {$mem<=0} {
	    error [list zero_or_negative_index $mem]
	}
    }
    return $mem
}

proc EnumTypeToNumber {topNode tgt head trans when useCppArray} {
    if {![llength $head]} {
        # empty head, signal to clear out old values
        if {$useCppArray} {
            c_cleartimeseries $topNode $tgt
        } else {
	    tcl_cleartimeseries $topNode $tgt
        }
    } else {
	set head [UntransVal $trans $head data]
	if {[llength $head]>1} {
	    error [list unwanted_param_array $head]
	} elseif {![string is double -strict $head]} {
	    error [list data_not_number $head]
	}
	PlaceInArray $topNode $tgt $head $when $useCppArray
    }
    #puts "just went set paramData($tgt) $paramData($tgt)"
}

#proc FPError {occurrence inds errorData} {
#    if {![llength]} {
#	error aborted ;# quick way out
#    }
#    set query [concat param_load_fail $errorData [list $where $occurrence]]
#    if {[string equal abort [ExecQuery $query warning spf {} abort]]} {
#	error aborted
#    } else {
#	return {} ;# in hope ListParamArray will return same
#    }
#}

proc NumberToEnumType {idx trans} {
    if {[llength $trans]} {
        return [lindex $trans $idx]
    } else {
        return $idx
    }
}

proc tcl_setparamarray {model node} {
    global paramLocns

    set paramIdx [getinfo $node 8]
#puts "tcl_setparamarray $model $node $paramIdx"
    set paramLocns($paramIdx,nod) $node
    set paramLocns($paramIdx,arr) tclParmData ;# was [InputVarFor $model $node]
}

proc tcl_cleartimeseries {topNode node} {
    global paramData

    array unset paramData $node*
}

proc tcl_setparamelement {node inds val} {
    global paramLocns

    set paramIdx [getinfo $node 8]
    upvar #0 $paramLocns($paramIdx,arr) varData
    set varData([join [concat [list $node] $inds] ,]) $val
} 

# replaces previous param values with 0s, used to clear events
proc tcl_zeroparam {node} {
    global paramLocns

    set paramIdx [getinfo $node 8]
    upvar #0 $paramLocns($paramIdx,arr) varData
    foreach current [array names varData $node*] {
	set varData($current) 0
    }
} 

proc tcl_settimepointelement {node inds val} {
    global paramData

    set paramData([join [concat [list $node] $inds] ,]) $val
} 
 
# no longer needed, as sliderVars, checkStates and comboChoices are now all
# subsumed under widgetSeln
#proc InputVarFor {topNode node} {
#    switch -glob [GetTclCompProperty $topNode Type $node] {
#	FLAG {
#	    return checkStates
#	} ENUM(*) {
#	    return comboChoices
#	} default {
#	    if {[string equal TABLE [GetTclCompProperty $topNode Eval $node]]} {
#		return paramData
#	    } else {
#		return sliderVals
#	    }
#	}
#    }
#}
#   
proc oldcollect {tgt node count args} {
    global myNode
# ShowMess debug info "Collecting...$tgt...$node...$count...$args" ok
    if {[string match TABLE [getinfo $node 5]]} {
	set inputSrc paramData
    } else {
	set inputSrc [InputVarFor $myNode $node]
#	switch [getinfo $node 0] {
#	    FLAG {
#		set inputSrc checkStates
#	    } ENUMERATED {
#		set inputSrc comboChoices
#	    } default {
#		set inputSrc sliderVals
#	    }
#	}
    }
#    set sub [join [concat $node $args] ,]
    set val [BringParameter $inputSrc $node $args]
    if {[llength $val]} {
# Check that input source exists, it will not if model is being initialized
	if {[string equal REAL [getinfo $node 0]]} {
	    set $tgt $val
	} else {
	    set $tgt [expr int($val)]
	}
    }
}

proc getinstance {varName dest newvalue} {
    # If newvalue exists, it should be copied to target and returned
    upvar 1 $varName target
    upvar 1 $dest returnList

    if {[string compare $newvalue NULL]} {
        set target $newvalue

    } ;# end(if,$set)
    lappend returnList $target
    return $returnList
} ;# end(procedure,getinstance)

proc step_incr {step v} {
    return [expr $v*[glob_element dts $step]]
}

proc old_stage_incr {ns_extras step v} {
    upvar \#0 $ns_extras extras
    if {![info exists extras]} {
	set extras [list 0 0]
    }

    set dv [step_incr $step $v]
    switch [expr int([glob_element dts 0])] {
	0 {
	    return $dv
	} 1 {
	    set current_offset [expr $dv/2.0]
	    set extras [list [expr $dv/6.0] $current_offset]
	    return $current_offset
	} 2 {
	    set current_offset [expr $dv/2.0]
	    set old_offset [lindex $extras 1]
	    set extras [list [expr [lindex $extras 0]+$dv/3.0] $current_offset]
	    return [expr $current_offset-$old_offset]
	} 3 {
	    set old_offset [lindex $extras 1]
	    set extras [list [expr [lindex $extras 0]+$dv/3.0] $dv]
	    return [expr $dv-$old_offset]
	} 4 {
	    return [expr [lindex $extras 0]+$dv/6.0-[lindex $extras 1]]
	}
    }
}

proc stage_incr {ns_extras step v span gId} {
    global adapt adapt_maxerr
    upvar \#0 $ns_extras extras
    if {[info exists extras]} {
	scan $extras "%f %f %f" t1 t2 t3
    } else {
	set t1 [set t2 [set t3 0]]
    }
# In this version, the three intermediate increments are kept in t1-t3 while
# building the full R-K increment. After this is complete they are assigned:
# t1 = initial rate of change (used when redoing step with different dt)
# t2 = last increment (used to undo step)
# t3 = estimate of next initial increment
    if {[glob_element ts 0]<0} {
        set dv [step_incr $step $t1]
    } else {
        set dv [step_incr $step $v]
    }
    switch -- [expr int([glob_element ts 0])] {
        0 { ;# Euler
            set t1 $v
            set t2 $dv
            set t3 $dv
            set result $dv
        } 1 { ;# these 4 are R-K
            set result [expr [set t1 $dv]/2.0]
        } 2 {
            set result [expr ([set t2 $dv]-$t1)/2.0]
        } 3 {
            set result [expr [set t3 $dv]-$t2/2.0]
        } 4 {
            set t2 [expr $t1/6 + $t2/3 + \
                                $t3/3 + $dv/6]
            set mid [expr $t2 - $t3]
            set t3 [expr (-$t1 + 2*$t3 + 2*$dv)/3]
            set t1 [expr $t1/[glob_element dts $step]]
            set result $mid
        } -1 { ;# undoes previous change Euler
            set last_incr $t2
            set t3 $dv
            set result [expr [set t2 $dv]-$last_incr]
        } -2 { ;# undoes previous change R-K
            set result [expr [expr [set t1 $dv]/2.0]-$t2]
        } 10 - 11 { ;# does not change compartment, just checks for errors
#            if {$dv} {
	    set errMagn [expr {abs($dv-$t3)*100/$span}]
#puts "p10 pred_change $extras(pred_change) dv $dv errMagn $errMagn"
	        if {$errMagn > $adapt_maxerr} {
		    set adapt(culprit) $gId
		    set adapt_maxerr $errMagn
	        }
#            }
            set result 0
        }
    }
    set extras [list $t1 $t2 $t3]
    return $result
}

proc check_limit {trigger lower upper action graphId step ns_extras} {
    global event

    upvar \#0 $ns_extras extras
    set phase [expr {int([glob_element ts 0])}]

#puts "cmd [info level 0] phase $phase extras [array get extras]"
    switch -- $phase {
	0 - 1 { ;# resetting model, do not use saved data
	    set extras(t1) $trigger ;# for prediction next step
	} 2 { ;# next 3 are R-K substeps
	    set extras(t2) $trigger
	} 3 {
	    set extras(t2) [expr {($extras(t2)+$trigger)/2}]
	} 5 - 6 - 9 - 10 - 11 {
	    set heading_out 0
	    set out 0
	    if {$phase == 9} {
		set old $trigger ;# no heading or rate
		set extras(t3) 0
	    } else {
		set old $extras(t1)
	    }
	    if {$action & 1} {
		if {$trigger<$old} {
		    set heading_out -1
		    set to_limit [expr {$trigger-$lower}]
		    set rate [expr {$old-$trigger}]
		}
		if {$trigger<=$lower} {
		    set out -1
		}
	    }
	    if {$action & 2} {
		if {$trigger>$old} {
		    set heading_out 1
		    set to_limit [expr {$upper-$trigger}]
		    set rate [expr {$trigger-$old}]
		}
		if {$trigger>=$upper} {
		    set out 1
		}
	    }

# ok...if for_real, I need to update the last 'out' value and return
# the new value if it has changed, ot zero otherwise. If heading out,
# but not already fired (including this pass) I need to make a
# prediction (to be treated as an overshoot if out).
    
	    set forReal [expr {$phase==5 || $phase==6 || $phase==9}]
	    if {$forReal} {
		set extras(t1) $trigger ;# for prediction next step
		if {$out} {
		    if {$out != $extras(t3)} {
			set event(culprit) $graphId 
			return [set extras(t3) $out]
		    }
		} else {
		    set extras(t3) 0
		}
	    }	    
	    if {$heading_out && $extras(t3) != $heading_out} { 
		# make prediction for this event
		if {$phase==6 || $phase==11} { ;# ok approximate to quadratic
		    set a [expr {-$heading_out*2*($trigger-2*$extras(t2)+$old)/pow([glob_element dts $step],2)}]
		    if {$a==0} { ;# it is linear
			set prediction [expr {[glob_element ts $step] + [glob_element dts $step]*$to_limit/$rate}]
		    } else {
			set b [expr {-$heading_out*(3*$trigger-4*$extras(t2)+$old)/[glob_element dts $step]}]

			# that is the eqn for the curve. Determinant:
			set det [expr {pow($b,2)-4*$a*$to_limit}]
			if {$det<0} {return 0} ;# value turns round before limit
			set det [expr {pow($det,0.5)}]
			if {$to_limit*[glob_element dts $step]>0} {
			    # inside limit XOR going backwards
			    set prediction [expr {[glob_element ts $step] + \
						      (-$b-$det)/(2*$a)}]
			} else { ;# take later root
			    set prediction [expr {[glob_element ts $step] + \
						      (-$b+$det)/(2*$a)}]
			}
#puts "t [glob_element ts $step] dt [glob_element dts $step] old $old t2 $extras(t2) trigger $trigger a $a b $b det $det pred $prediction"
		    }
		} else { ;# phase is 5 or 10, do linear extrap
		    set prediction [expr {[glob_element ts $step] + [glob_element dts $step]*$to_limit/$rate}]
		}
	    
		if {$heading_out && $prediction<$event(predict)} {
		    set event(predict) $prediction
		}
	    }
	}
    }
    return 0
}
	
		    
proc do_model {what mstep} {
#puts [info level 0]
    if {[catch {eval ::AME_model<>::${what} $mstep}]} {
	RaiseTclExecError $what $mstep
    }
}

proc RaiseTclExecError {mproc mstep} {
    global myNode errorInfo model_prog ts phasecount

    set errorList [split $errorInfo \n]
    set whoopsie [lindex $errorList 0]
    set modelLine [lindex $errorList end-5]
    regexp { (\d+)\)$} $modelLine spare lineNo
    set mStream [open $model_prog($myNode) r]
    set mLine {}
    while {![string match "proc $mproc *" $mLine]} {
	gets $mStream mLine
    }
#puts "found proc $mLine"
    for {set procLine 1} {$procLine < $lineNo} {incr procLine} {
	gets $mStream mLine
    }
#puts "picked line $mLine"
    close $mStream
    if {[regexp {set ([^ ]*) .*} $mLine spare targetName]} {
	set dest [namespace eval AME_model<> "set spare $targetName"]
    } else {
	set dest none
    }
    error [list tcl_model_err $mproc $dest $ts($phasecount) $mstep $whoopsie] \
	$errorInfo
}

proc CheckGUI {node modelTime thisOp} {
    global GUILog dispDone
    
    set flash 20
    # first record how much time the last op took
    set thisUpdate [clock clicks -milliseconds]
    if {[info exists GUILog(lastExit)]} {
	set GUILog($GUILog(lastOp),took) [expr $thisUpdate-$GUILog(lastExit)]
	set currentOld [expr $thisUpdate-$GUILog(lastUpdate)>$flash]
    } else {
	set currentOld 1
    }
    set GUILog(lastOp) $thisOp
    
    if {[info exists GUILog($thisOp,took)]} {
	set startingLong [expr $GUILog($thisOp,took)>$flash]
    } else {
	set startingLong 1
    }
    
    if {$currentOld || $startingLong} { 
	if {[string equal ext $thisOp]} {
	    set col 2
	} else {
	    set col 1
	}
	set result [InteractGUI $node $modelTime $col]
	set thisUpdate [clock clicks -milliseconds] ;# GUI may have taken time
	set GUILog(lastUpdate) $thisUpdate
    } else {
	set result 0
    }
    set GUILog(lastExit) $thisUpdate
    return $result
}
    
proc abort_check {args} {
    global myNode
    if {[AbortCheck $myNode]>=10} {
	error "abort request from the user"
    }
}

proc TclResetModel {node t0 doingRK topPhase} {
    global myNode ts dts steps phasecount adapt adapt_maxerr event

    set myNode $node
    set ts(0) 9 ;# start prediction cycle
    if {$topPhase <= 0} {
	if {$topPhase <= -1} {
	    InitTimeSeries $node
	}
	ResetTimeSeries $node
        for {set tweakPhase 1} {$tweakPhase <= $phasecount} {incr tweakPhase} {
            set ts($tweakPhase) $t0
            set dts($tweakPhase) $steps($tweakPhase)
        }
	set event(predict) [expr {$t0+$steps($phasecount)}] ;# just initialize
    }
    set adapt(curFreq) $steps($phasecount)
    set adapt_maxerr 0 ;# just so it is defined at first comparison
    UpdateTimeSeries $node $t0
    set event(culprit) 0
    do_model evalmodel [set dts(0) $topPhase]
    set event(nextSeries) [expr {$adapt(curFreq)>0?Inf:-Inf}]
    return 1
}

proc TclExecuteModel {node howInt start end errLim evtPause} {
    global ts dts steps phasecount adapt adapt_maxerr event
#    if {[string equal cancel [ShowMess debug info "XM from $start to $end" okcancel]]} {
#	error cancelled
#    }
    set intMtd [string equal Runge-Kutta $howInt]
    upvar #0 adapt(curFreq) freq
    set xtime $start
    if {$errLim} {
	set minFreq $errLim
    } else {
	set minFreq 1
    }
    if {$minFreq>1e-6*$steps($phasecount)} {
	set minFreq [expr {1e-6*$steps($phasecount)}]
    }
    while {($end-$xtime)/$freq>0} { ;# freq only affects sign
	set madeStep 0
	set firstPass 1
	set bigPhase [PhaseFor $xtime $freq $phasecount]
	set weePhase [expr {$phasecount+1}]
# that is the biggest phase we will try to run, we may not succeed
	if {[CheckGUI $node $xtime ph$bigPhase]} {
	    return [list 0 $xtime]
}
# call update purely to drive events...and last() etc
	if {$event(culprit) || $event(seriesSign)} {
# an event is waiting to take effect
	    set ts(0) [expr {10+$intMtd}] ;# no change due to flows
	    do_model updatemodel $bigPhase
	    set ts(0) $intMtd ;# start prediction cycle
	    do_model evalmodel $bigPhase
	}

        while {!$madeStep} {
	    # aim for next predicted event if closer than end
#puts "freq $freq end $end xtime $xtime series $event(nextSeries) predict $event(predict)"
	    set aim_for $end
	    if {$firstPass && ($aim_for-$event(nextSeries))/$freq>0} {
		set aim_for $event(nextSeries)
	    }
            if {($aim_for-$event(predict))/$freq>0} {
		set aim_for $event(predict)
	    }
	    
            # stretch interval to hit end if necssary
            if {$xtime/$freq+1.0625>$aim_for/$freq} {
                set freq [expr $aim_for-$xtime]
		if {$freq/$minFreq<1} {
		    set freq $minFreq
		}
	    }
	    set xtime [expr $xtime+$freq]

	    SetDTs $bigPhase $xtime

#	    do_model advancemodel $bigPhase
	    if {$intMtd==0} {
                if {$firstPass} {
		    set recover 0.5
 		    set ts(0) 0
                } else {
                    set ts(0) -1
                }
		do_model updatemodel $weePhase
                AdvanceTime $node $bigPhase 1 ;# sets event(nextSeries)
	    } else {
                if {$firstPass} {
		    set recover 0.0625
                    set ts(0) 1
                } else {
                    set ts(0) -2
                }
		do_model updatemodel $weePhase
		RKUpdate $node
	    }
            set firstPass 0
            set event(culprit) 0 ;# use to check if a limit event fires 
            if {!$errLim} {
		set freq $steps($phasecount) ;# no need to keep short step
		break ;# from while {!$madeStep} loop
	    }

# tweak to allow events to be placed precisely in time. Clear maxerr
# before the final rate calculation, and allow threshold detection to
# increase it to the amount by which the threshold is crossed.
	    set evtError 0
	    set ts(0) [expr {10+$intMtd}]
	    set event(predict) [expr {$xtime+$freq}] ;# horizon not important
	    do_model evalmodel [set dts(0) $weePhase]
#  event error is time by which new prediction earlier
	    set evtError [expr {$xtime-$event(predict)}]
# now, if this error is too great, we wish to shorten the step
# -- no need to undo anything -- and try again
	    set newFreq $freq
	    if {$evtError>$errLim} {
		set newFreq [expr {$event(predict)-($xtime-$freq)}]
		if {$newFreq/$minFreq<1} {
		    set newFreq $minFreq 
		}
	    }
# Now, type 10/11 act will not actually fire events so we can check for
# continuous errors too
	    set adapt_maxerr 0
	    set adapt(culprit) $event(culprit) ;# in c: userDefStop->targetId
	    do_model updatemodel $weePhase ;# ts(0) still 10/11

#puts "adapt error $adapt_maxerr event error $evtError"
	    if {$adapt_maxerr>$errLim} {               
		if {$newFreq/$freq>0.5} {
		    set newFreq [expr {$freq/2}]
		}
	    }

	    if {$newFreq/$freq<1} { 
		# error too great; put comps back and try shorter
		if {$freq/$minFreq > 1} { ;# not already short as we can go
		    AdvanceTime $node $bigPhase -1 ;# back to the start
		    set xtime [expr $xtime-$freq]
		    set freq $newFreq
		    set bigPhase [PhaseFor $xtime $freq $phasecount]
		} else {
		    # reached max freq limit; could be compartment or event
		    error [list tcl_model_err evalmodel $adapt(culprit) \
			       $xtime $bigPhase discontinuity]
		}
	    } else {
		set madeStep 1
		if {$freq!=$steps($phasecount) && \
			$adapt_maxerr<$errLim*$recover} {
		    # low error; try longer next time if poss
		    if {$freq/$steps($phasecount) < 0.5} {
			set freq [expr {2*$freq}]
		    } else {
			set freq [expr {$steps($phasecount)}]
		    }
		} ;# lengthen time step
	    } ;# timestep too short or not
	} ;# made progress
	
	set ts(0) [expr {5+$intMtd}]
# now limit events will actually affect the model
        set event(culprit) 0 ;# will be what actually fired
	set event(predict) [expr {$xtime + 1.0625*$freq}] ;# max for next step
# limit of period of interest
	do_model evalmodel [set dts(0) $bigPhase]
#	if {[string length $event(prev_sign)]} {
# if so, run eval again in subphase to set up new predictions
#	    set ts(0) $intMtd
#	    do_model evalmodel [set dts(0) [expr {$phasecount+1}]]
#	}
# now pause on event if doing so
	if {$evtPause && $event(culprit)} {
	    return [list -1 evalmodel $event(culprit) $xtime $bigPhase event]
#	    error [list tcl_model_err evalmodel $event(culprit) \
#		       $xtime $bigPhase event]
	}
    } ;# finished executing
    if {[CheckGUI $node $end ext]} {
	return [list 0 $xtime]
    }
    return [list 1 $xtime]
}
	    
proc PhaseFor {current step soFar} {
    global steps

#ShowMess debug info "PhaseFor $current $step $soFar" ok
    if {$soFar == 1} {
	return 1
    }
    set try [expr $soFar-1]
    set nextStep $steps($try)
    set last [expr $current+($step/2.0)]
    set next [expr $last+$step]

    set tryCurrent [expr $nextStep*floor($last/$nextStep)]
    set tryNext [expr $nextStep*floor($next/$nextStep)]
    if {$tryCurrent == $tryNext} {
	return $soFar
    } else {
	return [PhaseFor $tryCurrent $nextStep $try]
    }
}

proc RKUpdate {node} {
    global ts dts phasecount

    set weePhase [expr $phasecount+1]
    set dts(0) $weePhase
    AdvanceTime $node $phasecount 0.5
    set ts(0) 2
    do_model evalmodel $weePhase
    do_model updatemodel $weePhase
    set ts(0) 3
    do_model evalmodel $weePhase
    do_model updatemodel $weePhase
    AdvanceTime $node $phasecount 0.5
    set ts(0) 4
    do_model evalmodel $weePhase
    do_model updatemodel $weePhase
    set ts(0) 1
}
    
proc SetDTs {phase current} {
    global ts dts phasecount
    for {set tweakPhase $phase} {$tweakPhase<=$phasecount} {incr tweakPhase} {
	set dts($tweakPhase) [expr $current-$ts($tweakPhase)]
    }
}

proc AdvanceTime {node phase fraction} {
    global ts dts phasecount
    for {set tweakPhase $phase} {$tweakPhase<=$phasecount} {incr tweakPhase} {
	set ts($tweakPhase) [expr $ts($tweakPhase)+$dts($tweakPhase)*$fraction]
    }
#    set seriesPt [expr $ts($phasecount)+$dts($phasecount)*$fraction/2]
    set ::event(nextSeries) [UpdateTimeSeries $node $ts($phasecount)]
}

# try to minimize effort at runtime -- list timepoints for each node...
proc InitTimeSeries {topNode} {
    global setFromSeries paramData
    array unset setFromSeries
    foreach node [GetTclCompProperty $topNode Objects] {
	set evalN [lsearch {INPUT} \
		       [GetTclCompProperty $topNode Eval $node]]
	if {$evalN > -1} {
#puts "node $node timePts [array names paramData $node,*]"
	    foreach timePt [array names paramData $node,*] {
		set ${node}([lindex [split $timePt ,] 1]) 1
	    }
# include nodes with no time points so we can clear NOW events
#	    if {[array size $node]} {
		set setFromSeries($topNode,$node,times) \
		    [lsort -real [array names $node]]
		set setFromSeries($topNode,$node,next) -1 ;# no data yet loaded
		set setFromSeries($topNode,$node,wraps) 0 ;# wraparound count
		set setFromSeries($topNode,$node,active) 0
#puts "initted $setFromSeries($topNode,$node,times)"
#	    }
	}
    }
    set setFromSeries($topNode,current) 0
}

proc ResetTimeSeries {topNode} {
    global setFromSeries
    foreach pt [array names setFromSeries $topNode,*,next] {
	set setFromSeries($pt) -1
	set node [lindex [split $pt ,] 1]
	set setFromSeries($topNode,$node,wraps) 0 ;# wraparound count
    }
    set setFromSeries($topNode,current) 0
}

# for each node we have a list of times in the time series, and a pointer to 
# where we are in the list. If the time has gone past that pointed to, signal 
# the data to be written and look at the next one...see update_from_points in
# shank.cpp...

proc UpdateTimeSeries {topNode now} {
    global setFromSeries
#puts "$setFromSeries($topNode,current) to $now"
    set ::event(seriesSign) 0
    set seriesEvt [expr {$now>=$setFromSeries($topNode,current)?Inf:-Inf}]
    foreach list [array names setFromSeries $topNode,*,times] {
	set seriesEvt [UpdateFromPoints $list $topNode $now $seriesEvt]
    }
    set setFromSeries($topNode,current) $now
    return $seriesEvt
}

proc UpdateFromPoints {list topNode newTimeInDays next} {
    global setFromSeries paramData

    set inC [RunningInC $topNode]
	set ptCount [llength $setFromSeries($list)]
	set node [lindex [split $list ,] 1]
	set newTime [expr {$newTimeInDays/$paramData(timePointInterval,$node)}]
    if {[lsearch {EVENT SQUIRT} [GetTclCompProperty $topNode Class $node]]>-1} {
	set fillMethod none
	} else {
	    set fillMethod [string tolower [SetFillMethod $topNode $inC $node]]
	}
	    set loWraps $setFromSeries($topNode,$node,wraps)
	    set hiWraps $loWraps

	    set loBound $setFromSeries($topNode,$node,next)
	    if ($loBound>-1) {
		set hiBound [expr $loBound+1]
		if {$hiBound >= $ptCount} {
		    if {$paramData(wrapAroundPoint,$node)} {
			set hiBound 0
			incr hiWraps
		    } else {
			set hiBound -1
		    }
		}
	    } elseif {$ptCount} {
		set hiBound 0 ;# first point
	    } else {
		set hiBound -1
	    }

	    if {$next>=$newTimeInDays} {
		while {$hiBound>-1 && $newTime>=[lindex $setFromSeries($list) $hiBound]+$hiWraps*$paramData(wrapAroundPoint,$node)} {
		    set loBound $hiBound
		    set loWraps $hiWraps
		    incr hiBound
		    if {$hiBound >= $ptCount} {
			if {$paramData(wrapAroundPoint,$node)} {
			    set hiBound 0
			    incr hiWraps
			} else {
			    set hiBound -1
			}
		    }
		}
	    } else {
		while {$loBound>-1 && $newTime<[lindex $setFromSeries($list) $loBound]+$loWraps*$paramData(wrapAroundPoint,$node)} {
		    set hiBound $loBound
		    set hiWraps $loWraps
		    incr loBound -1
		    if {$paramData(wrapAroundPoint,$node) && $loBound==-1} {
			incr loWraps -1
			set loBound [expr $ptCount-1]
		    }
		}
	    }
# Now if fill method is interpolate, calculate the place in the interval,
# set the value to it and finish. Otherwise only set the value if it has
# changed, i.e., if we have gone past a time point for use_last, or past 
# midway between two if use_closest.
	    if {$loBound>-1 && $hiBound>-1 && \
		    [lsearch {use_closest interpolate} $fillMethod]>-1} {
		set interFract [expr ($newTime-$loWraps*$paramData(wrapAroundPoint,$node)-[lindex $setFromSeries($list) $loBound])/([lindex $setFromSeries($list) $hiBound]+($hiWraps-$loWraps)*$paramData(wrapAroundPoint,$node)-[lindex $setFromSeries($list) $loBound])]
		if {[string equal interpolate $fillMethod]} {
		    set setFromSeries($topNode,$node,next) $loBound
		    # cos that's what wraps refers to...now do interpolation
		    set loTime [lindex $setFromSeries($list) $loBound]
		    set hiTime [lindex $setFromSeries($list) $hiBound]
# concats are hack to make this work with or without array indices -- cannot
# use *  without , as one time may be prefix of another
		foreach loValue [concat [array names paramData $node,$loTime] \
				     [array names paramData $node,$loTime,*]] \
			hiValue	[concat [array names paramData $node,$hiTime] \
				     [array names paramData $node,$hiTime,*]] {
		    set midValue [expr $paramData($hiValue)*$interFract + \
				      $paramData($loValue)*(1-$interFract)]
		    set tgtIndex [join [lreplace [split $loValue ,] 1 1] ,]
		    PlaceInArray $topNode $tgtIndex $midValue 0 $inC
		}
		    return $next ;# nothing has changed it yet
		}
		if {$interFract>0.5} { ;# fillMethod is USE_CLOSEST
		    set loBound $hiBound
		    set loWraps $hiWraps
		}
	    }
	    if {[string equal none $fillMethod]} {
		if {$setFromSeries($topNode,$node,active)} {
		    incr setFromSeries($topNode,$node,active) -1
		    if {!$setFromSeries($topNode,$node,active)} {
			tcl_zeroparam $node
		    }
		}
		if {$hiBound>-1} {
		    set later [expr {([lindex $setFromSeries($list) $hiBound]+$hiWraps*$paramData(wrapAroundPoint,$node))*$paramData(timePointInterval,$node)}]
		    if {$later<$next} {
			set next $later
		    }
		}
	    }

# any but interpolate: change value (or have nonzero if none) only if new
# value in series reached

	    if {$loBound>-1 && 
		($loBound != $setFromSeries($topNode,$node,next) || \
		 $loWraps != $setFromSeries($topNode,$node,wraps))} {
		set useTime [lindex $setFromSeries($list) $loBound]
		set setFromSeries($topNode,$node,next) $loBound
		set setFromSeries($topNode,$node,wraps) $loWraps
		set setFromSeries($topNode,$node,active) 1
		foreach tsValue [concat [array names paramData $node,$useTime] \
				     [array names paramData $node,$useTime,*]] {
		    set tgtIndex [join [lreplace [split $tsValue ,] 1 1] ,]
		    PlaceInArray $topNode $tgtIndex $paramData($tsValue) 0 $inC
		}
	    }
    if {$fillMethod eq "none" && $setFromSeries($topNode,$node,active)} {
	set ::event(seriesSign) [getinfo $node 8]
    }
    return $next
}

proc loses {prob phase} {
    global ts dts
    if {$prob <= 0 || $ts(0)==-1} {
	return 0
    } elseif {$prob >= 1} {
	return 1
    } else {
	set kills_per_step [expr $ts(0)?4:1]
	return [expr [ame_rand 0 1] > \
		    pow(1-$prob, $dts($phase)/$kills_per_step)]
    }
}

# delete_list is a dummy procedure. What it should do is clear the
# submodel instances from the list supplied, but since (a) it would also
# need the parent namespace and (b) they tend to get reused anyway in
# tcl, I have not bothered.

proc delete_list {list_id} {
}

# When there are multiple models, prune will be called with some reference
# to the source namespace. For now we add that inside the proc...

proc prune {target metaTxt idCount} {
    upvar 1 $metaTxt meta
    set status 1
    while {[string compare [set $meta] 0] && \
                [set status [compare_instance_status \
                [set submodelptr [set $meta]]::instanceid \
                $target $idCount]]==-1} {
        set $meta [set ${submodelptr}::next]
        namespace delete $submodelptr
    }
    return [expr !$status]
}

proc init_pop {metaTxt crNode ptCount channelId maker name} {
    upvar 1 $metaTxt meta
    set lastIndx [expr $ptCount+int([max 0 $crNode])]
    while {$ptCount<$lastIndx} {
	incr ptCount
	if {[prune $ptCount meta 1]} {
	    set submodelptr [set $meta]
	    set ${submodelptr}::new_instance 0
	    set $meta [set ${submodelptr}::next]
	} else { ;# Instance exists
#	    ${byrecspointer}::submodel1maker submodel1<$loop>
#	    set submodel1pointer ${byrecspointer}::submodel1<$loop>
	    # fantasy cmd replacing above:
	    set submodelptr [eval [list $maker] $name<$ptCount>]
	    set ${submodelptr}::instanceid $ptCount
	    set ${submodelptr}::new_instance 1
	} ;# end(cond,Instance exists)
	set ${submodelptr}::baseptrs(0) NULL
	set ${submodelptr}::channelId $channelId

	set ${submodelptr}::next [set $meta]
	set $meta $submodelptr
	set meta ${submodelptr}::next
    }
    return $lastIndx
}

proc compare_instance_status {testInstName refInst num} {
    upvar 1 $testInstName testInst
    #    ShowMess debug info "testInst $testInst refInst $refInst" ok
    if {[string match 0 $testInst]} {return 1}
    for {set ptr 0} {$ptr < $num} {incr ptr} {
        if {[lindex $testInst $ptr]<[lindex $refInst $ptr]} {return -1}
        if {[lindex $testInst $ptr]>[lindex $refInst $ptr]} {return 1}
    }
    return 0
}

proc compare_values {v1 indexTxt v2 length step} {
    # ShowMess debug info "compare_values\n$v1\n$indexTxt\n$v2\n$length\n$step" ok
    upvar 1 $indexTxt index
    compare_lists 1 $v1 index $v2 $length $step
}

proc compare_lists {count nestlist1 indexTxt list2 length step} {
    upvar 1 $indexTxt index

    set hunting 2

    while {$hunting==2} {
        if {$index >= $length} {
            set hunting 0
        } else {
            set list1 [lindex $nestlist1 $index]
            set hunting [compare_tcl_lists $count $list1 $list2]
            if {$hunting == 2} {
                incr index $step
            }
        }
    }
    return $hunting
}

proc compare_tcl_lists {count list1 list2} {

    for {set ptr 0} {$ptr < $count} {incr ptr} {
        set diff [expr [lindex $list1 $ptr]-[lindex $list2 $ptr]]
        if {$diff < 0} {
            return 2 ; Dead parent condition
        }
        if {$diff > 0} {
            return 0 ; Non-existence condition
        }
    }
    return 1
}
proc init_pop_member {new_one index channel} {
    upvar 1 $new_one tgt

    set ${tgt}::instanceid $index
    set ${tgt}::baseptrs(0) NULL ;# overwritten in generated code if has parent
    set ${tgt}::channelId $channel
    set ${tgt}::new_instance 1
    set ${tgt}::next 0
}

proc assign_if_max {sample payload runner pick} {
    upvar 1 $runner runnerV
    if {$sample > $runnerV} {
	upvar 1 $pick pickV
	set runnerV $sample
	set pickV $payload
    }
}

proc assign_if_min {sample payload runner pick} {
    upvar 1 $runner runnerV
    if {$sample < $runnerV} {
	upvar 1 $pick pickV
	set runnerV $sample
	set pickV $payload
    }
}

proc ame_rand {lowBound highBound} {
    return [expr $lowBound +[random01]*($highBound - $lowBound)]
}


proc stop_on_id {compId code} {
    error "User-defined interruption code $code"
}

proc stop {code} {
    stop_on_id 0 $code
}

proc GetCompProperty {topNode prop args} {
    global runState
       
    if {[RunningInC $topNode]} {
	set result [eval GetCCompProperty $topNode $prop $args]
    } else {
	set result [eval GetTclCompProperty $topNode $prop $args]
    }
#puts "result $result"
    return $result
}

proc GetTclCompProperty {topNode prop args} {
    global nodecount nodedata phasecount steps
    set node [lindex $args 0]
    set set [lrange $args 1 end]
#    set nodecount [set nodecount]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Objects {
	    set result {}
# objects must be in order for ModelInspector to work
	    for {set record 2} {$record<=$nodecount} {incr record} {
		lappend result [lindex $nodedata($record) 0]
	    }
	    return $result
	} SetStep { ;# node is actually time
	    set steps($set) $node
	    return $phasecount
	} Class|Type|Eval {
	    array set propData [list Class 11 Type 0 Eval 5]
	    set extracted [getinfo $node $propData($prop)]
	    if {[string is integer $extracted]} {
		return ENUM([expr -10-$extracted])
	    } else {
		return $extracted
	    }
	} Dims|Trans {
	    set dimRefs [GetFullDims [FindRecord $node] typeList]
	    set count 0
	    set transList {}
	    while {$count<[llength $dimRefs]-1} {
		set aDim [lindex $dimRefs $count]
		if {[lsearch {START_VM END_VM} $aDim]>-1} {
		} elseif {$aDim<=-10} {
		    set usedET [lindex $typeList \
				    [expr [llength $typeList]+$aDim+9]]
		    lset dimRefs $count [lindex $usedET 0]
		    lappend transList [lrange $usedET 1 end]
		} elseif {[string equal FLAG $aDim]} {
		    lset dimRefs $count 2
		    lappend transList [list boolean false true]
		} else {
		    lappend transList {}
		}
		incr count
	    }
	    if {[string equal Dims $prop]} {
		return $dimRefs
	    } else {
		set vType [getinfo $node 0]
		if {[string is integer $vType]} {
		    set usedET [lindex $typeList \
				    [expr [llength $typeList]+$vType+9]]
		    lappend transList [lrange $usedET 1 end]
		} elseif {[string equal FLAG $vType]} {
		    lappend transList [list false true]
		} else {
		    lappend transList {}
		}
		return $transList
	    }
	} Graph {
	    set index [getinfo $node 8]
	    if {[llength $set]} {
		eval {setup_graph_data $index} $set
	    } else {
		return [graph_table 21 $index]
	    }
	} Caption {
	    return [GetFullCaption [FindRecord $node]]
#ShowMess debug info "node $node data [array get nodedata] npath $numericPath" ok
	} IdFromCapt {
	    foreach record [array names nodedata] {
		if {![string equal GHOST [lindex $nodedata($record) 6]]} {
		    set poss [GetFullCaption $nodedata($record)]
		    if {[string equal $node $poss]} {
			return [lindex $nodedata($record) 0]
		    }
		}
	    }
	    return nomatch
	} MinVal {
	    getinfo $node 9
	} MaxVal {
	    getinfo $node 10
	} Name|Spec|Desc|Comment {
	    set which [lsearch {Name Spec Desc Comment} $prop]
	    set targetVar [lindex [getinfo $node 12] $which]
	    if {![string equal NULL $targetVar]} {
		return [set ::$targetVar]
	    }
	}
    }
}

proc GetTclCompExecData {topNode prop args} {
    set node [lindex $args 0]
    set incoming [lrange $args 1 end]
    switch -regexp $prop {
	Value {
	    return [tcl_insert $node [lindex $incoming 0]]
	} default {
	    error "Property $prop not available in debug mode"
	}
    }
}

proc ParentLine {line} {
    global nodedata
    set handle [lindex $line 8]
    if {[lindex $handle end-1]<0} {
	set ptHand [lreplace $handle end-2 end 0]
    } else {
	set ptHand [lreplace $handle end-1 end 0]
    }
    foreach record [array names nodedata] {
	if {[ListSameNumbers [lindex $nodedata($record) 8] $ptHand]} {
	    return $nodedata($record)
	}
    }
}    

proc ListSameNumbers {list1 list2} {
    set target [llength $list1]
    if {$target != [llength $list2]} {return 0}
    for {set count 0} {$count < $target} {incr count} {
        if {[lindex $list1 $count] != [lindex $list2 $count]} {return 0}
    }
    return 1
}

proc GetFullCaption {line} {
    if {[llength [lindex $line 8]] < 3} {
	return {}
    } else {
	set parentCapt [GetFullCaption [ParentLine $line]]
	append parentCapt / [set ::[lindex [lindex $line 13] 0]]
	return $parentCapt
    }
}				      

proc TypeAsList {arrName count} {
    upvar \#0 $arrName arrVal
    upvar \#0 $arrVal($count,2) tName
    set result [list $arrVal($count,1) $tName]
    upvar \#0 $arrVal($count,3) arrTypes
    for {set elt 1} {$elt<=$arrVal($count,1)} {incr elt} {
	upvar \#0 $arrTypes($elt) arrTxt
	lappend result $arrTxt
    }
    return $result
}

proc GetFullDims {line ETptrs} {
#do_in_editor puts $handle
    upvar 1 $ETptrs localETs
    if {[llength [lindex $line 8]] < 3} {
	set parentDims 0
	set localETs {}
    } else {
	set ptLine [ParentLine $line]
	set parentDims [GetFullDims $ptLine localETs]
    }
# add this levels type data -- reverse order cos outer models start list
    set count [lindex $line 2]
    while {$count} {
	lappend localETs [TypeAsList [lindex $line 3] $count]
	incr count -1
    }
# correct earlier enum type references to take account of this level
    set count [llength $parentDims]
    while {$count} {
	incr count -1
	set oVal [lindex $parentDims $count]
	if {$oVal<=-10} {
	    lset parentDims $count [expr $oVal-[lindex $line 2]]
	}
    }
    set parentDims [concat [lrange $parentDims 0 end-1] [lindex $line 7]]
    return $parentDims
}				      
	    
proc FillListValues {nextRefPtr newTree type innerDims listDims dimPlace} {
    upvar 1 $nextRefPtr nextRef
#puts "FLV $nextRef $listDims $dimPlace"
    set result {}
    set smHandle $nextRef
    set nextElt [set [burrow_to $smHandle {2 0} dummy]]
    set newDimPlace [expr $dimPlace+1]
    while {[string match $listDims [lrange $nextElt 0 $dimPlace]]} {
	if {[llength $nextElt] == $newDimPlace} {
	    set result [FillValue $smHandle $newTree $type $innerDims {} 0 {}]
	    set nextRef [set [burrow_to $smHandle {1 0} {}]]
	} else {
	    set newIndex [lindex $nextElt $newDimPlace]
	    set subVals [FillListValues nextRef $newTree $type $innerDims \
				[concat $listDims $newIndex] $newDimPlace]
	    if {[llength $subVals]} {
		lappend result $newIndex $subVals
	    }
	}
	if {[string compare $nextRef 0]} {
	    set smHandle $nextRef
	    set nextElt [set [burrow_to $smHandle {2 0} {}]]
	} else {
	    break
	}
    }
    return $result
}

proc FillValue {smHandle tree type useDims dims dimPlace newVals} {
#puts "filling tree $tree bounds $useDims inds $dims place $dimPlace"
    set nextUseDim [lindex $useDims 0]
    if {[lsearch {MEMBERS START_VM} $nextUseDim]!=-1} {
	set breakPt [lsearch $tree -1]
	set oldTree [lrange $tree 0 [expr $breakPt-1]]
	set newTree [lrange $tree [expr $breakPt+1] end]
	set nextRef [set [burrow_to $smHandle $oldTree $dims]]
	set result {}
	array set arrayVals $newVals

	if {[string compare $nextRef 0]} {
	    if {[string equal START_VM $nextUseDim]} {
		set cutDim [expr [lsearch $useDims END_VM]+1]
	    } else {
		set cutDim 1
	    }
	    return [FillListValues nextRef $newTree $type \
			[lrange $useDims $cutDim end] {} -1]
	} else {
	    return
	}

#	while {[string compare $nextRef 0]} {
#	    set smHandle do_model $nextRef
#	    set nextElt [set [burrow_to $smHandle {2 0} {}]]
#	    lappend result $nextElt
#	    if {[info exists arrayVals($nextElt)]} {
#		set eltVals $arrayVals($nextElt)
#	    } else {
#		set eltVals {}
#	    }
#	    lappend result [FillValue $smHandle $newTree $type \
#		    [lrange $useDims 1 end] {} 0 $eltVals]
#	    set nextRef [set [burrow_to $smHandle {1 0} {}]]
#	}
#	return $result	    
    }  elseif {$nextUseDim==0} {
	if {[string match VALUELESS $type]} {
	    return sm
	} else {
	    set tgtVar [burrow_to $smHandle $tree $dims]
	    set oldVal [set $tgtVar]
	    if {[llength $newVals]} {
		set $tgtVar $newVals
	    }
	    return $oldVal
	}
    } else {
	if {[string equal RECORDS $nextUseDim]} {
	    set tgtVar [burrow_to $smHandle $tree [concat $dims REQ_COUNT]]
	    set nextUseDim [set $tgtVar]
	}
	array set arrayVals $newVals
	set result {}
	for {set nextDim 1} {$nextUseDim>=$nextDim} \
		{incr nextDim} {
	    if {[info exists arrayVals($nextDim)]} {
		set eltVals $arrayVals($nextDim)
	    } else {
		set eltVals {}
	    }
	    set subVals [FillValue $smHandle $tree $type \
		    [lrange $useDims 1 end] \
		    [concat $dims $nextDim] [expr $dimPlace+1] $eltVals]
	    if {[llength $subVals]} {
		lappend result $nextDim $subVals
	    }
		    
	}
	return $result
    }
}

proc burrow_to {level id_meta dim_list} {
    while {[lindex $id_meta 0]>0} {
	set lastDim $dim_list
	append level ::[${level}::get_pointer [step_list id_meta 1] dim_list]
	if {[string equal REQ_COUNT [lindex $lastDim 0]] && \
		![string equal $dim_list $lastDim]} {
	    break;
	}
	if {[lindex $id_meta 0]==-1} {
	    set inst1 [set ::$level]
	    set nInds [llength [set ${inst1}::instanceid]]
	    append level <[lrange $dim_list 0 [expr $nInds-1]]>
	    set dim_list [lrange $dim_list $nInds end]
	    set id_meta [lrange $id_meta 1 end]
	}
    }
    return $level
}
	
proc step_list {dimList climb} {    
    upvar $climb $dimList useList
    set head [lindex $useList 0]
    set useList [lrange $useList 1 end]
    return $head
}

proc requests_record_count {dimList} {
    upvar 2 $dimList useList
    return [string equal REQ_COUNT $useList]
}

proc glob_element {arrptr phase} {
    upvar #0 $arrptr arr
    return $arr($phase)
}

# utility procs needed in both interps

proc min {first last} {
    return [expr $first<$last?$first:$last]
}

proc max {first last} {
    return [expr $first>$last?$first:$last]
}

proc following {lo} {
    return [expr $lo+1] ;# fn will accept floats so better work with them
}

proc preceding {lo} {
    return [expr $lo-1] ;# fn will accept floats so better work with them
}

proc first {lo} {
    return [expr $lo==1] ;# fn will accept floats so better work with them
}

proc res {value} {
    global fromEditor
    set fromEditor [list res $value]
}

proc err {value} {
    global fromEditor
    set fromEditor [list err $value]
}

########################### stuff for both languages below ###############
proc PlaceInArray {topNode where what when inC} {
    #puts "PlaceInArray $where $what $inC"
    set map [split $where ,]
    if {$inC} {
	if {$when} {
	    c_settimepointelement $topNode [lindex $map 0] \
		[lrange $map 2 end] [lindex $map 1] $what
	} else {
	    c_setparamelement $topNode [lindex $map 0] \
		[lrange $map 1 end] $what
	}
    } else {
	if {$when} {
	    tcl_settimepointelement [lindex $map 0] [lrange $map 1 end] $what
	} else {
	    tcl_setparamelement [lindex $map 0] [lrange $map 1 end] $what
	}
    }
}

proc MarkEvtParamActive {topNode node inC} {
    if {$inC} {
	c_markevtparamactive $topNode $node
    } else {
	set ::setFromSeries($topNode,$node,active) 2
    }
}

proc SetWrapTime {topNode inC where args} {
    global paramData
    if {$inC} {
	eval c_setwraparoundtime $topNode $where $args
    } else {
	eval set paramData(wrapAroundPoint,$where) $args
    }
}

# this one takes numerical for c and textual for tcl
proc SetFillMethod {topNode inC where {what {}}} {
    global paramData

    set fillMtds {use_last use_closest interpolate}
    if {[string length $what]} {
	if {[set which [lsearch $fillMtds [string tolower $what]]]<0} {
	    error "bad fill method: $what"
	}
    } else {
	set which {}
    }
    if {$inC} {
	lindex $fillMtds [eval c_setfillmethod $topNode $where $which]
    } else {
	eval set paramData(fillMethod,$where) [string toupper $what]
    }
}

proc SetInterval {topNode inC where {what {}} {howLong {}}} {
    global paramData

    if {[string length $what]} {
	set paramData(uftsi,$where) $what
	if {$inC} {
	    eval c_setinterval $topNode $where $howLong
	} else {
	    set paramData(timePointInterval,$where) $howLong
	}
    } else {
	return $paramData(uftsi,$where)
    }
}
