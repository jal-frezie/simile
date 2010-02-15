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

    #define HINSTANCE void*
    #define LOAD_DLL flopen
/* 'dummyunload' clause was used with macos because dlcompat didn't include
 * unload, but using -bundle instead of -dynamiclib to build the model seems to
 * make dlcompat, and dummyunload, unnecessary. Indeed it allows model
 * crosstalk on Intel macs, so is now never used.
 */
#ifdef SIM_OPSYS_Darwin
#define UNLOAD_DLL dummyunload
int dummyunload(HINSTANCE unused) {
  return(1);
}
#else
    #define UNLOAD_DLL !dlclose
/* dlclose inverted cos it seems to return NULL when it works */
#endif
    #define WHAT_WENT_WRONG (char*)dlerror
    #define FIND_FUNCTION dlsym
/* sig handler cos 64bit gcc code sigfpe's on 32bit machine */
jmp_buf env;

static void exit_sighandler(int x){
  longjmp(env, x);
}

HINSTANCE flopen(char* fileName) {
  int error;

  signal(SIGFPE,exit_sighandler);
  error = setjmp(env);
  if (error) {
    return 0;
  } else {
    return dlopen(fileName, RTLD_NOW);
  }
}

/*
 * Unix version: does not have min & max defined
 */
int min(int a, int b) {
  return a<b?a:b;
}
int max(int a, int b) {
  return a>b?a:b;
}

#endif

/* Definitions used in this code and the model code */
#include <dllcalls.h>

interact_gui_type* interact_gui;
get_value_pointer_type* get_client_value_pointer;
/*fetch_instance_type fetch_instance;
update_submodel_type update_submodel;
advance_submodel_type advance_submodel;
eval_submodel_type eval_submodel;
search_from_type search_from;
advance_ptr_type advance_ptr;
get_remote_value_type get_remote_value;
*/
stat_check_type stat_check;

char* xsimileVersion;
showMess_type* showMessLocal;
char globMess[256];

/* values for keeping track of GUI interaction and execution times */
int last_op = 0;
unsigned long int last_exit = 0, last_update = 0, last_check = 0;
unsigned long int flash=CLOCKS_PER_SEC/25; // 40ms
unsigned long int took[]={0,0,0,0,0,0,0,0};
long int topType;
int resetting;

BOOLEAN check_gui(void* id, double model_time, int this_op) {
  unsigned long int this_update;
  long int while_running;
  BOOLEAN result = FALSE;
  int while_resetting;

  // first record how much time the last op took
  this_update=clock();
  took[last_op]=this_update-last_exit;
  
  if ((this_update-last_update)+took[this_op]>flash) {
    while_running = topType;
    while_resetting = resetting;
    result=interact_gui(id, 1+!this_op, model_time);
    topType = while_running;
    resetting = while_resetting;
    this_update=clock(); // GUI may have taken time
    last_update=last_check=this_update;
  }

  last_op = this_op;
  last_exit=this_update;
  return result;
}

// check for abort (and do non-intrusive gui action). Do not do this if the
// time point borders are happening frequently.

int stat_check(void* id) {
  unsigned long int this_update;
  BOOLEAN result;

  this_update=clock();
  if (this_update-last_check>2*flash) {
    result=interact_gui(id, 0, 0);
    this_update=clock(); // GUI may have taken time
    last_check=this_update;
  } else {
    result=FALSE;
  }
  return result;
}

