#!/bin/wish
# NB change the line above to suit your UNIX system.
# Windows will ignore it.


set keyValue "threeDoodle98"
namespace eval ::$keyValue {

 variable helperNamespace [ namespace current ]
 variable thdVersion "v1.0 1600 27th August 1998"
 

# Versions: 0.1.* and newer will interact with AME via the Helper
# interface. (Actually, that worked from 0.0.9)
# 0.0.* Are developments of the 3D code and interface.

# As of Version 0.1.0 this will have a name - 3Doodle

# Version 0.1.0 (Will proly become Version 1.0.0)
# Removed use of fonts, not useful.
# Check for div-by-zero errors.
#   proc calcXYStep
# Height auto-scaling.
# 
# Version 0.0.99
# From an email to bob:
# 
#New things, then:
#1. Feedback to AME. RIGHT click on a column TOP and you get a list of 
#values on that grid square. As you'll see, >1 value on a grid sq 
#stack now, instead of combining as before. Change the value(s) and 
#click OK, the display updates and AME updates internally too.
#
#  BUG : if you have any stacking, then switching to 'surface view' 
#will not work. Can't say why yet.
#
#2. Colour auto-ranging. You can see the values by going into the 
#Colour menu. Changing these values has noeffect at present, as 
#auto-ranging is on all the time. This is a TODO.
#
#Another TODO is height autoranging.
#
#3. Number of Columns. 
#Option | Number of Columns ...
#Change the number, hit OK. voila.
#
#TODO : Column height dragging. (The LEFT mouse button is reserved for 
#this.)
#Also , colouring on a match (eg a spp or type) rather than a range, 
#fixing surface mode, auto-adjust num cols if the num values are 
#obviously evenly spaced... Anything you can think of.(?)
#
#HTH, al.
#
# Version 0.0.98
# Finally implemented AME interaction. Involves a fairly thorough rewrite of the
# data structures, a big job.
# Done. Basic technique : ( Look in GetQuadList, use of a_Id in proc ReadData and
# proc setNewValues.
# 1. When constructing data from AME, keep a corresponding array of lists of
# array identifiers (called (elt) in GetQuadList)
# 2. When changing data in setNewValues, use these identifiers to change the
# correct data.
# Also, added colour auto-ranging and column stacking. For this, changed the
# data repn from arrays to arrays of lists (a_ZValues and a_rawColourData and
# a_Id).
#
# Version 0.0.97e:
# rethinking data representation to enable feedback to AME.  (see notes 0.0.97b)
# Another issue to be solved quickly is multiple instances.
# 
# Version 0.0.97d:
# Silly way of constructing the display list repaired in proc graphics::draw
# 
# Version 0.0.97c:
# Small bug in rotation code fixed - if view was rotated to VRot=+-1, then the
# view stuck there.
# 
# Version 0.0.97b:
# Half way there. Values changed internally by user.
# Problem with the feeedback to AME. I'll have to rework the internal data
# structures a bit. From an email to Jasper:
# 
#This is fine, and seems to mean that if I want to change the height 
#at some (x,y), then I fetch the list and search for the nth element, 
#where [lindex $xvals $n] is x and similarly for y. Then I change 
#$heightvals element n, and send it back to AME.
#
#Correct? (Of course, I could just keep the list hanging around 
#instead of fetching it, but that's nasty IMHO)
#
#If so, then I have an interesting problem as >1 value can be 
#displayed at any given x,y and so the user click on the screen item 
#doesn't in general correspond to a unique datum. hmm.
#
#It looks like my best bet is to change the internal data structure to 
#an array of lists, where if >1 data is on the same x,y then instead 
#of summing (height) or overriding (colour) the datum is appended to 
#the list at x,y.
#
#Then upon a user request to change data at x,y a list of 
#corresponding data can be presented and one chosen, or summin 
#similar.
#
# Version 0.0.97a:
# Reworked the GUI using menus instead of ugly buttons.
#
# Version 0.0.96:
# NB TODO: BUG: Multiple instances of this helper share the same namespace.
# subnamespaces added to control variable bloat, and add some self-documentation
# etc. All the code except that required by AME to be at this level is now in
# one of 5 sub-namespaces, graphics:: window:: data:: utility:: debug::
# To get this working, I have found it best to declare all shared variables at
# this level, then upvar them into the subnamespaces and declare them 
# variables again in the procs where they are rqd. The code is much neater as a
# consequence. Might consider splitting the code into several files now.
# 
# Version 0.0.95a:
# BUG! fixed in GetQuadList, which crashed whenever a model was run! oeps.
# Version 0.0.95:
# namespace named using system clock, to generate unique name in case of
# multiple instances.
# Added tags to every drawn poly to identify the array posn of it's data. The
# event binding will have to wait for next version, as I need some advice here.
# Added fourth value and "don't do that" response to extra clicks. The fourth
# value will be used to colour the columns, and will provide feedback to the
# model. Some error checking must be done on the value chosen, as it seems that
# if a value which does not have a corresponding x,y meaning is chosen, then an
# error is generated. TODO: discuss with Jasper.
# Speeding up the drawing: 
#     1. Don't draw the 'back sides' TODO: Make this a user option DONE
#     2. Don't draw sides where top is height zero.
#     These optimisations take place in buildDisplayList.
# 
# Version 0.0.94:
# Generalised the grid display size. Growth as mentioned in 0.0.93 below should
# now work, but I have no suitable models to test this.
# Note : the number of namespace variables is now large. Too large. Split this
# code into other namespaces (akin to OO classes) to encapsulate functionality
# and variables.
# 
# Version 0.0.93:
# Tidied up a few hangovers from the old method of data representation, so that
# now the number of columns on the display is set with a couple of variables.
# This allows me to do various things, not least grow the display to maintain
# the meaning as the range extends.
# 
# Version 0.0.92:
# Debug following responses from Jasper: 
# proc ReadData {winId xs ys hs} :
# Changed method of calculating indices, to ensure -ve x,y is acceptable.
#
# Version 0.0.91:
# Generally tidying up before v 0.1*. Added thdVersion which should be kept up
# to date and is displayed on the gui. Added divide by zero check in ReadData.
# Changed default startup to columns. Added z scale. This is the first version
# to work on Jasper Taylor's PC.
#
# Version 0.0.9:
# Finally, I have sicstus 3#6, TclTk 8, and AME 3.2 working happily alongside
# each other. So... now to get this code working with it.
# The namespace has already been setup (version 0.0.6) and so the next task is
# to wrap all the stray initialisation into an init proc. For simple variables
# this is sufficient, for window widgets we need to create them as children of
# the top-level window created by AME.
# The point of entry for AME is the procs identify, initialize, click and
# display.
# The initialisation code previously lying around this file has been swept up
# and popped in Initialise3Doodle. This sets up the viewer and buttons and
# scales, as well as the dummy data. It then performs a ReadData, which should
# replace the dummy data with AME data, and calls calcViewParams and draw to
# display it.
# Completed 19th Feb 1998, 00:03 am!!!! Thank **** for that. I can goto bed. Or
# mibbe I'll have a glass of wine first, to celebrate ;)
# 
# Version 0.0.8:
# This version intended to polish off the 3D code, adding columnar display
# and improve rotation code which has been a bit ropey.
# New state variable b_columns added, b_columns == 0, surface; 1, columns.
# Completed 160298
#
# Version 0.0.7:
# Previous version completed the basic 3D code. This version adds improved 3D
# appearance and rotation.
# Started 180197
#
# Version 0.0.6:
# Adding support for AME Helper integration. This adapted from the
# lollipop.tcl example.
# The first thing to do was wrap the whole thing in a namespace and then
# replace all the variables declared with the 'set' keyword with
# 'variable' declarations. Also, the '-command' options for the scale
# widgets needed to be given fully scoped function names.
# Also added some rough shading effects in proc buildDisplayList 
# Also added a 'spin' function (, assigned to the previously crappy Rotate
# button.
# Completed 170197
#
# New in version 0.0.5:
# 360 degree horzontal rotation.
# For this, changes have been made in buildDisplayList, calcViewParams,
# and esp. HRotate
#
# New in version 0.0.4:
# Globals controlling the view are d_zoomValue, d_vertRotn, d_horzRotn
# Screen coord parameters are derived from these 3 globals in 
# proc calcViewParams, and used to calculate screen coords in 
# proc setUpVertex
#
# Please note this is my first tcl so if the style is crap,
# have patience!
# Author :  allan.kelly@ed.ac.uk
#
# Written under W95 with the VIM editor. Well, do you know any other
# small editors ith a TCL mode?
# Besides, I *like* it. It does *everything* =)
# http://www.vim.org

 ##################
 # SHARED VARIABLES
 #
 # THE DATA
 variable a_ZValues
 variable a_Id
 variable a_rawColourData
 variable a_Colours
 #
 variable xColsStart
 variable yColsStart
 variable xColsEnd
 variable yColsEnd
 variable i_canWidth
 variable i_canHeight
 variable b_columns
 variable b_backFaces
 
 variable myCanvas
 variable myDebug
 
 variable dataNS ${helperNamespace}::data
 variable graphicsNS ${helperNamespace}::graphics
 variable windowNS ${helperNamespace}::window
 variable utilityNS ${helperNamespace}::utility
 variable code_columnsDialog 
 variable code_setNewColumns 
 variable code_colourDialog 
 variable code_setNewColours 
 variable code_adjustValuesDialog

