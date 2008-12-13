// Definitions used in this code and the model code
#include <tcl.h>
#include <dllcalls.h>

char simileVersion[] = SIMILE_VERSION;

/* next two call convert_to_tcl, which calls them, so declare in advance */
Tcl_Obj* convert_to_tcl(int*, int*, char*);

Tcl_Obj* append_list_members(int dimty, int depth, int* dims, int* indices, 
			     int* subBlocks, int *members, char** block) {
  Tcl_Obj *localObj, *localSubObj;
  int count;
  if (depth==dimty) {
    if (*members) {
      *block += dimty*sizeof(int);
      localObj = convert_to_tcl(dims, subBlocks, *block);
      *block += subBlocks[0];
      --*members;
    } else {
      localObj = Tcl_NewListObj(0, NULL);
    }
  } else {
    localObj = Tcl_NewListObj(0, NULL);
    while (*members) {
      for (count=0; count<depth; ++count) {
	if (((int*)*block)[count]!=indices[count]) return(localObj);
      }
      indices[depth] = ((int*)*block)[depth];
      localSubObj = append_list_members(dimty, depth+1, dims, indices,
					subBlocks, members, block);
      Tcl_ListObjLength(NULL, localSubObj, &count); // re-use count variable
      if (count) {
	Tcl_ListObjAppendElement(NULL, localObj, Tcl_NewIntObj(indices[depth]));
	Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
      }
    }
  }
  return(localObj);
}

Tcl_Obj* append_array_members(int membership, int* dims, int* subBlocks, 
			      char* block) {
  Tcl_Obj *localObj, *indObj, *localSubObj;
  int offset, arrayOut;
  
  localObj = Tcl_NewListObj(0, NULL);
  for (offset = 0; membership > offset; ++offset) {
    indObj = Tcl_NewIntObj(offset+1);
    localSubObj = convert_to_tcl(dims, subBlocks, block+offset*subBlocks[0]);
    Tcl_ListObjLength(NULL, localSubObj, &arrayOut);
    if (arrayOut) {
      Tcl_ListObjAppendElement(NULL, localObj, indObj);
      Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
    }
  }
  return localObj;
}
  
Tcl_Obj* convert_to_tcl(int* dims, int* subBlocks, char* block) {
  Tcl_Obj *localObj;
  int membership, *indices;
  char *newBlock, *blockEnd;

  if (dims[0] > 0) { // it's an array bound
    localObj = append_array_members(dims[0], dims+1, subBlocks+1, block);
  } else {
    switch (dims[0]) {
    case OWNSIZED:
      membership = ((sizeAndPtr*)block)->size;
      newBlock = ((sizeAndPtr*)block)->ptr;
      localObj = append_array_members(membership, dims+1, subBlocks+1, newBlock);
      break;
    case SPARSEARRAY: 
      // need clevers to nest indices; see old stuff
      membership = ((sizeAndPtr*)block)->size;
      newBlock = ((sizeAndPtr*)block)->ptr;
      block = newBlock;
      indices = (int*)malloc(sizeof(int)*dims[1]);
      blockEnd = block+membership*(dims[1]*sizeof(int)+subBlocks[1]);
      localObj = append_list_members(dims[1], 0, dims+2, indices, subBlocks+1,
				     &membership, &block);
      free(indices);
      break;
    case VALUELESS:
      localObj = Tcl_NewStringObj("sm", -1);
      break;
    case REAL:
      localObj = Tcl_NewDoubleObj(*(double *)block);
      break;
    case FLAG:
      localObj = Tcl_NewBooleanObj(*(int *)block);
      break;
    default: /* INTEGER or ENUM(*) */
      localObj = Tcl_NewIntObj(*(int *)block);
    }
  }
  return localObj;
}

void make_sub_block_sizes(int *dims, int *sizes) {
  int usedDims = 1;
  switch (dims[0]) {
  case SPARSEARRAY:
    usedDims = 2;
  case OWNSIZED:
    make_sub_block_sizes(dims+usedDims, sizes+1);
    sizes[0] = sizeof(sizeAndPtr);
    break;
  case REAL:
    sizes[0] = sizeof(double);
    break;
  case FLAG:
    sizes[0] = sizeof(BOOLEAN);
    break;
  case VALUELESS:
    sizes[0] = 0;
    break;
  default: // dimension, INTEGER or enumerated type
    if (dims[0]>0) {
      make_sub_block_sizes(dims+1, sizes+1);
      sizes[0]=sizes[1]*dims[0];
    } else
      sizes[0] = sizeof(int);
  }
}

