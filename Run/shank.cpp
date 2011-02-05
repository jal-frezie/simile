#ifdef WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #undef WIN32_LEAN_AND_MEAN

    #define LOAD_DLL LoadLibrary
    #define UNLOAD_DLL FreeLibrary
    #define WHAT_WENT_WRONG GetErrorText
    #define FIND_FUNCTION GetProcAddress
/*
BOOL APIENTRY
DllEntryPoint(
    HINSTANCE hInst,		// Library instance handle.
    DWORD reason,		// Reason this function is being called.
    LPVOID reserved)		// Not used.
{
    return TRUE;
}
*/
char* GetErrorText() {
LPVOID lpMsgBuf;
FormatMessage( 
    FORMAT_MESSAGE_ALLOCATE_BUFFER | 
    FORMAT_MESSAGE_FROM_SYSTEM | 
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    GetLastError(),
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
    (LPTSTR) &lpMsgBuf,
    0,
    NULL 
);
return (char*)lpMsgBuf;
}

#else

    #include <signal.h>
    #include <setjmp.h>
    #include <dlfcn.h>

    #define LOAD_DLL flopen
/* 'dummyunload' clause was used with macos because dlcompat didn't include
 * unload, but using -bundle instead of -dynamiclib to build the model seems to
 * make dlcompat, and dummyunload, unnecessary. Indeed it allows model
 * crosstalk on Intel macs, so is now never used.

#ifdef SIM_OPSYS_Darwin
#define UNLOAD_DLL dummyunload
int dummyunload(HINSTANCE unused) {
  return(1);
}
#else */
    #define UNLOAD_DLL !dlclose
// dlclose inverted cos it seems to return NULL when it works */
// #endif
    #define WHAT_WENT_WRONG (char*)dlerror
    #define FIND_FUNCTION dlsym
/* sig handler cos 64bit gcc code sigfpe's on 32bit machine */
jmp_buf env;

static void exit_sighandler(int x){
  longjmp(env, x);
}

void* flopen(char* fileName) {
  int error;

  signal(SIGFPE,exit_sighandler);
  error = setjmp(env);
  if (error) {
    return 0;
  } else {
    return dlopen(fileName, RTLD_NOW | RTLD_LOCAL);
  }
}
#define NEED_MINMAX
#endif

/*
 * Unix or Win64 version: does not have min & max defined
 */

#ifdef _WIN64
    #define NEED_MINMAX
#endif
#ifdef NEED_MINMAX
int min(int a, int b) {
  return a<b?a:b;
}
int max(int a, int b) {
  return a>b?a:b;
}
#endif

// Definitions used in this code and the model code
#include <dllcalls.h>
// for talking to compiled models
#include <backend.h>
// class interface for c++ clients
#include <6d.h>

stat_check_type stat_check;
model_requests_file_param_type handle_model_param_request;

char globMess[256];

// check for abort (and do non-intrusive gui action). Do not do this if the
// time point borders are happening frequently.

int stat_check(void* id) {
  if (clock()-((ExecutingModel*)id)->last_check>2*FLASH)
    return ((ExecutingModel*)id)->do_gui_check(0, 0);
  else
    return FALSE;
}

show_model_mess_type showModelMess;
void showModelMess(void* id, const char* content) {
  ((ExecutingModel*)id)->modelSpec->showMess(content);
}

/* utility procedures making no direct reference to model classes/instances */

graph_data_type* find_graph_by_index(int index, graph_data_type* use_gptr) {
  while (use_gptr && use_gptr->index != index) {
    use_gptr = use_gptr->next;
  }
  return(use_gptr);
}

double graphpoint(double xval, graph_data_type* graphdata, int index) {
	double interval, intersection;
	int spaces, lower;
	int *right, *left;
	graph_data_type *use_graph_pointer;
	
	use_graph_pointer = find_graph_by_index(index, graphdata);

	spaces = use_graph_pointer->xsize-1;
	/* Interval is distance from left of graph in point units */
	interval = spaces*(xval - use_graph_pointer->xlow)/
		(use_graph_pointer->xhigh - use_graph_pointer->xlow);
	switch (use_graph_pointer->range) {
	case 0: case 4: case 5: /* truncate to fit on graph */
	  interval = interval<0?0:(interval>spaces?spaces:interval);
	  break;
	case 2: case 6: /* wrap around graph range */
	  interval = spaces*(interval/spaces - floor(interval/spaces));
	  break;
	/* case 1: extrapolate end sections of graph */
	}
	/* right = use_graph_pointer->points;
	interval++;

	for (length=spaces;length;length--) {
		left = right;
		right++;
		if (--interval <= 1) break;
	}
	*/
	if (use_graph_pointer->range > 3) {
	  intersection = *(use_graph_pointer->points + 
			   max(0,min(spaces,(int)round(interval))));
	} else {
	  lower = max(0,min(spaces-1,(int)(interval)));
	  interval -= lower;
	  left = use_graph_pointer->points + lower;
	  right = use_graph_pointer->points + min(spaces,lower+1);
	  intersection = interval*(*right) + (1-interval)*(*left);
	}
	return use_graph_pointer->ylow + 
		(use_graph_pointer->yhigh - use_graph_pointer->ylow)*
		intersection/use_graph_pointer->yspan;

}

void release_graph_data(graph_data_type *graph_data_pointer) {
   free(graph_data_pointer->points);
}

#ifdef __OPENMP
#define PLUS_THREAD_NUM +omp_get_thread_num()
#else
#define PLUS_THREAD_NUM
#endif
#ifdef WIN32
void setup_randoms(unsigned int seed) {
   srand(seed);
}

double rand_fract() {
/* some built-in random generators are not very accurate. In this
case we may use several random numbers to get a random double. */
    double fraction = 0, precise = 1;
    while (precise > 1e-16) {
	precise = precise/(RAND_MAX+1.0);
	fraction = fraction+precise*rand();
    }
    return fraction;
}
#else
unsigned short (*rand_states)[3];
void setup_randoms(unsigned int seed) {
  int coo, tnum = 0;
#pragma omp parallel
  ++tnum;

  rand_states = new unsigned short[tnum][3];
  for (coo=0; coo<tnum; ++coo) {
    rand_states[coo][0] = seed/65536;
    rand_states[coo][1] = (unsigned short)fmod(seed,65536);
    rand_states[coo][2] = 10000+coo;
  }
}

double rand_fract() {
  return erand48(rand_states[0 PLUS_THREAD_NUM]);
}
#endif

double ame_rand(double lo, double hi) {
    return  lo + (hi-lo)*rand_fract();
}

int compare_instance_status (const int pointers[], const int ref_pointers[], 
			     int num) {
   int count;
   for (count=0; count<num; count++) {
     if (pointers[count]<ref_pointers[count]) return -1;
     if (pointers[count]>ref_pointers[count]) return 1;
   }
   return 0;
}

void append_ints_to_null(int* dest, int* src, int sep, int sep2) {
  while (*dest) { dest++; }
  if (sep) { *(dest++)=sep; }
  if (sep2) { *(dest++)=sep2; }
  do { *(dest++)= *src; } while (*src++);
}
/* This was used to throw exceptions when creating model instances -- these are
tricky for clients to handle, so instead we just report errors into a char**
class DllLossage {
 public:
  const char* action;
  char* fileName;
  char* wibble;
  
  DllLossage(const char* Action, char* FileName, char* Wibble) {
    action=Action;
    fileName=FileName;
    wibble=Wibble;
  }

  char* tell() {
    char* complaint;
    complaint = new char[256];
    sprintf(complaint, "couldn't %s file \"%s\": %s",
	action, fileName, wibble);
    return complaint;
  }
};
*/
  
BOOLEAN is_base_type(int dim) {
  return dim==VALUELESS||dim==REAL||dim==INTEGER||dim==FLAG||dim<=ENUM_BASE;
}

int size_for_data_type(int dtype) { // only works if is_base_type
  switch (dtype) {
  case REAL:
    return sizeof(double);
  case FLAG:
    return sizeof(BOOLEAN);
  case VALUELESS:
    return 0;
  default: // INTEGER or enumerated type
    return sizeof(int);
  }
}

/* This takes a pointer into a dimension list, and returns the number
   of items rrepresented by that list, setting its second arg to point
   to the position in the dim list that specifies one data item in the
   bloc. */

int array_count(int* startDim, int** tgtDim) {
  /* sprintf(globMess, "doing array size, dim %d", *startDim);
     showMess(globMess); */
  if (*startDim>0)
    return (*startDim*array_count(startDim + 1, tgtDim));
  else {
    *tgtDim = startDim;
    return 1;
  }
}