 variable quadlist
##################################################
# AME helper procs

##################################################
# proc identify {}
# Description displayed in AME menu
proc identify {} {
   return "3-D viewer"
}
# proc identify {}
##################################################

##################################################
# proc initialize {winId}
# The first thing this Helper will do with it's window.
proc initialize {winId} {
    global normalColor

# set normal button colour ina system-independent way
    button .dummy
    set normalColor [.dummy cget -bg]
    destroy .dummy

   set ms [message $winId.intro -text "CHOOSE tree::xposn PLEASE."]
   pack $ms
   SetState $winId xcoord
    GrabClicks $winId
}
# proc initialize {winId}
##################################################

##################################################
# proc click {winId node caption}
proc click {winId node caption} {
   set ms $winId.intro
   set testResult [GetModelValue $node]
   if {[string compare $testResult novalue]} {
      set state [GetState $winId]
      switch [lindex $state 0] {
         xcoord {
            $ms configure -text \
               "CHOOSE tree::yposn PLEASE."
            set newState ycoord
         }
         ycoord {
            $ms configure -text \
               "FOR THE COLOUR, CHOOSE tree::variation PLEASE."
            set newState colorValue
         }
         colorValue {
            $ms configure -text \
               "CHOOSE tree::SIZE PLEASE."
            set newState sizeval
         }
         sizeval {
            pack forget $ms
            # Now, call my init fn.
            Initialise3Doodle $winId [lindex $state 1] [lindex $state 3] [lindex $state 5] $node
            # And update the state
            set newState displaying
	     ReleaseClicks $winId
         }
         displaying {
            # An Error condition.
            set ms [message $winId.intro -text "Ouch! *(>("]
            pack forget $ms
         }
      }
      # END switch
      SetState $winId [lreplace [lappend state $node $caption] 0 0 $newState]
   } else {
      $ms configure -text \
         "This component, $caption, does not have a value; please choose a compartment, variable or flow."
   }
}
# END proc click {winId node caption}
##################################################

##################################################
# proc display {winId time step remainder} 
proc display {winId time step remainder} {
   set status [GetState $winId]
   if {[string compare [lindex $status 0] displaying] == 0} {
      data::ReadData $winId [lindex $status 1] [lindex $status 3] [lindex $status 5] [lindex $status 7]
      graphics::calcViewParams
      graphics::draw $winId
   }
}
# END proc display {winId time step remainder} 
##################################################

# END AME specific code.
##################################################

#########################
# INITIALISATION
# version 0.0.9 - wrapped into a function for calling from AME
#########################

#########################
# proc Initialise3Doodle { winId xs ys hs }
proc Initialise3Doodle { winId xs ys cs hs } {
 set DEBUG 0

# TODO:
#   source "./3Doodle/data.tcl"
#   source "./3Doodle/graphics.tcl"
#   source "./3Doodle/window.tcl"
#   source "./3Doodle/debug.tcl"
#   source "./3Doodle/data.tcl"

   data::InitializeVariables
   graphics::InitializeVariables
   
   if { $DEBUG == 1 } {
      debug::InitDebugConsole $winId $DEBUG
   }

   window::InitialiseWidgets $winId

   # Draw the stuff.
   data::ReadData $winId $xs $ys $cs $hs
   graphics::calcViewParams
   graphics::draw $winId
}
# END proc Initialise3Dooodle { winId }
#########################


#########################
# namespace eval debug 
namespace eval debug {
 upvar myDebug myDebug
   #########################
   # proc InitDebugConsole { winId }
   proc InitDebugConsole { winId DEBUG } {
      #########################
      # DEBUG stuff
      # Create a frame and plonk a text widget init. Then direct all debug
      # output to this handy 'console'.
      # Hence, all debug output looks like $myDebug insert ......
      set topdebug ".debug[clock clicks]"
      toplevel $topdebug
      
       variable myDebug "$topdebug.text"
      text $myDebug -wrap none -yscrollcommand "$topdebug.v_scroll set" \
                     -xscrollcommand "$topdebug.h_scroll set" \
                     -width 100 -height 10

      scrollbar $topdebug.v_scroll -command "$myDebug yview"
      scrollbar $topdebug.h_scroll -orient horizontal \
                                      -command "$myDebug xview"
      pack $topdebug.v_scroll -side right -fill y -expand 1
      pack $topdebug.h_scroll -side bottom -fill x -expand 1
      pack $myDebug -side left -expand 1
      #########################
   }
   # END proc InitDebugConsole { winId }
   #########################
}
# namespace eval debug 
#########################

#########################
# namespace eval data
namespace eval data {
    
 upvar helperNamespace helperNamespace 
 upvar thdVersion thdVersion 
 upvar utilityNS utilityNS 
 upvar graphicsNS graphicsNS
 # These are needed outside this namespace
 # Used in graphics::
 upvar myDebug myDebug
 upvar a_ZValues a_ZValues
 upvar a_Id a_Id
 upvar a_rawColourData a_rawColourData
 upvar a_Colours a_Colours
 # Used in graphics::
 upvar xCols xCols      
 upvar yCols yCols      
 # Used in graphics::
 upvar xColsStart xColsStart
 upvar yColsStart yColsStart
 upvar xColsEnd xColsEnd
 upvar yColsEnd yColsEnd
 upvar f_lowColour f_lowColour
 upvar f_highColour f_highColour

 upvar quadlist quadlist
   
   #########################
   # proc data::InitializeVariables { }
   proc InitializeVariables { } {
    # Initialise these to impossible values, to ensure that they're set by the
    # first pass.
    variable f_minXInterval -1
    variable f_minYInterval -1
    # There aren't really any unreasonable values for these so just set 'em to
    # zero and use f_minXInterval f_minYInterval to decide if it's the first pass.
    variable f_minX 0
    variable f_minY 0

    variable minXCols 9
    variable minYCols 9
   }
   # END proc InitializeVariables { }
   #########################
   
   #########################
   # proc data::getMinXCols { }
   proc getMinXCols { } {
    variable minXCols
      return $minXCols
   }
   # END proc data::getMinXCols { }
   #########################

   #########################
   # proc data::getMinYCols { }
   proc getMinYCols { } {
    variable minYCols
      return $minYCols
   }
   # END proc data::getMinYCols { }
   #########################

   #########################
   # proc data::setMinXCols { minXC }
   proc setMinXCols { minXC } {
    variable minXCols
      set minXCols $minXC
   }
   # END proc data::setMinXCols { }
   #########################
   
   #########################
   # proc data::setMinYCols { minYC }
   proc setMinYCols { minYC } {
    variable minYCols
      set minYCols $minYC
   }
   # END proc data::setMinYCols { }
   #########################

   #########################
   # proc data::calcXYStep {winId xs ys cs hs}
   proc calcXYStep { } {
#   variable f_xStep
#   variable f_yStep
   variable f_minXInterval 
   variable f_minYInterval 
   variable minXCols 
   variable minYCols
      # f_xStep and f_yStep are constants.
      # TODO: Check for div by zero here!
      if { $minXCols != 0 } {
         variable f_xStep [expr $f_minXInterval/$minXCols]
      } else {
         variable f_xStep $f_minXInterval
      }
      if { $minYCols != 0 } {
         variable f_yStep [expr $f_minYInterval/$minYCols]
      } else {
         variable f_yStep $f_minYInterval
      }
   }
   # END proc data::calcXYStep { }
   #########################
   
   #########################
   # proc data::ReadData {winId xs ys cs hs}
   proc ReadData {winId xs ys cs hs} {
    # These are needed outside this namespace
    # Used in graphics::
    variable utilityNS
    variable graphicsNS
    variable a_ZValues
    variable a_Id
    variable a_rawColourData
    variable a_Colours
    # Used in graphics::
    variable xCols      
    variable yCols      
    # Used in graphics::
    variable xColsStart
    variable yColsStart
    variable xColsEnd
    variable yColsEnd
    #
    # data:: only
    variable f_lowX 
    variable f_highX
    variable f_lowY
    variable f_highY
    variable minXCols
    variable minYCols
    variable f_minXInterval
    variable f_minYInterval
    variable f_minX  
    variable f_minY  
    variable f_maxX  
    variable f_maxY  
    variable f_xStep
    variable f_yStep
    variable myDebug

    variable quadList
    
      if [info exists myDebug ] {
         $myDebug insert 1.0 "proc ReadData: winId $winId xs $xs ys $ys cs $cs hs $hs\n"
      }
      # GetQuadList fetches the data and pops it into a list, quadlist.
      # The order is { x y colour height }
      # Also, it keeps a record of low,high X,Y
      # Ver 0.0.98 : each $quad has a unique identifier tagged on the end. Can
      # be used to identify the data for AME feedback.
      GetQuadList $winId [lindex [GetModelValue $xs] 0] \
                        [lindex [GetModelValue $ys] 0] \
                        [lindex [GetModelValue $cs] 0] \
                        [lindex [GetModelValue $hs] 0]
      if [info exists myDebug ] {
         $myDebug insert 1.0 "proc ReadData: f_highX=$f_highX f_lowX=$f_lowX f_highY=$f_highY f_lowY=$f_lowY\n"
      }   

      set f_xInterval [ expr ($f_highX - $f_lowX) ]
      set f_yInterval [ expr ($f_highY - $f_lowY) ]
      if { $f_minXInterval == -1 } {
         # Then this is the first pass.
         set f_minXInterval $f_xInterval
         set f_minYInterval $f_yInterval
         set f_minX $f_lowX
         set f_minY $f_lowY
         set f_maxX $f_highX
         set f_maxY $f_highY
         calcXYStep
      } else {
         set f_minX [expr ($f_lowX<$f_minX)  ?  $f_lowX  :  $f_minX]
         set f_minY [expr ($f_lowY<$f_minY)  ?  $f_lowY  :  $f_minY]
         set f_maxX [expr ($f_highX>$f_maxX) ?  $f_highX :  $f_maxX]
         set f_maxY [expr ($f_highY>$f_maxY) ?  $f_highY :  $f_maxY]
      }
      if [info exists myDebug ] {
         $myDebug insert 1.0 "proc ReadData: f_maxX=$f_maxX f_minX=$f_minX f_maxY=$f_maxY f_minY=$f_minY\n"
      }   
      
      if { $f_xStep != 0 } {
         set xCols [${utilityNS}::format_floor [expr ($f_xInterval/$f_xStep)]]
         set xColsStart [${utilityNS}::format_floor [expr ($f_minX/$f_xStep)]]
         set xColsEnd [${utilityNS}::format_floor [expr ($f_maxX/$f_xStep)]]
      } else {
         # NB xColsStart and xColsEnd will be equal
         set xCols 1
         set xColsStart [${utilityNS}::format_floor $f_minX]
         set xColsEnd [${utilityNS}::format_floor $f_maxX]
      }
      
      if { $f_yStep != 0 } {
         set yCols [${utilityNS}::format_floor [expr ($f_yInterval/$f_yStep)]]
         set yColsStart [${utilityNS}::format_floor [expr ($f_minY/$f_yStep)]]
         set yColsEnd [${utilityNS}::format_floor [expr ($f_maxY/$f_yStep)]]
      } else {
         # NB yColsStart and yColsEnd will be equal
         set yCols 1
         set yColsStart [${utilityNS}::format_floor $f_minY]
         set yColsEnd [${utilityNS}::format_floor $f_maxY]
      }

      # Here we sort on y values, and lose the original ordering, which is a
      # problem later! :/ (for AME feedback)
      set sorted_quadlist [lsort -index 1 $quadlist]

      # initialise data arrays.
      for { set x $xColsStart } { $x <= $xColsEnd } { incr x } {
         for { set y $yColsStart } { $y <= $yColsEnd } { incr y } {
            set index "$x,$y"
            # set a_ZValues($index) 0.0
            set a_ZValues($index) {}
            set a_rawColourData($index) {}
            set a_Colours($index) {}
            set a_Id($index) {}
#            $myDebug insert 1.0 "ReadData init: index=$index\n"
         }
      }
      # END init loops

      # OK, now convert the data to something useful.
      # ie, Fill up the "raw data" arrays.
      # My data format is a 2D array, and also I have no concept of
      # real number xs and ys - because this is a grid square by definition.
      # So, first work out the extent of the x,y values, and spread them over a
      # reasonable sized grid.
      
      if { $f_xInterval != 0 } {
         # NB string compare returns 0 on success.
         for { set i 0 } { $i < [llength $sorted_quadlist] } { incr i } {
            # $myDebug insert 1.0 "Converting data\n"
            set quad [lindex $sorted_quadlist $i]
            set f_x [lindex $quad 0]
            set f_y [lindex $quad 1]
            set f_colour [lindex $quad 2]
            set f_height [lindex $quad 3]
            # 0.0.98 : This unique identifier used for AME feedback.
            set f_Id [lindex $quad 4]

            # OK, we've got the data (height) now plonk it in the right place in the
            # 2D array. First get xindex and yindex, then construct an index from
            # these.
            if { $f_xStep != 0 } {
               set xindex [${utilityNS}::format_floor [expr ($f_x/$f_xStep)]]
            } else {
               set xindex 0
            }
            if { $f_yStep != 0 } {
               set yindex [${utilityNS}::format_floor [expr ($f_y/$f_yStep)]]
            } else {
               set yindex 0
            }
            # OK, we should have INTEGER xindex, yindex.
            set index "$xindex,$yindex"

            set a_ZValues($index) [ lappend a_ZValues($index) $f_height ]

            set a_rawColourData($index) [ lappend a_rawColourData($index) $f_colour ]
            
            set a_Id($index) [ lappend a_Id($index) $f_Id ]
            
         }
         # END while {[string compare $quadlist ""]}
      }
      # END if { $f_xInterval != 0 }
   }
   # END proc ReadData {winId xs ys cs hs}
   #########################

