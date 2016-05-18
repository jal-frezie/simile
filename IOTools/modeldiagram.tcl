# ModelInspector.tcl

# Based on SaveState.tcl
# Added Treeview of sub-models and table view of variables  Jonathan Massheder 22/4/01

# SaveState.tcl Jasper Taylor, 28/5/99
# AME Helper app to record or retrieve the state of a model. This is
# to be used both as a general modelling tool, and in conjunction with
# the GCLMI interface or other interface requiring creation and
# initialization of multiple instances of the model.

set keyValue ModelDiagram20060804

namespace eval ::ModelDiagram20060804 {
    
    proc identify {} {
        return "Model diagram"
    }
    
    proc display {args} {
    }
    
    proc clear {winId} {
    }
    
    proc reset {winId} {
    }

    proc initialize {winId} {
	global window_info
	
	pack [frame $winId.bar] -fill x
	pack [message $winId.bar.msg -aspect 1000 -text "Click on submodel or component, or"] -side left
	pack [button $winId.bar.btn -text "top level" \
		  -command [namespace code "click $winId top Desktop"]] \
	    -side left
	AddToolbar $winId
	AddDiagram $winId {}
	GrabClicks $winId
    }
    
    proc AddToolbar {winId} {
        set toolbarItems \
	    [list \
		 [list zoomin.gif "Zoom in" [namespace code "Zoom $winId 1.25"]] \
		 [list zoomout.gif "Zoom out" [namespace code "Zoom $winId 0.8"]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
    }

    proc Zoom {winId factor} {
	global window_info

	set window_info($winId.c,width) [winfo width $winId.c]
	set window_info($winId.c,height) [winfo height $winId.c]
	set window_info($winId.c,top_node) \
	    [$::helperTable($winId,whichInstance) GetNode]
	DoZoom $winId.c $factor
	array unset window_info $winId.c,top_node
    }
    
    proc click {winId node caption} {
	global window_info

	set topNode [$::helperTable($winId,whichInstance) GetNode]
	if {$node eq "top"} {
	    set node $topNode
	    SetState $winId "top level"
	} else {
	    SetState $winId [GetCaptionPathFromId $node]
	}
	set window_info($winId.c,top_node) $topNode
	set window_info($winId.c,scale) 1.0
	set window_info($winId.c,width) [winfo width $winId.c]
	set window_info($winId.c,height) [winfo height $winId.c]
	set ::custom(showgrids,$winId.c) 0
	prolog state'><'set_display_depth('$winId.c',_,32)
	set bg [$winId.c create rectangle 0 0 1 1 -outline {} -fill beige \
		    -tags "/base/ /background"]
	prolog tcl_export_graphics('$winId.c',$node)
	$winId.c configure -scrollregion $::fromProlog
	$winId.c coords $bg $::fromProlog
	array unset window_info $winId.c,top_node

	ReleaseClicks $winId
	pack forget $winId.bar
    }
    
    proc old_initialize {winId} {
        set diagFile [ChooseFile model.cnv [tr. "Display model diagram file:"] \
			  0 [$::helperTable($winId,whichInstance) GetNode]]
	if {[string length $diagFile]} {
	    set quikStr [NetOpen $diagFile r]
	    SetState $winId [read $quikStr] ;# transcribe file into contents
	    close $quikStr
	    AddDiagram $winId [GetState $winId]
	}
    }

    proc AddDiagram {winId diagFile} {
	global window_info

	set c [canvas $winId.c -bg white -confine 1 \
		   -xscrollcommand "$winId.xscroll set" \
		   -yscrollcommand "$winId.yscroll set"]
	pack [scrollbar $winId.xscroll -orient horizontal \
		  -command "$c xview"] -side bottom -fill x
	pack [scrollbar $winId.yscroll -orient vertical \
		  -command "$c yview"] -side right -fill y
	pack $c -fill both -expand 1
	
	set window_info($c,topCapt) {} ;# must be top-level diagram!
	eval $diagFile

	bind $c <Button-1> [list [namespace code OnElementClick] %W %x %y]

	$c bind has_info <Enter> \
	    [list QueuePopup [namespace code DoInspPopup] %W %x %y %X %Y]
	$c bind has_info <B1-Enter> RemovePopup ;# make sure it does nothing
	$c bind has_info <Leave> RemovePopup

    }
    
    proc GetCanvas {winId} {
        return $winId.c
    }

    proc CaptPathFromPoint { winId x y } {
	set canx [$winId canvasx $x]
	set cany [$winId canvasy $y]
	set target [GetClickedObj $winId $canx $cany 6]
	set node [ExtractPrologName $winId $target]
	set result [GetClickCapt $winId $canx $cany $node]
	#puts [list $canx $cany $target $node $result]
	return $node
    }

    proc OnElementClick { winId x y } {
#	set caption [$winId.tableframe.table itemcget $node -text]
	set canx [$winId canvasx $x]
	set cany [$winId canvasy $y]
	set target [GetClickedObj $winId $canx $cany 6]
	set node [ExtractPrologName $winId $target]
	set context [GetClickCapt $winId $canx $cany $node]

	ProdFromHelper [winfo parent $winId] [CaptPathFromPoint $winId $x $y]
    }
    
    proc DoInspPopup {winId x y X Y} {
	#	    ShowMess debug info $args ok
	global helperTable runState

	set context [CaptPathFromPoint $winId $x $y]

	set topNode [$helperTable([winfo parent $winId],whichInstance) GetNode]
	if {$runState($topNode,modelRunning)>2} {
	    PostPopup $X $Y
#	    set trans [GetTransTable $plName]
#	    if {[catch {GetModelValue $plName} mVal]} {
#		set missing [lindex [split $mVal \"] 1]
#		set value \
#		    "Missing value: [lindex [DescribeComponent $missing] 0]"
#		set value no_value
#	    } else {
#		set value [lindex $mVal 0]
		#puts "trans $trans value $value"
#	    }
	    AddPopupMessage novalue \#ffffc0 GetShortVals $topNode $context
	    AddPopupMessage [GetCompProperty $topNode Spec $context] \#c0ffc0
	    set desc [GetCompProperty $topNode Desc $context]
	    set comment [GetCompProperty $topNode Comment $context]
	    if {[string length $comment]} {
		append desc \n$comment
	    }
	    if {![string length $desc]} {
		set desc {No comment}
	    }
	    AddPopupMessage $desc \#ffe0c0
	}
    }

    proc PrepareSaveString {winId} {
    }
    
    proc Restore {winId} {
	initialize $winId
	set state [GetState $winId]
	if {$state eq "top level"} {set node top} else {
	    set node [GetIdFromCaptionPath $state]
	}
	click $winId $node dummy
    }
    
# override Simile procs in this namespace
    proc ResizeDesktop {can l t r b} {
	$can configure -scrollregion [list $l $t $r $b]
    }
    proc TweakWindow {args} {
    }
    proc LoadModelLooks {args} {
    }

}; # end namespace

