/* cmx stands for c model extensions
This builds into a shared library which is loaded by Tcl when
AME starts up. Subsequently it can itself load other shared
libraries corresponding to compiled model programs, and allow
them to be executed etc by Tcl commands. */

#include <tcl.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdlib.h> /* for rand procedure used by tcl models */

#define	GETDIMS		0
#define	GETTYPE		1
#define	GETEVAL		2
#define	GETGRAPH	3
#define	GETCAPTION	5
#define	GETMIN          6
#define	GETMAX	        8
#define GETPATH        10
#define GETCLASS       11
#define	TEST	       99

#define READGRAPH      21
#define WRITEGRAPH     22
#define USEGRAPH       23

#define USE_MY_HMAC

#ifdef WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #undef WIN32_LEAN_AND_MEAN

    #define LOAD_DLL LoadLibrary
    #define UNLOAD_DLL FreeLibrary
    #define WHAT_WENT_WRONG GetErrorText
    #define FIND_FUNCTION GetProcAddress
    #define FORUNIX 0
BOOL APIENTRY
DllEntryPoint(
    HINSTANCE hInst,		/* Library instance handle. */
    DWORD reason,		/* Reason this function is being called. */
    LPVOID reserved)		/* Not used. */
{
    return TRUE;
}

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
    #define FORUNIX 1
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
#include <locale.h>

/* Definitions used in this code and the model code */
#include <dllcalls.h>

char simileVersion[] = SIMILE_VERSION;

/* utility procedures making no direct reference to model classes/instances */
graph_data_type *graphdata;

