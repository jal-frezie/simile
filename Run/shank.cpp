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

    #include <dlfcn.h>

    #define HINSTANCE void*
    #define LOAD_DLL flopen
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
HINSTANCE flopen(char* fileName) {
  return dlopen(fileName, RTLD_NOW);
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
fetch_instance_type fetch_instance;
update_submodel_type update_submodel;
advance_submodel_type advance_submodel;
eval_submodel_type eval_submodel;
search_from_type search_from;
advance_ptr_type advance_ptr;
get_remote_value_type get_remote_value;

char* xsimileVersion;
int connCount;
connectRecord* connectData;
showMess_type* showMessLocal;
char globMess[256];
double lts[8], ldts[8], steps[8];

/* values for keeping track of GUI interaction and execution times */
int last_op = 0;
unsigned long int last_exit = 0, last_update = 0;
unsigned long int took[]={0,0,0,0,0,0,0,0};
BOOLEAN resetting;

BOOLEAN check_gui(double model_time, int this_op) {
  unsigned long int flash, this_update;
  BOOLEAN result;
  
  flash=CLOCKS_PER_SEC/50; // 20ms
  // first record how much time the last op took
  this_update=clock();
  took[last_op]=this_update-last_exit;
  last_op = this_op;
  
  if ((this_update-last_update)>flash || took[this_op]>flash) {
    result=interact_gui(model_time);
    this_update=clock(); // GUI may have taken time
    last_update=this_update;
  } else {
    result=FALSE;
  }
  last_exit=this_update;
  return result;
}

void showMess(char* mess) {
  (*showMessLocal)(mess);
}

/* utility procedures making no direct reference to model classes/instances */
double graphpoint(double xval, graph_data_type* graphdata, int index) {
	double interval, intersection;
	int spaces, lower;
	int *right, *left;
	graph_data_type *use_graph_pointer;
	
	use_graph_pointer = find_graph(index, graphdata);

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
			   max(0,min(spaces,(int)(interval+0.5))));
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

/* some built-in random generators are not very accurate. In this
case we may use several random numbers to get a random double. */

double rand_fract() {
    double fraction = 0, precise = 1;
    while (precise > 1e-16) {
	precise = precise/(RAND_MAX+1.0);
	fraction = fraction+precise*rand();
    }
    return fraction;
}

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
  char* action;
  char* fileName;
  char* wibble;
  
  DllLossage(char* Action, char* FileName, char* Wibble) {
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

/* listable class for data to be loaded at a time point */

class listTimePoint {
public:
  double when;
  BOOLEAN myArraySpace;
  char* dataPtr;
  listTimePoint* next;

  listTimePoint() {
    myArraySpace = FALSE;
    dataPtr = NULL;
    next = NULL;
  }      

  ~listTimePoint() {
    if (dataPtr && myArraySpace) delete(dataPtr);
    if (next) delete(next);
  }

  char* create_space(void* newDataPtr, int sizeIfNeeded) {
    if (newDataPtr) {
      if (myArraySpace) {
	delete dataPtr;
      }
      myArraySpace = FALSE;
      dataPtr = (char*)newDataPtr;
    } else if (!myArraySpace) {
      dataPtr = new char[sizeIfNeeded];
      myArraySpace = TRUE;
    }
    return dataPtr;
  }  

  listTimePoint* find_last_pt(double time) {
    if (next) {
      sprintf(globMess, "seeking after %lf for %lf", when, time);
      /* showMess(globMess); */
      if (next->when<=time) {
	return next->find_last_pt(time);
      }
    }
    return this;
  }
};
  
class recordSet {
public:
  int count;
  char* space;

  recordSet() {
    space = NULL;
  }

  ~recordSet() {
  }
};

/* listable class for keeping track of arrays associated with parameters */

class listParamArray {
public:
  char* nodeId;
  node_data_line *nodeLine;
  int fullDims[32];
  BOOLEAN myArraySpace;
  char* dataPtr;
  listTimePoint* timePoints;
  listTimePoint* nextTimePoint;
  double wrapAroundPoint;
  int wraps;
  listParamArray* next;

  void remove_vm_dims() {
    int *src, *dest;
    BOOLEAN cutting_bases = FALSE;

    dest = src = fullDims;
    do {
      switch (*src) {
      case MEMBERS:
	continue;
      case START_VM:
	cutting_bases = TRUE;
	continue;
      case END_VM:
	cutting_bases = FALSE;
	continue;
      case RECORDS:
	// If a variable param, treat RECORDS as vm and remove.
	// If its a submodel and this is the last dimension then we
        // are making a space to keep the record count so get rid of
        // the RECORDS, otherwise drop through
	if (nodeLine->eval== INPUT || 
	    *(src+1)==0 && nodeLine->compclass==SUBMODEL) {
	  continue;
	}
      default:
	if (!cutting_bases) {
	  *(dest++) = *src;
	}
      }
    } while (*(src++));
  }

  listParamArray(char* newNodeId) {
    int sparePath[32];
    long int spareModel;
    char spareCapt[255];
    enum_type_data *spareTypes[32]; // might need for reading files

    nodeId = strdup(newNodeId);
    nodeLine = searchinfo(nodeId, &spareModel, spareCapt, fullDims, sparePath,
			  spareTypes);
    remove_vm_dims();
    myArraySpace = FALSE;
    dataPtr = NULL;
    timePoints = NULL;
    nextTimePoint = NULL;
    next = NULL;
  }      

  ~listParamArray() {
    delete(nodeId);
    if (dataPtr && myArraySpace) delete(dataPtr);
    if (next) delete(next);
  }
  
  int size_for_type() {
    switch (nodeLine->datatype) {
    case REAL:
      return sizeof(double);
    case FLAG:
      return sizeof(BOOLEAN);
    default: // submodel, INTEGER or enumerated type
      return sizeof(int);
    }
  }

  int array_count(int* startDim) {
    sprintf(globMess, "doing array size, dim %d", *startDim);
    /* showMess(globMess); */
    switch (*startDim) {
    case 0:
      return 1;
    case RECORDS:
      return -1; // -ve result means count is of records
    default:
      return (*startDim*array_count(startDim + 1));
    }
  }

  char* create_space(void* newDataPtr) {
    int count;
    if (newDataPtr) {
      if (myArraySpace) {
	delete dataPtr;
      }
      myArraySpace = FALSE;
      dataPtr = (char*)newDataPtr;
    } else if (!myArraySpace) {
      count = array_count(fullDims);
      if (count>0) {
	dataPtr = new char[size_for_type()*count];
      } else {
	dataPtr = (char*)new recordSet[-count];
      }
      myArraySpace = TRUE;
    }
    return dataPtr;
  }  

  char* create_time_point(double time, void* newDataPtr) {
    listTimePoint *lastTimePt, *thisTimePt;
    if (timePoints && timePoints->when<=time) {
      lastTimePt = timePoints->find_last_pt(time);
      if (lastTimePt->when==time) {
	thisTimePt = lastTimePt;
      } else {
	thisTimePt = new listTimePoint;
	thisTimePt->next = lastTimePt->next;
	lastTimePt->next = thisTimePt;
      }
    } else {
      thisTimePt = new listTimePoint;
      thisTimePt->next = timePoints;
      timePoints = thisTimePt;
    }
    thisTimePt->when = time;
    return thisTimePt->create_space(newDataPtr, 
				    array_count(fullDims)*size_for_type());
  }

  void* locate_elt(char* startPtr, int off, int* dimPtr, int* indxs) {
    recordSet* newRecord;

    sprintf(globMess, "locate_elt array %ld off %d dim %d indx %d",
	    startPtr, off, *dimPtr, *indxs);
	    /* showMess(globMess); */
    if (*dimPtr==RECORDS) {
      newRecord = (recordSet*)(startPtr + off*sizeof(recordSet));
      if  (*indxs) { // more indices, use to get value from a record submodel
	return locate_elt(newRecord->space, (*indxs)-1, dimPtr+1, indxs+1);
      } else { // no more indices, we are looking for recordSet struct
	return newRecord;
      }
    } else if (*dimPtr) {
      return locate_elt(startPtr, *dimPtr*off+*indxs-1, dimPtr+1, indxs+1);
    } else {
      return startPtr + off*size_for_type();
    }
  }
    
  /* indxs should be only those of models containing the per-record submodel
     followed by a 0 */
  int create_record_list(int* indxs, int records) {
    recordSet* newRecord;
    int* subDims;
    int count;

    newRecord = (recordSet*)locate_elt(dataPtr, 0, fullDims, indxs);
    newRecord->count = records;
    if (newRecord->space) {
      delete newRecord->space;
    }
    subDims = fullDims;
    while (*indxs) {
      subDims += 1;
      indxs += 1;
    }
    // at this point subDims points to the RECORDS element
    count = records*array_count(subDims + 1);
    if (count>0) {
      newRecord->space  = new char[size_for_type()*count];
    } else {
      newRecord->space = (char*)new recordSet[-count];
    }
    return 0;
  }

  int insert_to_array(char* useDataPtr, double val, int* indxs) {
    void* insertionPt;
    
    insertionPt = locate_elt(useDataPtr, 0, fullDims, indxs);
    switch (nodeLine->datatype) {
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
    return 0;
  }

  int insert_elt(double val, int* indxs) {
    // Because Simile input tools may not supply all the dimensions of the 
    // parameter array, this has to work out how many dimensions are supplied
    // and fill all the elements for which these are the innermost indices.
    int count, haveDims, needDims, makeDims, useDims[32], done = 0;
    for (count=31; count>=0; count--) {
      if (!indxs[count]) {
	haveDims = count;
      }
      if (!fullDims[count]) {
	needDims = count;
	haveDims = count; // avoid having too many
      }
    }
    makeDims = needDims-haveDims;

    for (count = 0; count<needDims; count++) {
      if (count<makeDims) {
	useDims[count] = 1;
      } else {
	useDims[count] = indxs[count-makeDims];
      }
    }

    while (!done) {
      insert_to_array(dataPtr, val, useDims);
      for (count = 0; count<makeDims; count++) {
	if (++useDims[count]<=fullDims[count]) break;
	useDims[count] = 1;
      }
      done = count==makeDims;
    }
    return 0;
  }

  int insert_time_point_elt(double time, double val, int* indxs) {
    listTimePoint* timePt;

    if (timePoints) {
      timePt = timePoints->find_last_pt(time);
      if (timePt->when == time) {
	return insert_to_array(timePt->dataPtr, val, indxs);
      }
    }
    return 1;
  }
  
  BOOLEAN time_point_exists (double time) {
    if (timePoints) {
      return (timePoints->find_last_pt(time)->when==time);
    }
    return FALSE;
  }

  void extract_elt(void* tgt, int* indxs) {
    // do not do it if this is a variable parameter and we are initializing --
    // array not yet set so let model keep default value...in fact, save it in
    // the array for later
    void* insertionPt;
    
    insertionPt = locate_elt(dataPtr, 0, fullDims, indxs);
    if (nodeLine->eval==INPUT && resetting && !(time_point_exists(0.0))) {
      memcpy(insertionPt, tgt, size_for_type());
    } else {
      memcpy(tgt, insertionPt, size_for_type());
    }
  }

  double update_from_points(double now, double horizon) {
    listTimePoint* timePt;
    double shifted;

    if (nextTimePoint) {
      shifted = now-wraps*wrapAroundPoint;
      if (nextTimePoint->when<=shifted) {
	nextTimePoint = nextTimePoint->find_last_pt(shifted);
	memcpy(dataPtr, nextTimePoint->dataPtr, 
	       size_for_type()*array_count(fullDims));
	nextTimePoint = nextTimePoint->next;
	if (wrapAroundPoint>0.0 && !nextTimePoint) {
	  nextTimePoint = timePoints;
	  wraps += 1;
	}
      }
      if (nextTimePoint) {
	return fmin(nextTimePoint->when+wraps*wrapAroundPoint,horizon);
      }
    }
    return horizon;
  }
};   // end of listParamArray class

listParamArray* param_array_base = NULL;

double update_time_series(double now, double horizon) {
  listParamArray* param_array_current;

  param_array_current = param_array_base;
  while (param_array_current) {
    horizon = param_array_current->update_from_points(now, horizon);
    param_array_current = param_array_current->next;
  }
  return horizon;
}    
  
void reset_time_series() {
  listParamArray* param_array_current;

  param_array_current = param_array_base;
  while (param_array_current) {
    param_array_current->nextTimePoint = param_array_current->timePoints;
    param_array_current->wraps = 0;
    param_array_current->update_from_points(0,0);
    param_array_current = param_array_current->next;
  }
}

/* prototypical declarations for functions to be supplied by the model dll
 */

typedef int getcount_type(void*, void*, void*, void*, void*, void*, void*,
			  void*, void*, void*, void*, void*, void*, void*,
			  int*, node_data_line**, int*, char***);
typedef double getversion_type(void);
typedef void* createmodel_type(void);
typedef int setstep_type(double, int);
typedef void updatemodel_type(void*, double, int);
typedef void advancemodel_type(void*, double, int);
typedef int evalmodel_type(void*, double, int, BOOLEAN);
typedef void* getpointer_type(void*, int**, int**);
typedef void exitmodel_type(void*);

/* Matching set of declarations for the pointers by which we will access
   these functions locally */

class Model {
  HINSTANCE handle;
  int count, count2, count3;
  int inArcCount;
  char** inArcList;
  //  enum_data_type *enumtypedata;

  getcount_type *getcount;
  getversion_type *getversion;
  createmodel_type *createmodel;

public:
  updatemodel_type *updatemodel;
  advancemodel_type *advancemodel;
  evalmodel_type *evalmodel;
  getpointer_type *getpointer;
  setstep_type *setstepmodel;
  exitmodel_type *exitmodel;

  int phases;
  graph_data_type* c_graphdata;
  int nodecount;
  node_data_line* nodedata;
  int *connLines;
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
sprintf(globMess, "Loaded %ld", handle);
/* showMess(globMess); */

    getcount = (getcount_type *)FIND_FUNCTION(handle, "get_count");
    createmodel = (createmodel_type *)FIND_FUNCTION(handle, "do_createmodel");
    updatemodel = (updatemodel_type *)FIND_FUNCTION(handle, "do_updatemodel");
    advancemodel = (advancemodel_type *)FIND_FUNCTION(handle, 
						      "do_advancemodel");
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
			    (void*)fetch_instance,
			    (void*)update_submodel,
			    (void*)advance_submodel,
			    (void*)eval_submodel,
			    (void*)search_from,
			    (void*)advance_ptr,
			    (void*)get_remote_value,
			    (void*)&c_graphdata,
			    &phases, &nodedata, 
			    &inArcCount, &inArcList);
    /*	sprintf(erreur, "finding %d (%s) of %d connections, first has top %s and %d dests.", 
	inArcCount, inArcList[0], connCount, connectData[0].TopArc, connectData[0].DestCount);
  	throw DllLossage("initialize", fileName, strdup(erreur)); */




    connLines = new int[inArcCount];
    /* Create a local reference for each component to the global table */
    for (count=0; inArcCount>count; count++) {
      connLines[count] = -1;
      for (count2=0; connCount>count2; count2++) {
	if (!strcmp(inArcList[count], connectData[count2].TopArc)) {
	  connLines[count] = count2;
	} else {
	  for (count3=0; connectData[count2].DestCount>count3; count3++) {
	    if (!strcmp(inArcList[count], connectData[count2].Dests[count3])) {

	      connLines[count] = count2;
	    }
	  }
	}
      }
      if (connLines[count] == -1) {
	sprintf(erreur, "Found no connection data for %s", inArcList[count]);
	throw DllLossage("initialize", fileName, strdup(erreur));
      }
    }
  }

  ~Model() {
    if (!UNLOAD_DLL(handle)) {
      throw DllLossage("unload", "", WHAT_WENT_WRONG());
    }
  }

  /* Next bit is really boring...and possibly needles...but I feel I have to
     make class procedures for the things loaded from the model dll rather than
     trying to refer to procedure variables in the model class directly */

  void* create() {
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

  int executemodel(void* id, int how_int, double start, double* end) {
    double freq, xtime;
    int big_phase, err;

    freq = steps[phases];
    for (xtime=int(start/freq + 0.5)*freq; xtime<=*end-0.5*freq;) {
      big_phase = phase_for(xtime, freq, phases+1);
      if (check_gui(xtime, big_phase)) {
	return -100; // should not conflict with os signal numbers
      }
      xtime+=freq;
      set_dts(big_phase, xtime);
      (*advancemodel)(id, xtime, big_phase);
      switch (how_int) {
      case EULER:
	advance_time(big_phase, 1);
	setdt(0,0);
	(*updatemodel)(id, xtime, big_phase);
	break;
      case RUNGE_KUTTA:
	if (err=rk_update(id, xtime, big_phase, phases)) {
	  *end=xtime;
	  return err;
	}
	break;
      }
      update_time_series(xtime, xtime);
      if (err=(*evalmodel)(id, xtime, big_phase, FALSE)) {
	*end=xtime;
	return err;
      }
    }
    check_gui(*end, 0);
    return 0;
  }
  
  int phase_for(double current, double step, int so_far) {
    int try_now, try_next;
    double last, next, next_step;

    if (so_far==1) {
      return 1;
    }
    try_now = so_far-1;
    next_step = steps[try_now];
    last = current-step/2;
    next = last+step;

    try_next = (int)floor(next/next_step);
    if (try_next == (int)floor(last/next_step)) {
      return so_far;
    } else {
      return phase_for(next_step*try_next, next_step, try_now);
    }
  }

  int rk_update(void* id, double xtime, int big_phase, int phases) {
    int err;
    setdt(1, 0);
    (*updatemodel)(id, xtime, big_phase);
    advance_time(big_phase, 0.5);
    setdt(2, 0);
    if (err=(*evalmodel)(id, xtime, big_phase, FALSE)) return err;
    (*updatemodel)(id, xtime, big_phase);
    setdt(3, 0);
    if (err=(*evalmodel)(id, xtime, big_phase, FALSE)) return err;
    (*updatemodel)(id, xtime, big_phase);
    advance_time(big_phase, 0.5);
    setdt(4, 0);
    if (err=(*evalmodel)(id, xtime, big_phase, FALSE)) return err;
    (*updatemodel)(id, xtime, big_phase);
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
  
  void advance_time (int phase, double fraction) {
    int tweak_phase;
    for (tweak_phase=phase; tweak_phase<=phases; tweak_phase++) {
      lts[tweak_phase]=lts[tweak_phase]+ldts[tweak_phase]*fraction;
      setdt(lts[tweak_phase],-tweak_phase); 
      // ts should only be global but im lazy
    }
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

    if ((parent = parent_line(line)) >= 0) {
      typesSoFar = make_full_caption(parent, result, dims, types);
    } else {
      *result = (char)NULL;
      *dims = 0;
      typesSoFar = 0;
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
      strcat(result, nodedata[line].caption);
    }
    append_ints_to_null(dims, nodedata[line].dims, 0, 0);
    // add this levels type data -- reverse order cos outer models start list
    for (count=nodedata[line].enum_type_count-1;count>=0;--count) {
      types[typesSoFar++]=&(nodedata[line].enum_type_ptrs[count]);
    }
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
    for (count=0;nodecount>count;++count) {
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
    if (next) {
      delete(next);
    }
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
};

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

listParamArray* param_array_item(listParamArray* start, char* seekNodeId) {
  if (!start) {
    return NULL;
  } else if (!strcmp(start->nodeId, seekNodeId)) {
    return start;
  } else {
    return param_array_item(start->next, seekNodeId);
  }
}
  
void* use_array_for_params(char* nodeId, void* dataSpace) {
  listParamArray* arrSlot;

  sprintf(globMess, "use_array_for_params node %s",
	  nodeId);
	  /* showMess(globMess); */
  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    arrSlot = new listParamArray(nodeId);
    if (!arrSlot->nodeLine) {
      delete arrSlot;
      return NULL;
    }
    arrSlot->next = param_array_base;
    param_array_base = arrSlot;
  }

  return arrSlot->create_space(dataSpace);
}

int clear_time_point_elts(char* nodeId) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return 1; // no data structure for this elt
  }
  delete arrSlot->timePoints;
  arrSlot->timePoints = NULL;
  arrSlot->nextTimePoint = NULL;
}

int set_wrap(char* nodeId, double time) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return 0; // no data structure for this elt
  }
  arrSlot->wrapAroundPoint = time;
  return 1;
}

