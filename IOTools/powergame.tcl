# PowerGame

set keyValue powergame001_jt

namespace eval $keyValue {
    variable col 0

proc identify {} {
    return "Power to Change"
}

proc initialize {winId} {
    DoAtStart $winId {}
}

proc Restore {winId} {
    DoAtStart $winId [GetState $winId]
}

proc display {winId time step remainder} {
   DoEachTimeStep $winId $time	
}

proc DoAtStart {win elements} {
   global info

   set info(attributes,edit) \
      {type x0 y0 fill_colour text text_colour font}
   set info(attributes,helper) \
      {type x0 y0 x1 y1 id state}
   set info(attributes,graph) \
      {type x0 y0 x1 y1 edge_colour width fill_colour nxticks nyticks \
      ticksize grid_colour node_label min max line_colours}
   set info(attributes,hyperlink) \
      {type x0 y0 x1 y1 link}
   set info(attributes,image) \
      {type x0 y0 file}
   set info(attributes,label) \
      {type x0 y0 text text_colour font}
   set info(attributes,line) \
      {type x0 y0 x1 y1 colour width arrow}
   set info(attributes,movie) \
      {type x0 y0 node_label directory files thresholds}
   set info(attributes,prediction) \
      {type x0 y0 x1 y1 edge_colour width fill_colour font text_colour \
      node_label font1 text_colour1 predicted_value property}
   set info(attributes,radiobutton) \
      {type xc yc radius outline_colour border_width fill_colour \
      initial_state dot_colour label}
   set info(attributes,rectangle) \
      {type x0 y0 x1 y1 edge_colour width fill_colour}
   set info(attributes,rectangle1) \
      {type x0 y0 x1 y1 raised}
   set info(attributes,slider) \
      {type node_label label_posn x0 y0 x1 y1 min max initial value_posn nticks cursor_colour \
      back_colour font}
   set info(attributes,speak) \
      {type node_label thresholds}
   set info(attributes,text) \
      {type x0 y0 x1 y1 edge_colour width fill_colour font text_colour \
      node_label}
   set info(attributes,warning) \
      {type conditions message}

    if {[llength $elements]} {
	set file [lindex $elements 0]
	set elements [lreplace $elements 0 0]
    } else {
	clipboard clear
	clipboard append "Please select a Simile user interface design file"
	set file [tk_getOpenFile -filetypes {{"User interface design file" {".txt"}}} \
		      -title "Load user interface design file"]
	set ch [open $file r]
	set elements [read $ch]
	close $ch
	SetState $win [linsert $elements 0 $file]
    }
    set info(current_file) $file

   set info(hyperlinks) {}
    set info(logfile) [open [file rootname $file].log w]
# 'catch' is used in next line because event seems to get generated twice when
# closing the window directly
    bind $win <Destroy> [namespace code {DoAtEnd %W}]

   set canvas_settings [lindex $elements 0]
   set info(canvas_settings) $canvas_settings
   set xsize [lindex $canvas_settings 0]
   set ysize [lindex $canvas_settings 1]
   set canvas_colour [lindex $canvas_settings 2]
   set info(max_time) [lindex $canvas_settings 3]
   canvas $win.canvas -width $xsize -height $ysize -bg $canvas_colour
   pack $win.canvas
    CanvasEditBind $win.canvas ;# in toolbox.tcl -- makes text editable
    $win.canvas bind currently_editable <Button-1> \
       [namespace code {ClickCaption %W %x %y}]
    $win.canvas focus

                           ### Direct copying of all the file data into 
                           ### the 'info' array.
   set elements [lreplace $elements 0 0]
   set ielement 0
   foreach element $elements {
       set oops 0
      if {[llength $element]>1} then {
         incr ielement
	   set element_type [lindex $element 0]
         set attributes $info(attributes,$element_type)
         set nvalue [llength $element]
         for {set i 0} {$i<$nvalue} {incr i} {
            set attribute [lindex $attributes $i]
            set info($ielement,$attribute) [lindex $element $i]
            if {[string match $attribute node_label]==1} then {
               set node_label [lindex $element $i]
               set node_label /Desktop/$node_label
               set node_ID [GetIdFromCaptionPath $node_label]
		if {[string match nomatch $node_ID]} {
		    ShowMessage "Missing component" warning "Could not find component $node_label in the model" ok
		    set oops 1
		} else {
		    set info($ielement,node_ID) $node_ID
		}
            }
         }
      }
       if {!$oops} {
	   lappend info(ielements) $ielement
       }
   }

                            ### Now call the appropriate procedure for
                            ### each element.
                            ### We do it like this so we can use exactly the
                            ### same method when any attributes for any elements
                            ### are changed: i.e we re-draw the whole window (to
                            ### preserve the layer ordering).
   toplevel .progress
   foreach ielement $info(ielements) {
      set element_type $info($ielement,type)
      label .progress.label -text "Failed to process this element:\n \
[lindex $elements [expr $ielement-1]]\n\n \
This and all subsequent elements have been ignored."
      pack .progress.label
      pg_$element_type $win.canvas $ielement
      destroy .progress.label
   }
   destroy .progress

                            ### Bindings
   $win.canvas bind radio <Button-1> \
      [namespace code "radiobutton_flip $win.canvas %x %y"]
   $win.canvas bind all <Button-3> \
      [namespace code "set_attributes $win %x %y"]
   $win.canvas bind assignable <Double-Button-1> \
      [namespace code "assign_variable $win.canvas %x %y"]

                            ### Bindings for canvas text (the edit element)
                            ### JT -- it now uses currently_editable for Simile
                            ### bindings, so these are unused

   $win.canvas bind edit_element <1> \
      [namespace code {textB1Press %W %x %y}]
   $win.canvas bind edit_element <B1-Motion> \
      [namespace code [list textB1Move $win.canvas %x %y]]
   $win.canvas bind edit_element <Any-Key> {
      %W insert [%W focus] insert %A
   }
   $win.canvas bind edit_element <BackSpace> {
      if {[%W select item] != {}} {
         %W dchars [%W select item] sel.first sel.last
      } elseif {[%W focus] != {}} {
         set _t [%W focus]
         %W icursor $_t [expr [%W index $_t insert]-1]
         %W dchars $_t insert
         unset _t
      }
   }
   $win.canvas bind edit_element <Return> \
      [namespace code [list textInsert $win.canvas \\n]]
   $win.canvas bind edit_element <Delete> {
      if {[%W select item] != {}} {
         %W dchars [%W select item] sel.first sel.last
      } elseif {[%W focus] != {}} {
         %W dchars [%W focus] insert
      }
   }

   DoEachTimeStep $win 0
}

proc DoAtEnd {$win} {
    global info
    if {[info exists info(ielements)]} {
	unset info(ielements)
	close $info(logfile)
    }
}

proc ClickCaption {W x y} {
    global info

    focus $W
    set tgt [GetClickedObj $W [$W canvasx $x] [$W canvasy $y] 2]
# First, transfer old value to slider, this will re-create the text
    regexp { element([0-9]*) } [$W gettags $tgt] all i
    set value [$W itemcget $tgt -text]
    if {![catch {set fraction [expr round((1e3*$value-$info($i,min))/($info($i,max)-$info($i,min)))]}]} {
	set tgtx [expr $info($i,x0)+$fraction*($info($i,x1)-$info($i,x0))/1e3]
	set node_ID $info($i,node_ID)
	slider_drag slider$node_ID $i $node_ID $tgtx $W slidervalue$node_ID
    }
    $W focus $tgt
}

proc set_attributes {win x y} {
   global info

   set item [$win.canvas find closest $x $y]
   set tags [$win.canvas gettags $item]
   set index [lsearch $tags element*]
   set tag [lindex $tags $index]
   set ielement [string range $tag 7 end]
   set type $info($ielement,type)
   set attributes $info(attributes,$type)

   set w .attributes_dialogue
   toplevel $w
   label $w.label1 -text "Element $ielement"
   pack $w.label1 -side top -anchor w

   frame $w.frame1
   pack $w.frame1 -side top -expand yes -fill y

   set n [llength $attributes]
   for {set i 0} {$i<$n} {incr i} {
      set attribute [lindex $attributes $i]
      if {[string match $type edit]==1 && [string match $attribute text]==1} then {
         set item $info($ielement,item)
         set value [$win.canvas itemcget $item -text]
      } else {
         set value $info($ielement,$attribute)
      }
      label $w.frame1.label$i -text $attribute -anchor w
      entry $w.frame1.entry$i -textvariable address($i) -relief sunken \
            -bg white
# if something has node in its name make it settable from the model diag
       if {[regexp node $attribute]} {
	   bind $w.frame1.entry$i <Button-3> \
	       [namespace code "ClickSet $win %W"]
       }
      $w.frame1.entry$i delete 0 end
      $w.frame1.entry$i insert 0 $value
      if {$i==0} then {
         $w.frame1.entry$i configure -state disabled -bg #b0b0b0
      }
      grid $w.frame1.label$i $w.frame1.entry$i -sticky news
      bind $w.frame1.entry$i <Return> Update
   }

   frame $w.frame2
   pack $w.frame2 -side top -expand yes -fill y

   button $w.frame2.okbutton -text OK \
      -command [namespace code "set_attributes_ok $win $w $ielement $type $n"]
   button $w.frame2.savebutton -text Save \
      -command [namespace code "attributes_save $win.canvas $w $ielement $n"]
   button $w.frame2.saveasbutton -text "Save as ..." \
      -command [namespace code "attributes_saveas $win.canvas $w $ielement $n"]
   pack $w.frame2.okbutton $w.frame2.savebutton $w.frame2.saveasbutton \
      -side left
}

proc ClickSet {win entry} {
    variable curEntry {}
    if {[llength $curEntry]} {
	$curEntry delete 0 end
    }
    if {![string match $entry $curEntry]} {
	$entry delete 0 end
	set curEntry $entry
	$entry insert 0 {CLICK ON COMPONENT}
	GrabClicks $win
    } else {
	ReleaseClicks $win
    }
}

proc click {win node caption} {
    variable curEntry
    ReleaseClicks $win
    $curEntry delete 0 end
    $curEntry insert 0 $caption
}

proc set_attributes_ok {win w ielement type n} {
   global info

   set attributes $info(attributes,$type)

   for {set i 0} {$i<$n} {incr i} {
      set attribute [lindex $attributes $i]
      set info($ielement,$attribute) [$w.frame1.entry$i get]
      if {[string match $attribute node_label]==1} then {
         set node_label $info($ielement,node_label)
         set node_label /Desktop/$node_label
         set node_ID [GetIdFromCaptionPath $node_label]
         set info($ielement,node_ID) $node_ID
      }
   }
   destroy $w
    clear $win
    save_state $win
}

proc clear {win} {
   global info
    variable col
   $win.canvas delete all

    foreach ielement $info(ielements) {
	set element_type $info($ielement,type)
	pg_$element_type $win.canvas $ielement
    }
    set col 0
}

proc attributes_save {canvas w ielement n} {
   global info

   set file $info(current_file)
   attributes_save_to_file $canvas $w $ielement $n $file
}



proc attributes_saveas {canvas w ielement n} {
   global info

   set file [tk_getSaveFile -filetypes {{"User interface design file" {".txt"}}} \
      -title "Save to user interface design file"]
   attributes_save_to_file $canvas $w $ielement $n $file
}



proc attributes_save_to_file {canvas w ielement n file} {
   global info

   set type $info($ielement,type)
   set attributes $info(attributes,$type)

   for {set i 0} {$i<$n} {incr i} {
      set attribute [lindex $attributes $i]
      set info($ielement,$attribute) [$w.frame1.entry$i get]
   }
    save_state $canvas
    write_state_to_file $canvas $file
}

proc save_state {winId} {
    global info

    set state $info(current_file)
   lappend state [list $info(canvas_settings)]
   foreach ielement $info(ielements) {
      set output {}
      set type $info($ielement,type)
      set attributes $info(attributes,$type)
      set n [llength $attributes]
      for {set i 0} {$i<$n} {incr i} {
         set attribute [lindex $attributes $i]
         lappend output $info($ielement,$attribute)
      }
   lappend state [list $output]
   }
   SetState $winId $state
}

proc write_state_to_file {winId file} {
    file delete $file
    set ch [open $file w]
    foreach line [GetState $winId] {
	puts $ch $line
    }
    close $ch
}


proc Update {} {
bell
}


proc scroll_lists {w a b c} {
   $w.frame1.list1 yview
   $w.frame1.list2 yview
}

proc assign_variable {canvas x y} {
   global info

   set current_node_ID [find_tag $canvas $x $y node*]
   set i [lsearch $info(graphed_nodes) $current_node_ID]
   set info(graphed_nodes) [lreplace $info(graphed_nodes) $i $i]
   $canvas delete graphlabel$current_node_ID
debug "$current_node_ID  :::  $info(graphed_nodes)"

   set w .dialogue
   toplevel $w
   frame $w.frame -borderwidth 10
   pack $w.frame -side top -expand yes -fill y

   scrollbar $w.frame.scroll -command "$w.frame.list yview"
   listbox $w.frame.list -yscroll "$w.frame.scroll set" \
      -width 30 -height 16 -setgrid 1
   pack $w.frame.list $w.frame.scroll -side left -fill y -expand 1

   bind $w.frame.list <Double-1> \
      [namespace code "listboxselect fred"]

   set allowed_types {CONSTANT LEVEL DERIVED}
   set objectlist [GetObjectList]
   foreach object $objectlist {
      set object_type [GetModelType $object]
      if {[lsearch -exact $allowed_types $object_type]>=0} {
         set label [GetCaptionPathFromId $object]
         set label [string range $label 9 end]
         $w.frame.list insert end $label
      }
   }

}


proc listboxselect {x} {
   global info

   set sel [.dialogue.frame.list curselection]
   set node_label [.dialogue.frame.list get $sel]
   set node_label /Desktop/$node_label
   set node_ID [GetIdFromCaptionPath $node_label]
#debug "$sel ; $node_label ; $node_ID"
   lappend info(graphed_nodes) $node_ID
   #$canvas create text $x0 [expr $y1-2] \
   $canvas create text 100 100 \
      -text $node_label -anchor sw -tag graphlabel$node_ID
}



proc DoEachTimeStep {win time} {
   global info
    variable col
   
   set max_time $info(max_time)
   if {$time==$max_time} then {
       foreach i $info(ielements) {
	   if {[string match prediction $info($i,type)]} {
	       set predictText [$win.canvas find withtag predict$i]
	       set predictedVal [$win.canvas itemcget $predictText -text]
	       puts $info(logfile) "$info($i,property) value of $info($i,node_label): predicted $predictedVal actual $info($i,last_value)"
	   }
       }
       puts $info(logfile) {}
       bell
   }
    if {$time==0} {
	incr col
    }
   set canvas_height [$win.canvas cget -height]
   $win.canvas delete movie
   $win.canvas delete prediction
   $win.canvas delete text
   clipboard clear

   foreach i $info(ielements) {
      switch $info($i,type) {

         graph {
            set x0 $info($i,x0)
            set y0 [expr $canvas_height-$info($i,y0)]
            set x1 $info($i,x1)
            set y1 [expr $canvas_height-$info($i,y1)]
            set node_ID $info($i,node_ID)
            set min $info($i,min)
            set max $info($i,max)
	     set colPt [expr $col%[llength $info($i,line_colours)]]
            set line_colour [lindex $info($i,line_colours) $colPt]
            set val [lindex [GetModelValue $node_ID] 0]
	     if {[string match novalue $val]} {
		 ShowMessage "Missing value" warning "Could not get a value for $i (Label $info($i,node_label), node $node_ID)" ok
	     } else {
		set maxtcap [$win.canvas find withtag xmax$i]
		set mymax_time [$win.canvas itemcget $maxtcap -text]
		 set x [expr $x0+($time/$mymax_time)*($x1-$x0)]
		 set y [expr $y0+($y1-$y0)*($val-$min)/($max-$min)]
		 if {$time>0} then {
		     set xold $info($i,xold)
		     set yold $info($i,yold)
		     $win.canvas create line $xold $yold $x $y \
			 -fill $line_colour -tag graph_$i
		 }
		 # scale axes if values are out of range -- jasper
		 while {$val<$min} {
		     set min [expr 2*$min-$max]
		     set mincapt [$win.canvas find withtag ymin$i]
		     $win.canvas itemconfigure $mincapt -text $min
		     $win.canvas scale graph_$i 0 $y1 1 0.5
		     set y [expr ($y1+$y)/2]
		     # adjust y so next line starts from right place
		 }
		 while {$val>$max} {
		     set max [expr 2*$max]
		     set maxcapt [$win.canvas find withtag ymax$i]
		     $win.canvas itemconfigure $maxcapt -text $max
		     $win.canvas scale graph_$i 0 $y0 1 0.5
		     set y [expr ($y0+$y)/2]
		 }
		 while {$time>$mymax_time} {
		     set mymax_time [expr 2*$mymax_time]
		     $win.canvas itemconfigure $maxtcap -text $mymax_time
		     $win.canvas scale graph_$i $x0 0 0.5 1
		     set x [expr ($x0+$x)/2]
		 }
		 set info($i,min) $min
		 set info($i,max) $max

		 set info($i,xold) $x
		 set info($i,yold) $y  
	     }
         }

         helper {
         }

         movie {
            set x0 $info($i,x0)
            set y0 [expr $canvas_height-$info($i,y0)]
            set node_ID $info($i,node_ID)
            set val [lindex [GetModelValue $node_ID] 0]
            set thresholds $info($i,thresholds)
            set j 0
            set ok 0
            foreach threshold $thresholds {
               if {$val<$threshold} then {
                  set im [lindex $info($i,images) $j]
                  $win.canvas create image $x0 $y0 \
                     -image $im -anchor sw -tag movie
                  set ok 1
                  break
               }
               incr j
            }
            if {$ok==0} then {
               set im [lindex $info($i,images) end]
               $win.canvas create image $x0 $y0 \
                  -image $im -anchor sw -tag movie
            }
         }

         prediction {
            set x0 $info($i,x0)
            set y0 [expr $canvas_height-$info($i,y0)]
            set x1 $info($i,x1)
            set y1 [expr $canvas_height-$info($i,y1)]
            set node_ID $info($i,node_ID)
            set yincr [expr ($y0-$y1)/3]
            set y0a [expr $y0-$yincr]
            set font $info($i,font)
            set predicted_value $info($i,predicted_value)
            set property $info($i,property)
            set current_value [lindex [GetModelValue $node_ID] 0]

	     if {$time==0 || [regexp final $property]} {
		 set value $current_value
	     } else {
		 set value $info($i,last_value)
		 if {[regexp min $property] && $current_value<$value || \
			 [regexp max $property] && $current_value>$value} {
		     set value $current_value
		 } elseif {[regexp average $property]} {
		     set value [expr ($value*$info(lasttime)+0.5*($value+$current_value)*($time-$info(lasttime)))/$time]
		 }
	     }
	     set info($i,last_value) $value

            $win.canvas create text [expr $x0+3] [expr $y0a-1] -text $value \
               -anchor sw -tag prediction -font $font
         }

         slider {
            set node_ID $info($i,node_ID)
	     set oldValue [lindex [GetModelValue $node_ID] 0]
	     if {$info($i,current_value)!=$oldValue} {
		 puts $info(logfile) "Slider $info($i,node_label) set to \
$info($i,current_value) at time $time"
		 SetModelValue $node_ID $info($i,current_value)
	     }
         }

         speak {
            set node_ID $info($i,node_ID)
            set val [lindex [GetModelValue $node_ID] 0]
            if {$time>0} then {
               set oldval $info($i,oldval)
               set thresholds $info($i,thresholds)
               foreach threshold $thresholds {
                  if {$oldval<$threshold && $val>$threshold} then {
                     clipboard clear
                     clipboard append \
             "Variable $info($i,node_label) has risen above $threshold"
                  } elseif {$oldval>$threshold && $val<$threshold} then {
                     clipboard clear
                     clipboard append \
             "Variable $info($i,node_label) has fallen below $threshold"
                  }
               }
            }
            set info($i,oldval) $val
         }
 
         text {
            set x0 $info($i,x0)
            set y0 [expr $canvas_height-$info($i,y0)]
            set node_ID $info($i,node_ID)
            set val [lindex [GetModelValue $node_ID] 0]
            $win.canvas create text [expr $x0+3] [expr $y0-1] \
               -text $val -anchor sw -tag text
         }

         warning {
            set warning $info($i,warning)
            set conditions [lindex $warning 0]
            set warning_message [lindex $warning 1]
            set issue_warning 1  
            foreach condition $conditions {
               set node_ID [lindex $condition 0]
               set actual_value [lindex [GetModelValue $node_ID] 0]
               set op [lindex $condition 1]
               set test_value [lindex $condition 2]
               switch $op {
                  gt {
                     if {$actual_value<=$test_value} then {
                        set issue_warning 0
                        break
                     }
                  }
                  lt {
                     if {$actual_value>=$test_value} then {
                        set issue_warning 0
                        break
                     }
                  }
                  eq {
                     if {$actual_value!=$test_value} then {
                        set issue_warning 0
                        break
                     }
                  }
               }
            }
            if {$issue_warning==1} then {
               clipboard append $warning_message
            }
         }
      }
   }
    set info(lasttime) $time
}


##########################################################################
#
#              WIDGET-SPECIFIC BITS
#
##########################################################################


proc pg_edit {canvas i} {
   global info

   foreach attribute $info(attributes,label) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]

