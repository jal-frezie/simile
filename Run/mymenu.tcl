# first problem: widget for mymenu must be a child of parent's
# toplevel window, so it can be placed anywhere inside. Two opts: (i)
# de-dot the path and hope the result not used, (ii) brew a random new
# pathname. Since the pathname will be different either way, try the
# latter first.

# V2: Using the system library bindings for menus is proving less than
# helpful, because if label widgets are used for the entries the
# frame's bindings are not activated when things happen inside
# them. If I get rid of them I can leave the frame's own command where
# it is as I won't try to do anything inappropriate to it

# Entry widgets are siblings of the menu, which grabs while mouse is inside,
# so they never get events.

#bind Mymenuentry <Enter> {%W configure -state active -relief raised}
#bind Mymenuentry <Leave> {%W configure -state normal -relief flat}
#bind Mymenuentry <Button> {focus [winfo parent %W]}
#bind Mymenuentry <ButtonRelease> {DoCommand %W}

# v4: the labels that make up the entries have bindings that forward
# events to the frame, so drags can go from one to another.

bind Mymenu <Motion> {MymenuMotion %W %X %Y}
bind Mymenu <ButtonRelease> {DoCommand %W}

proc HitWidget {win x y} {
#puts "mmm $win $X $Y"
    return [expr {$x>=0 && $x<[winfo width $win] && \
                      $y>=0 && $y<[winfo height $win]}]
}

proc MymenuMotion {win X Y} {
    global mymenuCmds

#puts "mmm $win $X $Y"
    set x [expr {$X-[winfo rootx $win]}]
    set y [expr {$Y-[winfo rooty $win]}]
    if {[HitWidget $win $x $y]} {
        mymenuCmd $win activate @$x,$y
    } else {
        set nowActive [ResolveIndex $win active]
        if {[string equal none $nowActive]} {
            mymenuCmd $win activate none
        } elseif {[string equal cascade $mymenuCmds($nowActive,type)]} {
            MymenuMotion [GetButtonMenu $nowActive] $X $Y
        } else {
            mymenuCmd $win activate none
        }
    }
}

proc mymenu {w args} {
    global mymenuCmds

    frame $w
    rename $w ${w}cmd
    set mymenuCmds($w) [randchild [winfo toplevel $w]]
    frame $mymenuCmds($w) -bd 2 -relief raised -class Mymenu
    proc $w {args} [subst {return \[eval mymenuCmd $mymenuCmds($w) \$args\]}]
    return $w
}

proc randchild {base} {
    if {[string equal . $base]} {
        set base {}
    }
    return [format %s.%07x%07x $base \
                [expr int(rand()*268435456)] [expr int(rand()*268435456)]]
}

proc ResolveIndex {myw spec} {
    global mymenuCmds

    if {[string is integer -strict $spec]} {
        return [lindex [pack slaves $myw] $spec]
    } elseif {[string equal last $spec]||[string equal end $spec]} {
        return [lindex [pack slaves $myw] end]
    } elseif {[string equal active $spec]} {
        foreach entry [pack slaves $myw] {
            if {![string equal separator $mymenuCmds($entry,type)]} {
                if {[string equal active [$entry cget -state]]} {
                    return $entry
                }
            }
        }
        return none
    } elseif {[scan $spec @%d,%d x y]==2} {
        set rootx [expr $x+[winfo rootx $myw]]
        set rooty [expr $y+[winfo rooty $myw]]
        return [winfo containing $rootx $rooty]
    } else {
        foreach entry [pack slaves $myw] {
            if {[string match $spec [$entry cget -text]]} {
                return $entry
            }
        }
        error "bad menu entry index \"$spec\""
    }
}

proc EnumIndex {myw spec} {
    if {[string is integer -strict $spec]} {
        return $spec
    } elseif {[string equal last $spec]||[string equal end $spec]} {
        return [expr {[llength [pack slaves $myw]]-1}]
    } else {
        return [lsearch [pack slaves $myw] [ResolveIndex $myw $spec]]
    }
}

