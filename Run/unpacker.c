// Definitions used in this code and the model code
#include <signal.h> /* for killing stuck model execution */
#include <tcl.h>

#ifdef WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #undef WIN32_LEAN_AND_MEAN

int kill (int pid, int sig) {
  HANDLE procHandle;
  BOOL outcome;
  
  procHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
  outcome = TerminateProcess(procHandle, sig);
  CloseHandle(procHandle);
  return(outcome);
}
#endif

#include <dllcalls.h>

#define USE_MY_HMAC

char simileVersion[] = SIMILE_VERSION;

FINDABLE int GetVersionCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 1) {
    Tcl_WrongNumArgs(interp, 1, argv, "");
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewStringObj(simileVersion, -1));
  return TCL_OK;
}

/* String to use as secret */
char secret[] = "R^6tf*Y}@?>H(U(ddJ(::{><Lu8H*G";
#ifdef SIM_EVALUATION
char edition[]="evaluation";
#endif
#ifdef SIM_TEACHING
char edition[]="teaching";
#endif
#ifdef SIM_STANDARD
char edition[]="standard";
#endif
#ifdef SIM_ENTERPRISE
char edition[]="enterprise";
#endif

void crash (Tcl_Interp *interp, const char *cause) {
 /* oh dear. */
 /* oh dear, oh dear. */
  // fat chance, we have no Tk in the exec interpreter
  Tcl_VarEval(interp, "ShowMessage {Authorization failure} error {Bad ", cause, " authorization. Simile will now exit.} ok", NULL);
  Tcl_Exit(-1);
  strcpy(NULL, secret); // that should screw it up nicely
}	 
#ifdef USE_MY_HMAC
int my_md5(Tcl_Interp *interp, Tcl_Obj* text) {
  Tcl_Obj* argv[3];
  int result;

  /* First we must make up our command for doing MD5. This will involve direct 
     invocation of the Trf library routine with Tcl objects. */
  Tcl_CmdInfo info;
  Tcl_ObjCmdProc* md5ObjProc;
  ClientData md5ObjClientData;

  if (! Tcl_GetCommandInfo(interp, "::md5", &info)) {
    Tcl_AppendResult(interp, "unknown command \"", "::md5", "\"", NULL);
    return TCL_ERROR;
  }
  md5ObjProc = info.objProc;
  md5ObjClientData = info.objClientData;

  argv[0] = Tcl_NewStringObj("::md5", -1);
  Tcl_IncrRefCount(argv[0]);  
  argv[1] = Tcl_NewStringObj("--", -1);
  Tcl_IncrRefCount(argv[1]);  



  argv[2] = text;
  Tcl_IncrRefCount(argv[2]);  

  result = (*md5ObjProc)(md5ObjClientData, interp, 3, argv);

  Tcl_DecrRefCount(argv[2]);  
  Tcl_DecrRefCount(argv[1]);  
  Tcl_DecrRefCount(argv[0]);  

  return result;
}

int my_hash(Tcl_Interp *interp, Tcl_Obj *textObj) {
  Tcl_Obj* md5Target;

  if (my_md5(interp, textObj) == TCL_ERROR) {
    return TCL_ERROR;
  }
  md5Target = Tcl_NewStringObj("::hex -mode encode -- ", -1);
  Tcl_ListObjAppendElement(interp, md5Target, Tcl_GetObjResult(interp));
  if (Tcl_EvalObjEx(interp, md5Target, 0) == TCL_ERROR) {
    return TCL_ERROR;
  }
  return Tcl_VarEval(interp, "string tolower ",
	      Tcl_GetStringResult(interp), NULL);
}
      
