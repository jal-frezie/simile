#!/usr/bin/tclsh
encoding system utf-8
foreach local {sPath sHome emPath mdl shLib} val $argv {
    set $local $val
}
puts "Here [pwd] args $argv<br>"
exec echo {} > /tmp/error-output.txt
lappend auto_path [file join $sPath System lib]
if {![file exists [file join $sHome .simile userinfo.txt]]} {
    file delete -force $sHome
    file mkdir $sHome
    file copy /var/www/tmplate/.simile /var/www/tmplate/.emscripten $sHome
}
set env(HOME) $sHome
catch {file delete [file join $sHome $shLib].cpp}
catch {file delete [file join $sHome $shLib].asm.js}
catch {file delete [file join $sHome .simile Desktop1.smx]}
# puts $auto_path<br>
if {[catch {
    package require SimileAutoObj

    similescript::ModelWindow modelWin
    modelWin Open $mdl.sml
    #    modelWin BuildShareLib [file join $sHome $shLib]
    set middle [file join $sHome $shLib].cpp
    modelWin ExportCppCode $middle
    catch {exec [file join $emPath emcc] -I [file join $sPath Run] -o [file join $sHome $shLib].asm.js $middle [file join $sPath Run shank.cpp] -O2 -DJOIN_AT_HIP --memory-init-file 0 -Wno-logical-op-parentheses -s EXPORTED_FUNCTIONS=\['_proc_pointers_for_shank','_load_model','_get_node_count','_get_data_line','nodlin_from_id','_name_from_nodlin','_eqn_from_nodlin','_min_from_nodlin','_max_from_nodlin','_class_from_nodlin','_type_from_nodlin','_eval_from_nodlin','_units_from_nodlin','_searchinfo','_getNodeId','_fetch_top_instance','_setstep','_use_array_for_params','_get_param_ptr_and_dims','_set_bloc_element','_paste_param_data','_param_array_size','_create_time_point','_get_timepoint_ptr_and_dims','_get_wrap_ptr','_get_fill_ptr','_get_interval_ptr','_reset','_get_raw_values','_ds_from_nodvals','_ct_from_nodvals','_size_from_sznptr','_ptr_from_sznptr','_free_bloc_data','_execute'\] -s RESERVED_FUNCTION_POINTERS=3 -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1} emccWibbles
    puts $emccWibbles ;# command returns error even if successful
    
# now export the svg not over the original model
    puts "svg to $mdl.svg"
    modelWin BuildSVGDiagram $mdl.svg

    # try returning the runParams if we have them...as json of course
    array set runParams {execTime 100.0 timeUnit unit displayInt 1 \
			     intMethod Euler phaseList 0.1 resetTo 0}
    # defaults
    set node [modelWin cget -modelNode]
    if {[info exists runState($node,runParams)] && \
	     [lindex $runState($node,runParams) 0] eq "execTime"} {
	array set runParams $runState($node,runParams) ;# overwrite
    }
    set rps \{
    foreach {role val} [array get runParams] {
	append rps \"$role\":\"$val\",
    }
    puts -nonewline [string replace $rps end end \}]
}]} {
    puts $errorInfo
}
exit
