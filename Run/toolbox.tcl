# Welcome to toolbox.tcl, the file containing the bits of tcl and tk
# needed to supply the graphical interface to the modelling environment.
# Just to give you an idea of (a) the sort of thing you can do in tcl,
# and (b) my preferred programming style, check this out....

package require BWidget

source ../Run/shapes.tcl
source ../Run/forms.tcl
source ../Run/prefs.tcl
source ../Run/runmodel.tcl
source ../Run/messages.tcl

# Find a new temporary directory
#if {[info exists env(TMP)]} {
#    set tempDir $env(TMP)
#} else {
#    if {[info exists env(TEMP)]} {
#	set tempDir $env(TEMP)
#    } else {
#	if {[string match windows $tcl_platform(platform)]} {
#	    set tempDir /temp
#	} else {
#	    set tempDir /tmp
#	}
#    }
#}

# Test new Windows printing technology -- see file for credits/licence
if {[string match windows $tcl_platform(platform)]} {
    #    set tempDir [file attributes $tempDir -shortname]
    #    set tempDir [file join [file dirname $tempDir] [file tail $tempDir]]
    
    #   pkg_mkIndex ../System/lib/Extras
    source ../System/lib/Extras/prntcanv.tcl
    
    # Make Simile a DDE server under Windows. Jonathan autotesting
    # Must be after the sourcing or Simile fails
    package require dde 1.2
    dde servername Simile
} elseif {[string match Linux $tcl_platform(os)]} {
    # avoid loading buggy Trf if ActiveTcl present on system
    # package ifneeded Trf 2.1 {}
}

set equationbar(current_action) null

proc NewTopLevel {} {
    MenuSelect dummy file new_toplevel
    #    set newInstance [interp create]
    #    $newInstance eval package require Tk
    #    $newInstance eval set argc 0
    #    $newInstance eval source ../Run/simile.tcl
    
}

proc OpenTopLevel {model} {
    MenuSelect dummy open_toplevel $model
    #    set newInstance [interp create]
    #    $newInstance eval package require Tk
    #    $newInstance eval set argc 1
    #    $newInstance eval [list set argv $model]
    #    $newInstance eval source ../Run/simile.tcl
}

proc AttackGlobalVariable {array elt val} {
    global $array
    #ShowMessage debug info "Setting $array$elt" ok
    set $array$elt $val
    return ;# because letting it return an array causes a crash
}

# Prolog typically calls this to make error handling prettier

proc FilterErrors {args} {
    global errorInfo
    set oldDir [pwd]
    if {[catch $args retVal]} {
	wm withdraw . ;# ensure error mess is not obscured by splash screen
        set ans [ShowMessage "Simile error" error "Simile encountered an unexpected problem:\n $retVal \nDo you want to see more information?" yesno]
        if {[string match yes $ans]} {
            BuildProblem unsaved none $errorInfo tcl
        }
        cd $oldDir
        return -1
    } else {
        return $retVal
    }
}

# Now to switch off all error reporting from Tcl (Unintended feature of
# Version 8.0p2, any image file will do)
# image create photo open -file "../Images/mailbox.gif"
# Actually I think not, it seems to prevent the window menu appearing as well

proc ShiftDll {Point Top Loc Rep} {
    if {[llength $Loc]} {
        set AddLoc /$Loc
    } else {
        set AddLoc $Loc
    }
    
    set base $Top/$Point$AddLoc
    file mkdir $base
    if {[llength $Rep]} {
        set prefx $base/model
        if {$Rep && [file exists ${prefx}${Rep}[info sharedlibextension]]} {
            file copy -force ${prefx}${Rep}[info sharedlibextension] \
                    ${prefx}[info sharedlibextension]
        } else {
            file delete -force ${prefx}[info sharedlibextension]
            file delete -force ${prefx}.tcl
        }
        #	foreach file [glob -nocomplain ${prefx}*] {
        #	    if {![string match ${prefx}.* $file]} {
        #		file delete $file
        #	    }
        #	}
    }
}

proc TrimTree {Top Point} {
    if {[llength $Point]} {
        foreach file [glob -nocomplain "$Top/$Point/*"] {
            file delete -force $file
        }
    } else {
        file delete -force [file rootname $Top]
    }
}

# this takes the spec for a model executable file and a list of user-defined
# functions. It gets the date on which the executable was made, then looks
# up which file contains the function definition (for procedures we assume
# that is the same base as the one containing its declaration) and drops out
# if the latter is newer

proc CheckFnsFresh {L progDir id userFnList} {
    global equation custom
    
    if {[string equal tcl $L]} {
        set procXtn .tcl
        set progFile $progDir/model.tcl
    } else {
        set procXtn .cpp
        set progFile $progDir/model${id}[info sharedlibextension]
    }
    set stat 0
    set files {}
    if {[file exists $progFile]} {
        set date [file mtime $progFile]
    } else {
        set date 0
    }
    foreach func $userFnList {
        set functor [lindex [split $func /] 0] ;# remove arity
        set posn [lsearch $equation(fnDefs) "{Macros *} $functor"]
        if {$posn == -1} {
            set posn [lsearch $equation(fnDefs) \
                    "{Procedures *} $functor * returns *"]
        }
        if {$posn == -1} {
            return "4 $func" ;# missing function declaration
            # should never happen because we read them when starting up
        } else {
            set fnSpec [lindex [lindex $equation(fnDefs) $posn] 0]
            set fnBase $custom(prefDir)/Functions/[lindex $fnSpec 1]
            if {[file mtime ${fnBase}.pl]>$date} {
                set stat [max $stat 2] ;# Declaration out of date
            }
            if {[string equal Procedures [lindex $fnSpec 0]]} {
                set file ${fnBase}$procXtn
                if {![file exists $file]} {
                    return "3 $func $file";# Missing or misplaced definition
                } else {
                    if {[lsearch $files $file]==-1} {
                        lappend files $file
                    }
                    if {[file mtime $file]>$date && ![string equal tcl $L]} {
                        set stat [max $stat 2] ;# Definition out of date
                        # no problem with tcl definitions, included at run time
                    }
                }
            }
        }
    }
    return [concat $stat $files]
}

# this exists in case I don't want to exploit the concat in eval
proc do_for_node {node args} {
    global runState
    if {![info exists runState($node,interp)]} {
        set runState($node,interp) [interp create]
        $runState($node,interp) alias BringParameter BringParameter
        $runState($node,interp) eval source ../Run/support.tcl
    }
    return [$runState($node,interp) eval $args]
}

proc KillInterpFor {node} {
    global runState
    if {[info exists runState($node,interp)]} {
        interp delete $runState($node,interp)
        unset runState($node,interp)
    }
}

proc LoadProgram {node lang} {
    global runState
    set runState($node,updated) 0
    set runState($node,lang) $lang
    if {[update_executable $node $lang]} {
        set runState($node,modelRunning) 2
        ToggleIOToolMenu $node
    }
}

proc CheckUpToDate {node action} {
    global runState window_info
    
    if {$runState($node,updated) == 1} {
        set updateChoice [ShowMessage "Model out of date" warning \
                "The model has been altered since the curent runnable version was built. Rebuild it now?" yesnocancel]
        switch $updateChoice {
            yes {
                # grits teeth
                foreach win [array names window_info *,top_node] {
                    if {[string equal $node $window_info($win)]} {
                        set winId [string range $win 0 end-9]
                        if {$window_info($winId,is_top_level)} {
                            return [Rerun $winId [string match start $action]]
                        }
                    }
                }
            } no {
                set runState($node,updated) 0 ;# do not ask again
            }
        }
        return $updateChoice
    } else {
        return
    }
}

proc ControlDraw {prologVersion} {
    global sendvars custom tcl_platform env userinfo openModel simtmpdir
    
    LoadIconImages
    
    # Defaults to use if debugging
    if {![info exists env(SIMILE_VERSION)]} {
        set env(SIMILE_VERSION) 4.0
        set env(licensee_name) "Support team"
        set env(licensee_corp) "Simulistics, inc."
        set env(license_code) default_license=072ccc96dced2bef53403afd67fe7782
    }
    
    set sendvars(simV) $env(SIMILE_VERSION)
    set sendvars(proV) $prologVersion
    
    # no longer have a separate floating toolbar
    
    # loading stub sets license entries
    load_c_stub
    
    # substitutes for license entries if we want to avoid loading stub
    #set userinfo(final_expiry) 0
    #set userinfo(days_after_install) 0
    #set userinfo(edn) standard
    
    # eezi-hack implementation of time limit: to do this anything like
    # properly, have stub dll check unix time against clock time
    
    set day [expr 24*60*60]
    if {$userinfo(final_expiry)} {
        set expTime $userinfo(final_expiry)
    }
    if {$userinfo(days_after_install)} {
        set installTime [lindex [lindex [split $env(install_time) =] 1] 0]
        set relExpTime [expr $installTime+$userinfo(days_after_install)*$day]
        if {$userinfo(final_expiry)} {
            set expTime [min $expTime $relExpTime]
        } else {
            set expTime $relExpTime
        }
    }
    if {[info exists expTime]} {
        set userinfo(exp_time) $expTime
        set toGo [expr $expTime-[clock seconds]]
        
        if {$toGo<0} {
            set crumble "This version of Simile has passed its expiry date."
            error $crumble
        } elseif {$toGo<7*$day} {
            #	    ShowMessage "Expiry imminent" warning "This version of Simile will expire on [clock format $expTime]. Please contact www.simulistics.com for an update." ok
            ShowExpiryImminent $expTime
        }
    }
    
    
    if {[file exists $env(HOME)]} {
        set custom(prefDir) [file join $env(HOME) .simile]
    } else {
        set custom(prefDir) [pwd]/../Prefs
    }
    
    if {![file exists $custom(prefDir)]} {
        file mkdir $custom(prefDir)
    }
    
    set simtmpdir $custom(prefDir)/sim
    set go [clock clicks]
    while {[file exists $simtmpdir]} {
        set guess_free [expr [clock clicks]-$go]
        set simtmpdir $custom(prefDir)/sim$guess_free
    }
    file mkdir $simtmpdir
    
    if {[file exists $custom(prefDir)/version]} {
        set UserStream [NetOpen $custom(prefDir)/version r]
        gets $UserStream userinfo(name)
        gets $UserStream userinfo(corp)
        gets $UserStream userinfo(oldVersion)
        gets $UserStream userinfo(done)
        close $UserStream
    } else {
        set userinfo(oldVersion) 0
        set userinfo(done) 0
    }
    
    set UserStream [NetOpen $custom(prefDir)/version w]
    puts $UserStream $userinfo(name)
    puts $UserStream $userinfo(corp)
    puts $UserStream $userinfo(Version)
    puts $UserStream $userinfo(done)
    close $UserStream
    
    set sendvars(running) 0
    
    set custom(hotlist) {}
    if {[file exists $custom(prefDir)/recent]} {
        set cacheStream [NetOpen $custom(prefDir)/recent r]
        while {[gets $cacheStream oldFile]>0} {
            if {[file exists $oldFile] && \
                        [lsearch $custom(hotlist) $oldFile]==-1} {
                lappend custom(hotlist) $oldFile
            }
        }
        close $cacheStream
    }
    if {[llength $custom(hotlist)]} {
        RecordPathChoice .sml [lindex $custom(hotlist) 0] 0
    }
    
    Pref_Init $custom(prefDir)/prefs ../Run/sysprefs
    Pref_Add {{custom(initNavbar) initNavbar ON "Tool bar"} \
                {custom(initToolbar) initToolbar ON "Component bar"} \
                {custom(initEqnbar) initEqnbar ON "Equation bar"} \
                {custom(bigButtons) bigButtons OFF "Use large buttons"} \
                {custom(popupHelp) popupHelp ON "Popup help text"} \
                {custom(saveExtras) saveExtras {CHOICE {Model file only} {Canvas file}} "Save models as..."} \
                {custom(compDescPop) compDescPop ON "Equation"} \
                {custom(compValPop) compValPop ON  "Value"}
        {custom(compCmtPop) compCmtPop ON  "Comment"} \
                {custom(recentCount) recentCount 10 "Entries on recently used file list"} \
                {custom(flowRouting) flowRouting ON "Rectilinear flow routing"} \
                {custom(deleteEndToEnd) deleteEndToEnd ON "Select links end-to-end"}}
    # JMM change wording and change default to ON
    Pref_Add {{custom(helperManager) helperManager ON \
                    "Use single window manager"}};
    #JMM add postions for run control and slider
    Pref_Add {{custom(runControlPosition) runControlPosition "+0-20" "Position of run control"} \
                {custom(slidersPosition) slidersPosition "+0+0" "Position of sliders"}}
    Pref_Add {{custom(hackBreak) hackBreak OFF \
                    "Pause to edit C++ code?"}}
    if {[string match windows $tcl_platform(platform)]} {
        Pref_Add {{custom(compChoice) compChoice {CHOICE None Microsoft GNU} \
                        "Use which C++ compiler?"}}
        file attributes $custom(prefDir) -hidden true
        if {[string mat Microsoft [PrefValue custom(compChoice) compChoice]]} {
            set compiler cl.exe
            set possDirs {}
            if {[info exists env(MSVCDIR)]} {
                set possDirs [concat $possDirs [split $env(MSVCDIR) \;]]
            }
            if {[info exists env(MSDEVDIR)]} {
                set possDirs [concat $possDirs [split $env(MSDEVDIR) \;]]
            }
            lappend possDirs {c:/progra~1/micros~1/vc98} {}
        }
    } else {
        set custom(compChoice) GNU
    }
    if {[string mat GNU [PrefValue custom(compChoice) compChoice]]} {
        set compiler g++
        set possDirs {{}}
    }
    if {[info exists compiler]} {
        if {[llength [set execLoc [auto_execok $compiler]]]} {
            # compiler tools are in path, hope libs and includes are nearby
            set env(MSVCDIR) [file dirname [file dirname [lindex $execLoc 0]]]
        } else {
            foreach possDir $possDirs {
                if {[llength [auto_execok $possDir/bin/$compiler]]} {
                    break
                }
            }
            if {[llength $possDir]} {
                set env(MSVCDIR) [lindex $possdir 0]
            } else {
                ShowMessage "C++ compiler setup problem" warning \
                        "c++ compiler preference set to [PrefValue \
                        custom(compChoice) compChoice] but no executable $compiler found in command \
                        path or any of $possDirs" ok
                set custom(compChoice) none
            }
        }
    }
    foreach nodeType {normal generic compartment channel \
                variable function submodel flow influence \
                ghost_link relation} {
        ResetLooks $nodeType
    }
    CustomizeLooks
    MakeHelperMenu
    
    # Bogosity alert -- setting an env var to {} causes it to stay
    # (or be) unset (in windows) otherwise lappend env(OPEN_MODEL)
    # would do here...
    if {[info exists env(OPEN_MODEL)]} {
        set openModel [brainwash $env(OPEN_MODEL)]
        # Add to path and recently opened files data
        RecordPathChoice .sml $openModel 1
    } else {
        set openModel {}
    }
    
    # Take the opportunity to pass the temp directory name etc to Prolog
    return [list $sendvars(simV) [brainwash $simtmpdir] \
            $openModel $userinfo(edn)]
}