// Creates space and initializes record counts to 0
char* init_space(int dimList[]) {
  int reps, count, *unit;
  sizeAndPtr* bloc;
  
  reps = array_count(dimList, &unit);
  if (*unit == OWNSIZED) {
    bloc = new sizeAndPtr[reps];
    for (count=0; count<reps; ++count)
      bloc[count].size = 0;
    return (char*)bloc;
  } else  // no more per-record levels
    return new char[reps*size_for_data_type(*unit)];
}

/* This and next few could be bundled into a class for the bloc data
void free_bloc_data(char* ptData, int* ptDims) {
  int reps, count, *subDims, saved;
  char* subData;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED or SPARSEARRAY
    if (*subDims==SPARSEARRAY) ++subDims; // advance to dim count slot
    saved = *subDims;
    for (count=0; count<reps; ++count) {
      // prepend size to remaining dims to create right size block
      *subDims = ((sizeAndPtr*)ptData)[count].size;
      free_bloc_data(((sizeAndPtr*)ptData)[count].ptr, subDims);
    }
    *subDims = saved; // restore original contents in case reusing dim list
  } else if (*subDims) // do not delete if empty
    delete ptData; // nothing else to do
}
*/
int free_bloc_level(char* ptData, int* ptDims, int offset) {
  // done by looking at call_for_each_val, which looked elsewhere
  int count;
  sizeAndPtr* convenience;
  int anyData;

  convenience = (sizeAndPtr*)ptData + offset;
  switch (ptDims[0]) {
  case OWNSIZED:
    for (count=0; count<convenience->size; ++count) {
      free_bloc_level(convenience->ptr, ptDims+1, count);
    }
    if (convenience->size) 
      delete convenience->ptr;
    return 1;
  case SPARSEARRAY:
    for (count=0; count<convenience->size; ++count) {
      free_bloc_level(convenience->ptr + sizeof(int)*ptDims[1]*(1+count),
		      // corrects for space taken up by indices
		      ptDims+2, count);
    }
    if (convenience->size) 
      delete convenience->ptr;
    return 1;
  default:
    int reps, *subDims;
    reps = array_count(ptDims, &subDims);
    if (!is_base_type(*subDims)) { // assume its OWNSIZED or SPARSEARRAY
      for (count=0; count<reps; ++count)
	anyData = free_bloc_level(ptData, subDims, reps*offset+count);
// this version was same but looped unnecessarily over numerical arrays
//    if (ptDims[0]>0) { // an array dimension
//      for (count=0; count<ptDims[0]; ++count)
//	anyData = free_bloc_level(ptData, ptDims+1, ptDims[0]*offset+count);
      return anyData;
    } else // a base data type (0 = dataless submodel)
      return *subDims; 
  }
}

// free_bloc_data frees all memory used in a structure
void free_bloc_data(char* ptData, int* ptDims) {
  if (free_bloc_level(ptData, ptDims, 0))
    delete ptData;
}

// copy_bloc_data duplicates a structure, allocating the required memory
// (doesn't work on SPARSEARRAY)
char* copy_bloc_data(char* source, int* ptDims) {
  int reps, count, *subDims;
  char* newData;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED
    newData = new char[reps*sizeof(sizeAndPtr)];
    for (count=0; count<reps; ++count) {
      //substitute OWNSIZED to create right size block then put back
      *subDims = ((sizeAndPtr*)source)[count].size;
      ((sizeAndPtr*)newData)[count].size = *subDims;
      ((sizeAndPtr*)newData)[count].ptr = 
	copy_bloc_data(((sizeAndPtr*)source)[count].ptr, subDims);
    }
    *subDims = OWNSIZED;
  } else {
    count = reps*size_for_data_type(*subDims);
    newData = new char[count];
    memcpy(newData, source, count);
  }
  return newData;
}

char* interpolate_bloc_data(char* loSource, char* hiSource, int* ptDims,
			    double interFract) {
  int reps, count, *subDims;
  char* newData;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED
    newData = new char[reps*sizeof(sizeAndPtr)];
    for (count=0; count<reps; ++count) {
      //substitute OWNSIZED to create right size block then put back
      *subDims = ((sizeAndPtr*)loSource)[count].size;
      ((sizeAndPtr*)newData)[count].size = *subDims;
      ((sizeAndPtr*)newData)[count].ptr = 
	interpolate_bloc_data(((sizeAndPtr*)loSource)[count].ptr, 
			      ((sizeAndPtr*)hiSource)[count].ptr, 
			      subDims, interFract);
    }
    *subDims = OWNSIZED;
  } else {
    count = reps*size_for_data_type(*subDims);
    newData = new char[count];
    if (*subDims == REAL)
      for (count=0; count<reps; ++count)
	*((double*)newData+count) = *((double*)hiSource+count)*interFract
	  + *((double*)loSource+count)*(1-interFract);
    else
      for (count=0; count<reps; ++count)
	*((int*)newData+count) = (int)round(*((int*)hiSource+count)*interFract
				    + *((int*)loSource+count)*(1-interFract));
  }
  return newData;
}

// this sets all the actual values in the structure to 0 without changing
// the size of anything -- used for cancelling events
void zero_bloc_data(char* dest, int* ptDims) {
  int reps, count, *subDims;
  char* newData;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED
    for (count=0; count<reps; ++count) {
      //substitute OWNSIZED to create right size block then put back
      *subDims = ((sizeAndPtr*)dest)[count].size;
      zero_bloc_data(((sizeAndPtr*)dest)[count].ptr, subDims);
    }
    *subDims = OWNSIZED;
  } else {
    if (*subDims == REAL)
      for (count=0; count<reps; ++count)
	*((double*)dest+count) = 0;
    else
      for (count=0; count<reps; ++count)
	*((int*)dest+count) = 0;
  }
}

// locate_elt returns a pointer to one model value in the structure,
// given its indices. If there are fewer than the full number of
// indices, returns a pointer to the structure containing the values
// whose indices start with the given ones. (doesn't work on
// SPARSEARRAY and indeed cannot, because this structure may not
// exist.)
void* locate_elt(char* startPtr, int off, int* dimPtr, int* indxs) {
  sizeAndPtr* newRecord;

  // sprintf(globMess, "locate_elt array %lx off %d d0 %d d1 %d d2 %d indx %d", 
  // (long)startPtr, off, dimPtr[0], dimPtr[1], dimPtr[2], *indxs);
  // showMess(globMess);
  if (*dimPtr==OWNSIZED) {
    newRecord = (sizeAndPtr*)startPtr + off;
    if  (*indxs) // more indices, use to get value from a record submodel
      // bounds check, added in case getting variable params before setting
      if (indxs[0]>newRecord->size)
	return NULL;
      else
	return locate_elt(newRecord->ptr, (*indxs)-1, dimPtr+1, indxs+1);
    else // no more indices, we are looking for recordSet struct
      return newRecord;
  } else if (is_base_type(*dimPtr))
    return startPtr + off*size_for_data_type(*dimPtr);
  else
    return locate_elt(startPtr, *dimPtr*off+(*indxs)-1, dimPtr+1, indxs+1);
}

//! listable class for data to be loaded at a time point 

//! This contains
//! data in a char*, rather than a nodeValue structure, because the
//! dimSpecs are the same for all the time points of a parameter. All
//! members are private because all its operations are done by methods
//! of the FileParamdata class.

class listTimePoint {
  friend class VarParamData;

  double when;
  BOOLEAN myArraySpace;
  char* dataPtr;
  listTimePoint *last, *next;

  listTimePoint(double time, int* dimSpecs) {
    myArraySpace = FALSE;
    when = time;
    dataPtr = init_space(dimSpecs);
    last = next = NULL;
  }      

  // delete contents when deleting parent class cos it has access to dims
  ~listTimePoint() {
  }

  listTimePoint* find_last_pt(double time) {
    if (next) {
      /* sprintf(globMess, "seeking after %lf for %lf", when, time);
      showMess(globMess); */
      if (next->when<=time) {
	return next->find_last_pt(time);
      }
    }
    return this;
  }
};

// class for keeping track of arrays associated with parameters

FileParamData::FileParamData(ExecutingModel* instToUse, int newNodeNum,
			     int* fullDims) {
  int sparePath[32];

  myModelExec = instToUse;
  nodeNum = newNodeNum;
  translate_dims(fullDims, sparePath, dataPtr.dimSpecs, 
		 myModelExec->modelSpec->nodedata[nodeNum].datatype, TRUE);
  dataPtr.contents = init_space(dataPtr.dimSpecs);
  //    dataPtr.contents = new char[sparePath[0]];
  // now insert it into the list (at beginning)
  next = myModelExec->param_array_base;
  myModelExec->param_array_base = this;
}      

  FileParamData::~FileParamData() {
    int size, count;
    char* innerSp;
    
    free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
    // now remove it from the list
    FileParamData** current = &(myModelExec->param_array_base);
    while (*current != this) current = &(*current)->next; // better be in there
    *current = next;
  }
  
