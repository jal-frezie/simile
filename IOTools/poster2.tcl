################################################################################
#
# poster2.tcl
#
################################################################################

set keyValue "poster002"

namespace eval $keyValue {

proc identify {} {
	return "PosterMaker2"
}

proc initialize {w} {
	#ConstructPosterPanel $w
	destroy $w
	set w1 .poster
	toplevel $w1
	ConstructPosterPanel $w1
}


proc click {w node caption} {
}

# Called at start up only
proc ShowHelper {w} {
	#ConstructPosterPanel $w
}

    proc reset {winId} {
    }

# Invoked at every time interval.
proc display {w time step remainder} {
}


	
# Draw panel containing controls and canvas for the graph.
proc ConstructPosterPanel {w} {

global line
global box

set line [open "c:/dump.txt" w]

	set box($w,boxtype) 0
	set box($w,boxnumber) 0

	frame $w.control -width 350 -height 24

	# create buttons
	frame $w.control.buttons 
	foreach item  [list \
			[list "^" [namespace code "SetBoxType $w 0"]] \
			[list "diag" [namespace code "SetBoxType $w 1"]] \
			[list "displ" [namespace code "SetBoxType $w 2"]] \
			[list "txt" [namespace code "SetBoxType $w 3"]] \
			[list "title" [namespace code "SetBoxType $w 5"]] \
			[list ">" [namespace code "ZoomIn $w"]] \
			[list "<" [namespace code "ZoomOut $w"]]  \
			[list "del" [namespace code "SetBoxType $w -1"]]  \
			[list "save" [namespace code "Save $w"]]  \
			[list "load" [namespace code "Load $w"]]  \
			[list "ps" [namespace code "MakePostscript $w"]]] {
		set name [lindex $item 0]
		button $w.control.buttons.$name -text $name  \
			-command [lindex $item 1]
		pack $w.control.buttons.$name -side left
	}
	pack propagate $w.control false
	pack $w.control -fill y -side bottom -fill y
	pack $w.control.buttons -side left

	set width 420
	set height 594

	# Create canvas for poster
	canvas $w.canvas -width $width -height $height 
	pack $w.canvas -fill both -expand true -side bottom

	# Create background rectangle (so that postscript will print background
	# colour).
	# Remember to 'lower' this after lowering anything else!
	$w.canvas create rectangle 0 0 $width $height \
		-tags background -fill #ffe0e0

	# Create title
	$w.canvas create text 2 [expr $height-10] -anchor sw \
		-text "Simile:  http://www.simile.co.uk" \
		-font [myAssembleFont Helvetica Bold R 120] \
		-tags {title}

	# Create rulers
	for {set i 0} {$i<$height} {incr i 20} {
		if {[expr fmod($i,100)]==0} then {
			set colour black
		} else {
			set colour #a0a0a0
		}
		$w.canvas create line   0  $i   5  $i -fill $colour -tag ruler
		$w.canvas create line [expr $width-6]  $i $width  $i -fill $colour -tag ruler
		$w.canvas create line  $i   0  $i   5 -fill $colour -tag ruler
		$w.canvas create line  $i [expr $height-7]  $i $height -fill $colour -tag ruler
	}

	#bind $w.canvas <Button-1> [namespace code ring_bell]
	#bind $w.canvas <Button-1> \
	#	[namespace code "show_canvas_list $w"]
	bind $w.canvas <ButtonPress-1> \
		[namespace code "start_box $w %x %y"]
	bind $w.canvas <B1-Motion> \
		[namespace code "grow_box $w %x %y"]
	bind $w.canvas <ButtonRelease-1> \
		[namespace code "finish_box $w %x %y"]

	$w.canvas bind boxtype:1 <Double-Button-1> \
		[namespace code "BoxAction $w %x %y"]
	$w.canvas bind boxtype:2 <Double-Button-1> \
		[namespace code "BoxAction $w %x %y"]
	#$w.canvas bind boxtype3 <Button-1> \
	#	[namespace code "TextAction $w %x %y"]
	$w.canvas bind boxtype:4 <Double-Button-1> \
		[namespace code "ImageAction $w %x %y"]

	#$w.canvas bind all <Button-1> \
	#	[namespace code "CanvasMark $w %x %y %W"]
	#$w.canvas bind movable <B1-Motion> \
	#	[namespace code "CanvasDrag %x %y %W"]
	$w.canvas bind isbox <Button-1> \
		[namespace code "CanvasMark $w %x %y %W"]
	$w.canvas bind isbox <B1-Motion> \
		[namespace code "CanvasDrag %x %y %W"]
	$w.canvas bind isbox <B1-ButtonRelease> \
		[namespace code "DeleteGuideLines $w.canvas"]

	Canvas_EditBind $w.canvas

}


proc Save {w} {
	global box

	set channel [open [ChooseFile poster.cnv "Poster file" 1] w]

	set items [$w.canvas find all]
	foreach item $items {
		set itemtype [$w.canvas type $item]
		set coords [$w.canvas coords $item]
		set options [$w.canvas itemconfigure $item]
		set opts {}
		foreach option $options {
			set opt_name [lindex $option 0]
			set opt_value [lindex $option 4]
			lappend opts $opt_name $opt_value
		}

		puts $channel "$w.canvas create $itemtype $coords $opts" 
	}
	close $channel
}


proc Load {w} {
	global box
	set posterfile [ChooseFile poster.cnv "Poster file" 0]
	source $posterfile
	set items [$w.canvas find withtag isbox]
	foreach item $items {
		set box($item,boxtype) [get_value $w.canvas $item boxtype]
		set box($item,aspect_ratio) [get_value $w.canvas $item aspect_ratio]
		set box($item,boxnumber) [get_value $w.canvas $item boxnumber]
	}

}


proc get_value {can item attribute} {
	set tags [$can itemcget $item -tags]
	set itag [lsearch $tags $attribute:*]
	if {$itag>=0} then {
		set tag [lindex $tags $itag]
		set i [expr [string first $tag :]+1]
		set value [string range $tag $i end]
		return $value
	}
	return null
}

proc set_value {can item attribute value} {
	set tags [$can itemcget $item -tags]
	set itag [lsearch $tags $attribute:*]
	if {$itag>=0} then {
		set tag [lindex $tags $itag]
		$can dtag $item $tag
	}
	set tag $attribute:$value
	$can addtag $tag withtag $item
}



proc MakePostscript {w} {
	global scaleinfo

	$w.canvas delete ruler

	$w.canvas scale all 0 0 100 100
	ScaleLine $w.canvas all 100

	#set msfont {MS Sans Serif}
	#set fontmap(-*-helvetica-bold-*-*-*-10-*) [list Helvetica-Bold 10]
	#set fontmap(-*-helvetica-*-*-*-*-6-*) [list Helvetica 6]
	#set fontmap(-*-helvetica-*-*-*-*-5-*) [list Helvetica 5]
	#set fontmap(-*-helvetica-bold-*-*--*-120-*) [list Helvetica 4]
	#set fontmap(-*-$msfont-*-*-*-*-8-*) [list Helvetica 4]
		
	$w.canvas postscript -file "c:/poster.ps" \
		-font fontmap \
		-height [expr 59400] -width [expr 42000] \
		-pagex 10.m -pagey 287.m -pageanchor nw \
		-pagewidth 200.m -pageheight 287.m

	$w.canvas scale all 0 0 0.01 0.01
	ScaleLine $w.canvas all 0.01
}


proc ScaleLine {can tag scale} {
	set items [$can find withtag $tag]
	foreach item $items {
		set tags [$can itemcget $item -tags]
		if {[lsearch $tags real_width*]>=0} then {
			set itag [lsearch $tags real_width*]
			set width_tag [lindex $tags $itag]
			set real_width [string trimleft $width_tag real_width]
			set new_width [expr $scale*$real_width]
			$can itemconfigure $item -width $new_width 
			$can dtag $item $width_tag
			$can addtag real_width$real_width withtag $item
		}
		if {[lsearch $tags real_arrow*]>=0} then {
			set itag [lsearch $tags real_arrow*]
			set arrow_tag [lindex $tags $itag]
			set real_arrow_string [string trimleft $arrow_tag real_arrow]
			set real_arrow_list [split $real_arrow_string %]
			set arrow0 [expr $scale*[lindex $real_arrow_list 0]]
			set arrow1 [expr $scale*[lindex $real_arrow_list 1]]
			set arrow2 [expr $scale*[lindex $real_arrow_list 2]]
			$can itemconfigure $item -arrowshape \
				[list $arrow0 $arrow1 $arrow2]
			$can dtag $item $arrow_tag
			$can addtag real_arrow$arrow0%$arrow1%$arrow2 withtag $item
		}
		if {[$can type $item]=="text"} then {
			if {$scale>1} then {
				set scalebox 1.3
				set scalefont 1.05
			} else {
				set scalebox 1.0/1.3
				set scalefont 1.0/1.05
			}
			set font_data [myExtractFontData [$can itemcget $item -font]]
			set family [lindex $font_data 0]
			set weight [lindex $font_data 1]
			set style [lindex $font_data 2]
			set size [lindex $font_data 3]
			set new_size [expr round($size*$scale*$scalefont)]
			$can itemconfigure $item -font \
				[myAssembleFont $family $weight $style $new_size]
			set width [$can itemcget $item -width]
			$can itemconfigure $item -width [expr $scalebox*$width*$scale]
		}
	}
}


proc SetBoxType {w boxtype} {
	global box
	global canvas

	set box($w,boxtype) $boxtype
	if {$boxtype==-1} {
		set canvas($w.canvas,mode) -1
	}
}

proc BoxAction {w x y} {

	set box_item [$w.canvas find closest $x $y]

	set canvasses [show_canvas_list $w]
	set w1 .diagram_dialogue
	toplevel $w1

	frame $w1.f1
	scrollbar $w1.f1.yscroll -command "$w1.f1.listbox yview" -orient vertical
	listbox $w1.f1.listbox -width 45 -yscrollcommand "$w1.f1.yscroll set"
	pack $w1.f1.listbox -side left
	pack $w1.f1.yscroll -side left -fill y
	foreach canvas $canvasses {
		set wintop [winfo toplevel $canvas]
		set title [wm title $wintop]
		$w1.f1.listbox insert end $title
	}
	pack $w1.f1

	button $w1.ok -text "OK" \
		-command [namespace code "choose_canvas $w $w1 \
 			{$canvasses} $box_item"]
	pack $w1.ok


}


proc ImageAction {w x y} {
	tk_messageBox -message "Image insertion not yet implemented."
}


proc TextAction {w x y} {
	bell
}

proc choose_canvas {w w1 canvasses box_item} {

	set isel [$w1.f1.listbox curselection]
	set sel [$w1.f1.listbox get $isel]
	set canvas [lindex $canvasses $isel]

	destroy $w1

	add_one_canvas $w $canvas $box_item
	
}


proc start_box {w x y} {
	global box

	set x0 $x
	set y0 $y
	set box($w,x0) $x
	set box($w,y0) $y
	set box($w,$x0,$y0) 0;   # Cool! The array subscripts are the
					 # initial co-ordinates!

}


proc grow_box {w x y} {
	global box

	set boxtype $box($w,boxtype)
	if {$boxtype>0} {
		set bgcolour [lindex [list #ffffdd #ffffff #ddffff #ffeeee #eeeeff] \
			[expr $boxtype-1]]
		set x0 $box($w,x0)
		set y0 $box($w,y0)
		set x1 $x
		set y1 $y
		if {$box($w,$x0,$y0)==0} {
			if {[expr hypot($x0-$x1,$y0-$y1)]>4} {
				set boxnumber [expr $box($w,boxnumber)+1]
				set box($w,boxnumber) $boxnumber
				set aspect_ratio [expr 1.0*($x1-$x0)/($y1-$y0)]
				set item [$w.canvas create rectangle $x0 $y0 $x1 $y1 \
					-fill $bgcolour \
					-tags "isbox movable \
						boxtype:$boxtype \
						boxnumber:$boxnumber \
						aspect_ratio:$aspect_ratio"]
				set box($w,item) $item
				set box($w,$x0,$y0) 1
				set box($item,aspect_ratio) $aspect_ratio
			}
		}

		if {$box($w,$x0,$y0)==1} {
			set item $box($w,item)
			$w.canvas coords $item $x0 $y0 $x1 $y1
		}
	}
}


proc finish_box {w x y} {
	global box

	set boxtype $box($w,boxtype)
	if {$boxtype>0} {
		set x0 $box($w,x0)
		set y0 $box($w,y0)

		if {$box($w,$x0,$y0)==1} {
			set item $box($w,item)
			set x1 $x
			set y1 $y
			$w.canvas coords $item $x0 $y0 $x1 $y1
			if {$boxtype==3} then {
				set boxnumber $box($w,boxnumber)
				set xa [expr $x0+3]
				set ya [expr $y0+3]
				$w.canvas create text $xa $ya -anchor nw \
					-width [expr $x1-$x0-6] \
					-font [myAssembleFont Helvetica Normal R 100] \
					-tags "text texttext movable \
						boxnumber:$boxnumber \
						textnumber$boxnumber" \
					-text "Text"
			}
			if {$boxtype==5} then {
				set boxnumber $box($w,boxnumber)
				set xa [expr ($x0+$x1)/2]
				set ya [expr ($y0+$y1)/2]
				$w.canvas create text $xa $ya -anchor center \
					-width [expr $x1-$x0-6] \
					-font [myAssembleFont Helvetica Bold R 240] \
					-justify center \
					-tags "text titletext movable \
						boxnumber:$boxnumber\
						textnumber$boxnumber" \
					-text "Title"
			}

		}
	}
	
}



proc ring_bell {} {
	bell
}


proc show_canvas_list {w} {

#set windows [lreplace [winfo children .] 0 1]
#set windows [lreplace $windows 1 1] ; # Awful hack: removes Run Control
#set windows [lreplace $windows end end]
set windows [winfo children .]
set nwindows [llength $windows]

set canvasses {}
foreach window $windows {
	set children1 [winfo children $window]
	foreach child1 $children1 {
		set class [winfo class $child1]
		if {$class=="Canvas"} {
			set canvasses [lappend canvasses $child1]
		} elseif {$class=="Frame"} {
			set children2 [winfo children $child1]
			foreach child2 $children2 {
				set class [winfo class $child2]
				if {$class=="Canvas"} {
					set canvasses [lappend canvasses $child2]
				}
			}; # End foreach child2
		}; # End if $class==canvas or frame
	}; # End foreach child1
}

return $canvasses

}


proc add_one_canvas {w canvas box_item} {

	global box

	set box_coords [$w.canvas coords $box_item]
	set box_x0 [lindex $box_coords 0]
	set box_y0 [lindex $box_coords 1]
	set box_x1 [lindex $box_coords 2]
	set box_y1 [lindex $box_coords 3]
	set box_width [expr $box_x1-$box_x0]
	set box_height [expr $box_y1-$box_y0]

	#Get information on items on the canvas of each window.
	set items [$canvas find all]
	set xmin  999999
	set ymin  999999
	set xmax -999999
	set ymax -999999
	set x0 $xmin
	set y0 $ymin
	set x1 $xmax
	set y1 $ymax
	foreach item $items {
		set coords [$canvas coords $item]
		if {[llength $coords]==4} then { 
			set x0 [lindex $coords 0]
			set y0 [lindex $coords 1]
			set x1 [lindex $coords 2]
			set y1 [lindex $coords 3]
		} elseif {[llength $coords]==2} then {
			set x0 [lindex $coords 0]
			set y0 [lindex $coords 1]
			set x1 $x0
			set y1 $y0
		}
		if {$x0<$xmin} {set xmin $x0}
		if {$y0<$ymin} {set ymin $y0}
		if {$x1>$xmax} {set xmax $x1}
		if {$y1>$ymax} {set ymax $y1}
	}

	set width [$canvas cget -width]
	set height [$canvas cget -height]
	#if {$xmax>$width} {set xmax $width}
	#if {$ymax>$height} {set ymax $height}
	# The above two lines were put in for the case where a canvas item might
	# be drawn bigger than the window (e.g. like the blanking rectangles in
	# the 'Plotter' tool).   However, it seems like resizing the window on the
	# screen - while changing the coordinates of the canvas items - does not
	# change the screen height and width (?).   So these two lines are blanked
	# out - and we'll just have to rely on tools not drawing items bigger than
	# the window.

	set xmin [expr $xmin-20]
	set ymin [expr $ymin-20]
	set xmax [expr $xmax+20]
	set ymax [expr $ymax+20]

	set xrange [expr $xmax-$xmin]
	set yrange [expr $ymax-$ymin]

	set aspect_ratio [expr $xrange/$yrange]
	set box_aspect_ratio [expr $box_width/$box_height]
	set box($box_item,aspect_ratio) $aspect_ratio
	set_value $w.canvas $box_item aspect_ratio $aspect_ratio

	if {$aspect_ratio>$box_aspect_ratio} then {
		set scale [expr $box_width/$xrange]
	} else {
		set scale [expr $box_height/$yrange]
	}


	#set title [lindex $titles [expr $box-1]]
	set title "temporary title"

	set xleft $box_x0
	set xright $box_x1
	set ytop $box_y0
	set ybottom $box_y1

	set tags [$w.canvas gettags $box_item]
	set i [lsearch $tags boxnumber*]
	set boxtag [lindex $tags $i]
	set oxtag [string trimleft $boxtag b]	
	# oxtag is the boxtag for everything in the box except the box itself!
	# to simplify deleting the contents of a box

	foreach item $items {
		set itemtype [$canvas type $item]
		set coords [$canvas coords $item]
		set n [llength $coords]
		switch $itemtype {
			rectangle {
				set x0 [expr $xleft+$scale*([lindex $coords 0]-$xmin)]
				set y0 [expr $ytop+$scale*([lindex $coords 1]-$ymin)]
				set x1 [expr $xleft+$scale*([lindex $coords 2]-$xmin)]
				set y1 [expr $ytop+$scale*([lindex $coords 3]-$ymin)]
				set newitem [$w.canvas create rectangle $x0 $y0 $x1 $y1\
					-fill #d0d0d0 -tags "zz $boxtag $oxtag diagram movable"]
			}
			line {
				set start [list $w.canvas create line]
				set command [scale_coords $start $coords $n \
					$xmin $ymin $xleft $ytop $scale]
				set command [lappend command -tags \
					"zz $boxtag $oxtag movable line" \
					-smooth 1]
				eval $command
			}
			arc {
				set start [list $w.canvas create arc]
				set command [scale_coords $start $coords $n \
					$xmin $ymin $xleft $ytop $scale]
				set command [lappend command -tags "zz $boxtag $oxtag movable"]
				eval $command
			}
			oval {
				set x0 [expr $xleft+$scale*([lindex $coords 0]-$xmin)]
				set y0 [expr $ytop+$scale*([lindex $coords 1]-$ymin)]
				set x1 [expr $xleft+$scale*([lindex $coords 2]-$xmin)]
				set y1 [expr $ytop+$scale*([lindex $coords 3]-$ymin)]
				$w.canvas create oval $x0 $y0 $x1 $y1 \
					-fill #d0d0d0 -tags "zz $boxtag $oxtag movable"
			}
			polygon {
				set start [list $w.canvas create polygon]
				set command [scale_coords $start $coords $n \
					$xmin $ymin $xleft $ytop $scale]
				set command [lappend command -tags "zz $boxtag $oxtag movable"\
					-fill #d0d0d0 -outline black]
				eval $command
			}
			text {
				set x0 [expr $xleft+$scale*([lindex $coords 0]-$xmin)]
				set y0 [expr $ytop+$scale*([lindex $coords 1]-$ymin)]
				set newitem [$w.canvas create text $x0 $y0 \
					-fill #d0d0d0 -tags "zz $boxtag $oxtag movable"]
			}
		}

		set newitem [$w.canvas find withtag zz]
		set options [$canvas itemconfigure $item]
		foreach option $options {
			set opt_name [lindex $option 0]
			set opt_value [lindex $option 4]
			if {[lsearch [list -tags -width -arrowshape] $opt_name]==-1} {
				$w.canvas itemconfigure $newitem $opt_name $opt_value
			}
		}
		if {[lsearch [list rectangle line arc oval polygon] $itemtype]>=0} {
			set width [$canvas itemcget $item -width]
			set new_width [expr $scale*$width]
			$w.canvas itemconfigure $newitem -width $new_width
			set width_tag real_width$new_width
			$w.canvas addtag $width_tag withtag $newitem
		}
		if {$itemtype=="line"} then {
			set arrow [$w.canvas itemcget $newitem -arrowshape]
			set arrow1 [expr $scale*[lindex $arrow 0]]
			set arrow2 [expr $scale*[lindex $arrow 1]]
			set arrow3 [expr $scale*[lindex $arrow 2]]
			$w.canvas itemconfigure $newitem -arrowshape \
				[list $arrow1 $arrow2 $arrow3]
			set arrow_tag real_arrow$arrow1%$arrow2%$arrow3
			$w.canvas addtag $arrow_tag withtag $newitem
		}
		if {$itemtype=="text"} then {
			set font_data [myExtractFontData [$canvas itemcget $item -font]]
			set family [lindex $font_data 0]
			set weight [lindex $font_data 1]
			set style [lindex $font_data 2]
			set size [lindex $font_data 3]
			set new_size [expr round($size*$scale)]
			$w.canvas itemconfigure $newitem -font \
				[myAssembleFont $family $weight $style $new_size]
			set width [$canvas itemcget $item -width]
			$w.canvas itemconfigure $newitem -width [expr $width*$scale]
		}
		$w.canvas dtag $newitem zz
	}


	#$w.canvas lower diagram

}; # end proc add_one_canvas


proc ZoomIn {w} {
	$w.canvas scale all 0 0 1.5 1.5
}


proc ZoomOut {w} {
	$w.canvas scale all 0 0 0.666667 0.666667
}



proc scale_coords {start coords n xmin ymin xleft ytop scale} {

set command $start
for {set i 0} {$i<$n} {incr i 2} {
	set newx [expr $xleft+$scale*([lindex $coords $i]-$xmin)]
	set newy [expr $ytop+$scale*([lindex $coords [expr $i+1]]-$ymin)]
	set command [lappend command $newx $newy]
}
return $command
}

	

proc CanvasMark {w x y can} {
	global canvas
	global line
	global box


	set canvas($can,x) $x
	set canvas($can,y) $y
	set canvas($can,scale) 1

	set item [$can find closest $x $y]
	set coords [$can coords $item]
	set x0 [lindex $coords 0]
	set y0 [lindex $coords 1]
	set x1 [lindex $coords 2]
	set y1 [lindex $coords 3]
	if {$box($w,boxtype)==-1} then {
		set canvas($can,mode) -1
	} elseif {[expr hypot($x-$x1,$y-$y1)]>5} then {
		set canvas($can,mode) 1
	} else {
		set canvas($can,mode) 2
	}
	set canvas($can,obj) $item
	set tags [$can gettags $canvas($can,obj)]
	set i [lsearch $tags boxnumber*]
	set tag [lindex $tags $i]
	set canvas($can,tag) $tag	

	if {$canvas($can,mode)==-1} {
		set tag1 [string trimleft $tag b]
		$can delete $tag1
	} {
		ShowGuideLines $can
	}

}

proc CanvasDrag {x y can} {
	global box
	global canvas

	if {$canvas($can,mode)==-1} {return}

	set dx [expr $x-$canvas($can,x)]
	set dy [expr $y-$canvas($can,y)]
	set item $canvas($can,obj)
	set tag $canvas($can,tag)
	set coords [$can coords $item]
	set x0 [lindex $coords 0]
	set y0 [lindex $coords 1]
	set x1 [expr [lindex $coords 2]+$dx]
	set y1 [expr [lindex $coords 3]+$dy]

	# mode 1: move the box and its contents around
	if {$canvas($can,mode)==1} then {
		$can move $tag $dx $dy
		$can move guideline $dx $dy
		#MoveGuideLines $can $x0 $y0 $x1 $y1
		set canvas($can,x) $x
		set canvas($can,y) $y

	# mode 2: change the box size (bottom-right edge)
	} else {
		set coords [$can coords $item]
		set x0 [lindex $coords 0]
		set y0 [lindex $coords 1]
		set x1 [expr [lindex $coords 2]+$dx]
		set y1 [expr [lindex $coords 3]+$dy]

		set aspect_ratio $box($item,aspect_ratio)
		set box_aspect_ratio [expr ($x1-$x0)/($y1-$y0)]
		if {$aspect_ratio>$box_aspect_ratio} then {
			set scale [expr ($x1-$x0)/($x1-$x0-$dx)]
		} else {
			set scale [expr ($y1-$y0)/($y1-$y0-$dy)]
		}
		set canvas($can,scale) [expr $scale*$canvas($can,scale)]
		$can scale $tag $x0 $y0 $scale $scale
		$can coords $item $x0 $y0 $x1 $y1
		MoveGuideLines $can $x0 $y0 $x1 $y1
		set canvas($can,x) $x
		set canvas($can,y) $y

		set ibox [lindex [split $tag r] 1]
		set texttag textnumber$ibox
		set text_items [$can find withtag $texttag]
		#tk_messageBox -message "$tag ; $ibox ; $texttag ; $text_items"
		if {$text_items!={}} {
			set text_item [lindex $text_items 0]
			$can itemconfigure $text_item -width [expr $x1-$x0-6]
			set tags [$can itemcget $text_item -tags]
			if {[lsearch -exact $tags titletext]>=0} {
				$can coords $text_item \
					[expr ($x1+$x0)/2] [expr ($y1+$y0)/2]
			}
		}


	}
}


proc ShowGuideLines {can} {
	global canvas

	set item $canvas($can,obj)
	set boxtag $canvas($can,tag)

	set coords [$can coords $item]
	set x0 [lindex $coords 0]
	set y0 [lindex $coords 1]
	set x1 [lindex $coords 2]
	set y1 [lindex $coords 3]
	$can create line $x0 -2000 $x0 2000 -fill #a0a0a0 \
		-tags {x0_guideline guideline}
	$can create line -2000 $y0 2000 $y0 -fill #a0a0a0 \
		-tags {y0_guideline guideline}
	$can create line $x1 -2000 $x1 2000 -fill #a0a0a0 \
		-tags {x1_guideline guideline}
	$can create line -2000 $y1 2000 $y1 -fill #a0a0a0 \
		-tags {y1_guideline guideline}
}

proc MoveGuideLines {can x0 y0 x1 y1} {
	$can coords x0_guideline $x0 -2000 $x0 2000
	$can coords y0_guideline -2000 $y0 2000 $y0
	$can coords x1_guideline $x1 -2000 $x1 2000
	$can coords y1_guideline -2000 $y1 2000 $y1
}


#####################################################  proc DeleteGuideLines
#
# This handles everything that happens when a drag on a box is finished 
# (not just deleting the guidelines): rename?
# Note that, during a drag, only the coordinates of the items are changed
# continuously.   This is cheap and easy to do (using the canvas scale
# command), and provides the necessary feedback for the user.   The width
# of lines, and the sizing of the arrowheads, does NOT change during a drag:
# only here, at the end.   This is a computationally-expensive procedure, is
# of little use to the user during the drag, and in most cases things will
# hardly change at all.  

proc DeleteGuideLines {can} {
	global canvas

	set tag $canvas($can,tag)
	set scale $canvas($can,scale)
	ScaleLine $can $tag $scale

	$can delete guideline
}

#######################################################################
# 
# TEXT EDITING BINDINGS
#
# From Welch (Third Edition) p.490 (thanks!)
#
#
# Example 34-12
# Simple edit bindings for canvas text items.
#

proc Canvas_EditBind { c } {
	bind $c <<Cut>> {CanvasTextCopy %W; CanvasDelete %W}
	bind $c <<Copy>> \
		[namespace code "CanvasTextCopy %W"]
	bind $c <<Paste>> \
		[namespace code "CanvasPaste %W"]
	$c bind text <Button-1> \
		[namespace code "CanvasTextHit %W %x %y"]
	$c bind text <B1-Motion> \
		[namespace code "CanvasTextDrag %W %x %y"]
	$c bind text <Delete> \
		[namespace code "CanvasDelete %W"]
	$c bind text <Control-d> \
		[namespace code "CanvasDelChar %W"]
	$c bind text <Control-h> \
		[namespace code "CanvasBackSpace %W"]
	$c bind text <BackSpace> \
		[namespace code "CanvasBackSpace %W"]
	$c bind text <Control-Delete> \
		[namespace code "CanvasErase %W"]
	$c bind text <Return> \
		[namespace code "CanvasNewline %W"]
	$c bind text <Any-Key> \
		[namespace code "CanvasInsert %W %A"]
	$c bind text <Key-Right> \
		[namespace code "CanvasMoveRight %W"]
	$c bind text <Control-f> \
		[namespace code "CanvasMoveRight %W"]
	$c bind text <Key-Left> \
		[namespace code "CanvasMoveLeft %W"]
	$c bind text <Control-b> \
		[namespace code "CanvasMoveLeft %W"]
}
proc CanvasFocus {c x y} {
	focus $c
	set id [$c find overlapping [expr $x-2] [expr $y-2] \
			[expr $x+2] [expr $y+2]]
	if {($id == {}) || ([$c type $id] != "text")} {
		set t [$c create text $x $y -text "" \
			-tags text -anchor nw]
		$c focus $t
		$c select clear
		$c icursor $t 0
	}
}
proc CanvasTextHit {c x y {select 1}} {
	$c focus current
	focus $c
	$c icursor current @$x,$y
	$c select clear
	$c select from current @$x,$y
}
proc CanvasTextDrag {c x y} {
	$c select to current @$x,$y
}
proc CanvasDelete {c} {
	if {[$c select item] != {}} {
		$c dchars [$c select item] sel.first sel.last
	} elseif {[$c focus] != {}} {
		$c dchars [$c focus] insert
	}
}
proc CanvasTextCopy {c} {
	if {[$c select item] != {}} {
		clipboard clear
		set t [$c select item]
		set text [$c itemcget $t -text]
		set start [$c index $t sel.first]
		set end [$c index $t sel.last]
		clipboard append [string range $text $start $end]
	} elseif {[$c focus] != {}} {
		clipboard clear
		set t [$c focus]
		set text [$c itemcget $t -text]
		clipboard append $text
	}
}
proc CanvasDelChar {c} {
	if {[$c focus] != {}} {
		$c dchars [$c focus] insert
	}
}
proc CanvasBackSpace {c} {
	if {[$c select item] != {}} {
		$c dchars [$c select item] sel.first sel.last
	} elseif {[$c focus] != {}} {
		set _t [$c focus]
		$c icursor $_t [expr [$c index $_t insert]-1]
		$c dchars $_t insert
	}
}
proc CanvasErase {c} {
	$c delete [$c focus]
}
proc CanvasNewline {c} {
	$c insert [$c focus] insert \n
}
proc CanvasInsert {c char} {
	$c insert [$c focus] insert $char
}
proc CanvasPaste {c {x {}} {y {}}} {
	if {[catch {selection get} _s] &&
		 [catch {selection get -selection CLIPBOARD} _s]} {
		return		;# No selection
	}
	set id [$c focus]
	if {[string length $id] == 0 } {
		set id [$c find withtag current]
	}
	if {[string length $id] == 0 } {
		# No object under the mouse
		if {[string length $x] == 0} {
			# Keyboard paste
			set x [expr [winfo pointerx $c] - [winfo rootx $c]]
			set y [expr [winfo pointery $c] - [winfo rooty $c]]
		}
		CanvasFocus $c $x $y
	} else {
		$c focus $id
	}
	$c insert [$c focus] insert $_s
}

proc CanvasMoveRight {c} {
	$c icursor [$c focus] [expr [$c index current insert]+1]
}
proc CanvasMoveLeft {c} {
	$c icursor [$c focus] [expr [$c index current insert]-1]
}


###############################################################################
#
# Bits dealing with zooming image
# Adapted from runmodel.tcl
# Eventually, the whole zooming procedure should simply use the one that is 
# built into Simile for handling the normal Desktop window, but not just yet:
# - need to be careful about changing the method used in PosterMaker for 
# handling line- and arrow-sizes to be the same as that used in Simile proper.
#
proc myExtractFontData {font} {
	scan $font {-Adobe-%[^-]-%[^-]-%[^-]-Normal--*-%d-*-*-*-*-*-*} \
		family weight style textsize
	return [list $family $weight $style $textsize]
}

proc myAssembleFont {family weight style textsize} {
	set font [format "-Adobe-%s-%s-%1s-Normal--*-%d-*-*-*-*-*-*" \
			$family $weight $style $textsize]
	#tk_messageBox -message "font $font"
	return $font
}




# end of namespace
} ;