# After the initial model has been loaded we don't want to allow the window
# to change size when something different is loaded
# This is also a convenient time at which to hide the console
# if it is showing

# If this is a slave interp, keep the OS choice of window posn, as moving it
# may well sit it exactly on top of the previous one

proc FixSize {c} {
    global custom openModel
    update idletasks
    set win [winfo parent $c]
    wm state $win normal
    # seems necessary for console to hide
    #    catch {console hide}
    if {[file exists $custom(prefDir)/layout]} {
        set stream [NetOpen $custom(prefDir)/layout r]
        gets $stream whetherMaxed
        #ShowMessage debug info $whetherMaxed ok
        catch {
            if {$whetherMaxed} {
                wm state $win zoomed
            } else {
                gets $stream oldGeom
                wm geometry $win $oldGeom
            }}
        close $stream
    }
    pack propagate $win 0
    update
    wm withdraw .
    if {[string match $openModel {}]} {
        DoRegDialog $win
    }
    
}

proc AlterModel {topNode} {
    global runState
    set runState($topNode,updated) 1
}

package require mime

proc SaveFile {topNode tree tgt} {
    #ShowMessage debug info "SaveFile $tree $tgt" ok
    global errorInfo
    global SimileProjectDo
    
    if {[info exists SimileProjectDo]} {
        SaveProjectFile $topNode $tree
        # shfs to $tree
        # spfs to $tree
        unset SimileProjectDo
    }
    if {[catch {
            set parts [GetParts $tree $tree]
            #ShowMessage debug info "SaveFile GetParts $tree" ok
            set runParams [GetRunParams $topNode]
            if {[llength $runParams]} {
                lappend parts [mime::initialize -canonical text/plain \
                        -header [list "Content-Description" "Run Status"] \
                        -string $runParams]
            }
            set multiT [mime::initialize -canonical multipart/mixed \
                    -parts $parts]
            set stream [NetOpen $tgt w]
            fconfigure $stream -translation binary
            mime::copymessage $multiT $stream
            # clean everything up
            close $stream
            mime::finalize $multiT -subordinates all
        } Lossage]} {
        return $errorInfo
    } else {
        return $Lossage
    }
}