// These last two are actually called by the model code to get data

  void FileParamData::extract_elt(void* tgt, int* indxs) {
    // do not do it if this is a variable parameter and we are initializing --
    // array not yet set so let model keep default value...in fact, save it in
    // the array for later
    void* insertionPt;
    node_data_line* nodeLine;

    insertionPt = locate_elt(dataPtr.contents, 0, dataPtr.dimSpecs, indxs);
    if (!insertionPt) return; // record pointers not yet made
    nodeLine = myModelExec->modelSpec->nodedata + nodeNum;

    if (myModelExec->resetting<-1 && nodeLine->eval == INPUT)
      if (!((VarParamData*)this)->GetTimePtDataSpace(0.0)) 
	return;
    // back copy now done in blocks afterwards to make record spaces, but
    // avoid forward copying first
    // memcpy(insertionPt, tgt, size_for_type());
    memcpy(tgt, insertionPt, size_for_data_type(nodeLine->datatype));
  }

  void FileParamData::extract_record_count(void* tgt, int ic, int* indxs) {
    sizeAndPtr* insertionPt;
    int count, indxsWith0[32];

    // need zero at appropriate point in indxs to stop at record pointer
    for (count=0; count<ic; ++count) {
      indxsWith0[count] = indxs[count];
    }
    indxsWith0[count] = 0;
    insertionPt = (sizeAndPtr*)locate_elt(dataPtr.contents, 0, 
					  dataPtr.dimSpecs, indxsWith0);
    *(int*)tgt = insertionPt->size;
  }
// end of FileParamData class

// start of VarParamData class
VarParamData::VarParamData(ExecutingModel* instToUse, int newNodeNum,
			   int* fullDims) 
  : FileParamData(instToUse, newNodeNum, fullDims) {
  timePoints = NULL;
  finalTimePoint = NULL;
  curTimePoint = NULL;
  fillMethod = USE_LAST;

  nextVP = myModelExec->varParamArrayBase;
  myModelExec->varParamArrayBase = this;
}

VarParamData::~VarParamData() {
  ClearTimePtElements();
}

void VarParamData::update_from_points(BOOLEAN dir, double now) {
  listTimePoint *loBound, *hiBound;
  int hiWraps = 0;
  double interFract;
  
  loBound = curTimePoint;
  if (loBound)
    hiBound = roll_forward(loBound, &hiWraps);
  else
    hiBound = timePoints; // first point
  
  if (dir) {
    while (hiBound && now>=hiBound->when+hiWraps*wrapAroundPoint) {
      loBound = hiBound;
      wraps = hiWraps;
      hiBound = roll_forward(loBound, &hiWraps);
    }
  } else {
    while (loBound && now<loBound->when+wraps*wrapAroundPoint) {
      hiBound = loBound;
      hiWraps = wraps;
      loBound = loBound->last;
      if (wrapAroundPoint>0.0 && !loBound) {
	--wraps;
	loBound = finalTimePoint;
      }
    }
  }
  
  if (loBound && hiBound && fillMethod!=USE_LAST) {
    interFract = (now-wraps*wrapAroundPoint-loBound->when)/
      (hiBound->when+(hiWraps-wraps)*wrapAroundPoint-loBound->when);
    //            sprintf(globMess, "lotime %lf hitime %lf Fract %lf", 
    //		    loBound->when, hiBound->when, interFract);
    //      showMess(globMess);
    if (fillMethod==INTERPOLATE && 
	myModelExec->modelSpec->nodedata[nodeNum].datatype != FLAG) {
      curTimePoint = loBound; // cos that's what wraps refers to
      free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
      dataPtr.contents = interpolate_bloc_data(loBound->dataPtr, 
					       hiBound->dataPtr, 
					       dataPtr.dimSpecs, 
					       interFract);
      return;
    }
    if (interFract>0.5) { // fillMethod is USE_CLOSEST
      loBound = hiBound;
      wraps = hiWraps;
    }
  }
  if (loBound && loBound!=curTimePoint) {
    curTimePoint = loBound;
    free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
    dataPtr.contents = copy_bloc_data(loBound->dataPtr, dataPtr.dimSpecs);
    active=TRUE;
  } else {
    if (active && 
	myModelExec->modelSpec->nodedata[nodeNum].compclass == EVENT ) {
      zero_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
      active=FALSE;
    }
  }
}

  BOOLEAN VarParamData::create_time_point(double time) {
    listTimePoint *lastTimePt, *thisTimePt, *nextTimePt;
    if (timePoints && timePoints->when<=time) {
      lastTimePt = timePoints->find_last_pt(time);
      if (lastTimePt->when==time) {
	return FALSE; // a point already exists at this time
      } else { // lastTimePt is earlier than new one
	nextTimePt = lastTimePt->next;
	thisTimePt = new listTimePoint(time, dataPtr.dimSpecs);
	thisTimePt->next = lastTimePt->next;
	lastTimePt->next = thisTimePt;
	thisTimePt->last = lastTimePt;
	if (nextTimePt) {
	  nextTimePt->last = thisTimePt;
	} else {
	  finalTimePoint  = thisTimePt;
	}
      }
    } else {
      thisTimePt = new listTimePoint(time, dataPtr.dimSpecs);
      thisTimePt->next = timePoints;
      if (timePoints) {
	timePoints->last = thisTimePt;
      } else {
	finalTimePoint  = thisTimePt;
      }
      thisTimePt->last = NULL;
      timePoints = thisTimePt;
    }
    return TRUE; // new point has been created
  }

// only used for saving byte array, so obsolescent
char* VarParamData::FindNextTimePtSpace(double* last_time) {
  listTimePoint* seek = timePoints->find_last_pt(*last_time);

  if (seek = seek->next) { // assignment
    *last_time = seek->when;
    return seek->dataPtr;
  }
  return NULL;
  /* old version duplicated effort
  while (seek) {
    if (seek->when>*last_time) {
      *last_time = seek->when;
      break;
    }
    seek = seek->next;
  }
  if (seek)
    return seek->dataPtr;
  else
    return NULL;
  */
}

  char* VarParamData::GetTimePtDataSpace (double time) {
    listTimePoint* timePt;

    if (timePoints) {
      if ((timePt = timePoints->find_last_pt(time))->when==time)
	return timePt->dataPtr;
    }
    return NULL;
  }

  listTimePoint* VarParamData::roll_forward(listTimePoint *bound, int *newWraps) {
    bound = bound->next;
    if (!bound && wrapAroundPoint>0.0) {
      *newWraps = wraps+1;
      bound = timePoints;
    } else
      *newWraps = wraps;
    return bound;
  }

void VarParamData::ClearTimePtElements() {
  while (timePoints) {
    curTimePoint = timePoints;
    timePoints = curTimePoint->next;
    free_bloc_data(curTimePoint->dataPtr, dataPtr.dimSpecs);
    delete(curTimePoint);
  }
  finalTimePoint = NULL;
  curTimePoint = NULL;
}

void VarParamData::back_copy_vars() {
  nodeValues* fromModel;
  
  if (!GetTimePtDataSpace(0.0)) {
    free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
    fromModel = myModelExec->GetRawValues(nodeNum);
    dataPtr.contents = fromModel->contents;
//    sprintf(globMess, "dims %d %d backcopied %d records 1st %lf", 
//	    dataPtr.dimSpecs[0], dataPtr.dimSpecs[1], ((sizeAndPtr*)dataPtr.contents)->size,
//	    *(double*)(((sizeAndPtr*)dataPtr.contents)->ptr));
//    showMess(globMess);
    delete fromModel;
  }
  if (nextVP) nextVP->back_copy_vars();
}

void VarParamData::ResetTimeSeries(int topPhase) {
  curTimePoint = NULL;
  wraps = 0;
  if (topPhase <= -2)
    active = FALSE;
  update_from_points(TRUE, 0);

  if (nextVP) nextVP->ResetTimeSeries(topPhase);  
}

void VarParamData::UpdateTimeSeries(double now, BOOLEAN forward) {
  update_from_points(forward, now);

  if (nextVP) nextVP->UpdateTimeSeries(now, forward);  
}    
  
int step_list(int **dim_list) {
  return *(*dim_list)++;
}