void showMess(char* mess) {
  (*showMessLocal)(mess);
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

/* listable class for data to be loaded at a time point This contains
   data in a char*, rather than a nodeValue structure, because the
   dimSpecs are the same for all the time points of a parameter. */

class listTimePoint {
public:
  double when;
  BOOLEAN myArraySpace;
  char* dataPtr;
  listTimePoint *last, *next;

  listTimePoint() {
    myArraySpace = FALSE;
    dataPtr = NULL;
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

/* listable class for keeping track of arrays associated with parameters */

class listParamArray {
public:
  char* nodeId;
  node_data_line *nodeLine;
  long int spareModel;
  nodeValues dataPtr;
  listTimePoint* timePoints;
  listTimePoint* finalTimePoint;
  listTimePoint* curTimePoint;
  double wrapAroundPoint;
  int wraps;
  int fillMethod;
  listParamArray* next;

  int size_for_type() {
    /*    if (nodeLine->compclass == SUBMODEL)
      return sizeof(int); // keeps count of per-record type
    */ return size_for_data_type(nodeLine->datatype);
  }

  listParamArray(char* newNodeId) {
    int fullDims[32], sparePath[32];
    char spareCapt[255];
    enum_type_data *spareTypes[32]; // might need for reading files

    nodeId = strdup(newNodeId);
    nodeLine = searchinfo(nodeId, &spareModel, spareCapt, fullDims, sparePath,
			  spareTypes);
    translate_dims(fullDims, sparePath, dataPtr.dimSpecs, nodeLine->datatype, 
		   TRUE);
    dataPtr.contents = init_space(dataPtr.dimSpecs);
    //    dataPtr.contents = new char[sparePath[0]];
    timePoints = NULL;
    finalTimePoint = NULL;
    curTimePoint = NULL;
    fillMethod = USE_LAST;
    next = NULL;
  }      

  ~listParamArray() {
    int size, count;
    char* innerSp;
    
    delete(nodeId);
    while (timePoints) {
      curTimePoint = timePoints;
      timePoints = curTimePoint->next;
      free_bloc_data(curTimePoint->dataPtr, dataPtr.dimSpecs);
      delete(curTimePoint);
    }
    free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
  }
  
  listParamArray* strip_out(long int oldModelId) {
    listParamArray* current;

    if (next) {
      next = next->strip_out(oldModelId);
    }
    if (spareModel == oldModelId) { // node belongs to model being removed
      current = next;
      delete(this);
      return current;
    } else {
      return this;
    }
  }

  int space_used() {
    int *base;
    // hope it evaluates left to right
    return array_count(dataPtr.dimSpecs, &base)*size_for_data_type(*base);
  }

  char* create_time_point(double time) {
    listTimePoint *lastTimePt, *thisTimePt, *nextTimePt;
    if (timePoints && timePoints->when<=time) {
      lastTimePt = timePoints->find_last_pt(time);
      if (lastTimePt->when==time) {
	thisTimePt = lastTimePt;
      } else { // lastTimePt is earlier than new one
	nextTimePt = lastTimePt->next;
	thisTimePt = new listTimePoint;
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
      thisTimePt = new listTimePoint;
      thisTimePt->next = timePoints;
      if (timePoints) {
	timePoints->last = thisTimePt;
      } else {
	finalTimePoint  = thisTimePt;
      }
      thisTimePt->last = NULL;
      timePoints = thisTimePt;
    }
    thisTimePt->when = time;

    thisTimePt->dataPtr = init_space(dataPtr.dimSpecs);
  }

  char* time_point_exists (double time) {
    listTimePoint* timePt;

    if (timePoints) {
      if ((timePt = timePoints->find_last_pt(time))->when==time)
	return timePt->dataPtr;
    }
    return NULL;
  }

  listTimePoint *roll_forward(listTimePoint *bound, int *newWraps) {
    bound = bound->next;
    if (!bound && wrapAroundPoint>0.0) {
      *newWraps = wraps+1;
      bound = timePoints;
    } else
      *newWraps = wraps;
    return bound;
  }

  void update_from_points(BOOLEAN dir, double now) {
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
      if (fillMethod==INTERPOLATE && nodeLine->datatype != FLAG) {
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
    }
  }

  /* These last three are actually called by the model code to get data */

  void back_copy_vars(long int modelClass, long int modelInstance) {
    nodeValues* fromModel;

    if (spareModel==modelClass && nodeLine->eval == INPUT &&
	!time_point_exists(0.0)) {
      free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
      fromModel = get_raw_values(nodeId, modelInstance);
      dataPtr.contents = fromModel->contents;
      // sprintf(globMess, "dims %d %d backcopied %d records 1st %lf", 
	      // dataPtr.dimSpecs[0], dataPtr.dimSpecs[1], ((sizeAndPtr*)dataPtr.contents)->size,
	      // *(double*)(((sizeAndPtr*)dataPtr.contents)->ptr));
      // showMess(globMess);
      delete fromModel;
    }
  }

  void extract_elt(void* tgt, int* indxs) {
    // do not do it if this is a variable parameter and we are initializing --
    // array not yet set so let model keep default value...in fact, save it in
    // the array for later
    void* insertionPt;
    
    insertionPt = locate_elt(dataPtr.contents, 0, dataPtr.dimSpecs, indxs);
    if (!insertionPt) return; // record pointers not yet made
    if (nodeLine->eval==INPUT && resetting<-1 && !(time_point_exists(0.0))) {
      // back copy now done in blocks afterwards to make record spaces
      // memcpy(insertionPt, tgt, size_for_type());
    } else {
      // sprintf(globMess, "Gonna copy %d from %ld to %ld", size_for_type(),
// 	      (long int)insertionPt, (long int)tgt);
      // showMess(globMess);
      memcpy(tgt, insertionPt, size_for_type());
    }
  }

  void extract_record_count(void* tgt, int ic, int* indxs) {
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
};   // end of listParamArray class

listParamArray* param_array_base = NULL;

class Model;

void update_time_series(Model* client, double now);
  
void reset_time_series(Model* client);

typedef struct channelRecord_t {
  void* SearchBase;
  int* UpTree;
} channelRecord;

void setdt(double, int);

/* Matching set of declarations for the pointers by which we will access
   these functions locally */

class Model {
  HINSTANCE handle;
  int count, count2, count3;
/*  int inArcCount;
  char** inArcList; */
  //  enum_data_type *enumtypedata;

  getcount_type *getcount;
  getversion_type *getversion;
  createmodel_type *createmodel;

public:
  updatemodel_type *updatemodel;
//  advancemodel_type *advancemodel;
  evalmodel_type *evalmodel;
  getpointer_type *getpointer;
  setstep_type *setstepmodel;
  exitmodel_type *exitmodel;

  int phases;
  /* Time series info exists only for each model class, so thisTsPosn
     remembers for what time the series have been set up, so we know
     what to do when setting them up for a different instance which
     may be at a different time */
  double lts[8], ldts[8], steps[8], thisTsPosn;
  graph_data_type* c_graphdata;
  int nodecount;
  node_data_line* nodedata;
  int *connLines;
  // channelRecord* channelData; only used in top model
  double* adapt_maxerr;
  excpData* userDefStop; // set by stop function in model
  char erreur[256];

  Model(char* fileName) {
    handle = LOAD_DLL(fileName);
    if (handle == NULL) {
      throw DllLossage("load", fileName, WHAT_WENT_WRONG());
    }
    getversion = (getversion_type *)FIND_FUNCTION(handle, "get_version");
    if (getversion == NULL) {
      UNLOAD_DLL(handle);
      throw DllLossage("get version number of", fileName, WHAT_WENT_WRONG());
    }
    if (fabs((*getversion)()-atof(xsimileVersion))>0.00001) {
      UNLOAD_DLL(handle);
      throw DllLossage("find current version of", fileName, WHAT_WENT_WRONG());
    }
/* sprintf(globMess, "Loaded %ld", handle);
showMess(globMess); */

    getcount = (getcount_type *)FIND_FUNCTION(handle, "get_count");
    createmodel = (createmodel_type *)FIND_FUNCTION(handle, "do_createmodel");
    updatemodel = (updatemodel_type *)FIND_FUNCTION(handle, "do_updatemodel");
//    advancemodel = (advancemodel_type *)FIND_FUNCTION(handle, 
//						      "do_advancemodel");
    evalmodel = (evalmodel_type *)FIND_FUNCTION(handle, "do_evalmodel");
    setstepmodel = (setstep_type *)FIND_FUNCTION(handle, "do_setstep");
    getpointer = (getpointer_type *)FIND_FUNCTION(handle, "burrow_to");
    exitmodel = (exitmodel_type *)FIND_FUNCTION(handle, "do_exitmodel");

    nodecount = (*getcount)(this, 
			    (void*)ame_rand, 
			    (void*)graphpoint,
			    (void*)release_graph_data, 
			    (void*)compare_instance_status, 
			    (void*)get_value_pointer, 
/*			    (void*)fetch_instance,
			    (void*)update_submodel,
			    (void*)advance_submodel,
			    (void*)eval_submodel,
			    (void*)search_from,
			    (void*)advance_ptr,
			    (void*)get_remote_value,
*/			    (void*)stat_check,
			    (void*)showMess,
			    (void*)&c_graphdata,
			    &phases, &nodedata, &adapt_maxerr, &userDefStop);
  }

  ~Model() {
    if (!UNLOAD_DLL(handle)) {
      throw DllLossage("unload", (char*)"", WHAT_WENT_WRONG());
    }
    // if (channelData) delete channelData;
  }

  /* Next bit is really boring...and possibly needles...but I feel I have to
     make class procedures for the things loaded from the model dll rather than
     trying to refer to procedure variables in the model class directly */

  void* create() {
    c_graphdata = NULL; // this will be filled when initializing new instance
    return (*createmodel)();
  }

  /* 
  Now for the locally defined model class procedures 

  Following can go anyway if new ones outside the model class work

  void update(void* id, double start, int phase) {
    (*updatemodel)(id, start, phase);
  }

  void advance(void* id, double start, int phase) {
    (*advancemodel)(id, start, phase);
  }

  int eval(void* id, double start, int phase, BOOLEAN exo) {
    return (*evalmodel)(id, start, phase, exo);
  }

  int setstep(double start, int phase) {
    return (*setstepmodel)(start, phase);
  }

  void* get_ptr(void* level, int** id_meta, int** dim_list) {
    return (*getpointer)(level, id_meta, dim_list);
  }

  void exit(void* id) {
    (*exitmodel)(id);
  }
*/
  int adapt_doublings;

  excpData* resetmodel(void* modelHandle, int how_int, int top_phase) {
    int tweak_phase, err;
    
    userDefStop->excpNo = 0;
    if (top_phase<=0) {
      for (tweak_phase=1; tweak_phase <= 7; tweak_phase++) {
	lts[tweak_phase]=0;
	setdt(0, -tweak_phase);
	setdt(steps[tweak_phase], tweak_phase);
      }
      switch (how_int) {
      case EULER:
	setdt(0,0);
	break;
      case RUNGE_KUTTA:
	setdt(1,0);
      } // was -1,0 to stop loss, but now we want it cos it happens next step
      reset_time_series(this);
      adapt_doublings = 0;
    }
    err=(*evalmodel)(modelHandle, top_phase);
    if (err)
      userDefStop->excpNo = err;
//    else
//      (*advancemodel)(modelHandle, top_phase);
    if (userDefStop->excpNo)
      return userDefStop;
    return NULL;
  }

  excpData* executemodel(void* id, int how_int, 
		   double start, double* end, double errlim) {
    double freq, xtime;
    int big_phase, err;
    BOOLEAN made_step, first_pass;
    // sprintf(globMess, "xm %d %lf-%lf at %lf", how_int, start, *end, errlim);
    // showMess(globMess);
    userDefStop->excpNo = 0;
    freq = steps[phases]*pow(2,-adapt_doublings);
    xtime = start;
    while (freq*(*end-xtime)>0) { // freq only affects sign
      made_step = 0;
      first_pass = 1;
      big_phase = phase_for(xtime, freq, phases);
      // that is the biggest phase we will try to run, we may not succeed
      if (check_gui(id, xtime, big_phase)) {
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
	    setdt(0,0);
	  } else {
	    setdt(-1,0);
	  }
	  advance_time(this, big_phase, 1);
	  (*updatemodel)(id, big_phase);
	  break;
	case RUNGE_KUTTA:
	  if (first_pass) {
	    setdt(1,0);
	  } else {
	    setdt(-2,0);
	  }
	  (*updatemodel)(id, big_phase);
	  userDefStop->excpNo=rk_update(id);
	  break;
	}
	if (userDefStop->excpNo) break; // from inner loop
	first_pass = 0;
	if (!errlim) {
	  made_step = 1;
	} else {
	  if (userDefStop->excpNo=(*evalmodel)(id, phases+1)) break;
	  // from inner loop

	  // get the model to generate its error estimate
	  *adapt_maxerr = 0;
	  setdt(10, 0);
	  (*updatemodel)(id, big_phase);
	  if (*adapt_maxerr>errlim) {
	    // error too great; put comps back and try shorter
	    if (adapt_doublings<31) {
	      advance_time(this, big_phase, -1); // back to start
	      xtime-=freq;
	      adapt_doublings++;
	      freq = steps[phases]*pow(2,-adapt_doublings);
	      big_phase = phase_for(xtime, freq, phases);
	    } else {
	      // signal problem
	      userDefStop->excpNo = -99;
	      break;
	    }
	  } else {
	    made_step = 1;
	    if (adapt_doublings && *adapt_maxerr<errlim/16) {
	      // low error; try longer next time if poss
	      adapt_doublings--;
	      freq = steps[phases]*pow(2,-adapt_doublings);
	    } // lengthen time step
	  } // timestep too short or not
	} // error limit exists
      } // made progress
      if (userDefStop->excpNo) break; // from outer loop
      if (userDefStop->excpNo=(*evalmodel)(id, big_phase)) break;
//      (*advancemodel)(id, big_phase);
    }
    if (check_gui(id, *end, 0) && !userDefStop->excpNo)
      // always go to make sure time is right
      userDefStop->excpNo = -100;
    *end=xtime;
    if (userDefStop->excpNo)
      return userDefStop;
    return NULL;
  }
  
  int phase_for(double current, double step, int so_far) {
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

  int rk_update(void* id) {
    int wee_phase, err;

    wee_phase=phases+1;
    advance_time(this, phases, 0.5);
    setdt(2, 0);
    if (err=(*evalmodel)(id, wee_phase)) return err;
    (*updatemodel)(id, phases);
    setdt(3, 0);
    if (err=(*evalmodel)(id, wee_phase)) return err;
    (*updatemodel)(id, phases);
    advance_time(this, phases, 0.5);
    setdt(4, 0);
    if (err=(*evalmodel)(id, wee_phase)) return err;
    (*updatemodel)(id, phases);
    setdt(1, 0);
    return 0;
  }

  void set_dts (int phase, double current) {
    int tweak_phase;
    for (tweak_phase=phase; tweak_phase<=phases; tweak_phase++) {
      ldts[tweak_phase]=current-lts[tweak_phase];
      setdt(ldts[tweak_phase],tweak_phase); 
      // dts should only be global but im lazy
    }
  }
  
  void advance_time (Model* client, int phase, double fraction) {
    int tweak_phase;
    double series_pt;

    // series_pt = lts[phases]+ldts[phases]*fraction/2; 
    // load values for middle of interval as they apply throughout it...no
    for (tweak_phase=phase; tweak_phase<=phases; tweak_phase++) {
      lts[tweak_phase]=lts[tweak_phase]+ldts[tweak_phase]*fraction;
      setdt(lts[tweak_phase],-tweak_phase); 
      // ts should only be global but im lazy
    }
    // time value is chosen to work with RK so series pt should do the same
    series_pt = lts[phases];
    update_time_series(this, series_pt);
    client->thisTsPosn = series_pt;
  }
  
  int parent_line (int line) {
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
      
  int make_full_caption(int line, char *result, int* dims,
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
  int getinfo(char* node_id) {
    int count;
    for (count=1;nodecount>count;++count) {
      if (!strcmp(node_id, nodedata[count].name)) { 
      return count;
      }
    }
    return -1;
  }
} /* end of class Model */ ;

/* listable class for submodel data -- allows us to find model id from node id
 */
class listNodeModel {
public:
  char* node;
  Model* model;
  listNodeModel* next;

  listNodeModel(char* newNode, Model* newModel, listNodeModel* prev) {
    node = strdup(newNode);
    model = newModel;
    next = prev;
  }

  ~listNodeModel() {
    delete(node);
    delete(model);
  }
      
  Model* nodeModel(char* seekNode) {
    if (!strcmp(node, seekNode)) {

      return(model);
    } else if (next) {
      return(next->nodeModel(seekNode));
    } else {
      return NULL;
    }
  }

  listNodeModel* strip_out(Model* oldModelId) {
    int count;
    listNodeModel* current;

    if (next) {
      next = next->strip_out(oldModelId);
    }
    if (model == oldModelId) { // node belongs to model being removed
      /* delete any separate submodels in here (old)
      for (count=0; count<model->nodecount;count++) {
	if ((model->nodedata[count]).datatype==EXTERNAL) {
	  strip_out(nodeModel((model->nodedata[count]).name));
	}
	} */
      current = next;
      delete(this);
      return current;
    } else {
      return this;
    }
  }
}; // end of class listNodeModel

listNodeModel* nodeModelList = NULL;

/* listable class for enumerated types, similar to above
class listEnumTypes {
public:
  enum_type_data* enumTypePtr;
  listEnumTypes* next;

  listEnumTypes(enum_type_data* newType, listEnumTypes* prev) {
    enumTypePtr = newType;
    next = prev;
  }

  ~listEnumTypes() {
    if (next) {
      delete(next);
    }
  }
  }; */

void update_time_series(Model* client, double now) {
  listParamArray* param_array_current;
  BOOLEAN forward;

  param_array_current = param_array_base;
  forward = (now >= client->thisTsPosn);
  client->thisTsPosn = now;
  while (param_array_current) {
    if (param_array_current->spareModel == (long int)client) {
      param_array_current->update_from_points(forward, now);
    }
    param_array_current = param_array_current->next;
  }
}    
  
void reset_time_series(Model* client) {
  listParamArray* param_array_current;

  param_array_current = param_array_base;
  client->thisTsPosn = 0;
  while (param_array_current) {
    if (param_array_current->spareModel == (long int)client) {
      param_array_current->curTimePoint = NULL;
      param_array_current->wraps = 0;
      param_array_current->update_from_points(TRUE, 0);
    }
    param_array_current = param_array_current->next;
  }
}

listParamArray* param_array_item(listParamArray* start, char* seekNodeId) {
  if (!start) {
    return NULL;
  } else if (!strcmp(start->nodeId, seekNodeId)) {
    return start;
  } else {
    return param_array_item(start->next, seekNodeId);
  }
}

void* use_array_for_params(char* nodeId) {
  listParamArray* arrSlot;

  /* sprintf(globMess, "use_array_for_params node %s",
	  nodeId);
	  showMess(globMess); */
  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    arrSlot = new listParamArray(nodeId);
    if (!arrSlot->nodeLine) {
      delete arrSlot;
      return NULL;
    }
    arrSlot->next = param_array_base;
    param_array_base = arrSlot;
  }

  return arrSlot->dataPtr.contents;
}

int param_array_size(char* nodeId) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) return 0;
  return arrSlot->space_used();
}

int clear_time_point_elts(char* nodeId) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return 1; // no data structure for this elt
  }
  delete arrSlot->timePoints;
  arrSlot->timePoints = NULL;
  arrSlot->finalTimePoint = NULL;
  arrSlot->curTimePoint = NULL;
}

double* get_wrap_ptr(char* nodeId) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return NULL; // no data structure for this elt
  }
  return &arrSlot->wrapAroundPoint;
}

