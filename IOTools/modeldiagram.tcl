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
        set diagFile [ChooseFile model.cnv "Display model diagram file:" 0]
	if {[string length $diagFile]} {
	    set quikStr [NetOpen $diagFile r]
	    SetState $winId [read $quikStr] ;# transcribe file into contents
	    close $quikStr
	    AddDiagram $winId [GetState $winId]
	}
    }

    proc AddDiagram {winId diagFile} {
	global window_info

	pack [ScrolledWindow $winId.s] -fill both -expand 1
	$winId.s setwidget [set c [canvas $winId.c]]
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
	return [GetClickCapt $winId $canx $cany $node]
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
	#	    ShowMessage debug info $args ok
	global helperTable runState

	set context [CaptPathFromPoint $winId $x $y]

	set topNode $helperTable([winfo parent $winId],whichModel)
	if {$runState($topNode,modelRunning)>2} {
	    PostPopup $winId $X $Y
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
    
    proc Restore {winId} {
	AddDiagram $winId [GetState $winId]
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