   set item [$canvas create text $x0 $y0 -text $text -anchor sw \
      -fill $text_colour -font $font -tag element$i]
   $canvas addtag currently_editable withtag $item
   set info($i,item) $item
}


proc pg_graph {canvas i} {
   global info

   foreach attribute $info(attributes,graph) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   set node_ID $info($i,node_ID)

   $canvas create rectangle $x0 $y0 $x1 $y1 -fill $fill_colour \
      -tag element$i

   set xincr [expr int(($x1-$x0)/($nxticks-1))]
   for {set x $x0} {$x<=$x1} {incr x $xincr} {
      $canvas create line $x $y0 $x $y1 -fill $grid_colour -tag element$i
      if {$ticksize>0} then {
         $canvas create line $x $y0 $x [expr $y0+$ticksize] -tag element$i
      }
   }

   set yincr [expr int(($y1-$y0)/($nyticks-1))]
   for {set y $y0} {$y>=$y1} {incr y $yincr} {
      $canvas create line $x0 $y $x1 $y -fill $grid_colour -tag element$i
      if {$ticksize>0} then {
         $canvas create line $x0 $y [expr $x0-$ticksize] $y -tag element$i
      }
   }

   $canvas create rectangle $x0 $y0 $x1 $y1 \
      -width $width -outline $edge_colour -tag element$i

   $canvas create text [expr ($x0+$x1)/2] [expr $y0+5] \
      -text Time -anchor n -tag element$i
   $canvas create text $x0 [expr $y1-2] \
      -text $info($i,node_label) -anchor sw -tag element$i
   $canvas create text [expr $x0] [expr $y0+2] \
       -text 0 -anchor n -tag element$i
   $canvas create text [expr $x1] [expr $y0+2] \
	-text $info(max_time) -anchor n -tag "element$i xmax$i"
    # tag extras allow updating on rescale -- jasper
   $canvas create text [expr $x0-3] [expr $y0] \
       -text $min -anchor e -tag "element$i ymin$i"
   $canvas create text [expr $x0-3] [expr $y1] \
       -text $max -anchor e -tag "element$i ymax$i"


}
proc pg_helper {canvas i} {
   global info helperTable

   foreach attribute $info(attributes,helper) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

    set f [frame $canvas.win$i]
    $canvas create window $x0 $y0 -anchor sw -window $f \
       -tag element$i
    set helperTable($f,whichHelper) $id
    set helperTable($f,status) [RestoreCrs $state]
    ${id}::Restore $f
    $f configure -width [expr $x1-$x0] -height [expr $y0-$y1]
}