proc LoadFile {topNode tree tgt} {
    global mimeSquirter errorInfo
    global loadingProject mimedir
    #ShowMessage debug info "LoadFile $tree $tgt" ok
    set CodeChecked no
    if {[catch {
            set multiT [mime::initialize -file $tgt]
            if {[catch {set intent [mime::getheader $multiT Readability]}]} {
                set intent standard
            }
            foreach bit [mime::getproperty $multiT parts] {
                set Desc [mime::getheader $bit Content-Description]
                #ShowMessage debug info $Desc ok
                switch [lindex $Desc 0] {
                    "Run Status" {
                        set runParams [mime::getbody $bit]
                        SetRunParams $topNode $runParams
                    } "Authentication Code" {
                        set AuthCode [string trimright [mime::getbody $bit]]
                    } default {
                        if {[string match "Simile model" [lindex $Desc 0]] && \
                                    [info exists AuthCode]} {
                            check_auth_code $bit
                            set CodeChecked yes
                        }
                        set Disposition [mime::getheader $bit Content-Disposition]
                        if {![regexp \"(.*)\" $Disposition all oldPath]} {
                            set oldPath [lindex [lindex $Disposition 0] 1]
                        }
                        set newPath $tree$oldPath
                        file mkdir [file dirname $newPath]
                        set mimeSquirter [NetOpen $newPath w]
                        fconfigure $mimeSquirter -translation binary
                        mime::getbody $bit -command SquirtMime -blocksize 256
                        if {![catch {mime::getheader $bit Date-Modified} \
                                    Date]} {
                            file mtime $newPath [clock scan [lindex $Date 0]]
                        }
                    }
                }
            }
            #ShowMessage debug info "LoadFile after unpack\n[glob $tree/*]" ok
            # if there is a project file
            if {[file exists $tree/model.spj]} {
                #ShowMessage debug info "LoadFile file is package" ok
                set loadingProject 1
                set mimedir $tree
                #OpenProjectFile $tree
            }
        } Lossage]} {
        return $Lossage
    } else {
        return $CodeChecked
    }
}

#                model.spj {
#                    set PartType "application/x-simile"
#                    set Description "Simile project file"
#                    set style attachment
#               }

proc GetParts {top tree} {
    set mimes {}
    foreach subtree [glob -nocomplain ${tree}/*] {
        #ShowMessage debug info "GetParts subtree $subtree" ok
        if {[file isdirectory $subtree]} {
            set mimes [concat $mimes [GetParts $top $subtree]]
        } else {
            set ext [file tail $subtree]
            switch -glob $ext {
                *.gif {
                    set PartType "image/gif"
                    set Description "Image"
                    set style inline
                }
                *.jpeg {
                    set PartType "image/jpeg"
                    set Description "Image"
                    set style inline
                }
                model.pl {
                    set PartType "application/x-simile"
                    set Description "Simile model"
                    set style inline
                }
                model.cnv {
                    set PartType "application/x-simile"
                    set Description "Simile canvas description"
                    set style attachment
                }
                *.shf {
                    set PartType "application/x-simile"
                    set Description "Simile helper configuration file"
                    set style attachment
                }
                *.spf {
                    set PartType "application/x-simile"
                    set Description "Simile parameter file"
                    set style attachment
                }
                model.* {
                    set PartType "application/x-simile"
                    set Description "Data"
                    set style attachment
                } default {
                    set Description junk
                }
            }
            # when saving, save all relevant files from current level but only
            # program files for submodels -- everything else is included in top level
            if {[string equal Data $Description] || \
                        [string equal $top $tree] && \
                        ![string match junk $Description]} {
                set relPath [string range $subtree [string length $top] end]
                set Disposition "${style}; filename=\"$relPath\""
                set Date [clock format [file mtime $subtree] -gmt true]
                set newMime [mime::initialize -canonical $PartType \
                        -header [list "Content-Disposition" \
                        $Disposition] \
                        -header [list "Content-Description" \
                        $Description] \
                        -header [list "Date-Modified" $Date] \
                        -file $subtree]
                if {[string match "Simile model" $Description]} {
                    set HmacCode [get_auth_code $newMime]
                    set codeT [mime::initialize -canonical text/plain \
                            -header [list "Content-Description" \
                            "Authentication Code"] \
                            -string $HmacCode]
                    lappend mimes $codeT
                }
                lappend mimes $newMime
            }
            # cannot delete the component files yet, they will be accessed when the
            # main file is written
            #	    if {[string compare "Data" $Description]} {
            #		file delete $subtree
            #	    }
            
            # Debug: write the body to see if it's baaad...yes it was
            # Workaround: don't save anything as text/plain, stick to application/x-simile
            #	    set debugname ${subtree}.mim
            #	    set stream [NetOpen $debugname w]
            #	    fconfigure $stream -translation binary
            #	    mime::copymessage $newMime $stream
            #	    close $stream
        }
    }
    return $mimes
}

proc SquirtMime {args} {
    global mimeSquirter
    if {[string match end [lindex $args 0]]} {
        close $mimeSquirter
    } else {
        puts -nonewline $mimeSquirter [lindex $args 1]
    }
}

# Path names derived from Windows environment variables must be
# 'brainwashed' i.e., stripped of their native culture and turned
# into blank-faced Unix-style forward-slash-separated automata.
# Otherwise mingw gcc variably gets culture shock.

proc brainwash {ethnic} {
    return [file join [file dirname $ethnic] [file tail $ethnic]]
}

proc byebye {winId} {
    prolog [list tk_off_window( '$winId.canvas' )]
}

proc exit_simile {} {
    global custom
    
    set cacheStream [NetOpen $custom(prefDir)/recent w]
    foreach oldFile $custom(hotlist) {
        puts $cacheStream $oldFile
    }
    close $cacheStream
}

proc ZapWindow { fullName } {
    global custom window_info
    
    upvar 0 window_info($fullName,parent) target
    #ShowMessage debug info "$winId $custom(first_up)" ok
    if {$window_info($fullName,is_top_level)} {
        focus $target.canvas
        update
        set cacheStream [NetOpen $custom(prefDir)/layout w]
        puts $cacheStream [string match zoomed [wm state $target]]
        puts $cacheStream [wm geometry $target]
        close $cacheStream
    }
    destroy ${target}top
    
    destroy $target
    foreach oldData [array names window_info $fullName,*] {
        unset window_info($oldData)
    }
}

proc ClearWindow {winId} {
    # Bit of tricky manoovering to delete all but window background
    $winId addtag doomed all
    $winId dtag /base/ doomed
    $winId delete doomed
    ResetEqnBar [winfo parent $winId].toolSlot.eqnbar
}

# Scale translates coordinates in desktop space to canvas space. Used to include
# 'round' because some floating point values caused trouble, but later Tcls do
# not seem to mind them, and they help when things are made very small then zoomed.

proc Scale {winId can} {
    global window_info
    expr $can*$window_info($winId,scale)
}

proc ScaleList {winId clist} {
    set output {}
    foreach elt $clist {
        lappend output [Scale $winId $elt]
    }
    return $output
}

# Reverse of scale -- still contains round(...) cos is used to send
# stuff to Prolog.does not contain round(...) either because the
# latest Prologs (well at least the Linux ones) seem immune to
# floating-point values.

proc Unscale {winId can} {
    global window_info
    expr $can/$window_info($winId,scale)
}

# procedure called when Prolog wants to know what object is at a point

proc FindObj { winId x y } {
    set canx [Scale $winId $x]
    set cany [Scale $winId $y]
    
    return [ExtractPrologName $winId [GetClickedObj $winId $canx $cany 6]]
}

# canvasTLDistance returns the offset of a canvas coordinate from its top
# left corner. If you are going to use @x,y to refer to a point in a canvas
# text item, these are the values you need (this is a bug in TclTk)

proc canvasTLDistance {winId x y} {
    if {[scan [$winId cget -scrollregion] "%g %g" cl ct]==2} {
        return [list [expr $x-$cl] [expr $y-$ct]]
    } else {
        return [list $x $y]
    }
}

# This is used when Tcl wants to get a result from Prolog, e.g., for the
# equation bar. The prolog procedure has to set fromProlog. It should stop
# the thread until it returns, but something is wrong -- occasionally
# fromProlog doesn't get set. Answer: set it first. Or fix the actual
# bug -- it seems 'update idletasks' somehow interferes with this,
# resulting in the variable not getting set, or something. Bug seems fixed now
# by new pipe interface technology -- might still do funnies if the Prolog
# command calls Tcl back though...

proc GetFromProlog {prologCmd} {
    global fromProlog
    prolog $prologCmd
    return $fromProlog
}

# This does similar to the above but gets the translation table, specially
# for aliasing into the execution interpreters. It's a stopgap, as the
# translation table should really be in the model code.

proc GetTransTable {node} {
    global fromProlog
    prolog tk_get_info({},$node,types)
    return $fromProlog
}

# Procedure for when Tcl recognizes what object is clicked but being a
# maleficent pile of junk refuses to pass on this information so we have
# to interrogate it to find what is closest to the click point

proc ClickObj { x y winId X Y action} {
    global clicktime
    global equationbar
    global pushedbutton
    global window_info
    
    #puts "$action it!"
    
    switch $action {
        ctrl {
            set action click
            set RB 0
            set CD 1
        } right {
            set action click
            set RB 1
            set CD 0
        } ctrl-right {
            set action click
            set RB 1
            set CD 1
        } default {
            set RB 0
            set CD 0
        }
    }
    
    set clicktime [clock clicks -milliseconds]
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set xco [Unscale $winId $canx]
    set yco [Unscale $winId $cany]
    
    focus $winId
    set target [GetClickedObj $winId $canx $cany 6]
    
    if {!$target} {
        # a background click
        $winId select clear
        $winId focus {}
        if {$RB && [string equal select $pushedbutton]} {
            prolog [list tk_${action}('$winId', $xco , $yco , 2)]
            tk_popup [winfo parent $winId]top.edit $X $Y
            prolog [list tk_unclick( $xco , $yco )]
        } else {
            prolog [list tk_${action}('$winId', $xco , $yco , $CD)]
        }
        return
    }
    
    set node [ExtractPrologName $winId $target]
    set caption [ExtractCaption $winId $node]
    set topNode $window_info($winId,top_node)
    if {[ProdObj $topNode $node $caption]} {
        return
        # IO tool took the click, so do no more
    }
    if {[string compare $pushedbutton snap]==0} then {
        snap $topNode $node
    } else {
        if {[string equal click $action]} {
            set obj [GetCaptionItem $winId $node]
            
            # This bit used to start a drag selecting some caption text
            if {[string compare $obj {}]} {
                set realPlace @[join [canvasTLDistance $winId $canx $cany] ,]
                $winId icursor $obj $realPlace
                $winId select clear
                if {[lsearch [$winId gettags $obj] selected] != -1} {
                    $winId select from $obj $realPlace
                }
            }
            
            if {!$RB && [string equal $target $obj]} {
                set action clicktext
            }
        }
        prolog [list tk_click_obj('$winId',  $action , $xco , $yco , $node \
                , $CD)]
        # Right button puts up context menu.
        if {$RB && [string equal select $pushedbutton]} {
            tk_popup [winfo parent $winId]top.edit $X $Y
            prolog [list tk_unclick( $xco , $yco )]
        }
        
        ### Formula bar
        ### Added by Jasper: ignore all eqnbar stuff if none in current window or
        ### not in pointer mode
        
        set bar [winfo parent $winId].toolSlot.eqnbar
        if {[catch {pack info $bar}] || [string compare $pushedbutton select]} {
            set equationbar(current_action) null
        } else {
            set equationbar(current_action) $action
            #	ModeSelect move
            #	ModeSelect select
            
            
            
        }
        
        if {[string match $equationbar(current_action) click]} {
            set fromProlog [GetFromProlog tk_get_info('$winId',$node,eqn)]
            if {![string match <none> $fromProlog]} {
                set label [BlankCrs [ExtractCaption $winId $node]]
                $bar.label configure -text "$label = "
                
                set winid [winfo parent $winId]
                set equationbar($winid,node) $node
                set equationbar($winid,initText) $fromProlog
                set equationbar(current_action) null
                SetEqnButtonState $bar normal
                restore_equation $winid $bar
            }
        }
        ### End equation bar
    }
}


proc ExtractCaption {win variable} {
    set capt $variable
    foreach obj [$win find withtag $variable] {
        if {[string compare [$win type $obj] text] == 0} {
            set capt [$win itemcget $obj -text]
        }
    }
    return $capt
}

# This is called when an operatio may have brought into view an area of canvas
# the existence of which was previously unknown to Prolog; it sends the virtual
# coordinates of the current area. l, t, r, b are relative to window.

proc RollBack { winId toProlog l t r b } {
    set newSpace 0
    scan [$winId cget -scrollregion] "%g %g %g %g" cl ct cr cb
    #    puts "debug info Rolling from $cl $ct $cr $cb to $l $t $r $b ok"
    set pt [$winId canvasx $l]
    if {$pt < $cl-2} {
        set cl $pt
        set newSpace 1
    }
    
    set pt [$winId canvasx $r]
    if {$pt > $cr+2} {
        set cr $pt
        set newSpace 1
    }
    
    set pt [$winId canvasy $t]
    if {$pt < $ct-2} {
        set ct $pt
        set newSpace 1
    }
    
    set pt [$winId canvasy $b]
    if {$pt > $cb+2} {
        set cb $pt
        set newSpace 1
    }
    
    if {$newSpace && $toProlog} {
        ResizeDesktop $winId $cl $ct $cr $cb
    }
}

proc ResizeDesktop {winId cl ct cr cb} {
    set canl [Unscale $winId $cl]
    set cant [Unscale $winId $ct]
    set canr [Unscale $winId $cr]
    set canb [Unscale $winId $cb]
    prolog [list tk_visible( '$winId' , $canl , $cant , $canr , $canb )]
}

# Dragging: as well as the Prolog dragging, we implement
# natively the feature that dragging causes the visible area
# of the window to follow the mouse.

proc DragObj {winId xco yco} {
    global window_info
    global clicktime
    
    set dragtime [clock clicks -milliseconds]
    if {$dragtime>$clicktime && $dragtime-$clicktime<100} {
        return
    }
    
    set canx [$winId canvasx $xco]
    set cany [$winId canvasy $yco]
    set virtx [Unscale $winId $canx]
    set virty [Unscale $winId $cany]
    set sloth 5
    
    RollBack $winId 1 $xco $yco $xco $yco
    
    if {$xco < 0} {
        $winId xview scroll [expr $xco/$sloth] units
    }
    if {$yco < 0} {
        $winId yview scroll [expr $yco/$sloth] units
    }
    if {$xco > $window_info($winId,width)} {
        $winId xview scroll \
                [expr int($xco-$window_info($winId,width))/$sloth] units
    }
    if {$yco > $window_info($winId,height)} {
        $winId yview scroll \
                [expr int($yco-$window_info($winId,height))/$sloth] units
    }
    
    prolog [list tk_drag( $virtx , $virty )]
}


proc ReleaseObj {winId xco yco} {
    set canx [Unscale $winId [$winId canvasx $xco]]
    set cany [Unscale $winId [$winId canvasy $yco]]
    prolog [list tk_unclick( $canx , $cany )]
}

# This allows Prolog to highlight an object in order to treat its text as being
# edited, if focusing on the window causes a cursor to start flashing in one.

proc EmbraceObj {winId} {
    set nodeId [GetEdit $winId]
    
    prolog [list tk_embrace( '$winId' , $nodeId )]
}

# This allows prolog to save the values of editing when the window is exited.
# Comment it out to debug edit procedure from separate window.
proc AbandonObj {} {
    prolog tk_abandon
}

# ChangeRegion causes a window to respond to a change in the size of its canvas.

# Strange things can happen if the canvas is shrunk below the size of the viewport
# so a little zoom is slipped in if this looks like happening. This is commented
# out for now because it can send a cmd back to Prolog, which calls this again,
# eventually bursting the stack and bombing out most horribly. Fix it properly
# some time -- OK! 3rd param now cuts out Prolog if 0.

proc ChangeRegion {w l t r b} {
    global window_info
    
    set allowScrollBar [winfo reqwidth [winfo parent $w].yscroll]
    set hcomp [expr [Unscale $w [expr $window_info($w,width)-$allowScrollBar]]/($r - $l)]
    set vcomp [expr [Unscale $w [expr $window_info($w,height)-$allowScrollBar]]/($b - $t)]
    set comp [expr $hcomp>$vcomp?$hcomp:$vcomp]
    set newReg [list [Scale $w $l] [Scale $w $t] [Scale $w $r] [Scale $w $b]]
    $w configure -scrollregion $newReg
    eval {ResizeBackgnd $w} $newReg
    #ShowMessage debug info "Just done [$w coords 1]" ok
    #    puts $comp
    if {$comp>1.01} {
        DoZoom $w $comp 0
    }
}

#######################################################################
#                                                                     #
# MainWindowDraw: puts a new model window on the screeen              #
#                                                                     #
#######################################################################

proc MainWindowDraw {topNode winName winTitle wl wt wr wb \
            colour initialScale isTopLevel args} {
    global window_info looks env custom
    set c [ModelWindow $winName]
    
    TweakWindow $c $winTitle 1 $wl $wt $wr $wb $colour
    #    wm maxsize $winName [winfo screenwidth $winName] \
    #	[winfo screenheight $winName]
    
    wm protocol $winName WM_DELETE_WINDOW \
            [list byebye $winName]
    
    set window_info($c,top_node) $topNode
    set window_info($c,scale) $initialScale
    set window_info($c,is_top_level) $isTopLevel
    
    AddMainMenu $winName $topNode [expr $wr-$wl] $isTopLevel $args
    AddCanvasBindings $c $topNode
    
    #    tkwait visibility $winName
    set window_info($c,parent) $winName
    
    InterpMenu $c off
    focus $c
    #    ShowMessage debug info "Messing with [wm frame $winName]" ok
    #    maximize_fg_win
    return $c
}

proc ModelWindow {winName} {
    global tcl_platform
    menu ${winName}top
    toplevel $winName -menu ${winName}top
    
    switch $tcl_platform(platform) {
        windows { wm iconbitmap $winName -default ../Run/simile16.ico }
        unix { wm iconbitmap $winName @../Images/dribble.xbm}
    }
    # Create a scrollable canvas
    set c [canvas $winName.canvas -bg white -confine 1 \
            -xscrollcommand "AdjustCanvas $winName toolSlot x" \
            -yscrollcommand "AdjustCanvas $winName canvas y" \
            -xscrollincrement 1 -yscrollincrement 1]
    # scrollincrements set the only way we can get precise scrolling...
    
    # this rectangle will be resized to fill the scrollable area and coloured to
    # show the background
    # $c create rect 0 0 100 100 -outline {} -tag {/base/ /background/}
    
    # space for toolbar
    frame $winName.toolSlot
    pack $winName.toolSlot -fill x
    
    scrollbar $winName.xscroll -orient horizontal \
            -command [list AdjustScroll $c xview]
    scrollbar $winName.yscroll -orient vertical \
            -command [list AdjustScroll $c yview]
    
    pack $c -fill both -expand true
    
    bind $c <Configure> {SetSpace %W %w %h}
    return $c
}

proc AdjustScroll {canvas dir args} {
    if {[string compare [lindex $args 2] units] == 0} {
        set jump [expr 10*[lindex $args 1]]
        $canvas $dir [lindex $args 0] $jump units
    } else {
        eval {$canvas $dir} $args
    }
}

# SetSpace: this command is called when the canvas is 'configured' by attacking
# its window's borders and so forth. It saves the new width and height of the
# canvas (This is Tk 4.0 which is too dumb to do it itself) and informs Prolog
# of the visible area of the scrollregion. We don't get any information about
# which way the window was grown so the diagram is kept in the middle.

proc SetSpace {c w h} {
    global window_info
    set cx $window_info($c,width)
    set cy $window_info($c,height)
    set window_info($c,width) [expr $w - 4]
    set window_info($c,height) [expr $h - 4]
    #    ShowMessage debug info "New size is $w $h" ok
    RollBack $c 1 [expr ($cx - $w)/2 + 2] [expr ($cy - $h)/2 + 2] \
            [expr ($cx + $w)/2 - 2] [expr ($cy + $h)/2 - 2]
}

proc TweakWindow {c winTitle scale wl wt wr wb bg args} {
    global window_info rads
    #    put back if Windows users want respite from their gash placement system
    #    wm geometry $winName +0+84
    
    # set the display depths to those we recorded
    #ShowMessage debug info "TweakWindow $c $winTitle $scale $wl $wt $wr $wb $bg $args" ok
    set cats {ghost_link influence variable flow \
                compartment submodel caption sections}
    for {set depthParam 0} {$depthParam < [llength $args]} {incr depthParam} {
        set rads($c,[lindex $cats $depthParam]) [lindex $args $depthParam]
        WindowDetail $c [lindex $cats $depthParam] \
                [lindex $args $depthParam] 0
    }
    
    $c configure -width 1 -height 1
    $c configure -scrollregion "$wl $wt $wr $wb" \
            -width [expr $wr-$wl] -height [expr $wb-$wt]
    set window_info($c,width) [expr $wr - $wl]
    set window_info($c,height) [expr $wb - $wt]
    set window_info($c,scale) $scale
    # last will be overwritten if drawing from Prolog
    
    ChangeParentTitle $c $winTitle $bg
    
    set topWin [winfo parent $c]
    scan [wm maxsize $topWin] "%d %d" mw mh
    #ShowMessage debug info "$wl $wt $wr $wb <> $mw $mh" ok
    if {[pack propagate $topWin] &&
        ($wr-$wl >= $mw-8 || $wb-$wt >= $mh-8)} {
        catch {winfo state $topWin zoomed}
    }
    #ShowMessage debug info "Just done [$c coords 1]" ok
}

proc ChangeParentTitle {wc title bg} {
    wm title [winfo parent $wc] $title
    if {[string match clear $bg]} {
        set bg {}
    }
    $wc delete /base/
    scan [$wc cget -scrollregion] "%g %g %g %g" bl bt br bb
    
    foreach colour $bg {
        if {[llength $colour]>1} {
            set posn [lindex $colour 1]
            set colour [lindex $colour 0]
        } else {
            set posn Tiled
        }
        set tag "/base/ /background/"
        if {[string equal clear $colour]} {
        } elseif {[catch {image type $colour}]} {
            $wc create rectangle $bl $bt $br $bb -outline {} -fill $colour \
                    -tag $tag
        } else {
            $wc create image $bl $bt -anchor nw -image [image create photo] \
                    -tag [concat $tag "source($colour) posn($posn)"]
        }
    }
    $wc lower /base/ ;# should keep them in order
    ResizeBackgnd $wc $bl $bt $br $bb
}

proc ResizeBackgnd {wc l t r b} {
    foreach baseItem [$wc find withtag /base/] {
        if {[string match image [$wc type $baseItem]]} {
            set baseImg [$wc itemcget $baseItem -image]
            #	    set oldW [base$wc cget -width]
            #	    set oldH [base$wc cget -height]
            $wc coords $baseItem $l $t
            set w [expr int($r-$l)]
            set h [expr int($b-$t)]
            $baseImg configure -width $w -height $h
            set tags [$wc gettags $baseItem]
            regexp {source\(([^\)]+)\)} $tags all sourceImage
            if {[regexp {posn\(([^\)]+)\)} $tags all sourcePosn]} {
                if {[string equal Scaled $sourcePosn]} {
                    set sourceImage [GrowImage $sourceImage $w $h]
                    set usingTemp 1
                }
            }
            $baseImg blank
            $baseImg copy $sourceImage -to 0 0 $w $h ;# clever stuff later
            if {[info exists usingSpare]} {
                image delete $sourceImage
            }
        } else {
            $wc coords $baseItem $l $t $r $b
        }
    }
}

proc AcceleratorState {winName menu item state} {
    global accelerator
    #puts "AcceleratorState {winName menu item state} $winName $menu $item $state [info exists accelerator($menu,$item)]"
    if {[info exists accelerator($menu,$item)]} {
        if {[string match normal $state]} {
            bind $winName $accelerator($menu,$item) \
                    [list if "\[DoingSelection $winName\]" \
                    [${winName}top.$menu entrycget $item -command]]
        } else  {
            bind $winName $accelerator($menu,$item) {}
        }
    }
}

proc AddAccelerator {winName menu item event} {
    #puts "AddAccelerator {winName menu item event} $winName $menu $item $event"
    global accelerator
    set accelerator($menu,$item) $event
    AcceleratorState $winName $menu $item [${winName}top.$menu entrycget $item -state]
}

proc DoingSelection {winName} {
    return [expr ![llength [$winName.canvas focus]] \
            && [string match [focus] $winName.canvas]]
}

proc AddCanvasBindings { c topNode } {
    bind $c <Button-1> {ClickObj %x %y %W %X %Y click}
    bind $c <Control-Button-1> {ClickObj %x %y %W %X %Y ctrl}
    # Doubleclicks now bound to objects not canvas
    bind $c <Double-1> {ClickObj %x %y %W %X %Y doubleclick}
    
    bind $c <B1-Motion> {DragObj %W %x %y}
    bind $c <ButtonRelease-1> {ReleaseObj %W %x %y}
    bind $c <Button-3> {ClickObj %x %y %W %X %Y right}
    bind $c <Control-Button-3> {ClickObj %x %y %W %X %Y ctrl-right}
    bind $c <ButtonRelease-3> {ReleaseObj %W %x %y}
    bind $c <FocusIn> {EmbraceObj %W}
    bind $c <FocusOut> {AbandonObj}
    
    # text/clipboard action from Welch example
    # commented because we can now cut/copy parts of a model
    #    bind $c <<Cut>> {CanvasTextCopy %W; CanvasDelete %W}
    #    bind $c <<Copy>> {CanvasTextCopy %W}
    #    bind $c <<Paste>> {CanvasPaste %W}
    
    # let's be sure never to show the highlight border...
    # (except for debugging)
    
    $c configure -highlightcolor white
    # now confer editability on the editable text items on this canvas
    CanvasEditBind $c
    
    # Stuff to put a popup help window on a canvas item
    # (could use tag 'has_info' for this)
    $c bind has_info <Enter> [list QueuePopup AddEqnPopup $topNode \
            %x %y %W %X %Y]
    $c bind has_info <Leave> RemovePopup
}

proc AddEqnPopup {node x y winId X Y} {
    global pushedbutton equationbar errorInfo runState
    set doDesc [PrefValue custom(compDescPop) compDescPop]
    set doVal [expr $runState($node,modelRunning)>1 && \
            [PrefValue custom(compValPop) compValPop]]
    set doCmt [PrefValue custom(compCmtPop) compCmtPop]
    if {[string compare select $pushedbutton] || \
                !$doDesc && !$doVal && !$doCmt} {
        return
    }
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set target [GetClickedObj $winId $canx $cany 2]
    #puts "Adding for $target"
    #    set target [$winId find closest $canx $cany 1]
    #puts "targeting $target"
    if {$target} {
        PostPopup $X $Y
        set plName [ExtractPrologName $winId $target]
        if {$doDesc} {
            set desc [GetFromProlog tk_get_info('$winId',$plName,desc)]
            
            # after going Prolog, check popup window still there
            # note colour etc are not comments though they look like them in emacs
            # actually new technology should make this unnecessary
            #if {![winfo exists .popup]} return
            AddPopupMessage $desc \#c0ffc0
        }
        if {$doCmt} {
            set fromProlog [GetFromProlog tk_get_info('$winId',$plName,comment)]
            #if {![winfo exists .popup]} return
            AddPopupMessage $fromProlog \#ffe0c0
        }
        if {$doVal} {
            if {[catch {GetTransValues $node $plName} value]} {
                set missing [lindex [split $value \"] 1]
                set value "Missing value: $missing"
            }
            AddPopupMessage [lindex [GetCompProperty $node Value $plName] 0] \
                    \#ffffc0 [GetTransTable $plName]
            # we might want to prettify this a bit first
        }
    }
    
}

# Canvas chapter (of Welch)

# Bindings for canvas Text items

# when we paste we do not know whether the selection has been encoded as utf-8
# or not, but Tcl knows and will do the right thing if pasting into an entry
# box. So why struggle -- make an entry box where no-one can see it, and when
# pasting into canvas text, paste into that then read the text from it.

entry .hidden_e
pack .hidden_e

proc CanvasEditBind { c } {
    
    $c bind currently_editable <B1-Motion> {
        if {[lsearch [%W gettags [%W focus]] selected] != -1} {
            %W select to current \
                    @[join [canvasTLDistance %W [%W canvasx %x] \
                    [%W canvasy %y]] ,]
        }
    }
    $c bind currently_editable <Delete> {
        if {![CanvasDelSeln %W]} {
            %W dchars [%W focus] insert
        }
    }
    $c bind currently_editable <Control-d> {
        if {[%W focus] != {}} {
            %W dchars [%W focus] insert
        }
    }
    $c bind currently_editable <Control-h> {
        if {![CanvasDelSeln %W]} {
            set _t [%W focus]
            if {[%W index $_t insert]} {
                %W icursor $_t [expr [%W index $_t insert]-1]
                %W dchars $_t insert
            }
        }
    }
    $c bind currently_editable <BackSpace> \
            [$c bind currently_editable <Control-h>]
    
    $c bind currently_editable <Control-Delete> {
        %W delete [%W focus]
    }
    $c bind currently_editable <Return> {
        %W insert [%W focus] insert \n
    }
    $c bind currently_editable <Any-Key> {
        # do not allow control chars other than the above mentioned
        if {[string compare %A { }] > -1} {
            CanvasDelSeln %W
            %W insert [%W focus] insert %A
        }
    }
    bind $c <<PasteSelection>> {
	.hidden_e delete 0 end
	event generate .hidden_e <<PasteSelection>>
	if {[%W focus] != {}} {
	    %W insert [%W focus] insert [.hidden_e get]
	}
    }
    $c bind currently_editable <Key-Right> {
        %W select clear
        %W icursor [%W focus] [expr [%W index [%W focus] insert]+1]
    }
    $c bind currently_editable <Shift-Right> {
        set farEnd [%W index [%W focus] insert]
        if {[llength [%W select item]]} {
            set newEnd [%W index [%W focus] sel.first]
            if {$newEnd==$farEnd} {
                set newEnd [%W index [%W focus] sel.last]
            }
        } else {
            set newEnd $farEnd
            %W select from [%W focus] $newEnd
        }
        %W select to [%W focus] [expr $newEnd+1]
    }
    $c bind currently_editable <Control-f> \
            [$c bind currently_editable <Key-Right>]
    
    $c bind currently_editable <Key-Left> {
        %W select clear
        %W icursor [%W focus] [expr [%W index [%W focus] insert]-1]
    }
    $c bind currently_editable <Shift-Left> {
        set farEnd [%W index [%W focus] insert]
        if {[llength [%W select item]]} {
            set newEnd [%W index [%W focus] sel.first]
            if {$newEnd==$farEnd} {
                set newEnd [%W index [%W focus] sel.last]
            }
        } else {
            set newEnd $farEnd
            %W select from [%W focus] $newEnd
        }
        %W select to [%W focus] [expr $newEnd-1]
    }
    $c bind currently_editable <Control-b> \
            [$c bind currently_editable <Key-Left>]
    
    $c bind currently_editable <Key-Home> {
        %W icursor [%W focus] 0
    }
    $c bind currently_editable <Control-a> \
            [$c bind currently_editable <Key-Home>]
    
    $c bind currently_editable <Key-End> {
        %W icursor [%W focus] end
    }
    $c bind currently_editable <Control-e> \
            [$c bind currently_editable <Key-End>]
    
    $c bind currently_editable <<Cut>> {CanvasTextCopy %W; CanvasDelete %W}
    $c bind currently_editable <<Copy>> {CanvasTextCopy %W}
    $c bind currently_editable <<Paste>> {
	.hidden_e delete 0 end
	event generate .hidden_e <<Paste>>
	CanvasDelSeln %W
	if {[%W focus] != {}} {
	    %W insert [%W focus] insert [.hidden_e get]
	}
    }
}

# Next three procs are from Welch examples

proc CanvasDelete {c} {
    CanvasDelSeln $c
    if {[$c focus] != {}} {
        $c dchars [$c focus] insert
    }
}

proc CanvasDelSeln {c} {
    if {[llength [$c select item]]} {
        $c dchars [$c select item] sel.first sel.last
	$c select clear
        return 1
    } else {
        return 0
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

# update display detail. This process sets the display depth of component
# types more important than the one that has been adjusted to be at
# least as deep, and those less important to be at least as shallow,
# as the one explicitly changed. Second MenuSelect is commented out as
# Prolog does the same thing itself to avoid many redraws (aargh!)

proc WindowDetail {window category level redraw} {
    #    global rads
    MenuSelect $window window detail($category,$level,$redraw)
    #    set cats {ghost_link influence variable flow compartment submodel}
    #    if {[lsearch $cats $category]>-1} {
    #	set hiding 1
    #	foreach cat $cats {
    #	    if {[string match $category $cat]} {
    #		set hiding 0
    #	    } elseif {$hiding && $rads($cat)>$level || \
    #		    !$hiding && $rads($cat)<$level} {
    #		set rads($cat) $level
    #		MenuSelect $window window \[detail,$cat,$level\]
    #	    }
    #	}
    #    }
}

# This patches a bug with error reporting in Tk 8.0. Also puts up a
# feedback window allowing progress reports on long activities.

proc MenuSelect { window button item } {
    global exports
    if {[lsearch "run_c run_tcl load_exec" $item] != -1} {
        set exports(running_window) $window
    }
    if [string match local $button] {
        DoLocalCmd $window $item
    } else {
        set command tk_menu('$window',$button,'$item')
        DoWithErrors prolog $command
    }
}

proc DoLocalCmd {win item} {
    global pushedbutton
    switch $item {
        undo {UnOrReDo $win 0}
        redo {UnOrReDo $win 1}
        print {PrintNow $win}
        rerun {Rerun $win 1}
        zoomin {DoZoom $win 1.414214 1}
        tosel {DisplayArea $win}
        tofit {DisplayAll $win}
        zoomout {DoZoom $win .707107 1}
        customize {Customize $win $pushedbutton}
        find {FindCaption $win}
        findnext {NextCaption $win}
        raiseMRE {RaiseMREFor $win}
        open_all {OpenAll $win}
        save_all {SaveAll $win}
        insert {InsertModel $win}
    }
}

proc RaiseMREFor {win} {
    global window_info helperTable
    
    set myMre $helperTable($window_info($win,top_node),whichRunEnv)
    wm deiconify $myMre
    raise $myMre
}


proc OpenAll {win} {
    global loadingProject mimedir
    MenuSelect $win file open
    if {[info exists loadingProject]} {
        OpenProjectFile $win $mimedir
    }
}

proc OpenProjectFile {win path} {
    global SimileProject loadingProject window_info
    set projectF [NetOpen $path/model.spj r]
    gets $projectF SimileProjectData
    close $projectF
    #ShowMessage debug info "open_all win $win; $SimileProjectData" ok
    array set SimileProject $SimileProjectData
    #ShowMessage debug info "open_all SimileProject(ModelFile) $SimileProject(ModelFile)" ok
    
    # if params it should load the spfs
    # MergeParams {smPath metaFile interactive}
    if {[info exists SimileProject(modelRunning)]} {
        if {[info exists SimileProject(running_c)]} {
            MenuSelect $win file run_c
        } else  {
            MenuSelect $win file run_tcl
        }
        if {[info exists SimileProject(nameOfHelperStateFile)]} {
            set command [ChooseText \
                    [PrefValue custom(helperManager) helperManager] \
                    ::RunEnv::LoadSHF CreateView]
            $command $window_info($win,top_node) \
                    ${path}/$SimileProject(nameOfHelperStateFile)
        }
    }
    unset loadingProject
}

proc SaveAll {win} {
    global SimileProjectDo
    #ShowMessage debug info "SaveAll win $win" ok
    set SimileProjectDo 1
    MenuSelect $win file save_as
}

proc SaveProjectFile {topNode path} {
    global custom runState nameOfHelperStateFile
    global SimileProject model_id
    #ShowMessage debug info "SaveProjectFile $path" ok
    # save any current spf names to the spj file
    # save any shf files names
    
    set ProjectFile $path/model.spj
    
    # is it builtC|builtTcl|notbuilt
    if {$runState($topNode,modelRunning)>1} {
        set SimileProject(modelRunning) 1
        if {$model_id($topNode)} {
            set SimileProject(running_c) 1
        }
    }
    if {[info exists nameOfHelperStateFile($topNode)]} {
        file copy -force $nameOfHelperStateFile($topNode) $path
        set SimileProject(nameOfHelperStateFile) \
                [file tail $nameOfHelperStateFile($topNode)]
    }
    # shf file name loaded
    
    #ShowMessage debug info "SaveProjectFile [array get SimileProject]\n\
    #            $path/[file tail $nameOfHelperStateFile]" ok
    set projectF [NetOpen $ProjectFile w]
    puts $projectF [array get SimileProject]
    close $projectF
}



proc UnOrReDo {curWin fwd} {
    global window_info
    foreach win [array names window_info *,parent] {
        lappend canList '[lindex [split $win ,] 0]'
    }
    set curPos [lsearch $canList '$curWin']
    set canArgs [join $canList ,]
    if {$fwd} {
        prolog tk_redo($curPos,\[$canArgs\])
    } else {
        prolog tk_undo($curPos,\[$canArgs\])
    }
}

# I think the only reason for having this is to work around a Windows bug
# where the Prolog errors didn't come up properly...
proc DoWithErrors {args} {
    eval $args
    #    if [catch $args err] {
    #        bgerror $err
    #    }
}

# Export a postscript file from a window. Only the bit of the diagram showing in
# the viewport is included, and the output is in landscape mode, sized so 100
# pixels = 1 inch (so my beautiful 1152x864 screen will be about a sheet of A4)

proc ExportPostscript { winId } {
    set psfile [ChooseFile image.ps "Name of postscript file" 1]
    # check for cancel
    if {![string match */ $psfile]} {
        
        # force .ps extension
        if {[string compare [file extension $psfile] .ps]} {
            set psfile [file root $psfile].ps
        }
        SpitPS $winId $psfile
    }
}

