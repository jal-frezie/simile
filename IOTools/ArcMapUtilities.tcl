if {[string equal windows $::tcl_platform(platform)]} {
package require tcom
package require registry

# global vars used for COM object pointers namespace vars seem to get deleted
# at present allowing each helper instance to create own acrmap etc

namespace eval ArcMap {
    
    global Arc_Map; #refs seem to get lost if namespace vars
    global Arc_ArcMap
    
    variable TypeLibLoaded false
    variable esriType {integer longint single double string date ObjId Geom Blob}
    
    variable esriCorekey HKEY_CLASSES_ROOT\\TypeLib\\{866AE5D3-530C-11D2-A2BD-0000F8774FB5}\\1.0\\0\\win32
    variable esriCore_typelib [registry get $esriCorekey ""]
    variable esriMxkey HKEY_CLASSES_ROOT\\TypeLib\\{AA603763-259A-11D3-9F4A-00C04F6BC621}\\1.0\\0\\win32
    variable esriMx_typelib [registry get $esriMxkey ""]
    
    proc StartArcMap {ref} {
        global Arc_ArcMap
        global Arc_Map
        variable TypeLibLoaded
        variable esriCore_typelib
        variable esriMx_typelib
        #set origcursor [.mre cget -cursor]
        #.mre configure -cursor watch
        
        if {!$TypeLibLoaded} {
            ::tcom::import $esriCore_typelib
            ::tcom::import $esriMx_typelib; # ArcMap
        }
        
        set Arc_Map($ref) [::esriCore::MxDocument]; # start ArcMap
        set Arc_ArcMap($ref) [$Arc_Map($ref) -get Parent]; # get a reference to the application
        $Arc_ArcMap($ref) -set Visible True
        $Arc_ArcMap($ref) Caption "Simile ArcMap display"
        $Arc_ArcMap($ref) Visible True
        #    frmStartArcMap.MousePointer = vbNormal
        #.mre configure -cursor $origcursor
    }
    
    proc QuitArcMap {ref} {
        global Arc_ArcMap Arc_ArcMap
        
        $Arc_ArcMap($ref) -method Shutdown;  # Quit ArcMap
        #    Set m_pDoc = Nothing  ' Release m_pDoc
        #    Set m_pApp = Nothing  ' Releasr m_pApp
    }
    
    
    proc AddShapeFiles {ref multiSelect} {
        # multiSelect : boolean; true if allow open more than 1 file
        global Arc_Map Arc_ArcMap
        
        #set origcursor [.mre cget -cursor]
        #.mre configure -cursor watch
        
        # Obtain the object factory interface from the app
        set pObjFactory [::esriCore::IObjectFactory $Arc_ArcMap($ref)]
        
        # Get a reference to the ArcMap document and the focus map
        set pMxDoc [::esriCore::IMxDocument $Arc_Map($ref)]
        set pMap [$pMxDoc FocusMap]
        
        # Create feature layers and add them to ArcMap.
        # Note that we will use ArcMaps generic object factory to ensure that
        # these objects exist in ArcMaps process space.
        
        # Display the GXDialog to allow user to choose data.
        set pGxDialog [$pObjFactory Create "esriCore.GxDialog" ]
        set pGxDialog [::esriCore::IGxDialog $pGxDialog]
        $pGxDialog AllowMultiSelect $multiSelect
        $pGxDialog Title "Select Feature Classes to Add To ArcMap"
        
        # Equivalent to Set pGxFilter = New GxFilterFeatureClasses
        set pGxFilter [$pObjFactory Create "esriCore.GxFilterFeatureClasses"]
        set pGxFilter [::esriCore::IGxObjectFilter $pGxFilter]
        #$pGxDialog ObjectFilter $pGxFilter; # doesn't like it
        set ifc [::esriCore::IGxObjectFilterCollection $pGxDialog]
        $ifc AddFilter $pGxFilter 1
        
        set pGxObjects {}; #[::esriCore::EnumGxObject]; # selection
        $pGxDialog DoModalOpen [$Arc_ArcMap($ref) hWnd] pGxObjects
        
        ###############################################################################
        if {[string match {} $pGxObjects]} {
            return
        } else  {
            $pGxObjects Reset
            set pGxDataset [$pGxObjects Next]
            #Create Layer
            while {![string match {} $pGxDataset]} {
                set pGxDataset [::esriCore::IGxDataset $pGxDataset]
                set pFeatureLayer [$pObjFactory Create "esriCore.FeatureLayer"]
                
                set pFeatureLayer [::esriCore::IGeoFeatureLayer $pFeatureLayer]
                $pFeatureLayer FeatureClass [$pGxDataset Dataset]
                $pFeatureLayer Name [[$pFeatureLayer FeatureClass] AliasName]
                $pMap AddLayer $pFeatureLayer
                set pGxDataset [$pGxObjects Next]
                #unset those set? todo
            }
        }
        #.mre configure -cursor $origcursor
        [$pMxDoc ActiveView] Refresh
    }
    
    proc AddMap {ref multiSelect} {
        # multiSelect : boolean; true if allow open more than 1 file
        global Arc_Map Arc_ArcMap
        
        #set origcursor [.mre cget -cursor]
        #.mre configure -cursor watch
        
        # Obtain the object factory interface from the app
        set pObjFactory [::esriCore::IObjectFactory $Arc_ArcMap($ref)]
        
        # Get a reference to the ArcMap document and the focus map
        set pMxDoc [::esriCore::IMxDocument $Arc_Map($ref)]
        #set pMap [$pMxDoc FocusMap]
        
        # Create feature layers and add them to ArcMap.
        # Note that we will use ArcMaps generic object factory to ensure that
        # these objects exist in ArcMaps process space.
        
        # Display the GXDialog to allow user to choose data.
        set pGxDialog [$pObjFactory Create "esriCore.GxDialog" ]
        set pGxDialog [::esriCore::IGxDialog $pGxDialog]
        $pGxDialog AllowMultiSelect $multiSelect
        $pGxDialog Title "Load a map"
        
        # Equivalent to Set pGxFilter = New GxFilterFeatureClasses
        set pGxFilter [$pObjFactory Create "esriCore.GxFilterMaps"]; # choose file type
        set pGxFilter [::esriCore::IGxObjectFilter $pGxFilter]
        set ifc [::esriCore::IGxObjectFilterCollection $pGxDialog]
        $ifc AddFilter $pGxFilter 1
        
        set pGxObjects {}; #[::esriCore::EnumGxObject]; # selection
        $pGxDialog DoModalOpen [$Arc_ArcMap($ref) hWnd] pGxObjects
        
        if {[string match {} $pGxObjects]} {
            return
        } else  {
            $pGxObjects Reset
            set pGxDataset [$pGxObjects Next]
            #Create Layer
            while {![string match {} $pGxDataset]} {
                #ShowMessage debug info "Name [$pGxDataset Name]\
                #        FullName [$pGxDataset FullName]\
                #        BaseName [$pGxDataset BaseName]" ok
                $Arc_ArcMap($ref) OpenDocument [$pGxDataset FullName]
                set Arc_Map($ref) [$Arc_ArcMap($ref) Document]
                
                set pGxDataset [$pGxObjects Next]
                #unset those set? todo
            }
        }
        #.mre configure -cursor $origcursor
        [$pMxDoc ActiveView] Refresh
    }
    
    proc ArcMapFileOpen {winId} {
        # executes the ArcMap application's File Open menu item
        global Arc_Map
        set pCommandBars [$Arc_Map($winId) CommandBars]
        set pUIDFM [::esriCore::UID]
        $pUIDFM Value "esriCore.MxFileMenuItem"
        $pUIDFM SubType 2; # open item New is 1, 3 is save etc.
        set pCmdItem [$pCommandBars Find $pUIDFM]
        $pCmdItem Execute
    }
    
    proc GetTableAttr {pFeatureLayer} {
        set pIAttributeTable [::esriCore::IAttributeTable $pFeatureLayer]; # IUnknown
        set pAttributeTable [$pIAttributeTable AttributeTable]; # ITable
        
        set pFields [$pAttributeTable Fields]
        set FieldCount [$pFields FieldCount]
        for {set i 0} {$i<$FieldCount} {incr i} {
            puts -nonewline "[[$pFields Field $i] Name] "
        }
        puts ""
        # eg FID Shape NAME ID Salinity x
        
        
        set pQuery [::esriCore::QueryFilter]
        set pQuery [::esriCore::IQueryFilter $pQuery]
        $pQuery WhereClause "FID>-1"
        set RowCount [$pAttributeTable RowCount $pQuery]
        for {set j 0} {$j<$RowCount} {incr j} {
            set pRow [$pAttributeTable GetRow $j]
            for {set i 0} {$i<$FieldCount} {incr i} {
                puts -nonewline "[$pRow Value $i] "
            }
            puts ""
        }
        
    }
    
    # prototype proc from working with wish
    proc GetAttrValues {pFeatureLayer} {
        set pIAttributeTable [::esriCore::IAttributeTable $pFeatureLayer]; # IUnknown
        set pAttributeTable [$pIAttributeTable AttributeTable]; # ITable
        
        set pFields [$pAttributeTable Fields]
        set FieldCount [$pFields FieldCount]
        for {set i 0} {$i<$FieldCount} {incr i} {
            puts -nonewline "[[$pFields Field $i] Name] "
        }
        puts ""
        # eg FID Shape NAME ID Salinity x
        
        
        set pQuery [::esriCore::QueryFilter]
        set pQuery [::esriCore::IQueryFilter $pQuery]
        $pQuery WhereClause "FID>-1"
        set RowCount [$pAttributeTable RowCount $pQuery]
        for {set j 0} {$j<$RowCount} {incr j} {
            set pRow [$pAttributeTable GetRow $j]
            for {set i 0} {$i<$FieldCount} {incr i} {
                puts -nonewline "[$pRow Value $i] "
            }
            puts ""
        }
        
    }
    
    
    proc GetTableFieldNames {pFields} {
        set FieldCount [$pFields FieldCount]
        set FieldNames {}; #{Name Type}
        for {set i 0} {$i<$FieldCount} {incr i} {
            lappend FieldNames "[[$pFields Field $i] Name] \
                    [lindex $::ArcMap::esriType [[$pFields Field $i] Type]]"
        }
        return $FieldNames
    }
    
    # in progress does not work
    proc WriteAttr {pFeatureLayer} {
        set pEditor [$ArcMap FindExtensionByName "ESRI Object Editor"]; # IExtension
        set pEditor [::esriCore::IEditor $pEditor]
        set pDataset [$pFeatureLayer FeatureClass]
        set pDataset [::esriCore::IDataset $pDataset]
        set pWorkspace [$pDataset Workspace]
        
        $pEditor StartEditing $pWorkspace
        
        # set value of current row field 4
        #see GetTableAttr
        $pRow Value 5 4.3
        $pRow Store
        $pEditor StopEditing 1
        
        # need to tell map to update
        [$pMxDoc ActiveView] Refresh
    }
    
    # This will make a dbf table that can be attached to a shapefile
    # DOES NOT WORK - AT THE STAGE OF WORKING OUT WHAT CALLS TO MAKE!
    proc MakeDBF {winId Name Folder Fields} {
        
        
        # param strName As String, _
        #strFolder As String, _
        #Optional pFields As IFields
        
        # return ITable
        
        
        # createDBF: simple function to create a DBASE file.
        # note: the name of the DBASE file should not contain the .dbf extension
        #
        ##On Error GoTo EH
        
        # Open the Workspace
        #Dim pFWS As IFeatureWorkspace
        #Dim pWorkspaceFactory As IWorkspaceFactory
        #Dim fs as object
        #Dim pFieldsEdit As esriCore.IFieldsEdit
        #Dim pFieldEdit As esriCore.IFieldEdit
        #Dim pField As IField
        
        # Obtain the object factory interface from the app
        set pObjFactory [::esriCore::IObjectFactory $Arc_ArcMap($ref)]
        
        set pWorkSpaceFactory [$pObjFactory Create "esriCore.ShapefileWorkspaceFactory"]
        set pWorkSpaceFactory [::esriCore::IWorkspaceFactory $pWorkSpaceFactory]
        
        ## do directory exists in Tcl!! todo
        set fs [$pObjFactory Create "Scripting.FileSystemObject"]
        if {![$fs FolderExists $Folder]} {
            ShowMessage Warning warning "Folder does not exist: /n  $Folder" ok
            return
        }
        #Set pFWS = pWorkspaceFactory.OpenFromFile(strFolder, 0)
        set pFWS [$pWorkspaceFactory OpenFromFile $strFolder 0]
        
        # if a fields collection is not passed in then create one
        #If pFields Is Nothing Then
        # create the fields used by our object
        set pFields [$pObjFactory Create "esriCore.Fields"]
        set pFieldsEdit [::esriCore::IFieldsEdit $pFields]
        #$pFieldsEdit FieldCount 1
        
        foreach {field type} $Fields {
            #Create text Field
            set pField [$pObjFactory Create "esriCore.Field"]
            set pFieldEdit [::esriCore::::IFieldEdit $pField]
            $pFieldEdit Length 30; ###################
            $pFieldEdit Name = "TextField"
            $pFieldEdit Type = esriFieldTypeString
            $pFieldsEdit Field 0 $pField
        }
        
        Set createDBF = pFWS.CreateTable(strName, pFields, Nothing, Nothing, "")
        
    }
    
    
    
    # procs to return value forced to boolean (otherwise Tcl may have left it as a string)
    ##StartArcMap .
    ##AddShapeFiles . false
    
    # find active feature layer and get its attributes
    ##set pMxDoc [::esriCore::IMxDocument $Arc_Map(.)]
    ##set pMap [$pMxDoc FocusMap]; # IMap
    ##puts [$pMap Name]
    ##set Layer [$pMap Layer 0]
    #puts $Layer
    #GetTableAttr $Layer
    ##puts [GetTableFieldNames $Layer]
    
    
    
}; # end namespace
}