// FINDABLE EXPORT getpointer_type burrow_to;
// FINDABLE EXPORT void* burrow_to(void* level, int** id_meta, int** dim_list) {
// This has been messed with in a manner similar to do_evalmodel above
void* get_ptr(void* level, int** id_meta, int** dim_list) {
  int* lastDim;

  while (**id_meta>0) { /* 0 means end of tree, -1 means vm level */
    lastDim = *dim_list;
    // char globMess[255];
    // sprintf(globMess, "gonna g_p id %d,%d... dims %d,%d",
    //    **id_meta, *(*id_meta+1), **dim_list, *(*dim_list+1));
    // suppShowMess(globMess);
    level = ((submodeltype*)level)->get_pointer(step_list(id_meta),dim_list);
    // note that if it is a vm submodel, level is set to a metapointer
    // so we had better not recurse
    if ((*lastDim == REQ_COUNT) && (*dim_list != lastDim)) { // moved on
      break;
    }
  }
  return(level);
};

InstanceOfModel* step_ptr(InstanceOfModel* ptr) {
  int next_handle[] = {1,0}, dimDum[] = {0}, *idler1, *idler2;

  idler1 = next_handle;
  idler2 = dimDum; // dummy dim needed to survive member count retreival test
  return *(InstanceOfModel**)(get_ptr(ptr, &idler1, &idler2));
}

int count_members(InstanceOfModel* ptr) {
  // do not recurse, there may be too many of them
  int count = 0;
  while(ptr) {
    ptr = step_ptr(ptr);
    ++count;
  }
  return count;
}

// put indices of current instance onto data blk
void fill_indices(InstanceOfModel* smHandle, int indxCount, 
		  char** insertionPt) {
  int idHandle[] = {2,0}, idIdx[1], *idler1, *idler2;

  for (idIdx[0] = 0; idIdx[0]<indxCount; ++idIdx[0]) {
    idler1 = idHandle;
    idler2 = idIdx;
    memcpy(*insertionPt, get_ptr(smHandle, &idler1, &idler2),
	   sizeof(int));
    *insertionPt += sizeof(int);
  }
}

int skip_vm_bounds(int** modelDimList) {
  int count = 0;
  while (*(++(*modelDimList)) != END_VM)
    ++count;
  return count;
}

// this is used by the ExecutingModel class to recurse through submodels
// to get values. Not a class member because it works at a lower level

// dims starts off as the block sizes at each level of data nesting,
// but ass we recurse through this it gets replaced by the array of
// counts that are being incremented in the instances of this
// procedure from which the current one is being called
void fill_raw_values(InstanceOfModel* smHandle, int tree[],
		     int* use_dims, int dims[], int* dim_place,
		     char** insertionPt) {
  int count, dimty = 0; // value for RECORDS
  void* model_val_ptr;
  char *newBlk;
  
//  sprintf(globMess, "fill_raw: case %d %d, dims %d %d %d %d, off %d fill %d",
//	  use_dims[0], use_dims[1], dims[0], dims[1], dims[2], dims[3], 
//        dim_place - dims, (int)*insertionPt);
//  showMess(globMess);
  
  switch (*use_dims) {
  case START_VM:
    dimty = skip_vm_bounds(&use_dims); // and drop through, keeping this value
//  case RECORDS: // dimty will end up as 0
    --dimty; // and drop through
  case MEMBERS: // dimty will end up as 1
    ++dimty; 
    /* Count the number of instances in the submodel, multiply by size
       needed for each instance and its indices, alloc this and
       recurse to fill it up, and place count and pointer to new space
       in insertionPt. */
    smHandle = *(InstanceOfModel**)get_ptr(smHandle, &tree, &dims);
    count = count_members(smHandle);
    ((sizeAndPtr*)(*insertionPt))->size = count;
    if (count) // do not waste energy creating zero-length blox
      newBlk = new char[count*(dimty*sizeof(int) + dim_place[1])];
    ((sizeAndPtr*)(*insertionPt))->ptr = newBlk;
    *insertionPt += sizeof(sizeAndPtr);
    while (*tree++ != -1) {} // make relevant to current submodel
    while (smHandle) {
      fill_indices(smHandle, dimty, &newBlk);
      fill_raw_values(smHandle, tree,
		      use_dims+1, dim_place+1, dim_place+1, &newBlk);
      smHandle = step_ptr(smHandle);
    }
    break;
  case 0:
    model_val_ptr = get_ptr(smHandle, &tree, &dims);
    memcpy(*insertionPt, model_val_ptr, *dim_place);
    *insertionPt += *dim_place;
    break;
  case RECORDS:
    dimty = *dim_place; // save block size in case we need it again
    *dim_place = REQ_COUNT; // tells get_ptr to get made count
    int *tree_copy, *dims_copy;
    tree_copy = tree;
    dims_copy = dims; 
    count = *(int*)get_ptr(smHandle, &tree_copy, &dims_copy);
    ((sizeAndPtr*)(*insertionPt))->size = count;
    newBlk = new char[count*dim_place[1]];
    ((sizeAndPtr*)(*insertionPt))->ptr = newBlk;
    *insertionPt += sizeof(sizeAndPtr);
    *dim_place = dimty;
    // now overwrite dim to look like normal array, recurse, and put back
    *use_dims=count;
    fill_raw_values(smHandle, tree, use_dims, dims, dim_place, &newBlk);
    *use_dims=RECORDS;
    break;
  default: /* value is a dimension of the array we are accessing */
    count = *dim_place; // save block size in case we need it again
    for (*dim_place = 0; *use_dims > *dim_place; ++*dim_place) {
      fill_raw_values(smHandle, tree, use_dims+1, dims, dim_place+1, 
		      insertionPt);
    }
    *dim_place = count;
    break;
  }
}

class ModelServer;

// Implementation of class ExecutingModel
ExecutingModel::ExecutingModel(ModelServer* newModelSpec, void* yourRef) {
    modelSpec = newModelSpec;
    clientRef = yourRef;
    loadedInst = ((createmodel_type*)modelSpec->createmodel)(this);
    //sprintf(globMess, "This is XM %lx of M %lx being created with IOM %lx", 
//	    (long)this, (long)modelSpec, (long)loadedInst);
    //showMess(globMess);
    param_array_base = NULL;
    varParamArrayBase = NULL;
}

ExecutingModel::~ExecutingModel() {
  while (param_array_base) delete param_array_base;
  delete loadedInst;
}

excpData* ExecutingModel::ResetInstance(int how_int, int top_phase) {
  int tweak_phase, err;

  loadedInst->userStop.excpNo = 0;
  if (top_phase<=0) {
    resetting = top_phase;
    last_op = 0;
    last_exit = last_update = last_check = 0; // reset timekeeping
    for (tweak_phase=1; tweak_phase <= 7; tweak_phase++) {
      lts[tweak_phase]=0;
      took[tweak_phase]=0;
      SetdT( -tweak_phase,0);
      SetdT( tweak_phase,steps[tweak_phase]);
    }
    switch (how_int) {
    case EULER:
      SetdT(0,0);
      break;
    case RUNGE_KUTTA:
      SetdT(0,1);
    } // was -1,0 to stop loss, but now we want it cos it happens next step
    thisTsPosn = 0.0;
    if (varParamArrayBase)
      varParamArrayBase->ResetTimeSeries(top_phase);
    adapt_doublings = 0;
  }
  
  err=loadedInst->do_evalmodel(top_phase);
  if (err)
    loadedInst->userStop.excpNo = err;
  //    else
  //      (*advancemodel)(modelHandle, top_phase);
  if (loadedInst->userStop.excpNo)
    return &(loadedInst->userStop);
  // reset successful: now do back copy if needed
  if (top_phase<-1 && varParamArrayBase) {
    varParamArrayBase->back_copy_vars(); // does all
  }
  return NULL;
}