int* get_fill_ptr(char* nodeId) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return NULL; // no data structure for this elt
  }
  return &arrSlot->fillMethod;
}

int create_time_point(char* nodeId, double time) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return 1; // no data structure for this elt
  }
  arrSlot->create_time_point(time);
  return 0;
}

void* find_next_timept_space(char* nodeId, double* last_time) {
  listParamArray* arrSlot;
  listTimePoint* seek;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return NULL; // no data structure for this elt
  }
  seek = arrSlot->timePoints;
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
}

char* get_param_ptr_and_dims(char* nodeId, int** dimSlot) {
  listParamArray* arrSlot;
  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return NULL; // no data structure for this elt
  }

  *dimSlot = arrSlot->dataPtr.dimSpecs;
  return arrSlot->dataPtr.contents;
}

int get_timepoint_ptr_and_dims(char* nodeId, double time, 
				 char** ptDataSlot, int** dimSlot) {
  listParamArray* arrSlot;
  char* ptData;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return 2; // no data structure for this elt
  }
  ptData = arrSlot->time_point_exists(time);
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

int member_param_item(listParamArray** start, void* modelId, int* parentPath) {
  if (!*start)
    return 0; // no children found
  else if ((*start)->spareModel==(long int)modelId && // in right model
	   (*start)->nodeLine->eval == TABLE) { // and fixed, is child?
    int count = -1;
    while (parentPath[++count])
      if (((*start)->nodeLine)->path[count] != parentPath[count])
	break; // found difference
    if (!parentPath[count]) // got to end without difference, result!
      return 2;
  }
  *start = (*start)->next;
  return  member_param_item(start, modelId, parentPath); // keep looking
}

