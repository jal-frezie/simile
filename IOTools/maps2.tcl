# This contains generic procedures used by various other IO tools that
# draw coloured maps, e.g., the polygon and grid tools.

# It will not be picked up as a menu item when the tools ar loadede because
# it does not contain a set keyValue instruction.

# Only the useful procedures are exported so a tool that uses them can import
# everything from this namespace.

# by Jasper Taylor, March 2001

#$Log: maps2.tcl,v $
#Revision 1.2  2002/10/18 14:24:47  jmm
#proc GetCanvas added returns canvas for printing etc.
#absolute namespaces used, i.e. start with ::
#
#Revision 1.1  2002/07/18 14:12:14  jmm
#Required for polygon.tcl. All helpers using maps.tcl should eb updated to use maps2.tcl
#
#Revision 1.0  2002-05-12 22:19:26+01  jmm
#Initial revision
#
#Revision 1.3  2002-04-29 17:26:49+01  jmm
#Added RCS Log directive
#

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
    for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
	    $winId.legend.pop$swatch configure -bg $useNodes($winId,c$swatch)
    }
}

namespace export SetColours InsertLegend ColourScale
}