excpData* ExecutingModel::ExecuteInstance(int how_int, 
		   double start, double* end, double errlim) {
  double freq, xtime, recover;
    int big_phase, err;
    BOOLEAN made_step, first_pass;
    // sprintf(globMess, "xm %d %lf-%lf at %lf", how_int, start, *end, errlim);
    // showMess(globMess);
    // temporary arrangement until we move this function into the instance
    excpData* userDefStop = &(loadedInst->userStop);

    resetting = 0;
    userDefStop->excpNo = 0;
    freq = steps[modelSpec->phases]*pow(2,-adapt_doublings);
    xtime = start;
    while (freq*(*end-xtime)>0) { // freq only affects sign
      made_step = 0;
      first_pass = 1;
      big_phase = phase_for(xtime, freq, modelSpec->phases);
      // that is the biggest phase we will try to run, we may not succeed
      if (check_gui(xtime, big_phase)) {
	userDefStop->excpNo = -100; // should not conflict with os signals
	*end = xtime;
	return userDefStop;
      }
      while(!made_step) {
	// stretch interval to hit end if necssary
	if (xtime/freq+1.0625>*end/freq) {
	  freq = *end-xtime;
	  xtime = *end;
	} else {
	  xtime+=freq;
	}
	set_dts(big_phase, xtime);

	switch (how_int) {
	case EULER:
	  if (first_pass) {
	    recover = 0.5;
	    SetdT(0,0);
	  } else {
	    SetdT(0,-1);
	  }
	  advance_time(big_phase, 1);
	  loadedInst->updatemodel(big_phase);
	  break;
	case RUNGE_KUTTA:
	  if (first_pass) {
	    SetdT(0,1);
	    recover = 0.0625;
	  } else {
	    SetdT(0,-2);
	  }
	  loadedInst->updatemodel(big_phase);
	  userDefStop->excpNo=rk_update();
	  break;
	}
	if (userDefStop->excpNo) break; // from inner loop
	first_pass = 0;
	if (!errlim) {
	  made_step = 1;
	} else {
	  /* tweak to allow events to be placed precisely in time. Clear maxerr
	     before the final rate calculation, and allow threshold detection 
	     to increase it to the amount by which the threshold is crossed. */
	  loadedInst->adapt_maxerr = 0;
	  if (userDefStop->excpNo=loadedInst->do_evalmodel(modelSpec->phases+1))
	    break;
	  // from inner loop

	  // get the model to generate its error estimate
	  // previous point for zeroing maxerr
	  if (loadedInst->adapt_maxerr<=errlim) { // no point if already over
	    SetdT( 0,10);
	    loadedInst->updatemodel(big_phase);
	  }
	  if (loadedInst->adapt_maxerr>errlim) {
	    // error too great; put comps back and try shorter
	    if (adapt_doublings<31) {
	      advance_time(big_phase, -1); // back to start
	      xtime-=freq;
	      adapt_doublings++;
	      freq = steps[modelSpec->phases]*pow(2,-adapt_doublings);
	      big_phase = phase_for(xtime, freq, modelSpec->phases);
	    } else {
	      // signal problem
	      userDefStop->excpNo = -99;
	      break;
	    }
	  } else {
	    made_step = 1;
	    if (adapt_doublings && loadedInst->adapt_maxerr<errlim*recover) {
	      // low error; try longer next time if poss
	      adapt_doublings--;
	      freq = steps[modelSpec->phases]*pow(2,-adapt_doublings);
	    } // lengthen time step
	  } // timestep too short or not
	} // error limit exists
      } // made progress
//      printf("Moved forward %f units\n", freq);
      if (userDefStop->excpNo) break; // from outer loop
      if (userDefStop->excpNo=loadedInst->do_evalmodel(big_phase)) break;
//      (*advancemodel)(id, big_phase);
    }
    if (check_gui(*end, 0) && !userDefStop->excpNo)
      // always go to make sure time is right
      userDefStop->excpNo = -100;
    *end=xtime;
    if (userDefStop->excpNo)
      return userDefStop;
    return NULL;
  }
  
int ExecutingModel::phase_for(double current, double step, int so_far) {
    int try_now, try_current;
    double last, next, next_step;

    if (so_far==1) {
      return 1;
    }
    try_now = so_far-1;
    next_step = steps[try_now];
    last = current+step/2;
    next = last+step;

    try_current = (int)floor(last/next_step);
    if (try_current == (int)floor(next/next_step)) {
      return so_far;
    } else {
      return phase_for(next_step*try_current, next_step, try_now);
    }
  }

int ExecutingModel::rk_update() {
  int wee_phase, err, phases=modelSpec->phases;
    InstanceOfModel* id = loadedInst;

    wee_phase=phases+1;
    advance_time(phases, 0.5);
    SetdT( 0,2);
    if (err=id->do_evalmodel(wee_phase)) return err;
    id->updatemodel(phases);
    SetdT( 0,3);
    if (err=id->do_evalmodel(wee_phase)) return err;
    id->updatemodel(phases);
    advance_time(phases, 0.5);
    SetdT( 0,4);
    if (err=id->do_evalmodel(wee_phase)) return err;
    id->updatemodel(phases);
    SetdT( 0,1);
    return 0;
  }

void ExecutingModel::set_dts (int phase, double current) {
    int tweak_phase;
    for (tweak_phase=phase; tweak_phase<=modelSpec->phases; tweak_phase++) {
      ldts[tweak_phase]=current-lts[tweak_phase];
      SetdT(tweak_phase,ldts[tweak_phase]); 
      // dts should only be global but im lazy
    }
  }
  
void ExecutingModel::advance_time (int phase, double fraction) {
    int tweak_phase;
    double series_pt;

    // series_pt = lts[phases]+ldts[phases]*fraction/2; 
    // load values for middle of interval as they apply throughout it...no
    for (tweak_phase=phase; tweak_phase<=modelSpec->phases; tweak_phase++) {
      lts[tweak_phase]=lts[tweak_phase]+ldts[tweak_phase]*fraction;
      SetdT(-tweak_phase,lts[tweak_phase]); 
      // ts should only be global but im lazy
    }
    // time value is chosen to work with RK so series pt should do the same
    series_pt = lts[modelSpec->phases];
    if (varParamArrayBase) 
      varParamArrayBase->UpdateTimeSeries(series_pt, series_pt > thisTsPosn);
    thisTsPosn = series_pt;
  }
  
// new version: is member of model-execution class and takes numerical node id
nodeValues* ExecutingModel::GetRawValues(int nodeId) {
  int sparePath[32], fullDims[32], indices[32];
  char spareCapt[255], *insertionPt;
  enum_type_data *spareTypes[32]; // might need for reading files
  nodeValues* newBlk;

  modelSpec->SearchInfo(nodeId, spareCapt, fullDims, spareTypes);
  newBlk = new nodeValues;
  // find first dimension not a positive integer
  translate_dims(fullDims, indices, newBlk->dimSpecs, 
		 modelSpec->nodedata[nodeId].datatype, 
		 FALSE);

  if (indices[0]) {
    insertionPt = newBlk->contents = new char[indices[0]];
    *sparePath = 0; // copy path data because f_r_v could overwrite it
    append_ints_to_null(sparePath, modelSpec->nodedata[nodeId].path, 0, 0);
    fill_raw_values(loadedInst, sparePath, 
		    fullDims, indices, indices, &insertionPt);
  } else
    newBlk->contents = NULL;
  return newBlk;
}

BOOLEAN ExecutingModel::do_gui_check(double model_time, int actionType) {
  BOOLEAN result;

  result = modelSpec->interact_gui(clientRef, actionType, model_time);
  last_check = clock(); // GUI may have taken time
  return result;
}

BOOLEAN ExecutingModel::check_gui(double model_time, int this_op) {
  unsigned long int this_update;
  BOOLEAN result = FALSE;

  // first record how much time the last op took
  this_update=clock();
  took[last_op]=this_update-last_exit;
  
  if ((this_update-last_update)+took[this_op]>FLASH) {
    result=do_gui_check(model_time, 1+!this_op);
    last_update=last_check;
  }

  last_op = this_op;
  last_exit=this_update;
  return result;
}

FileParamData* ExecutingModel::UseArrayForParams(int nodeNum) {
  int fullDims[32];
  char spareCapt[255];
  enum_type_data *spareTypes[32]; // might need for reading files

  // use searchinfo because we want the ET dims translated to numbers
  modelSpec->SearchInfo(nodeNum, spareCapt, fullDims, spareTypes);
  // make the appropriate kind of file parameter
  if (modelSpec->GetProperty(nodeNum, GETEVAL) == INPUT)
    return new VarParamData(this, nodeNum, fullDims);
  else
    return new FileParamData(this, nodeNum, fullDims);
}

void ExecutingModel::GetValuePointer(void* modelSlot, int paramId,
				     int ic, int* indxs) {
  FileParamData* paramArrayItem;

  paramArrayItem = param_array_base;
  if (modelSpec->param_item_from_id(&paramArrayItem, paramId))
    paramArrayItem->extract_elt(modelSlot, indxs);
  else {
    // couldn't find id, try to find a member parameter
    // first get its nodeline
    node_data_line *nodeLine;
    nodeLine = modelSpec->md_nodlin_from_id(paramId);
    paramArrayItem = param_array_base;
    if (modelSpec->member_param_item(&paramArrayItem, nodeLine->path))
      // found a parameter inside this submodel, get record count
      paramArrayItem->extract_record_count(modelSlot, ic, indxs);
    else
      modelSpec->get_value_pointer(clientRef, modelSlot, thisTsPosn,
			       paramId, ic, indxs);
  }
  // sprintf(globMess, "Think we got %d (%lf)", *(int*)modelSlot, *(double*)modelSlot);
  // showMess(globMess);

}

