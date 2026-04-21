#include "tcl.h"

#ifdef WIN32
    #define EXPORT __declspec( dllexport )
#else
    #define EXPORT
    #define LINK_ON_RUN 1
#endif
// extern "C" not needed, this _is_ C

#ifdef LINK_ON_RUN
    #include <stdlib.h>
    #include <stdint.h>
    #include <string.h>
    #include <dlfcn.h>
    #include "gdal_tcl.h"
#ifdef MACOS
#define GDAL_SHARELIB "/opt/homebrew/lib/libgdal.dylib"
#define ALT_GDAL_SHARELIB "libgdal.dylib"
#else
#define GDAL_SHARELIB "libgdal.so"
#endif
#else
#ifdef MACOS
    #include <GDAL/gdal.h>
    #include <GDAL/cpl_string.h>
#else
    #include <gdal.h>
    #include <cpl_string.h>
#endif
#endif

#if TCL_MAJOR_VERSION<9
typedef int Tcl_Size;
#endif

#define XSIZE 0
#define YSIZE 1
#define COUNT 2
#define VARS 3
#define CLOSE 99

char scratch[256];

int gdalOpenReadOnlyCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *const argv[]) {
  GDALDatasetH  *hDataset;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "file_name");
    return TCL_ERROR;
  }

  hDataset = (GDALDatasetH*)malloc(sizeof(GDALDatasetH));
  *hDataset = GDALOpen(Tcl_GetStringFromObj(argv[1], NULL), GA_ReadOnly );
  if( *hDataset ) {
    sprintf(scratch, "gdal_ds_%08lx", (intptr_t)hDataset);
    Tcl_SetStringObj(Tcl_GetObjResult(interp), scratch, -1);
    return TCL_OK;
  } else {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Failed to open file", -1);
    return TCL_ERROR;
  }
}

int gdalCreateCopyCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *const argv[]) {
  GDALDatasetH *hSrcDS, *hDataset;
  GDALDriverH hDriver;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "file_name driver_id handle_to_copy");
    return TCL_ERROR;
  }

  hDriver = GDALGetDriverByName(Tcl_GetStringFromObj(argv[2], NULL));
  if( hDriver == NULL ) {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Bad driver", -1);
    return TCL_ERROR;
  }

  if (!sscanf(Tcl_GetStringFromObj(argv[3], NULL), "gdal_ds_%lx", 
	      (intptr_t*)&hSrcDS)) {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Bad handle", -1);
    return TCL_ERROR;
  }
  hDataset = (GDALDatasetH*)malloc(sizeof(GDALDatasetH));
  *hDataset = (GDALDatasetH)GDALCreateCopy(hDriver,
					   Tcl_GetStringFromObj(argv[1], NULL),
					   *hSrcDS, 0, NULL, NULL, NULL );
  if( *hDataset ) {
    sprintf(scratch, "gdal_ds_%08lx", (intptr_t)hDataset);
    Tcl_SetStringObj(Tcl_GetObjResult(interp), scratch, -1);
    return TCL_OK;
  } else {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Failed to create copy", -1);
    return TCL_ERROR;
  }
}

int gdalAccessCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *const argv[]) {
  GDALDatasetH  *hDataset;
  int setInfo;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "file_handle");
    return TCL_ERROR;
  }

  if (!sscanf(Tcl_GetStringFromObj(argv[1], NULL), "gdal_ds_%lx", 
	      (intptr_t*)&hDataset)) {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Bad handle", -1);
    return TCL_ERROR;
  }

  switch ((intptr_t)clientData) {
  case XSIZE:
    setInfo = GDALGetRasterXSize(*hDataset);
    break;
  case YSIZE:
    setInfo = GDALGetRasterYSize(*hDataset);
    break;
  case COUNT:
    setInfo = GDALGetRasterCount(*hDataset);
    break;
  case VARS:
    for (setInfo = 1; setInfo <= GDALGetRasterCount(*hDataset); ++setInfo) {
      Tcl_ListObjAppendElement(interp, Tcl_GetObjResult(interp),
			       Tcl_NewIntObj(setInfo));
    }
    return TCL_OK;
  case CLOSE:
    GDALClose(*hDataset);
    return TCL_OK;
 default:
    Tcl_SetIntObj(Tcl_GetObjResult(interp), (intptr_t)clientData);
    return TCL_ERROR;
  }
  Tcl_SetIntObj(Tcl_GetObjResult(interp), setInfo);
  return TCL_OK;
}

