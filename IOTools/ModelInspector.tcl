# ModelInspector.tcl

# Based on SaveState.tcl
# Added Treeview of sub-models and table view of variables  Jonathan Massheder 22/4/01

# SaveState.tcl Jasper Taylor, 28/5/99
# AME Helper app to record or retrieve the state of a model. This is
# to be used both as a general modelling tool, and in conjunction with
# the GCLMI interface or other interface requiring creation and
# initialization of multiple instances of the model.

#$Log: ModelInspector.tcl,v $
#Revision 1.1  2002/05/23 15:33:18  jmm
#*** empty log message ***
#
#Revision 1.12  2002-05-03 14:31:57+01  jmm
#Got rid of references to BLT as it now uses BWidget instead. It is now available for use in the classic multiple window run-time environment.
#
#Revision 1.11  2002-05-01 17:11:19+01  jmm
#Used BWidget::Tree rather than BLT::hiertable
#

set keyValue ModelInspector63654

namespace eval ModelInspector63654 {
    
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
    
    proc initialize {winId} {
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
        ##        ::blt::hiertable $tableframe.table -hideroot true -linespacing 0
        Tree $tableframe.table -showlines yes
        $tableframe setwidget $tableframe.table
        ##        $tableframe.table column insert end "Type"
        ##        $tableframe.table column insert end "Value"
        #        $tableframe.table column insert end "Node"; # dubugging
        
        # Force the creation of ancestors. and allow duplicates for now!
        ##        $tableframe.table configure -autocreate yes; # -allowduplicates yes
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
                set path [lrange $SubbedCompList 1 [llength $SubbedCompList] ]
                set pathLength [llength $path]
                if {$pathLength == 1} {
                    set parent root
                } else  {
                    set parentLabel [lindex $path [expr {$pathLength-2}]]; # indexed from 0
                    set parent $submodel($parentLabel)
                }
                set label [lindex $path end]
                set submodel($label) $component
                $tableframe.table insert end $parent $component \
                        -text [lindex $path end]  -open 1 -image $im(submodel)
            }
        }
        foreach component [GetObjectList] {
            # substitute " " for <cr>s so entry goes on one line # no - need the crs
            set SubbedComp [GetCaptionPathFromId $component]
            set SubbedCompList [split $SubbedComp /]
            set path [lrange $SubbedCompList 1 [llength $SubbedCompList] ]
            #        ShowMessage debug info "GetModelValue $component = [GetModelValue $component]" ok
            if {[llength [info commands GetModelClass]] >0} {
                set type [GetModelClass $component]; # Simile 2.7+
            } else  {
                set type [GetModelType $component]; # Simile < 2.7 - not very good
            }
            set value "None"
            if {![string match SUBMODEL $type]} {
                set value [GetModelValue $component];
                if {[string length $value] == 0 } then {
                    set value {None}
                }
            }
            set label [lindex $path end]
            switch $type {
                INTERNAL { continue; # don't show internal variables }
                SUBMODEL { set image $im(submodel) }
                VARIABLE     {set image $im(variable) }
                COMPARTMENT  {set image $im(compartment) }
                FLOW         {set image $im(flow)}
                CONDITION    {set image $im(condition)}
                CREATION     {set image $im(creation)}
                REPRODUCTION {set image $im(reproduction)}
                IMMIGRATION  {set image $im(immigration)}
                LOSS         {set image $im(loss)}
                default      {set image  $im(variable)}
            }
            
            set pathLength [llength $path]
            if {$pathLength == 1} {
                set parent root
            } else  {
                set parentLabel [lindex $path [expr {$pathLength-2}]]; # indexed from 0
                set parent $submodel($parentLabel)
            }
            #        ShowMessage debug info "$component; $parent; path $path" ok
            #        ShowMessage debug info "$path Type $type Value $value Node $component" ok
            ##            if [catch {$tableframe.table insert end $path \
            ##                        -data "Type $type Value $value " \
            ##                        -icons "$image $image" -activeicons "$image $image"}] {
            #                $tableframe.table entry configure $path -data "Type $type Value $value " \
            #                        -icons "$image $image" -activeicons "$image $image"
            #            }
            
            if {![$tableframe.table exists $component]} {
                $tableframe.table insert end $parent $component \
                        -text [lindex $path end]  -open 1 -image $image
            }
        }
        
        ##        $tableframe.table open -recurse root; # expand all the branches
        ##        $tableframe.table bind all <Button-1> [namespace code OnElementClick]; # bad subst "P PlaceOnTop"
        $tableframe.table bindImage <Button-1> [namespace code OnElementClick]
        $tableframe.table bindText <Button-1> [namespace code OnElementClick]
    }
    
    proc OnElementClick { node } {
        global helperTable
        variable tableframe
        if {![string match none $helperTable(current)]} {
##            set pathlist [$tableframe.table get -full current]; # full path as a list
##            set path [join $pathlist / ]
##            set node [GetIdFromCaptionPath "/$path"]
            set PathList [split [GetCaptionPathFromId $node] /]
            set caption [lindex $PathList end]; # just the var name
            ProdObj $node $caption
        }
    }
    
    proc Restore {winId} {initialize $winId}
    
    
    
}; # end namespace
