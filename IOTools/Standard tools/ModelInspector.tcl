# ModelInspector.tcl

# Based on SaveState.tcl
# Added Treeview of sub-models and table view of variables  Jonathan Massheder 22/4/01

# SaveState.tcl Jasper Taylor, 28/5/99
# AME Helper app to record or retrieve the state of a model. This is
# to be used both as a general modelling tool, and in conjunction with
# the GCLMI interface or other interface requiring creation and
# initialization of multiple instances of the model.

set keyValue ModelInspector63654

namespace eval ::ModelInspector63654 {
    
    package require BWidget
    namespace import ::BWidget::*
    
    
    variable tableframe
    
    proc identify {} {
        return "Explorer"
    }
    
    proc display {args} {
    }
    
    proc clear {winId} {
    }
    
    proc reset {winId} {
    }

    proc initialize {winId} {
        global tcl_platform
        variable tableframe
        set im(submodel) [image create photo submodel_im -file "../Images/Toolbar/submodel.gif"]
        set im(compartment) [image create photo  -file "../Images/Toolbar/compartment.gif"]
        set im(flow) [image create photo  -file "../Images/Toolbar/flow.gif"]
        set im(variable) [image create photo  -file "../Images/Toolbar/variable.gif"]
        set im(condition) [image create photo  -file "../Images/Toolbar/condition.gif"]
        set im(creation) [image create photo  -file "../Images/Toolbar/creation.gif"]
        set im(reproduction) [image create photo  -file "../Images/Toolbar/reproduction.gif"]
        set im(immigration) [image create photo  -file "../Images/Toolbar/immigration.gif"]
        set im(loss) [image create photo  -file "../Images/Toolbar/loss.gif"]
        
        set tableframe $winId.tableframe
        ScrolledWindow $tableframe
        Tree $tableframe.table -showlines yes
        $tableframe setwidget $tableframe.table
        pack $tableframe -expand yes -fill both
        
        
        
#        tk_messageBox -message [GetObjectList] -type ok
        #get submodel nodeIds for parents
        foreach component [GetObjectList] {
            if {[llength [info commands GetModelClass]] >0} {
                set type [GetModelClass $component]; # Simile 2.7+
            } else  {
                set type [GetModelType $component]; # Simile < 2.7 - not very good
            }
            if {[string match SUBMODEL $type ]} then {
                set SubbedComp [GetCaptionPathFromId $component]
                set SubbedCompList [split $SubbedComp /]
                set path [lrange $SubbedCompList 1 end]
                set pathLength [llength $path]
                if {$pathLength == 1} {
                    set parent root
                } else  {
                    set parentLabel [lrange $path 0 [expr {$pathLength-2}]]; # indexed from 0
                    set parent $submodel($parentLabel)
                }
                set submodel($path) $component
                $tableframe.table insert end $parent $component \
		    -text [BlankCrs [lindex $path end]]  -open 1 \
		    -image $im(submodel)
            }
        }
        foreach component [GetObjectList] {
            # substitute " " for <cr>s so entry goes on one line # no - need the crs
            set SubbedComp [GetCaptionPathFromId $component]
            set SubbedCompList [split $SubbedComp /]
            set path [lrange $SubbedCompList 1 end]
            #        ShowMessage debug info "GetModelValue $component = [GetModelValue $component]" ok
            if {[llength [info commands GetModelClass]] >0} {
                set type [GetModelClass $component]; # Simile 2.7+
            } else  {
                set type [GetModelType $component]; # Simile < 2.7 - not very good
            }
            switch $type {
                INTERNAL { continue ;# don't show internal variables
		}
                SUBMODEL { set image $im(submodel) }
                VARIABLE     {set image $im(variable) }
                COMPARTMENT  {set image $im(compartment) }
                FLOW         {set image $im(flow)}
                CONDITION    {set image $im(condition)}
                CREATION     {set image $im(creation)}
                REPRODUCTION {set image $im(reproduction)}
                IMMIGRATION  {set image $im(immigration)}
                LOSS         {set image $im(loss)}
                default      {set image $im(variable)}
            }
            
            set pathLength [llength $path]
            #ShowMessage debug info "$component; $type; path $path;" ok
            if {$pathLength == 1} {
                set parent root
            } else  {
                set parentLabel [lrange $path 0 [expr {$pathLength-2}]]; # indexed from 0
                set parent $submodel($parentLabel)
            }
            #        ShowMessage debug info "$component; $parent; path $path" ok
            if {![$tableframe.table exists $component]} {
                # search parent for node with same text
                set text [BlankCrs [lindex $path end]]
                set sameText 0
                foreach node [$tableframe.table nodes $parent] {
                    #ShowMessage debug info "$node" ok ; # Simile node IDs
                    if {[string match [$tableframe.table itemcget $node -text] $text]} {
                        set sameText 1
                    }
                }
                if {!$sameText} {
                    $tableframe.table insert end $parent $component \
			-text $text -image $image
                }
            }
        }
        
#	OpenLevel 0; # open up level 0 only (so can see level 1)
        
	$tableframe.table bindImage <Button-1> \
	    [namespace code "OnElementClick $winId"]
        $tableframe.table bindText <Button-1> \
	    [namespace code "OnElementClick $winId"]
        if [PrefValue custom(compValPop) compValPop] {
	    $tableframe.table bindImage <Enter> \
	        [list QueuePopup [namespace code DoInspPopup] $winId %X %Y]
	    $tableframe.table bindText <Enter> \
	        [list QueuePopup [namespace code DoInspPopup] $winId %X %Y]
	    $tableframe.table bindImage <Leave> RemovePopup
	    $tableframe.table bindText <Leave> RemovePopup
        }
    }
    
    proc GetCanvas {winId} {
        return ""
    }

    proc OnElementClick { winId node } {
	set caption [$winId.tableframe.table itemcget $node -text]
	ProdFromHelper $winId $node $caption
    }
    
    proc DoInspPopup {winId X Y plName} {
	#	    ShowMessage debug info $args ok
	global helperTable runState
	set node $helperTable($winId,whichModel)
	if {$runState($node,modelRunning)>2} {
	    PostPopup $X $Y
#	    set trans [GetTransTable $plName]
	    if {[catch {GetModelValue $plName} mVal]} {
#		set missing [lindex [split $mVal \"] 1]
#		set value \
#		    "Missing value: [lindex [DescribeComponent $missing] 0]"
		set value no_value
	    } else {
		set value [lindex $mVal 0]
		#puts "trans $trans value $value"
	    }
	    AddPopupMessage novalue \#ffffc0 $node GetShortVals $node $plName
	}
    }
    
    proc Restore {winId} {initialize $winId}
    
    proc OpenLevel {level} {
        # only works for level = 0
        variable tableframe
        $tableframe.table closetree node00001; # recursively close all nodes
        set nodes node00001; # root or Desktop
        for {set i 0} {$i <= $level} {incr i} {
            foreach node $nodes {
                $tableframe.table itemconfigure $node -open 1
                set nodes [$tableframe.table nodes $node]
            }
        }
    }
    
}; # end namespace

