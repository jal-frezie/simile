# This contains generic procedures used by various other IO tools that
# draw coloured maps, e.g., the polygon and grid tools.

# It will not be picked up as a menu item when the tools ar loadede because
# it does not contain a set keyValue instruction.

# Only the useful procedures are exported so a tool that uses them can import
# everything from this namespace.

# by Jasper Taylor, March 2001

namespace eval maptools {

proc SetColours {winData winId} {
    upvar 1 $winData useNodes

    scan [winfo rgb $winId $useNodes($winId,cbot)] "%d %d %d" botr botg botb
    scan [winfo rgb $winId $useNodes($winId,cmid)] "%d %d %d" midr midg midb
    scan [winfo rgb $winId $useNodes($winId,ctop)] "%d %d %d" topr topg topb
# make the colour descriptions, this should improve speed
    for {set icolour 0} {$icolour <= 32} {incr icolour} {
      if {$icolour<16} {
         set red [expr ($icolour*$midr+(16-$icolour)*$botr)/16]
         set green [expr ($icolour*$midg+(16-$icolour)*$botg)/16]
         set blue [expr ($icolour*$midb+(16-$icolour)*$botb)/16]
      } elseif {$icolour<=32} {
         set red [expr (($icolour-16)*$topr+(32-$icolour)*$midr)/16]
         set green [expr (($icolour-16)*$topg+(32-$icolour)*$midg)/16]
         set blue [expr (($icolour-16)*$topb+(32-$icolour)*$midb)/16]
      }
      set useNodes($winId,c$icolour) [format #%04x%04x%04x $red $green $blue]
  }
}

proc InsertLegend {winData winId} {
    upvar 1 $winData useNodes
    frame $winId.legend
    pack $winId.legend -side right -fill y -pady 2m
    scale $winId.legend.scale -from $useNodes($winId,max) \
	    -to $useNodes($winId,min) -showvalue false -sliderlength 2 \
	    -width 5 -tickinterval [expr $useNodes($winId,range)/10.0] \
	    -borderwidth 1 -resolution [expr $useNodes($winId,range)/100.0]
    pack $winId.legend.scale -side left -fill y -expand true
    for {set swatch 0} {$swatch<=32} {incr swatch} {
	pack [frame $winId.legend.pop$swatch -width 10] -fill y -expand true \
		-side bottom
    }
}

proc ColourScale {winData winId} {
    variable useNodes
    upvar 1 $winData useNodes
    for {set swatch 0} {$swatch<=32} {incr swatch} {
	$winId.legend.pop$swatch configure -bg $useNodes($winId,c$swatch)
    }
}

namespace export SetColours InsertLegend ColourScale
}