   #########################
   # proc data::GetQuadList {Id xcoords ycoords colours heights}
   proc GetQuadList {Id xcoords ycoords colours heights} {
    variable f_lowX
    variable f_highX
    variable f_lowY
    variable f_highY
    variable f_lowColour
    variable f_highColour
    variable myDebug

    upvar 1 quadlist quadlist

# Do not do anything if this list is for an empty submodel --Jasper
       if {![llength $heights]} {
	   return
       }

      if {[llength $heights] == 1} {
         # Add a new value to the list.
         # Keep a record of min,max,X,Y
	  if {[info exists f_lowX]} {
	      if {[expr ($f_lowX>$xcoords)]} { set f_lowX $xcoords } 
	      if {[expr ($f_highX<$xcoords)]} { set f_highX $xcoords } 
	      if {[expr ($f_lowY>$ycoords)]} { set f_lowY $ycoords } 
	      if {[expr ($f_highY<$ycoords)]} { set f_highY $ycoords }
	      if {[expr ($f_lowColour>$colours)]} { set f_lowColour $colours } 
	      if {[expr ($f_highColour<$colours)]} { set f_highColour $colours }
	  } else {
	      set f_lowX [set f_highX $xcoords]
	      set f_lowY [set f_highY $ycoords]
	      set f_lowColour [set f_highColour $colours]
	  }

         # NB On recursive calls to this proc, Id is $elt (see below) allowing
         # us to uniquely identify this data sub-list.
         lappend quadlist [list $xcoords $ycoords $colours $heights $Id]
      } else {
#         set f_lowX [lindex $xcoords 1]
#         set f_highX [lindex $xcoords 1]
#         set f_lowY [lindex $ycoords 1]
#         set f_highY [lindex $ycoords 1]
#         set f_lowColour [lindex $colours 1]
#         set f_highColour [lindex $colours 1]
#         $myDebug insert 1.0 "proc GetQuadList: xcoords = $xcoords"
#         set f_lowX 0.0
#         set f_highX 0.0
#         set f_lowY 0.0
#         set f_highY 0.0
#         set f_lowColour 0.0
#         set f_highColour 0.0
         array set newxs $xcoords
         array set newys $ycoords
         array set newcs $colours
         array set newhs $heights

#         $myDebug insert 1.0 "proc GetQuadList: newhs = [array get newhs]"
         foreach elt [array names newhs] {
            GetQuadList $elt $newxs($elt) $newys($elt) $newcs($elt) $newhs($elt)
         }
      }
   }
   # END  proc GetQuadList {Id xcoords ycoords colours heights}
   #########################
}
# END namespace eval data
#########################


#########################
# namespace eval graphics
namespace eval graphics {
 upvar helperNamespace helperNamespace 
 upvar thdVersion thdVersion 
 upvar utilityNS utilityNS 
 upvar windowNS windowNS 
 upvar dataNS dataNS 
 # These are needed outside this namespace
 upvar myCanvas myCanvas
 upvar myDebug myDebug
 upvar b_columns b_columns 
 upvar b_backFaces b_backFaces 
 upvar i_canWidth i_canWidth
 upvar i_canHeight i_canHeight
 # Used in data::
 upvar a_ZValues a_ZValues
 upvar a_Id a_Id
 upvar a_rawColourData a_rawColourData
 upvar a_Colours a_Colours
 # Used in data::
 upvar xCols xCols      
 upvar yCols yCols      
 # Used in data::
 upvar xColsStart xColsStart
 upvar yColsStart yColsStart
 upvar xColsEnd xColsEnd
 upvar yColsEnd yColsEnd
 # Colour selection thingys
 upvar f_lowColour f_lowColour
 upvar f_highColour f_highColour
 # Proly not needed outside this ns
 upvar a_colourSpecs a_colourSpecs
 upvar colourMethod colourMethod
 upvar code_columnsDialog code_columnsDialog
 upvar code_setNewColumns code_setNewColumns 
 upvar code_colourDialog code_colourDialog
 upvar code_setNewColours code_setNewColours 
 upvar code_adjustValuesDialog code_adjustValuesDialog 

   ##################################################
   # Drawing code.

   #########################
   # proc graphics::InitializeVariables { }
   proc InitializeVariables { } {
    variable code_columnsDialog [namespace code {columnsDialog}]
    variable code_setNewColumns [namespace code {setNewColumns}]
    variable code_colourDialog [namespace code {colourDialog}]
    variable code_setNewColours [namespace code {setNewColours}]
    variable code_adjustValuesDialog [namespace code { adjustValuesDialog }]
    variable code_setNewValues [namespace code { setNewValues }]
    # As usual, 0,0 is screen top left.
    variable i_canWidth 500
    variable i_canHeight 400
    # The screen 'origin' ie where the  central point be drawn w. 0
    #    rotation.
    variable d_screenXOrigin [expr $i_canWidth / 2.0 ]
    variable d_screenYOrigin [expr $i_canHeight * 0.6 ]
    # We need scaling for screen X,Y mappings.
    # version 0.0.4 : The new globals controlling screen mapping should be
    # set and calcViewParams called.
    # These default values give an isometric view not unlike SC2000
    variable viewpoint 0
    variable d_XScaleBodge 1
    variable d_zoomScale 20
    variable d_zoomValue $d_zoomScale
    variable d_vertRotn 0.5
    variable d_horzRotn 0.5
    variable horRot $d_horzRotn
    variable d_zScale 0.75
    variable b_columns 1
    variable b_rotate 0
    variable b_backFaces 0
    # Init for colour selection
    variable a_colourSpecs
    set a_colourSpecs(grey) 0.79
    set a_colourSpecs(red) 0.87
    set a_colourSpecs(orange) 0.95
    set a_colourSpecs(yellow) 1.02
    set a_colourSpecs(green) 1.10
    set a_colourSpecs(blue) 1.30
    variable colourMethod "RANGE"
   }
   # END proc graphics::InitializeVariables { }
   #########################
   
   ##################################################
   # graphics::setUpVertex : Screen coordinate calculation.
   # This uses the '2D array' of Z values and grid x,y to set
   # the screen coords x,y
   # This was my first attempt at a proc, so I'm sure the value passing is a
   # bit messy. Basically, I've tried to avoid the use of 'global's
   #
   # As of version 0.0.5, the z value is passed as an argument.
   proc setUpVertex { winId grid_x grid_y grid_z screen_x screen_y } {
    # NB The variable names here are eg
    # d_XscreenYScale = array-X, screen-Y offset, scale
    variable d_XscreenXScale 
    variable d_XscreenYScale 
    variable d_YscreenXScale 
    variable d_YscreenYScale 
    variable d_screenZScale 
    variable d_screenXOrigin 
    variable d_screenYOrigin 
    variable d_XScaleBodge
    variable d_gridMidX 
    variable d_gridMidY 
    set x $grid_x 
    set y $grid_y 
    set z $grid_z 
    upvar $screen_x d_xCoord
    upvar $screen_y d_yCoord
      set x [expr $x - $d_gridMidX ]
      set y [expr $y - $d_gridMidX ]
      ############################################################
      # Setup the quad coords
      set d_xCoord [expr (( ($x * $d_XscreenXScale) - ($y * $d_YscreenXScale) ) \
                  * $d_XScaleBodge ) + $d_screenXOrigin ]
      # TODO: Height auto-scaling can be achieved by checking that every ($z *
      # $d_screenZScale ) < screenHeight.
      # This has to be done before we get this far, of course.
      # Maybe extract all z's, sort, calc on biggest.
      #
      set d_yCoord [expr $d_screenYOrigin \
         - (( ($x * $d_XscreenYScale) + ($y * $d_YscreenYScale) ) \
                  + ( $z * $d_screenZScale ))]
   } 
   # END proc setUpVertex { winId grid_x grid_y grid_z screen_x screen_y }
   #########################