proc pg_hyperlink {canvas i} {
   global info

   foreach attribute $info(attributes,hyperlink) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   $canvas create polygon $x0 $y0 $x0 $y1 $x1 $y1 $x1 $y0 -fill black \
      -outline {} -stipple gray12 -tag element$i

   $canvas bind element$i <Enter> \
      [namespace code "hyperlink_detect $canvas 1"]
   $canvas bind element$i <Leave> \
      [namespace code "hyperlink_detect $canvas 0"]
   $canvas bind element$i <Button-1> \
      [namespace code "hyperlink_go $i"]
}


proc hyperlink_detect {win in} {
   if {$in==1} then {
      $win config -cursor hand2
   } else {
      $win config -cursor arrow
   }
}


proc hyperlink_go {i} {
   global info

   bell
   exec "c:/program files/netscape/communicator/program/netscape.exe" \
   $info($i,link) &
}




proc pg_image {canvas i} {
   global info

   foreach attribute $info(attributes,image) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
    if {[catch {
	set im [image create photo -file $file]
    }]} {
	ShowMessage {Missing file} warning "Could not find image file $file" ok
    } else {
	$canvas create image $x0 $y0 -image $im -anchor sw -tag element$i
    }
}


proc pg_label {canvas i} {
   global info

   foreach attribute $info(attributes,label) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]

   $canvas create text $x0 $y0 -text $text -anchor sw \
      -fill $text_colour -font $font -tag element$i
}


