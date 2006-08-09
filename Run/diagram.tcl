# 6/8/2006: There is now an I/O tool that displays the model
# diagram. Therefore we want some procedures that manipulate the
# diagram (e.g., generate popups, send node ids to other helpers) to
# be available in both the editor and execution contexts. They go
# here.

# GetClickedObj: returns the object at the target position. We want to return
# the closest object within a certain number of pixels. Since there is always
# something in the background we will get that if our search radius is too
# small, so we gradually increase it until we find a non-background thing or
# we reach the edge of our search radius.

proc GetCaptionItem {w name} {
    if {[winfo exists $w]} {
	foreach object [$w find withtag $name] {
	    if {[string compare [$w type $object] text] == 0} {
		set taglist [$w gettags $object]
		if {[string match *is_caption* $taglist]} {
		    return $object
		}
	    }
        }
    }
}

proc GetText { w name } {
    set nameItem [GetCaptionItem $w $name]
    if {[string compare $nameItem {}]} {
        return [$w itemcget $nameItem -text]
    } else {
        return /no_caption/
    }
}

proc GetPathSect { w name } {
    set nameItem [GetCaptionItem $w $name]
    if {[string compare $nameItem {}]} {
        set txt [$w itemcget $nameItem -text]
# If it's a module occurrence we want the text of the component whose value is
# to be displayed
	if {[regexp {valuepath\(([^\)]+)\)} [$w gettags $nameItem] \
		 tag pathExtra]} {
	    append txt $pathExtra
	}
	return $txt
    } else {
        return /no_caption/
    }
}

proc GetClickedObj { winId canx cany range} {
    for {set halo 1} {$halo < $range} {incr halo 2} {
        set target [$winId find closest $canx $cany $halo]
        if {![string match "*/background/*" [$winId gettags $target]]} {
            return $target
        }
    }
    return 0
}

proc ExtractPrologName { winId target } {
    set tagList [$winId gettags $target]
    set objNamePosn [lsearch -regexp $tagList {((node)|(arc)[0-9]*)|(sample)}]
    return [lindex $tagList $objNamePosn]
}

proc GetClickCapt { winId canx cany node} {
    global window_info
    set result $window_info($winId,topCapt)
    set tgts [$winId find overlapping $canx $cany $canx $cany]
    set lastNod none
    foreach tgt $tgts {
    if {[string match "*/background/*" [$winId gettags $tgt]] && \
        ![string match "*/base/*" [$winId gettags $tgt]]} {
        set thisNod [ExtractPrologName $winId $tgt]
        if {![string equal $thisNod $lastNod]} {
        set lastNod $thisNod
        set newText [GetPathSect $winId $thisNod]
        append result /$newText
        if {[string equal $node $thisNod]} {
            return $result
        }
        }
    }
    }
    append result /[GetPathSect $winId $node]
    return $result
}    

