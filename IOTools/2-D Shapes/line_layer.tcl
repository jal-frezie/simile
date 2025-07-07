# 2-d shapes layer helper -- basically will use the 3-d engine with
# 0 for the z coords

set newLayerClass Lines20171122
oo::class create iotool::$newLayerClass {
    superclass iotool::ShapeLayer

    # need to insert type as extra arg to constructor
    constructor {modelInst mainCanvas args} {
	eval [list next $modelInst $mainCanvas lines] $args
    }
    
    self {
	method identify {} {
	    return "Line Plotter"
	}
    }

    method getTitle {} {
	return [my GetSortTitle Lines]
    }
}