proc PrepForExport {winId way} {
    global jiggles tcl_platform
    
    # now, zoom in by detail factor to get the line thickness resolution decent
    set detail 1.0
    # For font scale 1 seems right for Unix -- Windows takes about 1.6
    if {[string match windows $tcl_platform(platform)]} {
        set textBoost 1.6
    } else {
        set textBoost 1.0
    }
    set textscale [expr $detail*$textBoost]
    if {[string match there $way]} {
        if {[scan [$winId cget -scrollregion] "%g %g %g %g" sl st sr sb]<4} {
            set sl 0; set st 0
            set sr [winfo width $winId]; set sb [winfo height $winId]
        }
        set jiggles(bl) $sl
        set jiggles(bt) $st
        set jiggles(br) $sr
        set jiggles(bb) $sb
        
        set jiggles(sl) [lindex [$winId xview] 0]
        set jiggles(st) [lindex [$winId yview] 0]
        set xbase [expr [$winId canvasx 0]-$sl]
        set ybase [expr [$winId canvasy 0]-$st]
        $winId move all [expr -$sl] [expr -$st]
        # Don't bother moving the scrollregion, it will not be staying like this
        # -- actually we need to move it because print_widget scales to it
        $winId configure -scrollregion [list 0 0 \
                [expr $detail*($sr-$sl)] [expr $detail*($sb-$st)]]
        ZoomImage $winId all $detail $textscale
        return [list $xbase $ybase $detail]
    } else {
        ZoomImage $winId all [expr 1/$detail] [expr 1/$textscale]
        $winId configure -scrollregion [list $jiggles(bl) $jiggles(bt) \
                $jiggles(br) $jiggles(bb)]
        $winId xview moveto $jiggles(sl)
        $winId yview moveto $jiggles(st)
        $winId move all $jiggles(bl) $jiggles(bt)
    }
}

