# This contains generic procedures used by various other IO tools that
# draw coloured maps, e.g., the polygon and grid tools.

# It will not be picked up as a menu item when the tools ar loadede because
# it does not contain a set keyValue instruction.

# Only the useful procedures are exported so a tool that uses them can import
# everything from this namespace.

# by Jasper Taylor, March 2001


namespace eval ::maptools2 {
    
    proc SetColours {winData winId} {
        #    ShowMessage debug info "proc SetColours" ok
        upvar 1 $winData useNodes
        
        scan [winfo rgb $winId $useNodes($winId,cbot)] "%d %d %d" botr botg botb
        scan [winfo rgb $winId $useNodes($winId,cmid)] "%d %d %d" midr midg midb
        scan [winfo rgb $winId $useNodes($winId,ctop)] "%d %d %d" topr topg topb
        
        set max $useNodes($winId,nswatches); #[expr int($useNodes($winId,max))]
        set min 0; #[expr int($useNodes($winId,min))]
        set med [expr int(($useNodes($winId,nswatches))/2.0)]
        #    ShowMessage debug info "$min $max $med" ok
        # make the colour descriptions, this should improve speed
        for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
            if {$icolour<$med} {
                set red [expr ($icolour*$midr+($med-$icolour)*$botr)/$med]
                set green [expr ($icolour*$midg+($med-$icolour)*$botg)/$med]
                set blue [expr ($icolour*$midb+($med-$icolour)*$botb)/$med]
            } elseif {$icolour<=$max} {
                set red [expr (($icolour-$med)*$topr+($max-$icolour)*$midr)/$med]
                set green [expr (($icolour-$med)*$topg+($max-$icolour)*$midg)/$med]
                set blue [expr (($icolour-$med)*$topb+($max-$icolour)*$midb)/$med]
            }
            set useNodes($winId,c$icolour) [format #%04x%04x%04x $red $green $blue]
        }
    }
    
    proc InsertLegend {winData winId} {
        #    ShowMessage debug info "proc InsertLegend" ok
        upvar 1 $winData useNodes
        set max [expr int($useNodes($winId,max))]
        set min [expr int($useNodes($winId,min))]
        #ShowMessage debug info "min $min; max $max" ok
        frame $winId.legend
        pack $winId.legend -side right -fill y -pady 2m
        if $useNodes($winId,integer) {
            set tickinterval 1
            set resolution 1
        } else  {
            set tickinterval [expr 1.0*$useNodes($winId,range)/$useNodes($winId,nswatches)]
            set resolution [expr $tickinterval/10.0]
        }
        #-tickinterval [expr $useNodes($winId,range)/10.0] TODO
        #-resolution [expr $useNodes($winId,range)/100.0] TODO
        #ShowMessage debug info "min $min; max $max; $tickinterval; $resolution" ok
        scale $winId.legend.scale -from $max \
                -to $min -showvalue false -sliderlength 2 \
                -width 5 -tickinterval $tickinterval \
                -borderwidth 1 -resolution $resolution
        pack $winId.legend.scale -side left -fill y -expand true
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            pack [frame $winId.legend.pop$swatch -width 10] -fill y -expand true \
                    -side bottom
        }
    }
    
    proc ColourScale {winData winId} {
        #    ShowMessage debug info "proc ColourScale" ok
        upvar 1 $winData useNodes
        set max [expr int($useNodes($winId,max))]
        set min [expr int($useNodes($winId,min))]
        $winId.legend.scale config -from $max \
                -to $min
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            $winId.legend.pop$swatch configure -bg $useNodes($winId,c$swatch)
        }
    }
    
    proc GetQuadList {inds args} {
        # requires an empty list, quadlist, at the calling stack level
        upvar 1 quadlist quadlist
        
        set pilot [lindex $args 0]
        if {![llength $pilot]} {
            set args [lreplace $args 0 0 nil]
        } elseif {[llength $pilot]==2 && ![llength [lindex $pilot 0]]} {
            set args [lreplace $args 0 0 [lindex $pilot 1]]
        }
        if {[llength [lindex $args 0]] == 1} {
            lappend quadlist $inds $args
        } else {
            set arrcount 0
            foreach arg $args {
                array set new$arrcount $arg
                incr arrcount
            }
            
            foreach elt [array names new0] {
                set arrcount 0
                set newargs {}
                foreach arg $args {
                    upvar 0 new$arrcount newarr
                    lappend newargs [set new${arrcount}($elt)]; # $newarr($elt); ####
                    incr arrcount
                }
                eval GetQuadList [list [concat $inds $elt]] $newargs
            }
        }
    }
    
    proc Flatten {nested flat} {
        for {set i 1} {$i < [llength $nested]} {incr i 2} {
            set subi [lindex $nested $i]
            if {[string match {} $subi]} {
                lappend flat {}
            } elseif {[llength $subi] == 1} {
                lappend flat $subi
            } else {
                set flat [Flatten $subi $flat]
            }
        }
        return $flat
    }
    
    proc IsNumber {str} {
        return [expr {[string is integer $str] || [string is double $str]}]
    }
    
    namespace export SetColours InsertLegend ColourScale GetQuadList Flatten \
            IsNumber
}