   #########################
   # graphics::drawPoly 
   # Basically, given a display list, draw 'em.
   proc drawPoly { winId l_quadDisplay  } {
    variable myCanvas 
    variable myDebug 
    upvar $l_quadDisplay l_qDisp
      # foreach poly $l_qDisp 
      for { set index [expr [llength $l_qDisp] - 1] } { $index>=0 } { incr index -1 } {
         # VERY irritatingly, this doesn't work...
         #$myCanvas create polygon $poly -fill green -outline black
         # ... which means I have to resort to this mess...
         # (which BTW is a bitch to debug)
         # This code creates variables called x0,y0,x1,x2...etc and
         # extracts values from the list $poly
         set poly [lindex $l_qDisp $index]
         for { set i 0 } { $i < 4 } { incr i } {
            set varName [format "x%s" $i]
            set ${varName} [lindex $poly [expr 2*$i] ]
            
            set varName [format "y%s" $i]
            set ${varName} [lindex $poly [expr (2*$i)+1] ]
         }
         set quadColour [lindex $poly 8 ]
         set taglist [concat [lindex $poly 9]]
         set polyId [$myCanvas create polygon $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 \
                        -fill $quadColour -outline black -width 1]
#         $myDebug insert 1.0 "Adding taglist [lindex $poly 9]\n"
         foreach tag $taglist {
            $myCanvas addtag $tag withtag $polyId 
#            $myDebug insert 1.0 "Adding tag $tag\n"
         }
      }
      # END foreach poly $l_qDisp
   }
   # END proc drawPoly { l_quadDisplay  }
   #########################

   #########################
   # proc graphics::setupDataTraversal { }
   # NB call this with value of last index
   proc setupDataTraversal { xCols yCols } {
    variable viewpoint
    variable lx_start
    variable lx_end
    variable lx_incr
    variable ly_start
    variable ly_end
    variable ly_incr
    variable xColsStart
    variable yColsStart
    variable xColsEnd
    variable yColsEnd
      # version 0.0.5: New stuff for various viewpoints
      # This code sets the start, end and increment for array traversal.
      switch $viewpoint {
         0 {   
         set lx_start $xColsStart
         set lx_end $xColsEnd
         set lx_incr 1
         set ly_start $yColsStart
         set ly_end $yColsEnd
         set ly_incr 1 }
         1 {   
         set lx_start $xColsEnd
         set lx_end $xColsStart
         set lx_incr -1
         set ly_start $yColsStart
         set ly_end $yColsEnd
         set ly_incr 1 }
         2 {   
         set lx_start $xColsEnd
         set lx_end $xColsStart
         set lx_incr -1
         set ly_start $yColsEnd
         set ly_end $yColsStart
         set ly_incr -1 }
         3 {   
         set lx_start $xColsStart
         set lx_end $xColsEnd
         set lx_incr 1
         set ly_start $yColsEnd
         set ly_end $yColsStart
         set ly_incr -1 }
      }
      # END switch $viewpoint
   }
   # proc graphics::setupDataTraversal { xCols yCols }
   #########################

   proc ColourAutoRange { } {
    variable f_lowColour
    variable f_highColour
    variable a_colourSpecs
    
      set f_colourRange [ expr $f_highColour - $f_lowColour ]
      set a_colourSpecs(grey) $f_lowColour
      set f_colourStep [ expr $f_colourRange / 5 ]
      set a_colourSpecs(red) [ expr $a_colourSpecs(grey) + $f_colourStep ]
      set a_colourSpecs(orange) [ expr $a_colourSpecs(red) + $f_colourStep ]
      set a_colourSpecs(yellow) [ expr $a_colourSpecs(orange) + $f_colourStep ]
      set a_colourSpecs(green) [ expr $a_colourSpecs(yellow) + $f_colourStep ]
      set a_colourSpecs(blue) [ expr $a_colourSpecs(green) + $f_colourStep ]
   }
   #########################
   # graphics::buildDisplayList:
   # version 0.0.9: The list of lists that was previously used to hold the data has
   # been replaced with an array. This is neater and more easily manipullated in
   # anger 8)
   proc buildDisplayList { winId x_length y_length l_display } {
    upvar $l_display link_display 
    #
    variable a_ZValues
    variable a_Colours
    variable a_rawColourData
    #
    variable d_gridMidX 
    variable d_gridMidY 
    #
    variable b_columns
    variable b_backFaces
    #
    variable lx_start
    variable lx_end
    variable lx_incr
    #
    variable ly_start
    variable ly_end
    variable ly_incr
    #
    variable myDebug
    variable utilityNS
    

      # New in version 0.0.5: calc the centre for improved rotation.
      # TODO: tighten this, its still a bit wobbly on view shift.
      if { $b_columns == 0 } then {
         # Continuous surface
         set d_gridMidX [ expr $x_length / 2 ]
         set d_gridMidY [ expr $y_length / 2 ]
      } else {
         # '3d bar graph' aka 'columns'
         set d_gridMidX [ expr ($x_length + 1) / 2 ]
         set d_gridMidY [ expr ($y_length + 1) / 2 ]
         # We need to 'walk further towards the end' if it's columns.
         incr lx_end $lx_incr
         incr ly_end $ly_incr
#         if { b_colourAutoRange } {
            ColourAutoRange
#         }
      }
      
      
      for { set lx $lx_start; set x_count 0 } { $lx != $lx_end } {
         incr lx $lx_incr; incr x_count } {
         for { set ly $ly_start; set y_count 0 } { 
            $ly != $ly_end } { 
            incr ly $ly_incr } {

            # Take a copy so we don't mess up the loops
            set x $lx
            set y $ly
            
            # the z_array stuff below is to store the z values for use in colour
            # calculation etc.
            if { $b_columns == 0 } then {
               ############################################################
               # SURFACE display.
               
               setUpSurfaceVertices $winId x y x_count y_count link_display

            } else {
               ############################################################
               # COLUMNS display.

               setUpColumnsVertices $winId x y x_count y_count link_display 0 0

            }
            # END if { $b_columns == 0 } then .. else

         }
         # END for { set ly 0 }
      }
      # END for { set lx 0 } 
   }
   # END proc graphics::buildDisplayList { l_display } 
   #########################

   #########################
   proc setUpSurfaceVertices { winId upX upY upX_count upY_count l_display } {
    upvar $upX x 
    upvar $upY y
    upvar $upX_count x_count
    upvar $upY_count y_count
    upvar $l_display link_display 
    variable a_ZValues
    variable lx_incr
    variable ly_incr
    variable myDebug

      ############################################################
      # For each of the 4 vertices of the quad, call setUpVertex
      # Extract the currently interesting z value
      set first "$x,$y"
      setUpVertex $winId $x_count $y_count $a_ZValues($first) d_x1 d_y1
      setUpVertex $winId $x_count $y_count 0  d_x1z0 d_y1z0
      #
      incr x $lx_incr;incr x_count
      set second "$x,$y"
      setUpVertex $winId $x_count $y_count $a_ZValues($second) d_x2 d_y2
      setUpVertex $winId $x_count $y_count 0  d_x2z0 d_y2z0
      #
      incr y $ly_incr; incr y_count
      set third "$x,$y"
      setUpVertex $winId $x_count $y_count $a_ZValues($third) d_x3 d_y3
      setUpVertex $winId $x_count $y_count 0  d_x3z0 d_y3z0
      #
      incr x [expr -1 * $lx_incr]; incr x_count -1
      set fourth "$x,$y"
      setUpVertex $winId $x_count $y_count $a_ZValues($fourth) d_x4 d_y4
      setUpVertex $winId $x_count $y_count 0  d_x4z0 d_y4z0

      # OK, some bollocks to guess a reasonable colour.
      # Basically I want to make tiles facing (0,0) lighter than
      # those which are facing away from (0,0), with flat ones
      # somewhere in the middle. So, I just take the opposite
      # corners and depending on which ones higher I choose a
      # colour. This is a real cheap effect.
      # Works OK, I'd like to improve the colours though.
      if { $lx_incr == $ly_incr } then {
         if { [expr $a_ZValues($first) * $lx_incr] < \
            [expr $a_ZValues($third) * $lx_incr] } then {
            set quadColour green
         } elseif { [expr $a_ZValues($first) * $lx_incr] > \
            [expr $a_ZValues($third) * $lx_incr] } then {
            set quadColour "\#00a000"
         } else {
            set quadColour limegreen
         }
      } else {
         if { [expr $a_ZValues($second) * $ly_incr] < \
            [expr $a_ZValues($fourth) * $ly_incr] } then {
            set quadColour green
         } elseif { [expr $a_ZValues($second) * $ly_incr] > \
            [expr $a_ZValues($fourth) * $ly_incr] } then {
            set quadColour "\#00a000"
         } else {
            set quadColour limegreen
         }
      }        
      # END ...guess a reasonable colour.
      
      # Plonk this new quad into the display list.
      # Surface
      set link_display [ lappend link_display \
         "$d_x1 $d_y1 $d_x2 $d_y2 $d_x3 $d_y3 $d_x4 $d_y4 $quadColour {$first surfaceQuad}" ] 
      # Floor
      set link_display [ lappend link_display \
         "$d_x1z0 $d_y1z0 $d_x2z0 $d_y2z0 $d_x3z0 $d_y3z0 $d_x4z0 $d_y4z0 grey {$first floor}" ] 
   }
   
