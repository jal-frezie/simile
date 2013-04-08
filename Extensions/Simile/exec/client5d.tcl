# This should be replaced with a Tcl command to load Simile from a certain path
# ...like this:
proc UseSimileAt {path} {
    global env tcl_platform auto_path custom SIMILE_PATH
    set SIMILE_PATH [file normalize $path]

    source [file join $SIMILE_PATH Run setup.tcl]

    append env(PATH) ";[file nativename $env(SYSDIR)/bin]" ;# for Windows

# for Ame_dll to load the 5-D sharelib on Mac (and Linux for 5.9 on) 
# the wd has to be right relative to it
    set oldWD [pwd]
    cd $SIMILE_PATH/Examples
    package require Ame_dll
    randseed [clock seconds]
    cd $oldWD

    package require Unpacker
    package require Trf
    c_testlicense ;# sets edition 
    loadcommands ;# for unpacker -- edition checked here

## Start of stuff needed to load and execute Simile code for reading .spfs
    set ::simtmpdir [file join $custom(prefDir) cl5d]
    file mkdir $::simtmpdir 

# No messages should be displayed so translation not needed
    proc tr. {en} {return $en}

    uplevel \#0 {
	source $SIMILE_PATH/Run/utility.tcl
	source $SIMILE_PATH/Run/support.tcl
	set simplify 1
	source $SIMILE_PATH/Run/graphs.tcl ;# for loading tabular data
	unset simplify
	source $SIMILE_PATH/Run/params.tcl ;# for loading .spfs
    }
}

set paramData(needed) {}
# parameter sources ; these are used in specifying data popups
set msgs(metafile_ref)  {}
set msgs(metafile_lit)  {}
set msgs(metafile_bin)  {}
set msgs(direct_ref) {}

## called but not supplied
proc RunningInC {args} {
    return 1 ;# we always are
}

# report queries to console and take default action
proc Query {act level topic win opts} {
    set response [lindex $opts 0]
    puts "Simile problem occurred."
    puts "Identification: $act"
    puts "Severity level: $level"
    puts "Action taken: $response"
    return $response
}

# from exec.tcl -- workaround for hideous old stuff in params.tcl
proc c_setparamarray {topNode tgtNode} {
    set ::param_id($tgtNode) [c_createparamarray $::cbInstanceId $tgtNode]
}

# Old versions of these (identifying parameters by target node id) are passed
# to the exec thread. These calls now also have the top node to identify the
# right exec thread, so strip it off here
foreach oldCProc {setparamelement settimepointelement settimepointarray \
		      cleartimeseries setwraparoundtime setfillmethod \
		      setinterval \
		      setrecordlist settimepointrecords markevtparamactive \
		      setparamall getparamall settimepointall gettimepointall} {
    proc c_$oldCProc {args} {
	set cmd [info level 0]
	return [eval [list new[lindex $cmd 0] $::param_id([lindex $cmd 2])] \
		    [lrange $cmd 3 end]] ;# elt 1 (2nd) is top node
    }
}

# here is the scripting command to do it
proc ConsultParameterMetafile {instanceHandle fileLocn {targetSubmodel {}}} {
    set mHandle $::modelTypes($instanceHandle)
    set ::cbModelId $mHandle
    set ::cbInstanceId $instanceHandle
    set topNode [lindex [listobjects $mHandle] 0]
    foreach component [ListObjPaths $mHandle] {
	set ::readMany(/$topNode$component) \
	    [string equal INPUT [GetModelProperty $mHandle $component Eval]]
    }
    ZapParams $topNode $targetSubmodel [file normalize $fileLocn] 0
}
## End of parameter loading accessories 

proc GetModelProperty {model_id path prop} {
    set node [getnodeid $model_id $path]
    return [GetCCompPropById $model_id $prop $node]
}

proc GetCompProperty {topNode prop node} {
# now only needed for v5.x
    return [GetCCompPropById $::cbModelId $prop $node]
}