node_data_line* md_nodlin_from_id(Model* modelId, int paramId) {
    int count;
    node_data_line *nodeLine;
    for (count=0; count<modelId->nodecount; ++count) {
      nodeLine = modelId->nodedata + count;
      if (nodeLine->graph==paramId) return nodeLine;
    }
    return NULL;
}

node_data_line* nodlin_from_id(long int modelId, int paramId) {
  return md_nodlin_from_id((Model*)modelId, paramId);
}

int param_item_from_id(listParamArray** start, Model* modelId,
				   int paramId) {
  if (!*start) {
    // couldn't find id, try to find a member parameter
    // first get its nodeline
    node_data_line *nodeLine;
    nodeLine = md_nodlin_from_id(modelId, paramId);
    *start = param_array_base;
    return member_param_item(start, modelId, nodeLine->path);
  } else if ((*start)->spareModel==(long int)modelId && 
	     ((*start)->nodeLine)->graph==paramId) {
    return 1;
  } else {
    *start = (*start)->next;
    return param_item_from_id(start, modelId, paramId);
  }
}
 
void get_value_pointer(void* modelId, void* modelSlot, int paramId,
		       int ic, int* indxs) {
  listParamArray* paramArrayItem;

  //sprintf(globMess, "get_value_pointer for %ld node %d count %d indx0 %d indx1 %d", (long)modelSlot, paramId, ic, indxs[0], indxs[1]);
  //showMessLocal(globMess);
  paramArrayItem = param_array_base;
  switch (param_item_from_id(&paramArrayItem, (Model*)modelId, paramId)) {
  case 1:
    paramArrayItem->extract_elt(modelSlot, indxs);
    break;
  case 2: // found a parameter inside this submodel, get record count
    paramArrayItem->extract_record_count(modelSlot, ic, indxs);
    break;
  default:
    get_client_value_pointer(modelId, modelSlot, paramId, ic, indxs);
  }
  // sprintf(globMess, "Think we got %d (%lf)", *(int*)modelSlot, *(double*)modelSlot);
  // showMessLocal(globMess);

}