FINDABLE int extractListCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  Tcl_Obj *resultPtr, *newData;
  int iPosn, error;

  char spare[256];
  int dims[32], path[32];
  long int mSpare;
  enum_type_data* usedTypes[32];
  nodeValues* c_result;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "data_handle");
    return TCL_ERROR;
  }

  error = Tcl_GetLongFromObj(interp, argv[1], (long int*)&c_result);
  if (error != TCL_OK) {
    return error;
  }
  
  int subBlocks[32];
  make_sub_block_sizes(c_result->dimSpecs, subBlocks);
  resultPtr = convert_to_tcl(c_result->dimSpecs, subBlocks, c_result->contents);
  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}

/* New version using nodeValues structure -- first its callback procs */

void add_to_size(void* spareValue, int spareOffset, void* sizePtr) {
  // sizePtr is actually an integer pointer
  ++(*(int*)sizePtr);
}

// structures to treat last arg of callback as 
typedef struct addSorted_pt {
  int baseType;
  int *discCount;
  double **dPtrDiscList;
} addSortedParms;

// only doubles work for now, add ints to this later
void addSorted(void* values, int offset, addSortedParms* cbData) {
  //void addDSorted(int* discCount, double** dPtrDiscList, double newVal) {
  double *spareArr, **dPtrDiscList, newVal;
  int count, exp, bigexp, *discCount;

  if (cbData->baseType == REAL) 
    newVal = ((double*)values)[offset];
  else 
    newVal = ((int*)values)[offset];
  discCount = cbData->discCount;
  dPtrDiscList = cbData->dPtrDiscList;

  spareArr = *dPtrDiscList;
  // straight search could be replaced by binary if more speed needed
  for (count=0; count<*discCount; ++count) {
    if (newVal==spareArr[count]) {
      return;
    } else if (newVal<spareArr[count]) {
      break;
    }
  }
  if (*discCount>=16 && frexp(*discCount,&bigexp)<frexp((*discCount)-1,&exp)) {
    *dPtrDiscList = (double*)malloc(sizeof(double)*(int)(ldexp(1,bigexp)));
    memmove(*dPtrDiscList, spareArr, count*sizeof(double));
  }
  memmove(*dPtrDiscList+count+1, spareArr+count, 
	  (*discCount-count)*sizeof(double));
  (*dPtrDiscList)[count] = newVal;
  ++(*discCount);
  if (*dPtrDiscList!=spareArr) free(spareArr);
}

// structures to treat last arg of callback as 
typedef struct convert_pt {
  int baseType;
  unsigned char** tgtPtr;
  double *valfor0, *valfor255;
} convertParms;

void convert_to_byte(void* values, int offset, convertParms* cbData) {
  unsigned char** tgtPtr;
  double valfor0, valfor255, thisVal;

  valfor0 = *cbData->valfor0;
  valfor255 = *cbData->valfor255;
  if (cbData->baseType == REAL) 
    thisVal = ((double*)values)[offset];
  else 
    thisVal = ((int*)values)[offset];

//  sprintf(globMess, "Span is %lf to %lf; off %d, val %lf", valfor0, valfor255,
//	  offset, values[offset]);
//  showMess(globMess);
  *((*cbData->tgtPtr)++) =
    (unsigned char)(thisVal<valfor0?0:(thisVal>=valfor255?255:
				       (255*(thisVal-valfor0)/
					(valfor255-valfor0))));
}

void move_to_double(double* values, int offset, double** tgtPtr) {
  *((*tgtPtr)++) = values[offset];
}

void call_for_each_val(int* ptDims, char* ptData, int offset,
		       valCallback callback_proc, void* cbData) {
  int count;
  sizeAndPtr* convenience;
  switch (ptDims[0]) {
  case OWNSIZED:
    convenience = (sizeAndPtr*)ptData + offset;
    for (count=0; count<convenience->size; ++count) {
      call_for_each_val(ptDims+1, convenience->ptr, count,
			callback_proc, cbData);
    }
    break;
  case SPARSEARRAY: // or any other kind this doesn't handle yet
    //do the necessary
    break;
  default:
    if (ptDims[0]>0)
      for (count=0; count<ptDims[0]; ++count)
	call_for_each_val(ptDims+1, ptData,
			  ptDims[0]*offset+count, callback_proc, cbData);
    else // a base value, callback proc should know what sort
      (*callback_proc)(ptData, offset, cbData);
  }
}