void* create_time_point(char* nodeId, double time, void* dataSpace) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return NULL; // no data structure for this elt
  }
  return arrSlot->create_time_point(time, dataSpace);
}

int set_record_list(char* nodeId, int* indxs, int length) {
  listParamArray* arrLocn;

  sprintf(globMess, "set_record_list node %s indx0 %d length %d",
	  nodeId, *indxs, length);
	  /* showMess(globMess); */
  arrLocn = param_array_item(param_array_base, nodeId);
  if (!arrLocn) {
    return(1);
  } else {
    return(arrLocn->create_record_list(indxs, length));
  }
}

int set_param_array_elt(char* nodeId, double val, int* indxs) {
  listParamArray* arrLocn;

  sprintf(globMess, "set_param_array_elt node %s indx0 %d val %lf",
	  nodeId, *indxs, val);
	  /* showMess(globMess); */
  arrLocn = param_array_item(param_array_base, nodeId);
  if (!arrLocn) {
    return(1);
  } else {
    return(arrLocn->insert_elt(val, indxs));
  }
}  

int set_time_point_elt(char* nodeId, double time, double val, int* indxs) {
  listParamArray* arrLocn;
  arrLocn = param_array_item(param_array_base, nodeId);
  if (!arrLocn) {
    return(2);
  } else {
    return(arrLocn->insert_time_point_elt(time, val, indxs));
  }
}  