proc pg_line {canvas i} {
   global info

   foreach attribute $info(attributes,line) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   $canvas create line $x0 $y0 $x1 $y1 -fill $colour -width $width \
      -arrow $arrow -tag element$i
}


                                ### pg_movie
                                ### Displays one 
proc pg_movie {canvas i} {
   global info

   foreach attribute $info(attributes,movie) {
      set $attribute $info($i,$attribute)
   }

   set images {}
   foreach file $files {
      set filepath {}
      append filepath $directory / $file .gif
       if {[catch {
	   set im [image create photo -file $filepath]
       }]} {
	   ShowMessage {Missing file} warning \
	       "Could not find image file $file" ok
       } else {
	   lappend images $im
    }
   }
   set info($i,images) $images
}


                                ### pg_prediction
                                ### Compares actual and predicted values for
                                ### a variable
proc pg_prediction {canvas i} {
   global info

   foreach attribute $info(attributes,prediction) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   set node_ID $info($i,node_ID)

   set yincr [expr ($y0-$y1)/3]
   set y0a [expr $y0-$yincr]
   set y0b [expr $y0-2*$yincr]


   $canvas create rectangle $x0 $y0b $x1 $y1 -tag element$i \
      -outline $edge_colour -width $width -fill $fill_colour
   $canvas create rectangle $x0 $y0a $x1 $y0b -tag element$i \
      -outline $edge_colour -width $width -fill $fill_colour
   $canvas create rectangle $x0 $y0 $x1 $y0a -tag element$i \
      -outline $edge_colour -width $width -fill $fill_colour

   $canvas create text [expr $x0-2] [expr $y0b-2] \
      -text "Prediction" -anchor se -tag element$i\
      -fill $text_colour1 -font $font1
   $canvas create text [expr $x0-2] [expr $y0a-2] \
      -text "Outcome" -anchor se -tag element$i\
      -fill $text_colour1 -font $font1
   $canvas create text [expr $x0-2] [expr $y0-2] \
      -text Score -anchor se -tag element$i\
      -fill $text_colour1 -font $font1

   $canvas create text [expr $x0+2] [expr $y0b-2] -text $predicted_value \
      -anchor sw -tag "element$i predict$i currently_editable" \
      -fill $text_colour -font $font
   $canvas create text [expr $x0+2] [expr $y0-2] \
      -text 0 -anchor sw -tag "element$i currently_editable" \
      -fill $text_colour -font $font

   $canvas create text [expr $x0] [expr $y1-2] \
      -text "$property $info($i,node_label)" -anchor sw -tag element$i\
      -fill $text_colour -font $font
}


                                ### pg_radiobutton
                                ### An on/off radio button
