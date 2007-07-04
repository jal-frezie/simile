# SurfaceGridOGL.tcl
# Helper to display a grid as a 2.5D surface
# Use gridsquare.sml as a test model

# To do
# controls for user to rotate the model
# adjust light to show the surface - it looks flat at now
# controls to accommodate different sized grids - zoom or move to and from

lappend ::auto_path "C:/Program Files/Tcl/lib"; # todo remove sort installation
package require tcl3d 0.3

# proc bgerror { msg } {
# tk_messageBox -icon error -type ok -message "Error: $msg"
# exit
# }

set keyValue surfacegridTcl3d070701
namespace eval $keyValue {
    
    variable useNodes
    variable cell_ids
    variable old_icolour
    variable min; # edit var for entry widget
    variable max; # edit var for entry widget
    
    # todo
    #set ::texImgWidth  256
    #set ::texImgHeight 256
    
    
    proc identify {} {
        return "OpenGL surface grid display"
    }
    
    proc bgerror { msg } {
        tk_messageBox -icon error -type ok -message "Error: $msg"
        exit
    }
    
    proc tclCreateFunc { toglwin } {
        glClearColor 1.0 1.0 1.0 0.0            ; # White Background
        glClearDepth 1.0                        ; # Depth Buffer Setup
        glDepthFunc GL_LEQUAL                   ; # The Type Of Depth Testing To Do
        glEnable GL_DEPTH_TEST                  ; # Enables Depth Testing
        #glShadeModel GL_FLAT
        glShadeModel GL_SMOOTH                  ; # Select smooth Shading
        glHint GL_PERSPECTIVE_CORRECTION_HINT GL_NICEST
        #glEnable GL_LIGHT0                      ; # Enable Default Light
        #glEnable GL_LIGHTING                    ; # Enable Lighting
        
        #glEnable GL_COLOR_MATERIAL              ; # Enable Color Material
    }
    
    proc tclDisplayFunc { toglwin } {
        #ShowMessage debug info tclDisplayFunc ok
        set winId [winfo parent $toglwin]
        
        glClear [expr $::GL_COLOR_BUFFER_BIT | $::GL_DEPTH_BUFFER_BIT]

        glColor4f 0.1 0.5 0.1 0.1
        
        if {[info exists ::surfacegridTcl3d070701::useNodes($winId,color)]} {
            Triangulate $winId $::surfacegridTcl3d070701::useNodes($winId,color)
        }
        
        glFlush
        $toglwin swapbuffers
    }
    
    proc tclReshapeFunc { toglwin w h } {
        #ShowMessage debug info tclReshapeFunc ok
        # Prevent A Divide By Zero By
        if { $h == 0 } {
            set h 1
        }
        glViewport 0 0 $w $h        ; # Reset The Current Viewport
        
        glMatrixMode GL_PROJECTION  ; # Select The Projection Matrix
        glLoadIdentity              ; # Reset The Projection Matrix
        # Calculate The Aspect Ratio Of The Window
        #gluPerspective 10.0 [expr double($w)/double($h)] 1.0 100.0; #newcoord
        gluPerspective 12.0 [expr double($w)/double($h)] 1.0 1000.0; #newcoord
        
        glMatrixMode GL_MODELVIEW   ; # matrix op to be on the Modelview Matrix
        glLoadIdentity              ; # Reset The Modelview Matrix
        
        gluLookAt -50.0 50.0 100.0 10.0 10.0 0.0 0.0 1.0 0.0
    }
    
################################################################################
#     proc Method { toglwin num } {
#         glClear [expr $::GL_COLOR_BUFFER_BIT | $::GL_DEPTH_BUFFER_BIT]
#         glFlush
#         
#         if { [info exists ::texImg] } {
#             $::texImg delete
#         }
#         set measure [time {
#             set texSize [expr $::texImgHeight*$::texImgWidth * 3]
#             set ::texType $::GL_RGB
#             
#             set template [binary format ccc 1 0 0]
#             for { set j 1 } { $j < $::texImgWidth } { incr j } {
#                 append template [binary format ccc $j 0 0]
#             }
#             set row $template
#             for { set i 0 } { $i < $::texImgHeight } { incr i } {
#                 append img $row
#                 set row [string map [list [binary format c 0] [binary format c $i]] \
#                         $template]
#             }
#             set ::texImg [tcl3dVectorFromByteArray GLubyte $img]
#         } ]
#         #PrintTimeInfo $measure
#         #PrintTitle "Test $num"
#         
#         glPixelStorei GL_UNPACK_ALIGNMENT 1
#         
#         set ::texName [tcl3dVector GLuint 1]
#         glGenTextures 1 $::texName
#         glBindTexture GL_TEXTURE_2D [$::texName get 0]
#         
#         # bytearray.tcl
#         # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S $::GL_REPEAT
#         # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T $::GL_REPEAT
#         # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER $::GL_NEAREST
#         # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER $::GL_NEAREST
#         #
#         # glTexImage2D GL_TEXTURE_2D 0 $::GL_RGBA \
#         # $::texImgWidth $::texImgHeight \
#         # 0 $::texType GL_UNSIGNED_BYTE $::texImg
#         
#         # imgViewer
#         glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S $::GL_CLAMP
#         glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T $::GL_CLAMP
#         glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER $::GL_LINEAR
#         glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER $::GL_LINEAR
#         # glTexImage2D GL_TEXTURE_2D 0 4 \
#         # $sqr $sqr \
#         # 0 GL_RGBA GL_UNSIGNED_BYTE $::vecImg
#         glTexImage2D GL_TEXTURE_2D 0 $::GL_RGBA \
#                 $::texImgWidth $::texImgHeight \
#                 0 $::texType GL_UNSIGNED_BYTE $::texImg
#         
#         $toglwin postredisplay
#     }
################################################################################
    