   proc setUpColumnsVertices { winId upX upY upX_count upY_count l_display stack_index prevHeight } {
    upvar $upX x 
    upvar $upY y
    upvar $upX_count x_count
    upvar $upY_count y_count
    upvar $l_display link_display 
    variable a_ZValues
    variable a_Colours
    variable a_rawColourData
    variable lx_incr
    variable ly_incr
    variable b_backFaces
    variable myDebug
      if [info exists myDebug ] {
         $myDebug insert 1.0 "In setUpColumnsVertices x=$x y=$y stack_index=$stack_index \n"
      }   
      ############################################################
      # COLUMNS display.
      ############################################################
      # Use a single Z value for the Quad. Also calculate the 'walls' of 
      # the column, these are the d_*z0 values. 
      set first "$x,$y"
      set stack_top [expr [llength $a_ZValues($first)] -1 ]
         
      set startX $x
      set startY $y
      set startXCount $x_count
      set startYCount $y_count
      
      set z [lindex $a_ZValues($first) $stack_index]
      # Next line is necessary to draw floor.
      if { $z == "" } { set z 0.0 }

      selectColour [lindex $a_rawColourData($first) $stack_index] $first
       
      set quadColour $a_Colours($first)
      
      if { ($quadColour == "black") || ($quadColour == "white") } {
         set dark ""
         set vdark ""
      } else {
         set dark 3
         set vdark 4
      }
      #
      setUpVertex $winId $x_count $y_count $z d_x1   d_y1
      setUpVertex $winId $x_count $y_count 0  d_x1z0 d_y1z0
      #
      incr x $lx_incr;incr x_count
      setUpVertex $winId $x_count $y_count $z d_x2 d_y2
      setUpVertex $winId $x_count $y_count 0  d_x2z0 d_y2z0
      #
      incr y $ly_incr; incr y_count
      setUpVertex $winId $x_count $y_count $z d_x3 d_y3
      setUpVertex $winId $x_count $y_count 0  d_x3z0 d_y3z0
      #
      incr x [expr -1 * $lx_incr]; incr x_count -1
      setUpVertex $winId $x_count $y_count $z d_x4 d_y4
      setUpVertex $winId $x_count $y_count 0  d_x4z0 d_y4z0

      # Next line used if columns stack.
      set this_prevHeight [ expr $d_y1z0 - $d_y1 ]

      # If this column is to be stacked, offset it upwards.
      if { $stack_index > 0 } {
         set d_y1 [ expr $d_y1 - $prevHeight ]
         set d_y2 [ expr $d_y2 - $prevHeight ]
         set d_y3 [ expr $d_y3 - $prevHeight ]
         set d_y4 [ expr $d_y4 - $prevHeight ]
         set d_y1z0 [ expr $d_y1z0 - $prevHeight ]
         set d_y2z0 [ expr $d_y2z0 - $prevHeight ]
         set d_y3z0 [ expr $d_y3z0 - $prevHeight ]
         set d_y4z0 [ expr $d_y4z0 - $prevHeight ]
      }
       
      # ##############
      # Recurse here - with View from Top, must draw bottom before top.
      # TODO : Vice-versa with view from bottom.
      if { $stack_index < $stack_top } { 
         setUpColumnsVertices \
            $winId startX startY startXCount startYCount \
            link_display [incr stack_index] $this_prevHeight
      }
      # End Recursion
      # ##############
      
      # Draw a column
      #
      # Front sides
      # Version 0.0.95 - ensure that the sides need to be drawn,
      if { $d_y2 != $d_y2z0 } {
         set link_display [ lappend link_display \
            "$d_x1 $d_y1 $d_x2 $d_y2 $d_x2z0 $d_y2z0 $d_x1z0 $d_y1z0 \
            ${quadColour}${dark} {side $first}" ] 
      }
      if { $d_y2 != $d_y2z0 } {
         set link_display [ lappend link_display \
            "$d_x1 $d_y1 $d_x4 $d_y4 $d_x4z0 $d_y4z0 $d_x1z0 $d_y1z0 \
            ${quadColour}${dark} {side $first}" ] 
      }
      # "Top"
      set link_display [ lappend link_display \
         "$d_x1 $d_y1 $d_x2 $d_y2 $d_x3 $d_y3 $d_x4 $d_y4 \
         ${quadColour} {top $first}" ] 
      
      # Back Sides. These need to be drawn if there are substantial
      # negative value columns, for that hollow look you'll like 8l
      if { $b_backFaces } {
         set link_display [ lappend link_display \
            "$d_x3 $d_y3 $d_x2 $d_y2 $d_x2z0 $d_y2z0 $d_x3z0 $d_y3z0 \
            ${quadColour}${vdark} {side $first}" ] 
         
         set link_display [ lappend link_display \
            "$d_x4 $d_y4 $d_x3 $d_y3 $d_x3z0 $d_y3z0 $d_x4z0 $d_y4z0 \
            ${quadColour}${vdark} {side $first}" ] 
      }
      # END if { $b_backFaces }

      # END for { i=0 } { i < [llength $a_ZValues($first) } { incr i }
   }
   # END proc graphics::setUpColumnsVertices
   #########################
   
   #########################
   # proc graphics::draw : All the drawing stuff bundled
   proc draw { winId } {
    variable xCols
    variable yCols
    variable lx_start
    variable lx_end
    variable lx_incr
    variable ly_start
    variable ly_end
    variable ly_incr
    variable myCanvas 
    variable utilityNS
    variable windowNS

      # Tell user what's happening
       ${windowNS}::setDrawingStatus TRUE $winId
   
      # clear
      $myCanvas delete all

      #########################
      # We'll need a display list of quads, so init it here.
      # TODO: This may be a really nasty way to do this, check it out. Mibbe use
      # the upvar trick demonstrated in GetQuadList ?
      set l_quadDisplayList {}

      # Set the start, end and increment for array traversal.
      setupDataTraversal [expr $xCols-1] [expr $yCols-1] 
      #$x_length $y_length
      
      # Given the array of Zs, calc the displayList
      buildDisplayList $winId $xCols $yCols l_quadDisplayList 

      # Well, with any luck we've translated the z coords to screen coords.
      # Now, draw them.
      drawPoly $winId l_quadDisplayList 

      # Tell user what's happening
      ${windowNS}::setDrawingStatus FALSE $winId
   }
   # END proc draw
   #########################


   #########################
   # proc graphics::spin {} 
   proc spin { winId } {
    variable b_rotate
    variable d_horzRotn
    variable windowNS
      set rotation $d_horzRotn

      if { [set b_rotate [expr !$b_rotate]] } {
         ${windowNS}::setRotateStatus TRUE $winId
      } else {
         ${windowNS}::setRotateStatus FALSE $winId
      }

      while { $b_rotate == 1 } {
         #set rotation [expr $rotation + 0.1]
         HRotate LEFT $winId
         #if { $rotation > 1 } then { set rotation [expr $rotation - 1] }
         update
      }
   }
   # END proc spin {} 
   #########################

   #########################
   # proc graphics::columnsToggle
   proc columnsToggle { winId } {
    variable b_columns
    variable windowNS
      if { $b_columns == 0 } then {
         set b_columns 1
         # Tell user what's happening.
         ${windowNS}::setViewStatus COLS $winId
      } else {
         set b_columns 0
         # Tell user what's happening.
         ${windowNS}::setViewStatus SURFACE $winId
      }
      draw $winId 
   }
   # END proc columnsToggle
   #########################

   #########################
   # proc graphics::heightButton { upDown winId }
   proc heightButton { upDown winId } {
    variable d_zScale
    variable myDebug
      if [info exists myDebug ] {
         $myDebug insert 1.0 "in zoomButton\n"
      }   
      switch $upDown {
      "UP" {
         set d_zScale [expr $d_zScale * 2]
         }
      "DOWN" {
         set d_zScale [expr $d_zScale / 2]
         }
      }
      # END switch $upDown
      calcViewParams
      draw $winId
   }
   #########################

   #########################
   # proc graphics::ZScale { winId value }
   proc ZScale { winId value } {
    variable d_zScale
      set d_zScale $value
      calcViewParams
      draw $winId
   }
   #########################

   #########################
   # proc graphics::zoomButton { inOut winId } 
   proc zoomButton { inOut winId } {
    variable d_zoomValue 
    # Use d_zoomScale when resizing window! Cool.
    variable d_zoomScale
    variable myDebug
      if [info exists myDebug ] {
         $myDebug insert 1.0 "in zoomButton\n"
      }   
      switch $inOut {
      "IN" {
         set d_zoomValue [expr 1.25 * $d_zoomValue ] 
         }
      "OUT" {
         set d_zoomValue [expr 0.8 * $d_zoomValue ] 
         }
      }
      # END switch $inOut
      calcViewParams
      draw $winId
   }
   #########################

   #########################
   # proc graphics::zoom { winId value } 
   proc zoom { winId value } {
    variable d_zoomValue 
    variable d_zoomScale
      set d_zoomValue [expr $value * $d_zoomScale ]
      calcViewParams
      draw $winId
   }
   #########################

   #########################
   # proc graphics::toggleBackFaces { winId } 
   proc toggleBackFaces { winId } {
    variable myDebug
    variable b_backFaces 
    variable windowNS
      
      if { [set b_backFaces [expr !$b_backFaces]] } {
         if [info exists myDebug ] {
            $myDebug insert 1.0 "b_backFaces = $b_backFaces\n"
         }   
         ${windowNS}::setBackFacesState TRUE $winId
      } else {
         if [info exists myDebug ] {
            $myDebug insert 1.0 "b_backFaces = $b_backFaces\n"
         }   
         ${windowNS}::setBackFacesState FALSE $winId
      }
      # END if { [set b_backFaces [expr !$b_backFaces]] }
      
      calcViewParams
      draw $winId
   }
   #########################

   #########################
   # proc graphics::calcViewParams 
   # After a scale or rotation this should be called to recalc the screen mapping
   # variables.
   proc calcViewParams {} {
    # All these are graphics:: only
    variable d_XscreenXScale 
    variable d_YscreenXScale 
    variable d_XscreenYScale 
    variable d_YscreenYScale 
    variable d_screenZScale
    variable d_zScale
    variable d_zoomValue  
    variable d_vertRotn
    variable d_horzRotn
    variable viewpoint 
    variable d_XScaleBodge

      set d_XscreenYScale [ expr $d_horzRotn * $d_vertRotn * $d_zoomValue ]
      set d_YscreenYScale [ expr ( 1 - ($d_horzRotn*$d_horzRotn) ) \
                     * $d_vertRotn * $d_zoomValue ]
      set d_YscreenXScale [ expr $d_horzRotn * $d_zoomValue ]
      set d_XscreenXScale [ expr ( 1 - ($d_horzRotn*$d_horzRotn) ) \
                     * $d_zoomValue ]
      set d_screenZScale [ expr ( 1 - ($d_vertRotn * $d_vertRotn) ) \
                     * $d_zoomValue * $d_zScale ]
      if { [ expr $viewpoint % 2 ] == 1 } then {
         set d_XScaleBodge -1
      } else {
         set d_XScaleBodge 1
      }
   }
   # END proc graphics::calcViewParams 
   #########################

