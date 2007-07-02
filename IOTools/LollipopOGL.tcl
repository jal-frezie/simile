lappend ::auto_path "C:/Program Files/Tcl/lib"; # todo remove sort installation
package require tcl3d 0.3

# doesn't work if no trees at time zero OK NOW??
# only handles one set of obj
# show key: a list of opengl commands
# grid
# axis
# zoom in a out --- really want to change distance NOT perspective

# use display lists


set keyValue OGLLollipop070629

namespace eval ::$keyValue {
    variable useNodes
    variable colours {\#00ff00 \#f1da7e \#36b694 \#ec9844 \#94a646 \#d9d095}
    variable base -25
    
    variable quadric
    variable cx
    variable cy
    
    # Show errors occuring in the Togl callbacks.
    ###############################################################################
    proc bgerror { msg } {
        tk_messageBox -icon error -type ok -message "Error: $msg\n\
                namespace [namespace current] [namespace children ::]"
        ExitProg
    }
    ###############################################################################
    
    
    proc identify {} {
        return "OpenGL Lollipop diagram"
    }
    
    proc printString { str font } {
        glListBase $font
        set len [string length $str]
        set sa [tcl3dVectorFromString GLubyte $str]
        glCallLists $len GL_UNSIGNED_BYTE $sa
        $sa delete
    }
    
    # Resize And Initialize The GL Window
    proc tclReshapeFunc { toglwin  w h } {
        # Prevent A Divide By Zero By
        if { $h == 0 } {
            set h 1
        }
        glViewport 0 0 $w $h        ; # Reset The Current Viewport
        glMatrixMode GL_PROJECTION  ; # Select The Projection Matrix
        glLoadIdentity              ; # Reset The Projection Matrix
        
        # Calculate The Aspect Ratio Of The Window
        gluPerspective 10.0 [expr double($w)/double($h)] 1.0 100.0
        
        glMatrixMode GL_MODELVIEW   ; # atrix op to be on the Modelview Matrix
        glLoadIdentity              ; # Reset The Modelview Matrix
        
        gluLookAt 0.0 0.0 70.0 0.0 0.0 0.0 0.0 1.0 0.0
    }
    
    # All Setup For OpenGL Goes Here
    proc tclCreateFunc { toglwin } {
        variable trunks
        set trunks {}
        #ShowMessage debug info tclCreateFunc ok
        # set ::OGLLollipop070625::xdist($toglwin) 0
        # set ::OGLLollipop070625::ydist($toglwin) 0
        # set ::OGLLollipop070629::zdist($toglwin) 70
        set ::OGLLollipop070629::xRotate($toglwin) -55.0; #0.0
        # set ::OGLLollipop070629::yRotate($toglwin) 0.0
        set ::OGLLollipop070629::zRotate($toglwin) 30.0
        
        glClearColor 1.0 1.0 1.0 0.0            ; # White Background
        glClearDepth 1.0                        ; # Depth Buffer Setup
        glDepthFunc GL_LEQUAL                   ; # The Type Of Depth Testing To Do
        glEnable GL_DEPTH_TEST                  ; # Enables Depth Testing
        #glShadeModel GL_FLAT                    ; # Select Flat Shading
        glShadeModel GL_SMOOTH                  ; # Select smooth Shading
        # Set Perspective Calculations To Most Accurate
        glHint GL_PERSPECTIVE_CORRECTION_HINT GL_NICEST
        
        set ::OGLLollipop070629::quadric($toglwin) [gluNewQuadric]           ; # Create A Pointer To The Quadric Object
        gluQuadricNormals $::OGLLollipop070629::quadric($toglwin) GLU_SMOOTH ; # Create Smooth Normals
        gluQuadricTexture $::OGLLollipop070629::quadric($toglwin) GL_TRUE    ; # Create Texture Coords
        
        glEnable GL_LIGHT0                      ; # Enable Default Light
        glEnable GL_LIGHTING                    ; # Enable Lighting
        
        glEnable GL_COLOR_MATERIAL              ; # Enable Color Material
        
        # Could load 3D model definitions specified using OpenGL/Tcl
        # stored in a dir
        
        # pre-build lollipop shape using a display list
        set ::OGLLollipop070629::ThreeDModel($toglwin,lollipop) [glGenLists 1]
        glNewList $::OGLLollipop070629::ThreeDModel($toglwin,lollipop) GL_COMPILE
            # draw in brown
            glColor3f 0.45 0.06 0.02
            
            # draw a cylinder at the local origin to represent the trunk 
            # gluCylinder quad  , radius base  , radius top  , height  , slices  , stacks
            gluCylinder $::OGLLollipop070629::quadric($toglwin) 0.05 0.05 0.9 15 5
            #draw a disk at the local origin to close the cylinder at the bottom
            gluDisk $::OGLLollipop070629::quadric($toglwin) 0.0 0.05 15 5
            
            #move the local origin (where next figure will be placed)
            #to the top of the cylinder (trunk)
            glTranslatef 0.0 0.0 0.9
            
            #draw in green (tree crown), rgb with translucency alpha or a value
            glColor4f 0.1 0.5 0.1 0.1
            
            #draw sphere to represent the tree crown
            gluSphere $::OGLLollipop070629::quadric($toglwin) 0.3 20 20
        glEndList
        
        # pre-build cone-tree shape using a display list
        set ::OGLLollipop070629::ThreeDModel($toglwin,conetree) [glGenLists 2]
        glNewList $::OGLLollipop070629::ThreeDModel($toglwin,conetree) GL_COMPILE
            # draw in brown
            glColor3f 0.45 0.06 0.02
            
            # draw a cylinder at the local origin to represent the trunk
            # gluCylinder quad  , radius base  , radius top  , height  , slices  , stacks
            gluCylinder $::OGLLollipop070629::quadric($toglwin) 0.05 0.05 0.9 15 5
            #draw a disk at the local origin to close the cylinder at the bottom
            gluDisk $::OGLLollipop070629::quadric($toglwin) 0.0 0.05 15 5
            
            #move the local origin (where next figure will be placed)
            #to the top of the cylinder (trunk)
            glTranslatef 0.0 0.0 0.9
            
            #draw in green (tree crown), rgb with translucency alpha or a value
            glColor4f 0.1 0.5 0.1 0.1
            
            #draw cone to represent the tree crown
            gluCylinder $::OGLLollipop070629::quadric($toglwin) 0.3 0.0 0.9 15 5
        glEndList
    }
    
    #ShowMessage debug info "date  $x $y $ht" ok
    #
    # write the co-ord in text
    #glRasterPos2i 2 0
    #set fontBase [$toglwin loadbitmapfont]
    #printString "$x $y $ht" $fontBase

    proc tclDisplayFunc { toglwin } {
        glClear [expr $::GL_COLOR_BUFFER_BIT | $::GL_DEPTH_BUFFER_BIT]
        
        
        #set lollipop $::OGLLollipop070629::lollipop($toglwin)
        set first [lindex $::OGLLollipop070629::trunks 0]
        # set fontBase [$toglwin loadbitmapfont]
        # glRasterPos2f -4.5 -4.5
        # printString "Hello" $fontBase
        # glRasterPos2f -4.5 -4.6
        # printString "No. trees: [expr {[llength $first]/2.0}]" $fontBase
        
        # complex pointer if no trees so list has to have one more than "nil" pointer
        if {[llength $first]>2} {
            
            #viewing transformation commands must be
            #called before any modeling transformations are performed
            # ................
            set winId [winfo parent $toglwin]
            glPushMatrix
            glRotatef $::OGLLollipop070629::xRotate($toglwin) 1.0 0.0 0.0
            glRotatef $::OGLLollipop070629::zRotate($toglwin) 0.0 0.0 1.0
            
            #foreach set of object to display
            # for now only have one set so no foreach
            #############set first [lindex $::OGLLollipop070629::trunks 0]
            #ShowMessage debug info "first $first" ok
            foreach {index data} $first {
                foreach {x y ht} $data {}
                
                glPushMatrix
                
                #########################
                # SCALED FOR model X AND Y TO BE 0 TO 100
                # TO FIT IN 5 X 5
                #########################
                # move to object's location
                glTranslatef [expr {$x/20.0}] [expr {$y/20.0}] 0.0;
                
                set s [expr {$ht/20.0}]
                # scale using $ht
                # scale to object
                glScalef $s $s $s
                
                #could rotate object
                #2D e.g. land animal, 3D flying or swimming animal
                
                #glCallList $lollipop
                #glCallList $::OGLLollipop070629::ThreeDModel($toglwin,lollipop)
                glCallList $::OGLLollipop070629::ThreeDModel($toglwin,conetree)
                
                glPopMatrix
            }
            
            
            glPopMatrix
            
            #.................................
            
        }
        glFlush
        $toglwin swapbuffers
    }
    
    proc initialize {winId} {
        variable useNodes
        variable trunks
        variable base
        namespace import -force ::maptools2::*
        set toolbarItems [list \
                [list new.gif "Clear" \
                [namespace code "clear $winId"]] \
                [list add.gif "Add a variable" \
                [namespace code "AddVariable $winId"]]]
        
        ::graphtools::MakeToolBar $winId $toolbarItems
        pack [message $winId.intro -aspect 800] -fill x
        variable grid
        variable viewVector
        set pi 3.14
        array set viewVector [list $winId,angle -0.3 $winId,elevation 0.5 \
                $winId,cos_angle 1 $winId,cos_elevation 1 \
                $winId,sin_angle -0.3 $winId,sin_elevation 0.5]
        # scale $winId.elv -orient v -from [expr $pi/2] -to [expr -$pi/2] \
        # -resolution 0.01 \
        # -command [namespace code "TweakScale $winId elevation"]
        scale $winId.elv -orient v -from 180 -to -180 \
                -resolution 1.0 \
                -command [namespace code "TweakScale $winId elevation"]
        $winId.elv set -40.0
        #jmcanvas $winId.c -width 1 -height 1 -bg white
        togl $winId.c -width 500 -height 500\
                -double true -depth true \
                -createproc [namespace code tclCreateFunc] \
                -reshapeproc [namespace code tclReshapeFunc] \
                -displayproc [namespace code tclDisplayFunc]
        
        frame $winId.buttons -relief raised -bd 1
        button $winId.buttons.but_print -text "Print..." \
                -command "PrintNow $winId.c"
        pack [label $winId.buttons.anglab -text "View angle:"] -side left
        scale $winId.buttons.ang -orient h -from -180 -to 180 \
                -resolution 1.0 \
                -command [namespace code "TweakScale $winId angle"]
        $winId.buttons.ang set -30.0
        pack $winId.buttons.ang -side left -fill x -expand true
        pack [label $winId.buttons.elvlab -text "View\nelev."] -side right
        pack $winId.buttons.but_print -side right
        pack $winId.buttons -side bottom -fill x
        pack $winId.elv -side right -fill y
        pack $winId.c -fill both -expand true
        
        #jm bind $winId.c <Configure> \
        #jm        [namespace code " WindowSizeChanged $winId"]
        
        ################################################################################
        #         #Grid is always displayed so only define it once
        #         set grid {}
        #         for {set x -50} {$x <= 50} {incr x 10} {
        #             lappend grid [list line {} "$x -50 $base" "$x 50 $base" 1 red]\
        #                     [list text "X posn" "$x -60 $base" [expr $x+50] red] \
        #                     [list text "X posn" "$x 60 $base" [expr $x+50] red]
        #         }
        #         for {set y -50} {$y <= 50} {incr y 10} {
        #             lappend grid [list line {} "-50 $y $base" "50 $y $base" 1 red]\
        #                     [list text "Y posn" "-60 $y $base" [expr $y+50] blue] \
        #                     [list text "Y posn" "60 $y $base" [expr $y+50] blue]
        #         }
        #         for {set z 10} {$z <= 50} {incr z 10} {
        #             set zposn [expr $base+2*$z]
        #             lappend grid [list text "Z posn" "-50 -50 $zposn" $z black] \
        #                     [list text "Z posn" "-50 50 $zposn" $z black] \
        #                     [list text "Z posn" "50 50 $zposn" $z black] \
        #                     [list text "Z posn" "50 -50 $zposn" $z black]
        #         }
        ################################################################################
        
        SetState $winId initial
        set useNodes($winId,selected) {}
        set useNodes($winId,captions) {}
        set trunks {}
        catch {wm geometry $winId 650x500}
        set viewVector($winId,X) [winfo width $winId.c]
        set viewVector($winId,Y) [winfo height $winId.c]
    }
    
    proc GetCanvas {winId} {
        return {}
        #return $winId.c
    }
    
    proc clear {winId} {
        # variable useNodes
        # set useNodes($winId,selected) {}
        # set useNodes($winId,captions) {}
        # display $winId 0 0 0
        # ShowKey $winId
    }
    
    proc reset {winId} {
    }
    
    proc AddVariable {winId} {
        $winId.intro configure -text "Click on the array value representing the X coordinates of the treelike objects to be displayed."
        GrabClicks $winId
        SetState $winId xcoord
    }
    
    proc click {winId node caption} {
        variable useNodes
        set ms $winId.intro
        set testResult [GetModelValue $node]
        if {[string compare $testResult novalue]} {
            lappend useNodes($winId,selected) $node
            lappend useNodes($winId,captions) $caption
            set state [GetState $winId]
            switch $state {
                xcoord {
                    $ms configure -text "Now click on the value representing the Y coordinates."
                    SetState $winId ycoord
                }
                ycoord {
                    $ms configure -text "Now select a value to display as the size of the objects."
                    SetState $winId sizeval
                }
                sizeval {
                    ReleaseClicks $winId
                    $ms configure -text {}
                    SaveState $winId
                    display $winId 0 0 0
                    #ShowKey $winId
                }
            }
        } else {
            $ms configure -text \
                    "This component does not have a value; please choose a compartment, variable or flow."
        }
    }
    
    proc SaveState {winId} {
        variable useNodes
        variable viewVector
        set state displaying
        lappend state $viewVector($winId,angle) $viewVector($winId,elevation)
        foreach node $useNodes($winId,selected) {
            lappend state [GetCaptionPathFromId $node]
        }
        SetState $winId $state
    }
    
    proc Restore {winId} {
        variable useNodes
        set state [GetState $winId]
        initialize $winId
        if {[string match displaying [lindex $state 0]]} {
            $winId.buttons.ang set [lindex $state 1]
            foreach node [lrange $state 3 end] {
                lappend useNodes($winId,selected) [GetIdFromCaptionPath $node]
                lappend useNodes($winId,captions) [lindex [split $node /] end]
            }
            LoadPosns $winId
            $winId.elv set [lindex $state 2]
        } else {
            GrabClicks $winId
        }
        SaveState $winId
    }
    
    proc TweakScale {winId which where} {
        variable viewVector
        set viewVector($winId,$which) $where
        SaveState $winId
        
        set viewVector($winId,cos_angle) [expr cos($viewVector($winId,angle))]
        set viewVector($winId,sin_angle) [expr sin($viewVector($winId,angle))]
        set viewVector($winId,cos_elevation) \
                [expr cos($viewVector($winId,elevation))]
        set viewVector($winId,sin_elevation) \
                [expr sin($viewVector($winId,elevation))]
        #jm WindowSizeChanged $winId
        set ::OGLLollipop070629::xRotate($winId.c) $viewVector($winId,elevation)
        set ::OGLLollipop070629::zRotate($winId.c) $viewVector($winId,angle)
        $winId.c postredisplay
    }
    
    proc display {winId time step remainder} {
        variable trunks
        LoadPosns $winId
        #ShowMessage debug info "display $trunks" ok
        if {[winfo exists $winId.c]} {
            $winId.c postredisplay
        }
    }
    
    proc LoadPosns {winId} {
        #ShowMessage debug info "proc LoadPosns" ok
        variable useNodes
        variable trunks
        #variable colours
        #variable base
        
        set col 0
        set trunks {}
        foreach {px py h} $useNodes($winId,selected) {
            set quadlist {}
            GetQuadList {} [lindex [GetModelValue $px] 0] \
                    [lindex [GetModelValue $py] 0] \
                    [lindex [GetModelValue $h] 0]
            lappend trunks $quadlist
        }
    }
    
    proc ShowKey {winId} {
        # translate x y z
        # draw lolipop dislay list
        #set fontBase [$toglwin loadbitmapfont]
        #printString "$x $y 0" $fontBase
    }
    
    proc ObsShowKey {winId} {
        variable useNodes
        variable colours
        variable viewVector
        
        set col 0
        set atx 20
        set aty $viewVector($winId,Y)
        
        $winId.c delete -withtag key
        foreach {x y sz} $useNodes($winId,captions) {
            $winId.c create line $atx $aty $atx [expr $aty-16] -width 4 \
                    -fill brown -tag key
            $winId.c create oval [expr $atx-8] [expr $aty-32] [expr $atx+8] \
                    [expr $aty-16] -fill [lindex $colours $col] -tag key
            $winId.c create text [expr $atx+16] $aty -anchor sw -tag key \
                    -text "z: $sz\nx: $x\ny: $y"
            incr col
            incr atx 100
        }
    }
}