proc pg_radiobutton {canvas i} {
   global info

   foreach attribute $info(attributes,radiobutton) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set yc [expr $canvas_height-$yc]

   set x0 [expr $xc-$radius]
   set y0 [expr $yc-$radius]
   set x1 [expr $xc+$radius]
   set y1 [expr $yc+$radius]

   set tag radio$xc$yc
   $canvas create oval $x0 $y0 $x1 $y1 -outline $outline_colour \
      -width $border_width -fill $fill_colour -tag "$tag element$i"

   set r [expr $radius-$border_width-2]
   set x0 [expr $xc-$r]
   set y0 [expr $yc-$r]
   set x1 [expr $xc+$r]
   set y1 [expr $yc+$r]

   if {$initial_state==1} then {
      $canvas create oval $x0 $y0 $x1 $y1 -outline $dot_colour \
         -fill $dot_colour -tag "$tag element$i"
      set info($tag,state) 1
   } else {
      set info($tag,state) 0
   }

   $canvas bind $tag <Button-1> \
      [namespace code "radio_flip $canvas $i $xc $yc $radius $r $tag $dot_colour \
      $outline_colour $border_width $fill_colour"]
}


proc radio_flip {canvas i xc yc radius r tag dot_colour outline_colour \
   border_width fill_colour} {
   global info

   if {$info($tag,state)==1} then {
      $canvas delete $tag
      set info($tag,state) 0

      set x0 [expr $xc-$radius]
      set y0 [expr $yc-$radius]
      set x1 [expr $xc+$radius]
      set y1 [expr $yc+$radius]
      $canvas create oval $x0 $y0 $x1 $y1 -outline $outline_colour \
         -width $border_width -fill $fill_colour -tag "$tag element$i"
   } else {
      set x0 [expr $xc-$r]
      set y0 [expr $yc-$r]
      set x1 [expr $xc+$r]
      set y1 [expr $yc+$r]
      $canvas create oval $x0 $y0 $x1 $y1 -outline $dot_colour \
         -fill $dot_colour -tag "$tag element$i"
      set info($tag,state) 1
   }
}


                                ### pg_rectangle
                                ### Draws a rectangle