double graphpoint(double xval, int index) {
	double interval, intersection;
	int spaces, lower;
	int *right, *left;
	graph_data_type *use_graph_pointer;
	
	use_graph_pointer = find_graph(index, graphdata);

	spaces = use_graph_pointer->xsize-1;
	/* Interval is distance from left of graph in point units */
	interval = spaces*(xval - use_graph_pointer->xlow)/
		(use_graph_pointer->xhigh - use_graph_pointer->xlow);
	switch(use_graph_pointer->range) {
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

int compare_instance_status (const int pointers[], const int ref_pointers[], 
			     int num) {
   int count;
   for (count=0; count<num; count++) {
     if (pointers[count]<ref_pointers[count]) return -1;
     if (pointers[count]>ref_pointers[count]) return 1;
   }
   return 0;
}

class DllLossage {
  char* action;
  char* fileName;
  char* wibble;
  
public:
  DllLossage(char* Action, char* FileName, char* Wibble) {
    action=Action;
    fileName=FileName;
    wibble=Wibble;
  }

  void tellTcl(Tcl_Interp* interp) {
    Tcl_AppendResult(interp, "couldn't ", action, " file \"", fileName,
		     "\": ", wibble, (char *) NULL);
  }
};

class connectRecord {
public:
  char* TopArc;
  char* TopNode;
  void* TopModel; // should be Model* but one has to be declared first
  char* SourceNode;
  int DestCount;
  char** Dests;
  void* SearchBase;
  int* UpTree;
};

int connCount;
connectRecord* connectData;
Tcl_Obj* connectInfoObject;

ame_rand_type ame_rand;
graphpoint_type graphpoint;
release_graph_data_type release_graph_data;
compare_instance_status_type compare_instance_status;
get_value_pointer_type get_value_pointer;
fetch_instance_type fetch_instance;
update_submodel_type update_submodel;
advance_submodel_type advance_submodel;
eval_submodel_type eval_submodel;
search_from_type search_from;
advance_ptr_type advance_ptr;
get_remote_value_type get_remote_value;

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

  getcount_type *getcount;
  getversion_type *getversion;
  createmodel_type *createmodel;
  setstep_type *setstepmodel;
  updatemodel_type *updatemodel;
  advancemodel_type *advancemodel;
  evalmodel_type *evalmodel;
  getpointer_type *getpointer;
  exitmodel_type *exitmodel;

public:
  int phases;
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
    if ((*getversion)() < atof(simileVersion)-0.00001) {
      UNLOAD_DLL(handle);
      throw DllLossage("find current version of", fileName, WHAT_WENT_WRONG());

    }



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
			    (void*)&graphdata,
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

  /* Now for the locally defined model class procedures */

  void make_full_caption(int *tree, char *result) {
    /* New version which does not depend on the nodedata array being in
       any particular order -- and returns the whole caption */
    int count,level;

    *result = (char)NULL;
    level = 1;
    while (tree[level]) {
      level++;
      for (count=1;nodecount>count;count++) {
	if (!compare_instance_status(nodedata[count].path,tree,level) &&
	    !nodedata[count].path[level]) {
	  strcat(result, "/");
	  strcat(result, nodedata[count].caption);
	  break;
	}
      }
    }
  }
  
  node_data_line* getinfo(char* node_id) {
    int count;

    for (count=0;nodecount>count;++count) {
      if (!strcmp(node_id, nodedata[count].name)) { 
	return(nodedata + count);
      }
    }
    return NULL;
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

Model *modelType;
void* modelHandle;
Tcl_Interp* globInterp;
int serviceError;

/* this simply makes up a tcl list of all the objects that
appear in the object table. */

int list(Model* listType, Tcl_Interp *interp) {

  Tcl_Obj *resultPtr;
  char* find;
  int line;

  resultPtr = Tcl_GetObjResult(interp);
  for (line=0; line<listType->nodecount; line++) {
    find = listType->nodedata[line].name;
    if (listType->nodedata[line].datatype == EXTERNAL) {
      list(nodeModelList->nodeModel(find), interp);
    } else {
      Tcl_ListObjAppendElement(interp, resultPtr, Tcl_NewStringObj(find, -1));
    }
  }
  return TCL_OK;
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
  for (count = 1; seekType->nodecount>count; ++count) {
    seekType->make_full_caption(seekType->nodedata[count].path, test);
	  
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
   fails to find path. */

void append_ints_to_null(int* dest, int* src, int sep, int sep2) {
  while (*dest) { dest++; }
  if (sep) { *(dest++)=sep; }
  if (sep2) { *(dest++)=sep2; }
  do { *(dest++)= *src; } while (*src++);
}
  
node_data_line* searchinfo(char* node, Model** tgtModel, 
			   char* caption, int* dims, int* path) {
  listNodeModel* searchPoint = nodeModelList;
  Model* tryModel;
  node_data_line *bottomLine;
  char localCapt[256];

  while (searchPoint) {
    tryModel = searchPoint->model;
    if (bottomLine=tryModel->getinfo(node)) {
      *tgtModel = tryModel;
      tryModel->make_full_caption(bottomLine->path, localCapt);
      if (tryModel == modelType) {
	strcpy(caption, localCapt);
	*dims = *path = 0;
	append_ints_to_null(dims, bottomLine->dims, 0, 0);
	append_ints_to_null(path, bottomLine->path, 0, 0);
      } else if (searchinfo(searchPoint->node, &tryModel,
			    caption, dims, path)) { /* ref to tryModel spare */
	append_ints_to_null(dims, bottomLine->dims, SEPARATE, 0);
	append_ints_to_null(path, bottomLine->path, SEPARATE, 
			    (int)searchPoint->model);
	strcpy(caption + strlen(caption), /* was strrchr(caption, '/'), */
	       localCapt);
      } else {
	bottomLine = NULL;
      }
      return(bottomLine);
    }
    searchPoint = searchPoint->next;
  }
  return(NULL);
}

int do_interface(Tcl_Interp *interp, int argc, Tcl_Obj *CONST argv[])
{
  int count;
  char current[255];
  int dims[32], path[32];
  Tcl_Obj *resultPtr;
  int error, action;
  node_data_line *data_line;
  Model* tgtModel;

  if (argc < 3) {
    interp->result = "At least three arguments for interface please!";
    return TCL_ERROR;
  }
  error = Tcl_GetIntFromObj(interp, argv[2], &action);
  if (error != TCL_OK) {
    return error;
  } /* if(error) */

  resultPtr = Tcl_GetObjResult(interp);

  if (!(data_line=searchinfo(Tcl_GetStringFromObj(argv[1], NULL), &tgtModel,
			     current, dims, path)))
    {
    sprintf(current, "noitem");
    Tcl_SetStringObj(resultPtr, current, -1);
    return(TCL_OK);
  }

  switch (action) {
  case GETDIMS:
    count=0;
    do {
      if (Tcl_ListObjAppendElement(interp, resultPtr, 
			       Tcl_NewIntObj(dims[count])) != TCL_OK) {
	return TCL_ERROR;
	}
    } while (dims[count++]);
    return TCL_OK;
  Tcl_SetIntObj(resultPtr, dims[0]);
  case GETPATH:
    count=0;
    do {
      if (Tcl_ListObjAppendElement(interp, resultPtr, 
			       Tcl_NewIntObj(path[count])) != TCL_OK) {
	return TCL_ERROR;
	}
    } while (path[count++]);
    return TCL_OK;
  case GETCLASS:
    Tcl_SetIntObj(resultPtr, data_line->compclass);
    return TCL_OK;

  case GETTYPE:
    Tcl_SetIntObj(resultPtr, data_line->datatype);
    return TCL_OK;

  case GETEVAL:
    Tcl_SetIntObj(resultPtr, data_line->eval);
    return TCL_OK;

  case GETMIN:
    Tcl_SetDoubleObj(resultPtr, data_line->min);
    return TCL_OK;

  case GETMAX:
    Tcl_SetDoubleObj(resultPtr, data_line->max);
    return TCL_OK;

  case GETGRAPH:
    if (!data_line->graph) {
      sprintf(current, "No graph associated with node %s.", data_line->name);
      Tcl_SetStringObj(resultPtr, current, -1);

      return TCL_ERROR;
    }
    Tcl_SetIntObj(resultPtr, data_line->graph);
    return TCL_OK;

  case GETCAPTION:
    Tcl_SetStringObj(resultPtr, current, -1);
    return TCL_OK;

  default:
    sprintf(current, "getvalue does not support action %d",
	    action);
    Tcl_SetStringObj(resultPtr, current, -1);
    return TCL_ERROR;

 } /* end(switch,action) */
} /* end(procedure,!(finished)) */

/* Now for procedures that are called from the dll and therefore have to be
   global even though they may refer to stuff by model type and instance */

void get_value_pointer(void* tgt, char* id, int count, int* inds) {
  node_data_line* data_line;
  char caption[255];
  char* varName;
  int dims[32], path[32];
  Tcl_Obj* valPtr;
  int stepIndex, rv;
  Model* mSpare;

  data_line = searchinfo(id, &mSpare, caption, dims, path);
  strcpy(caption, data_line->name);
  for (stepIndex = 0; count>stepIndex; ++stepIndex) {
    sprintf(caption + strlen(caption), ",%d", inds[stepIndex]); 
  }
  
  if (data_line->eval == TABLE) {
    varName = "paramData ";
  } else if (data_line->eval == INPUT) {
    if (data_line->datatype == FLAG) {
      varName = "checkStates ";
    } else if (data_line->datatype == ENUMERATED) {
      varName = "comboChoices ";
    } else {
      varName = "sliderVals ";
    }
  }
  if (Tcl_VarEval(globInterp, "BringParameter ", varName, caption, NULL) 
      == TCL_OK) {
    valPtr = Tcl_GetObjResult(globInterp);
    switch (data_line->datatype) {
    case FLAG:
      serviceError = Tcl_GetBooleanFromObj(globInterp, valPtr, (int*)tgt);
      return;
    case VALUELESS: /* getting number of instances for record submodel */
    case INTEGER:
    case ENUMERATED:
      serviceError = Tcl_GetIntFromObj(globInterp, valPtr, (int*)tgt);
      return;
    case REAL:
      serviceError = Tcl_GetDoubleFromObj(globInterp, valPtr, (double*)tgt);
      return;
    }
  }
}
      
void* fetch_instance(char* nodeId) {
  return(nodeModelList->nodeModel(nodeId)->create());
}

void* search_ptr(Model* type, void* level, int** id_meta, int** dims) {
  level = type->get_ptr(level, id_meta, dims);
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
  return *(void**)((Model*)(typeRef))->get_ptr(topInstRef, &tree, NULL);
}

void search_from(void* typeRef, int nodeIndx, void* instPtr) {

  connectData[((Model*)typeRef)->connLines[nodeIndx]].SearchBase = instPtr;
}

void update_submodel(char* nodeId, void* instanceId,
		       double start_time, int phase) {
  nodeModelList->nodeModel(nodeId)->update(instanceId, start_time, phase);
}

void advance_submodel(char* nodeId, void* instanceId,
		       double start_time, int phase) {
  nodeModelList->nodeModel(nodeId)->advance(instanceId, start_time, phase);
}

int eval_submodel(char* nodeId, void* instanceId,
		       double start_time, int phase, BOOLEAN exo) {
  return nodeModelList->nodeModel(nodeId)->eval(instanceId, start_time, 
						phase, exo);
}

/* Here is code that has been added by hand to make these procedures available
as Tcl commands so the dialog box can call them as if it were a Tcl simulation.
 This one is called after a new dll has been built, to set the function
   pointers to the appropriate addresses in the dll. Some code is copied
   from TclLoadDl.c -- well, that works...if called without an arg it
unloads the model. Since the model dll now merely defines the model class, this
also causes an instance of it to be created. */

extern "C" int loadmodelCmd(ClientData clientData, Tcl_Interp *interp, 
			    int argc, Tcl_Obj *CONST argv[]) {
  char* fileName;
  char* nodeName;
 
  switch (argc) {
  case 3:
    fileName = Tcl_GetStringFromObj(argv[1], NULL);
    nodeName = Tcl_GetStringFromObj(argv[2], NULL);

    try {
      modelType = new Model(fileName);
    }
    catch(DllLossage prang) {
      prang.tellTcl(interp);
      return TCL_ERROR;
    }

    nodeModelList = new listNodeModel(nodeName, 
				      modelType,
				      nodeModelList);
    Tcl_SetObjResult(interp, Tcl_NewLongObj((long int)modelType));
    break;

  default:
    interp->result = "Two arguments for loadmodel please!";
    return TCL_ERROR;
  }
  return TCL_OK;
}

/* Create also sets up the tables required to get data out of one submodel
   instance into another */

extern "C" int createmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
   int count, count2, error;
   char spare[256];
   int dims[32], path[32];
   int* tree;
   connectRecord* currConnect;
   Model* mSpare;

   if (argc != 2) {
	interp->result = "One argument for create please!";
	return TCL_ERROR;
   }

   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }
   for (count=0; connCount>count; count++) {
     currConnect = &connectData[count];
     currConnect->TopModel = nodeModelList->nodeModel(currConnect->TopNode);
     if (searchinfo(currConnect->TopNode, &mSpare, spare, dims, path)) {
       tree = new int[32];
       if (searchinfo(currConnect->SourceNode, &mSpare, spare, dims, tree)) {
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
	 Tcl_SetStringObj(Tcl_GetObjResult(interp), spare, -1);
	 return TCL_ERROR;
       }
     } else {
       sprintf(spare, "Found no path for top node %s",
		 currConnect->TopNode);
       Tcl_SetStringObj(Tcl_GetObjResult(interp), spare, -1);
       return TCL_ERROR;
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

   Tcl_SetLongObj(Tcl_GetObjResult(interp), (long int)(modelType->create()));
   return TCL_OK;
}

extern "C" int updatemodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
   double starttime;
   int phase;
   int error;

   if (argc != 5) {
	interp->result = "Four arguments for update please!";
	return TCL_ERROR;
   }

   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetLongFromObj(interp, argv[2], (long int *)&modelHandle);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetDoubleFromObj(interp, argv[3], &starttime);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetIntFromObj(interp, argv[4], &phase);
   if (error != TCL_OK) {
	return error;
   }

   serviceError = TCL_OK;
   modelType->update(modelHandle, starttime, phase);
   return serviceError;
}

extern "C" int advancemodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
   double starttime;
   int phase;
   int error;

   if (argc != 5) {
	interp->result = "Four arguments for advance please!";
	return TCL_ERROR;
   }

   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetLongFromObj(interp, argv[2], (long int *)&modelHandle);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetDoubleFromObj(interp, argv[3], &starttime);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetIntFromObj(interp, argv[4], &phase);
   if (error != TCL_OK) {
	return error;
   }

   serviceError = TCL_OK;
   modelType->advance(modelHandle, starttime, phase);
   return serviceError;
}

extern "C" int evalmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  char spare[256];
   double starttime;
   int phase;
   int error;

   if (argc != 5) {
	interp->result = "Four arguments for eval please!";
	return TCL_ERROR;
   }

   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetLongFromObj(interp, argv[2], (long int *)&modelHandle);
   if (error != TCL_OK) {
	return error;

   }

   error = Tcl_GetDoubleFromObj(interp, argv[3], &starttime);
   if (error != TCL_OK) {
	return error;

   }

   error = Tcl_GetIntFromObj(interp, argv[4], &phase);
   if (error != TCL_OK) {
	return error;
   }

   error = modelType->eval(modelHandle, starttime, phase, FALSE);
   if (error < 0) {
     sprintf(spare, "Illegal operation signal %d", -error);
     Tcl_SetStringObj(Tcl_GetObjResult(interp), spare, -1);
     return TCL_ERROR;
   } else if (error > 0) {
     sprintf(spare, "User-defined interruption code %d", error);
     Tcl_SetStringObj(Tcl_GetObjResult(interp), spare, -1);
     return TCL_ERROR;
   } else {
     return TCL_OK;
   }
}

extern "C" int setstepCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
   double starttime;
   int phase;
   int error;
   listNodeModel* nodeModelPoint = nodeModelList;
   

   if (argc != 3) {
	interp->result = "Two arguments for setstep please!";
	return TCL_ERROR;
   }

   error = Tcl_GetDoubleFromObj(interp, argv[1], &starttime);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetIntFromObj(interp, argv[2], &phase);
   if (error != TCL_OK) {
	return error;
   }

   while (nodeModelPoint) {
     modelType = nodeModelPoint->model;
     if (modelType->phases>=abs(phase)) {
       modelType->setstep(starttime, phase);
     }
     nodeModelPoint = nodeModelPoint->next;
   }
   Tcl_SetIntObj(Tcl_GetObjResult(interp), (nodeModelList->model)->phases);
   return TCL_OK;
}

/* exit model: unload all dlls. If the handle is nonzero, free its data
   structures first (though this probably gets done when the dlls are unloaded
*/

extern "C" int exitmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  if (argc != 3) {
    interp->result = "Two arguments for exit please!";
    return TCL_ERROR;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], (long int *)&modelHandle);
  if (error != TCL_OK) {
    return error;
  }
  
  if (modelHandle) { 
    modelType->exit(modelHandle);
  }

  if (nodeModelList) {
    try {
      delete nodeModelList;
    }
    catch(DllLossage prang) {
      prang.tellTcl(interp);
      return TCL_ERROR;
    }
  }
  
  nodeModelList = NULL;
  return TCL_OK;
}