char* load_model(char* fileName, char* nodeName, long int* modelType) {
  Model* newModel;
  try {
    newModel = new Model(fileName);
  } catch(DllLossage prang) {
    return prang.tell();
  }
  nodeModelList = new listNodeModel(nodeName, newModel, nodeModelList);

  *modelType = (long int)newModel;
  return NULL;
}

/* utility procedures for accessing model data */

int get_node_count(long int type) {
  return ((Model*)type)->nodecount;
}

node_data_line* get_data_line(long int type, int line) {
  return &((Model*)type)->nodedata[line];
}

long int get_node_model_id(char* find) {
  return (long int)nodeModelList->nodeModel(find);
}

graph_data_type** get_graph_base(long int type) {
  return &((Model*)type)->c_graphdata;
}

/* This finds node ids from captions globally. It runs through a model
comparing each caption with what we are after, and as well as returning if
it finds it, it continues inside any separate submodel it comes across whose
caption fits the start of what we are after (after trimming the portion found
from the search string, less the submodel itself -- note it may be an issue
that the submodel name is searched for in both models ) */

int nodeModelAndId(Model* seekType, char* seeknode, Model** tgtModel) {
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
    } /* separate submodels no longer in use
    if (seekType->nodedata[count].datatype == EXTERNAL) {
      if (!strncmp(seeknode, test, strlen(test))) {
	return(nodeModelAndId(nodeModelList->nodeModel(seekType->
						       nodedata[count].name),
			      seeknode + strlen(test), // was (strrchr(test, '/') - test),
			      tgtModel));
      }
      
    } */
  }
  /* Node with given caption not found... */
  return -1;
}

