# ArcMap.tcl
# Helper to write/read Arcmap (ArcGis) shape file attributes
# Adapted from polygon mapper

# 3x

# OptionsDialog -expand on -fill both; scroll bars for tables
# should deal with whole map - project just need to be able to load from dialog box
# should deal with more than 1 link (submodel <--> layer) put each on a tabbed page?
# input table should only show input parameters
# check dimensions of submodel and layer match

# what about multiple instances of helper and of ArcMap!

# can't load raster -- Add datasets and layers

# ignore if not Windows
if {[string equal windows $::tcl_platform(platform)]} {
    
    package require Tktable
    
    set keyValue ArcMap9Vector396
    
    # requires ArcMapUtilities.tcl to be already sourced (ArcMap namespace)
    
    namespace eval $keyValue {
        variable data
        variable pQueryGetAll
        variable chkbxVars
        variable pObjFactory
        
        proc identify {} {
            return "ArcMap 9 Vector Map"
        }
        
        proc initialize {winId} {
            global Arc_Map
            variable data
            SetState $winId {}
            
            init $winId
            ShowHelper $winId
            # would like dialog box to show shapes and attrib avail in GIS
            # and model var ond link  them cf SimArc
            set data($winId,mapfile) [lindex [::ArcMap::AddMap9 $winId false] 0]
            UpdateState $winId
            #ShowMessage debug info "data($winId,mapfile) $data($winId,mapfile)" ok
            ConfigDlg $winId
            
            ################################################################################
            #             global runState
            #             global helperTable
            #             set keyvalue $helperTable(RunControl)
            #             #set t $runState($modelNode,helperId)
            #             set t [regexp "(.helper\[0-9\]+),whichHelper $keyvalue" \
            #                     [array get helperTable] spare helperId]
            #             ${keyvalue}::SetMode $t reset
            ################################################################################
        }
        
        proc init {winId} {
            variable data
            set data($winId,outvarNodeIndex) {}
        }
        
        proc ShowHelper {winId} {
            global Arc_Map; # todo either in namespace or unique name
            variable pQueryGetAll
            variable data
            
            set data($winId,layer) {}
            set data($winId,submodel) {}
            set data($winId,invars) {}
            set data($winId,outputs) {}
            set data($winId,moduleName) {}
            set data($winId,MacroName) {}
            set data($winId,mapfile) {}
            set data($winId,inputAttr) {}
            
            set toolbarItems [list \
                    [list property.gif " Properties " [namespace code "ConfigDlg $winId"]]]
            ::graphtools::MakeToolBar $winId $toolbarItems
            pack [label $winId.label -text "Please wait for ArcMap to load ..."]
            
            update
            
            ::ArcMap::StartArcMap9 $winId
            bind $winId <Destroy> [namespace code "OnDestroy $winId"]; # todo only call if ArcMap started
            
            #Stored query to get all rows of a table
            set pIUnkown [::esriGeoDatabase::QueryFilter]
            set pQueryGetAll [::esriGeoDatabase::IQueryFilter $pIUnkown]
            $pQueryGetAll WhereClause "FID>-1"
        }
        
        proc Restore {winId} {
            global Arc_ArcMap Arc_Map
            global pEditor
            global pWorkspace
            variable data
            variable VbaAppl
            variable pMxDoc
            
            init $winId
            ShowHelper $winId
            
            regsub -all /WIN/ [GetState $winId] $winId restoreString
            array set data $restoreString
            
            set filePath $data($winId,mapfile)
            $Arc_ArcMap($winId) OpenDocument $filePath
            
            #after 4000
            ShowMessage Information info "Continue?" ok
            # below is copied from ConfigDlg !!! todo extract common code
            set pMxDoc [::esriArcMapUI::MxDocument $Arc_Map($winId)]
            set pMap [$pMxDoc FocusMap]
            set pObjFactory [::esriFramework::IObjectFactory $Arc_ArcMap($winId)]
            set pUID [$pObjFactory Create esriSystem.UID]
            $pUID Value "{E156D7E5-22AF-11D3-9F99-00C04F6BC78E}"; # FeatureLayers todo rasters? tins?
            set NTries 0
            set pEnumLayer [$pMap Layers $pUID true]
            
            set layers {}
            $pEnumLayer Reset
            set pLayer [$pEnumLayer Next]
            while {![string match "" $pLayer]} {
                lappend layers [$pLayer Name]
                set pLayer [$pEnumLayer Next]
            }
            set layers [lsort -unique $layers]
            
            #ShowMessage dubug info "layers $layers\n\
            #        data(winId,layer) $data($winId,layer)" ok
            set layerIndex [lsearch $layers $data($winId,layer)]
            if {$layerIndex==-1} {
                ShowMessage Error info "ArcMap helper failed to restore:\n\
                        the map did not contain the named Layer: $data($winId,layer)" ok
                return
            }
            set pLayer [$pMap Layer $layerIndex]
            
            set pIAttributeTable [::esriCarto::IAttributeTable $pLayer]; # IUnknown
            set pFLayer [::esriCore::IFeatureLayer $pLayer]
            
            if {[catch {set pDataset [$pFLayer FeatureClass]}]} {
                ShowMessage Error error "The layer chosen is not a feature layer" ok
                return
            }
            set pFeatureClass [::esriGeoDatabase::IFeatureClass $pDataset]
            set data($winId,FeatureClass) $pFeatureClass
            
            set parent [[::esriFramework::IDocument $pMxDoc] Parent]
            # IVbaApplication
            set VbaAppl [::esriFramework::IVbaApplication $parent]
            set pDataset [::esriGeoDatabase::IDataset $pDataset]
            
            set pWorkspace [$pDataset Workspace]
            
            set pEditor [::esriGeoDatabase::IWorkspaceEdit $pWorkspace]
            
            $winId.label configure -text "ArcMap GIS Link"
        }
        
        proc click {winId node caption} {
            #        variable useNodes
            # can't use click to select submodels GetClick doesn't allow it
            ################################################################################
            #             variable dlg
            #             $dlg draw
            #
            #             set ms $winId.intro
            #             set testResult [GetModelValue $node]
            #
            #             # This tests for the user having clicked on a suitable element
            #             # of the model diagram
            #             if {[string compare $testResult novalue]} {
            #
            #                 switch $useNodes($winId,state) {
            #                     sizeval {
            #                         pack forget $ms
            #                         ReleaseClicks $winId
            #                         set useNodes($winId,color) $node
            #                         set useNodes($winId,state) displaying
            #                     }
            #                 }
            #
            #                 UpdateState $winId
            #             } else {
            #                 $ms configure -text \
            #                         "This component does not have a value; please choose a compartment, variable or flow."
            #             }
            ################################################################################
        }
        proc display {winId time step remainder} {
            variable data
            variable VbaAppl
            
            SetInputs $winId $data($winId,FeatureClass)
            if {![string match {} $data($winId,moduleName)]} {
                if {![string match {} $data($winId,MacroName)]} {
                    $VbaAppl RunVBAMacro Project $data($winId,moduleName) $data($winId,MacroName) [::tcom::null]
                }
            }
            WriteOutputsToShapeFile $winId $data($winId,FeatureClass)
        }
        
        #############################################################
        # internal procs
        
        proc OnDestroy  {winId} {
            #ShowMessage debug info "OnDestroy" ok
            ::ArcMap::QuitArcMap $winId
        }
        
        proc ConfigDlg {winId} {
            global Arc_ArcMap Arc_Map window_info
            variable submodelPaths
            variable attr
            variable data
            variable chkbxVars
            global pEditor
            global pWorkspace
            variable pMxDoc; # should be helper instance specific
            variable pCursor
            variable VbaAppl
            
            destroy .arcMapVectorConfig
            catch {unset ::intabledata${winId}}
            catch {unset ::outtabledata${winId}}
            
            set attr($winId) {}
            set pObjFactory [::esriFramework::IObjectFactory $Arc_ArcMap($winId)]
            #set modelWin [do_for_node set window_info([lindex [lsort [array name window_info *,parent]] 0])]
            # -parent $modelWin
            set dlg [Dialog .arcMapVectorConfig -modal local \
                    -separator 0 \
                    -title   "ArcMap Vector Map Config" \
                    -default 0 -cancel 1]
            $dlg add -name ok
            $dlg add -name cancel
            
            # combobox with all submodels to select from
            set submodelPaths {{}}; # start with blank entry
            foreach component [GetObjectList] {
                set type [GetModelClass $component]; # Simile 2.7+
                if {[string match SUBMODEL $type ]} then {
                    set path [GetCaptionPathFromId $component]
                    lappend submodelPaths [BlankCrs [lindex $path end]]
                }
            }
            set submodelF [labelframe $dlg.submodelF -text "Submodel"]
            set submodelcb [ComboBox $submodelF.submodelcb -values $submodelPaths]
            pack $submodelF $submodelcb -fill x -expand on
            
            after 4000
            # even if I get a proper value for pMxDoc AND later pMap ($pMap LayerCount)
            # causes no errors, [$pMap Layers $pUID true] does cause errors without the
            # above wait
            set pMxDoc [::esriArcMapUI::IMxDocument $Arc_Map($winId)]
            # loop till its loaded
            #set NTries 0
            #while {[catch {set pMxDoc [::esriCore::IMxDocument $Arc_Map($winId)]}] && $NTries <100} {
            #    after 50
            #    incr NTries
            #}
            #ShowMessage debug info "pMxDoc $pMxDoc; NTries $NTries" ok
            # IMap todo what if more than 1 map
            #   - get the collection of maps [$pMxDoc Maps]
            #   - make user choose from that
            set pMap [$pMxDoc FocusMap]
            ################################################################################
            #             set NTries 0
            #             while {[catch {set pMap [$pMxDoc FocusMap]}] && $NTries <100} {
            #                 after 50
            #                 incr NTries
            #             }
            ################################################################################
            #ShowMessage debug info "pMap $pMap; NTries $NTries" ok
            
            if {[$pMap LayerCount]<0} {
                ShowMessage Warning info "No map layers" ok
                return
            }
            set pUID [$pObjFactory Create esriSystem.UID]
            $pUID Value "{E156D7E5-22AF-11D3-9F99-00C04F6BC78E}"; # todo FeatureLayers rasters? tins?
            
            
            #### ERROR
            #ShowMessage debug info "pMap $pMap; pUID $pUID" ok
            #ShowMessage debug info "3" ok
            #set pEnumLayer [$pMap Layers $pUID true]
            #after 4000
            set NTries 0
            while {[catch {set pEnumLayer [$pMap Layers $pUID true]}] && $NTries <100} {
                after 50
                incr NTries
                #ShowMessage debug info "pEnumLayer NTries $NTries" ok
            }
            #ShowMessage debug info "pEnumLayer $pEnumLayer; NTries $NTries" ok
            
            set layers {}
            $pEnumLayer Reset
            set pLayer [$pEnumLayer Next]
            while {![string match "" $pLayer]} {
                lappend layers [$pLayer Name]
                set pLayer [$pEnumLayer Next]
            }
            set layers [lsort -unique $layers]
            
            set layerF [labelframe $dlg.layerF -text "GIS Layer"]
            set layercb [ComboBox $layerF.layercb -values $layers]
            pack $layerF $layercb -fill x -expand on
            
            set inputF [labelframe $dlg.inputF -text Input -width 400]
            table $inputF.table -cols 3 -titlerows 1 -variable ::intabledata$winId \
                    -colwidth 15 -width 400
            pack $inputF $inputF.table -fill x -expand on
            set ::intabledata${winId}(0,0) {Model variable}
            set ::intabledata${winId}(0,1) {Type}
            set ::intabledata${winId}(0,2) {GIS attribute}
            #ShowMessage debug info "[set ::intabledata${winId}(0,2)]" ok
            
            set outputF [labelframe $dlg.outputF -text Output]
            #pack [LabelEntry $outputF.database -label "DataDase " -text $data($winId,dbf)]\
            #        -fill x -expand on
            table $outputF.table -cols 3 -titlerows 1 -variable outtabledata$winId \
                    -colwidth 15 -width 400 -rows 15; # todo
            pack $inputF $outputF.table -fill x -expand on
            set ::outtabledata${winId}(0,0) {Model variable}
            set ::outtabledata${winId}(0,1) {Type}
            set ::outtabledata${winId}(0,2) {Output}
            
            pack $outputF
            
            set macroF [labelframe $dlg.macroF -text "ArcMap macro to run"]
            pack [entry $macroF.entry] -fill x -expand on
            $macroF.entry insert 0 [join [list $data($winId,moduleName) $data($winId,MacroName)] .]
            pack $macroF -fill x -expand on
            
            
            $submodelcb configure -modifycmd \
                    [namespace code "OnSubmodelChosen $winId $submodelcb $inputF.table \
                    $outputF.table"]
            $layercb configure -modifycmd \
                    [namespace code "OnLayerChosen $winId $layercb $inputF.table"]
            
            if {![string match {} $data($winId,submodel)]} {
                set indx [lsearch $submodelPaths $data($winId,submodel) ]
                $submodelcb setvalue @$indx
                OnSubmodelChosen $winId $submodelcb $inputF.table $outputF.table
            }
            
            if {![string match {} $data($winId,layer)]} {
                set indx [lsearch $layers $data($winId,layer) ]
                $layercb setvalue @$indx
                OnLayerChosen $winId $layercb $inputF.table
            }
            
            if {[llength $data($winId,inputAttr)]>0} {
                set cbs [winfo children $inputF.table]
                set i 0
                foreach ele $cbs {
                    set indx [lindex $data($winId,inputAttr) $i]
                    $ele setvalue @$indx
                    incr i
                }
            }
            
            
            #ShowMessage debug info "data(winId,outvarNodeIndex) $data($winId,outvarNodeIndex)" ok
            if {[llength $data($winId,outvarNodeIndex)]>0} {
                set N [llength [array names ::outtabledata${winId} *,0 ]]
                #ShowMessage debug info "N $N" ok
                for {set i 1} {$i<=$N} {incr i} {
                    set caption [set ::outtabledata${winId}(${i},0)]
                    set submodel $data($winId,submodel)
                    set node [GetIdFromCaptionPath ${submodel}/$caption]
                    #ShowMessage debug info "caption $caption\n\
                    #        node $node\n\
                    #        search [lsearch -glob $data($winId,outvarNodeIndex) ${node}*] " ok
                    if {[lsearch -glob $data($winId,outvarNodeIndex) ${node}*]>-1} {
                        $outputF.table.cBx$i select
                    }
                }
            }
            
            set macros {}
            # have to catch the following because trying to get the VBproject of an
            # MxDoc with no macros causes as error. Without getting the VBproject
            # how can one tell that there are no macros?
            if {![catch {set thisVBproj [[::esriFramework::IDocument $pMxDoc] VBProject]}]} {
                ::tcom::foreach vbComp [$thisVBproj VBComponents] {
                    lappend macros [$vbComp Name]
                }
            }
            #ShowMessage debug info "macros $macros [$vbComp Type]" ok
            
            set result [$dlg draw]
            if {$result==0} {
                # ok
                #set data($winId,dbf) [$outputF.database cget -text]
                
                set data($winId,layer) [lindex $layers [$layerF.layercb getvalue]]
                
                set pLayer [$pMap Layer [$layerF.layercb getvalue]]
                set pIAttributeTable [::esriCarto::IAttributeTable $pLayer]; # IUnknown
                #set data($winId,layerpAttrTable) [$pIAttributeTable AttributeTable]
                set data($winId,submodel) \
                        [lindex $submodelPaths [$submodelF.submodelcb getvalue]]
                
                # get type of layer
                set pFLayer [::esriCarto::IFeatureLayer $pLayer]
                #set pRLayer [::esriCore::IRasterLayer $pLayer]
                
                if {[catch {set pDataset [$pFLayer FeatureClass]}]} {
                    ShowMessage Error error "The layer chosen is not a feature layer" ok
                    return
                }
                # !!!!!!!!!!!!!!!!!!!!!!!!!
                if {[catch {set pDataset [$pFLayer FeatureClass]}]} {
                    if {[catch {set pDataset [$pFLayer Raster]}]} {
                        ShowMessage Error error "The layer chosen is not a feature or raster layer" ok
                        return
                    }
                }
                # set pRaster [pRLayer Raster]; # put this in the if and handle rasters
                set pFeatureClass [::esriGeoDatabase::IFeatureClass $pDataset]
                set data($winId,FeatureClass) $pFeatureClass
                
                set pDataset [::esriGeoDatabase::IDataset $pDataset]
                set pWorkspace [$pDataset Workspace]
                set pEditor [::esriGeoDatabase::IWorkspaceEdit $pWorkspace]
                
                #ShowMessage debug info "::intabledata\{winId\} [array names ::intabledata${winId} *,0]" ok
                # input vars
                set data($winId,invars) {}
                # MUST SORT array names to get them in row order
                # foreach does not preserve order!
                foreach ele [lsort [array names ::intabledata${winId} *,0]] {
                    #ShowMessage debug info "make invars ${ele}" ok
                    lappend data($winId,invars) [set ::intabledata${winId}(${ele})]
                }
                #ShowMessage debug info "data(winId,invars) $data($winId,invars)\n\
                #        " ok
                #set data($winId,invars) [lreplace $data($winId,invars) 0 0]; # get rid of the heading
                set cbs [winfo children $inputF.table]
                set data($winId,inputAttr) {}
                foreach ele $cbs {
                    lappend data($winId,inputAttr) [$ele getvalue]
                }
                #ShowMessage debug info "data(winId,invars) $data($winId,invars)\n\
                #       data(winId,inputAttr) $data($winId,inputAttr)" ok
                # todo save nodeids not captions, make list used pairs, take from SetInputs
                # make list of nodeids
                set submodel $data($winId,submodel)
                foreach Var $data($winId,invars) {
                    set nodeId [GetIdFromCaptionPath ${submodel}/$Var]
                    lappend data($winId,inputNodes) $nodeId
                }
                #ShowMessage debug info "data(winId,inputNodes) $data($winId,inputNodes)\n\
                #        data(winId,inputAttr) $data($winId,inputAttr)" ok
                
                # output vars
                # instead of creating fields in the database they must be
                # already created and we search for them to get the index
                set N [llength [array names ::outtabledata${winId} *,0 ]]
                set data($winId,outvarNodeIndex) {}
                for {set i 1} {$i<=$N} {incr i} {
                    if $[namespace current]::cBx$i {
                        set caption [set ::outtabledata${winId}(${i},0)]
                        set index [$pFeatureClass FindField $caption]
                        if {$index<0} {
                            ShowMessage Error error "Cannot find field \"$caption\" in the feature class table.\n\
                                    Please add a field named \"$caption\" to the feature class table and then reconfigure \
                                    this link to allow this variable to be written to the GIS." ok
                        } else  {
                            lappend data($winId,outvarNodeIndex) \
                                    [GetIdFromCaptionPath ${submodel}/$caption] $index
                        }
                    }
                }
                #ShowMessage debug info "data(winId,outvarNodeIndex) $data($winId,outvarNodeIndex)" ok
                
                # get module and macro name from entry box
                set macrol [split [$macroF.entry get] .]
                set data($winId,moduleName) [lindex $macrol 0]
                set data($winId,MacroName) [lindex $macrol 1]
                
                set parent [[::esriFramework::IDocument $pMxDoc] Parent]
                # IVbaApplication
                set VbaAppl [::esriFramework::IVbaApplication $parent]
                
                UpdateState $winId
                $winId.label configure -text "ArcMap GIS Link"
                display $winId 0 0 0
            } else  {
                #ShowMessage debug info "cancel" ok
                #kill_helper_window $winId
            }
            UpdateState $winId
            destroy $dlg
        }
        
        proc SetInputs {winId pTable} {
            variable data
            #ShowMessage debug info "$data($winId,inputNodes)" ok
            if {[string match {} [array names data "$winId,inputNodes"]]} {
                return
            } elseif {[llength $data($winId,inputNodes)]==0} {
                return
            }
            
            # todo check number of records match number of instances
            set pCursor [$pTable Search [::tcom::object null] false]
            set pRow [$pCursor NextFeature]
            while {![string match {} $pRow]} {
                foreach FieldId $data($winId,inputAttr) nodeId $data($winId,inputNodes) {
                    if {$FieldId<0} {
                        continue
                    }
                    #ShowMessage debug info "$nodeId [$pRow Value $FieldId]" ok
                    #SetModelValue $nodeId [$pRow Value $FieldId]
                    set ::sliderVals($nodeId,[expr {[$pRow Value 0]+1}]) [$pRow Value $FieldId]
                }
                set pRow [$pCursor NextFeature]
            }
        }
        
        proc WriteOutputsToShapeFile {winId pTable} {
            variable data
            variable pMxDoc; # should be helper inst spec
            global pWorkspace
            global pEditor
            
            $pEditor StartEditing false; #$pWorkspace
            
            $pEditor StartEditOperation
            #ShowMessage debug info "data(\$winId,outvarNodeIndex) $data($winId,outvarNodeIndex)\n\
            #        length [llength $data($winId,outvarNodeIndex)]" ok
            if {[llength $data($winId,outvarNodeIndex)]>0} {
                set pCursor [$pTable Search [::tcom::object null] false]
                
                set pRow [$pCursor NextFeature]
                while {![string match {} $pRow]} {
                    foreach {nodeId AttrIndex} $data($winId,outvarNodeIndex) {
                        set values [lindex [GetModelValue $nodeId] 0]; # could flatten it todo
                        foreach {index v} $values {
                            $pRow Value $AttrIndex $v
                        }
                        $pRow Store
                    }
                    unset pRow
                    set pRow [$pCursor NextFeature]
                }
            }
            $pEditor StopEditOperation
            $pEditor StopEditing true
            
            [$pMxDoc ActiveView] Refresh
        }
        
        proc SetInputsOld {winId pTable} {
            variable data
            variable pQueryGetAll
            variable pCursor
            variable pMxDoc
            
            # todo check number of records match number of instances
            set nodeIds {}
            set pCursor [$pTable Search $pQueryGetAll true]
            set pRow [$pCursor NextRow]
            while {![string match {} $pRow]} {
                foreach FieldId $data($winId,inputAttr) nodeId $data($winId,inputNodes) {
                    if {$FieldId<0} {
                        continue
                    }
                    set ::sliderVals($nodeId,[expr {[$pRow Value 0]+1}]) [$pRow Value $FieldId]
                }
                set pRow [$pCursor NextRow]
            }
        }
        
        proc OnSubmodelChosen {winId submodelCB intable outtable} {
            variable submodelPaths
            variable attr
            variable chkbxVars
            
            # clear anything set
            foreach w [winfo children $intable] {
                destroy $w
            }
            foreach w [winfo children $outtable] {
                destroy $w
            }
            unset ::intabledata${winId}
            unset ::outtabledata${winId}
            
            set subpath [lindex $submodelPaths [$submodelCB getvalue]]
            #ShowMessage debug info "subpath $subpath" ok
            set io 1
            set ii 1
            set chkbxVars {}
            foreach node [GetObjectList] {
                set path [GetCaptionPathFromId $node]
                if {[string match ${subpath} [file dirname $path]]} {
                    #ShowMessage debug info "GetModelEval node [GetModelType $node]" ok
                    if {[string match VALUELESS [GetModelType $node]]} {
                        # do nothing
                    } elseif {[string match INPUT [GetModelEval $node]]} {
                        set ::intabledata${winId}($ii,0) [file tail $path]
                        set ::intabledata${winId}($ii,1) [GetModelType $node]
                        set comboBox [ComboBox ${intable}.cB$ii -values $attr($winId)]
                        $intable window config $ii,2 -window $comboBox
                        incr ii
                    } else  {
                        set ::outtabledata${winId}($io,0) [file tail $path]
                        set ::outtabledata${winId}($io,1) [GetModelType $node]
                        set checkBox [checkbutton ${outtable}.cBx$io -variable [namespace current]::cBx$io]
                        lappend chkbxVars [namespace current]::cBx$io
                        $outtable window config $io,2 -window $checkBox
                        incr io
                    }
                }
            }
            #ShowMessage debug info "io $io" ok
        }
        
        proc OnLayerChosen {winId layerCB intable} {
            global Arc_Map
            #pIAttributeTable
            variable attr
            #ShowMessage debug info [$layerCB getvalue] ok
            # get GIS attribute names
            set pMxDoc [::esriArcMapUI::IMxDocument $Arc_Map($winId)]
            set pMap [$pMxDoc FocusMap]; # IMap
            set pLayer [$pMap Layer [$layerCB getvalue]]
            set pIAttributeTable [::esriCarto::IAttributeTable $pLayer]; # IUnknown
            if [string match "" $pIAttributeTable] {
                ShowMessage Error error "[$pLayer Name] has no atrributes" ok
            }
            set pAttributeTable [$pIAttributeTable AttributeTable]; # ITable
            
            set pFields [$pAttributeTable Fields]
            
            set attr($winId) {}
            foreach field [::ArcMap::GetTableFieldNames $pFields] {
                lappend attr($winId) $field
            }
            #ShowMessage debug info "fields $attr($winId)" ok
            
            # todo all
            foreach cb [winfo children $intable] {
                $cb configure -text "" -values $attr($winId)
            }
        }
        
        proc UpdateState {winId} {
            variable data
            
            regsub -all $winId [array get data $winId,*] /WIN/ saveString
            #ShowMessage debug info "saveString $saveString" ok
            SetState $winId $saveString
        }
        
    } ;
    # end of namespace
}