extern "C" int getnodeidCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
    int error, tgtIndex;
    Model* tgtModel;

    if (argc != 3) {
	interp->result = "Two arguments for get_node_id please!";
	return TCL_ERROR;
    }

   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

   tgtIndex = nodeModelAndId(modelType, Tcl_GetStringFromObj(argv[2], NULL),
			     &tgtModel);
    if (tgtIndex != -1) {
	interp->result = tgtModel->nodedata[tgtIndex].name;
	return TCL_OK;
    } else {
	Tcl_AppendResult(interp, "No node with caption string ",
			 Tcl_GetStringFromObj(argv[2], NULL), " found.",
		(char*)NULL);
	return TCL_ERROR;
    }
}

extern "C" int interfaceCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
   int error;
   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

  return do_interface(interp, argc-1, argv+1);
}

extern "C" int graphCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int action, index, count, error;
  Tcl_Obj* resultPtr;
  graph_data_type* graphptr;
  char current[255];
  double xval;

  if (argc < 3) {
    interp->result = "At least two arguments for graph_table please!";
    return TCL_ERROR;
  }
  error = Tcl_GetIntFromObj(interp, argv[1], &action);
  if (error != TCL_OK) {
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[2], &index);
  if (error != TCL_OK) {
    return error;
  } /* if(error) */

  resultPtr = Tcl_GetObjResult(interp);

  switch (action) {
  case READGRAPH:
    graphptr = find_graph(index, graphdata);
    sprintf(current, "%f %f %d %f %f %d %d %d",
            graphptr->xlow,
            graphptr->xhigh,
            graphptr->xspan,
            graphptr->ylow,
            graphptr->yhigh,
            graphptr->yspan,
            graphptr->range,
            graphptr->xsize);
    Tcl_SetStringObj(resultPtr, current, -1);

    for (count=0;count<graphptr->xsize;count++) {
      sprintf(current, " %d", graphptr->points[count]);
      Tcl_AppendStringsToObj(resultPtr, current, 
			     (char *)NULL);
			     }
    return TCL_OK;
  case WRITEGRAPH:
    if (argc < 12) {
      Tcl_SetStringObj(resultPtr, "At least 12 args needed to set graph!", -1);
      return TCL_ERROR;
    } /* if(error) */

    graphptr = find_graph(index, graphdata);
    if (!graphptr) { /* add a new graph */
      graphptr = graphdata = new graph_data_type(index, graphdata);
    } else {
      release_graph_data(graphptr);
    }

    error = Tcl_GetDoubleFromObj(interp, argv[3], &(graphptr->xlow));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetDoubleFromObj(interp, argv[4], &(graphptr->xhigh));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[5], &(graphptr->xspan));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetDoubleFromObj(interp, argv[6], &(graphptr->ylow));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetDoubleFromObj(interp, argv[7], &(graphptr->yhigh));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[8], &(graphptr->yspan));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[9], &(graphptr->range));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[10], &(graphptr->xsize));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    
    if (argc-1 != 10+graphptr->xsize) {
      sprintf(current, "Got %d args for graph of %d datapoints -- need %d",
	      argc-1, graphptr->xsize, 10+graphptr->xsize);
      Tcl_SetStringObj(resultPtr, current, -1);
      return TCL_ERROR;
    } /* if(error) */

    graphptr->points = new int[graphptr->xsize];
    for(count=0;count<graphptr->xsize;count++) {
      Tcl_GetIntFromObj(interp, argv[count+11], &(graphptr->points[count]));
    }
    return TCL_OK;

 case USEGRAPH:
    error = Tcl_GetDoubleFromObj(interp, argv[3], &xval);
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    Tcl_SetDoubleObj(resultPtr, graphpoint(xval, index));
    return TCL_OK;

  default:
    sprintf(current, "graph_table does not support action %d", action);
    Tcl_SetStringObj(resultPtr, current, -1);
    return TCL_ERROR;
  } /* end(switch,action) */
}

