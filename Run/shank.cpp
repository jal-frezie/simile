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

char* xsimileVersion;
int connCount;
connectRecord* connectData;
showMess_type* showMessLocal;
char globMess[256];

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

void append_ints_to_null(int* dest, int* src, int sep, int sep2) {
  while (*dest) { dest++; }
  if (sep) { *(dest++)=sep; }
  if (sep2) { *(dest++)=sep2; }
  do { *(dest++)= *src; } while (*src++);
}
  
ame_rand_type* ame_rand;
get_value_pointer_type* get_value_pointer;
fetch_instance_type fetch_instance;
update_submodel_type update_submodel;
advance_submodel_type advance_submodel;
eval_submodel_type eval_submodel;
search_from_type search_from;
advance_ptr_type advance_ptr;
get_remote_value_type get_remote_value;

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
//sprintf(globMess, "Loaded %ld", handle);
//showMess(globMess);

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

  /* Following can go anyway if new ones outside the model class work
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

  Now for the locally defined model class procedures */
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

/* listable class for enumerated types, similar to above */
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
};

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
				    ame_rand_type* ame_rand_ptr,
				    showMess_type* showMess_ptr,
				    char* simileVersionPtr,
				    connectRecord*** connectDataPtr, 
				    int** connCountPtr) {
  get_value_pointer = get_value_pointer_ptr;
  ame_rand = ame_rand_ptr;
  showMessLocal = showMess_ptr;
  xsimileVersion = simileVersionPtr;
  // put pointers to our connection database globals into the given locations 
  *connectDataPtr = &connectData;
  *connCountPtr = &connCount;
}

int setstep(double starttime, int phase) {
  listNodeModel* nodeModelPoint = nodeModelList;
  Model* modelType;

  while (nodeModelPoint) {
    modelType = nodeModelPoint->model;
    if (modelType->phases>=abs(phase)) {
      modelType->setstepmodel(starttime, phase);
    }
    nodeModelPoint = nodeModelPoint->next;
  }
  return (nodeModelList->model)->phases;
}

char* myexit(long int modelType, long int modelHandle) {  
  if (modelHandle) { 
    ((Model*)modelType)->exitmodel((void*)modelHandle);
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
