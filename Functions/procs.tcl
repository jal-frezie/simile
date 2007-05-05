# see procs.cpp for c++ equivalents and documemtation

global have_spare
set have_spare 0
proc gaussian {mean sd} {
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

proc gammln {xx} {
    set stp 2.50662827465

    set x [expr {$xx-1}]
    set tmp [expr {$x+5.5}]
    set tmp [expr {($x+0.5)*log($tmp)-$tmp}]
    set ser [expr {1+76.18009173/($x+1)-86.50532033/($x+2)+24.01409822/($x+3) \
	       -1.231739516/($x+4)+1.20858003e-3/($x+5)-5.36382e-6/($x+6)}]
    return [expr {$tmp+log($stp+$ser)}]
}

proc poidev {xm} {
# Returns an integer value that is a random deviate drawn from a Poisson 
# distribution of mean xm, using random01 to get a random value between 0 and 1
# Thanks to "Numerical Recipes", CUP
    set pi 3.14159265359
    if {$xm < 12} {
	set PoidevG [expr exp(-$xm)]
	set em -1
	set t 1.0
	while {$t>=$PoidevG} {
	    incr em
	    set t [expr {$t*[random01]}]
	}
    } else {
	set PoidevSq [expr {sqrt(2*$xm)}]
	set PoidevAlxm [expr {log($xm)}]
	set PoidevG [expr {$xm*$PoidevAlxm-[gammln [expr {$xm+1}]]}]

	set t 0
	while {[random01]>$t} {
# change to NR: orig had arg of tan going from 0 to pi and retried if em<=0
	    set em -1;
	    while {$em<0} {
		set y [expr {tan([random01]*$pi)}]
		set em [expr {int($PoidevSq*$y+$xm)}]
	    }
	    set t [expr {0.9*(1+$y*$y)*exp($em*$PoidevAlxm \
					       -[gammln [expr {$em+1}]] \
					       -$PoidevG)}]
	}
    }
    return $em
}
## see procs.cpp
# proc bnldev {pp n} {
#     set pi 3.14159265359
#     if {$pp<0.5} {
# 	set p $pp
# 	set pc [expr {1-$pp}]
#     } else {
# 	set pc $pp
# 	set p [expr {1-$pp}]
#     }
#     set am [expr {$n*$p}]
#     if {$n<25} {
# 	set bnl 0
# 	for {set j 0} {$j<$n} {incr j} {
# 	    incr bnl [expr {[random01]<$p}]
# 	}
#     } elseif {$am<1} {
# 	set bnl [poidev $am]
#     } else {
# 	set Oldg [gammln [expr {$n+1}]]
# 	set Plog [expr {log($p)}]
# 	set Pclog [expr {log($pc)}]
# 	set Sq [expr {sqrt(2*$am*$pc)}]
# 	
# 	set t 0
# 	while {[random01]>$t} {
# 	    set em -1
# 	    while {$em<0 || $em>$n} {
# 		set y [expr {tan([random01]*$pi)}]
# 		set em [expr {int($Sq*$y+$am)}]
# 	    }
# 	    set emc [expr {$n-$em}]
# 	    set t [expr {1.2*$Sq*(1+$y*$y)*exp($Oldg-[gammln [expr {$em+1}]] \
# 						  -[gammln [expr {$emc+1}]] \
# 						  +$em*$Plog+$emc*$Pclog)}]
# 	}
# 	set bnl $em
#     }
#     if {$pp<0.5} {
# 	return $bnl
#     } else {
# 	return [expr {$n-$bnl}]
#     }
#     return $bnl
# }
# 		
proc wrapped {lo hi here} {
    return [expr {($hi<$lo)==($hi<$here)==($lo<$here)}]
}

proc simile_mod {point span} {
    return [expr $point-$span*floor($point/$span)]
}

# translated from procs.cpp -- see Free Software etc

proc GammaDeviate_direct {order} {
    set x [random01]
    while {[incr order -1]} {set x [expr {$x*[random01]}]}
    return [expr {-log($x)}]
}

proc GammaDeviate_rejection {order} {
    set pi 3.14159265359

    set s [expr {sqrt(2*$order-1)}]
    set doingOuter 1
    while {$doingOuter} {
	set doingInner 1
	while {$doingInner} {
	    set y [expr {tan($pi*[random01])}]
	    set x [expr {$s*$y+$order-1}]
	    set doingInner [expr {$x<=0}]
	}
# tcl gets upset with small numbers, so
	set wee [expr {($order-1)*log($x/($order-1))-$s*$y}]
	if {$wee<-500} {
	    set expwee 0
	} else {
	    set expwee [expr {exp($wee)}]
	}
	set doingOuter [expr {[random01]>(1+$y*$y)*$expwee}]
    }
    return $x
}

proc binome {p n} {
    if {$p<0 || $p>1} {error "p is $p"}
    if {$n<0} {error "n is $n"}
    set k 0
    while {$n>20} {
	set a [expr {1+$n/2}]
	set b [expr {1+$n-$a}]

	if {$a<12} {
	    set x1 [GammaDeviate_direct $a]
	} else {
	    set x1 [GammaDeviate_rejection $a]
	}
	if {$b<12} {
	    set x2 [GammaDeviate_direct $b]
	} else {
	    set x2 [GammaDeviate_rejection $b]
	}
	set x [expr {$x1/($x1+$x2)}]

	if {$x>=$p} {
	    set n [expr {$a-1}]
	    set p [expr {$p/$x}]
	} else {
	    set k [expr {$k+$a}]
	    set n [expr {$b-1}]
	    set p [expr {($p-$x)/(1-$x)}]
	}
    }

    for {set i 0} {$i<$n} {incr i} {
	set x [random01]
	if {$x<$p} {incr k}
    }
    return $k
}

proc safe_fract {upper lower} {
    if {$lower==0} {return 0}
    return [expr 1.0*$upper/$lower]
}

proc trinome {pop marked sample} {
    if {$sample<20} {
	set fished 0
	while {$sample>0} {
	    if {[random01]<1.0*$marked/$pop} {
		incr marked -1
		incr fished
	    }
	    incr pop -1
	    incr sample -1
	}
    } else {
	set fished [binome [expr 1.0*$marked/$pop] $sample]
    }
    return $fished
}

proc hypergeom {pop seln1 seln2} {
    set flip1 [expr $seln1>$pop]
    set flip2 [expr $seln2>$pop]
    if {$flip1} {set seln1 [expr $pop-$seln1]}
    if {$flip2} {set seln2 [expr $pop-$seln2]}
    
    set out [trinome $pop [max $seln1 $seln2] [min $seln1 $seln2]]

    if {$flip2} {set out [expr $seln1-$out]; set seln2 [expr $pop-$seln2]}
    if {$flip1} {set out [expr $seln2-$out]}
    return $out
}

	