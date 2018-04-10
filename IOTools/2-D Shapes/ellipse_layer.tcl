# 2-d shapes layer helper -- basically will use the 3-d engine with
# 0 for the z coords

set newLayerClass Ellipses20171122
itcl::class similescript::$newLayerClass {
    inherit ShapeLayer

    proc Identify {} {
	return "Ellipse Plotter"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	ShapeLayer::constructor $modelInst $mainCanvas ellipses \
	    $xzoom $yzoom $state
	    
    } { }

    public method GetTitle {} {
	return [GetSortTitle Ellipses]
    }
}
