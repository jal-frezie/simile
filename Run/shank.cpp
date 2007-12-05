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
unsigned long int flash=CLOCKS_PER_SEC/50; // 20ms
unsigned long int took[]={0,0,0,0,0,0,0,0};
long int topType;
BOOLEAN resetting;

BOOLEAN check_gui(void* id, double model_time, int this_op) {
  unsigned long int this_update;
  long int while_running;
  BOOLEAN result = FALSE, while_resetting;
  
  // first record how much time the last op took
  this_update=clock();
  took[last_op]=this_update-last_exit;
  
  if ((this_update-last_update)>flash) {
    while_running = topType;
    while_resetting = resetting;
    result=interact_gui(id, 1+!last_op, model_time);
    topType = while_running;
    resetting = while_resetting;
    this_update=clock(); // GUI may have taken time
    last_update=last_check=this_update;
  }
  if (took[this_op]>flash) {
    while_running = topType;
    while_resetting = resetting;
    result=result||interact_gui(id, 1+!this_op, model_time);
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
  if (this_update-last_check>flash && this_update-last_update>2*flash) {
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
  listTimePoint *last, *next;

  listTimePoint() {
    myArraySpace = FALSE;
    dataPtr = NULL;
    last = next = NULL;
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
      /* sprintf(globMess, "seeking after %lf for %lf", when, time);
      showMess(globMess); */
      if (next->when<=time) {
	return next->find_last_pt(time);
      }
    }
    return this;
  }
};
  
class recordSet {
public:
  //  int count;
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
  long int spareModel;
  int fullDims[32];
  BOOLEAN myArraySpace;
  char* dataPtr;
  listTimePoint* timePoints;
  listTimePoint* finalTimePoint;
  listTimePoint* curTimePoint;
  double wrapAroundPoint;
  int wraps;
  int fillMethod;
  listParamArray* next;

  void remove_vm_dims() {
    int *src, *dest;
    BOOLEAN cutting_bases = FALSE;

    dest = src = fullDims;
    do {
      switch (*src) {
      case MEMBERS:
      case SEPARATE:
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
    char spareCapt[255];
    enum_type_data *spareTypes[32]; // might need for reading files

    nodeId = strdup(newNodeId);
    nodeLine = searchinfo(nodeId, &spareModel, spareCapt, fullDims, sparePath,
			  spareTypes);
    remove_vm_dims();
    myArraySpace = FALSE;
    dataPtr = NULL;
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
    if(timePoints) delete(timePoints);
    size=array_count(fullDims);
     if (dataPtr && myArraySpace) {
      if (size<0) {
	for (count=0;count<-size;++count) {
	  innerSp = ((char**)dataPtr)[count];
	  /* sprintf(globMess, "lose %lx", innerSp);
	     showMess(globMess); */
	  if (innerSp) {
	    delete(innerSp);
	  }
	}
      }
      /*  sprintf(globMess, "freeing %lx fd0 %d", dataPtr,size);
	  showMess(globMess); */
      delete(dataPtr);
   }
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
    /* sprintf(globMess, "doing array size, dim %d", *startDim);
    showMess(globMess); */
    switch (*startDim) {
    case 0:
      return 1;
    case RECORDS:
      return -1; // -ve result means count is of records
    default:
      return (*startDim*array_count(startDim + 1));
    }
  }

  char* generate_local_space(int size_code) {
    char** ptrToNew;
    int count;

    if (size_code>0) {
      ptrToNew = (char**)(new char[size_for_type()*size_code]);
    } else {
      ptrToNew = new char*[-size_code];
      for (count=0; count<-size_code; ++count) {
	ptrToNew[count] = NULL;
      }
    }
    /* sprintf(globMess, "g_l_s created %lx size %d", ptrToNew, size_code);
       showMess(globMess); */
    return (char*)ptrToNew;
  }	

  char* create_space(void* newDataPtr) {
    int count;
    if (newDataPtr) {
      if (myArraySpace) {
	/* sprintf(globMess, "c_s freeing %lx", dataPtr);
	   showMess(globMess); */
	delete dataPtr;
      }
      myArraySpace = FALSE;
      dataPtr = (char*)newDataPtr;
    } else if (!myArraySpace) {
      dataPtr = generate_local_space(array_count(fullDims));
      myArraySpace = TRUE;
    }
    return dataPtr;
  }  

  int space_used() {
    return array_count(fullDims)*size_for_type();
  }
  
  char* create_time_point(double time, void* newDataPtr) {
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
    return thisTimePt->create_space(newDataPtr, 
				    array_count(fullDims)*size_for_type());
  }

  void* locate_elt(char* startPtr, int off, int* dimPtr, int* indxs) {
    char** newRecord;

    /* sprintf(globMess, "locate_elt array %lx off %d d0 %d d1 %d d2 %d indx %d",
    	    startPtr, off, dimPtr[0], dimPtr[1], dimPtr[2], *indxs);
	    showMess(globMess); */
    if (*dimPtr==RECORDS) {
      newRecord = (char**)startPtr + off;
      if  (*indxs) { // more indices, use to get value from a record submodel
	return locate_elt(*newRecord, (*indxs)-1, dimPtr+1, indxs+1);
      } else { // no more indices, we are looking for recordSet struct
	return newRecord;
      }
    } else if (*dimPtr) {
      return locate_elt(startPtr, *dimPtr*off+(*indxs)-1, dimPtr+1, indxs+1);
    } else {
      return startPtr + off*size_for_type();
    }
  }
    
  /* indxs should be only those of models containing the per-record submodel
     followed by a 0 */
  int create_record_list(int* indxs, int records) {
    char** newRecord;
    int* subDims;
    int count;

    newRecord = (char**)locate_elt(dataPtr, 0, fullDims, indxs);
    //    newRecord->count = records;
    if (*newRecord) {
      /* sprintf(globMess, "c_r_l freeing %lx", *newRecord);
	 showMess(globMess); */
      delete *newRecord;
    }
    subDims = fullDims;
    while (*indxs) {
      subDims += 1;
      indxs += 1;
    }
    // at this point subDims points to the RECORDS element
    *newRecord = generate_local_space(records*array_count(subDims + 1));
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
      //      sprintf(globMess, "Gonna copy %d from %ld to %ld", size_for_type(),
      //	      insertionPt, tgt);
      //      showMess(globMess);
      memcpy(tgt, insertionPt, size_for_type());
    }
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
	load_interpolated(loBound, hiBound, interFract);
	return;
      }
      if (interFract>0.5) { // fillMethod is USE_CLOSEST
	loBound = hiBound;
	wraps = hiWraps;
      }
    }
    if (loBound && loBound!=curTimePoint) {
      curTimePoint = loBound;
      memcpy(dataPtr, loBound->dataPtr, size_for_type()*array_count(fullDims));
    }
  }

  void load_interpolated(listTimePoint *loBound, listTimePoint *hiBound,
			 double interFract) {
    int off;

    if (nodeLine->datatype == REAL)
      for (off=0; off<array_count(fullDims); ++off)
	*((double*)dataPtr+off) = *((double*)hiBound->dataPtr+off)*interFract
	  + *((double*)loBound->dataPtr+off)*(1-interFract);
    else
      for (off=0; off<array_count(fullDims); ++off)
	*((int*)dataPtr+off) = (int)round(*((int*)hiBound->dataPtr+off)
					  *interFract
	  + *((int*)loBound->dataPtr+off)*(1-interFract));
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
  advancemodel_type *advancemodel;
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
			    &phases, &nodedata, &adapt_maxerr);
    /*	sprintf(erreur, "finding %d (%s) of %d connections, first has top %s and %d dests.", 
	inArcCount, inArcList[0], connCount, connectData[0].TopArc, connectData[0].DestCount);
  	throw DllLossage("initialize", fileName, strdup(erreur)); */


    /*
    channelData = NULL;
    connLines = new int[inArcCount];
    // Create a local reference for each component to the global table
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
    */
  }

  ~Model() {
    if (!UNLOAD_DLL(handle)) {
      throw DllLossage("unload", "", WHAT_WENT_WRONG());
    }
    // if (channelData) delete channelData;
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
  int adapt_doublings;

  int resetmodel(void* modelHandle, int top_phase) {
    int tweak_phase;
    
    if (top_phase<=0) {
      for (tweak_phase=1; tweak_phase <= 7; tweak_phase++) {
	lts[tweak_phase]=0;
	setdt(0, -tweak_phase);
	setdt(steps[tweak_phase], tweak_phase);
      }
      setdt(-1, 0);
      reset_time_series(this);
      adapt_doublings = 0;
    }
    return evalmodel(modelHandle, top_phase);
  }

  int executemodel(void* id, int how_int, 
		   double start, double* end, double errlim) {
    double freq, xtime;
    int big_phase, err;
    BOOLEAN made_step, first_pass;
    //    sprintf(globMess, "xm %lf-%lf at %lf", start, *end, errlim);
    //    showMess(globMess);
    freq = steps[phases]*pow(2,-adapt_doublings);
    xtime = start;
    while (freq*(*end-xtime)>0) { // freq only affects sign
      made_step = 0;
      first_pass = 1;
      big_phase = phase_for(xtime, freq, phases);
      // that is the biggest phase we will try to run, we may not succeed
      if (check_gui(id, xtime, big_phase)) {
	return -100; // should not conflict with os signal numbers
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

	(*advancemodel)(id, big_phase);
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
	  if (err=rk_update(id, big_phase)) {
	    *end=xtime;
	    return err;
	  }
	  break;
	}
	first_pass = 0;
	if (!errlim) {
	  made_step = 1;
	} else {
	  // get the model to generate its error estimate
	  if (err=(*evalmodel)(id, big_phase)) {
	    *end=xtime;
	    return err;
	  }
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
	      check_gui(id, xtime, 0);
	      return -99;
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
      if (err=(*evalmodel)(id, big_phase)) {
	*end=xtime;
	return err;
      }
    }
    if (check_gui(id, *end, 0)) {
      return -100; // should not conflict with os signal numbers
    }
    return 0;
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

  int rk_update(void* id, int big_phase) {
    int err;

    advance_time(this, big_phase, 0.5);
    setdt(2, 0);
    if (err=(*evalmodel)(id, big_phase)) return err;
    (*updatemodel)(id, big_phase);
    setdt(3, 0);
    if (err=(*evalmodel)(id, big_phase)) return err;
    (*updatemodel)(id, big_phase);
    advance_time(this, big_phase, 0.5);
    setdt(4, 0);
    if (err=(*evalmodel)(id, big_phase)) return err;
    (*updatemodel)(id, big_phase);
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
      // delete any separate submodels in here
      for (count=0; count<model->nodecount;count++) {
	if ((model->nodedata[count]).datatype==EXTERNAL) {
	  strip_out(nodeModel((model->nodedata[count]).name));
	}
      }
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
  
listParamArray* param_item_from_id(listParamArray* start, void* modelId,
				   int paramId) {
  if (!start) {
    return NULL;
  } else if (start->spareModel==(long int)modelId && 
	     (start->nodeLine)->graph==paramId) {
    return start;
  } else {
    return param_item_from_id(start->next, modelId, paramId);
  }
}
 
void* use_array_for_params(char* nodeId, void* dataSpace) {
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

  return arrSlot->create_space(dataSpace);
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

void* create_time_point(char* nodeId, double time, void* dataSpace) {
  listParamArray* arrSlot;

  if (!(arrSlot=param_array_item(param_array_base, nodeId))) {
    return NULL; // no data structure for this elt
  }
  return arrSlot->create_time_point(time, dataSpace);
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

int set_record_list(char* nodeId, int* indxs, int length) {
  listParamArray* arrLocn;

  /* sprintf(globMess, "set_record_list node %s indx0 %d length %d",
	  nodeId, *indxs, length);
	  showMess(globMess); */
  arrLocn = param_array_item(param_array_base, nodeId);
  if (!arrLocn) {
    return(1);
  } else {
    return(arrLocn->create_record_list(indxs, length));
  }
}

int set_param_array_elt(char* nodeId, double val, int* indxs) {
  listParamArray* arrLocn;

  /*  sprintf(globMess, "set_param_array_elt node %s indx0 %d val %lf",
	  nodeId, *indxs, val);
	  showMess(globMess); */
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

void get_value_pointer(void* modelId, void* modelSlot, int paramId,
		       int ic, int* indxs) {
  listParamArray* paramArrayItem;

  paramArrayItem = param_item_from_id(param_array_base, modelId, paramId);
  //  sprintf(globMess, "get_value_pointer for %ld node %s indx0 %d item %ld",
  //	  modelSlot, nodeId, *indxs, paramArrayItem);
  //  showMess(globMess);
  if (paramArrayItem) {
    paramArrayItem->extract_elt(modelSlot, indxs);
  } else {
    get_client_value_pointer(modelId, modelSlot, paramId, ic, indxs);
  }
  //  sprintf(globMess, "Think we got %lf", *(double*)modelSlot);
  //  showMess(globMess);

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

char* trueTxt = "true";
enum_type_data noType = {0, NULL, NULL}, boolType = {1, "false", &trueTxt};

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
      } else if (dims[dimCount]==SEPARATE || 
		 dims[dimCount]==START_VM || 
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
      usedTypes[usedCount++] = &boolType;
    } else {
      usedTypes[usedCount++] = &noType;
    }
  }
  usedTypes[usedCount] = NULL;
  return bottomLine;
}

void* fetch_instance(char* nodeId) {
  return(nodeModelList->nodeModel(nodeId)->create());
}

long int fetch_top_instance(long int modelType, char* spare) {
/*   int count, count2;
   int dims[32], path[32];
   int* tree;
   connectRecord* currConnect;
   channelRecord* currChannel;
   long int mSpare;
   enum_type_data* spareTypes[32];
*/
   /* this section sets up the connection database -- done here because all

      model types must be loaded first */

   /*   ((Model*)modelType)->channelData = new channelRecord[connCount];
   for (count=0; connCount>count; count++) {
     currConnect = connectData + count;
     currChannel = ((Model*)modelType)->channelData + count;

     //     currConnect->TopModel = nodeModelList->nodeModel(currConnect->TopNode);
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

	 currChannel->UpTree = &(tree[count2]);

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
     // now hopefully we won't be using the reference strings anymore, so...
   }     
   delete connectData;
   */
   return (long int)((Model*)modelType)->create();
}

void* get_ptr(long int modelType, long int level, int** id_meta, 
	      int** dim_list) {
  return ((Model*)modelType)->getpointer((void*)level, id_meta, dim_list);
}

/* definitions for regularData class -- note we may later want
to use regularData items to describe simple c++ arrays, which is why we 
create them and then set them to a model item */

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
/*
void update(long int modelType, long int modelHandle, int phase) {
  ((Model*)modelType)->updatemodel((void*)modelHandle, phase);
}

// model execution

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

int reset(long int modelType, long int modelHandle, int top_phase) {
  topType = modelType;
  resetting=(top_phase==-2);
  return ((Model*)topType)->resetmodel((void*)modelHandle, top_phase);
}

int execute(long int modelType, long int modelHandle, int how_int,
	 double starttime, double* endtime, double errlim) {
  topType = modelType;
  resetting=FALSE;
  return ((Model*)topType)->executemodel((void*)modelHandle, 
					how_int, starttime, endtime, errlim);
}

void* search_ptr(Model* type, void* level, int** id_meta, int** dims) {
  level = get_ptr((long int)type, (long int)level, id_meta, dims);
  //  sprintf(globMess, "got ptr %ld", level);
  //  showMess(globMess);
  if (*(*id_meta)++ == SEPARATE) {
    type = (Model*)*(*id_meta)++;
    return search_ptr(type, *(void**)level, id_meta, dims);
  } else {
    return level;
  }
}
/*
void* get_remote_value(void* typeRef, void* topInstRef, int level,
			    int arcIndx, int* subList) {
  channelRecord* currentData;
  int* tree;
  int recordNo;
  void* useInstRef;

  recordNo = ((Model*)typeRef)->connLines[arcIndx];
  currentData = ((Model*)topType)->channelData + recordNo;
  tree = currentData->UpTree;

  while (level-->0) {
    while (*tree++ != -1) {}
  }
  if (topInstRef) {
    useInstRef = topInstRef;
  } else {
    useInstRef = currentData->SearchBase;
  }
  //  sprintf(globMess, "get_remote: type %ld base %ld tree %d,%d,%d,%d,%d,%d",
  //	  typeRef, currentData->SearchBase, 
  //	  tree[0], tree[1], tree[2], tree[3], tree[4], tree[5]);
  //  showMess(globMess);
  return(search_ptr((Model*)typeRef, useInstRef, &tree, &subList));
}
*/
void* advance_ptr(void* typeRef, void* topInstRef) {
  int next_handle[] = {1,0}, *tree = next_handle;
  return *(void**)get_ptr((long int)typeRef, (long int)topInstRef, &tree, 
			  NULL);
}
/*
void search_from(void* typeRef, int nodeIndx, void* instPtr) {
  int recordNo;
  recordNo = ((Model*)typeRef)->connLines[nodeIndx];
  ((Model*)topType)->channelData[recordNo].SearchBase = instPtr;
}

void update_submodel(char* nodeId, void* instanceId, int phase) {
  update((long int)nodeModelList->nodeModel(nodeId), (long int)instanceId, 
	 phase);
}

void advance_submodel(char* nodeId, void* instanceId, int phase) {
  advance((long int)nodeModelList->nodeModel(nodeId), (long int)instanceId, 
	  phase);
}

int eval_submodel(char* nodeId, void* instanceId, int phase, BOOLEAN exo) {
  //  sprintf(globMess, "Entering submodel ph.%d ex.%d", phase, exo);
  //  showMess(globMess);
  return eval((long int)nodeModelList->nodeModel(nodeId), (long int)instanceId,
	      phase, exo);
}

procedure that is called by shim when it is loaded to supply pointers
   to its callback procedures */

void proc_pointers_for_shank(interact_gui_type* interact_gui_ptr,
			     showMess_type* showMess_ptr,
			     char* simileVersionPtr) {
  //  get_client_value_pointer = get_value_pointer_ptr;
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