int gdalGetRasterBand(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *const argv[]) {

  GDALDatasetH  *hDataset;
  int bandIndex, error;
  GDALRasterBandH *hBand;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "file_handle band_index");
    return TCL_ERROR;
  }

  if (!sscanf(Tcl_GetStringFromObj(argv[1], NULL), "gdal_ds_%lx", 
	      (intptr_t*)&hDataset)) {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Bad handle", -1);
    return TCL_ERROR;
  }

  error = Tcl_GetIntFromObj(interp, argv[2], &bandIndex);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  hBand = (GDALRasterBandH*)malloc(sizeof(GDALRasterBandH));
  *hBand = GDALGetRasterBand( *hDataset, bandIndex );

  if( *hBand ) {
    sprintf(scratch, "gdal_rb_%08lx", (intptr_t)hBand);
    Tcl_SetStringObj(Tcl_GetObjResult(interp), scratch, -1);
    return TCL_OK;
  } else {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Failed to open band", -1);
    return TCL_ERROR;
  }
}

int gdalGetRasterValues(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *const argv[]) {
  char *bandHandle;
  GDALRasterBandH *hBand;
  int error, l,t,w,h,x,y,cx,cy;
  Tcl_Size xl;
  float *holder;
  double dbl;
  CPLErr failure;
  Tcl_Obj* lineList;

  if (clientData) { // writing to file
    if (argc != 7) {
      Tcl_WrongNumArgs(interp, 1, argv, "band left top width height data");
      return TCL_ERROR;
    } 
  } else if (argc != 6 && argc != 8) {
    Tcl_WrongNumArgs(interp, 1, argv, "band left top width height ?cols rows?");
    return TCL_ERROR;
  }

  bandHandle = Tcl_GetStringFromObj(argv[1], NULL);

  if (!sscanf(bandHandle, "gdal_rb_%lx", (intptr_t*)&hBand)) {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Bad handle", -1);
    return TCL_ERROR;
  }


  error = Tcl_GetIntFromObj(interp, argv[2], &l);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[3], &t);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[4], &w);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[5], &h);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  if (clientData) { // writing to file
    Tcl_Obj **eltListY, **eltListX;

    if (Tcl_ListObjGetElements(interp, argv[6], &xl, &eltListY) != TCL_OK)
      return TCL_ERROR;
    y = (int)xl;
    for (cy=0; cy<y; ++cy) {
      if (Tcl_ListObjGetElements(interp, eltListY[cy], &xl, &eltListX)!= TCL_OK)
	return TCL_ERROR;
      x = (int)xl;
      if (cy) {
	if (cx!=x) {
	  Tcl_SetStringObj(Tcl_GetObjResult(interp), 
			   "Data lines not all same length", -1);
	  return TCL_ERROR;
	}
      } else
	holder = (float*)malloc(x*y*sizeof(float));
      for (cx=0; cx<x; ++cx) {
	if (Tcl_GetDoubleFromObj(interp, eltListX[cx], &dbl)==TCL_OK)
	  holder[x*cy+cx] = (float)dbl;
	else
	  return TCL_ERROR;
      }
    }
    failure = GDALRasterIO( *hBand, GF_Write, l, t, w, h,
			    holder, x, y, GDT_Float32, 
			    0, 0 );
    if (failure) {
      free(holder);
      Tcl_SetIntObj(Tcl_GetObjResult(interp), failure);
      return TCL_ERROR;
    }
  } else {      
    if (argc == 8) {
      error = Tcl_GetIntFromObj(interp, argv[6], &x);
      if (error != TCL_OK) {    
	return error;
      } /* if(error) */
      
      error = Tcl_GetIntFromObj(interp, argv[7], &y);
      if (error != TCL_OK) {    
	return error;
      } /* if(error) */
    } else {
      x=w;
      y=h;
    }
    
    holder = (float*)malloc(x*y*sizeof(float));
    failure = GDALRasterIO( *hBand, GF_Read, l, t, w, h,
			    holder, x, y, GDT_Float32, 
			    0, 0 );
    if (failure) {
      free(holder);
      Tcl_SetIntObj(Tcl_GetObjResult(interp), failure);
      return TCL_ERROR;
    }
    
    // now convert into a nested array tclObj
    for (cy=0; cy<y; ++cy) {
      lineList = Tcl_NewListObj(0, NULL);
      for (cx=0; cx<x; ++cx) {
	Tcl_ListObjAppendElement(interp, lineList, 
				 Tcl_NewDoubleObj(holder[x*cy+cx]));
      }
      Tcl_ListObjAppendElement(interp, Tcl_GetObjResult(interp), lineList);
    }
  }
  free(holder);
  return TCL_OK;
}