proc CopyCanvasToWindowsClipboard {canvas} {
    global tcl_platform
    
    if {[string match windows $tcl_platform(platform)]} {
        package require gdi
        package require printer
        package require wmf
        
        set hdc [wmf open]; #Opens a memory metafile
        printer::print_select $hdc $canvas withtag tocopy
        set wmfdc [ wmf close $hdc ]; # Turn the context into a metafile handle
        wmf copy $wmfdc; # Copy to the clipboard
    }
}

proc PrintNow {winId} {
    global simtmpdir tcl_platform
    
    if {[string match windows $tcl_platform(platform)]} {
        set oldDir [pwd] ;# apparently printing can change directory
        package require gdi
        package require printer
        
        # print routines still seem unable to handle negative coordinates so
        # put image through prep mech
        PrepForExport $winId there
        printer::print_widget $winId 0
        PrepForExport $winId back
        cd $oldDir
    } else {
        set tempPSFile $simtmpdir/temp.ps
        SpitPS $winId $tempPSFile
        if {[catch "exec $env(PRINTCMD) {[file nativename $tempPSFile]}" result]} {
            ShowMessage "Print command result" warning \
                    "Printing seems to have failed. \
                    The result returned by the print command was:
            
            $result
            
            Please see the online help to find out more about setting up printing from Simile. Alternatively you can export the model diagram as a PostScript file (use the File...Export menu command) and then print that using another package." ok
        }
        file delete $tempPSFile
    }
}

