global have_spare
set have_spare 0
proc gaussian {random mean sd} {
    global spare have_spare
    if {$have_spare} {
	set norm $spare
    } else {
	set r 1
	while {$r>=1} {
	    set v1 [ame_rand -1 1]
	    set v2 [ame_rand -1 1]
	    set r [expr $v1*$v1 + $v2*$v2]
	}
	set fac [expr sqrt(-2*log($r)/$r)]
	set spare [expr $v1*$fac]
	set norm [expr $v2*$fac]
    }
    set have_spare [expr !$have_spare]
    return [expr $mean+$sd*$norm]
}
