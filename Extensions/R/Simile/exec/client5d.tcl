# This should be replaced with a Tcl command to load Simile from a certain path
# ...like this:
proc UseSimileAt {path} {
    global env tcl_platform SIMILE_PATH
    set SIMILE_PATH $path

# From simile.tcl --  sets libraries to 32 or 64 bit version per Tcl bitness
# (right version must be installed, wrong one can be too)
    set tclBitness [expr {8*$tcl_platform(wordSize)}]
    if {[info exists tcl_platform(pointerSize)]} {
	set tclBitness [expr {8*$tcl_platform(pointerSize)}]
    }
    set env(SYSDIR) [file join $SIMILE_PATH System]
    if {$tclBitness==64} {
	append env(SYSDIR) 64
    }
    set ::auto_path [list $env(SYSDIR)/lib]
    append env(PATH) ";[file nativename $env(SYSDIR)/bin]" ;# for Windows

    set savedCredentials [list prologId interfaceId install_time license_code \
			      licensee_name licensee_corp]
    set UserStream [open $SIMILE_PATH/Run/userinfo.txt r]
    foreach regEntry $savedCredentials {
	gets $UserStream env($regEntry)
    }
    close $UserStream

# for Ame_dll to load the 5-D sharelib on Mac (and Linux for 5.9 on) 
# the wd has to be right relative to it
    set oldWD [pwd]
    cd $SIMILE_PATH/Examples
    package require Ame_dll
    cd $oldWD

    package require Unpacker
    package require Trf
    loadcommands ;# for unpacker

## Start of stuff needed to load and execute Simile code for reading .spfs

    switch $tcl_platform(os) {
	"Windows NT" {
	    if {[info exists ::loadedFromR]} {
		set docsDir . ;# home dir already includes "Documents"
	    } elseif {$tcl_platform(osVersion)>=6.0} {
		set docsDir Documents
	    } else {
		set docsDir "My Documents"
	    }
	    set tail [file join $docsDir "My Simile files"]
	} Darwin {
	    set tail Simile
	} default {
	    set tail .simile
	}
    }
    set ::simtmpdir [file join $env(HOME) $tail]

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

# from exec.tcl -- workaround for hideous old stuff in params.tcl
proc c_setparamarray {topNode tgtNode} {
    set ::param_id($tgtNode) [c_createparamarray $::cbInstanceId $tgtNode]
}

# Old versions of these (identifying parameters by target node id) are passed
# to the exec thread. These calls now also have the top node to identify the
# right exec thread, so strip it off here
foreach oldCProc {setparamelement settimepointelement settimepointarray \
		      cleartimeseries setwraparoundtime setfillmethod \
		      setrecordlist settimepointrecords markevtparamactive \
		      setparamall getparamall settimepointall gettimepointall} {
    proc c_$oldCProc {args} {
	set cmd [info level 0]
	return [eval [list new[lindex $cmd 0] $::param_id([lindex $cmd 2])] \
		    [lrange $cmd 3 end]] ;# elt 1 (2nd) is top node
    }
}

proc GetCompProperty {topNode prop node} {
    global cbModelId

    switch -regexp $prop [list \
	IdFromCapt {
	    # node is actually caption in this case
	    if {[catch {getnodeid $cbModelId $node} res]} {
		set res nomatch
	    } 
	} default {
	    set res [GetCCompProperty $cbModelId $prop $node]
	}
			 ]
    return $res
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
    ZapParams $topNode $targetSubmodel $fileLocn
}
## End of parameter loading accessories 

proc GetModelProperty {model_id path prop} {
    set node [getnodeid $model_id $path]
    GetCCompProperty $model_id $prop $node
}

proc GetCCompProperty {model_id prop node} {
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
	}
			 ] ;# must be list to substitute last case
}

proc CreateModel {mHandle} {
    set iHandle [c_createmodel $mHandle]
    set ::modelTypes($iHandle) $mHandle
# infinite loop result if run without setting time step so create defaults
    for {set st 1} {$st<8} {incr st} {
	c_setstepmodel $iHandle 0.1 $st
    }
    return $iHandle
}

proc GetPairedValues {iHandle outputNode} {
    set bloc [handle_data dummyMHandle $iHandle \
		  [getnodeid $::modelTypes($iHandle) $outputNode]]
    set result [extract_list $bloc 16777216]
    free_data_handle $bloc
    return $result
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

proc SetParamArrayFromFlatList {aHandle content dims} {
    SetParamArrayFromList $aHandle [lindex [SharpenList $content $dims] 0]
}

proc IntMethodID {intMethod} {
    lsearch {euler runge-kutta} [string tolower $intMethod]
}

proc ResetModel {iHandle t0 intMethod depth} {
    c_resetmodel $::modelTypes($iHandle) $iHandle $t0 \
	[IntMethodID $intMethod] $depth
}

proc ExecuteModel {iHandle intMethod from to errLim evtPause} {
    c_executemodel $::modelTypes($iHandle) $iHandle [IntMethodID $intMethod] \
	$from $to $errLim $evtPause
}