int my_hmac(Tcl_Interp *interp, const char* key, const char* text) {
  char* k_ipad;
  char k_opad[96];
  Tcl_Obj* md5Target;

  k_ipad = (char*)malloc(strlen(text)+80);
  int count;
  for (count=strlen(key)-1; count>=0; count--) {
    k_ipad[count]=key[count]^0x36;
    k_opad[count]=key[count]^0x5c;
  }
  for (count=strlen(key); count<64; count++) {
    k_ipad[count]=0x36;
    k_opad[count]=0x5c;
  }

  strcpy(k_ipad+64, text);
  my_md5(interp, Tcl_NewStringObj(k_ipad, strlen(text)+64));
  
  free(k_ipad);

  md5Target = Tcl_NewStringObj(k_opad, 64);
  Tcl_AppendObjToObj(md5Target, Tcl_GetObjResult(interp));
  return my_hash(interp, md5Target);
}
#endif    
/* This gets the authorisation code that is needed for a particular combination
   of original simile edition and Prolog model specification */

FINDABLE int GetAuthCodeCmd(ClientData clientData, Tcl_Interp *interp, 
			      int argc, Tcl_Obj *CONST argv[]) {
   if (argc != 2) {
     Tcl_WrongNumArgs(interp, 1, argv, "source_string");
     return TCL_ERROR;
   }
   /* set ModelText [mime::getbody $Part($Model)]
   if (Tcl_VarEval(interp, "set hvfe587gw938 ", 
		   Tcl_GetStringFromObj(argv[1], NULL), NULL) != TCL_OK) {
     return TCL_ERROR;
   }
   regexp {edition=([^,]*),} $ModelText all putativeEdition */
   Tcl_SetVar2Ex(interp, "hvfe587gw938", NULL, argv[1], 0);
   if (Tcl_VarEval(interp, 
		   "regexp {edition=([^,]*),} $hvfe587gw938 all h76rt4g7",
		   NULL) != TCL_OK) {
     return TCL_ERROR;
   }
   if (strcmp(edition, Tcl_GetVar(interp, "h76rt4g7", 0))) {
     crash(interp, "edition");
   }
#ifdef USE_MY_HMAC
   return my_hmac(interp, secret, Tcl_GetVar(interp, "hvfe587gw938", 0));
#else
   /*    ::sha1::hmac "Expensive" $ModelText */
   return Tcl_VarEval(interp, "::md5::hmac ", secret, " $hvfe587gw938", NULL);
#endif
}   

/* This bit exists solely to make our lives difficult, especially if we are
thinking of ripping off Simulistics, Inc. A special security code is generated
from our little secret -- after checking that the edition specified is right */

FINDABLE int CheckAuthCodeCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "source_string code");
    return TCL_ERROR;
  }
  /* set ModelText [mime::getbody $Part($Model)]
  if (Tcl_VarEval(interp, "set hvfe587gw938 [mime::getbody ", 
		  Tcl_GetStringFromObj(argv[1], NULL), "]", NULL) != TCL_OK) {
    return TCL_ERROR;
    } */
#ifdef USE_MY_HMAC
  if (my_hmac(interp, secret, Tcl_GetStringFromObj(argv[1], NULL)) != TCL_OK) {
    return TCL_ERROR;
  }
#else
  Tcl_SetVar2Ex(interp, "hvfe587gw938", NULL, argv[1], 0);
  if (Tcl_VarEval(interp, "::md5::hmac ", secret, " $hvfe587gw938", NULL) != TCL_OK) {
    return TCL_ERROR;
  }
#endif

  /* check it matches what we got before */
  if (strcmp(Tcl_GetStringFromObj(argv[2],NULL), Tcl_GetStringResult(interp))) {
    crash(interp, "model");
  }
  
  /* Also if we are evaluation, it was not written by enterprise and it has 
     more than 30 lines beginning 'node...' there are grounds to suspect foul
     play...actually it might not be their fault so don't do this...
  if (strcmp("evaluation", edition)) {
    return TCL_OK;
  }
  if (strcmp("enterprise", Tcl_GetVar(interp, "h76rt4g7", 0))) {
    return TCL_OK;
  }
  if (Tcl_VarEval(interp, "regexp -all {node\(node} $hvfe587gw938",
		  NULL) != TCL_OK) {
    return TCL_ERROR;
  }
  Tcl_GetIntFromObj(interp, Tcl_GetObjResult(interp), &trouble);
  if (trouble > 30) {
    crash();
    } */
  return TCL_OK;
}

