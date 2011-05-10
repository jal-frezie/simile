proc tr. {english} {
    global means

    if {![info exists means($english)]} {
	set means($english) [DoTr $english]
    }
    return $means($english)
}

# These are used for making lists of strings requiring translation
proc LoadTrans {} {
#    set stm [open $::SIMILE_PATH/means.txt r]
#    array set ::means [read $stm]
#    close $stm
    global parseStatus

    package require xml
    set transRsrc $::SIMILE_PATH/Help/langspec.trn
    if {![file exists $transRsrc]} return
    set parseStatus(trnParser) [::xml::parser -ignorewhitespace true \
				-elementstartcommand StartTrnElt \
				-elementendcommand FinishTrnElt \
				-characterdatacommand DoTrnElt]
    $parseStatus(trnParser) reset
    set pStr [open $transRsrc r]
    set dada [read $pStr]
    close $pStr

    set parseStatus(trnStatus) idle
    $parseStatus(trnParser) parse $dada
}

proc StartTrnElt {name attList args} {
    global parseStatus

    switch $name {
	phrase {
	    array unset parseStatus trnContent
	} english {
	    set parseStatus(trnStatus) expecting_english
	} target {
	    set parseStatus(trnStatus) expecting_target
	}
    }
}

proc DoTrnElt {rawContent} {
    global parseStatus means

    # simile strings use 3 periods for ellipsis so substitute Unicode repn
    set content [string map {\u2026 ...} $rawContent]
    if {[info exists parseStatus(trnContent)]} {	
	switch $parseStatus(trnStatus) {
	    expecting_english {
		set means($content) $parseStatus(trnContent)
	    } expecting_target {
		set means($parseStatus(trnContent)) $content
	    }
	}
    } else {
	set parseStatus(trnContent) $content
    }
}

proc FinishTrnElt {name args} {
    global parseStatus

    set parseStatus(trnStatus) idle
}

proc SaveTrans {} {
#    set stm [open $::SIMILE_PATH/means.txt w]
#    puts -nonewline $stm [array get ::means]
#    close $stm
}

proc DoTr {english} {
    if {[string length $english]==0} return {}

    set latin [string range $english 0 0]
    if {[string equal % $latin]} { ;# format substr %n$x -- keep
	set result [string range $english 0 3]
	set tail [string range $english 4 end]
    } else {
	if {[string is alpha $latin]} {
	    set ruski [lsearch {a v b g d y j z i {} k l m n o p r s t u f h q c {} x {} {} {} e w {}} [string tolower $latin]]
	    if {[string is upper $latin]} {
		set result [format %c [expr 0x410+$ruski]]
	    } else {
		set result [format %c [expr 0x430+$ruski]]
	    }
	    set result [format %c [expr {int(0xac00+rand()*(0xd7a3-0xac00))}]]
	} else {
	    set result $latin
	}
	set tail [string range $english 1 end]
    }
    return ${result}[DoTr $tail]
    # 	puts "Translated $english to $means($english)"
}

# Hangul is 0xd7a3-0xac00

# In use: just return the original English
proc DoTr {english} {
    return $english
}

proc ExpandMessage {key} {
    return $::msgs($key)
}