proc pg_rectangle {canvas i} {
   global info

   foreach attribute $info(attributes,rectangle) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   $canvas create rectangle $x0 $y0 $x1 $y1 -fill $fill_colour \
      -width $width -outline $edge_colour -tag element$i

   #$canvas bind element$i <Motion> bell
}


proc pg_rectangle1 {canvas i} {
   global info

   foreach attribute $info(attributes,rectangle1) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   if {$raised==1} then {
      $canvas create line $x0 $y0 $x0 $y1 $x1 $y1 -fill white
      $canvas create line $x0 $y0 $x1 $y0 $x1 $y1 -fill black
   } else {
      $canvas create line $x0 $y0 $x0 $y1 $x1 $y1 -fill black
      $canvas create line $x0 $y0 $x1 $y0 $x1 $y1 -fill white
   }
}



                                ### pg_rectangle3d
                                ### Experimental: 3D box
proc pg_rectangle3d {canvas i} {
   global info

   foreach attribute $info(attributes,rectangle3d) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   set x0a [expr $x0-2]
   set y0a [expr $y0+2]
   set x1a [expr $x1+2]
   set y1a [expr $y1-2]
   set x0b [expr $x0+2]
   set y0b [expr $y0-2]
   set x1b [expr $x1-2]
   set y1b [expr $y1+3]

   $canvas create line $x0a $y0a $x0a $y1a -fill white 
   $canvas create line $x0a $y1a $x1a $y1a -fill white
   $canvas create line $x0a $y0a $x1a $y0a -fill black
   $canvas create line $x1a $y0a $x1a $y1a -fill black
   $canvas create line $x0b $y0b $x0b $y1b -fill black
   $canvas create line $x0b $y1b $x1b $y1b -fill black
   $canvas create line $x0b $y0b $x1b $y0b -fill white
   $canvas create line $x1b $y0b $x1b $y1b -fill white
   $canvas create rectangle $x0 $y0 $x1 $y1 \
      -width $width -outline $edge_colour
   $canvas create rectangle [expr $x0+$width+1] [expr $y0-$width-1] \
      [expr $x1-2] [expr $y1+2] -fill $fill_colour -outline $fill_colour

}


                                ### pg_slider
                                ### Slider for setting a parameter value