// Implementation of class ModelServer
ModelServer::ModelServer(char* fileName, char** complaint) {
    handle = LOAD_DLL(fileName);
    if (!handle) {
      *complaint = strdup(WHAT_WENT_WRONG());
      return;
    }
    getversion = (void*)FIND_FUNCTION(handle, "get_version");
    // this does nothing but return the version number, so it can be checked 
    // even if different versions change the args to getcount()
    if (getversion == NULL) {
      *complaint = new char[256];
      sprintf(*complaint, "the shared object is probably not a Simile model");
      return;
    }
    if (fabs(((getversion_type*)getversion)()-atof(SIMILE_VERSION))>0.00001) {
      *complaint = new char[256];
      sprintf(*complaint, "client is for version %s but model is %.1f", 
	      SIMILE_VERSION, ((getversion_type*)getversion)());
      return;
    }
/* sprintf(globMess, "Loaded %ld", handle);
showMess(globMess); */
    *complaint = NULL;

    getcount = (void*)FIND_FUNCTION(handle, "get_count");
    nodecount = ((getcount_type*)getcount)((void*)ame_rand, 
			 (void*)graphpoint,
			 (void*)release_graph_data, 
			 (void*)compare_instance_status, 
			 (void*)handle_model_param_request, 
			 (void*)stat_check,
			 (void*)showModelMess,
			 (void*)&c_graphdata,
			 &phases, &nodedata);

    createmodel = (void*)FIND_FUNCTION(handle, "do_createmodel");
  }

ModelServer::~ModelServer() {
  if (handle && !UNLOAD_DLL(handle)) {
    // cannot use showMess because deleting object
    printf("Failed to unload shared library: %s\n", WHAT_WENT_WRONG());
  }
  // if (channelData) delete channelData;
}

  /* Next bit is really boring...and possibly needles...but I feel I have to
     make class procedures for the things loaded from the model dll rather than
     trying to refer to procedure variables in the model class directly */

ExecutingModel* ModelServer::create(void* yourRef) {
    c_graphdata = NULL; // this will be filled when initializing new instance
    // Do not return raw instance -- just create a wrapper object with fields
    // for raw instance and model type object
    return new ExecutingModel(this, yourRef);
  }

int ModelServer::parent_line (int line) {
    int count, level, test, *path;
    path = nodedata[line].path;
    for (count=0;nodecount>count;count++) {
      level = 0;
      while (test = nodedata[count].path[level]) {
	if (test != path[level++]) {
	  break;
	}

      }
      if (!test && path[level] && (!path[level+1] || 
				  (path[level+1]<0 && !path[level+2]))) {
	return(count);
      }
    }
    return(-1);
  }
      
int ModelServer::make_full_caption(int line, char *result, int* dims,
			 enum_type_data** types) {
    /* New version which does not depend on the nodedata array being in
       any particular order -- and returns the whole caption */
    int parent, typesSoFar, count;

    for (count=0; count<nodedata[line].enum_type_count; ++count) {
      types[count]=&(nodedata[line].enum_type_ptrs[count]);
    }
    if ((parent = parent_line(line)) >= 0) {
      typesSoFar = count+make_full_caption(parent, result, dims, types+count);
    } else {
      *result = (char)NULL;
      *dims = 0;
      typesSoFar = count;
    }
    // correct earlier enum type references to take account of this level
    count = 0;
    while (dims[count]) {
      if (dims[count] <= ENUM_BASE) {
	dims[count] = dims[count] - nodedata[line].enum_type_count;
      }
      count++;
    }
    // add this levels caption unless it is top
    if (parent>=0) {
      strcat(result, "/");
      strcat(result, nodedata[line].strings[0]);
    }
    append_ints_to_null(dims, nodedata[line].dims, 0, 0);
    /* add this levels type data -- reverse order cos outer models start list
    for (count=nodedata[line].enum_type_count-1;count>=0;--count) {
      types[typesSoFar++]=&(nodedata[line].enum_type_ptrs[count]);
      } ...not any more */
    return typesSoFar;
}
  
  /*  int find_et_struct(int fake_dim) {
    enum_data_type* seeker = enumtypedata;
    while (fake_dim++ < -10) {
      seeker = seeker->next;
    }
    return 3;
  }
  */

int ModelServer::getinfo(char* node_id, int* gLine) {
    int count, gcount;
    char* ghosts;
    ghost_ref_data* gpair;

    *gLine = -1;
    for (count=0;nodecount>count;++count) {
      if (!strcmp(node_id, nodedata[count].name))
	return count; // found node line
      for (gcount=0;gcount<nodedata[count].ghost_count;++gcount) {
	gpair = nodedata[count].ghost_ref_ptrs + gcount;
	if (!strcmp(node_id, gpair->ghost)) {
	  *gLine = count;
	  return getinfo(gpair->base, &count); // count is spare
	}
      }
    }
    return -1;
  }

int ModelServer::GetProperty(int line, int propertyId) {
  switch (propertyId) {
    case GETTYPE:
      return nodedata[line].datatype;
    case GETEVAL:
      return nodedata[line].eval;
    case GETCLASS:
      return nodedata[line].compclass;
    case GETGRAPH:
      return nodedata[line].graph;
    default:
      return BADTYPE;
    }
}

char* ModelServer::GetMetadataText(int line, int propertyId) {
  switch (propertyId) {
    case GETINTERNALID:
      return nodedata[line].name;
    case GETSPEC:
      return nodedata[line].strings[1];
    case GETDESC:
      return nodedata[line].strings[2];
    case GETCOMMENT:
      return nodedata[line].strings[3];
    default:
      return NULL;
    }
}

int ModelServer::param_item_from_id(FileParamData** start, int paramId) {
  if (!*start) {
    return 0;
  } else if (nodedata[(*start)->nodeNum].graph==paramId)
    return 1;
  else {
    *start = (*start)->next;
    return param_item_from_id(start, paramId);
  }
}

// New version of nodeModelAndId returns number
// -- who knows, maybe one day it will work intelligently?
int ModelServer::NodeNumFromCapt(char* seeknode) {
  int count;
  char test[255];
  int dims[32];
  enum_type_data* types[32];

  for (count = 1; nodecount>count; ++count) {
    if (nodedata[count].eval == GHOST) continue;
    make_full_caption(count, test, dims, types);
	  
    if (!strcmp(seeknode, test)) {
      return(count);
    }
  }
  /* Node with given caption not found... */
  return -1;
}

int ModelServer::member_param_item(FileParamData** start, int* parentPath) {
  node_data_line* nLine;

  if (!*start)
    return 0; // no children found
  else {
    nLine = nodedata + (*start)->nodeNum;
    if (nLine->eval == TABLE) { // and fixed, is child?
      int count = -1;
      while (parentPath[++count])
	if (nLine->path[count] != parentPath[count])
	  break; // found difference
      if (!parentPath[count]) // got to end without difference, result!
	return 2;
    }
  }
  *start = (*start)->next;
  return  member_param_item(start, parentPath); // keep looking
}

node_data_line* ModelServer::md_nodlin_from_id(int paramId) {
    int count;
    node_data_line *nodeLine;
    for (count=0; count<nodecount; ++count) {
      nodeLine = nodedata + count;
      if (nodeLine->graph==paramId) return nodeLine;
    }
    return NULL;
}

int ExecutingModel::SetStep(int phase, double step) {
  steps[phase] = step;
  return modelSpec->phases;
}

void ExecutingModel::SetdT(int phase, double starttime) {
  if (modelSpec->phases>=abs(phase))
    if (phase>0) { /* lazy */
      loadedInst->dts[phase] = starttime;
    } else {
      loadedInst->ts[-phase] = starttime;
    }
}

FileParamData* ExecutingModel::FileParamForNodeNum(int seekNodeNum) {
  FileParamData* check = param_array_base;
  while (check) {
    if (check->nodeNum == seekNodeNum)
      return check;
    check = check->next;
  }
  return NULL;
}
// End of implementation of class ExecutingModel

FileParamData* param_array_item(ExecutingModel* xm, char* seekNodeId) {
  int seekNodeNum, spareInt;

  // all params are for same model instance so convert nodeId to line number
  // using model spec from first
  seekNodeNum = xm->modelSpec->getinfo(seekNodeId, &spareInt);
  return xm->FileParamForNodeNum(seekNodeNum);
}
    
