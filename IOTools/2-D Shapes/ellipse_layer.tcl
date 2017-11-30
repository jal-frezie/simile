# 2-d shapes layer helper -- basically will use the 3-d engine with
# 0 for the z coords

set newLayerClass Ellipses20171122
itcl::class similescript::$newLayerClass {
    inherit Layer
    variable useNodes

    proc Identify {} {
	return "Ellipse Plotter"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	::similescript::Shapes3D20141208 ${this}_3dinst $modelInst \
	    [list layer ellipses $winId $xzoom $yzoom] $state
    }

    destructor {
	itcl::delete object ${this}_3dinst
	$winId delete [namespace tail $this].main
    }

    public method GetTitle {} {
	return "Ellipses"
    }

    public method Display {time dispInt step} {
	${this}_3dinst Display $time $dispInt $step
    }

    public method ZoomTo {x y} {
	set subWin [winfo parent $winId]
	array set ::gen3d1::scaleVector [list $subWin,xoff [expr {250.0/$x}] \
					     $subWin,yoff [expr {-250.0/$y}] \
					     $subWin,xmag [expr {500.0/$x}] \
					     $subWin,ymag [expr {500.0/$y}]]
    }

    public method PrepareSaveString {} {
	set State [${this}_3dinst cget -State]
    }
}
