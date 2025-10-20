#!/usr/bin/tclsh
#

proc JsonifyDict {ugly} {
    set result {}
    set safety {\n \\n}
    foreach {indx val} [string map $safety $ugly] {
	if {[string length $result]} {
	    append result {, }
	}
	if {![string is double -strict $val] && \
		[string first [string index $val 0] \[\{\"]==-1} {
	    set val \"$val\"
	}
	append result \"$indx\":\ $val
    }
    return \{$result\}
}

proc JsonifyArray {ugly} {
    set result {}
    set safety {\n \\n}
    foreach {val} [string map $safety $ugly] {
	if {[string length $result]} {
    	    append result {, }
	}
	if {![string is double -strict $val] && \
		[string first [string index $val 0] \[\{\"]==-1} {
	    set val \"$val\"
	}
	append result $val
    }
    return \[$result\]
}

#proc JsonifyAny {ugly} {
#    if {[llength $ugly]==1} {
#	set val $ugly
#	if {![string is double -strict $val] && \
#		[string first [string index $val 0] \[\{\"]==-1} {
#	    set val \"$val\"
#	}
#	return $val
#    } else {
#	set result {}
#	set safety {\n \\n}
#	foreach {indx val} [string map $safety $ugly] {
#	    if {[string length $result]} {
#		append result {, }
#	    }
#	    append result \"$indx\":\ [JsonifyAny $val]
#	}
#	return \{$result\}
#    }
#}
#
proc urlDecode {str} {
    set specialMap {"[" "%5B" "]" "%5D" + " "}
    set seqRE {%([0-9a-fA-F]{2})}
    set replacement {[format "%c" [scan "\1" "%2x"]]}
    set modStr [regsub -all $seqRE [string map $specialMap $str] $replacement]
    return [encoding convertfrom utf-8 [subst -nobackslash -novariable $modStr]]
}

proc urlEncode {str} {
    set uStr [encoding convertto utf-8 $str]
    set chRE {[^-A-Za-z0-9._~\n]};		# Newline is special case!
    set replacement {%[format "%02X" [scan "\\\0" "%c"]]}
    return [string map {"\n" "%0A"} [subst [regsub -all $chRE $uStr $replacement]]]
}

proc AnyValue {iH itm max} {
    if {[llength $itm]!=1} {
	array set bits $itm
	set hdl [handle_data dummyMHandle $iH $bits(node)]
	switch $bits(format) {
	    binary {
		set stac [extract_gif_tail $hdl $bits(bottom) $bits(top) \
			      [string is true $bits(hex)]]
		append stac [binary format cc 0 0x3b]
		set resp [base64::encode $stac]
	    } distinct {
		set resp [llength [lrange [distinct_values $hdl] 1 end]]
	    }
	}
    } else {
	set hdl [handle_data dummyMHandle $iH $itm]
	set loseZeros [expr {[lsearch {EVENT SQUIRT} \
				  [GetCCompProperty DUMMY Class $itm]]+1}]
	set resp [extract_json $hdl $max $loseZeros 1]
	# set resp [JsonifyAny [thread::send $::masterId [list extract_list $hdl $max $loseZeros]]]
	
    }
    free_data_handle $hdl
    return $resp
}
   
proc ValuesOfInterest {iH reqs} {
    set resps {}
    foreach itm $reqs {
	lappend resps [AnyValue $iH $itm 16777216]
    }
    return $resps
}

proc Sanitize {rough} {
    return [string map {\" \\\" \t \\t \\ \\\\} $rough]
}

proc ResponseTo {paramList} {
    # puts [info level 0]
    global service
    array set params $paramList
   
    switch $params(act) {
	BuildShareLib {
	    set mH $::model_id
	    set iH [c_createmodel $mH]
	    set service($params(base)) $iH
	    # Now create data structs for all parameters except per-record
	    foreach obj [listobjects $mH] {
		set isP [GetCCompProperty DUMMY Eval $obj]
		if {[lsearch [GetCCompProperty DUMMY Dims $obj] RECORDS]<0 && \
			($isP eq "INPUT" || $isP eq "TABLE" && \
			     [GetCCompProperty DUMMY Spec $obj] eq {})} {
		    # per-records too difficult -- avoid
		    # dont prevent v7 using eqn as default for fixparams
		    set ::aH($obj) [c_createparamarray $iH $obj]
		}
	    }

	    array set rps [list intMethod Euler execTime 100.0 phaseList 0.1 displayInt 1 resetTo 0 timeUnit unit errLimit 0]
	    array set rps $::web_service(parms) ;# override defaults
	    set result [JsonifyDict [array get rps]]
	} CreateSocket {
	    package require json
	    package require can2svg
	    package require base64

	    set result "Direct SIMILE Connection"
	} WaitSocket {
	    set result "Local SIMILE"
	} GetSVG {
	    set stm [open [file join $::web_service(local) for_web.svg] r]
	    fconfigure $stm -translation binary
	    set result [read $stm]
	    set line1 [string first "<svg " $result]
	    set line2 [string first "\n" $result $line1]
	    set linen [string first "\n</svg " $result]
	    set result [string replace \
			[string replace $result $linen $linen "\n</g>\n"] \
			    $line2 $line2 "\n<g id=\"mod_diag\">\n"]
	    close $stm
	} GetXMLHelperSetup {
	    if {[catch {open [file join $::web_service(local) for_web.shf] r} \
		     stm]} {
		set result {}
	    } else {
		fconfigure $stm -translation binary
		set result [read $stm]
		close $stm
	    }
	} Can2SVG {
	    foreach {tclCmd} [json::json2dict $params(cnvdraw)] {
		append result [can2svg::can2svg $tclCmd]
	    }
	} Describe - Report {
	    set mH $::model_id
	    foreach id [lrange [listobjects $mH] 1 end] {
		set path [getvalue $mH $id 5]
		if {$params(act) eq "Describe"} {
		    set parentPath [file dirname $path]
		    set dict [list parent]
		    if {$parentPath ne "/"} {
			lappend dict [getnodeid $mH $parentPath]
		    } else {
			lappend dict \#
		    }
		    lappend dict text \"[Sanitize [file tail $path]]\" \
			captpath \"[Sanitize $path]\" \
			icon images/[GetCCompProperty DUMMY Class $id].gif
		    # include path too
		    foreach {prop key} \
			{equation Spec comment Comment eval Eval min MinVal \
			     max MaxVal type Type units Units} {
			set jBit [GetCCompProperty DUMMY $key $id]
			lappend dict $prop \"[Sanitize $jBit]\"
		    }
		    lappend dict dims \
			[JsonifyArray [GetCCompProperty DUMMY Dims $id]]
		    set transList {}
		    foreach level [GetCCompProperty DUMMY Trans $id] {
			lappend transList [JsonifyArray $level]
		    }
		    lappend dict trans [JsonifyArray $transList]
		    lappend ency $id [JsonifyDict $dict]
		} else { ;# Report
		    set goodJSON [AnyValue $service($params(base)) $id 1024]
		    lappend ency $id \"[Sanitize $goodJSON]\"
		    # run.js wants strings not nested JSON objects
		}
	    }
	    set result [string map {/ \\/} [JsonifyDict $ency]]
	} Parameterize {
	    global parmTimeStamps ;# clear if reloading run.js
	    
	    set result {""}
	    array set incoming [::json::json2dict $params(data)]
	    set parmReqOrdinality $incoming(seqNo)
	    array unset incoming seqNo
	    foreach {path stack} [array get incoming] {
		set id [getnodeid $::model_id $path]
		set trans [GetCCompProperty DUMMY Trans $id]
		set times [string equal INPUT [GetCCompProperty DUMMY Eval $id]]
		set dims [GetCCompProperty DUMMY Dims $id]
		if {[lsearch $dims RECORDS]>-1} continue ;# too complicated
		if {$times} {
		    if {[info exists parmTimeStamps($id)] && \
			    $parmTimeStamps($id)>=$parmReqOrdinality} {
			continue
		    }
		    set parmTimeStamps($id) $parmReqOrdinality
		    set dims [linsert $dims 0 TIME]
		}
		if {![info exists ::aH($id)]} {
		    set ::aH($id) [c_createparamarray $service($params(base)) $id]
		}
		set ::param_id(cur) $::aH($id)
		set resp [ListToArray DUMMY {} cur {} {} $trans \
			      [lrange $dims 0 end-1] $stack $times 1]
		if {[lsearch {-1 0 1} $resp]==-1} {
		    puts $path-->$resp
		}
	    }
	} LoadSPF {
	    if {$params(base) eq "local"} {
		return [ParamsFromGUI $service($params(base))]
	    } elseif {[file exists $params(base).spf]} { ;# SimiLive
		# This is currently handled in model_action -- following is
		# experimental version
		ConsultParameterMetafile $service($params(base)) \
		    $params(base).spf
		# do whatever cpm did here
#		set allComps [listobjects $::model_id]
#		set topNode [lindex $allComps 0]
#		foreach id [lrange $allComps 1 end] {
#		    set component [getvalue $::model_id $id 5] 
#		    set eval [GetCCompProperty DUMMY Eval $id]
#		    set ::readMany($component) \
#		        [string equal INPUT $eval]
#		    if {[string equal TABLE $eval]} {
#			set ::paramData($component) {}
	    # placeholders needed for table submodels set per record
#		    }
#		}
#		ZapParams $topNode {} [file normalize $params(base).spf] 0

		set gotAll [GetCompProperty DUMMY IdFromCapt $component]
		foreach {pName pVal} [array get ::paramData] {
		    if {$pName ne "needed" && $pVal eq "" && \
			    [GetCCompProperty DUMMY Class [TrimDTFromPath $pName]] ne "SUBMODEL"} {
			#return 0
		    }
		}
		return $gotAll
	    } else {
		return -1
	    }
	} GetParamVals {
	    # get strings from GUI side as we have no functions to get from c++
	    #set prmStrs [array get ::paramData]
	    # purge any that are refs or binary
	    set prmStrs {}
	    foreach {paramPath paramSpec} [ReportParams] {
		if {[lsearch {scenario} [lindex $paramSpec 0]]==-1} {
		    lappend prmStrs $paramPath $paramSpec
		}
	    }
	    set result [JsonifyDict $prmStrs]
	} Reset {
	    set iH $service($params(base))
	    set i 0
	    foreach dt [split $params(step) " "] {
		c_setstepmodel $iH $dt [incr i]
	    }
	    set ::instance_id $iH
	    ResetModel DUMMY 1 $params(current) $params(depth)
	    set reqs [::json::json2dict $params(note)]
	    set result [JsonifyArray [ValuesOfInterest $iH $reqs]]
	} Query {
	    set reqs [::json::json2dict $params(note)]
	    set result [JsonifyArray [ValuesOfInterest $service($params(base)) $reqs]]
	} ExecuteMulti {
	    set iH $service($params(base))
	    set i 0
	    foreach dt [split $params(step) " "] {
		c_setstepmodel $iH $dt [incr i]
	    }
	    set reqs [::json::json2dict $params(note)]
	    set endPt [expr {$params(current)+$params(runlength)}]

	    set ::instance_id $iH
	    set hlpArr {}
	    for {set t $params(current)} {$t<$endPt} {set t $endInt} {
		set endInt [expr {$t+$params(log)}]
		if {$endInt>$endPt} {set endInt $endPt}
		set stat [ExecuteModel DUMMY $params(method) $t $endInt \
			      $params(errLimit) 0 0]
		set resp [ValuesOfInterest $iH $reqs]

		lappend resp [lindex $stat 1] ;# actual finish time
		lappend hlpArr [JsonifyArray $resp]
		if {[lindex $stat 0]==0} break;
	    }
	    lappend hlpArr [lindex $stat 0]
	    set result [JsonifyArray $hlpArr]
	} Exit {
	    c_exitmodel $::model_id $service($params(base))
	    unset ::model_id
	    return {}
	} default {
	    error "Unhandled request $paramList"
	}
    }
    # puts "Responded: $result"
    return $result
}

proc Respond {to what mt} {

    set resp "HTTP/1.1 200 OK
Date: [clock format [clock seconds]]
Server: simile
Access-Control-Allow-Origin: *
Content-Length: [string length $what]
Keep-Alive: timeout=5, max=100
Connection: Keep-Alive
Content-Type: $mt; charset=UTF-8

$what"
# convert string to crlfs first or length comes out wrong
#    fconfigure $to -translation crlf
    if {[catch {puts -nonewline $to $resp} sktErr]} {
	puts "Channel failure $sktErr"
	puts "Socket status [chan configure $::web_service(curent) -error]"
    }
#    fconfigure $to -translation binary
}
	
proc relay {from to in} {
    global web_service
    
    if {[eof $from]} {
	close $from
	close $to
    } else {
	set blk [read $from]
	if {$in} {
	} else {
	    if {[string first "GET /" $blk]==0} {
		set lineEnd [string first " HTTP/1." $blk 5]
		set soughtLocn [file join $web_service(inst) Extensions www [string range $blk 5 $lineEnd-1]]
		if {[file exists $soughtLocn]} {
		    # serve local version if present -- only load_tools.html
		    # needs to be local
		    set stm [open $soughtLocn r]
		    set response [read $stm]
		    set mimeTrans {.html text/html .js text/javascript \
				       .gif image/gif .jpg image/jpeg \
				       .png image/png}
		    set mt [lindex $mimeTrans [lsearch $mimeTrans [file extension $soughtLocn]]+1]
		    Respond $from $response $mt
		    close $stm
		    return
		}
		set self $web_service(host):$web_service(port)
		set blk [string map [list "Host: $self" "Host: $web_service(tgt)"] $blk]
		set blk [string replace $blk 4 4 $web_service(path)/]
	    }
	    if {[string first "POST /model_action.php HTTP/1." $blk]==0} {
		set paramLine [string range $blk [string last \n $blk end]+1 end]
		while {[string length $paramLine]<8} {
		    # should really get required length from headers
		    append paramLine [read $from]
		}
		set paramList {}
		foreach paramVal [split [urlDecode $paramLine] &] {
		     eval lappend paramList [split $paramVal =]
		}
		set result [ResponseTo $paramList]
		Respond $from [encoding convertto utf-8 \
				   [string map {\n \r\n} $result]] text/html
		return ;# do not bother the server
	    } 
	}
	puts -nonewline $to $blk
    }
}

proc accept {clientsock clienthost clientport} {
    set serversock [socket $::web_service(tgt) 80]

    fconfigure $clientsock -blocking 0 -buffering none -translation binary
    fconfigure $serversock -blocking 0 -buffering none -translation binary
    fileevent $clientsock readable [list relay $clientsock $serversock 0]
    fileevent $serversock readable [list relay $serversock $clientsock 1]
}

proc start_server {host port tgt path inst runParams} {
    array set ::web_service [list host $host port $port tgt $tgt \
				 path $path inst $inst parms $runParams]
    set ::web_service(curent) [socket -server accept -myaddr $host $port]
}