void get_value_pointer(void* modelSlot, char* nodeId, int ic, int* indxs) {
  listParamArray* paramArrayItem;

  sprintf(globMess, "get_value_pointer node %s indx0 %d",
	  nodeId, *indxs);
	  /* showMess(globMess); */
  paramArrayItem = param_array_item(param_array_base, nodeId);
  if (paramArrayItem) {
    paramArrayItem->extract_elt(modelSlot, indxs);
  } else {
    get_client_value_pointer(modelSlot, nodeId, ic, indxs);
  }
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
    }
    if (seekType->nodedata[count].datatype == EXTERNAL) {
      if (!strncmp(seeknode, test, strlen(test))) {
	return(nodeModelAndId(nodeModelList->nodeModel(seekType->
						       nodedata[count].name),
			      seeknode + strlen(test), /* was (strrchr(test, '/') - test), */
			      tgtModel));
      }
      
    }
  }
  /* Node with given caption not found... */
  return -1;
}

char* trueTxt = "true";
enum_type_data noType = {0, NULL, NULL}, boolType = {1, "false", &trueTxt};

void* append_ptrs_to_null(enum_type_data** dest, enum_type_data** src) {
  while (*dest) {dest += 1; }
  while (*src) {*dest = *src; dest += 1; src += 1; }
  *dest = NULL;
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

node_data_line* searchinfo(char* node, long int* tgtModel, char* caption, 
			   int* dims, int* path, enum_type_data** usedTypes) {
  listNodeModel* searchPoint = nodeModelList;
  Model* tryModel;
  node_data_line *bottomLine;
  char localCapt[256];
  int localDims[32], dimCount, usedCount;
  enum_type_data *thisType, *localTypes[32], *localUsed[32];
  int line, typeCount, typeIdx;

  while (searchPoint) {
    tryModel = searchPoint->model;
    if ((line=tryModel->getinfo(node))>-1) {
      bottomLine = tryModel->nodedata + line;
      typeCount = tryModel->make_full_caption(line, localCapt, 
					      localDims, localTypes);
      dimCount = 0;
      usedCount = 0;
      while (localDims[dimCount]) {
	if (localDims[dimCount] <= ENUM_BASE) {
	  thisType = localTypes[typeCount+localDims[dimCount]-ENUM_BASE-1];
	  localUsed[usedCount++] = thisType;
	  localDims[dimCount] = thisType->count;
	} else if (localDims[dimCount]==START_VM || 
		  localDims[dimCount]==END_VM) {
	} else {
	  localUsed[usedCount++] = &noType;
	}
	++dimCount;
      }
      if (bottomLine->datatype <= ENUM_BASE) {
	localUsed[usedCount++] = localTypes[typeCount+bottomLine->datatype
					 -ENUM_BASE-1];
      } else if (bottomLine->datatype == FLAG) {
	localUsed[usedCount++] = &boolType;
      } else if (bottomLine->datatype != SUBMODEL) {
	localUsed[usedCount++] = &noType;
      }
      localUsed[usedCount] = NULL;

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
	strcpy(caption + strlen(caption), /* was strrchr(caption, '/'), */
	       localCapt);
      } else {
	bottomLine = NULL;
      }
      *tgtModel = (long int)tryModel;
      return(bottomLine);
    }
    searchPoint = searchPoint->next;
  }
  return(NULL);
}