proc mymenuCmd {myw act args} {
    global mymenuCmds
#    puts [concat $act $args]
    switch $act {
        activate {
            if {[string equal none [lindex $args 0]]} {
                set subWin none
            } else {
                set subWin [ResolveIndex $myw [lindex $args 0]]
            }
            foreach entry [pack slaves $myw] {
                if {![string equal separator $mymenuCmds($entry,type)]} {
                    if {[string equal $subWin $entry]} {
                        $entry configure -state active -relief raised
                    } else {
                        $entry configure -state normal -relief flat
                    }

                    if {[string equal cascade $mymenuCmds($entry,type)]} {
                        if {[string equal $subWin $entry]} {
                            PostCascadeFor $entry
                        } else {
                            $mymenuCmds($entry) unpost
                        }
                    }
                }
            }
        } add {
            switch -regexp [lindex $args 0] {
                command|cascade {
                    pack [set new [label [randchild $myw] -anchor w]] -fill x
                } separator {
                    pack [set new [frame [randchild $myw] -height 2 -bd 1 \
                                       -relief sunken]] -fill x
                } default {
                    error "bad menu entry type \"[lindex $args 0]\": must be cascade, command or separator"
                }
            }
            bind $new <Motion> [list MymenuMotion $myw %X %Y]
            if {[string equal command [lindex $args 0]]} {
                bind $new <Leave> [list mymenuCmd $myw activate none]
            }
            bind $new <ButtonRelease> [list DoCommand $myw]
            set opts [checkAddOpts $new [lindex $args 0] [lrange $args 1 end]]
            eval {$new config} $opts
        } cget {
            switch -- [lindex $args 0] {
                -type {
                    return normal
                } default {
                    return [eval {$myw $act} $args]
                }
            }
        } configure {
            return [eval {$myw $act} $args]
        } delete {
            set startDel [EnumIndex $myw [lindex $args 0]]
            if {[llength $args]>1} {
                set endDel [EnumIndex $myw [lindex $args 1]]
            } else {
                set endDel startDel
            }
            set entries [pack slaves $myw]
            for {set zap $startDel} {$zap<=$endDel} {incr zap} {
                destroy [lindex $entries $zap]
            }
        } entrycget {
            set child [ResolveIndex $myw [lindex $args 0]]
            return [eval {$child cget} [lrange $args 1 end]]
        } index {
            return [EnumIndex $myw [lindex $args 0]]
        } insert {
            set goesAfter [ResolveIndex $myw [lindex $args 0]]
            eval {mymenuCmd $myw add} [lrange $args 1 end]
            # it will be last -- now move to right place
            pack configure [lindex [pack slaves $myw] end] -before $goesAfter
        } postcascade {
        } post {
            set surround [winfo parent $myw]
            set x [expr {[lindex $args 0]-[winfo rootx $surround]}]
            set y [expr {[lindex $args 1]-[winfo rooty $surround]}]
            place $myw -x $x -y $y -anchor nw
            raise $myw
            grab $myw
        } type {
            return $mymenuCmds([ResolveIndex $myw [lindex $args 0]],type)
        } unpost {
            place forget $myw
        } yposition {
            return [expr {[winfo rooty [ResolveIndex $myw [lindex $args 0]]] \
                              - [winfo rooty $myw]}]
        } default {
            error "bad option \"$act\": must be activate, add, cget, configure or post"
        }
    }
}

proc checkAddOpts {lab type argList} {
    global mymenuCmds
    set res {}
    foreach {option value} $argList {
        switch -regexp -- $option {
            -label {
                lappend res -text $value
            } -command {
                set mymenuCmds($lab) $value
            } -menu {
                set mymenuCmds($lab) $value
            } default {
                lappend res $option $value
            }
        }
    }
    set mymenuCmds($lab,type) $type
    return $res
}

proc DoCommand {win} {
    global mymenuCmds
    set entry [ResolveIndex $win active]
    if {![string equal none $entry]} {
        switch $mymenuCmds($entry,type) {
            command {
                if {[info exists mymenuCmds($entry)]} {
                    uplevel \#0 $mymenuCmds($entry)
                }
            } cascade {
                DoCommand [GetButtonMenu $entry]
            }
        }
    }
    place forget $win
}

# Next section defines mymenubutton, which acts not unlike the Tk
# menubutton, but uses mymenu. In order to be able to post the menu
# and drag along it, it will forward drag actions to the menu once
# posted. This should not be hard.

proc mybutton {w args} {
    set labOpts [checkAddOpts $w button $args]
    eval {label $w} -padx 4 -pady 4 -relief raised $labOpts
    bind $w <Button> [list PostMenuFor $w]
    bind $w <Motion> [list MybuttonMotion %W %X %Y]
    bind $w <ButtonRelease> [list MybuttonRelease %W %x %y]
    rename $w ${w}cmd
    proc $w {args} [subst {return \[eval mybuttonCmd $w \$args\]}]
    return $w
}

proc mybuttonCmd {w act args} {
    switch $act {
        configure {
            set labOpts [checkAddOpts $w button $args]
            eval {${w}cmd configure} $labOpts
        } default {
            eval {${w}cmd configure $act} $args
        }
    }
}

proc PostMenuFor {w} {
    global mymenuCmds

    set overCursor [::tk::MenuFindName $mymenuCmds($w) [${w}cmd cget -text]]
# more clever stuff later
    set boxLeft [winfo rootx $w]
    if {[string is integer -strict $overCursor]} {
# simpler than library version cos assumes button and menu text same height
        set boxTop [expr {[winfo rooty $w]-[$mymenuCmds($w) yposition $overCursor]}]
    } else {
        set boxTop [expr {[winfo rooty $w]+[winfo height $w]}]
    }        
#puts "gonna pop [GetButtonMenu $w]"
    tk_popup $mymenuCmds($w) $boxLeft $boxTop
}

proc PostCascadeFor {w} {
    global mymenuCmds

# more clever stuff later
    set boxLeft [expr {[winfo rootx $w]+[winfo width $w]}]
    set boxTop [winfo rooty $w]
    tk_popup $mymenuCmds($w) $boxLeft $boxTop
}

proc MybuttonMotion {w x y} {
    MymenuMotion [GetButtonMenu $w] $x $y
}

proc MybuttonRelease {w x y} {
    if {![HitWidget $w $x $y]} {
        DoCommand [GetButtonMenu $w]
    }
}

proc GetButtonMenu {b} {
    global mymenuCmds

    return $mymenuCmds($mymenuCmds($b))
}

# testing stuff

#mybutton .b -text "Cascading test" -menu .b.top
#mymenu .b.top
#.b.top add command -label Boring -command "puts boring"
#.b.top add cascade -label Interesting -menu .b.top.next
#.b.top add command -label Monotonous -command "puts yawn"
#.b.top add command -label Tedious -command "puts stretch"

#mymenu .b.top.next
#.b.top.next add command -label "Popty ping" -command "puts ping"
#.b.top.next add command -label "Popty pong" -command "puts pong"

#pack .b -fill x -anchor w
#pack [canvas .c -bg \#c0c0ff]
