# ModelInspector.tcl

# Based on SaveState.tcl
# Added Treeview of sub-models and table view of variables  Jonathan Massheder 22/4/01

# SaveState.tcl Jasper Taylor, 28/5/99
# AME Helper app to record or retrieve the state of a model. This is
# to be used both as a general modelling tool, and in conjunction with
# the GCLMI interface or other interface requiring creation and
# initialization of multiple instances of the model.

#$Log: ModelInspector.tcl,v $
#Revision 1.5  2002/10/21 17:05:20  jaspert
#Going over to DOS file format as I find problems
#Fixed hang in PlotterXY/graphtools
#Fixed problem with integer sliders in c++ models (prolog)
#Removed requirement for out-of-date BWidget version
#
#Revision 1.4  2002/10/18 14:24:47  jmm
#proc GetCanvas added returns canvas for printing etc.
#absolute namespaces used, i.e. start with ::
#
#Revision 1.3  2002/07/24 17:33:35  jmm
#Prevented ghosted variables showing up more than once.
#
#Revision 1.2  2002/06/20 17:12:47  jaspert
#Prolog changes relating to GNU prolog port
#Tcl changes for usability in tcltk 8.3
#
#Revision 1.1.1.1  2002/05/23 15:33:18  jmm
#First Commercial Release (2.91) 
#
#Revision 1.12  2002-05-03 14:31:57+01  jmm
#Got rid of references to BLT as it now uses BWidget instead. It is now available for use in the classic multiple window run-time environment.
#
#Revision 1.11  2002-05-01 17:11:19+01  jmm
#Used BWidget::Tree rather than BLT::hiertable
#

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
                default      {set image $im(variable)}
            }
            
            set pathLength [llength $path]
            #ShowMessage debug info "$component; $type; path $path;" ok
            if {$pathLength == 1} {
                set parent root
            } else  {
                set parentLabel [lindex $path [expr {$pathLength-2}]]; # indexed from 0
                set parent $submodel($parentLabel)
            }
            #        ShowMessage debug info "$component; $parent; path $path" ok
            #        ShowMessage debug info "$path Type $type Value $value Node $component" ok
            
            if {![$tableframe.table exists $component]} {
                # search parent for node with same text
                set text [lindex $path end]
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
        
        OpenLevel 0; # open up level 0 only (so can see level 1)
        
        $tableframe.table bindImage <Button-1> [namespace code OnElementClick]
        $tableframe.table bindText <Button-1> [namespace code OnElementClick]
    }
    
    proc GetCanvas {winId} {
        return ""
    }

    proc OnElementClick { node } {
    global helperTable
    variable tableframe
    if {![string match none $helperTable(current)]} {
        set PathList [split [GetCaptionPathFromId $node] /]
            set caption [lindex $PathList end]; # just the var name
            ProdObj $node $caption
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
