// Definitions used in this code and the model code
#include <signal.h> /* for killing stuck model execution */
#include <stdint.h> // for uintptr_t etc
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

/* Strings to use as secret */
char secret[] = "OTFK&i|X36iGf)n~`^p19UG`/r&0S1G",
  secret5[] = "R^6tf*Y}@?>H(U(ddJ(::{><Lu8H*G";

void crash (Tcl_Interp *interp, const char *cause) {
 /* oh dear. */
 /* oh dear, oh dear. */
  // fat chance, we have no Tk in the exec interpreter
  Tcl_VarEval(interp, "ShowMessage {Authorization failure} error {Bad ", cause, " authorization. Simile will now exit.} ok", NULL);
  Tcl_Exit(-1);
  strcpy((char*)4, "deadbeef"); // that should screw it up nicely
}	 

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

char editions[][12] = {"evaluation", "teaching", "standard", "enterprise"};
int edn_id = 0;

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
		   "regexp {,edition=([^,]*),} $hvfe587gw938 all h76rt4g7",
		   NULL) != TCL_OK) {
     return TCL_ERROR;
   }
   if (strcmp(editions[edn_id], Tcl_GetVar(interp, "h76rt4g7", 0))) {
     crash(interp, "edition");
   }
   return my_hmac(interp, secret5, Tcl_GetVar(interp, "hvfe587gw938", 0));
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
  if (my_hmac(interp, secret5, Tcl_GetStringFromObj(argv[1], NULL)) != TCL_OK) {
    return TCL_ERROR;
  }

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

char* licenseRight (Tcl_Interp *interp) {
  /* If this version requires a license then check we have the right
     one...

     if (Tcl_VarEval(interp, "::md5::hmac ", secret, 
      " $userinfo(name)@$userinfo(corp)%$userinfo(edn)", NULL) != TCL_OK) {

      Above used hmac but now we just append the secret and hash because
      it needs to be generated by PHP 
      ...so for a while it looked like this: */

  const char *expected, *offered = Tcl_GetVar2(interp, "userinfo", "license_code", 0);
  if (!strncmp(offered, "     -     ", 11))
    return "evaluation";

  for (edn_id=1; edn_id<4; ++edn_id) {
    Tcl_Obj* dataCombo;

    dataCombo = Tcl_GetVar2Ex(interp, "userinfo", "name", TCL_LEAVE_ERR_MSG);
    if (dataCombo) {
      dataCombo = Tcl_DuplicateObj(dataCombo);
    } else {
      return NULL;
    }
    Tcl_AppendStringsToObj(dataCombo, "%", editions[edn_id], "^", secret, NULL);
    if (my_hash(interp, dataCombo) == TCL_ERROR) {
      return NULL;
    }

    /* check it matches what we got before */
    expected = Tcl_GetStringResult(interp);
    if (!strncmp(offered, expected, 5) && !strncmp(offered+6, expected+5, 5)) {
      //  Tcl_AppendResult(interp, " not ", offered, " is license code", NULL);
      //  return "evaluation";
      return editions[edn_id];
    }
  }
  Tcl_SetObjResult(interp, Tcl_NewStringObj("License code not recognized", -1));
  return NULL;
}

FINDABLE int testlicenseCmd(ClientData clientData, Tcl_Interp *interp, 
			    int argc, Tcl_Obj *CONST argv[]) {
  char* answer;
  answer = licenseRight(interp);
  if (answer) {
    Tcl_SetVar2Ex(interp, "env", "user,edn", Tcl_NewStringObj(answer, -1), 0);
    return TCL_OK;
  } else {
    return TCL_ERROR;
  }
}

// stuff to do with unpacking the general C format for model values follows:

BOOLEAN unp_base_type(int dim) {
  return dim==VALUELESS||dim==REAL||dim==INTEGER||dim==FLAG||
    dim==RECT_NBR||dim==HEX_NBR||dim<=ENUM_BASE;
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

Tcl_Obj* extend_string(Tcl_Obj *localObj, int index, Tcl_Obj *localSubObj, int dir) {
  Tcl_Obj* localNewObj = Tcl_NewStringObj("\"",1);
  Tcl_AppendObjToObj(localNewObj, Tcl_NewIntObj(index));
  Tcl_AppendToObj(localNewObj, "\":", 2);
  Tcl_AppendObjToObj(localNewObj, localSubObj);
  if (!Tcl_GetCharLength(localObj))
    return localNewObj;
  else if (dir>=0) {
     Tcl_AppendToObj(localObj, ",", 1);
     Tcl_AppendObjToObj(localObj, localNewObj);
     return localObj;
  } else {
     Tcl_AppendToObj(localNewObj, ",", 1);
     Tcl_AppendObjToObj(localNewObj, localObj);
     return localNewObj;
  }
}

/* next two call convert_to_tcl, which calls them, so declare in advance */
Tcl_Obj* convert_to_tcl(int*, int*, char*, BOOLEAN, int*, BOOLEAN);

Tcl_Obj* append_list_members(int dimty, int depth, int* dims, int* indices, 
			     int* subBlocks, int *members, char** block,
			     BOOLEAN loseZeros, int* toGet, BOOLEAN jsonic) {
  Tcl_Obj *localObj, *localSubObj;
  int count, dir;

  dir = *toGet>0?1:-1;
  if (depth==dimty) {
    if (*members) {
      *block += dimty*sizeof(int);
      localObj = convert_to_tcl(dims, subBlocks, *block,
				loseZeros, toGet, jsonic);
      if (dir>0) {
	*block += subBlocks[0];
      } else {
	*block -= (subBlocks[0]+2*dimty*sizeof(int));
      }
      --*members;
    } else {
      if (jsonic) {
	localObj = Tcl_NewStringObj("{}", 2);
      } else {
	localObj = Tcl_NewListObj(0, NULL);
      }
    }
  } else {
    localObj = Tcl_NewListObj(0, NULL);
    while (*members && *toGet) {
      for (count=0; count<depth; ++count) {
	if (((int*)*block)[count]!=indices[count]) goto nomorematching;
      }
      indices[depth] = ((int*)*block)[depth];
      localSubObj = append_list_members(dimty, depth+1, dims, indices,
					subBlocks, members, block, loseZeros,
					toGet, jsonic);

      if (jsonic) {
	if (Tcl_GetCharLength(localSubObj))
	  localObj = extend_string(localObj, indices[depth], localSubObj, dir);
      } else
	extend_list(localObj, indices[depth], localSubObj, dir);
    }
  nomorematching:
    if (jsonic) {
      localSubObj = Tcl_NewStringObj("{", 1);
      Tcl_AppendObjToObj(localSubObj, localObj);
      Tcl_AppendToObj(localSubObj, "}", 1);
      return localSubObj;
    }
  }
  return(localObj);
}

Tcl_Obj* append_array_members(int membership, int* dims, int* subBlocks, 
			      char* block, BOOLEAN loseZeros, int* count, BOOLEAN jsonic) {
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
				 loseZeros, count, jsonic);
    if (jsonic) {
      if (Tcl_GetCharLength(localSubObj))
	localObj = extend_string(localObj, offset+1, localSubObj, dir);
    } else
      extend_list(localObj, offset+1, localSubObj, dir);
  }
  if (jsonic) {
    localSubObj = Tcl_NewStringObj("{", 1);
    Tcl_AppendObjToObj(localSubObj, localObj);
    Tcl_AppendToObj(localSubObj, "}", 1);
    return localSubObj;
  }
  return localObj;
}
  