   #########################
   # proc graphics::VRotate { increment }
   # Rewritten for the scale widget .
   # increment should vary between 0 and 1
   # This implements a "camera rotating in the vertical" effect by imply
   # changing the Z offset. Cheap and effective. 
   # Version 0.0.4 : Substantially changed to use the new globals for
   # screen calcn.
   # Globals controlling the view are d_zoomValue, d_vertRotn, d_horzRotn
   proc VRotate { dirn winId } {
    variable d_vertRotn 
    variable myDebug


      if [info exists myDebug ] {
         $myDebug insert 1.0 "in VRotate, d_vertRotn = $d_vertRotn\n"
         $myDebug insert 1.0 "in VRotate, abs(d_vertRotn) = [expr abs($d_vertRotn)]\n"
      }   

      # Limit d_vertRotn to [-1,+1]
      if { ([expr abs($d_vertRotn)] <= 1.0) } {
         switch $dirn {
         UP {
               set d_vertRotn [expr $d_vertRotn-0.1]
               if { $d_vertRotn < -1.0 } { set d_vertRotn -1.0 }
            }
         DOWN {
               set d_vertRotn [expr $d_vertRotn+0.1]
               if { $d_vertRotn > 1.0 } { set d_vertRotn 1.0 }
            }
         }
         # END switch $dirn

         calcViewParams 
         draw $winId
      }
      # END if { [expr abs(d_vertRotn)<1] }

   }
   # END proc graphics::VRotate { value }
   #########################
   
   #########################
   # proc graphics::HRotate { dirn winId }
   proc HRotate { dirn winId } {
    variable d_horzRotn 
    variable viewpoint
    variable horRot 
    variable myDebug
      if [info exists myDebug ] {
         $myDebug insert 1.0 "in HRotate\n"
      }   


      switch $dirn {
      LEFT {
            set horRot [expr $horRot-0.1]
         }
      RIGHT {
            set horRot [expr $horRot+0.1]
         }
      }
      # switch $dirn
      
      set value $horRot
      set viewSwitch 0
      
      if { $value > 1 } then {
         # Anti-c.w.
         set viewpoint [expr (($viewpoint+4)-1) % 4 ]
         set viewSwitch 1
         set value [expr $value - 1 ]
      } elseif { $value < 0 } then {
         # c.w.
         set viewpoint [expr ($viewpoint+1) % 4 ]
         set viewSwitch 1
         set value [expr $value + 1 ]
      } 
      # END if { $value > 1 }
      
      if { $viewSwitch } then {
         set horRot $value
         if [info exists myDebug ] {
            $myDebug insert 1.0 "viewSwitch detected\n"
         }   
      }
      # END if { viewSwitch } 

      switch $viewpoint {
         0 -
         2 {
            set d_horzRotn $value
         }
         1 -
         3 {
            set d_horzRotn [expr 1 - $value ]
         }
         default { 
            if [info exists myDebug ] { $myDebug insert 1.0 "ERROR in switch proc HRotate\n" }
            }   
      }
      # END switch $viewpoint 

      calcViewParams 
      draw $winId

      if [info exists myDebug ] {
         $myDebug insert 1.0 "viewpoint=$viewpoint, d_horzRotn=$d_horzRotn \n \
                           value=$value horRot=$horRot\n"
      }                     

   }
   # END proc graphics::HRotate { dirn winId }
   #########################

   #########################
   # proc graphics::adjustValuesDialog
   proc adjustValuesDialog { index winId } {
    variable a_rawColourData
    variable a_ZValues
    variable code_setNewValues
      # (Try to) Be careful about toplevel widget names.
      set adjD ".adjD[clock clicks]"
      toplevel $adjD -class Dialog
      wm protocol $adjD WM_DELETE_WINDOW "destroy $adjD"
      wm title $adjD "Adjust Values"
      # Plonk it in the middle of the screen
      set width [winfo screenwidth .]
      set height [winfo screenheight .]
      set x [expr ($width/2) - 100]
      set y [expr ($height/2) - 100]
      wm geometry $adjD +$x+$y
      # Create
      label $adjD.colourLabel -text "Colour" -anchor w
      label $adjD.heightLabel -text "Height" -anchor w

      entry $adjD.colourEntry
      entry $adjD.heightEntry
      # Position
      grid config $adjD.colourLabel -column 0 -row 0 -sticky "w" -pady 8
      grid config $adjD.heightLabel -column 0 -row 1 -sticky "w" -pady 8

      grid config $adjD.colourEntry -column 1 -row 0 -sticky "nsew" -pady 8
      grid config $adjD.heightEntry -column 1 -row 1 -sticky "nsew" -pady 8
      # Display Data
      $adjD.colourEntry insert 0 $a_rawColourData($index)
      $adjD.heightEntry insert 0 $a_ZValues($index)

      set buts "$adjD.buts"
      frame $buts -bd 2
      button $buts.btn_OK -text "OK" -command "eval $code_setNewValues $index $winId $adjD"
      button $buts.btn_Cancel -text "Cancel" -command "destroy $adjD"
      pack $buts.btn_OK -side top -fill x
      pack $buts.btn_Cancel -side top -fill x -pady 6

      grid config $buts -column 3 -row 0 -padx 8 -pady 8 -rowspan 3

   }
   # END proc graphics::adjustValuesDialog
   #########################

   #########################
   # proc graphics::setNewValues { index winId colD }
   # This tricky function is buggy. TODO!!!
   # NB a_Id is a hash table, keys are index values (of the form $x,$y )
   # Every element in a_Id is a list of unique identifiers for the instances
   # positioned on this column. Usually only one, but can be many.
   proc setNewValues { index winId colD } {
    variable a_rawColourData
    variable a_ZValues
    variable a_Id
    variable myDebug
      # Id is used to uniquely identify this column
      # NB it's a list - can be many instances positioned on this column
      set Id $a_Id($index)
      # fetch values from edit boxes into arrays here in the helper
      set a_rawColourData($index) [$colD.colourEntry get]
      set a_ZValues($index) [$colD.heightEntry get]

      # This fetches the list of data identifiers
      set state [GetState $winId]
      # TODO: shouldn't use constant, but should work for now
      # List number 5 is colours
      set cs [lindex $state 5]
      # List number 7 is heights
      set hs [lindex $state 7]
      if [info exists myDebug ] {
         $myDebug insert 1.0 "proc setNewValues: cs = $cs\n"
         $myDebug insert 1.0 "proc setNewValues: hs = $hs\n"
         $myDebug insert 1.0 "proc setNewValues: GetModelValue cs = [GetModelValue $cs]\n"
         $myDebug insert 1.0 "proc setNewValues: GetModelValue hs = [GetModelValue $hs]\n"
      }   
      
      # Fetch the data as lists
      set colours [lindex [GetModelValue $cs] 0]
      set heights [lindex [GetModelValue $hs] 0]

      if [info exists myDebug ] {
         $myDebug insert 1.0 "proc setNewValues: colours = $colours\n"
         $myDebug insert 1.0 "proc setNewValues: heights = $heights\n"
      }   

      # take copies
      array set a_newCs $colours
      array set a_newZs $heights

      if [info exists myDebug ] {
         $myDebug insert 1.0 "proc setNewValues: llength $Id = [llength $Id]\n"
         $myDebug insert 1.0 "proc setNewValues: lindex Id i =[lindex $Id 0] \n" 
      }   
      # Effectively, "for each instance positioned on this column,
      #                 set corresponing elements"
      for { set i 0 } { $i < [llength $Id] } { incr i } {
         set a_newCs([lindex $Id $i]) [lindex $a_rawColourData($index) $i]
         set a_newZs([lindex $Id $i]) [lindex $a_ZValues($index) $i]
      }

      # copy back - why am i doing this? A mystery!
      set colours [array get a_newCs]
      set heights [array get a_newZs]
      
      if [info exists myDebug ] {
         $myDebug insert 1.0 "proc setNewValues: colours = $colours\n"
         $myDebug insert 1.0 "proc setNewValues: heights = $heights\n"
      }   

      # Now pass the values to AME
      SetModelValue $cs $colours
      SetModelValue $hs $heights

      destroy $colD
      calcViewParams
      draw $winId
   }
   # END proc graphics::setNewValues { index winId colD }
   #########################
 
   #########################
   # proc graphics::columnsDialog
   proc columnsDialog { winId } {
    variable dataNS
    variable code_setNewColumns 
      # Be careful about toplevel widget names.
      set colD ".colD[clock clicks]"
      # [namespace tail]"
      toplevel $colD -class Dialog
      wm protocol $colD WM_DELETE_WINDOW "destroy $colD"
      # TODO:Hide it # wm withdraw $colD
      # TODO:Make it pretty
      # wm transient $colD $winId
      set buts "$colD.buts"
      wm title $colD "Adjust number of Columns"
      # Plonk it in the middle of the screen
      set width [winfo screenwidth .]
      set height [winfo screenheight .]
      set x [expr ($width/2) - 100]
      set y [expr ($height/2) - 100]
      wm geometry $colD +$x+$y

      label $colD.xColsLabel -text "xCols" -anchor w
      label $colD.yColsLabel -text "yCols" -anchor w

      entry $colD.xColsEntry
      entry $colD.yColsEntry
      
      grid config $colD.xColsLabel -column 0 -row 0 -sticky "w"
      grid config $colD.yColsLabel -column 0 -row 1 -sticky "w"

      grid config $colD.xColsEntry -column 1 -row 0 -sticky "w"
      grid config $colD.yColsEntry -column 1 -row 1 -sticky "w"

      set minX [${dataNS}::getMinXCols]
      set minY [${dataNS}::getMinYCols]
      
      $colD.xColsEntry insert 0 $minX
      $colD.yColsEntry insert 0 $minY

      frame $buts -bd 2
      button $buts.btn_OK -text "OK" -command "eval $code_setNewColumns $winId $colD"
      button $buts.btn_Cancel -text "Cancel" -command "destroy $colD"
      pack $buts.btn_OK -side top -fill x
      pack $buts.btn_Cancel -side top -fill x -pady 6

      grid config $buts -column 2 -row 0 -padx 8 -pady 8 -rowspan 2
   }
   # END proc graphics::columnsDialog
   #########################