proc GetCCompProperty {topNode prop node} {
    return [GetCCompPropById $::cbModelId $prop $node]
}

proc GetCCompPropById {model_id prop node} {
    set numberWangs Caption|MinVal|MaxVal|Trans|Spec|Desc|Comment
    switch -regexp $prop [list \
	Class|Type|Eval {
	    array set propData [list Class,cIdx 11 Class,names \
			      {SUBMODEL VARIABLE COMPARTMENT FLOW CONDITION \
			       CREATION REPRODUCTION IMMIGRATION LOSS ALARM \
			       EVENT SQUIRT STATE} \
			    Type,cIdx 1 Type,names \
			    {VALUELESS REAL INTEGER FLAG EXTERNAL} \
			    Eval,cIdx 2 Eval,names \
			    {EXOGENOUS DERIVED TABLE INPUT SPLIT GHOST}]
	    set numericVal [getvalue $model_id $node $propData($prop,cIdx)]
	    if {![string is integer -strict $numericVal]} {
		return $numericVal
	    }
	    if {[string equal Type $prop] && $numericVal>=10} {
		return ENUM([expr $numericVal-10])
	    } else {
		return [lindex $propData($prop,names) $numericVal]
	    }
	} Dims {
	    set specials {RECORDS MEMBERS SEPARATE START_VM END_VM}
	    set fullList [getvalue $model_id $node 0]
	    
	    set idx 0
	    foreach elt $fullList {
		if {$elt<0} {
		    lset fullList $idx [lindex $specials [expr -$elt-1]]
		}
		incr idx
	    }
	    return $fullList
	} $numberWangs {
	    set dataWang [lindex {5 6 8 12 13 14 15} \
			      [lsearch [split $numberWangs |] $prop]]
	    return [getvalue $model_id $node $dataWang]
	} IdFromCapt {
	    # node is actually caption in this case
	    if {[catch {getnodeid $model_id $node} res]} {
		set res nomatch
	    } 
	    return $res
	}
			 ] ;# must be list to substitute last case
}

proc CreateTimeSeriesStructs {mHandle iHandle} {
    foreach component [ListObjPaths $mHandle] {
	if {[string equal INPUT [GetModelProperty $mHandle $component Eval]]} {
	    CreateParamArray $iHandle $component
	}
    }
}

proc CreateModel {mHandle} {
    set iHandle [c_createmodel $mHandle]
    set ::modelTypes($iHandle) $mHandle
# infinite loop result if run without setting time step so create defaults
    for {set st 1} {$st<8} {incr st} {
	c_setstepmodel $iHandle 0.1 $st
    }
    CreateTimeSeriesStructs $mHandle $iHandle
# create structures for time series parameters
    return $iHandle
}

proc GetPairedValues {iHandle outputNode asEnumType} {
    set bloc [handle_data dummyMHandle $iHandle \
		  [getnodeid $::modelTypes($iHandle) $outputNode]]
    set result [extract_list $bloc 16777216]
    free_data_handle $bloc
    if {$asEnumType} {
	set types [GetModelProperty $::modelTypes($iHandle) $outputNode Trans]
	set result [TransEnums $types $result yes]
    }
    return $result
}

# lifted from v5.9
proc TransEnums {transList vals fromNums} {
    set curLevel [lindex $transList 0]
    if {[llength $vals]==1} {
	return [TransValue $curLevel $vals $fromNums]
    } else {
# speed: if no defns, just return arg
	if {[lsearch -regexp $transList .] == -1} {return $vals}
	set argTrans [lrange $transList 1 end]
	set result {}
	foreach {index subVals} $vals {
	    lappend result [TransValue $curLevel $index $fromNums] \
		[TransEnums $argTrans $subVals $fromNums]
	}
	return $result
    }
}