FINDABLE int extractBinCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int error;
  double valfor0, valfor255, valspan, dval;
  nodeValues* accessTool;
  unsigned char* tgt;
  int* progress;
  int baseType, count, size;
  Tcl_Obj *resultPtr, *spareObjPtr;
  void* valAccessed;
  char* nodeId;
  char* myClientData[32];

  double *dDiscList;
  int discCount, *iDiscList;

  if (clientData) {
    // listing distinct vals
    if (argc != 2) {
      Tcl_WrongNumArgs(interp, 1, argv, "data_handle");
      return TCL_ERROR;
    }
  } else {
    if (argc != 4) {
      Tcl_WrongNumArgs(interp, 1, argv, "data_handle lower_limit upper_limit");
      return TCL_ERROR;
    }

    error = Tcl_GetDoubleFromObj(interp, argv[2], &valfor0);
    if (error != TCL_OK) {
      return error;
    }
    
    error = Tcl_GetDoubleFromObj(interp, argv[3], &valfor255);
    if (error != TCL_OK) {
      return error;
    }
  }

  error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&accessTool);
  if (error != TCL_OK) {
    return error;
  }
  
  valspan=valfor255-valfor0; // set to span

  count = 0;
  while (!is_base_type(baseType=accessTool->dimSpecs[count])) 
    ++count; //stop at base data type

  size = 0;
  call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		    add_to_size, (void*)&size);
  // this increments size once for each value

  resultPtr = Tcl_NewObj();
  if (!clientData) {
    if (valspan) {
      Tcl_SetByteArrayLength(resultPtr, size);
    } else { // no span: get values as floats
      Tcl_SetByteArrayLength(resultPtr, size*sizeof(double));
    }
    tgt = Tcl_GetByteArrayFromObj(resultPtr, NULL);
  } else {
    dDiscList = (double*)malloc(sizeof(double)*16);
    iDiscList = (int*)malloc(sizeof(int)*16);
  }

  discCount=0;
  if (clientData) {
    ((addSortedParms*)myClientData)->baseType = baseType; 
    ((addSortedParms*)myClientData)->discCount = &discCount; 
    ((addSortedParms*)myClientData)->dPtrDiscList = &dDiscList;
    call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		      (valCallback*)addSorted, myClientData);
  } else {
    ((convertParms*)myClientData)->tgtPtr = &tgt; 
    // not sure why I must cast a pointer rather than the structure itself
    // must be passed every call so increment it
    if (valspan) {
      ((convertParms*)myClientData)->baseType = baseType; 
      ((convertParms*)myClientData)->valfor0 = &valfor0;
      ((convertParms*)myClientData)->valfor255 = &valfor255;
	call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0, 
			  (valCallback*)convert_to_byte, myClientData);
    } else { // no span: get values as doubles
	call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
			  (valCallback*)move_to_double, &tgt);
    }
  }

  // if doing distinct vals, make tcl array of results and free space
  // (new for 5.3; first val is total member count)
  if (clientData) {
    Tcl_ListObjAppendElement(interp, resultPtr, Tcl_NewIntObj(size));
    for (count=0; count<discCount; ++count) {
      if (baseType==REAL) {
	spareObjPtr = Tcl_NewDoubleObj(dDiscList[count]);
      } else {
	spareObjPtr = Tcl_NewIntObj(iDiscList[count]);
      }
      Tcl_ListObjAppendElement(interp, resultPtr, spareObjPtr);
    }
    free(dDiscList);
    free(iDiscList);
  }
  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}

FINDABLE EXPORT int Unpacker_Init(Tcl_Interp *interp) {
  char pkgName[16];

  sprintf(pkgName, "%d.%d", TCL_MAJOR_VERSION, TCL_MINOR_VERSION);
  /* Use the Tcl Stubs mechanism */
  Tcl_InitStubs(interp, pkgName, 0);
  Tcl_CreateObjCommand(interp, "extract_list", extractListCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_binary", extractBinCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "distinct_values", extractBinCmd, 
		       (ClientData)1, (Tcl_CmdDeleteProc *)NULL);
  
  return Tcl_PkgProvide(interp, "Unpacker", simileVersion);
}