/* global version of getinfo, uses the list defined above to search through all
   current models to find given node, and combine their extraction data

   Needs a new node_data_line, to which it is passed a ptr. Returns 0 if
   fails to find path. 

   This is very ugly -- it should return a lot of NULLs if called with the
   top node, and otherwise call itself recursively before getting the local
   data, thus allowing it to pass pointers to current positions along the
   result arrays to make_full_caption. Well that's stepwise refinement...
*/

node_data_line* search_intnl(char* node, long int* tgtModel, char* caption, 
			   int* dims, int* path, enum_type_data** usedTypes) {
  listNodeModel* searchPoint = nodeModelList;
  Model* tryModel;
  node_data_line *bottomLine;
  char localCapt[256];
  int localDims[32], dimCount;
  int line, typeCount, typeIdx;

  while (searchPoint) {
//    sprintf(globMess, "seeking %s in %s", node, searchPoint->node);
//    showMess(globMess);
    tryModel = searchPoint->model;
    if (!strcmp(node,searchPoint->node)) line=0;
    else line=tryModel->getinfo(node);
    if (line>-1) {
      bottomLine = tryModel->nodedata + line;
      typeCount = tryModel->make_full_caption(line, localCapt, 
					      localDims, usedTypes);
      if (line) {
	if (!search_intnl(searchPoint->node, tgtModel, caption,
		       dims, path, usedTypes + typeCount)) {
	  return NULL;
	}
      } else {
	*tgtModel = (long int)tryModel;
      }

      /* Case for a separate submodel below toplevel: no longer used as of v5
	 (also breaks 64bit build)
      if (*tgtModel!=(long int)tryModel) {
	// correct higher ET references for those added at this level
	dimCount = 0;
	while (dims[dimCount]) {
	  if (dims[dimCount] <= ENUM_BASE) {
	    dims[dimCount] = dims[dimCount]-typeCount;
	  }
	  ++dimCount;
	}

	append_ints_to_null(dims, localDims, SEPARATE, 0);
	append_ints_to_null(path, bottomLine->path, SEPARATE, 
			    (int)searchPoint->model);
			    } else { */
	*dims = *path = 0;
	append_ints_to_null(dims, localDims, 0, 0);
	append_ints_to_null(path, bottomLine->path, 0, 0);
	*caption = 0;
	/*      } 
End removed separate submodel case */
      strcpy(caption + strlen(caption), localCapt);

      /* Old version with only one model hierarchy...
      if (searchPoint == nodeModelList) {
	strcpy(caption, localCapt);
	*dims = *path = 0;
	*usedTypes = NULL;
	append_ints_to_null(dims, localDims, 0, 0);
	append_ints_to_null(path, bottomLine->path, 0, 0);
	append_ptrs_to_null(usedTypes, localUsed);
      } else if (searchinfo(searchPoint->node, tgtModel, caption,
			    dims, path, usedTypes)) {
	append_ints_to_null(dims, localDims, SEPARATE, 0);
	append_ints_to_null(path, bottomLine->path, SEPARATE, 
			    (int)searchPoint->model);
	append_ptrs_to_null(usedTypes, localUsed);
	strcpy(caption + strlen(caption), // was strrchr(caption, '/'),
	       localCapt);
      } else {
	bottomLine = NULL;
      }
      */
      *tgtModel = (long int)tryModel;
      return(bottomLine);
    }
    searchPoint = searchPoint->next;
  }
  return(NULL);
}

char *falseTxt = (char*)"false";
char *trueTxt = (char*)"true";
char *booleanMems[2] = {falseTxt, trueTxt};
enum_type_data noType = {0, NULL, NULL}, 
  boolDataType = {1, falseTxt, &trueTxt},
  boolDimType = {2, "boolean", (char**)booleanMems};