   #########################
   # proc graphics::colourDialog
   proc colourDialog { winId } {
    variable code_setNewColours 
    variable a_colourSpecs
    variable colourMethod
    #variable colourM
      # Be careful about toplevel widget names.
      set colD ".colD[clock clicks]"
      # [namespace tail]"
      toplevel $colD -class Dialog
      wm protocol $colD WM_DELETE_WINDOW "destroy $colD"
      # TODO:Hide it
      # wm withdraw $colD
      # TODO:Make it pretty
      # wm transient $colD $winId
      wm title $colD "Setup Colours"
      # Plonk it in the middle of the screen
      set width [winfo screenwidth .]
      set height [winfo screenheight .]
      set x [expr ($width/2) - 100]
      set y [expr ($height/2) - 100]
      wm geometry $colD +$x+$y

      label $colD.greyLabel -text "grey" -anchor w
      label $colD.redLabel -text "red" -anchor w
      label $colD.orangeLabel -text "orange" -anchor w
      label $colD.yellowLabel -text "yellow" -anchor w
      label $colD.greenLabel -text "green" -anchor w
      label $colD.blueLabel -text "blue" -anchor w

      entry $colD.greyEntry
      entry $colD.redEntry
      entry $colD.orangeEntry
      entry $colD.yellowEntry
      entry $colD.greenEntry
      entry $colD.blueEntry

      grid config $colD.greyLabel -column 0 -row 0 -sticky "w" -pady 8
      grid config $colD.redLabel -column 0 -row 1 -sticky "w" -pady 8
      grid config $colD.orangeLabel -column 0 -row 2 -sticky "w" -pady 8
      grid config $colD.yellowLabel -column 0 -row 3 -sticky "w" -pady 8
      grid config $colD.greenLabel -column 0 -row 4 -sticky "w" -pady 8
      grid config $colD.blueLabel -column 0 -row 5 -sticky "w" -pady 8

      grid config $colD.greyEntry -column 1 -row 0 -sticky "nsew" -pady 8
      grid config $colD.redEntry -column 1 -row 1 -sticky "nsew" -pady 8
      grid config $colD.orangeEntry -column 1 -row 2 -sticky "nsew" -pady 8
      grid config $colD.yellowEntry -column 1 -row 3 -sticky "nsew" -pady 8
      grid config $colD.greenEntry -column 1 -row 4 -sticky "nsew" -pady 8
      grid config $colD.blueEntry -column 1 -row 5 -sticky "nsew" -pady 8

      $colD.greyEntry insert 0 $a_colourSpecs(grey)
      $colD.redEntry insert 0 $a_colourSpecs(red)
      $colD.orangeEntry insert 0 $a_colourSpecs(orange)
      $colD.yellowEntry insert 0 $a_colourSpecs(yellow)
      $colD.greenEntry insert 0 $a_colourSpecs(green)
      $colD.blueEntry insert 0 $a_colourSpecs(blue)

      radiobutton $colD.range -text "Range of Values" -variable colourMethod \
         -value "RANGE"
      radiobutton $colD.values -text "Match Values" -variable colourMethod \
         -value "MATCH"

      grid config $colD.range    -column 1 -row 6 -sticky "w"
      grid config $colD.values   -column 1 -row 7 -sticky "w"
      $colD.range invoke
      
      set buts "$colD.buts"
      frame $buts -bd 2
      button $buts.btn_OK -text "OK" -command "eval $code_setNewColours $winId $colD {$colourMethod}"
      button $buts.btn_Cancel -text "Cancel" -command "destroy $colD"
      pack $buts.btn_OK -side top -fill x
      pack $buts.btn_Cancel -side top -fill x -pady 6

      grid config $buts -column 3 -row 4 -padx 8 -pady 8 -rowspan 5

   }
   # END proc graphics::colourDialog
   #########################

   #########################
   # proc graphics::setNewColumns { winId colD }
   proc setNewColumns { winId colD } {
    variable dataNS

      set newX [$colD.xColsEntry get]
      set newY [$colD.yColsEntry get]
      
      # Close the dialog and redraw.
      destroy $colD

      ${dataNS}::setMinXCols $newX
      ${dataNS}::setMinYCols $newY
      ${dataNS}::calcXYStep

      set status [GetState $winId]
      ${dataNS}::ReadData $winId [lindex $status 1] [lindex $status 3] [lindex $status 5] [lindex $status 7]
      
      calcViewParams 
      draw $winId
   }
   # proc graphics::setNewColumns { winId colD }
   #########################

   #########################
   # proc graphics::setNewColours { winId colD colourM }
   proc setNewColours { winId colD colourM } {
    variable a_colourSpecs
    variable colourMethod 
      set a_colourSpecs(grey) [$colD.greyEntry get]
      set a_colourSpecs(red) [$colD.redEntry get]
      set a_colourSpecs(orange) [$colD.orangeEntry get]
      set a_colourSpecs(yellow) [$colD.yellowEntry get]
      set a_colourSpecs(green) [$colD.greenEntry get]
      set a_colourSpecs(blue) [$colD.blueEntry get]
      set colourMethod $colourM

      # Close the dialog and redraw.
      destroy $colD
      calcViewParams 
      draw $winId
   }
   # proc graphics::setNewColours { winId colD colourM }
   #########################

   #########################
   # proc graphics::selectColour { a_rawData index }
   proc selectColour { val index } {
    variable a_colourSpecs
    variable a_Colours
    variable colourMethod 
      
      if { $colourMethod=="RANGE" } {
      # Choosing colours on range
         if { $val == "" } { 
            set a_Colours($index) grey 
         } elseif { $val < $a_colourSpecs(grey) } { 
            set a_Colours($index) grey 
         } elseif { $val <= $a_colourSpecs(red) } { 
            set a_Colours($index) red
         } elseif { $val <= $a_colourSpecs(orange) } { 
            set a_Colours($index) orange
         } elseif { $val <= $a_colourSpecs(yellow) } { 
            set a_Colours($index) yellow 
         } elseif { $val <= $a_colourSpecs(green) } { 
            set a_Colours($index) green
         } elseif { $val <= $a_colourSpecs(blue) } { 
            set a_Colours($index) blue
         } else {
            set a_Colours($index) black
         }
      } else {
      # Choosing colours on match
         if { $val == "" } { 
            set a_Colours($index) grey 
         } else {
            switch $val {
            $a_colourSpecs(grey) { set a_Colours($index) grey }
            $a_colourSpecs(red) { set a_Colours($index) red }
            $a_colourSpecs(orange) { set a_Colours($index) orange }
            $a_colourSpecs(yellow) { set a_Colours($index) yellow }
            $a_colourSpecs(green) { set a_Colours($index) green }
            $a_colourSpecs(blue) { set a_Colours($index) blue }
            }
         }
      }
      return $a_Colours($index)
   }
   # proc graphics::selectColour { a_rawData index }
   #########################

}
# END namespace eval graphics
#########################


#########################
# namespace eval window
namespace eval window {
 # links to ${helperNamespace}::
 upvar helperNamespace helperNamespace 
 upvar thdVersion thdVersion
 upvar graphicsNS graphicsNS 
 upvar windowNS windowNS 
 # These are needed outside this namespace
 # Used in graphics::
 upvar b_columns b_columns 
 upvar i_canWidth i_canWidth
 upvar i_canHeight i_canHeight
 upvar myCanvas  myCanvas 
 upvar myDebug myDebug
 upvar a_ZValues a_ZValues
 upvar a_rawColourData a_rawColourData
 # Used in graphics::
 upvar xCols xCols      
 upvar yCols yCols      
 # Used in graphics::
 upvar xColsStart xColsStart
 upvar yColsStart yColsStart
 upvar xColsEnd xColsEnd
 upvar yColsEnd yColsEnd
 upvar code_columnsDialog code_columnsDialog 
 upvar code_setNewColumns code_setNewColumns 
 upvar code_colourDialog code_colourDialog 
 upvar code_setNewColours code_setNewColours 
 upvar code_adjustValuesDialog code_adjustValuesDialog