    proc initialize {winId} {
        variable useNodes
        namespace import -force ::maptools2::*
        set useNodes($winId,editMode) 0
        set useNodes($winId,cbot) black
        set useNodes($winId,cmid) red
        set useNodes($winId,ctop) white
        set useNodes($winId,nswatches) 32
        set useNodes($winId,integer) 0
        set useNodes($winId,freeze) false
        set useNodes($winId,min) 0
        set useNodes($winId,max) 100
        set useNodes($winId,dataMin) 1e100
        set useNodes($winId,dataMax) -1e100
        SetState $winId {}
        message	$winId.msg -aspect 1000
        AddToolbar $winId
        set NToolButtons [$winId.bbframe.buttonBox index last]
        for {set i 1} {$i<=$NToolButtons} {incr i} {
            $winId.bbframe.buttonBox itemconfigure $i -state disable
        }
        if {[string match $winId [winfo toplevel $winId]]} {
            wm geometry $winId 500x500
        }
        
    }
    
    proc reset {winId} {
    }
    
    proc AddToolbar {winId} {
        set toolbarItems [list \
                [list add.gif "Add a variable"   [namespace code "AddVariable $winId"]]\
                [list save.gif "Save as GIF"   [namespace code "SaveAsFile $winId"]]\
                [list zoomin.gif "Zoom in" [namespace code "zoomio $winId 1.25"] ]\
                [list zoomout.gif "Zoom out" [namespace code "zoomio $winId 0.8"] ]\
                [list property.gif " Properties " [namespace code "Settings $winId"]]\
                [list edit.gif "Enter edit mode " [namespace code "ChangeEditMode [namespace current] $winId"]] \
                [list less.gif "Decrease range" [namespace code "DecreaseRange $winId"] ]\
                [list greater.gif "Increase range" [namespace code "IncreaseRange $winId"] ]\
                [list pause.gif " Freeze " [namespace code "ToggleFreeze $winId"]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
    }
    
    proc AddVariable {winId} {
        set ms $winId.msg
        $ms configure -text \
                "Click on the variable containing the positions or IDs of the columns."
        GrabClicks $winId
        pack $ms
        $winId.bbframe.buttonBox itemconfigure 0 -state disable; #disable the add var button
        SetState $winId display0
    }
    
    proc Recolour {winId whichCol exampleWidget} {
        variable useNodes
        set colour [tk_chooseColor -initialcolor $useNodes($winId,c$whichCol)]
        if {[string length $colour]} {
            $exampleWidget configure -bg $colour
        }
        return $colour
    }
    
    proc Restore {winId} {
        variable useNodes
        namespace import -force ::maptools2::*
        set useNodes($winId,editMode) 0
        message	$winId.msg -aspect 1000
        set state [GetState $winId]
        # looks like "displaying %s %s colourmap %s %s %s aspect %d %g %g magnification %d"
        set useNodes($winId,color) [GetIdFromCaptionPath [lindex $state 1]]
        set useNodes($winId,colvals) [GetIdFromCaptionPath [lindex $state 2]]
        set mapBase [lsearch $state colourmap]
        if {$mapBase > -1} {
            foreach colourPt {cbot cmid ctop} {
                set useNodes($winId,$colourPt) [lindex $state [incr mapBase]]
            }
        }
        set rangeBase [lsearch $state aspect]
        foreach rangePt {nswatches min max} {
            set useNodes($winId,$rangePt) [lindex $state [incr rangeBase]]
        }
        SetColourMap useNodes $winId $useNodes($winId,color)
        set swatchBase [lsearch $state swatches]
        if {$swatchBase > -1} {
            for {set col 0} {$col<=$useNodes($winId,nswatches)} {incr col} {
                set useNodes($winId,c$col) [lindex $state [incr swatchBase]]
            }
            set useNodes($winId,colourMapTweaked) 1
        }
        set multBase [lsearch $state magnification]
        if {$multBase != -1} {
            set useNodes($winId,mult) [lindex $state [incr multBase]]
        }
        set useNodes($winId,caption) [lindex $state 1]
        
        AddToolbar $winId
        $winId.bbframe.buttonBox itemconfigure 0 -state disable
        NumDistinct $winId $useNodes($winId,colvals)
        set useNodes($winId,dataMin) 1e100
        set useNodes($winId,dataMax) -1e100
        InitialiseGrid $winId $useNodes($winId,color)
        set useNodes($winId,freeze) false
    }
    
    proc GetCanvas {winId} {
        return $winId.c
    }
    
    proc click {winId node caption} {
        variable useNodes
        
        set ms $winId.msg
        set testResult [GetModelType $node]
        if {[string compare $testResult VALUELESS]} {
            set state [GetState $winId]
            switch $state {
                display0 {
                    NumDistinct $winId $node
                    set useNodes($winId,colvals) $node
                    $ms configure -text "Grid currently has $useNodes($winId,ncol) columns and $useNodes($winId,nrow) rows. Now click on the variable to be displayed."
                    SetState $winId display1
                } display1 {
                    pack forget $ms
                    ReleaseClicks $winId
                    set useNodes($winId,color) $node
                    SetColourMap useNodes $winId $node
                    catch {wm title $winId $caption}
                    InitialiseGrid $winId $node
                    UpdateState $winId
                    #                    destroy $winId.intro
                    set NToolButtons [$winId.bbframe.buttonBox index last]
                    for {set i 1} {$i<=$NToolButtons} {incr i} {
                        if {!$useNodes($winId,ETCount) || \
                                    [lsearch {4 6 7} $i]==-1} {
                            $winId.bbframe.buttonBox itemconfigure $i \
                                    -state normal
                        }
                    }
                    if {![info exists useNodes($winId,values)]} {
                        #disable the edit mode as we do not know the model indices
                        $winId.bbframe.buttonBox itemconfigure 5 -state disable
                    }
                    raise $winId
                }
            }
        } else {
            $ms configure -text \
                    "This component does not have a value; please choose a compartment, variable or flow."
        }
    }
    
    proc NumDistinct {winId testNode} {
        variable useNodes
        
        if {![catch {ListDiscreteModelValues $testNode} vList]} {
            set useNodes($winId,ncol) [llength $vList]
            set useNodes($winId,nrow) \
                    [expr [string length [GetBinaryModelValue $testNode 0 255]]/$useNodes($winId,ncol)]
        } else {
            set columns [Flatten [lindex [GetModelValue $testNode] 0]]
            foreach col $columns {
                set colvals([lindex $col 1]) 1
            }
            if {[info exists colvals()]} {
                unset colvals()
            }
            set useNodes($winId,ncol) [array size colvals]
            set useNodes($winId,nrow) \
                    [expr {[llength $columns]/$useNodes($winId,ncol)}]
        }
    }
    
    proc UpdateState {winId} {
        variable useNodes
        
        set state [list displaying \
                [GetCaptionPathFromId $useNodes($winId,color)] \
                [GetCaptionPathFromId $useNodes($winId,colvals)]]
        if {$useNodes($winId,colourMapTweaked)} {
            lappend state swatches
            for {set col 0} {$col<=$useNodes($winId,nswatches)} {incr col} {
                lappend state $useNodes($winId,c$col)
            }
        } else {
            lappend state colourmap $useNodes($winId,cbot) \
                    $useNodes($winId,cmid) $useNodes($winId,ctop)
        }
        lappend state aspect $useNodes($winId,nswatches) \
                $useNodes($winId,min) $useNodes($winId,max) \
                magnification $useNodes($winId,mult)
        SetState $winId $state
    }
    
    proc display {winId time step remainder} {
        # OGL grid surface should build a display list of
        # triangle strips
        variable useNodes
        if {[string match [lindex [GetState $winId] 0] displaying] && \
                    !$useNodes($winId,freeze)} then {
            if {!$time} { ;# wrong, should only be done on reset
                NumDistinct $winId $useNodes($winId,colvals)
            }
            
            #ShowMessage debug info "display: $useNodes($winId,color)" ok
            $winId.c postredisplay
        }
    }
    
    proc InitialiseGrid {winId display1} {
        variable useNodes
        
        glClear [expr $::GL_COLOR_BUFFER_BIT | $::GL_DEPTH_BUFFER_BIT]
        glFlush
        
        # if { [info exists ::texImg] } {
            # $::texImg delete
        # }
        
        
        set useNodes($winId,hiddenMap) [image create photo]
        DrawGrid7 $winId $display1
        # This must now be done before we create the canvas because otherwise the
        # canvas might try to redraw while this is waiting for data from the model
        frame $winId.f
        #        scrollbar $winId.hscroll -orient horiz -command "$winId.c xview"
        #        scrollbar $winId.vscroll -command "$winId.c yview"
        ################################################################################
        #         canvas $winId.c \
        #                 -relief sunken \
        #                 -borderwidth 2 \
        #                 -xscrollcommand [namespace code "ScrollPhoto $winId h"] \
        #                 -yscrollcommand [namespace code "ScrollPhoto $winId v"]
        ################################################################################
        # -width 500 -height 500
        togl $winId.c -width 500 -height 500\
                -double true -depth true \
                -createproc [namespace code tclCreateFunc] \
                -reshapeproc [namespace code tclReshapeFunc] \
                -displayproc [namespace code tclDisplayFunc]
        pack $winId.f -expand yes -fill both -padx 1 -pady 1
        grid rowconfig    $winId.f 0 -weight 1 -minsize 0
        grid columnconfig $winId.f 0 -weight 1 -minsize 0
        
        grid $winId.c -padx 1 -in $winId.f -pady 1 \
                -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
        #grid $winId.vscroll -in $winId.f -padx 1 -pady 1 \
        -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
        #grid $winId.hscroll -in $winId.f -padx 1 -pady 1 \
        -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news
        
        if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
            set n $useNodes($winId,nrow)
        } else {
            set n $useNodes($winId,ncol)
        }
        
        if {[info exists useNodes($winId,mult)]} {
            set mult $useNodes($winId,mult)
        } else {
            set mult [expr {int(380/$n)}]
        }
        if {$mult<2} {
            set mult 1
            $winId.bbframe.buttonBox itemconfigure 3 -state disable
        }
        set useNodes($winId,mult) $mult
        set xwidth [expr {$mult*$useNodes($winId,ncol)}]
        set yheight [expr {$mult*$useNodes($winId,nrow)+20}]
        set useNodes($winId,xwidth) $xwidth
        set useNodes($winId,yheight) $yheight
        $winId.c configure -width $xwidth -height $yheight
        #
        # $winId.c bind all <Button-3> [namespace code "Settings $winId"]
        # $winId.c bind all <B1-Motion> [namespace code "value_popup $winId %X %Y %x %y"]
        # $winId.c bind all <ButtonPress-1> [namespace code "value_popup $winId %X %Y %x %y"]
        # $winId.c bind all <B1-ButtonRelease> RemovePopup
        #
        # set useNodes($winId,visibleMap) [image create photo]
        # $winId.c create image 0 0 -image $useNodes($winId,visibleMap) \
        # -anchor nw -tag map
        # recolour_scale [namespace current] $winId ;# do here for scrollers
        # bind $winId.c <Configure> \
        # [namespace code "recolour_scale [namespace current] $winId"]
        # #        $winId.c configure -scrollregion [$winId.c bbox all]
        
        #Method $winId.c 5
        
        # set ::texType $::GL_LUMINANCE
        # 
        # glPixelStorei GL_UNPACK_ALIGNMENT 1
        # 
        # set ::texName [tcl3dVector GLuint 1]
        # glGenTextures 1 $::texName
        # glBindTexture GL_TEXTURE_2D [$::texName get 0]
        # 
        # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S $::GL_REPEAT
        # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T $::GL_REPEAT
        # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER $::GL_NEAREST
        # glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER $::GL_NEAREST
        
        # glTexImage2D GL_TEXTURE_2D 0 $::GL_RGBA \
        # $::texImgWidth $::texImgHeight \
        # 0 $::texType GL_UNSIGNED_BYTE $::texImg
        
        #glPixelTransferi GL_RED_SCALE 1
        #glPixelTransferi GL_RED_BIAS 0
        
################################################################################
#         glTexImage2D GL_TEXTURE_2D 0 $::GL_RGBA \
#                 $::texImgWidth $::texImgHeight \
#                 0 $::texType GL_UNSIGNED_BYTE $::texImg
################################################################################
        
        $winId.c postredisplay
        
    }
    
    proc ToggleFreeze {winId} {
        variable useNodes
        if {$useNodes($winId,freeze)} {
            set useNodes($winId,freeze) false
            $winId.bbframe.buttonBox itemconfigure end -relief flat; #disable the add var button
        } else  {
            set useNodes($winId,freeze) true
            $winId.bbframe.buttonBox itemconfigure end -relief sunken; #disable the add var button
        }
    }
    
    proc IncreaseRange {winId} {
        variable useNodes
        set useNodes($winId,min) [expr {$useNodes($winId,min)*10}]
        set useNodes($winId,max) [expr {$useNodes($winId,max)*10}]
        SetColours useNodes $winId
        recolour_scale [namespace current] $winId
        UpdateState $winId
        display $winId 0 0 0
    }
    
    proc DecreaseRange {winId} {
        variable useNodes
        set useNodes($winId,min) [expr {0.1*$useNodes($winId,min)}]
        set useNodes($winId,max) [expr {0.1*$useNodes($winId,max)}]
        SetColours useNodes $winId
        recolour_scale [namespace current] $winId
        UpdateState $winId
        display $winId 0 0 0
    }
    
    proc Settings {winId} {
        variable useNodes
        variable min
        variable max
        set dlg [Dialog .gridprop -parent $winId -title "Grid display properties" \
                -modal local -default 0 -cancel 1]
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min($winId) $useNodes($winId,min)
        set max($winId) $useNodes($winId,max)
        
        #create widgets
        set coloursF [labelframe [$dlg getframe].colours -text "Colour scale"]
        pack [LabelFrame $coloursF.lowcolourF -text "Low colour"] -fill x  -padx 10
        frame $coloursF.lowcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cbot)
        pack [button $coloursF.lowcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId bot $coloursF.lowcolourF.colF"]] -side right
        pack $coloursF.lowcolourF.colF -side right -padx 10
        
        pack [LabelFrame $coloursF.midcolourF -text "Middle colour"] -fill x -padx 10
        frame $coloursF.midcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cmid)
        pack [button $coloursF.midcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId mid $coloursF.midcolourF.colF"]] -side right
        pack $coloursF.midcolourF.colF -side right -padx 10
        
        pack [LabelFrame $coloursF.topcolourF -text "High colour"] -fill x -padx 10
        frame $coloursF.topcolourF.colF -width 20 -height 15 -bg $useNodes($winId,ctop)
        pack [button $coloursF.topcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId top $coloursF.topcolourF.colF"]] -side right
        pack $coloursF.topcolourF.colF -side right -padx 10
        
        pack $coloursF -padx 10 -pady 10 -fill x
        
        set rangeF [labelframe [$dlg getframe].range -text "Scale range"]
        pack [label $rangeF.dataminL -text "Data min. so far: $useNodes($winId,dataMin)"] -fill x  -padx 10
        pack [label $rangeF.datamaxL -text "Data max. so far: $useNodes($winId,dataMax)"] -fill x  -padx 10
        pack [LabelFrame $rangeF.minF -text "Min"] -fill x  -padx 10 -pady 5
        pack [entry $rangeF.minF.entry -textvar [namespace current]::min($winId) -width 20] -side right -padx 10
        pack [LabelFrame $rangeF.maxF -text "Max"] -fill x -padx 10 -pady 5
        pack [entry $rangeF.maxF.entry -textvar [namespace current]::max($winId) -width 20] -side right -padx 10
        pack $rangeF -padx 10 -pady 10
        
        $dlg add -name ok \
                -command [namespace code "OnClickSettingOkBtn $winId $coloursF $rangeF $dlg"]; # buttons 0
        $dlg add -name cancel -command "$dlg enddialog 1"
        $dlg draw; # waits for a button to be clicked. Button command must call $dlg enddialog _result_
        destroy $dlg
    }
    
    proc OnClickSettingOkBtn {winId coloursF rangeF dlg} {
        
        variable useNodes
        variable min
        variable max
        
        # copy the values from the temp values to those to be edited if OK clicked
        set useNodes($winId,ctop) [$coloursF.topcolourF.colF cget -bg]
        set useNodes($winId,cmid) [$coloursF.midcolourF.colF cget -bg]
        set useNodes($winId,cbot) [$coloursF.lowcolourF.colF cget -bg]
        if {[IsNumber $min($winId)]} {
            set useNodes($winId,min) $min($winId)
        } else  {
            ShowMessage Error error "Value must be a number." ok
            $rangeF.minF.entry selection range 0 end
            focus $rangeF.minF.entry
            return
        }
        if {[IsNumber $max($winId)]} {
            set useNodes($winId,max) $max($winId)
        } else  {
            ShowMessage Error error "Value must be a number." ok
            $rangeF.maxF.entry selection range 0 end
            focus $rangeF.maxF.entry
            return
        }
        $dlg enddialog 0
        SetColours useNodes $winId
        recolour_scale [namespace current] $winId
        UpdateState $winId
        display $winId 0 0 0
    }
    
    proc click_cell {winId c} {
        variable useNodes
        bell
        $c itemconfigure current -fill red
        set tags [$c gettags current]
        $c create text 250 180 -text "TAGS $tags"
        set cell [string range $tags 4 [expr {[string first " " $tags]-1}]]
        $c create text 250 200 -text "xxx $cell xxx"
        set cella [expr {$cell*2}]
        $c create text 250 210 -text $cella
        
        set dis1 $useNodes($winId,color)
        set display1 [lindex [GetModelValue $dis1] 0]
        set this_colour [expr {int([lindex $display1 [expr $cell*2-1]])}]
        $c create text 250 230 -text "xx $this_colour xx"
    }
    
    proc Triangulate {winId node} {
        # from DrawGrid5
        # create triangle strips from the DEM
        variable useNodes
        
        set rows $useNodes($winId,nrow)
        set cols $useNodes($winId,ncol)
        
        variable useNodes
        
        set values [Flatten [lindex [GetModelValue $node] 0]]
        set useNodes($winId,values) $values
        
        set ncell [llength $values]
        
        # Data must be from a singly-nested fixed membership model,
        # or an indexless conditional model inside one
        # Note: tried to optimise (e.g. by use of holding variables for array
        # elements), since this is the time-critical part.
        
        set allData {}
        set min $useNodes($winId,min)
        set range [expr $useNodes($winId,max)-$useNodes($winId,min)]
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set nswatches $useNodes($winId,nswatches)
        
        glBegin GL_TRIANGLES                        ; # Drawing Using Triangles
        for {set row 1} {$row<$nrow} {incr row} {
            set rowData($row) {}
            for {set col 1} {$col<$ncol} {incr col} {
                set cell1 [expr {($row-1)*$ncol+$col-1}]
                set cell2 [expr {($row)*$ncol+$col-1}]
                set cell3 [expr {($row)*$ncol+$col}]
                set cell4 [expr {($row-1)*$ncol+$col}]
                set cellval1 [lindex [lindex $values $cell1] 1]
                set cellval2 [lindex [lindex $values $cell2] 1]
                set cellval3 [lindex [lindex $values $cell3] 1]
                set cellval4 [lindex [lindex $values $cell4] 1]
                set length [llength $cellval1]
                
                if {$length} {
                    # todo
                    if {$length>1} {set cellval1 [lindex $cellval1 1]}
                    if {$cellval1<$useNodes($winId,dataMin)} {
                        set useNodes($winId,dataMin) $cellval1
                    }
                    if {$cellval1>$useNodes($winId,dataMax)} {
                        set useNodes($winId,dataMax) $cellval1
                    }
                    # if [catch {set icolour [expr {int($nswatches*($celval-$min)/$range)}]}] {
                        # return
                    # }
                    # 
                    # if {$icolour < 0} {
                        # set icolour 0
                    # } elseif {$icolour > $nswatches} {
                        # set icolour $nswatches
                    # }
                    #lappend rowData($row) $useNodes($winId,c$icolour)   
                    glVertex3f [expr {1.0*$col}]  [expr {1.0*$row}] [expr {1.0*$cellval1}]
                    glVertex3f [expr {1.0*$col+1.0}]  [expr {1.0*$row+1.0}] [expr {1.0*$cellval3}]
                    glVertex3f [expr {1.0*$col+1.0}]  [expr {1.0*$row}] [expr {1.0*$cellval4}]
                    
                    glVertex3f [expr {1.0*$col}]  [expr {1.0*$row}] [expr {1.0*$cellval1}]
                    glVertex3f [expr {1.0*$col}]  [expr {1.0*$row+1.0}] [expr {1.0*$cellval2}]
                    glVertex3f [expr {1.0*$col+1.0}]  [expr {1.0*$row+1.0}] [expr {1.0*$cellval3}]
                } else  {
                    #lappend rowData($row) grey
                }
                
            }
        }
        glEnd   ; # Finished Drawing The Triangl

        # for {set row $nrow} {$row>=1} {incr row -1} {
        # lappend allData $rowData($row)
        # }
        #
        # $useNodes($winId,hiddenMap) put $allData
        set useNodes($winId,range) $range
        
        ################################################################################
        #         #load the raster
        #         set texSize [expr $rows*$cols]
        #         set ::texType $::GL_RED; #1 byte?? # $::GL_RGB
        #         set ::texImg [tcl3dVectorFromByteArray GLubyte $useNodes($winId,rawBinary)]
        #
        ################################################################################
    }
    
    # Old version -- actually extracted model data as Tcl numbers and stuck them
    # one by one into the photo. Crawled, of course.
    
    proc DrawGrid5 {winId node} {
        variable useNodes
        
        set values [Flatten [lindex [GetModelValue $node] 0]]
        set useNodes($winId,values) $values
        
        set ncell [llength $values]
        
        # Data must be from a singly-nested fixed membership model,
        # or an indexless conditional model inside one
        # Note: tried to optimise (e.g. by use of holding variables for array
        # elements), since this is the time-critical part.
        
        set allData {}
        set min $useNodes($winId,min)
        set range [expr $useNodes($winId,max)-$useNodes($winId,min)]
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set nswatches $useNodes($winId,nswatches)
        
        for {set row 1} {$row<=$nrow} {incr row} {
            set rowData($row) {}
            for {set col 1} {$col<=$ncol} {incr col} {
                set cell [expr ($row-1)*$ncol+$col-1]
                set celval [lindex [lindex $values $cell] 1]
                set length [llength $celval]
                
                if {$length} {
                    if {$length>1} {set celval [lindex $celval 1]}
                    if {$celval<$useNodes($winId,dataMin)} {
                        set useNodes($winId,dataMin) $celval
                    }
                    if {$celval>$useNodes($winId,dataMax)} {
                        set useNodes($winId,dataMax) $celval
                    }
                    if [catch {set icolour [expr {int($nswatches*($celval-$min)/$range)}]}] {
                        return
                    }
                    
                    if {$icolour < 0} {
                        set icolour 0
                    } elseif {$icolour > $nswatches} {
                        set icolour $nswatches
                    }
                    lappend rowData($row) $useNodes($winId,c$icolour)
                } else {
                    lappend rowData($row) grey
                }
            }
        }
        
        for {set row $nrow} {$row>=1} {incr row -1} {
            lappend allData $rowData($row)
        }
        
        $useNodes($winId,hiddenMap) put $allData
        set useNodes($winId,range) $range
    }
    
    proc DrawGrid7 {winId node} {
        variable useNodes
        
        
        # do not use image mode for inputs cos we will want to edit them
        if {[string equal INPUT [GetModelEval $node]] ||
            [catch {GetBinaryModelValue $node $useNodes($winId,min) \
                        $useNodes($winId,max)} useNodes($winId,rawBinary)]} {
            DrawGrid5 $winId $node
            return
        }
        set rows $useNodes($winId,nrow)
        set cols $useNodes($winId,ncol)
        
        
        
        #Method
        #set bitCols [expr 4*int(($cols+3)/4)]
        #set fullSize [expr 1078+$bitCols*$rows]
        # bmp header; BITMAPINFOHEADER
        #set bmpData [binary format a2is2iiiissiiiiii \
        #        BM $fullSize {0 0} 1078 40 $cols $rows 1 8 0 0 0 0 0 0]
        #        # palette
        # for {set rgbQuad 0} {$rgbQuad<256} {incr rgbQuad} {
        # set colourIndex [expr $rgbQuad*($useNodes($winId,nswatches)+1)/256]
        # set colourStr [Desystematize $useNodes($winId,c$colourIndex)]
        # append bmpData [binary format H2H2H2c \
        # [string range $colourStr 9 12] \
        # [string range $colourStr 5 8] \
        # [string range $colourStr 1 4] 0]
        # }
        # set filling [string repeat 0 [expr $bitCols-$cols]]
        # if {[string length $filling]} {
        # for {set row 0} {$row<$rows} {incr row} {
        # append bmpData [string range $useNodes($winId,rawBinary) \
        # [expr $row*$cols] [expr $row*$cols+$cols-1]] $filling
        # }
        # } else {
        # append bmpData $useNodes($winId,rawBinary)
        # }
        #$useNodes($winId,hiddenMap) configure -data $bmpData
        
        ################################################################################
        # OGL image as texture
        #         set texSize [expr $rows*$cols]
        #         set ::texType $::GL_RED; #1 byte?? # $::GL_RGB
        #
        #         set ::texImg [tcl3dVectorFromByteArray GLubyte $useNodes($winId,rawBinary)]
        ################################################################################
    }
    
    
    proc DrawGrid6 {winId node} {
        variable useNodes
        
        
        # do not use image mode for inputs cos we will want to edit them
        if {[string equal INPUT [GetModelEval $node]] ||
            [catch {GetBinaryModelValue $node $useNodes($winId,min) \
                        $useNodes($winId,max)} useNodes($winId,rawBinary)]} {
            DrawGrid5 $winId $node
            return
        }
        set rows $useNodes($winId,nrow)
        set cols $useNodes($winId,ncol)
        set bitCols [expr 4*int(($cols+3)/4)]
        set fullSize [expr 1078+$bitCols*$rows]
        set bmpData [binary format a2is2iiiissiiiiii \
                BM $fullSize {0 0} 1078 40 $cols $rows 1 8 0 0 0 0 0 0]
        for {set rgbQuad 0} {$rgbQuad<256} {incr rgbQuad} {
            set colourIndex [expr $rgbQuad*($useNodes($winId,nswatches)+1)/256]
            set colourStr [Desystematize $useNodes($winId,c$colourIndex)]
            append bmpData [binary format H2H2H2c \
                    [string range $colourStr 9 12] \
                    [string range $colourStr 5 8] \
                    [string range $colourStr 1 4] 0]
        }
        set filling [string repeat 0 [expr $bitCols-$cols]]
        if {[string length $filling]} {
            for {set row 0} {$row<$rows} {incr row} {
                append bmpData [string range $useNodes($winId,rawBinary) \
                        [expr $row*$cols] [expr $row*$cols+$cols-1]] $filling
            }
        } else {
            append bmpData $useNodes($winId,rawBinary)
        }
        $useNodes($winId,hiddenMap) configure -data $bmpData
    }
    
    proc zoomio {winId factor} {
        variable useNodes
        set view [$winId.c xview]
        set xmiddle [expr ([lindex $view 0]+[lindex $view 1])/2]
        set view [$winId.c yview]
        set ymiddle [expr ([lindex $view 0]+[lindex $view 1])/2]
        set next [expr round($factor*$useNodes($winId,mult))]
        if {$next==$useNodes($winId,mult)} {
            if $factor>1 {
                incr useNodes($winId,mult)
            } else {
                incr useNodes($winId,mult) -1
            }
        } else {
            set useNodes($winId,mult) $next
        }
        if {$useNodes($winId,mult)==1} {
            $winId.bbframe.buttonBox itemconfigure 3 -state disable
            # disable zoom out button
        } else {
            $winId.bbframe.buttonBox itemconfigure 3 -state normal
        }
        
        $winId.c configure -scroll "0 0 \
                [expr $useNodes($winId,ncol)*$useNodes($winId,mult)] \
                [expr $useNodes($winId,nrow)*$useNodes($winId,mult)+40]"
        set view [$winId.c xview]
        $winId.c xview moveto [expr $xmiddle-([lindex $view 1]-[lindex $view 0])/2]
        set view [$winId.c yview]
        $winId.c yview moveto [expr $ymiddle-([lindex $view 1]-[lindex $view 0])/2]
        recolour_scale [namespace current] $winId
        UpdateState $winId
    }
    
    proc ScrollPhoto {winId axis args} {
        #	puts $visible
        variable useNodes
        
        if {[string match h $axis]} {
            FillCanvas $winId
        }
        eval {$winId.${axis}scroll set} $args
        reposn_scale [namespace current] $winId
    }
    
    proc FillCanvas {winId} {
        variable useNodes
        
        #        set visible [concat [$winId.c xview] [$winId.c yview]]
        set dataL [expr [lindex $visible 0]*$useNodes($winId,ncol)]
        set dataR [expr int(ceil([lindex $visible 1]*$useNodes($winId,ncol)))]
        set dataT [expr [lindex $visible 2]*$useNodes($winId,nrow)]
        set dataB [expr int(ceil([lindex $visible 3]*$useNodes($winId,nrow)))]
        #        $winId.c coords 1 \
        [$winId.c canvasx [expr -fmod($dataL,1)*$useNodes($winId,mult)]] \
                [$winId.c canvasy [expr -fmod($dataT,1)*$useNodes($winId,mult)]]
        #puts "Displaying $dataL $dataT $dataR $dataB"
        $useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
                -from [expr int($dataL)] [expr int($dataT)] $dataR $dataB -to 0 0 \
                -zoom $useNodes($winId,mult) -shrink
    }
    
    #### Handle value popup
    proc value_popup {winId X Y x y} {
        variable useNodes
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set col [expr int(1+([$winId.c canvasx $x])/$useNodes($winId,mult))]
        set row [expr int(1+$nrow-([$winId.c canvasy $y])/$useNodes($winId,mult))]
        if {$row>0&&$row<=$nrow&&$col>0&&$col<=$ncol} {
            if {![winfo exists .popup]} {
                toplevel .popup -width 1 -height 1 -bd 2 -relief raised
                wm overrideredirect .popup 1
                pack [message .popup.message -aspect 400 -bg \#ffffc0] \
                        -fill x -expand true
                raise .popup
            }
            set cell [expr ($row-1)*$ncol+$col-1]
            if {[info exists useNodes($winId,values)]} {
                set vLine [lindex $useNodes($winId,values) $cell]
                set value [TransValue $useNodes($winId,dataETs) \
                        [lindex $vLine 1]]
                set index [join [TransEnums $useNodes($winId,allETs) \
                        [lindex $vLine 0]] ,]
                .popup.message config -text "Index=$index\nCol,row=($col,$row)\nValue=$value"
            } else { # get approx value from raw data
                binary scan $useNodes($winId,rawBinary) x${cell}H2 hexo
                set numValue [expr $useNodes($winId,min)+0x$hexo*(1+$useNodes($winId,range))/256]
                set value [TransValue $useNodes($winId,dataETs) $numValue]
                #puts "dot $hexo min $useNodes($winId,min) range $useNodes($winId,range)"
                .popup.message config -text "Col,row=($col,$row)\nValue=$value"
            }
            set xpoint [expr $X+15]
            set ypoint [expr $Y+43]
            wm geometry .popup +$xpoint+$ypoint
            update
        }
    }
    
    proc ChangeValue {winId newVal x y } {
        variable useNodes
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set col [expr int(1+([$winId.c canvasx $x])/$useNodes($winId,mult))]
        set row [expr int(1+$nrow-([$winId.c canvasy $y])/$useNodes($winId,mult))]
        if {$row>0&&$row<=$nrow&&$col>0&&$col<=$ncol} {
            set cell [expr ($row-1)*$ncol+$col-1]
            set vLine [lindex $useNodes($winId,values) $cell]
            PokeValue $useNodes($winId,color) [lindex $vLine 0] $newVal
            #	DrawGrid7 $winId $useNodes($winId,color)
            #	DrawGrid6 $winId $useNodes($winId,color)
            $useNodes($winId,hiddenMap) put $useNodes($winId,paintColour) \
                    -to [expr $col-1] [expr $nrow-$row]
            FillCanvas $winId
        }
    }
    
    # need to recode for this legend
    proc ColourScale {winData winId} {
        #    ShowMessage debug info "proc ColourScale" ok
        upvar 1 $winData useNodes
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            $winId.legend.pop$swatch configure -bg $useNodes($winId,c$swatch)
        }
    }
    
    
    proc SaveAsFile {winId} {
        variable useNodes
        # should have dialog to set for options
        set filename [ChooseFile image.gif "Save image as:" 1]
        if {[string length $filename]} {
            $useNodes($winId,visibleMap) write $filename \
                    -format [string range [file extension $filename] 1 end]
        }
    }
} ;
# end of namespace