node_data_line* searchinfo(char* node, long int* tgtModel, char* caption, 
			   int* dims, int* path, enum_type_data** usedTypes) {
  node_data_line *bottomLine;
  enum_type_data *thisType, *localTypes[128];
  int dimCount = 0, usedCount = 0;

  /* botch: when getting info on a new separate submodel, we don't
     want references to enumerated types in parent models to crash it,
     so fill the array with null types */
  for (usedCount=0; usedCount<128; ++usedCount) {
    localTypes[usedCount]=&noType;
  }
  usedCount=0;
	
  bottomLine = search_intnl(node, tgtModel, caption, dims, path, localTypes);
  if (bottomLine) {
    while (dims[dimCount]) {
      //    sprintf(globMess, "dim %d is %d", dimCount, dims[dimCount]);
      //    showMess(globMess);
      if (dims[dimCount] <= ENUM_BASE) {
	thisType = localTypes[ENUM_BASE-dims[dimCount]];
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
    if (bottomLine->datatype <= ENUM_BASE) {
      thisType = localTypes[ENUM_BASE-bottomLine->datatype];
      //    sprintf(globMess, "type is %d, setting result %d to %s", 
      //        datatype, usedCount, thisType->name);
      //    showMess(globMess);
      usedTypes[usedCount++] = thisType;
    } else if (bottomLine->datatype == FLAG) {
      usedTypes[usedCount++] = &boolDataType;
    } else {
      usedTypes[usedCount++] = &noType;
    }
  }
  usedTypes[usedCount] = NULL;
  return bottomLine;
}

long int fetch_top_instance(long int modelType) {
   return (long int)((Model*)modelType)->create();
}

void* get_ptr(long int modelType, long int level, int** id_meta, 
	      int** dim_list) {
  return ((Model*)modelType)->getpointer((void*)level, id_meta, dim_list);
}

long int step_ptr(long int type, long int ptr) {
  int next_handle[] = {1,0}, dimDum[] = {0}, *idler1, *idler2;

  idler1 = next_handle;
  idler2 = dimDum; // dummy dim needed to survive member count retreival test
  return *(long int*)(get_ptr(type, ptr, &idler1, &idler2));
}

int count_members(long int type, long int ptr) {
  // do not recurse, there may be too many of them
  int count = 0;
  while(ptr) {
    ptr = step_ptr(type, ptr);
    ++count;
  }
  return count;
}

// put indices of current instance onto data blk
void fill_indices(long int localType, long int smHandle,
		  int indxCount, char** insertionPt) {
  int idHandle[] = {2,0}, idIdx[1], *idler1, *idler2;

  for (idIdx[0] = 0; idIdx[0]<indxCount; ++idIdx[0]) {
    idler1 = idHandle;
    idler2 = idIdx;
    memcpy(*insertionPt, get_ptr(localType, smHandle, &idler1, &idler2),
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

// forward declaration for co-recursing procedures
// void fill_raw_values(long int, long int, int[], int*, int[], int*, char**);

// dims starts off as the block sizes at each level of data nesting,
// but ass we recurse through this it gets replaced by the array of
// counts that are being incremented in the instances of this
// procedure from which the current one is being called
void fill_raw_values(long int localType, long int smHandle, int tree[],
		     int* use_dims, int dims[], int* dim_place,
		     char** insertionPt) {
  int count, dimty = 0; // value for RECORDS
  void* model_val_ptr;
  char *newBlk;
  /*
    sprintf(globMess, "fill_raw: case %d %d, dims %d %d %d %d, off %d fill %d",
  	  use_dims[0], use_dims[1], dims[0], dims[1], dims[2], dims[3], 
	    dim_place - dims, (int)*insertionPt);
    showMess(globMess);
  */
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
    smHandle = *(long int*)get_ptr(localType, smHandle, &tree, &dims);
    count = count_members(localType, smHandle);
    ((sizeAndPtr*)(*insertionPt))->size = count;
    if (count) // do not waste energy creating zero-length blox
      newBlk = new char[count*(dimty*sizeof(int) + dim_place[1])];
    ((sizeAndPtr*)(*insertionPt))->ptr = newBlk;
    *insertionPt += sizeof(sizeAndPtr);
    while (*tree++ != -1) {} // make relevant to current submodel
    while (smHandle) {
      fill_indices(localType, smHandle, dimty, &newBlk);
      fill_raw_values(localType, smHandle, tree,
		      use_dims+1, dim_place+1, dim_place+1, &newBlk);
      smHandle = step_ptr(localType, smHandle);
    }
    break;
  case 0:
    model_val_ptr = get_ptr(localType, smHandle, &tree, &dims);
    memcpy(*insertionPt, model_val_ptr, *dim_place);
    *insertionPt += *dim_place;
    break;
  case RECORDS:
    dimty = *dim_place; // save block size in case we need it again
    *dim_place = REQ_COUNT; // tells get_ptr to get made count
    int *tree_copy, *dims_copy;
    tree_copy = tree;
    dims_copy = dims; 
    count = *(int*)get_ptr(localType, smHandle, &tree_copy, &dims_copy);
    ((sizeAndPtr*)(*insertionPt))->size = count;
    newBlk = new char[count*dim_place[1]];
    ((sizeAndPtr*)(*insertionPt))->ptr = newBlk;
    *insertionPt += sizeof(sizeAndPtr);
    *dim_place = dimty;
    // now overwrite dim to look like normal array, recurse, and put back
    *use_dims=count;
    fill_raw_values(localType, smHandle, tree, 
    		    use_dims, dims, dim_place, &newBlk);
    *use_dims=RECORDS;
    break;
  default: /* value is a dimension of the array we are accessing */
    count = *dim_place; // save block size in case we need it again
    for (*dim_place = 0; *use_dims > *dim_place; ++*dim_place) {
      fill_raw_values(localType, smHandle, tree,
		      use_dims+1, dims, dim_place+1, insertionPt);
    }
    *dim_place = count;
    break;
  }
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

/* filling a structure of this type is going to be a straight copy of the Tcl
   list builder in the shim, cos it's the easiest way to think through it */
nodeValues* get_raw_values(char* nodeId, long int instance_id) {
  long int spareModel;
  int sparePath[32], fullDims[32], indices[32];
  char spareCapt[255], *insertionPt;
  enum_type_data *spareTypes[32]; // might need for reading files
  node_data_line *nodeLine;
  nodeValues* newBlk;

  if (!(nodeLine = searchinfo(nodeId, &spareModel, spareCapt, 
			      fullDims, sparePath, spareTypes)))
    return NULL;
  newBlk = new nodeValues;
  // find first dimension not a positive integer
  translate_dims(fullDims, indices, newBlk->dimSpecs, nodeLine->datatype, 
		 FALSE);

  if (indices[0]) {
    insertionPt = newBlk->contents = new char[indices[0]];
    fill_raw_values(spareModel, instance_id, sparePath, 
		    fullDims, indices, indices, &insertionPt);
  } else
    newBlk->contents = NULL;
  return newBlk;
}

/* definitions for regularData class -- note we may later want
to use regularData items to describe simple c++ arrays, which is why we 
create them and then set them to a model item

these now obsolete, replaced by the more general nodeValues data type

class regularData {
  int spacings[32];
  char* top;
public:
  int datatype;
  int dimensionality;
  int bounds[32];
  
  regularData() {
  }

  ~regularData() {
  }

  int set_to_model_value(long int model_id, long int instance_id,
			 char* caption) {
    int count, *quickpath, *pathref, *testref;
    char test[255];
    enum_type_data* types[32];
    int test_indices[] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    for (count = 1; ((Model*)model_id)->nodecount>count; ++count) {
      ((Model*)model_id)->make_full_caption(count, test, bounds, types);
      if (!strcmp(caption, test)) {
	dimensionality = 0;
	while (*(bounds + dimensionality)) {
	  ++dimensionality;
	}
	datatype = ((Model*)model_id)->nodedata[count].datatype;
	quickpath = ((Model*)model_id)->nodedata[count].path;
	pathref = quickpath;
	testref = test_indices;
	top = (char*)get_ptr(model_id, instance_id, &pathref, &testref);
	for (count = 0; count < dimensionality; ++count) {
	  test_indices[count] = 1;
	  pathref = quickpath;
	  testref = test_indices;
	  spacings[count] = (char*)get_ptr(model_id, instance_id, 
					   &pathref, &testref) - top;
	  test_indices[count] = 0;
	}
	return 0;
      }
    }
    return -1;
  }

  void* locate_element(int* indices) {
    char* result;
    int count;
    
    result = top;
    for (count = 0; count < dimensionality; ++count) {
      result += spacings[count]*indices[count];
    }
    return result;
  }
};

// need non-class versions of these for 5-d interface!

long int createRegularData () {
  return (long int) new regularData;
}

void deleteRegularData (long int old) {
  delete (regularData*)old;
}

int rdSetToNodeValue(long int old, long int mid, long int iid, char* caption) {
  return ((regularData*)old)->set_to_model_value(mid, iid, caption);
}

int rdDimensionality(long int old) {
  return ((regularData*)old)->dimensionality;
}

int rdDatatype(long int old) {
  return ((regularData*)old)->datatype;
}

int rdBound(long int old, int idx) {
  return ((regularData*)old)->bounds[idx];
}

void* rdLocateElement(long int old, int* indices) {
  return ((regularData*)old)->locate_element(indices);
}

// Procedures to carry out individual phases of model execution; no longer
// needed as part of the interface cos the whole loop is on this side

void update(long int modelType, long int modelHandle, int phase) {
  ((Model*)modelType)->updatemodel((void*)modelHandle, phase);
}

void advance(long int modelType, long int modelHandle, int phase) {
  ((Model*)modelType)->advancemodel((void*)modelHandle, phase);
}

int eval(long int modelType, long int modelHandle, int phase) {
  return ((Model*)modelType)->evalmodel((void*)modelHandle, phase);
}

Above ones should now only be called by the do_submodel routines,
so we will simplify them eventually. These next two allow the client
to drive the model...
*/

excpData* reset(long int modelType, long int modelHandle, int how_int,
		int top_phase) {
  excpData* result;

  topType = modelType;
  resetting=top_phase;
  result = ((Model*)topType)->resetmodel((void*)modelHandle, how_int, 
					 top_phase);
  if (!result && top_phase<-1) {
    listParamArray* paramArrayItem;

    paramArrayItem = param_array_base;
    while (paramArrayItem) {
      paramArrayItem->back_copy_vars(modelType, modelHandle);
      paramArrayItem = paramArrayItem->next;
    }
  }
  return result;
}

excpData* execute(long int modelType, long int modelHandle, int how_int,
	 double starttime, double* endtime, double errlim) {

  topType = modelType;
  resetting=0;
  return ((Model*)topType)->executemodel((void*)modelHandle, 
				  how_int, starttime, endtime, errlim);
}

/* procedure that is called by shim when it is loaded to supply pointers
   to its callback procedures */

void proc_pointers_for_shank(get_value_pointer_type* get_value_pointer_ptr,
			     interact_gui_type* interact_gui_ptr,
			     showMess_type* showMess_ptr,
			     char* simileVersionPtr) {
  get_client_value_pointer = get_value_pointer_ptr;
  interact_gui = interact_gui_ptr;
  showMessLocal = showMess_ptr;
  xsimileVersion = simileVersionPtr;
}

int setstep(long int modelId, double starttime, int phase) {
  ((Model*)modelId)->steps[phase] = starttime;
  return ((Model*)modelId)->phases;
}

void setdt(double starttime, int phase) {
  listNodeModel* nodeModelPoint = nodeModelList;
  Model* modelType;

  while (nodeModelPoint) {
    modelType = nodeModelPoint->model;
    if (modelType->phases>=abs(phase)) {
      modelType->setstepmodel(starttime, phase);
    }
    nodeModelPoint = nodeModelPoint->next;
  }
}

char* myexit(long int modelType, long int modelHandle) {  
  if (modelHandle) { 
    ((Model*)modelType)->exitmodel((void*)modelHandle);
  }
  if (param_array_base) {
    param_array_base = param_array_base->strip_out(modelType);
  }
  if (nodeModelList) {
    try {
      nodeModelList = nodeModelList->strip_out((Model*)modelType);
    } catch(DllLossage prang) {
      return prang.tell();
    }
  }
  return NULL;
}

char* getNodeId(long int modelType, char* capt) {
  Model* tgtModel;
  int tgtIndex;

  tgtIndex = nodeModelAndId((Model*)modelType, capt, &tgtModel);
  if (tgtIndex != -1) {
    return tgtModel->nodedata[tgtIndex].name;
  } else {
    return NULL;
  }
}