void* fetch_instance(char* nodeId) {
  return(nodeModelList->nodeModel(nodeId)->create());
}

long int fetch_top_instance(long int modelType, char* spare) {
   int count, count2;
   int dims[32], path[32];
   int* tree;
   connectRecord* currConnect;
   long int mSpare;
   enum_type_data* spareTypes[32];

   /* this section sets up the connection database -- done here because all

      model types must be loaded first */

   for (count=0; connCount>count; count++) {
     currConnect = &connectData[count];

     currConnect->TopModel = nodeModelList->nodeModel(currConnect->TopNode);
     if (searchinfo(currConnect->TopNode, &mSpare, spare, 
		    dims, path, spareTypes)) {
       tree = new int[32];
       if (searchinfo(currConnect->SourceNode, &mSpare, spare, 
		      dims, tree, spareTypes)) {
	 count2=0;
	 while (path[count2]) {
	   ++count2;
	 }
	 // Botch to cope with the fact that we start from the
	 // submodel instance not its structure in the parent when
	 // importing a value from a separate submodel
	 if (tree[count2] == SEPARATE) {
	   count2 += 3;
	 }
	 if (tree[count2] == -1) {
	   count2++;
	 }

	 currConnect->UpTree = &(tree[count2]);

       } else {
	 sprintf(spare, "Found no path for source node %s",
		 currConnect->SourceNode);
	 return 0;
       }

     } else {
       sprintf(spare, "Found no path for top node %s",
		 currConnect->TopNode);
       return 0;
     }
   }     
   /* debug
   sprintf(spare, "Top node path %d %d %d %d %d %d, Source node path %d %d %d %d %d %d, count2 %d",
	   *path, *(path+1), *(path+2), *(path+3), *(path+4), *(path+5),
	   *tree, *(tree+1), *(tree+2), *(tree+3), *(tree+4), *(tree+5),
	   count2);
   interp->result = spare;
   Tcl_SetStringObj(Tcl_GetObjResult(interp), spare, -1);
   return TCL_ERROR;
   */
   // now hopefully we won't be using the reference strings anymore, so...

   return (long int)((Model*)modelType)->create();
}