/* byte version allows calling prog to set target array size */

int gdalGetRasterData(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *const argv[]) {
  char *bandHandle, *typeP;
  GDALRasterBandH *hBand;
  int error, l,t,w,h,x,y,sizes[11] = {1,2,2,4,4,4,8,4,8,8,16};
  Tcl_Size cposn;
  unsigned char *holder;
  CPLErr failure;
  Tcl_Obj* lineList;
  GDALDataType types[11] = {GDT_Byte,GDT_UInt16,GDT_Int16,GDT_UInt32,
			    GDT_Int32,GDT_Float32,GDT_Float64,GDT_CInt16,
			    GDT_CInt32,GDT_CFloat32,GDT_CFloat64};
  char typestrs[11][16] = {"GDT_Byte","GDT_UInt16","GDT_Int16","GDT_UInt32",
			   "GDT_Int32","GDT_Float32","GDT_Float64","GDT_CInt16",
			   "GDT_CInt32","GDT_CFloat32","GDT_CFloat64"};

  if (clientData) {
    cposn = 8;
    typeP = "band left top width height datatype cols rows data";
  } else {
    cposn = 7;
    typeP = "band left top width height datatype ?cols rows?";
  }
  if ((clientData || argc != cposn) && argc != cposn+2) {
    Tcl_WrongNumArgs(interp, 1, argv, typeP);
    return TCL_ERROR;
  }
  
  bandHandle = Tcl_GetStringFromObj(argv[1], NULL);

  if (!sscanf(bandHandle, "gdal_rb_%lx", (intptr_t*)&hBand)) {
    Tcl_SetStringObj(Tcl_GetObjResult(interp), "Bad handle", -1);
    return TCL_ERROR;
  }

  error = Tcl_GetIntFromObj(interp, argv[2], &l);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[3], &t);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[4], &w);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[5], &h);
  if (error != TCL_OK) {    
    return error;
  } /* if(error) */

  if (argc == cposn+2) {
    error = Tcl_GetIntFromObj(interp, argv[7], &x);
    if (error != TCL_OK) {    
      return error;
    } /* if(error) */
    
    error = Tcl_GetIntFromObj(interp, argv[8], &y);
    if (error != TCL_OK) {    
      return error;
    } /* if(error) */
  } else {
    x=w;
    y=h;
  }

  typeP = Tcl_GetStringFromObj(argv[6],NULL);
  for (error=0;error<11;++error) {
    if (!strcmp(typestrs[error], typeP)) {
	break;
    }
  }
  if (error==11) {
    Tcl_AppendStringsToObj(Tcl_GetObjResult(interp), 
			   "No such data type: \"", typeP, "\".", NULL);
    return TCL_ERROR;
  }
  
  if (clientData) {
    holder = Tcl_GetByteArrayFromObj(argv[9],&cposn);
    if (cposn != x*y*sizes[error]) {
      Tcl_SetStringObj(Tcl_GetObjResult(interp), "Wrong size byte array", -1);
      return TCL_ERROR;
    }
    failure = GDALRasterIO( *hBand, GF_Write, l, t, w, h,
			    holder, x, y, types[error], 
			    0, 0 );
  } else {
    holder = Tcl_SetByteArrayLength(Tcl_GetObjResult(interp), x*y*sizes[error]);
    failure = GDALRasterIO( *hBand, GF_Read, l, t, w, h,
			    holder, x, y, types[error], 
			    0, 0 );
  }
  if (failure) {
    Tcl_SetIntObj(Tcl_GetObjResult(interp), failure);
    return TCL_ERROR;
  }
  return TCL_OK;
}

