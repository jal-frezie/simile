# This version translates any string into random Russian characters,
# keeping the same one for each translation
proc tr. {english} {
    global means
    
    if {![info exists means($english)]} {
	foreach latin [split $english {}] {
	    if {[string is upper $latin]} {
		append means($english) \
		    [format %c [expr int(0x410+rand()*(0x42f-0x410))]]
	    } elseif {[string is lower $latin]} {
		append means($english) \
		    [format %c [expr int(0x430+rand()*(0x44f-0x430))]]
	    } else {
		append means($english) $latin
	    }
	}
	puts "Translated $english to $means($english)"
    }
    return $means($english)
}
# Hangul is 0xd7a3-0xac00

# In use: just return the original English
proc tr. {english} {
    return $english
}