void* get_ptr(long int modelType, long int level, int** id_meta, 
	      int** dim_list) {
  return ((Model*)modelType)->getpointer((void*)level, id_meta, dim_list);
}

/* definitions for regularData class */

regularData::regularData() {
}

regularData::~regularData() {
}

int regularData::set_to_model_value(long int model_id, long int instance_id,
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
      start_at_one = TRUE;
      return 0;
    }
  }
  return -1;
}

void* regularData::locate_element(int* indices) {
  char* result;
  int count;
  
    result = top;
    for (count = 0; count < dimensionality; ++count) {
      result += spacings[count]*indices[count];
    }
    return result;
}

void update(long int modelType, long int modelHandle, 
	     double starttime, int phase) {
  ((Model*)modelType)->updatemodel((void*)modelHandle, starttime, phase);
}

void advance(long int modelType, long int modelHandle, 
	     double starttime, int phase) {
  ((Model*)modelType)->advancemodel((void*)modelHandle, starttime, phase);
}

int eval(long int modelType, long int modelHandle, 
	 double starttime, int phase, BOOLEAN exo) {
  return ((Model*)modelType)->evalmodel((void*)modelHandle, 
					starttime, phase, exo);
}

/* Above ones should now only be called by the do_submodel routines,
so we will simplify them eventually. These next two allow the client
to drive the model...
*/

