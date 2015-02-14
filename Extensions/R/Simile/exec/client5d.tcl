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
	source $SIMILE_PATH/Run/exec.tcl
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

# report queries to console and take default action
proc Query {act level topic win opts} {
    set response [lindex $opts 0]
    puts "Simile problem occurred."
    puts "Identification: $act"
    puts "Severity level: $level"
    puts "Action taken: $response"
    return $response
}

# ignore GUI updates by default
proc AbortCheck {nodeId} {
    return 0
}
proc InteractGUI {nodeId time mode} {
    return 0
}

# would be provided by Prolog in Simile
proc InDays {unit} {
    array set timeLib {second 1.0/86400 minute 1.0/1440 hour 1.0/24 day 1.0 \
			   unit 1.0 week 7.0 month 365.0/12 year 365.0}
    return [expr $timeLib($unit)]
}

# here is the scripting command to do it
proc ConsultParameterMetafile {instanceHandle fileLocn {targetSubmodel {}}} {
    set mHandle $::modelTypes($instanceHandle)
    set ::cbModelId $mHandle
    set ::instance_id $instanceHandle
    set topNode [lindex [listobjects $mHandle] 0]
    foreach component [ListObjPaths $mHandle] {
	set ::readMany(/$topNode$component) \
	    [string equal INPUT [GetModelProperty $mHandle $component Eval]]
    }
    ZapParams $topNode $targetSubmodel [file normalize $fileLocn] 0
}
## End of parameter loading accessories 

# now we need something similar to set the value of a single parameter
proc SetParameter {accessHandle value} {
    set ::param_id(dummy) $accessHandle
    set mHandle $::modelTypes($::modelInstances($accessHandle))
    set path $::componentPaths($accessHandle)
    set trans [GetModelProperty $mHandle $path Trans]
    set dims $::cachedDims($accessHandle) ;# needs subbing for per-rec?
    set times [string equal INPUT [GetModelProperty $mHandle $path Eval]]
    if {$times} {
        set dims [linsert $dims 0 TIME]
    }
    return [ListToArray DUMMY dummy {} {} $trans $dims $value $times 1]
}

proc GetModelProperty {modelId path prop} {
    set node [getnodeid $modelId $path]
    set ::model_id $modelId
    return [GetCCompProperty DUMMY $prop $node]
}

proc GetCompProperty {topNode prop args} {
    return [eval GetCCompProperty DUMMY $prop $args]
}

proc CreateTimeSeriesStructs {mHandle iHandle} {
    foreach component [ListObjPaths $mHandle] {
	if {[string equal INPUT [GetModelProperty $mHandle $component Eval]]} {
	    CreateParamArray $iHandle $component
	}
    }
}

proc CreateModel {mHandle} {
    set ::nodeId C5
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
    set result [GetValuesById $iHandle \
		    [getnodeid $::modelTypes($iHandle) $outputNode]]
    if {$asEnumType} {
	set types [GetModelProperty $::modelTypes($iHandle) $outputNode Trans]
	set result [TransEnums $types $result yes]
    }
    return $result
}

proc GetValuesById {iHandle outputId} {
    set bloc [handle_data dummyMHandle $iHandle $outputId]
    set result [extract_list $bloc 16777216]
    free_data_handle $bloc
    return $result
}

proc GetJsonValues {iHandle outputNode} {
    return [GetJsonValuesById $iHandle \
		[getnodeid $::modelTypes($iHandle) $outputNode]]
# if we need enums transed, do in php or javascript
}

proc GetJsonValuesById {iHandle outputId} {
    set bloc [handle_data dummyMHandle $iHandle $outputId]
    set result [extract_json $bloc 16777216]
    free_data_handle $bloc
    return $result
}

# lifted from hai2mmii.tcl v5.9
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

proc DoResetModel {iHandle t0 intMethod depth} {
    set ::instance_id $iHandle
    set ::model_id $::modelTypes($iHandle)
    set ::currentTimes($iHandle) $t0
    return [ResetModel dummy $intMethod $t0 $depth]
}

proc DoExecuteModel {iHandle intMethod from to errLim pauses} {
    set ::instance_id $iHandle
    set ::model_id $::modelTypes($iHandle)
    set result [ExecuteModel dummy $intMethod $from $to $errLim $pauses $pauses]
    set ::currentTimes($iHandle) [lindex $result 1]
    return [lindex $result 0]
}

proc GetModelTime {iHandle} {
  return $::currentTimes($iHandle)
}