proc TransValue {curLevel val fromNums} {
    if {[llength $curLevel]} {
	if {$fromNums} {
	    return [lindex $curLevel $val]
	} else {
	    set poss [lsearch $curLevel $val]
	    if {$poss == -1} {
		if {[string equal false [lindex $trans 0]]} {
		    error [format [tr. {Data value %1$s is not a member of type boolean, pick one of %2$s.}] $head $trans]
		} else {
		    error [format [tr. {Data value %1%s is not a member of type %2$s, pick one of %3$s.}] $head [lindex $trans 0] [lrange $trans 1 end]]
		}
	    }
	    return $poss
	}
    } else {
	return $val
    }
}

proc ListObjPaths {mHandle} {
    foreach obj [lrange [listobjects $mHandle] 1 end] {
	lappend result [getvalue $mHandle $obj 5]
    }
    return $result
}

proc CreateParamArray {iHandle path} {
    set mHandle $::modelTypes($iHandle)
    set aHandle [c_createparamarray $iHandle \
		     [set id [getnodeid $mHandle $path]]]
    set ::modelInstances($aHandle) $iHandle
    set ::componentPaths($aHandle) $path
    set ::cachedDims($aHandle) [lrange [getvalue $mHandle $id 0] 0 end-1]
    return $aHandle
}

proc DimsFromList {content} {
    set len [llength $content]
    if {$len==0} {
	error "Empty sublist"
    } elseif {$len==1} {
	return {}
    } else {
	set goodDims [DimsFromList [lindex $content 0]]
	foreach sublist [lrange $content 1 end] {
	    if {[DimsFromList $sublist] != $goodDims} {
		error "Unmatched sublists"
	    }
	}
	return [concat [list $len] $goodDims]
    }
}

proc RecursiveInsert {aHandle content indexList} {
    if {[llength $content]==1} {
	newc_setparamelement $aHandle $indexList $content
    } else {
	set localIndex 0
	foreach sublist $content {
	    RecursiveInsert $aHandle $sublist \
		[concat $indexList [list [incr localIndex]]]
	}
    }
}

proc SetParamArrayFromList {aHandle content} {
    if {[DimsFromList $content] != $::cachedDims($aHandle)} {
	error "Failed -- dims do not match"
    }
    RecursiveInsert $aHandle $content {}
}

proc SharpenList {flatList dims} {
    if {[llength $dims]>1} {
	set flatList [SharpenList $flatList [lrange $dims 1 end]]
	set dims [lindex $dims 0]
    }
    while {[llength $flatList]} {
	lappend result [lrange $flatList 0 $dims-1]
	set flatList [lrange $flatList $dims end]
    }
    return $result
}

proc SetParamArrayFromFlatList {aHandle content asEnumType {dims {}}} {
    if {$asEnumType} {
	set types [GetModelProperty $::modelTypes($::modelInstances($aHandle)) \
		       $::componentPaths($aHandle) Trans]
	set content [TransEnums $types $content no]
    }
    if {![llength $dims]} {
	newc_setparamelement $aHandle {} $content
    } else {
	SetParamArrayFromList $aHandle [lindex [SharpenList $content $dims] 0]
    }
}

proc IntMethodID {intMethod} {
    lsearch {euler runge-kutta} [string tolower $intMethod]
}

proc ResetModel {iHandle t0 intMethod depth} {
    set ::currentTimes($iHandle) $t0
    c_resetmodel $::modelTypes($iHandle) $iHandle $t0 \
	[IntMethodID $intMethod] $depth
}

proc ExecuteModel {iHandle intMethod from to errLim evtPause} {
    set result [c_executemodel $::modelTypes($iHandle) $iHandle \
		    [IntMethodID $intMethod] $from $to $errLim $evtPause]
    set ::currentTimes($iHandle) [lindex $result 1]
    return [lindex $result 0]
}

proc GetModelTime {iHandle} {
  return $::currentTimes($iHandle)
}