int reset(long int modelType, long int modelHandle, int top_phase) {
  int tweak_phase;
  resetting=(top_phase==-2);
  for (tweak_phase=1; tweak_phase <= 7; tweak_phase++) {
    lts[tweak_phase]=0;
    setdt(0,-tweak_phase);
    setdt(steps[tweak_phase],tweak_phase);
  }
  reset_time_series();
  return ((Model*)modelType)->evalmodel((void*)modelHandle, 
					0, top_phase, FALSE);
}

int execute(long int modelType, long int modelHandle, int how_int,
	 double starttime, double* endtime) {
  resetting=FALSE;
  return ((Model*)modelType)->executemodel((void*)modelHandle, 
					how_int, starttime, endtime);
}

void* search_ptr(Model* type, void* level, int** id_meta, int** dims) {
  level = get_ptr((long int)type, (long int)level, id_meta, dims);
  if (*(*id_meta)++ == SEPARATE) {
    type = (Model*)*(*id_meta)++;
    return search_ptr(type, *(void**)level, id_meta, dims);
  } else {
    return level;
  }
}

int g_r_v_bug;

void* get_remote_value(void* typeRef, void* topInstRef, int level,
			    int arcIndx, int* subList) {
  connectRecord* currentData;
  int* tree;

  currentData = &connectData[((Model*)typeRef)->connLines[arcIndx]];
  tree = currentData->UpTree;
  while (level-->0) {
    while (*tree++ != -1) {}
  }
  if (topInstRef) {
    currentData->SearchBase = topInstRef;
  }
  g_r_v_bug = (int)(100*(*tree) + 10*(*(tree+1)) + *(tree+2));
  //  return(&g_r_v_bug);
  return(search_ptr((Model*)typeRef, currentData->SearchBase, 
		    &tree, &subList));
}