/* This does the same as compare_instance_status with Tcl_Obj lists instead
of arrays. It will put shorter lists in front of longer, though they should
always be the same length. */

int obj_compare_instance_status(Tcl_Obj* Obj, Tcl_Obj* RefObj) {
  int count, num1, num2, val1, val2;
  Tcl_Obj **objVals, **refVals;

  Tcl_ListObjGetElements(NULL, Obj, &num1, &objVals);
  Tcl_ListObjGetElements(NULL, RefObj, &num2, &refVals);
  for (count=0; count<num1 && count<num2; count++) {
    Tcl_GetIntFromObj(NULL, Obj, &val1);
    Tcl_GetIntFromObj(NULL, RefObj, &val2);
    if (val1<val2) return -1;
    if (val1>val2) return 1;
  }
  if (count<num1) return 1;
  if (count<num2) return -1;
  return 0;
}

/* This picks a Tcl_Obj from a list by matching its index (preceeding
element) with another obj. Returns empty obj if not found. ArrayVals
is the list of alternating index and value structures set by an I/O
tool. LocalSubObj is the index structure of the model list component
we are accessing. */

Tcl_Obj* pick_elt_vals(Tcl_Obj** arrayVals, int arrayLength, 
		       Tcl_Obj* localSubObj, int* arrayPosn) {
  int status;

  while (*arrayPosn<arrayLength) {
    status = obj_compare_instance_status(arrayVals[*arrayPosn], localSubObj);
    if (status==1) {
      /* Next input index too great: no input for this component */
      return Tcl_NewListObj(0, NULL);
    }
    /* Otherwise advance pointer */
    *arrayPosn += 2;
    if (status==0) {
      /* Last input index matches: return corresponding element */
      return arrayVals[*arrayPosn - 1];
    }
    /* Next input index too small: no component for this input. Try next. */
  }
  /* No more inputs in list, so none for this component */
  return Tcl_NewListObj(0, NULL);
}