Tcl_Obj* convert_to_tcl(int* dims, int* subBlocks, char* block,
			BOOLEAN loseZeros, int* count, BOOLEAN jsonic) {
  Tcl_Obj *localObj;
  int membership, *indices;
  char *newBlock;

  if (dims[0] > 0) { // it's an array bound
    localObj = append_array_members(dims[0], dims+1, subBlocks+1, block, 
				    loseZeros, count, jsonic);
  } else {
    switch (dims[0]) {
    case OWNSIZED:
      membership = ((sizeAndPtr*)block)->size;
      newBlock = ((sizeAndPtr*)block)->ptr;
      localObj = append_array_members(membership, dims+1, subBlocks+1, 
				      newBlock, loseZeros, count, jsonic);
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
				     &membership, &block, loseZeros, count, jsonic);
      free(indices);
      break;
    case VALUELESS:
      if (jsonic)
	localObj = Tcl_NewStringObj("\"sm\"", -1);
      else
	localObj = Tcl_NewStringObj("sm", -1);
      *count -= *count>0?1:-1;
      break;
    case REAL:
      if (loseZeros && *(double *)block == 0.0) {
	localObj = Tcl_NewListObj(0, NULL);
	break;
      }
      if (isfinite(*(double *)block) || !jsonic) // inf/nan no longer enquoted
	// in app, allowing inf to be formatted and NaN detected
	localObj = Tcl_NewDoubleObj(*(double *)block);
      else {
	localObj = Tcl_NewStringObj("\"", -1);
	Tcl_AppendObjToObj(localObj, Tcl_NewDoubleObj(*(double *)block));
	Tcl_AppendObjToObj(localObj, Tcl_NewStringObj("\"", -1));
      }
      *count -= *count>0?1:-1;
      break;
    default: /* FLAG, INTEGER or ENUM(*) */
      if (loseZeros && *(int *)block == 0) {
	localObj = Tcl_NewListObj(0, NULL);
	break;
      }
      if (dims[0] == FLAG)
	localObj = Tcl_NewBooleanObj(*(int *)block);
      else
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
    usedDims = 2; // and fall through
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
  enum_type_data* usedTypes[32];
  nodeValues* c_result;
  BOOLEAN loseZeros;

  if (argc < 3 || argc > 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "data_handle value_count ?lose_zeros?");
    return TCL_ERROR;
  }

  memcpy(&c_result, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
  error = Tcl_GetIntFromObj(interp, argv[2], &count);
  if (error != TCL_OK) {
    return error;
  }

  if (argc == 4) {
    error = Tcl_GetBooleanFromObj(interp, argv[3], &loseZeros);
    if (error != TCL_OK) {
      return error;
    }
  } else
    loseZeros = 0;
    
  int subBlocks[32];
  make_sub_block_sizes(c_result->dimSpecs, subBlocks);
  resultPtr = convert_to_tcl(c_result->dimSpecs, subBlocks, c_result->contents,
			     loseZeros, &count, clientData != NULL);
  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}

/* New version using nodeValues structure -- first its callback procs */

void add_to_size(void* spareValue, int spareOffset, void* sizePtr) {
  // sizePtr is actually an integer pointer
  ++(*(int*)sizePtr);
}

void add_nonzero_floats_to_size(void* Value, int Offset, void* sizePtr) {
  // sizePtr is actually an integer pointer
  if (((double*)Value)[Offset] != 0.0)
    ++(*(int*)sizePtr);
}

void add_nonzero_ints_to_size(void* Value, int Offset, void* sizePtr) {
  // sizePtr is actually an integer pointer
  if (((int*)Value)[Offset])
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
    (unsigned char)(thisVal<valfor0?1:(thisVal>=valfor255?255:
				       (1+255*(thisVal-valfor0)/
					(valfor255-valfor0))));
}

typedef struct hash_entry_t {
  uint16_t origin;
  uint16_t code;
  unsigned char ident;
} hash_entry;

typedef struct lzw_parm_t {
  convertParms cbData;
  Tcl_Obj* result;
  hash_entry htable[5000];
  uint16_t code, next_code;
  int tail, tbits, codeSize, tooBig, inBloc;
  char dump[257];
} lzwParms;

hash_entry* hash_lookup(lzwParms* encodeState, unsigned char id) {
  hash_entry* locn;
  locn = encodeState->htable + (847*encodeState->code+17*id)%5000;
  while (locn->origin != 257 && (locn->origin != encodeState->code || 
				 locn->ident != id))
    if (locn == encodeState->htable + (5000 - 1)) 
      locn = encodeState->htable;
    else
      locn += 1;
  if (locn->origin == 257) {
    locn->origin = encodeState->code;
    locn->ident = id;
  }
  return locn;
}

void write_bits(lzwParms* encodeState, uint16_t add) {
  int curLen;
  unsigned char *curTgt;

  encodeState->tail += add << encodeState->tbits;
  // printf("%d\n", tail);
  encodeState->tbits += encodeState->codeSize;
  while (encodeState->tbits >= 8) {
    encodeState->dump[++encodeState->inBloc] = encodeState->tail & 255;
    encodeState->tail = encodeState->tail >> 8;
    encodeState->tbits -= 8;
  }
  if (add == 257 && encodeState->tbits) // end of output, bits left, sqeeze out
    encodeState->dump[++encodeState->inBloc] = encodeState->tail & 255;
  if (add == 257 || encodeState->inBloc > 250) {
    // easiest way to stuff things on Tcl result is start filling bloc at 1
    // then stick count in 0 and null-terminate?
    encodeState->dump[0] = encodeState->inBloc;
    encodeState->dump[++encodeState->inBloc] = 0;
    // Tcl_AppendResult(encodeState->interp, "hello", NULL); // what?
    Tcl_GetByteArrayFromObj(encodeState->result, &curLen);
    curTgt = Tcl_SetByteArrayLength(encodeState->result, 
				    curLen+encodeState->inBloc);
    memcpy(curTgt + curLen, encodeState->dump, encodeState->inBloc);
    encodeState->inBloc = 0;
  }
}

void empty_table(lzwParms* encodeState) {
  int i;
  for (i=0; i<5000; i++) {
    encodeState->htable[i].code = 0;
    encodeState->htable[i].origin = 257;
  }
  // empty code table -- all ident values used so 257 origin means empty
  encodeState->codeSize = 9;
  encodeState->tooBig = 512;
}

void growLZW(void* values, int offset, lzwParms* encodeState) {
  unsigned char c, *cptr;
  uint16_t nc;

  convertParms* nested;
  cptr = &c;
  nested =  &(encodeState->cbData);
  nested->tgtPtr = &cptr;
  convert_to_byte(values, offset, nested); // puts byte in c

  hash_entry *hline;
  hline = hash_lookup(encodeState, c); // hash table and current code in state
  if ((nc = hline->code)) // assignment
    encodeState->code = nc;
  else {
    write_bits(encodeState, encodeState->code);
    hline->code = encodeState->next_code;
    if (encodeState->next_code++ == encodeState->tooBig) {
      if (encodeState->codeSize == 12) {
	write_bits(encodeState, 256);
	empty_table(encodeState);
	encodeState->next_code = 258;
      } else {
	encodeState->tooBig *= 2;
	++encodeState->codeSize;
	if (encodeState->codeSize == 12)
	  --encodeState->tooBig;
      }
    }
    encodeState->code = c;
  }
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
  lzwParms *encState;
    
  if (clientData) {
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
  } else {
    // listing distinct vals
    if (argc != 2) {
      Tcl_WrongNumArgs(interp, 1, argv, "data_handle");
      return TCL_ERROR;
    }
  }

  memcpy(&accessTool, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
  valspan=valfor255-valfor0; // set to span

  count = 0;
  while (!unp_base_type(baseType=accessTool->dimSpecs[count])) 
    ++count; //stop at base data type

  size = 0;
  call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		    add_to_size, (void*)&size);
  // this increments size once for each value

  resultPtr = Tcl_NewObj();
  switch ((uintptr_t)clientData) {
  case 1:
    if (valspan) {
      Tcl_SetByteArrayLength(resultPtr, size);
    } else { // no span: get values as floats
      Tcl_SetByteArrayLength(resultPtr, size*sizeof(double));
    }
    tgt = Tcl_GetByteArrayFromObj(resultPtr, NULL);
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
    break;

  case 0:
    dDiscList = (double*)malloc(sizeof(double)*16);
    discCount=0;
    ((addSortedParms*)myClientData)->baseType = baseType; 
    ((addSortedParms*)myClientData)->discCount = &discCount; 
    ((addSortedParms*)myClientData)->dPtrDiscList = &dDiscList;
    call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		      (valCallback*)addSorted, myClientData);
  // if doing distinct vals, make tcl array of results and free space
  // (new for 5.3; first val is total member count)
    Tcl_ListObjAppendElement(interp, resultPtr, Tcl_NewIntObj(size));
    for (count=0; count<discCount; ++count) {
      spareObjPtr = Tcl_NewDoubleObj(dDiscList[count]);
      Tcl_ListObjAppendElement(interp, resultPtr, spareObjPtr);
    }
    free(dDiscList);
    break;

  case 2:
    encState = (lzwParms*)malloc(sizeof(lzwParms));
    encState->cbData.baseType = baseType; 
    encState->cbData.valfor0 = &valfor0;
    encState->cbData.valfor255 = &valfor255;
    encState->result = resultPtr;

    empty_table(encState);
    encState->code = 256; // next char will be 1st, this starts output
    encState->next_code = 257; // resulting code never used
    encState->tail = encState->tbits = encState->inBloc = 0;
    call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		      (valCallback*)growLZW, encState);
    write_bits(encState, encState->code);
    write_bits(encState, 257);
    free(encState);
    break;
  }

  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}