int licenseRight (Tcl_Interp *interp) {
  /* If this version requires a license then check we have the right
     one...

     if (Tcl_VarEval(interp, "::md5::hmac ", secret, 
      " $userinfo(name)@$userinfo(corp)%$userinfo(edn)", NULL) != TCL_OK) {

      Above used hmac but now we just append the secret and hash because
      it needs to be generated by PHP 
      ...so for a while it looked like this: */
#ifdef SIM_LICENSED
#ifdef USE_MY_HMAC
  Tcl_Obj* dataCombo;
  const char* offered;

  dataCombo = Tcl_GetVar2Ex(interp, "env", "licensee_name", TCL_LEAVE_ERR_MSG);
  if (dataCombo) {
    dataCombo = Tcl_DuplicateObj(dataCombo);
  } else {
    return -1;
  }
  Tcl_AppendStringsToObj(dataCombo, "%", edition, "^", secret, NULL);
  if (my_hash(interp, dataCombo) == TCL_ERROR) {
    return -1;
  }
#else
  char md5cmd[] = "::md5::md5 $env(licensee_name)%$env(user,edn)^";
  if (Tcl_VarEval(interp, md5cmd, secret, NULL) != TCL_OK) {
    /* raise another error so user doesnt see secret in trace */
    Tcl_VarEval(interp, md5cmd, "<secret>", NULL);
    return -1;
  }
#endif

  /* check it matches what we got before */
  offered = Tcl_GetVar2(interp, "env", "license_code", 0);
  if (!offered || strncmp(offered, Tcl_GetStringResult(interp), 10)) {
    //    Tcl_AppendResult(interp, " not ", offered, " is license code", NULL);
    //    return -1;
    return 0;
  }
#endif
  return 1;
}

FINDABLE int testlicenseCmd(ClientData clientData, Tcl_Interp *interp, 
			    int argc, Tcl_Obj *CONST argv[]) {
  int answer;
  answer = licenseRight(interp);
  if (answer == -1) {
    return TCL_ERROR;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewIntObj(answer));
    return TCL_OK;
  }
}

// stuff to do with unpacking the general C format for model values follows:

BOOLEAN unp_base_type(int dim) {
  return dim==VALUELESS||dim==REAL||dim==INTEGER||dim==FLAG||dim<=ENUM_BASE;
}

void extend_list(Tcl_Obj *localObj, int index, Tcl_Obj *localSubObj, int dir) {
  int arrayOut;
  Tcl_Obj *indObj;

  Tcl_ListObjLength(NULL, localSubObj, &arrayOut);
  if (arrayOut) {
    indObj = Tcl_NewIntObj(index);
      if (dir>=0) {
	Tcl_ListObjAppendElement(NULL, localObj, indObj);
	Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
      } else { // stick them in at the beginning
	Tcl_ListObjReplace(NULL, localObj, 0,0,1, &indObj);
	Tcl_ListObjReplace(NULL, localObj, 1,0,1, &localSubObj);
      }
  }
}

/* next two call convert_to_tcl, which calls them, so declare in advance */
Tcl_Obj* convert_to_tcl(int*, int*, char*, int*);

Tcl_Obj* append_list_members(int dimty, int depth, int* dims, int* indices, 
			     int* subBlocks, int *members, char** block,
			     int* toGet) {
  Tcl_Obj *localObj, *localSubObj;
  int count, dir;

  dir = *toGet>0?1:-1;
  if (depth==dimty) {
    if (*members) {
      *block += dimty*sizeof(int);
      localObj = convert_to_tcl(dims, subBlocks, *block, toGet);
      if (dir>0) {
	*block += subBlocks[0];
      } else {
	*block -= (subBlocks[0]+2*dimty*sizeof(int));
      }
      --*members;
    } else {
      localObj = Tcl_NewListObj(0, NULL);
    }
  } else {
    localObj = Tcl_NewListObj(0, NULL);
    while (*members && *toGet) {
      for (count=0; count<depth; ++count) {
	if (((int*)*block)[count]!=indices[count]) return(localObj);
      }
      indices[depth] = ((int*)*block)[depth];
      localSubObj = append_list_members(dimty, depth+1, dims, indices,
					subBlocks, members, block, toGet);

      extend_list(localObj, indices[depth], localSubObj, dir);
    }
  }
  return(localObj);
}