/* This takes a model type and instance, list of integers and pointer into
that list, and returns, let us say, the first unused model index if the integers match the model's 
indices as far as the pointer, 0 if that is all the indices, and -1 if there
is a mismatch before the pointer */

int match_type(Model* localType, void* smHandle, int dims[], int* dim_place) {
  int id_handle[] = {2,0}, *cur_place, *short_tree, *id_ptr, id_val, id_count;
  short_tree = id_handle;
  id_count = 0;
  id_ptr = &id_count;
  cur_place = dims;
  while (cur_place < dim_place) {
    id_val = *(int *)localType->get_ptr(smHandle, &short_tree, 
					&id_ptr);
    if (id_val != *(cur_place++)) {
      return -1;
    }
    ++id_count;
    id_ptr = &id_count;
    short_tree = id_handle;
  }
  return *(int *)localType->get_ptr(smHandle, &short_tree, &id_ptr);
}
/* next two call one another so one needs to be declared in advance */
Tcl_Obj* fill_value(Model*, void*, int[], int, int*, int[], int*, Tcl_Obj*);

Tcl_Obj* fill_list_value(Model* localType, void** smHandle, int tree[], 
			 int type, int* use_dims, int dims[], int* dim_place) {
  Tcl_Obj *localObj, *localSubObj;
  int next_handle[] = {1,0}, match, arrayOut, *short_tree;
  localObj = Tcl_NewListObj(0, NULL);
  while (*smHandle && 
	 (match = match_type(localType, *smHandle, dims, dim_place)) != -1) {
    if (match == 0) {
      localObj = fill_value(localType, *smHandle, tree, type, use_dims, 
			    dim_place+1, dim_place+1, NULL);
      short_tree = next_handle;
      *smHandle = *(void**)(localType->get_ptr(*smHandle, &short_tree, 
						  NULL));
    } else {
      *dim_place=match;
      localSubObj = fill_list_value(localType, smHandle, tree, type,
				    use_dims, dims, dim_place+1);
      Tcl_ListObjLength(NULL, localSubObj, &arrayOut);
      if (arrayOut) {
	Tcl_ListObjAppendElement(NULL, localObj, Tcl_NewIntObj(match));
	Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
      }
    }
  }
  return(localObj);
}