void* advance_ptr(void* typeRef, void* topInstRef) {
  int next_handle[] = {1,0}, *tree = next_handle;
  return *(void**)get_ptr((long int)typeRef, (long int)topInstRef, &tree, 
			  NULL);
}

void search_from(void* typeRef, int nodeIndx, void* instPtr) {

  connectData[((Model*)typeRef)->connLines[nodeIndx]].SearchBase = instPtr;
}

void update_submodel(char* nodeId, void* instanceId,
		       double start_time, int phase) {
  update((long int)nodeModelList->nodeModel(nodeId), (long int)instanceId, 
	 start_time, phase);
}

void advance_submodel(char* nodeId, void* instanceId,
		       double start_time, int phase) {
  advance((long int)nodeModelList->nodeModel(nodeId), (long int)instanceId, 
	  start_time, phase);
}

int eval_submodel(char* nodeId, void* instanceId,
		       double start_time, int phase, BOOLEAN exo) {
  return eval((long int)nodeModelList->nodeModel(nodeId), (long int)instanceId,

	      start_time, phase, exo);

}

/* procedure that is called by shim when it is loaded to supply pointers
   to its callback procedures */

void proc_pointers_for_shank(get_value_pointer_type* get_value_pointer_ptr,
			     interact_gui_type* interact_gui_ptr,
			     showMess_type* showMess_ptr,
			     char* simileVersionPtr,
			     connectRecord*** connectDataPtr, 
			     int** connCountPtr) {
  get_client_value_pointer = get_value_pointer_ptr;
  interact_gui = interact_gui_ptr;
  showMessLocal = showMess_ptr;
  xsimileVersion = simileVersionPtr;
  // put pointers to our connection database globals into the given locations 
  *connectDataPtr = &connectData;
  *connCountPtr = &connCount;
}

int setstep(double starttime, int phase) {
  steps[phase] = starttime;
  return (nodeModelList->model)->phases;
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
    delete param_array_base;
    param_array_base = NULL;
  }
  if (nodeModelList) {
    try {
      delete nodeModelList;
    } catch(DllLossage prang) {
      return prang.tell();
    }
    nodeModelList = NULL;
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