Tcl_Obj* append_array_members(int membership, int* dims, int* subBlocks, 
			      char* block, int* count) {
  Tcl_Obj *localObj, *localSubObj;
  int offset, start, end, dir;
  
  localObj = Tcl_NewListObj(0, NULL);
  dir = *count>0?1:-1;
  if (dir==1) {
    start = 0; end = membership;
  } else {
    start = membership-1; end = -1;
  }
  for (offset = start; offset != end; offset += dir) {
    if (!*count) break;
    localSubObj = convert_to_tcl(dims, subBlocks, block+offset*subBlocks[0],
				 count);
    extend_list(localObj, offset+1, localSubObj, dir);
  }
  return localObj;
}
  
Tcl_Obj* convert_to_tcl(int* dims, int* subBlocks, char* block, int* count) {
  Tcl_Obj *localObj;
  int membership, *indices;
  char *newBlock;

  if (dims[0] > 0) { // it's an array bound
    localObj = append_array_members(dims[0], dims+1, subBlocks+1, block, count);
  } else {
    switch (dims[0]) {
    case OWNSIZED:
      membership = ((sizeAndPtr*)block)->size;
      newBlock = ((sizeAndPtr*)block)->ptr;
      localObj = append_array_members(membership, dims+1, subBlocks+1, 
				      newBlock, count);
      break;
    case SPARSEARRAY: 
      // need clevers to nest indices; see old stuff
      membership = ((sizeAndPtr*)block)->size;
      newBlock = ((sizeAndPtr*)block)->ptr;
      block = newBlock;
      indices = (int*)malloc(sizeof(int)*dims[1]);
      if (*count<0) { // start at last index group and work back
	block = block+(membership-1)*(dims[1]*sizeof(int)+subBlocks[1]);
      }
      localObj = append_list_members(dims[1], 0, dims+2, indices, subBlocks+1,
				     &membership, &block, count);
      free(indices);
      break;
    case VALUELESS:
      localObj = Tcl_NewStringObj("sm", -1);
      *count -= *count>0?1:-1;
      break;
    case REAL:
      localObj = Tcl_NewDoubleObj(*(double *)block);
      *count -= *count>0?1:-1;
      break;
    case FLAG:
      localObj = Tcl_NewBooleanObj(*(int *)block);
      *count -= *count>0?1:-1;
      break;
    default: /* INTEGER or ENUM(*) */
      localObj = Tcl_NewIntObj(*(int *)block);
      *count -= *count>0?1:-1;
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
  int iPosn, error, count;

  char spare[256];
  int dims[32], path[32];
  long int mSpare;
  enum_type_data* usedTypes[32];
  nodeValues* c_result;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "data_handle value_count");
    return TCL_ERROR;
  }

  error = Tcl_GetLongFromObj(interp, argv[1], (long int*)&c_result);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetIntFromObj(interp, argv[2], &count);
  if (error != TCL_OK) {
    return error;
  }
  
  int subBlocks[32];
  make_sub_block_sizes(c_result->dimSpecs, subBlocks);
  resultPtr = convert_to_tcl(c_result->dimSpecs, subBlocks, c_result->contents,
			     &count);
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
  int count, locount, hicount, exp, bigexp, *discCount;

  if (cbData->baseType == REAL) 
    newVal = ((double*)values)[offset];
  else 
    newVal = ((int*)values)[offset];
  discCount = cbData->discCount;
  dPtrDiscList = cbData->dPtrDiscList;

  spareArr = *dPtrDiscList;
  // straight search could be replaced by binary if more speed needed
  // for (count=0; count<*discCount; ++count) {
  //   if (newVal==spareArr[count]) {
  //     return;
  //   } else if (newVal<spareArr[count]) {
  //     break;
  //   }
  // }
  // ok, sew a button on this...
  locount=0;
  hicount=*discCount;
  count=hicount/2;
  while (count!=hicount) {
    if (newVal==spareArr[count])
      return;
    if (newVal>spareArr[count])
      locount = count+1;
    else
      hicount = count;
    count = (locount+hicount)/2;
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

  convenience = (sizeAndPtr*)ptData + offset;
  switch (ptDims[0]) {
  case OWNSIZED:
    for (count=0; count<convenience->size; ++count) {
      call_for_each_val(ptDims+1, convenience->ptr, count,
			callback_proc, cbData);
    }
    break;
  case SPARSEARRAY:
    // done by looking at free_bloc_level, which looked here
    for (count=0; count<convenience->size; ++count) {
      call_for_each_val(ptDims+2, 
			convenience->ptr + sizeof(int)*ptDims[1]*(1+count), 
			// corrects for space taken up by indices
			count, callback_proc, cbData);
    }
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
  int discCount;

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
  while (!unp_base_type(baseType=accessTool->dimSpecs[count])) 
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
      spareObjPtr = Tcl_NewDoubleObj(dDiscList[count]);
      Tcl_ListObjAppendElement(interp, resultPtr, spareObjPtr);
    }
    free(dDiscList);
  }
  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}