proc pg_slider {canvas i} {
   global info

   foreach attribute $info(attributes,slider) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   set node_ID $info($i,node_ID)
   set info($i,current_value) $initial

   set xc [expr $x0+($x1-$x0)*($initial-$min)/($max-$min)]
    set info($i,lastposn) $xc
   set xa [expr $xc-5]
   set xb [expr $xc+5]
   set yc [expr ($y0+$y1)/2]
   set ya [expr $yc-7]
   set yb [expr $yc+7]

   $canvas create rectangle $x0 $y0 $x1 $y1 -fill $back_colour -tag element$i
   set xincr [expr int(($x1-$x0)/($nticks-1))]
   for {set x $x0} {$x<=$x1} {incr x $xincr} {
      $canvas create line $x $y0 $x [expr $y0+4]
   }
   $canvas create polygon $xa $yc $xc $ya $xb $yc $xc $yb -fill $cursor_colour \
      -tag "slider$node_ID element$i"

    set capt_posn [GetTextPosn $x0 $y0 $x1 $y1 4 $label_posn]
    eval {$canvas create text} $capt_posn \
       {-text $info($i,node_label) -font $font -tag element$i}
   $canvas create text $x0 [expr $y0+3] -text $min \
      -anchor n -font $font -tag element$i
   $canvas create text $x1 [expr $y0+3] -text $max \
      -anchor n -font $font -tag element$i
    set val_posn [GetTextPosn $x0 $y0 $x1 $y1 4 $value_posn]
    eval {$canvas create text} $val_posn \
       {-text $initial -font $font \
	    -tag "slidervalue$node_ID element$i currently_editable"}
   
   $canvas bind slider$node_ID <Button-1> \
      [namespace code "slider_start %x %W"]
   $canvas bind slider$node_ID <B1-Motion> \
      [namespace code "slider_drag slider$node_ID $i $node_ID %x %W \
      slidervalue$node_ID"]
   $canvas bind slider$node_ID <ButtonRelease-1> \
      [namespace code "slider_end $node_ID $i"]
}

proc GetTextPosn {l b r t border align} {
    if {[regexp top $align]} {
	set anch s
	set y [expr $t-$border]
    } elseif {[regexp bottom $align]} {
	set anch n
	set y [expr $b+$border]
    } else {
	set y [expr ($b+$t)/2]
    }
    if {[regexp left $align]} {
	append anch e
	set x [expr $l-$border]
    } elseif {[regexp right $align]} {
	append anch w
	set x [expr $r+$border]
    } else {
	set x [expr ($r+$l)/2]
    }
    if !{[info exists anch]} {
	set anch c
    }
    return "$x $y -anchor $anch"
}