/* fill_value extracts a list of values from the model. Type is the full id
path to the component whose values we are after. use_dims is array of array
sizes which we are to get all the values from. Dims is an array of ints
for the indices in the arrays we are getting values from, and dim_place is the
pointer into this array where we can add more values as we go through the loops
up to the sizes specified in use_dims. */

Tcl_Obj* fill_value(Model* localType, void* smHandle, int tree[], int type, 
		    int* use_dims, int dims[], int* dim_place, Tcl_Obj* nVs) {
  Tcl_Obj *localObj, *indObj, *localSubObj, **arrayVals, *eltVals;
  void* model_val_ptr;
  int *new_tree;
  int arrayLength, arrayPosn, arrayOut;
  int next_handle[] = {1,0}, id_handle[] = {2,0};
  switch (*use_dims) {
  case SEPARATE:
    new_tree = tree;
    while (*new_tree++ != SEPARATE) {}

    smHandle = *(void**)(localType->get_ptr(smHandle, &tree, &dims));
    localType = (Model*)*(new_tree++);
    return(fill_value(localType, smHandle, new_tree, type, 
		      use_dims+1, dim_place, dim_place, nVs));
  case MEMBERS:
  case RECORDS:
    new_tree = tree;
    while (*new_tree++ != -1) {}

    smHandle = *(void**)(localType->get_ptr(smHandle, &tree, &dims));
    localObj = fill_list_value(localType, &smHandle, new_tree, type, 
			       use_dims+1, dim_place+1, dim_place+1);
    break;
  case 0:
    model_val_ptr = localType->get_ptr(smHandle, &tree, &dims);
    switch (type) {
    case VALUELESS:
      localObj = Tcl_NewStringObj("sm", -1);
      break;
    case REAL:
      localObj = Tcl_NewDoubleObj(*(double *)model_val_ptr);
      if (nVs) {
	Tcl_GetDoubleFromObj(NULL, nVs, (double *)model_val_ptr);
      }
      break;
    case INTEGER:
    case ENUMERATED:
      localObj = Tcl_NewIntObj(*(int *)model_val_ptr);
      if (nVs) {
	Tcl_GetIntFromObj(NULL, nVs, (int *)model_val_ptr);
      }
      break;
    case FLAG:
      localObj = Tcl_NewBooleanObj(*(int *)model_val_ptr);
      if (nVs) {
	Tcl_GetBooleanFromObj(NULL, nVs, (int *)model_val_ptr);
      }
      break;
    case EXTERNAL:
      localObj = Tcl_NewStringObj("ex", -1);
      break;
    }
    break;
  default: /* value is a dimension of the array we are accessing */
    localObj = Tcl_NewListObj(0, NULL);
    if (nVs) {
      Tcl_ListObjGetElements(NULL, nVs, &arrayLength, &arrayVals);
      arrayPosn = 0;
    } else {
      eltVals = NULL;
    }
    for (*dim_place = 1; *use_dims >= *dim_place; ++*dim_place) {
      indObj = Tcl_NewIntObj(*dim_place);
      if (nVs) {
	eltVals = pick_elt_vals(arrayVals, arrayLength, indObj, &arrayPosn);
      }
      localSubObj = fill_value(localType, smHandle, 
		tree, type, use_dims+1, dims, dim_place+1, eltVals);
      Tcl_ListObjLength(NULL, localSubObj, &arrayOut);
      if (arrayOut) {
	Tcl_ListObjAppendElement(NULL, localObj, indObj);
	Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
      }
    }
    break;
  }
  return(localObj);
}

extern "C" int extractCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  Tcl_Obj *resultPtr, *newData;
  int iPosn, error;

  char spare[256];
  int dims[32], path[32];
  Model* mSpare;

  error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], (long int *)&modelHandle);
  if (error != TCL_OK) {
    return error;
  }
  int count;
  node_data_line *data_line;
  int current_dims[32];

  if (clientData) {
    iPosn = 5;
    newData = argv[4];
  } else {
    iPosn = 4;
    newData = NULL;
  }

  for (count=0;count+iPosn<argc;count++) {
	Tcl_GetIntFromObj(interp, argv[count+iPosn], current_dims + count);
  }
  resultPtr = Tcl_NewObj();

  if (!(data_line=searchinfo(Tcl_GetStringFromObj(argv[3], NULL), 
			     &mSpare, spare, dims, path))) {
    resultPtr = Tcl_NewStringObj("novalue", -1);
  } else {
    resultPtr = fill_value(modelType, modelHandle, path, data_line->datatype, 

			   dims+count, current_dims, current_dims+count,
			   newData);
    /*
    for (count=0; 4>count; ++count) {
      Tcl_ListObjAppendElement(interp, resultPtr, Tcl_NewIntObj(dims[count]));
    }
    */
  }
  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}

