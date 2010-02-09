# This version translates any string into random Russian characters,
# keeping the same one for each translation
proc tr. {english} {
    global means

    if {![info exists means($english)]} {
	set means($english) [DoTr $english]
    }
    return $means($english)
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
#	    set result [format %c [expr {int(0xac00+rand()*(0xd7a3-0xac00))}]]
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
# proc tr. {english} {
#     return $english
# }