void* use_array_for_params(void* xmHandle, char* nodeId) {
  FileParamData* arrSlot;
  int lineFromNodeId, spareInt, seekNodeNum;
  ExecutingModel* recipient = (ExecutingModel*)xmHandle;

  // sprintf(globMess, "use_array_for_params node %s", nodeId);
  // showMess(globMess);

  if (!(arrSlot=param_array_item(recipient, nodeId))) {
    lineFromNodeId = recipient->modelSpec->getinfo(nodeId, &spareInt);
    arrSlot = recipient->UseArrayForParams(lineFromNodeId);
    if (!arrSlot) { // no failure condition made yet
      delete arrSlot;
      return 0;
    }
    // these now done in constructor
    // arrSlot->next = param_array_base;
    // param_array_base = arrSlot;
  }

  return arrSlot;
}

void* get_param_data_space(void* fpHandle) {
  return ((FileParamData*)fpHandle)->dataPtr.contents;
}
			   
int space_used(nodeValues* dataPtr) {
  int *base;
  // hope it evaluates left to right
  return array_count(dataPtr->dimSpecs, &base)*size_for_data_type(*base);
}

int param_array_size(void* fpHandle) {
  return space_used(&((FileParamData*)fpHandle)->dataPtr);
}

int clear_time_point_elts(void* fpHandle) {
  ((VarParamData*)fpHandle)->ClearTimePtElements();

//  if (!(arrSlot=param_array_item(recipient->param_array_base, nodeId))) {
//    return 1; // no data structure for this elt
//  }
}

double* get_wrap_ptr(void* fpHandle) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;

//  if (!(arrSlot=param_array_item(recipient->param_array_base, nodeId))) {
//    return NULL; // no data structure for this elt
//  }
  return &arrSlot->wrapAroundPoint;
}

int* get_fill_ptr(void* fpHandle) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;

//  if (!(arrSlot=param_array_item(recipient->param_array_base, nodeId))) {
//    return NULL; // no data structure for this elt
//  }
  return &arrSlot->fillMethod;
}

int create_time_point(void* fpHandle, double time) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;

//  if (!(arrSlot=param_array_item(recipient->param_array_base, nodeId))) {
//    return 1; // no data structure for this elt
//  }
  arrSlot->create_time_point(time);
  return 0;
}

void* find_next_timept_space(void* fpHandle, double* last_time) {
  ((VarParamData*)fpHandle)->FindNextTimePtSpace(last_time);
}

char* get_param_ptr_and_dims(void* fpHandle, int** dimSlot) {
  FileParamData* arrSlot = (FileParamData*)fpHandle;
//  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
//    return NULL; // no data structure for this elt
//  }

  *dimSlot = arrSlot->dataPtr.dimSpecs;
  return arrSlot->dataPtr.contents;
}

int get_timepoint_ptr_and_dims(void* fpHandle, double time, 
				 char** ptDataSlot, int** dimSlot) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;
  char* ptData;

//  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
//    return 2; // no data structure for this elt
//  }
  ptData = arrSlot->GetTimePtDataSpace(time);
  if (!ptData) return 1; // no matching time point

  *ptDataSlot = ptData;
  *dimSlot = arrSlot->dataPtr.dimSpecs;
  return 0; // success
}

int set_bloc_record_count(char* ptData, int* ptDims, int* indxs, int length) {
  sizeAndPtr* newRecord;
  int* subDims;

  newRecord = (sizeAndPtr*)locate_elt(ptData, 0, ptDims, indxs);
    // before going any further, check we are actually at a record list level
  subDims = ptDims;
  while (*indxs) {
    subDims += 1;
    indxs += 1;
  }
  if (*subDims != OWNSIZED) return 1; // we are not
  
  if (newRecord->size) {
    delete newRecord->ptr;
  }
  //substitute OWNSIZED to create right size block then put back
  *subDims = newRecord->size = length;
  newRecord->ptr = init_space(subDims);
  *subDims = OWNSIZED;
  return 0;
}

int insert_to_array(char* contents, double val, int* dimSpecs, int* indxs,
		    int base) {
  void* insertionPt;
  
  insertionPt = locate_elt(contents, 0, dimSpecs, indxs);
  switch (base) {
  case REAL:
    *(double*)insertionPt = val;
    break;
  case FLAG:
    *(BOOLEAN*)insertionPt = (BOOLEAN)val;
    break;
  default: // INTEGER or enumerated type
    *(int*)insertionPt = (int)val;
    break;
  }
  //sprintf(globMess, "inserted %lf to space at %d %d", val, indxs[0], indxs[1]);
  //showMess(globMess);
  return 0;
}

void set_bloc_element(char* ptData, int* ptDims, int* indxs, double value) {
  // Because Simile input tools may not supply all the dimensions of the 
  // parameter array, this has to work out how many dimensions are supplied
  // and fill all the elements for which these are the innermost indices.
  int count, haveDims, needDims, makeDims, useDims[32], recBounds[32], done = 0;
  for (count=31; count>=0; count--) {
    if (indxs[count]<0) {
      haveDims = count;
    }
    if (is_base_type(ptDims[count])) {
      needDims = count;
      haveDims = count; // avoid having too many
    }
  }
  makeDims = needDims-haveDims;
  //sprintf(globMess, "have %d need %d (val %lf)", haveDims,needDims,value);
  //showMess(globMess);
  for (count = 0; count<needDims; count++) {
    if (count<makeDims) {
      recBounds[count] = ptDims[count];
      useDims[count] = 1;
    } else {
      useDims[count] = indxs[count-makeDims];
    }
  }
  // next bit iterates over all combinations of outer dimensions
  while (!done) {
    insert_to_array(ptData, value, ptDims, useDims, ptDims[needDims]);
    for (count = makeDims-1; count>=0; count--) {
      if (useDims[count] == 1 && ptDims[count] == OWNSIZED) {
	useDims[count] = 0; // tells locate_elt to get record count
	recBounds[count] = 
	  ((sizeAndPtr*)locate_elt(ptData, 0, ptDims, useDims))->size;
	useDims[count] = 1; // back to normal
      }
      if (++useDims[count]<=recBounds[count]) break;
      useDims[count] = 1;
    }
    done = count==-1;
  }
}

void handle_model_param_request(void* instId, void* modelSlot,
		       int paramId, int ic, int* indxs) {
//  sprintf(globMess, "h_m_p_t to location %lx for exmod %lx node %d count %d indx0 %d indx1 %d", (long)modelSlot, (long)instId, paramId, ic, indxs[0], indxs[1]);
//  showMess(globMess);
  ((ExecutingModel*)instId)->GetValuePointer(modelSlot, paramId, ic, indxs);
}

/* This finds node ids from captions globally. It runs through a model
comparing each caption with what we are after, and as well as returning if
it finds it, it continues inside any separate submodel it comes across whose
caption fits the start of what we are after (after trimming the portion found
from the search string, less the submodel itself -- note it may be an issue
that the submodel name is searched for in both models ) */

int nodeModelAndId(ModelServer* seekType, char* seeknode,
		   ModelServer** tgtModel) {
  int count;
  char test[255];
  int dims[32];
  enum_type_data* types[32];

  for (count = 1; seekType->nodecount>count; ++count) {
    if (seekType->nodedata[count].eval == GHOST) continue;
    seekType->make_full_caption(count, test, dims, types);
	  
    if (!strcmp(seeknode, test)) {
      *tgtModel = seekType;
      return(count);
    }
  }
  /* Node with given caption not found... */
  return -1;
}

char *falseTxt = (char*)"false";
char *trueTxt = (char*)"true";
char *booleanMems[2] = {falseTxt, trueTxt};
enum_type_data noType = {0, NULL, NULL}, 
  boolDataType = {1, falseTxt, &trueTxt},
  boolDimType = {2, "boolean", (char**)booleanMems};