extern "C" int listobjCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
   int error;

   if (argc != 2) {
     interp->result = "One argument for listobjects please!";
     return TCL_ERROR;
   }
   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

   return list(modelType, interp);
}

extern "C" int randseedCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
   int seed, error;

   if (argc != 2) {
     interp->result = "One argument for randseed please!";
     return TCL_ERROR;
   }
   error = Tcl_GetIntFromObj(interp, argv[1], &seed);
   if (error != TCL_OK) {
	return error;
   }
   srand(seed);
   return TCL_OK;
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

extern "C" int random01Cmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
    Tcl_Obj *resultPtr;

   if (argc != 1) {
     interp->result = "No arguments for random01 please!";
     return TCL_ERROR;
   }
    resultPtr = Tcl_GetObjResult(interp);
    Tcl_SetDoubleObj(resultPtr, rand_fract());
   return TCL_OK;
}

/* Above is used by Tcl models. c++ models can easily include calls to rand()
themselves, but I want to test using the stub as a library, so let's have them
call this... */

double ame_rand(double lo, double hi) {
    return  lo + (hi-lo)*rand_fract();
}

extern "C" int SetConnDBCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  int count, count2, spare, error;
  Tcl_Obj** EltPtr;
  Tcl_Obj** PairPtr;
  Tcl_Obj** destObjs;
  connectRecord* currConnect;
   if (argc != 2) {
     interp->result = "One argument for set_connection_database please!";
     return TCL_ERROR;
   }
   // Move strings from the arg to a more easily searchable data structure

   error = Tcl_ListObjGetElements(interp, argv[1], &connCount, &EltPtr);
   if (error != TCL_OK) {
     return error;
   }
   connectData = new connectRecord[connCount];

   for (count=0; connCount>count; count++) {
     error = Tcl_ListObjGetElements(interp, EltPtr[count], &spare, &PairPtr);
     if (error != TCL_OK) {
       return error;
     }
     if (spare != 4) {
       interp->result="set_connection_database items need four elements each!";
       return TCL_ERROR;
     }
     currConnect = &connectData[count];
     currConnect->TopArc = strdup(Tcl_GetStringFromObj(PairPtr[0], NULL));
     currConnect->TopNode = strdup(Tcl_GetStringFromObj(PairPtr[1], NULL));
     currConnect->SourceNode = strdup(Tcl_GetStringFromObj(PairPtr[2], NULL));
     error = Tcl_ListObjGetElements(interp, PairPtr[3], 
				    &(currConnect->DestCount),
				    &destObjs);
     if (error != TCL_OK) {
       return error;
     }
     currConnect->Dests = new char*[currConnect->DestCount];
     for (count2=0; currConnect->DestCount>count2; count2++) {
       currConnect->Dests[count2] = strdup(Tcl_GetStringFromObj
					   (destObjs[count2], NULL));
     }

   }
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

void crash (Tcl_Interp *interp, char *cause) {
 /* oh dear. */
 /* oh dear, oh dear. */
  Tcl_VarEval(interp, "tk_messageBox -title {Authorization failure} -icon error -message {Bad ", cause, " authorization. Simile will now exit.} -type ok", NULL);
  Tcl_Exit(-1);
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

  my_md5(interp, textObj);
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

  k_ipad = new char[strlen(text)+80];
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
  
  delete k_ipad;

  md5Target = Tcl_NewStringObj(k_opad, 64);
  Tcl_AppendObjToObj(md5Target, Tcl_GetObjResult(interp));
  return my_hash(interp, md5Target);
}
#endif    
/* This gets the authorisation code that is needed for a particular combination
   of original simile edition and Prolog model specification */

extern "C" int GetAuthCodeCmd(ClientData clientData, Tcl_Interp *interp, 
			      int argc, Tcl_Obj *CONST argv[]) {
   if (argc != 2) {
     interp->result = "One argument for get_auth_code please!";
     return TCL_ERROR;
   }
   /* set ModelText [mime::getbody $Part($Model)] */
   if (Tcl_VarEval(interp, "set hvfe587gw938 [mime::getbody ", 
	       Tcl_GetStringFromObj(argv[1], NULL), "]", NULL) != TCL_OK) {
     return TCL_ERROR;
   }
   /* regexp {edition=([^,]*),} $ModelText all putativeEdition */
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

extern "C" int CheckAuthCodeCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 2) {
    interp->result = "One argument for check_auth_code please!";
    return TCL_ERROR;
  }
  /* set ModelText [mime::getbody $Part($Model)] */
  if (Tcl_VarEval(interp, "set hvfe587gw938 [mime::getbody ", 
		  Tcl_GetStringFromObj(argv[1], NULL), "]", NULL) != TCL_OK) {
    return TCL_ERROR;
  }
#ifdef USE_MY_HMAC
  if (my_hmac(interp, secret, Tcl_GetVar(interp, "hvfe587gw938", 0)) != TCL_OK) {
    return TCL_ERROR;
  }
#else
  if (Tcl_VarEval(interp, "::md5::hmac ", secret, " $hvfe587gw938", NULL) != TCL_OK) {
    return TCL_ERROR;
  }
#endif

  /* check it matches what we got before */
  if (strcmp(Tcl_GetVar(interp, "AuthCode", 0), Tcl_GetStringResult(interp))) {
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

extern "C" int GetVersionCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 1) {
    interp->result = "No arguments for get_simile_version please!";
    return TCL_ERROR;
  }
  interp->result = simileVersion;
  return TCL_OK;
}

