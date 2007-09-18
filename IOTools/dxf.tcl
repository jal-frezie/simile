#!./wish -f

# Program: dxf (an autocad's dxf to tk's canvas converter)
# Author:  Tuan T. Doan
# Date:    4/20/93
# =========================================================================
# Copyright 1993 Tuan T. Doan
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted,
# provided that the above copyright notice appear in all copies.  Tuan
# Doan make no representations about the suitability of this software
# for any purpose.  It is provided "as is" without express or implied
# warranty.  If you do use any part of the software, I would like to
# know about it.  Please send me mail at tdoan@bnr.ca
#
# DXF format is copyrighted by Autodesk, Inc.
# =========================================================================

namespace eval ::dxf {
    variable gvar

set gvar(unit) p
set gvar(scale) 1.0

proc _gettuple {fd} {
#  read in two lines; first line = groupcode, second line = groupvalue
   variable gvar
   set gvar(groupcode)  [string trim [gets $fd]]
   set gvar(groupvalue) [string trim [gets $fd]]
#  puts stdout "$gvar(groupcode) $gvar(groupvalue) - " nonewline
# JAT -- occasionally groupvalue missing so set to 0
   if {![string length $gvar(groupvalue)]} {
       puts "!!! groupcode $gvar(groupcode) groupvalue missing"
       set gvar(groupvalue) 0
   }
}

proc _circle {fd} {
#  we already read: 0,CIRCLE  ; continue to read in circle info until see 0
#  interested in: 10=xcenter, 20=ycenter, 40=radius
   variable gvar
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {return "[expr $x-$r]$gvar(unit) [expr $y-$r]$gvar(unit) [expr $x+$r]$gvar(unit) [expr $y+$r]$gvar(unit) -outline black"}
      {10}  {set x $gvar(groupvalue)}
      {20}  {set y [expr {-1 * $gvar(groupvalue)}]}
      {40}  {set r $gvar(groupvalue)}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _line {fd} {
#  we already read: 0,LINE  ; continue to read in line info until see 0
#  interested in: 10=xpoint1, 20=ypoint1, 11=xpoint2, 21=ypoint2
   variable gvar
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {return "${x1}$gvar(unit) ${y1}$gvar(unit) ${x2}$gvar(unit) ${y2}$gvar(unit) -fill black"}
      {10}  {set x1 $gvar(groupvalue)}
      {20}  {set y1 [expr {-1 * $gvar(groupvalue)}]}
      {11}  {set x2 $gvar(groupvalue)}
      {21}  {set y2 [expr {-1 * $gvar(groupvalue)}]}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _triangle {fd} {
#  we already read: 0,3DFACE ; continue to read in surface info until see 0
#  interested in: 10=xpoint1, 20=ypoint1, 11=xpoint2, 21=ypoint2
#                 12=xpoint3, 22=ypoint3, 13=xpoint3, 23=ypoint3
#  if last point 3 is same as point 4, we want only points 1-3
   variable gvar
   set x1 ""; set x2 ""; set x3 ""; set x4 ""
   set y1 ""; set y2 ""; set y3 ""; set y4 ""
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {if {$x3==$x4 && $y3==$y4} {
                puts stdout "3dtri"
#               return "polygon ${x1}$gvar(unit) ${y1}$gvar(unit) ${x2}$gvar(unit) ${y2}$gvar(unit) ${x3}$gvar(unit) ${y3}$gvar(unit) -fill white"
                return "line ${x1}$gvar(unit) ${y1}$gvar(unit) ${x2}$gvar(unit) ${y2}$gvar(unit) ${x3}$gvar(unit) ${y3}$gvar(unit) -fill black"
             } else {
               puts stdout "3dpoly"
#               return "polygon ${x1}$gvar(unit) ${y1}$gvar(unit) ${x2}$gvar(unit) ${y2}$gvar(unit) ${x3}$gvar(unit) ${y3}$gvar(unit) ${x4}$gvar(unit) ${y4}$gvar(unit) -fill white"
                return "line ${x1}$gvar(unit) ${y1}$gvar(unit) ${x2}$gvar(unit) ${y2}$gvar(unit) ${x3}$gvar(unit) ${y3}$gvar(unit) ${x4}$gvar(unit) ${y4}$gvar(unit) -fill black"
             }
            }
      {10}  {set x1 $gvar(groupvalue)}
      {20}  {set y1 [expr {-1 * $gvar(groupvalue)}]}
      {11}  {set x2 $gvar(groupvalue)}
      {21}  {set y2 [expr {-1 * $gvar(groupvalue)}]}
      {12}  {set x3 $gvar(groupvalue)}
      {22}  {set y3 [expr {-1 * $gvar(groupvalue)}]}
      {13}  {set x4 $gvar(groupvalue)}
      {23}  {set y4 [expr {-1 * $gvar(groupvalue)}]}
      {70}  {puts stdout "Invisible edge: $gvar(groupvalue)"}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _arc {fd} {
#  we already read: 0,ARC ; continue to read in arc info until see 0
#  interested in: 10=xcenter, 20=ycenter, 40=radius, 50=startangle, 51=endangle
   variable gvar
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {return "[expr $x-$r]$gvar(unit) [expr $y-$r]$gvar(unit) [expr $x+$r]$gvar(unit) [expr $y+$r]$gvar(unit) -start $sa -extent [expr $sa-$ea] -style arc -fill black"}
      {10}  {set x $gvar(groupvalue)}
      {20}  {set y [expr {-1 * $gvar(groupvalue)}]}
      {40}  {set r $gvar(groupvalue)}
      {50}  {set sa $gvar(groupvalue)}
      {51}  {set ea $gvar(groupvalue)}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _trace {fd} {
#  we already read: 0,TRACE ; continue to read in thick line info until see 0
#  interested in: 10=xpoint1, 20=ypoint1, 11=xpoint2, 21=ypoint2
#                 12=xpoint3, 22=ypoint3, 13=xpoint4, 13=ypoint4
   variable gvar
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {return "${x1}$gvar(unit) ${y1}$gvar(unit) ${x2}$gvar(unit) ${y2}$gvar(unit) ${x3}$gvar(unit) ${y3}$gvar(unit) ${x4}$gvar(unit) ${y4}$gvar(unit) -fill black"}
      {10}  {set x1 $gvar(groupvalue)}
      {20}  {set y1 [expr {-1 * $gvar(groupvalue)}]}
      {11}  {set x2 $gvar(groupvalue)}
      {21}  {set y2 [expr {-1 * $gvar(groupvalue)}]}
      {12}  {set x3 $gvar(groupvalue)}
      {22}  {set y3 [expr {-1 * $gvar(groupvalue)}]}
      {13}  {set x4 $gvar(groupvalue)}
      {23}  {set y4 [expr {-1 * $gvar(groupvalue)}]}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _solid {fd} {
#  we already read: 0,SOLID ; continue to read in triangle or quad until see 0
#  interested in: 10=xpoint1, 20=ypoint1, 11=xpoint2, 21=ypoint2
#                 12=xpoint3, 22=ypoint3, 13=xpoint4, 13=ypoint4
#  if we get only three points, the 4th pts will be the same as the third pts
   variable gvar
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {return "${x1}$gvar(unit) ${y1}$gvar(unit) ${x2}$gvar(unit) ${y2}$gvar(unit) ${x3}$gvar(unit) ${y3}$gvar(unit) ${x4}$gvar(unit) ${y4}$gvar(unit) -fill \"\""}
      {10}  {set x1 $gvar(groupvalue)}
      {20}  {set y1 [expr {-1 * $gvar(groupvalue)}]}
      {11}  {set x2 $gvar(groupvalue)}
      {21}  {set y2 [expr {-1 * $gvar(groupvalue)}]}
      {12}  {set x3 $gvar(groupvalue); set x4 $x3}
      {22}  {set y3 [expr {-1 * $gvar(groupvalue)}]; set y4 $y3}
      {13}  {set x4 $gvar(groupvalue)}
      {23}  {set y4 [expr {-1 * $gvar(groupvalue)}]}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _vertex {fd} {
# JAT -- looks like this proc is meant to set and read x and y on successive 
# calls, so declaring them variable
    variable x
    variable y

#  we already read: 0,VERTEX ; continue to read in point info until see 0
#  interested in: 10=xpoint, 20=ypoint
   variable gvar
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {return "${x}$gvar(unit) ${y}$gvar(unit)"}
      {10}  {set x $gvar(groupvalue)}
      {20}  {set y [expr {-1 * $gvar(groupvalue)}]}
      {70}  {puts stdout "vertex flag = $gvar(groupvalue)"}
      {42}  {puts stdout "vertex bludge = $gvar(groupvalue)"}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _conv2rect {coords} {
#  check to see if the polyline can be converted to a rectangle; this happen
#  if we get 4 points and polyflag=1 (indicate closed polygon) 
#  if we get 5 points and the 5th point is the same as the 1st point
   variable gvar
   if {$gvar(polyflag)=="1" ||
       ([lindex $coords 0]==[lindex $coords 8] &&
        [lindex $coords 1]==[lindex $coords 9])} {
      puts stdout "rect"
      return "rectangle [lindex $coords 0] [lindex $coords 1] [lindex $coords 4] [lindex $coords 5] -fill \"\""
   } else {
      return "line $coords -fill black"
   }
}

proc _polyline {fd} {
#  we already read: 0,POLYLINE ; continue to read in points info (0,VERTEX) 
#  until see 0,SEQEND.  if we see groupcode=70 set polyflag to groupvalue so
#  that we can later determine if polygon is closed
   variable gvar
   set result ""
   set np 0
   set gvar(polyflag) ""
   _gettuple $fd
   while {! [eof $fd]} {
      case $gvar(groupcode) in {
      {0}   {case $gvar(groupvalue) in {
             {VERTEX}  {incr np; append result " [_vertex $fd]"}
             {SEQEND}  {if {$np<2} {puts stdout "ERROR: no of pts in polyline is $np"; exit 1} 
                        _gettuple $fd
                        if {$gvar(polyflag)==1} {
                           return "polygon $result -fill black"
                        } else {
                           if {$np==4 || $np==5} {
                              return [_conv2rect $result]
                           } else {
                              return "line $result -fill black"
                           }
                        }
                       }
             }
            }
      {70}  {set gvar(polyflag) $gvar(groupvalue)
             puts stdout "polyflag = $gvar(polyflag)"
             _gettuple $fd}
      {62}  {set gvar(color)  $gvar(groupvalue); _gettuple $fd}
      {40}  {set gvar(swidth) $gvar(groupvalue); _gettuple $fd}
      {41}  {set gvar(ewidth) $gvar(groupvalue); _gettuple $fd}
      {71}  {set gvar(mcount) $gvar(groupvalue); _gettuple $fd}
      {72}  {set gvar(ncount) $gvar(groupvalue); _gettuple $fd}
      {73}  {set gvar(mdensity) $gvar(groupvalue); _gettuple $fd}
      {74}  {set gvar(ndensity) $gvar(groupvalue); _gettuple $fd}
      default {_gettuple $fd}
      }
   }
}

proc _text {fd} {
#  we already read: 0,TEXT ; continue to read in text info 
#  interested in: 10=xpos, 20=ypos, 1=textstring
   variable gvar
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}   {
             if {$x=="0." && $y=="-1.5"} {
                return "${x}$gvar(unit) ${y}$gvar(unit) -text \"$t\" -fill black"
             } else {
                return "${x}$gvar(unit) ${y}$gvar(unit) -text \"$t\" -fill black"
             }
            }
      {10}  {set x $gvar(groupvalue)}
      {20}  {set y [expr {-1 * $gvar(groupvalue)}]}
      {1}   {set t $gvar(groupvalue)}
      {40}  {set h $gvar(groupvalue)}
      {50}  {set ra $gvar(groupvalue)}
      {51}  {set oa $gvar(groupvalue)}
      {62}  {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _insert {fd} {
#  we already read: 0,INSERT ; continue to read in info on what and where to 
#  insert.  each block to be inserted will be encapsulated in a list consisting
#  of: {block_name xpos ypos xscale yscale angle attr}
#  currently only interested in:  block_name, xpos, ypos, xscale, yscale
   variable gvar
   set bname "";set x "";set y "";set sx 1.;set sy 1.;set ra 0;set attr 0
   while {! [eof $fd]} {
      _gettuple $fd
      case $gvar(groupcode) in {
      {0}  {return [list $bname $x $y $sx $sy $ra $attr]}
      {66} {set attr $gvar(groupvalue)}
      {2}  {set bname $gvar(groupvalue)}
      {10} {set x $gvar(groupvalue)}
      {20} {set y [expr {-1 * $gvar(groupvalue)}]}
      {41} {set sx $gvar(groupvalue)}
      {42} {set sy $gvar(groupvalue)}
      {50} {set ra $gvar(groupvalue)}
      {62} {set gvar(color) $gvar(groupvalue)}
      }
   }
}

proc _insertblock {{parent}} {
#  the data for block (grouped-data) are stored in the variable array 'block'.  
#  the block name is used as index to 'block' and 'binsert' array.  the 
#  'binsert' array is use to store list of block name associated with that 
#  block.  yep, blocks can be nested.  this procedure will extract and display 
#  the block in a canvas.
#  example:  block(table1)={{line ...} {circle ...} {text ...} ...}
#            binsert(table1)={{leg 5 15 .4 .5 0 0} {leg 15 15 .4 .5 0 0} ...}
#            binsert(leg)={{line ...} {line ...} ...}
   variable gvar
   variable block
   variable binsert
   foreach j $binsert($parent) {
      set n  [lindex $j 0]
      set x  [lindex $j 1]
      set y  [lindex $j 2]
      set sx [lindex $j 3]
      if {$sx < 0.0} {set sx [expr "-1 * $sx"]; puts stdout "-XSCALE"}
      set sy [lindex $j 4]
      if {$sy < 0.0} {set sy [expr "-1 * $sy"]; puts stdout "-YSCALE"}
      if {! [info exists binsert($n)]} {puts stdout "? $j"; return}
      if {$binsert($n)==""} {
	  set id $n
	  foreach i $block($n) {
	      eval "$gvar(canvas) create $i -outline black -fill green \
-tags \"$parent $parent:insert $id\""
	  }
	  $gvar(canvas) scale $id 0.0 0.0 $sx $sy
#	  $gvar(canvas) move $id $x $y
#	  $gvar(canvas) coords $id $x $y
      } else {
         _insertblock $n
      }
   }
}

proc _getelement {fd} {
#  check to see if the already read groupcode,groupvalue is one of the elements
#  we want to handle.  if we get a 0,VERTEX outside POLYLINE or 0,POINT  we
#  do a very small circle (OVAL x1 y1 x1 y1).  currently this is used to get
#  elements in the block.  the only way that this procedure will return is that
#  it must encounter one of the listed elements.
   variable gvar
   while {! [eof $fd]} {
#     puts stdout "$gvar(groupcode) $gvar(groupvalue)"
      case $gvar(groupcode) in {
      {0}  {case $gvar(groupvalue) in {
            {LINE}      {return "line [_line $fd]"}
            {3DLINE}    {return "line [_line $fd]"}
            {CIRCLE}    {return "oval [_circle $fd]"}
            {ARC}       {return "arc [_arc $fd]"}
            {3DFACE}    {return "[_triangle $fd]"}
            {POLYLINE}  {return "[_polyline $fd]"}
            {TRACE}     {return "line [_trace $fd]"}
            {SOLID}     {return "polygon [_solid $fd]"}
            {POINT}     {set t1 [_vertex $fd]; return "oval $t1 $t1"}
            {VERTEX}    {set t1 [_vertex $fd]; return "oval $t1 $t1"}
            {TEXT}      {return "text [_text $fd]"}
            default     {_gettuple $fd}
            }
           }
      default {_gettuple $fd}
      }
   }
}

proc _block {fd} {
#  we already read: 0,BLOCK ; continue to read in info until 0,ENDBLK 
#  if we see 2,?  it means this is the name of this block
#  if we see 0,INSERT then build the binsert appropriately
#  if we see 0,? then extract the element by calling _getelement and add it to
#  the list to be returned.
#  if we see 0,ENDBLK we set the variable variables: block and binsert
#  binsert could be an empty list if there is no nested block(s)
   variable gvar
   variable block
   variable binsert
   set r1 {}
   set r2 {}
   _gettuple $fd
   while {! [eof $fd]} {
#     puts stdout "$gvar(groupcode) $gvar(groupvalue)"
      while {$gvar(groupcode)=="0" && \
          $gvar(groupvalue)=="INSERT"} {lappend r2 [_insert $fd]}
      case $gvar(groupcode) in {
      {0}  {case $gvar(groupvalue) in {
            {ENDBLK} {set block($t1) $r1
                      set binsert($t1) $r2
#                     puts stdout block($t1)
                      return $t1}
            default  {lappend r1 [_getelement $fd]}
            }
           }
      {70} {_gettuple $fd}
      {2}  {set t1 $gvar(groupvalue); set binsert($t1) {}; set r2 {}; _gettuple $fd}
      default {_gettuple $fd}
      }
   }
}

proc _entities {fd} {
#  we already read: 0,ENTITIES ; continue to read in info until 0,ENDSEC 
#  
   variable gvar
   variable binsert
   set binsert(main) {}
   _gettuple $fd
   while {! [eof $fd]} {
#     puts stdout "$gvar(groupcode) $gvar(groupvalue)"
      while {$gvar(groupcode)=="0" && $gvar(groupvalue)=="INSERT"} {
         lappend binsert(main) [_insert $fd]
#        set binsert(main) [list [_insert $fd]]
#        _insertblock main
      }
      case $gvar(groupcode) in {
      {0}  {case $gvar(groupvalue) in {
            {ENDSEC}    {return}
            {LINE}      {set t5 "$gvar(canvas) create line [_line $fd]"
                         eval "$t5 -tags obj"
                        }
            {3DLINE}    {set t5 "$gvar(canvas) create line [_line $fd]"
                         eval "$t5 -tags obj"
                        }
            {CIRCLE}    {set t5 "$gvar(canvas) create oval [_circle $fd]"
                         eval "$t5 -tags obj"
                        }
            {ARC}       {set t5 "$gvar(canvas) create arc [_arc $fd]"
                         eval "$t5 -tags obj"
                        }
            {TRACE}     {set t5 "$gvar(canvas) create line [_trace $fd]"
                         eval "$t5 -tags obj"
                        }
            {SOLID}     {set t5 "$gvar(canvas) create polygon [_solid $fd]"
                         eval "$t5 -tags obj"
                        }
            {POINT}     {set p1 [_vertex $fd]
                         set t5 "$gvar(canvas) create oval $p1 $p1"
                         eval "$t5 -tags obj"
                        }
            {VERTEX}    {set p1 [_vertex $fd]
                         set t5 "$gvar(canvas) create oval $p1 $p1"
                         eval "$t5 -tags obj"
                        }
            {3DFACE}    {set t5 "$gvar(canvas) create [_triangle $fd]"
                         eval "$t5 -tags obj"
                        }
            {POLYLINE}  {set t5 "$gvar(canvas) create [_polyline $fd]"
                         eval "$t5 -tags obj"
                        }
            {TEXT}      {set t5 "$gvar(canvas) create text [_text $fd]"
                         eval "$t5 -tags obj"
                        }
            default {_gettuple $fd}
            }
           }
      default {_gettuple $fd}
      }
   }
}

proc _rscale {sr} {
   variable gvar
   puts stderr "SCALING: $sr - $gvar(scale)"
   $gvar(canvas) scale all 0.0 0.0 $sr $sr
   set gvar(scale) [expr $gvar(scale) * $sr]
   set t1 "[$gvar(canvas) bbox all]"
   if {$t1!=""} {$gvar(canvas) configure -scrollregion "$t1"}
}

proc _dumpobj {c tag} {
   global argv
   set fname [file root [file tail $argv]] 
   set fd [open $fname.tkobj w+]
   foreach j [$c find withtag $tag] {
      set opt {}
      foreach i [$c itemconfig $j] {
         if {[llength $i]==5 && [lindex $i 3]!=[lindex $i 4]} {
            lappend opt [lindex $i 0]
            lappend opt [lindex $i 4]
         }
      }
      set t1 [concat "$c create [$c type $j]" [$c coords $j] $opt]
      puts $fd "$t1"
      lappend result $t1
   }
   close $fd
}

# JAT proc to do popups
proc showStats {W x y} {
    set obj [$W find closest [$W canvasx $x] [$W canvasy $y]]
    puts "$obj -- [$W gettags $obj]"
}

proc AddMap {file canvas} {
    variable gvar
    variable binsert

    set gvar(section) 0
    set gvar(canvas) $canvas
    
    set fd [open $file r]
    set gvar(lineno) 1
    set noblock 0
    while {! [eof $fd]} {
	_gettuple $fd
	case $gvar(groupcode) in {
	    {0}  {case $gvar(groupvalue) in {
		{BLOCK}     {set t1 [_block $fd]
		    puts stdout "$t1: $binsert($t1)"
		    incr noblock
		    #                     if {$noblock>5} {break}
		}
	    }
	    }
	    {2}  {case $gvar(groupvalue) in {
		{ENTITIES}  {_entities $fd; _insertblock main}
		{HEADER TABLES BLOCKS ENTITIES} {set gvar(sname) $gvar(groupvalue)}
	    }
	    }
	}
    }
    close $fd
    return $noblock
}

} ;# end namespace