node_data_line* ModelServer::SearchInfo(int lineNum, char* caption, 
			   int* dims, enum_type_data** usedTypes) {
  enum_type_data *thisType, *localTypes[128];
  int dimCount, usedCount, iType;
  node_data_line* bottomLine;

  /* botch: when getting info on a new separate submodel, we don't
     want references to enumerated types in parent models to crash it,
     so fill the array with null types */
  for (usedCount=0; usedCount<128; ++usedCount) {
    localTypes[usedCount]=&noType;
  }	
  make_full_caption(lineNum, caption, dims, localTypes);
  usedCount=dimCount=0;
    while (dims[dimCount]) {
//      sprintf(globMess, "dim %d is %d", dimCount, dims[dimCount]);
//      showMess(globMess);
      if (dims[dimCount] <= ENUM_BASE) {
	thisType = localTypes[ENUM_BASE-dims[dimCount]];
//	printf("chaining type %s\n", thisType->name);
	usedTypes[usedCount++] = thisType;
	dims[dimCount] = thisType->count;
      } else if (dims[dimCount] == FLAG) {
	usedTypes[usedCount++] = &boolDimType;
	dims[dimCount] = 2;
      } else if (dims[dimCount]==START_VM || 
		 dims[dimCount]==END_VM) {
      } else {
	usedTypes[usedCount++] = &noType;
      }
      ++dimCount;
    }
    bottomLine = nodedata + lineNum;
    if (bottomLine->datatype <= ENUM_BASE) {
      thisType = localTypes[ENUM_BASE-bottomLine->datatype];
//      sprintf(globMess, "type is %d, setting result %d to %s", 
//              bottomLine->datatype, usedCount, thisType->name);
//      showMess(globMess);
      usedTypes[usedCount++] = thisType;
    } else if (bottomLine->datatype == FLAG) {
      usedTypes[usedCount++] = &boolDataType;
    } else {
      usedTypes[usedCount++] = &noType;
    }
  // }
  usedTypes[usedCount] = NULL;
  return bottomLine;
}

/* translate_dims: this takes the dimensions of the node's data as
returned by the model, and converts them to those used in the data
structure. The main difference is that in the data structure, a
variable-membership model identifier is followed by its dimensionality
(1 for population models) while per-record submodels do not have this
extra value.

A parallel array is also passed which gets the size of the data block
needed at each level, making it quicker to fill the actual structure.

If we are making a structure for a file parameter, we re-use data
across instances of conditional and population models (we cannot cope
with changes in membership otherwise), so leave out level info for
these if skip_vms is set.
*/
void translate_dims(int fromModel[], int blockSizes[], int structDims[],
		    int dataType, BOOLEAN skip_vms) {
  int defDimty = 1; // will be used unchanged if case MEMBERS
  structDims[0] = OWNSIZED; // will not be set if case RECORDS
  switch (fromModel[0]) {
  case START_VM: // count dims to FINISH_VM and insert SPARSEARRAY of them
    defDimty = skip_vm_bounds(&fromModel);
  case MEMBERS: // or START_VM
    if (skip_vms) {
      translate_dims(fromModel+1, blockSizes, structDims, dataType, skip_vms);
      return;
    }
    structDims[0] = SPARSEARRAY;
    structDims[1] = defDimty;
    structDims += 1;
    // and drop through
  case RECORDS: // or  MEMBERS or START_VM
    blockSizes[0] = sizeof(sizeAndPtr);
    break;
  case 0: // dimensions finished, insert type and its size (could alloc dims!)
    structDims[0]  = dataType;
    blockSizes[0] = size_for_data_type(dataType);
    return;
  default: // an array dimension, or RECORDS
    structDims[0] = fromModel[0];
  }
  translate_dims(fromModel+1, blockSizes+1, structDims+1, dataType, skip_vms);
  // now set size if a multiple of the next one...
  if (fromModel[0]>0) 
    blockSizes[0] = blockSizes[1]*fromModel[0];
}

// Start of 5-D interface for straight-C clients

// function pointers for callbacks

interact_gui_type* fivedee_interact_gui;
get_value_pointer_type* fivedee_get_value_pointer;
showMess_type* fivedee_showMess;

// procedure that is called by shim when it is loaded to supply pointers
// to its callback procedures

void proc_pointers_for_shank(get_value_pointer_type* get_value_pointer_ptr,
			     interact_gui_type* interact_gui_ptr,
			     showMess_type* showMess_ptr) {
  fivedee_get_value_pointer = get_value_pointer_ptr;
  fivedee_interact_gui = interact_gui_ptr;
  fivedee_showMess = showMess_ptr;
}

// Derived class which instantiates the callback procedures to those supplied
// by proc_pointers_for_shank
class ModelFor5D: public ModelServer {
public:
  ModelFor5D(char* fileName, char** complaint):ModelServer(fileName, complaint)
  {
  }

  void get_value_pointer(void* ref, void* slot, double time,
				int paramId, int ic, int* indxs) {
    fivedee_get_value_pointer(ref, slot, time, paramId, ic, indxs);
  }

  BOOLEAN interact_gui(void* ref, int action, double modelTime) {
    fivedee_interact_gui(ref, action, modelTime);
  }
  
  void showMess(const char* toShow) {
    fivedee_showMess(toShow);
  }
}; // End of class ModelFor5D

// Now here are the procedures which a 5-D client (such as Simile) will call

// This one creates a new kind of model from the saved executable
char* load_model(char* fileName, char* nodeName, void** modelType) {
  ModelFor5D* newModel;
  char* complaint;

  newModel = new ModelFor5D(fileName, &complaint);
  if (complaint) {
    delete newModel; // will unload dll if one has been loaded
    return complaint;
  }
  *modelType = newModel;
  return NULL;
}

// create a model instance
void* fetch_top_instance(void* modelType, void* clientRef) {
  ExecutingModel* justMade;

  // 5-D callbacks have the client data set to the instance
  justMade = ((ModelFor5D*)modelType)->create(clientRef);
  return justMade;
}

// get metadata: deprecated as each attribute should be sought individually
node_data_line* searchinfo(char* node, void* tgtModel, char* caption, 
			   int* dims, enum_type_data** usedTypes) {
  int ghostLine;
  node_data_line* bottomLine;
  char localCapt[255];

  int lineNum = ((ModelFor5D*)tgtModel)->getinfo(node, &ghostLine);
  if (lineNum == -1) return NULL;
  if (ghostLine>-1) {
    ((ModelFor5D*)tgtModel)->make_full_caption(ghostLine, caption, 
					       dims, usedTypes);
  }
  bottomLine = ((ModelFor5D*)tgtModel)->SearchInfo(lineNum, localCapt, 
						dims, usedTypes);
  if (ghostLine>-1) { // append base tail to ghost submodel caption
    strcat(caption, "/");
    strcat(caption, bottomLine->strings[0]);
  } else
    strcpy(caption, localCapt);
  return bottomLine;
}

/* utility procedures for accessing model data */

int get_node_count(void* type) {
  return ((ModelFor5D*)type)->nodecount;
}

node_data_line* get_data_line(void* type, int line) {
  return &((ModelFor5D*)type)->nodedata[line];
}

graph_data_type** get_graph_base(void* type) {
  return &((ModelFor5D*)type)->c_graphdata;
}

// get a node data line from the 'graph' number of the node
node_data_line* nodlin_from_id(void* modelId, int paramId) {
  return ((ModelFor5D*)modelId)->md_nodlin_from_id(paramId);
}

// setstep: the model class instances contain an array of doubles called
// dts representing the time steps at the various phases. This function reaches
// in and sets one of them. Returns phase count. Node that ts[0] is set to
// the integration step being done: 0 for Euler, 1-4 for the four stages of RK

int setstep(void* instId, double starttime, int phase) {
  return ((ExecutingModel*)instId)->SetStep(phase, starttime);
}

/* filling a structure of this type is going to be a straight copy of the Tcl
   list builder in the shim, cos it's the easiest way to think through it */

nodeValues* get_raw_values(char* nodeId, void* instance_id) {
  int nodeNum, spareNum;

  nodeNum = ((ExecutingModel*)instance_id)->modelSpec->getinfo(nodeId, 
							       &spareNum);
  if (nodeNum==-1)
    return NULL;
  return ((ExecutingModel*)instance_id)->GetRawValues(nodeNum);
}

excpData* reset(void* modelType, void* modelHandle, int how_int,
		int top_phase) {
  return ((ExecutingModel*)modelHandle)->ResetInstance(how_int, top_phase);
}

excpData* execute(void* modelType, void* modelHandle, int how_int,
	 double starttime, double* endtime, double errlim) {
  return ((ExecutingModel*)modelHandle)->ExecuteInstance(how_int, starttime, 
							 endtime, errlim);
}

// This deletes a model instance and/or a class -- both when used in Simile
char* myexit(void* modelType, void* modelHandle) {  
  if (modelHandle) { 
    delete (ExecutingModel*)modelHandle;
  }
  if (modelType) { 
    delete (ModelFor5D*)modelType;
  }
  return NULL; // message displayed in destructor cos it is not allowed
  // to have params or retval
}

char* getNodeId(void* modelType, char* capt) {
  ModelServer* tgtModel;
  int tgtIndex;

  tgtIndex = nodeModelAndId((ModelFor5D*)modelType, capt, &tgtModel);
  if (tgtIndex != -1) {
    return tgtModel->nodedata[tgtIndex].name;
  } else {
    return NULL;
  }
}