proc SpitPS {winId psfile} {
    scan [PrepForExport $winId there] "%g %g %g" xbase ybase detail
    set useWidth [winfo width $winId]
    set useHeight [winfo height $winId]
    
    $winId postscript -file $psfile -rotate true -pageanchor nw \
            -pagex 0 -pagey 0 -x [expr $detail*$xbase] -y [expr $detail*$ybase] \
            -width [expr $detail*$useWidth] -height [expr $detail*$useHeight] \
            -pagewidth [expr $useWidth/100.0]i -pageheight [expr $useHeight/100.0]i
    PrepForExport $winId back
}

proc InsertModel {winId} {
    set insertion [ChooseFile model.sml "Model file to insert" 0]
    if {![string match */ $insertion]} {
        Reopen $winId $insertion insert
    }
}

proc Reopen {canvas oldFile op} {
    global custom userinfo welcomeDone
    
    if [winfo exists .register] {
        set userinfo(done) $welcomeDone
    }
    
    RecordPathChoice .sml $oldFile 1
    set custom(hotlist) [linsert $custom(hotlist) 0 $oldFile]
    MenuSelect $canvas $op $oldFile
    global loadingProject mimedir
    if {[info exists loadingProject]} {
        OpenProjectFile $canvas $mimedir
    }
}

menu .openrecent -tearoff 0

proc FillReopen {winId} {
    global custom
    .openrecent delete 0 end
    set posted {}
    foreach hottie $custom(hotlist) {
        if {[llength $posted] >= [PrefValue custom(recentCount) recentCount]} {
            break
        }
        if {[file exists $hottie] && [lsearch $posted $hottie]==-1} {
            .openrecent add command -label [file tail $hottie] \
                    -command [list Reopen $winId.canvas $hottie reopen]
            lappend posted $hottie
        }
    }
}

