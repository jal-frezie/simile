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

proc JsonifyAny {ugly} {
    if {[llength $ugly]==1} {
	set val $ugly
	if {![string is double -strict $val] && \
		[string first [string index $val 0] \[\{\"]==-1} {
	    set val \"$val\"
	}
	return $val
    } else {
	set result {}
	set safety {\n \\n}
	foreach {indx val} [string map $safety $ugly] {
	    if {[string length $result]} {
		append result {, }
	    }
	    append result \"$indx\":\ [JsonifyAny $val]
	}
	return \{$result\}
    }
}

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
	set stac [extract_gif_tail $hdl $bits(bottom) $bits(top)]
	append stac [binary format cc 0 0x3b]
	set resp [base64 -mode encode -- $stac]
    } else {
	set hdl [handle_data dummyMHandle $iH $itm]
	#	set resp [thread::send $::masterId [list extract_json $hdl $max]]
	set resp [JsonifyAny [extract_list $hdl $max]]
	
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
    return [string map {\" \\\" \t \\t} $rough]
}

proc ResponseTo {paramList} {
    global service
    array set params $paramList
   
    switch $params(act) {
	BuildShareLib {
	    package require json
	    package require can2svg
	    package require base64

	    set mH $::model_id
	    set iH [c_createmodel $mH]
	    set service($params(base)) $iH
	    # Now create data structs for scalar parameters
	    foreach obj [listobjects $mH] {
		if {[lsearch {INPUT} [GetCCompProperty Eval $obj]]>-1 && [llength [GetCCompProperty Dims $obj]]==1} { ;# [0]
		    set ::aH($obj) [c_createparamarray $iH $obj]
		}
	    }

	    array set rps [list intMethod Euler execTime 100.0 phaseList 0.1 displayInt 1 resetTo 0 timeUnit unit errLimit 0]
	    array set rps $::web_service(parms) ;# override defaults
	    set result [JsonifyDict [array get rps]]
	} CreateSocket {
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
	    foreach {tclCmd} [json::json2dict [urlDecode $params(cnvdraw)]] {
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
			[JsonifyArray [GetCCompProperty Dims $id]]
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
	    array set incoming [::json::json2dict [urlDecode $params(data)]]
	    set parmReqOrdinality $incoming(seqNo)
	    array unset incoming seqNo
	    foreach {path stack} [array get incoming] {
		set id [getnodeid $::model_id $path]
		set trans [GetCCompProperty Trans $id]
		set times [string equal INPUT [GetCCompProperty Eval $id]]
		set dims {} ;# only ones we have created space for so far!
		if {$times} {
		    if {[info exists parmTimeStamps($id)] && \
			    $parmTimeStamps($id)>=$parmReqOrdinality} {
			continue
		    }
		    set parmTimeStamps($id) $parmReqOrdinality
		    set dims [linsert $dims 0 TIME]
		}
		set ::param_id(cur) $::aH($id)
		set resp [ListToArray DUMMY {} cur {} {} $trans $dims $stack \
				$times 1]
		if {[lsearch {-1 0 1} $resp]==-1} {
		    puts $path-->$resp
		}
	    }
	} LoadSPF {
	    set result [ParamsFromGUI $service($params(base))]
	} Reset {
	    set iH $service($params(base))
	    set i 0
	    foreach dt [split $params(step) +] {
		c_setstepmodel $iH $dt [incr i]
	    }
	    set isRK [expr {$params(method) ne "Euler"}]
	    CResetModel $params(current) $isRK $params(depth)
	    set reqs [::json::json2dict [urlDecode $params(note)]]
	    set result [JsonifyArray [ValuesOfInterest $iH $reqs]]
	} Query {
	    set reqs [::json::json2dict [urlDecode $params(note)]]
	    set result [JsonifyArray [ValuesOfInterest $service($params(base)) $reqs]]
	} ExecuteMulti {
	    set iH $service($params(base))
	    set i 0
	    foreach dt [split $params(step) +] {
		c_setstepmodel $iH $dt [incr i]
	    }
	    set reqs [::json::json2dict [urlDecode $params(note)]]
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
    return $result
}

proc Respond {to what} {

    set resp "HTTP/1.1 200 OK
Date: [clock format [clock seconds]]
Server: simile
Access-Control-Allow-Origin: *
Content-Length: [string length $what]
Keep-Alive: timeout=5, max=100
Connection: Keep-Alive
Content-Type: text/html; charset=UTF-8

$what"
# convert string to crlfs first or length comes out wrong
#    fconfigure $to -translation crlf
    puts -nonewline $to $resp
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
	    if {[string first "POST /create_model.php HTTP/1.1" $blk]==0} {
		set blk [string replace $blk 5 5 $web_service(path)/]
	    }
	    set self $web_service(host):$web_service(port)
	    set blk [string map [list "Host: $self" "Host: $web_service(tgt)"] $blk]
	    if {[string first "GET /" $blk]==0} {
		set blk [string replace $blk 4 4 $web_service(path)/]
	    }
	    if {[string first "POST /model_action.php HTTP/1.1" $blk]==0} {
		set paramLine [string range $blk [string last \n $blk end]+1 end]
		while {[string length $paramLine]<8} {
		    # should really get required length from headers
		    append paramLine [read $from]
		}
		set paramList {}
		foreach paramVal [split $paramLine &] {
		     eval lappend paramList [split $paramVal =]
		}
		set result [ResponseTo $paramList]
		Respond $from [encoding convertto utf-8 \
				   [string map {\n \r\n} $result]]
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

proc start_server {host port tgt path runParams} {
    array set ::web_service [list host $host port $port tgt $tgt \
				 path $path parms $runParams]
    socket -server accept -myaddr $host $port
}