extern "C" int loadcmdsCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 1) {
    interp->result = "No arguments for loadcommands please!";
    return TCL_ERROR;
  }

  /* Data about version etc held in dll for safety and convenience:
     these will become globals because we are not in the scope of a
     procedure */
  Tcl_SetVar2(interp, "userinfo", "edn", edition, 0);
  Tcl_SetVar2Ex(interp, "userinfo", "final_expiry", 
		Tcl_NewLongObj(SIM_FINAL_EXPIRY), 0);
  Tcl_SetVar2Ex(interp, "userinfo", "days_after_install", 
		Tcl_NewIntObj(SIM_DAYS_AFTER_INSTALL), 0);

  /* If this version requires a license then check we have the right
     one...

     if (Tcl_VarEval(interp, "::md5::hmac ", secret, 
      " $userinfo(name)@$userinfo(corp)%$userinfo(edn)", NULL) != TCL_OK) {

      Above used hmac but now we just append the secret and hash because
      it needs to be generated by PHP 
      ...so for a while it looked like this: */
#ifdef USE_MY_HMAC
  Tcl_Obj* dataCombo;
  dataCombo = Tcl_GetVar2Ex(interp, "userinfo", "name", TCL_LEAVE_ERR_MSG);
  if (dataCombo) {
    dataCombo = Tcl_DuplicateObj(dataCombo);
  } else {
    return TCL_ERROR;
  }
  Tcl_AppendStringsToObj(dataCombo, "%", edition, "^", secret, NULL);
  if (my_hash(interp, dataCombo) == TCL_ERROR) {
    return TCL_ERROR;
  }
#else
  if (Tcl_VarEval(interp, "::md5::md5 $userinfo(name)%$userinfo(edn)^", 
		  secret, NULL) != TCL_OK) {
    /* raise another error so user doesnt see secret in trace */
    Tcl_VarEval(interp, "::md5::md5 $userinfo(name)%$userinfo(edn)^<secret>", 
		NULL);
    return TCL_ERROR;
  }
#endif

#ifdef SIM_LICENSED
  /* check it matches what we got before */
  if (strcmp(Tcl_GetVar2(interp, "userinfo", "license_code", 0), 
	     Tcl_GetStringResult(interp))) {
    crash(interp, "program");
  }
#endif
  Tcl_CreateObjCommand(interp, "loadmodel", loadmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
    
    Tcl_CreateObjCommand(interp, "c_createmodel", createmodelCmd, 
			 (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "c_updatemodel", updatemodelCmd, 
			 (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "c_advancemodel", advancemodelCmd, 
			 (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "c_evalmodel", evalmodelCmd, 
			 (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "c_setstepmodel", setstepCmd, 
			 (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "c_exitmodel", exitmodelCmd, (ClientData)NULL,
        (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "getvalue", interfaceCmd, (ClientData)NULL,
        (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "graph_table", graphCmd, (ClientData)NULL,
        (Tcl_CmdDeleteProc *)NULL);
    
    Tcl_CreateObjCommand(interp, "extract", extractCmd, (ClientData)NULL,
        (Tcl_CmdDeleteProc *)NULL);
    
    Tcl_CreateObjCommand(interp, "insert", extractCmd, (ClientData)1,
        (Tcl_CmdDeleteProc *)NULL);
    
    Tcl_CreateObjCommand(interp, "getnodeid", getnodeidCmd, (ClientData)NULL,
        (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "listobjects", listobjCmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
    
    Tcl_CreateObjCommand(interp, "randseed", randseedCmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
    Tcl_CreateObjCommand(interp, "random01", random01Cmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand(interp, "set_connection_database", SetConnDBCmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

     Tcl_CreateObjCommand(interp, "get_auth_code", GetAuthCodeCmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

     Tcl_CreateObjCommand(interp, "check_auth_code", CheckAuthCodeCmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

     Tcl_CreateObjCommand(interp, "get_simile_verson", GetVersionCmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
    return TCL_OK;
  }

/*
 * The following declarations refer to internal Tk routines.  These
 * interfaces are available for use, but are not supported.
 */

//EXTERN void		TkConsoleCreate _ANSI_ARGS_((void));
//EXTERN int		TkConsoleInit _ANSI_ARGS_((Tcl_Interp *interp));

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AppInit --
 *
 *	This procedure performs application-specific initialization.
 *	Most applications, especially those that incorporate additional
 *	packages, will have their own version of this procedure.
 *
 * Results:
 *	Returns a standard Tcl completion code, and leaves an error
 *	message in interp->result if an error occurs.
 *
 * Side effects:
 *	Depends on the startup script.
 *
 * Note: 'version' is a global variable defined in the model,
 * and incremented for each new model program created -- this
 * should allow successive models to be built and executed in
 * c.
 *----------------------------------------------------------------------
 */

extern "C" 
#ifdef WIN32
__declspec( dllexport )
#endif
int Ame_dll_Init(Tcl_Interp *interp) {
 char pkgName[16];

   globInterp = interp;
    Tcl_CreateObjCommand(interp, "loadcommands", loadcmdsCmd, 
			(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
    
    sprintf(pkgName, "%d.%d.%s.%d", TCL_MAJOR_VERSION, TCL_MINOR_VERSION, 
	    simileVersion, FORUNIX);
    return Tcl_PkgProvide(interp, "Ame_dll", pkgName);
}