EXPORT int Gdal_Init(Tcl_Interp *interp) {
  /* Use the Tcl Stubs mechanism */
  Tcl_InitStubs(interp, "8.5", 0);

#ifdef LINK_ON_RUN
  void* handle = dlopen(GDAL_SHARELIB, RTLD_NOW | RTLD_LOCAL);
#ifdef ALT_GDAL_SHARELIB
  if (!handle) {
    void* handle = dlopen(ALT_GDAL_SHARELIB, RTLD_NOW | RTLD_LOCAL);
  }
#endif
  if (!handle) {
    printf("Failed to open shared object: %s\n", dlerror());
    return 0;
  }
  void* fns[10];
  char* fn_names[] = {"GDALAllRegister", "GDALOpen", "GDALGetDriverByName", "GDALCreateCopy", "GDALGetRasterXSize", "GDALGetRasterYSize", "GDALGetRasterCount", "GDALGetRasterBand", "GDALClose", "GDALRasterIO"};
  int i; for (i=0; i<10; ++i)  {
    fns[i] = dlsym(handle,fn_names[i]);
    if (!fns[i]) {
      printf("Failed to find shared functtion %s because %s\n",
	     fn_names[i], dlerror());
      return 0;
    }
  }
  GDALAllRegister = (GDALAllRegister_type*)fns[0];
  GDALOpen = (GDALOpen_type*)fns[1];
  GDALGetDriverByName = (GDALGetDriverByName_type*)fns[2];
  GDALCreateCopy = (GDALCreateCopy_type*)fns[3];
  GDALGetRasterXSize = (GDALGetRasterXSize_type*)fns[4];
  GDALGetRasterYSize = (GDALGetRasterYSize_type*)fns[5];
  GDALGetRasterCount = (GDALGetRasterCount_type*)fns[6];
  GDALGetRasterBand = (GDALGetRasterBand_type*)fns[7];
  GDALClose = (GDALClose_type*)fns[8];
  GDALRasterIO = (GDALRasterIO_type*)fns[9];
#endif
  
  GDALAllRegister();
  Tcl_CreateObjCommand(interp, "gdal_open_read_only", gdalOpenReadOnlyCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_create_copy", gdalCreateCopyCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_get_x_size", gdalAccessCmd,
		       (ClientData)XSIZE, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_get_y_size", gdalAccessCmd,
		       (ClientData)YSIZE, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_get_count", gdalAccessCmd,
		       (ClientData)COUNT, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_get_var_names", gdalAccessCmd,
		       (ClientData)VARS, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_get_raster_band", gdalGetRasterBand,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_get_raster_values", gdalGetRasterValues,
		       (ClientData)0, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_set_raster_values", gdalGetRasterValues,
		       (ClientData)1, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_get_raster_data", gdalGetRasterData,
		       (ClientData)0, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_set_raster_data", gdalGetRasterData,
		       (ClientData)1, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "gdal_close", gdalAccessCmd,
		       (ClientData)CLOSE, (Tcl_CmdDeleteProc *)NULL);
  return Tcl_PkgProvide(interp, "gdal", "1.1");
}