FINDABLE int getValueCountCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int size, error;
  nodeValues* accessTool;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "data_handle");
    return TCL_ERROR;
  }
  error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&accessTool);
  if (error != TCL_OK) {
    return error;
  }
  
  size = 0;
  call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		    add_to_size, (void*)&size);
  // this increments size once for each value

  Tcl_SetObjResult(interp, Tcl_NewIntObj(size));
  return TCL_OK;
}

FINDABLE int killmodelCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  int error, pid;
  Tcl_Obj* resultPtr;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "pid");
    return TCL_ERROR;
  }
  error = Tcl_GetIntFromObj(interp, argv[1], &pid);
  if (error != TCL_OK) {
    return error;
  }
  resultPtr = Tcl_GetObjResult(interp);
  Tcl_SetIntObj(resultPtr, kill(pid, SIGTERM));
  return TCL_OK;
}

FINDABLE int loadcmdsCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 1) {
    Tcl_WrongNumArgs(interp, 1, argv, "");
    return TCL_ERROR;
  }

  /* Data about version etc held in dll for safety and convenience:
     these will become globals because we are not in the scope of a
     procedure */
  Tcl_SetVar2Ex(interp, "env", "user,final_expiry", 
		Tcl_NewLongObj(SIM_FINAL_EXPIRY), 0);
  Tcl_SetVar2Ex(interp, "env", "user,days_after_install", 
		Tcl_NewIntObj(SIM_DAYS_AFTER_INSTALL), 0);
  switch (licenseRight(interp)) {
  case -1:
    return TCL_ERROR;
  case 0:
    crash(interp, "program");
  }

  Tcl_CreateObjCommand(interp, "get_simile_verson", GetVersionCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "get_auth_code", GetAuthCodeCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "check_auth_code", CheckAuthCodeCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_list", extractListCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_binary", extractBinCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "distinct_values", extractBinCmd, 
		       (ClientData)1, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "count_values", getValueCountCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_killmodel", killmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
return TCL_OK;
}
 
FINDABLE EXPORT int Unpacker_Init(Tcl_Interp *interp) {
  char pkgName[16];

  sprintf(pkgName, "%d.%d", TCL_MAJOR_VERSION, TCL_MINOR_VERSION);
  /* Use the Tcl Stubs mechanism */
  Tcl_InitStubs(interp, pkgName, 0);
  Tcl_SetVar2Ex(interp, "env", "user,edn", Tcl_NewStringObj(edition, -1), 0);
  Tcl_CreateObjCommand(interp, "c_testlicense", testlicenseCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

  Tcl_CreateObjCommand(interp, "loadcommands", loadcmdsCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  return Tcl_PkgProvide(interp, "Unpacker", pkgName);
}