proc AddMainMenu { winid topNode initWidth isTopLevel initDepths} {
    global custom pushedbutton tcl_platform runState iconImages
    
    set c $winid.canvas
    set fm [menu ${winid}top.file -tearoff 0 \
            -postcommand "FillReopen $winid"]
    ${winid}top add cascade -label File -underline 0 -menu ${winid}top.file
    $fm add command -label New -command "MenuSelect $c file new"\
            -accelerator "Ctrl+N"
    AddAccelerator $winid file New "<Control-n>"
    $fm add command -label "New top-level" -command "NewTopLevel"
    $fm add command -label Open... -command "MenuSelect $c local open_all"\
            -accelerator "Ctrl+O"
    AddAccelerator $winid file Open... "<Control-o>"
    $fm add cascade -label "Reopen" -menu .openrecent
    $fm add command -label Save -command "MenuSelect $c file save" \
            -accelerator "Ctrl+S"
    AddAccelerator $winid file Save "<Control-s>"
    
    $fm add command -label "Save as..." \
            -command "MenuSelect $c file save_as"
    $fm add command -label "Save selection as..." \
            -command "MenuSelect $c file save_seln_as"
    $fm add command -label "Save/Edit package" \
            -command "MenuSelect $c local save_all"
    
    $fm add separator
    $fm add command -label "Print..." \
            -command "PrintNow $c"\
            -accelerator "Ctrl+P"
    AddAccelerator $winid file "Print..." "<Control-p>"
    $fm add cascade -label "Export" -menu $fm.sub1
    set fm2 [menu $fm.sub1 -tearoff 0]
    $fm2 add command -label "Model declarations" \
            -command "MenuSelect $c file export_prolog"
    $fm2 add command -label "C++ code" \
            -command "MenuSelect $c file build_c"
    $fm2 add command -label "executable binary" \
            -command "MenuSelect $c file compile_c"
    $fm2 add command -label "PostScript graphics" \
            -command "DoWithErrors ExportPostscript $c"
    $fm add separator
    
    $fm add command -label Close -command "byebye $winid" \
            -accelerator "Alt+x"
    AddAccelerator $winid file Close "<Alt-x>"
    $fm add command -label Exit -command "prolog tk_kill_everything"
    
    
    # edit menu: purpose of postcommand is to enable/disable cut/copy/paste items
    # for what is available, overridden later if it is popup
    set fm [menu ${winid}top.edit -tearoff 0 \
            -postcommand "prolog tk_bar_edit_menu('$c')"]
    ${winid}top add cascade -label Edit -underline 0 -menu ${winid}top.edit
    
    $fm add cascade -label "Create new" -menu $fm.add
    set em1 [menu $fm.add -tearoff 0]
    foreach type {Compartment Variable Flow Influence} {
        $em1 add command -label $type -command \
                "MenuSelect $c edit [string tolower $type]"
    }
    $em1 add command -label "Role arrow" -command \
            "MenuSelect $c edit relation"
    $em1 add cascade -label "Membership control" -menu $em1.sub
    set em2 [menu $em1.sub -tearoff 0]
    foreach type {Creation Immigration Reproduction Loss} {
        $em2 add command -label $type -command \
                "MenuSelect $c edit [string tolower $type]"
    }
    $em2 add command -label "Existence condition" -command \
            "MenuSelect $c edit condition"
    $em2 add command -label "Iteration condition" -command \
            "MenuSelect $c edit alarm"
    $fm add separator
    
    $fm add command -label Undo -command "UnOrReDo $c 0" \
            -state disabled -accelerator "Ctrl+Z"
    AddAccelerator $winid edit Undo "<Control-z>"
    $fm add command -label Redo -command "UnOrReDo $c 1" \
            -state disabled
    # no need for this as cut/copy now does it -- keep so we can have non blue
    if {[string match windows $tcl_platform(platform)]} {
        $fm add separator
        $fm add command -label "Copy diagram" -command "CopyCanvasToWindowsClipboard $c"
    }
    $fm add separator
    
    $fm add command -label Cut -command "CopyCanvasToWindowsClipboard $c; \
            MenuSelect $c edit cut" -accelerator "Ctrl+X"
    AddAccelerator $winid edit Cut "<Control-x>"
    $fm add command -label Copy -command "CopyCanvasToWindowsClipboard $c; \
            MenuSelect $c edit copy" -accelerator "Ctrl+C"
    AddAccelerator $winid edit Copy "<Control-c>"
    $fm add command -label Paste -command "MenuSelect $c edit paste" \
            -accelerator "Ctrl+V"
    AddAccelerator $winid edit Paste "<Control-v>"
    $fm add command -label {Reroute links} \
            -command "MenuSelect $c edit reroute"
    $fm add command -label Delete -command "MenuSelect $c edit delete" \
            -accelerator "Del"
    AddAccelerator $winid edit Delete "<Delete>"
    $fm add separator
    
    $fm add command -label "Select all" -command "MenuSelect $c edit selall" \
            -accelerator "Ctrl+A"
    AddAccelerator $winid edit "Select all" "<Control-a>"
    $fm add command -label "Unselect all" \
            -command "MenuSelect $c edit unselall" -accelerator "Ctrl+U"
    AddAccelerator $winid edit "Unselect all" "<Control-u>"
    $fm add command -label "Invert selection" \
            -command "MenuSelect $c edit invsel" -accelerator "Ctrl+*"
    AddAccelerator $winid edit "Invert selection" "<Control-Shift-8>"
    
    AddFindMenu $c $fm
    $fm add separator
    $fm add command -label "Properties..." \
            -command "MenuSelect $c edit properties"
    $fm add command -label Preferences... -command Pref_Dialog
    
    
    set fm [menu ${winid}top.view -tearoff 0]
    ${winid}top add cascade -label View -underline 0 \
            -menu ${winid}top.view
    $fm add check -label Toolbar -variable custom(shownavbar,$winid) \
            -command "toggleBar $winid"
    $fm add check -command "toggleBar $winid" \
            -label "Component bar" -variable custom(showtoolbar,$winid)
    $fm add check -command "toggleBar $winid" \
            -label "Equation bar" -variable custom(showeqnbar,$winid)
    
    $fm add separator
    AddZoomMenu $c $fm 1
    $fm add cascade -label "Show detail" -menu $fm.sub3
    set fm3 [menu $fm.sub3 -tearoff 0]
    AddDetailMenu $c $fm3 $initDepths
    $fm add command -label "Customize..." \
            -command "DoLocalCmd $winid customize"
    
    set fm [menu ${winid}top.model -tearoff 0 -postcommand "AbleComp $winid"]
    ${winid}top add cascade -label Model -underline 0 \
            -menu ${winid}top.model
    $fm add command -label "Build In Tcl" \
            -command "MenuSelect $c file run_tcl" \
            -accelerator "Ctrl+T"
    AddAccelerator $winid model "Build In Tcl" "<Control-t>"
    $fm add command -label "Build In C++" \
            -command "MenuSelect $c file run_c" \
            -accelerator "Ctrl+B"
    AddAccelerator $winid model "Build In C++" "<Control-b>"
    if {!$isTopLevel} {
        $fm entryconfigure "Build In Tcl" -state disabled
        $fm entryconfigure "Build In C++" -state disabled
    }
    $fm add separator
    $fm add command -label "List equations" \
            -command "MenuSelect $c file list_eqns" \
            -accelerator "Ctrl+L"
    AddAccelerator $winid model "List equations" "<Control-l>"
    $fm add separator
    $fm add cascade -label Add -menu $fm.sub1
    set fm1 [menu $fm.sub1 -tearoff 0]
    
    # The radiobuttons use MIpushedbutton as their variable because
    # the command procedure has to know what the old pushedbutton was
    # so it can unpress it, so they cannot use that
    
    $fm1 add radiobutton -label Compartment -command "ItemSelect compartment"\
            -variable MIpushedbutton -value compartment
    $fm1 add radiobutton -label Variable -command "ItemSelect variable"\
            -variable MIpushedbutton -value variable
    $fm1 add radiobutton -label Flow -command "ItemSelect flow"\
            -variable MIpushedbutton -value flow
    $fm1 add radiobutton -label Influence -command "ItemSelect influence"\
            -variable MIpushedbutton -value influence
    $fm1 add radiobutton -label Submodel -command "ItemSelect submodel"\
            -variable MIpushedbutton -value submodel
    $fm1 add radiobutton -label Relation -command "ItemSelect relation"\
            -variable MIpushedbutton -value relation
    
    
    $fm1 add radiobutton -label Creation -command "ItemSelect creation"\
            -variable MIpushedbutton -value creation
    $fm1 add radiobutton -label Migration -command "ItemSelect immigration"\
            -variable MIpushedbutton -value immigration
    $fm1 add radiobutton -label Reproduction -command "ItemSelect reproduction"\
            -variable MIpushedbutton -value reproduction
    $fm1 add radiobutton -label Extermination -command "ItemSelect loss"\
            -variable MIpushedbutton -value loss
    $fm1 add radiobutton -label Condition -command "ItemSelect condition"\
            -variable MIpushedbutton -value condition
    $fm1 add radiobutton -label Alarm -command "ItemSelect alarm"\
            -variable MIpushedbutton -value alarm
    $fm add cascade -label Flip -menu $fm.sub2
    set fm2 [menu $fm.sub2 -tearoff 0]
    $fm2 add command -label Horizontal \
            -command "MenuSelect $c edit flip_h"
    $fm2 add command -label Vertical \
            -command "MenuSelect $c edit flip_v"
    
    $fm add command -label "Insert..." \
            -command "MenuSelect $c local insert"
    $fm add separator
    $fm add command -label "Save interface" \
            -command "MenuSelect $c file save_interface"
    $fm add command -label "Load interface" \
            -command "MenuSelect $c edit set_interface"
    
    
    set fm [menu ${winid}top.tools -tearoff 0]
    ${winid}top add cascade -label Tools -underline 0 \
            -menu ${winid}top.tools
    $fm add radiobutton -label "Label/move elements" \
            -command "ModeSelect select" -variable MIpushedbutton -value select
    #    $fm add radiobutton -label "Move elements" -command "ModeSelect move"\
    -variable MIpushedbutton -value move
    #    $fm add radiobutton -label "Delete elements" -command "ModeSelect delete"\
    -variable MIpushedbutton -value delete
    #    $fm add radiobutton -label "Duplicate submodels" -command "ModeSelect copy"\
    -variable MIpushedbutton -value copy
    $fm add radiobutton -label "Create ghost nodes"  -command "ModeSelect ghost"\
            -variable MIpushedbutton -value ghost
    $fm add radiobutton -label "Inspect elements"  -command "ModeSelect snap"\
            -variable MIpushedbutton -value snap -state disabled
    
    if {![info exists runState($topNode,modelRunning)]} {
        set runState($topNode,modelRunning) 0
    }
    if {$runState($topNode,modelRunning)>1} {
        ${winid}top add  cascade -label "I/O tools" -underline 0 \
                -menu .helpers
        $fm entryconfigure "Inspect elements" -state normal
    }
    #    menu $winid.helpers -tearoff 0 \
    #	-postcommand [list after idle PostRealHelperMenu $winid]
    
    set fm [menu ${winid}top.help -tearoff 0]
    ${winid}top add cascade -label Help -underline 0 -menu ${winid}top.help
    $fm add command -label Contents -command "ContextSensitiveHelp $winid index.htm" \
            -accelerator "F1"
    AddAccelerator $winid help Contents "<F1>"
    $fm add command -label Huh? -command {ShowMessage debug info $errorInfo ok}
    $fm add command -label About... -command [list ShowAbout $winid]
    
    set nb [frame $winid.toolSlot.navbar -border 2]
    pack [Separator $nb.afterSeparator -orient horizontal] -fill x -side bottom
    if {[PrefValue custom(bigButtons) bigButtons]} {
        set buttonImages ../Images/Toolbar/Large
    } else {
        set buttonImages ../Images/Toolbar
    }
    
    foreach navCmd {{new {file new}} {open {file open}} \
                {save {file save}}  {print {local print}} {separator1}\
                {undo {local undo}} {redo {local redo}} {separator2}\
                {flip_h {edit flip_h}} {flip_v {edit flip_v}} {separator3}\
                {zoomin {local zoomin}} {zoomsel {local tosel}} \
                {zoomfit {local tofit}} {zoomout {local zoomout}} \
                {separator4}   } {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised\
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    
    foreach navCmd {{rerun {local rerun}} {separator5} \
                {find {local find}} {findmore {local findnext}} {separator6}} {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised \
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    
    # button to raise single-window run env (ready for more tools in this section)
    foreach navCmd {{runenv {local raiseMRE}}} {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised \
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    $nb.runenv configure -state disabled
    
    set tb [frame $winid.toolSlot.toolbar -border 2]
    pack [Separator $tb.afterSeparator -orient horizontal] -fill x -side bottom
    foreach mode {compartment variable flow influence separator1 submodel \
                relation separator2 creation immigration reproduction loss condition alarm} {
        if {[string match separator* $mode]} {
            
            pack [Separator $tb.$mode -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${mode}.gif]
            set bt [button $tb.$mode -command "ItemSelect $mode" -image $testImg -borderwidth 1 -relief flat -overrelief raised]
            pack $bt -side left -padx 2 -pady 2
            BindPopup $bt $mode
            bind $bt <ButtonRelease-1> "DragComponentIn $c $bt %X %Y"
        }
    }
    pack [Separator $tb.spacer -orient vertical] -fill y -side left
    
    foreach mode {select ghost snap} {
        set testImg [image create photo -file $buttonImages/${mode}.gif]
        pack [button $tb.$mode -image $testImg -command "ModeSelect $mode" \
                -borderwidth 1 -relief flat -overrelief raised] \
                -side left -padx 2 -pady 2
        BindPopup $tb.$mode $mode
    }
    if {!$runState($topNode,modelRunning)>1} {
        $tb.snap configure -state disabled
    }
    
    $tb.$pushedbutton configure -relief sunken
    $tb.$pushedbutton configure -state active
    
    
    ### Formula bar section
    ### Robert Muetzelfeldt
    ### Started 4/3/02
    set eb [frame $winid.toolSlot.eqnbar -border 1 -relief flat]; # raised
    
    label $eb.label -anchor e
    pack $eb.label -side left
    
    
    entry $eb.equation -state disabled -width 40
    pack $eb.equation -side left -expand 1 -fill x
    bind $eb.equation <Return> [list accept_equation $winid $eb.equation]
    bind $eb.equation <FocusIn> "EmbraceEqn $winid"
    bind $eb.equation <FocusOut> AbandonEqn
    pack [button $eb.tick -state disabled -image $iconImages(tick) \
            -borderwidth 1 \
            -command [list accept_equation $winid $eb.equation]] -side left
    
    pack [button $eb.cross -state disabled -image $iconImages(cross) \
            -borderwidth 1 \
            -command [list restore_equation $winid $eb]] -side left
    
    frame $eb.padding -width 10
    pack $eb.padding -side left
    pack [Separator $eb.afterSeparator -orient horizontal] -fill x -side bottom
    
    set image [image create photo -file "../Images/Eqnbar/inputs.gif"]
    menubutton $eb.inputs -state disabled -menu $eb.inputs.menu \
            -borderwidth 2 -relief raised -image $image
    pack $eb.inputs -side left
    set m [menu $eb.inputs.menu -tearoff 0 \
            -postcommand [list AddInputs $winid $eb]]
    #    $m add command -label biomass -command bell
    #    $m add command -label k -command bell
    #BindPopup $m foobar
    
    menubutton $eb.function -state disabled -menu $eb.function.menu \
            -borderwidth 2 -relief raised -image $iconImages(function)
    pack $eb.function -side left
    set m [menu $eb.function.menu -tearoff 0]
    global equation msgs
    foreach funk [concat {{{{Built-in} {Model properties}} index}} \
            $equation(fnDefs)] {
                set box $m
                #puts "Adding $funk to $box"
                foreach level [split [join [lindex $funk 0] /] /] {
                    set lname $box.[string tolower [join $level _]]
                    if {[catch {$box index $level}]} {
                        menu $lname -tearoff 0
                        MenuBindPopup $lname {}
                        $box add cascade -menu $lname -label $level
                    }
                    set box $lname
                }
                set component [lindex $funk 1]
                if {[catch {$box index $component\(\)}]} {
                    $box add command -label $component\(\) \
                    -command [list InsertFunction $eb.equation $component]
                }
            }
    
    
    #    set useFunctions [lrange $equation(fnDefs) 0 9]
    #    foreach defn $useFunctions {
    #        set cmd [lindex $defn 1]
    #        $m add command -label $cmd\(\) \
    -command [list InsertFunction $eb.equation $cmd]
    #    }
    #    $m add command -label "All functions..." -command bell
    
    #   set image [image create photo -file "../Images/eqnbar/props.gif"]
    #   pack [button $eb.properties -state disabled -image $image -borderwidth 1] \
    #           -side left
    
    ### End of formula bar section
    
    update idletasks ;# to allow reqwidth to be calculated
    set navWidth [winfo reqwidth $tb] ;# tool bar is widest
    #ShowMessage debug info "Toolbar needs $navWidth" ok
    set custom(showtoolbar,$winid) [expr $initWidth>=$navWidth && \
            [PrefValue custom(initToolbar) initToolbar]]
    set custom(shownavbar,$winid) [expr $initWidth>=$navWidth && \
            [PrefValue custom(initNavbar) initNavbar]]
    set custom(showeqnbar,$winid) [expr $initWidth>=$navWidth && \
            [PrefValue custom(initEqnbar) initEqnbar]]
    
    
    pack [Separator $winid.toolSlot.topseparator -orient horizontal] -fill x -side top
    if {$custom(shownavbar,$winid)} {
        pack $nb -fill x
    }
    if {$custom(showtoolbar,$winid)} {
        pack $tb -fill x
    }
    if {$custom(showeqnbar,$winid)} {
        pack $eb -fill x
    }
    
    $nb.undo configure -state disabled
    $nb.redo configure -state disabled
}

proc AddFindMenu {canvas menu} {
    $menu add separator
    $menu add command -label Find... -command "FindCaption $canvas" \
            -accelerator "Ctrl+F"
    AddAccelerator [winfo parent $canvas] edit "Find..." "<Control-f>"
    $menu add command -label "Find next" -command "NextCaption $canvas" \
            -accelerator "F3"
    AddAccelerator [winfo parent $canvas] edit "Find next" "<F3>"
}

proc AddZoomMenu {canvas menu tellProlog} {
    $menu add cascade -label Zoom -menu $menu.sub2
    set fm2 [menu $menu.sub2 -tearoff 0]
    $fm2 add command -label "In lots" -command "DoZoom \
            $canvas 1.953125 $tellProlog"
    $fm2 add command -label "In a bit" -command "DoZoom \
            $canvas 1.25 $tellProlog"
    $fm2 add command -label "To selection" -command "DisplayArea $canvas"
    $fm2 add command -label "To fit" -command "DisplayAll $canvas"
    $fm2 add command -label "Out a bit" -command "DoZoom \
            $canvas 0.8 $tellProlog"
    $fm2 add command -label "Out lots" -command "DoZoom \
            $canvas 0.512 $tellProlog"
    
}

proc PostRealHelperMenu {winId} {
    global window_info runState
    
    set dotlessWinName [string range $winId 1 end]
    set bloodyClone $winId.\#${dotlessWinName}top.\#$dotlessWinName\#helpers
    set tgtx [winfo rootx $bloodyClone]
    set tgty [winfo rooty $bloodyClone]
    event generate $bloodyClone <ButtonRelease-1>
    
    set node $window_info($winId.canvas,top_node)
    $runState($node,interp) eval .helpers post $tgtx $tgty
    $runState($node,interp) eval focus .helpers
}
# below used to find out what the bloody clone is called when writing above
proc allwins {win} {
    puts $win
    puts [winfo geometry $win]
    foreach n [winfo children $win] {
        allwins $n
    }
}

# # character in colour spec is escaped purely for the benefit of the Emacs
# tcl mode parser

proc DragComponentIn {winId button x y} {
    set whatToAdd [winfo name $button]
    #    set top [winfo parent $winId]
    #puts $x,$y
    #    foreach level [list $top $winId] {
    #	scan [winfo geometry $level] %dx%d+%d+%d w h ox oy
    #puts $level,$ox,$oy
    #	incr x [expr -$ox]
    #	incr y [expr -$oy]
    #    }
    set x [expr $x-[winfo rootx $winId]]
    set y [expr $y-[winfo rooty $winId]]
    
    if {$x<0 || $x>[winfo width $winId] || $y<0 || $y>[winfo height $winId]} {
        # not in canvas, ignore
        return
    }
    
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set xco [Unscale $winId $canx]
    set yco [Unscale $winId $cany]
    
    set target [GetClickedObj $winId $canx $cany 6]
    
    # Now simulate what Prolog would get from an add component menu selection
    if {$target} {
        set node [ExtractPrologName $winId $target]
        prolog [list tk_click_obj('$winId', click , $xco , $yco , $node , 2)]
    } else {
        # a background drop
        prolog [list tk_click('$winId', $xco , $yco , 2)]
    }
    prolog tk_bar_edit_menu('$winId')
    prolog [list tk_unclick( $xco , $yco )]
    MenuSelect $winId edit $whatToAdd
}

proc ExtractPrologName { winId target } {
    set tagList [$winId gettags $target]
    set objNamePosn [lsearch -regexp $tagList {(node)|(arc)[0-9]*}]
    return [lindex $tagList $objNamePosn]
}

# GetClickedObj: returns the object at the target position. We want to return
# the closest object within a certain number of pixels. Since there is always
# something in the background we will get that if our search radius is too
# small, so we gradually increase it until we find a non-background thing or
# we reach the edge of our search radius.

proc GetClickedObj { winId canx cany range} {
    for {set halo 1} {$halo < $range} {incr halo 2} {
        set target [$winId find closest $canx $cany $halo]
        if {![string match "*/background/*" [$winId gettags $target]]} {
            return $target
        }
    }
    return 0
}

proc AbleComp {winid} {
    global custom
    # Not done now because compiler choice not given in Unix, and we need to load
    # pre-built executables even if we have no compiler ourselves
    
    #    if {[string match $winid $custom(first_up)]} {
    #	if {[string match None [PrefValue custom(compChoice) compChoice]]} {
    #	    set cCompOption disabled
    #	} else {
    #	    set cCompOption normal
    #	}
    #	${winid}top.model entryconfigure "Build In C++" -state $cCompOption
    #    }
}

proc EmbraceEqn {winId} {
    global equationbar
    if {[info exists equationbar($winId,node)]} {
        prolog tk_embrace('$winId.canvas',$equationbar($winId,node))
    }
}

proc AbandonEqn {} {
    prolog tk_abandon_eqn
}


if {![info exists interface]} {
    set interface dll
}

# toggler unpacks and repacks all bars to keep order right
proc toggleBar {winId} {
    global custom
    foreach which {nav tool eqn} {
        set barname $winId.toolSlot.${which}bar
        if {![catch {pack info $barname}]} {
            pack forget $barname
        }
        $winId.toolSlot configure -height 1
        if {$custom(show${which}bar,$winId)} {
            pack $barname -fill x
        }
    }
}

proc AddDetailMenu {winId fm3 initVals} {
    
    global rads
    set posn 0
    foreach category { \
        {ghost_link "Ghost links..."} \
                {influence "Influences..."} \
                {variable "Variables..."} \
                {flow "Flows and clouds..."} \
                {compartment "Compartments..."} \
                {submodel "Submodels and relations..."} \
                {caption "Captions..."}} {
        
        set cat [lindex $category 0]
        set rads($winId,$cat) [lindex $initVals $posn]
        incr posn
        $fm3 add cascade -label [lindex $category 1] \
                -menu $fm3.$cat
        set lastmenu [menu $fm3.$cat -tearoff 0]
        $lastmenu add radio -label "None" -variable rads($winId,$cat) \
                -value 0 -command "WindowDetail $winId $cat 0 1"
        foreach depth {1 2 3 4 5 6} {
            $lastmenu add radio -label "$depth levels" \
                    -variable rads($winId,$cat) -value $depth \
                    -command "WindowDetail $winId $cat $depth 1"
            
        }
        $lastmenu add radio -label "All" -variable rads($winId,$cat) \
                -value 32 -command "WindowDetail $winId $cat 32 1"
    }
    $fm3 add cascade -label "Influence sections..." -menu $fm3.sections
    set lastmenu [menu $fm3.sections -tearoff 0]
    set rads($winId,sections) [lindex $initVals $posn]
    foreach sectType {Local Terminal All} {
        $lastmenu add radio -label $sectType \
                -variable rads($winId,sections) -value show$sectType \
                -command "WindowDetail $winId sections show$sectType 1"
    }
}

proc Rerun {winId go} {
    global runState window_info
    
    set node $window_info($winId,top_node)
    if {!$runState($node,modelRunning)>1 || \
                $runState($node,updated) == 1} {
        if {[info exists runState($node,lang)]} {
            set runType run_$runState($node,lang)
        } else {
            set runType run_tcl
        }
        MenuSelect $winId file $runType
    } else {
        StartRun $node
        # assume if model was running before it will run again
    }
    # Only proceed if it worked
    if {!$runState($node,modelRunning)>1} {
        return fail
    }
    if {$go} {
        StartNow $node
    }
    return yes
}

proc UpdateAbility {c what where which whether} {
    global window_info
    set winId $window_info($c,parent)
    set newState [ChooseText $whether normal disabled]
    ${winId}top.$where entryconfigure $which -state $newState
    AcceleratorState $winId $where $which $newState
    if {![string equal none $what]} {
        set navBar $winId.toolSlot.navbar
        $navBar.$what configure -state $newState
    }
}

proc ToggleIOToolMenu {node} {
    global window_info custom model_id
    
    foreach win [array names window_info *,top_node] {
        if {[string equal $node $window_info($win)]} {
            set c [string range $win 0 end-9]
            set winData $window_info($c,parent)
            
            set topMenu ${winData}top
            catch {$topMenu delete "I/O tools"}
            $winData.toolSlot.navbar.runenv configure -state disabled
            if {[info exists model_id($node)]} {
                set newState normal
                if {[PrefValue custom(helperManager) helperManager]} {
                    $winData.toolSlot.navbar.runenv configure -state normal
                } else {
                    $topMenu insert "Help" cascade -label "I/O tools" \
                            -underline 0 -menu .helpers
                }
            } else {
                set newState disabled
            }
            $winData.toolSlot.toolbar.snap configure -state $newState
            $topMenu.tools entryconfigure {Inspect elements} -state $newState
        }
    }
}

proc InterpMenu {winId state} {
    global sendvars
    set sendvars(boxsize) 240
}

#initialize this variable, any button will do (if it is sunken)

set pushedbutton select

proc ModeSelect {modes} {
    global pushedbutton MIpushedbutton
    UpdateToolbars $modes
    set pushedbutton $modes
    set MIpushedbutton $modes
    prolog [list tk_mode_select( $modes )]
}

proc ItemSelect {newItem} {
    global adds
    global pushedbutton MIpushedbutton
    set adds $newItem
    UpdateToolbars $newItem
    set pushedbutton $newItem
    set MIpushedbutton $newItem
    prolog [list tk_menu_select( $newItem , from_box)]
}

# Change indentation of toolbar buttons. Apply in all desktop windows
# ie. those not in helper list

proc UpdateToolbars {newAction} {
    global pushedbutton window_info tcl_platform
    #puts "UpdateToolbars $pushedbutton $newAction"
    foreach winData [array name window_info *,parent] {
        set toolBar $window_info($winData).toolSlot.toolbar
        $toolBar.$pushedbutton configure -state normal
        $toolBar.$newAction configure -state active
        $toolBar.$pushedbutton configure -relief flat
        $toolBar.$newAction configure -relief sunken
        ResetEqnBar $window_info($winData).toolSlot.eqnbar
    }
}

proc ResetEqnBar {bar} {
    $bar.equation delete 0 end
    $bar.label configure -text {}
    SetEqnButtonState $bar disabled
}

proc SetEqnButtonState {bar newState} {
    foreach eqnButton {equation tick cross inputs function} {
        $bar.$eqnButton configure -state $newState
    }
}

proc RaiseModelWindow {} {
    set win [FindNodeTopWin $::RunEnv::currentNode]
    wm deiconify $win
    raise $win
}

proc FindNodeTopWin {node} {
    global window_info
    foreach {key win} [array get window_info *,parent] {
        set c [string range $key 0 end-7]
        if {[string equal $node $window_info($c,top_node)] && \
                    [info exists window_info($c,is_top_level)]} {
            return $win
        }
    }
}

##############################    Formula bar    #############################

proc accept_equation {winId text} {
    
    global equation
    global equationbar
    
    set equationbar(current_action) tick
    set equationbar(equation) [string trimright [$text get]]
    set node $equationbar($winId,node)
    prolog [list tk_click_obj('$winId.canvas',  doubleclick, 0 , 0 , $node, 0)]
    focus $winId.canvas
}

proc AddInputs {winId bar} {
    global equationbar
    $bar.inputs.menu delete 0 end
    set node $equationbar($winId,node)
    set paramData [GetFromProlog tk_get_params('$winId',$node)]
    foreach paramList $paramData {
        set paramName [lindex $paramList 1]
        $bar.inputs.menu add command -label $paramName \
                -command [list InsertParam $bar $paramName]
    }
    MenuBindPopup $bar.inputs.menu $paramData
}

proc InsertParam {bar paramName} {
    
    $bar.equation insert insert $paramName
    focus $bar.equation
}

proc restore_equation {winId bar} {
    global equationbar
    $bar.equation delete 0 end
    $bar.equation insert end $equationbar($winId,initText)
    focus $bar.equation
}

##############################    Formula bar    #############################


proc GetTransValues {topNode node} {
    global runState
    
    set value [GetCompProperty $topNode Value $node]
    if {![string match novalue $value]} {
        set trans [GetTransTable $node]
        return [TransEnums $trans [lindex $value 0]]
    } else {
        return novalue
    }
}