   #########################
   # proc window::InitialiseWidgets { winId }
   proc InitialiseWidgets { winId } {
    variable save_winId $winId
    variable graphicsNS
    variable windowNS
    variable thdVersion
    # We need some variables for screen drawing. As usual, 0,0 is screen top left.
    variable i_canWidth
    variable i_canHeight
    #
    variable b_columns
    # 
    # This neatens up the code and eases event bining. 
    # NB Should be evaluated as ${myCanvas}
    variable myCanvas "$winId.viewer.can.can_1"
    variable myMenubar "$winId.menubar"
    variable myDebug
    variable helperNamespace
    # These are window-scope only
    variable menuColsString 
    variable notColsString 
    variable menuViewCommand 
    variable code_columnsDialog 
    variable code_colourDialog 
      #########################
      # Some fonts. Straight out the book.
#      font create courierstrike -family Courier \
#         -weight bold \
#         -slant italic \
#         -overstrike true
#
#      font create comicSerif -family {Comic Sans MS} \
#         -weight bold 

      #########################
      # MENU
      # This is very nice and simplifies the GUI considerably.
      # 
      createMenuBar $winId $myMenubar
      set file_menu [createMenu $myMenubar filemenu "File" 0 0]
      set option_menu [createMenu $myMenubar optionmenu "Option" 0 0]
      set controls_menu [createMenu $myMenubar controlsmenu "View" 0 1]
      set colour_menu [createMenu $myMenubar colourmenu "Colour" 0 0]

      # FILE MENU
      $file_menu add command -label "Exit" -underline 0 \
         -command " set b_rotate 0; destroy $winId "
      # OPTION MENU
      set menuColsString [expr ($b_columns==0)?"View Columns":"View Surface"]
      $option_menu add checkbutton -label $menuColsString \
               -command " ${graphicsNS}::columnsToggle $winId " \
               -underline 0
      $option_menu add checkbutton -label "Back Faces" \
               -command " ${graphicsNS}::toggleBackFaces $winId " \
               -underline 0
      $option_menu add command -label "Number of Columns..." -underline 0 \
         -command " ${graphicsNS}::columnsDialog $winId"
      # CONTROLS MENU - NB tearoff-able
      $controls_menu add checkbutton -label "Spin View" \
               -command " ${graphicsNS}::spin $winId " \
               -underline 0
      $controls_menu add command -label "<- Rotate " \
               -command " ${graphicsNS}::HRotate LEFT $winId " \
               -underline 0
      $controls_menu add command -label "Rotate ->" \
               -command " ${graphicsNS}::HRotate RIGHT $winId " \
               -underline 8
      $controls_menu add command -label "Rotate Up" \
               -command " ${graphicsNS}::VRotate UP $winId " \
               -underline 7
      $controls_menu add command -label "Rotate Down" \
               -command " ${graphicsNS}::VRotate DOWN $winId " \
               -underline 7
      $controls_menu add command -label "Zoom in" \
               -command " ${graphicsNS}::zoomButton IN $winId " \
               -underline 5
      $controls_menu add command -label "Zoom out" \
               -command " ${graphicsNS}::zoomButton OUT $winId " \
               -underline 5
      $controls_menu add command -label "Shrink Heights" \
               -command " ${graphicsNS}::heightButton DOWN $winId " \
               -underline 1
      $controls_menu add command -label "Grow Heights" \
               -command " ${graphicsNS}::heightButton UP $winId " \
               -underline 0
      # COLOUR MENU
      $colour_menu add command -label "Setup Colours" -underline 0 \
         -command " ${graphicsNS}::colourDialog $winId"

      #########################
      # The canvas for drawing.
      frame $winId.viewer -bd 1 -relief raised
      frame $winId.viewer.can -bd 1 -relief raised

      canvas $myCanvas    -width $i_canWidth      \
               -height $i_canHeight    \
               -background white
      #########################
      # STATUS BAR
      frame $winId.status -borderwidth 0
      label $winId.status.lab_ver -text "$thdVersion" \
               -relief sunken -borderwidth 1 -anchor e
      label $winId.status.drawing -text "ready" \
               -relief sunken -borderwidth 1 -anchor w \
               -width 10
      label $winId.status.rotate -text "Rotate OFF" \
               -relief sunken -borderwidth 1 -anchor w \
               -width 10
      label $winId.status.backFace -text "Back Faces OFF" \
               -relief sunken -borderwidth 1 -anchor w \
               -width 15
      set viewString [expr ($b_columns==1)?"Columns View":"Surface View"]
      label $winId.status.view -text $viewString \
               -relief sunken -borderwidth 1 -anchor w \
               -width 15

      #########################
      # BUTTONS
      # Scales
      set ns [namespace current]

      frame $winId.viewer.can.scale -bd 1 -relief sunken
      message $winId.viewer.can.scale.msg -text "vert\nRot" 
      #-font comicSerif

#      frame $winId.viewer.buttons -bd 1 -relief raised
#      button $winId.viewer.buttons.setup -text "setup colours" -command "eval $code_colourDialog $winId"
      
      #########################
      # Make them visible
      # HRot buttons
#      pack $winId.viewer.buttons.setup -side right

      pack $myCanvas -side left -expand true -fill both
      # VRot scale
#      pack $winId.viewer.buttons -side bottom -fill y -anchor e -expand 1
      pack $winId.viewer.can.scale -side right -fill y

      pack $winId.viewer -side top -fill both -expand true
      pack $winId.viewer.can -side top -fill both -expand true
      pack $winId.status.lab_ver -side right -padx 2 -pady 1
      pack $winId.status.drawing $winId.status.view $winId.status.rotate $winId.status.backFace -side left -padx 2 -pady 1
      pack $winId.status -side bottom -fill x

      #########################
      # Event Bindings.
      # These are still slightly mysterious!
      # ie how do I use the %W identifier?
      #
      #########################

      $myCanvas bind top <Enter> [namespace code {$windowNS\::enterProc}]
      $myCanvas bind top <Leave> [namespace code {$windowNS\::leaveProc}]
#      $myCanvas bind top <Button-1> [namespace code {$windowNS\::but1Proc}]
      $myCanvas bind top <Button-3> [namespace code {$windowNS\::but3Proc}]

   }
   # proc window::InitialiseWidgets { }
   #########################
 
   #########################
   # proc window::setDrawingStatus{ status winId }
   proc setDrawingStatus { status winId } {
       global normalColor
      if { $status == "TRUE" } {
         $winId.status.drawing configure -bg red
         $winId.status.drawing configure -text "Drawing"
      } else {
         $winId.status.drawing configure -bg $normalColor
         $winId.status.drawing configure -text "Ready  "
      }
      # ensure that the message is displayed.
      update idletasks 
   }
   # proc window::setDrawingStatus{ status winId }
   #########################
 
   #########################
   # proc window::setRotateStatus{ status winId }
   proc setRotateStatus { status winId } {
       global normalColor
      if { $status == "TRUE" } {
         $winId.status.rotate configure -bg green
         $winId.status.rotate configure -text "Rotate ON "
      } else {
         $winId.status.rotate configure -bg $normalColor
         $winId.status.rotate configure -text "Rotate OFF"
      }
      # ensure that the message is displayed.
      update idletasks 
   }
   # proc window::setRotateStatus { status winId }
   #########################
 
   #########################
   # proc window::setBackFacesState { status winId }
   proc setBackFacesState { status winId } {
       global normalColor
      if { $status == "TRUE" } {
         $winId.status.backFace configure -bg blue
         $winId.status.backFace configure -text "Back Faces ON "
      } else {
         $winId.status.backFace configure -bg $normalColor
         $winId.status.backFace configure -text "Back Faces OFF"
      }
      # ensure that the message is displayed.
      update idletasks 
   }
   # proc window::setBackFacesState { status winId }
   #########################
 
   #########################
   # proc window::setViewStatus { status winId }
   proc setViewStatus { status winId } {
      if { $status == "COLS" } {
         $winId.status.view configure -text "Column View"
      } else {
         $winId.status.view configure -text "Surface View"
      }
      # ensure that the message is displayed.
      update idletasks 
   }
   # proc window::setViewStatus { status winId }
   #########################
 
   #########################
   # proc window::changeColour { colour }
   proc changeColour { colour } {
    variable myCanvas
    variable myDebug
      
      $myCanvas itemconfigure current -fill $colour
      # $myDebug insert 1.0 "in changeColour, colour=$colour\n"
   }
   # END proc changeColoiur { colour }
   #########################

   #########################
   # proc  window::enterProc { }
   proc enterProc { } { 
    variable myCanvas
    variable myDebug
    variable helperNamespace
    variable enterColour
    variable exitColour

      set enterColour [ $myCanvas itemcget current -fill ]
      set exitColour $enterColour
   }
   # END proc  window::enterProc { }
   #########################
   
   #########################
   # proc  window::leaveProc { }
   proc leaveProc { } { 
    variable myCanvas
    variable myDebug
    variable helperNamespace
    variable enterColour
    variable exitColour

      if { $exitColour!=$enterColour } {
         # Set column sides colour
         foreach index [$myCanvas gettags current] {
            if [regexp {^-*[0-9]+,-*[0-9]+$} $index] {
               # $myDebug
               
               $myCanvas itemconfigure $index -fill ${exitColour}3
            }
            # END if
         }
         # END foreach
         changeColour $exitColour
      }
      #END if
   }
   # END proc  window::leaveProc { }
   #########################
   
   #########################
   # proc  window::but1Proc { }
   proc but1Proc { } { 
    variable myCanvas
    variable helperNamespace
    variable enterColour
    variable exitColour

      if { $exitColour!=$enterColour } {
         set  exitColour $enterColour
         changeColour $enterColour
      } else {
         set  exitColour red
         changeColour $exitColour
      }
   }
   # END proc  window::but1Proc { }
   #########################
   
   #########################
   # proc  window::but3Proc { }
   proc but3Proc { } { 
    variable myCanvas
    variable myDebug
    variable code_adjustValuesDialog
    variable save_winId
      # extract the current tags and thus get the data from the arrays.
      foreach index [$myCanvas gettags current] {
#         $myDebug insert 1.0 "tag=$index\n" 
         if [regexp {^(-*[0-9]+)\,(-*[0-9]+)$} $index whole x y] {
            eval $code_adjustValuesDialog $index $save_winId
         }
         # END if [regexp {^([0-9]+)\,([0-9]+)$} $index whole x y]
      }
      # END foreach index [$myCanvas gettags current]
   }
   # END proc  window::but3Proc { }
   #########################
   
   #########################
   # proc window::createMenuBar
   # This function from Foster-Johnson p206. Thanks Eric!
   proc createMenuBar { window menubar } {
      menu $menubar -type menubar
      $window configure -menu $menubar
   }
   # END proc window::createMenuBar
   #########################

   #########################
   # proc window::createMenu
   # This function from Foster-Johnson p207. Thanks Eric!
   proc createMenu { menubar basename menutext mnemonic tearoff } {
      set menu_name "$menubar.$basename"
      # Next line creates a 'slot' on the $menubar
      $menubar add cascade -label $menutext -menu $menu_name -underline $mnemonic
      # Nextline creates menu at 'slot' above
      menu $menu_name -tearoff $tearoff
      return $menu_name
   }
   # END proc window::createMenu
   #########################
}
# END namespace eval window
#########################


#########################
# namespace eval utility 
namespace eval utility {
 upvar myDebug myDebug
 upvar helperNamespace helperNamespace 
 upvar thdVersion thdVersion 
   #########################
   # removeLast 
   # Used to (surprise) remove the last element from a list.
   # This is especially handy-dandy hen we have a list setup with a dummy
   # 1st member, all subsequent members being lists added at the beginning
   # of the list. Get that? Well, it's handy anyway.
   proc removeLast { l_list } {
    upvar $l_list l_link
      set temp_2ndLast [expr [llength $l_link] -2] 
      set l_link [lrange $l_link 0 $temp_2ndLast]
   }
   # END proc removeLast { l_list }
   #########################

   #########################
   # proc format_floor { value }
   # floor returns an integer value with .0 on the end! Remove it.
   proc format_floor { value } {
      return [format "%.0f" [expr floor($value)]]
   }
   # proc format_floor { value }
   #########################

   #########################
   # proc format_ceil { value }
   # ceil returns an integer value with .0 on the end! Remove it.
   proc format_ceil { value } {
      return [format "%.0f" [expr ceil($value)]]
   }
   # proc format_ceil { value }
   #########################
}
# namespace eval utility 
#########################

# fincr -- by Jasper -- does what incr does, but works with floats

   proc fincr {count args} {
       upvar 1 $count incount
       if {[llength $args]} {
	   set incount [expr $incount+$args]
       } else {
	   set incount [expr $incount + 1]
       }
   }

} ;
# end of threeDoodle namespace 