FINDABLE int getValueCountCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int size, error, baseType, loseZeros;
  nodeValues* accessTool;
  valCallback* callback_proc;

  if (argc < 2 || argc > 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "data_handle ?lose_zeros?");
    return TCL_ERROR;
  }
  memcpy(&accessTool, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));

  if (argc == 3) {
    error = Tcl_GetIntFromObj(interp, argv[2], &loseZeros);
    if (error != TCL_OK) {
      return error;
    }
  } else
    loseZeros = 0;

  if (loseZeros) {
    size = 0;
    while (!unp_base_type(baseType=accessTool->dimSpecs[size])) 
      ++size; //stop at base data type
    if (baseType == REAL)
      callback_proc = add_nonzero_floats_to_size;
    else
      callback_proc = add_nonzero_ints_to_size;
  } else
    callback_proc = add_to_size;
  
  size = 0;
  call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		    callback_proc, (void*)&size);
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
  Tcl_SetVar2Ex(interp, "env", "user,built", Tcl_NewLongObj(SIM_BUILT), 0);
  const char* denewded = licenseRight(interp);
  if (!denewded)
    return TCL_ERROR;
  if (strncmp(denewded, Tcl_GetVar2(interp, "env", "user,edn", 0), 8))
    crash(interp, "program");

  Tcl_CreateObjCommand(interp, "get_simile_verson", GetVersionCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "get_auth_code", GetAuthCodeCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "check_auth_code", CheckAuthCodeCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_list", extractListCmd, (ClientData)0,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_json", extractListCmd, (ClientData)1,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "distinct_values", extractBinCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_binary", extractBinCmd, 
		       (ClientData)1, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_gif_tail", extractBinCmd, 
		       (ClientData)2, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "count_values", getValueCountCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_killmodel", killmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
return TCL_OK;
}
 
FINDABLE EXPORT int Unpacker_Init(Tcl_Interp *interp) {
  // char pkgName[16];

  // sprintf(pkgName, "%d.d", TCL_MAJOR_VERSION, TCL_MINOR_VERSION);
  // Use the Tcl Stubs mechanism --version is earliest we expect to work
  if (!Tcl_InitStubs(interp, "8.5", 0)) return TCL_ERROR;
  Tcl_CreateObjCommand(interp, "c_testlicense", testlicenseCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

  Tcl_CreateObjCommand(interp, "loadcommands", loadcmdsCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  return Tcl_PkgProvide(interp, "Unpacker", simileVersion);
}