proc slider_start {x can} {
   global canvas

   set canvas($can,x) $x
}

proc slider_end {node_ID i} {
   global info

   #SetModelValue $node_ID $info($i,current_value)
}


proc slider_drag {tag i node_ID x can slidervaluetag} {
#ShowMessage debug info "Draggging $tag $i $node_ID $x $can $slidervaluetag" ok
   global canvas
   global info

   set x0 $info($i,x0)
   set x1 $info($i,x1)
   set y0 $info($i,y0)
   set y1 $info($i,y1)
   set canvas_height [$can cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]
   set min $info($i,min)
   set max $info($i,max)
   set font $info($i,font)
   set xold $info($i,lastposn)

   if {$x>=$x0 && $x<=$x1} then {
      set dx [expr $x-$xold]
   } elseif {$x<$x0 && $xold>$x0} then {
      set dx [expr $x0-$xold]
   } elseif {$x>$x1 && $xold<$x1} then {
      set dx [expr $x1-$xold]
   } else {
      set dx 0
   }
   $can move $tag $dx 0
   #set canvas($can,x) [expr $xold+$dx]
   set x [expr $xold+$dx]
   set info($i,lastposn) $x

   set value [expr $min+($max-$min)*(1.0*$x-$x0)/($x1-$x0)]
#   $can delete $slidervaluetag
#   $can create text [expr $x1+4] [expr $y0+3] -text $value -anchor sw \
#      -font $font -tag "$slidervaluetag element$i currently_editable"
    $can itemconfigure $slidervaluetag -text $value
   set info($i,current_value) $value

}


                                ### pg_speak
                                ### Speaks when a variable crosses some 
                                ### threshold
proc pg_speak {canvas i} {
   global info

   foreach attribute $info(attributes,speak) {
      set $attribute $info($i,$attribute)
   }

   set node_ID $info($i,node_ID)

}

                                ### pg_text
                                ### Displays the value for a variable 
proc pg_text {canvas i} {
   global info

   foreach attribute $info(attributes,text) {
      set $attribute $info($i,$attribute)
   }

   set canvas_height [$canvas cget -height]
   set y0 [expr $canvas_height-$y0]
   set y1 [expr $canvas_height-$y1]

   set node_ID $info($i,node_ID)

   $canvas create rectangle $x0 $y0 $x1 $y1 -tag element$i \
      -outline $edge_colour -width $width -fill $fill_colour 
   $canvas create text [expr $x0] [expr $y1-2] -tag element$i \
      -text $info($i,node_label) -anchor sw \
      -fill $text_colour -font $font
}


                                ### pg_warning
                                ### Speaks a warning when some condition is met
proc pg_warning {canvas i} {
   global info

   foreach attribute $info(attributes,warning) {
      set $attribute $info($i,$attribute)
   }

   set conditions1 {}
   foreach condition $conditions {
      set node_label [lindex $condition 0]
      set node_label /Desktop/$node_label
      set node_ID [GetIdFromCaptionPath $node_label]
      set op [lindex $condition 1]
      set value [lindex $condition 2]
      set condition1 [list $node_ID $op $value]
      lappend conditions1 $condition1
   }
   set message $info($i,message)
   set warning [list $conditions1 $message]
   set info($i,warning) $warning
}


###############################################################################
#
#                 EVENT HANDLERS
#
###############################################################################


proc radiobutton_flip {canvas x y} {
   global info

   bell
   
}


###############################################################################
#
#                 UTILITIES
#
###############################################################################

proc find_tag {canvas x y start_of_tag} {

   set item [$canvas find closest $x $y]
   set tags [$canvas gettags $item]
   foreach tag $tags {
      if {[string match $start_of_tag $tag] == 1} then {
         return $tag
      }
   }
}



### canvas text bindings

proc textEnter {w} {
    global textConfigFill
    set textConfigFill [lindex [$w itemconfig current -fill] 4]
    $w itemconfig current -fill black
}

proc textInsert {w string} {
    if {$string == ""} {
	return
    }
    catch {$w dchars text sel.first sel.last}
    $w insert text insert $string
}

proc textPaste {w pos} {
    catch {
	$w insert text $pos [selection get]
    }
}

proc textB1Press {w x y} {
    $w icursor current @$x,$y
    $w focus current
    focus $w
    $w select from current @$x,$y
}

proc textB1Move {w x y} {
    $w select to current @$x,$y
}

proc textBs {w} {
    if ![catch {$w dchars text sel.first sel.last}] {
	return
    }
    set char [expr {[$w index text insert] - 1}]
    if {$char >= 0} {$w dchar text $char}
}

proc textDel {w} {
    if ![catch {$w dchars text sel.first sel.last}] {
	return
    }
    $w dchars text insert
}



proc debug {message} {
   tk_messageBox -message $message
}
 
} ;
# end of namespace·
