extern "C" 
#ifdef WIN32
__declspec( dllexport )
#endif
     void* do_createmodel(void) {
  return (void*)new AME_model;
}


/* Procedures for accessing the model now also require the handle of the 
instance to use. Previously these came straight out of model.c; now they
are put inside a class wrapper, so we must here turn the handle back into
a class pointer before calling them. */

#ifdef WIN32
extern "C" __declspec( dllexport ) double get_version(void);
extern "C" __declspec( dllexport ) void do_updatemodel(void*, double, int);
extern "C" __declspec( dllexport ) void do_evalmodel(void*, double, int, 
     BOOLEAN);
extern "C" __declspec( dllexport ) void do_setstep(double, int);
extern "C" __declspec( dllexport ) void do_exitmodel(void*);
#else
extern "C" double get_version(void);
extern "C" void do_updatemodel(void*, double, int);
extern "C" void do_evalmodel(void*, double, int, BOOLEAN);
extern "C" void do_setstep(double, int);
extern "C" void do_exitmodel(void*);
#endif

/* version needs its own special procedure because any other might change
   and cause a crash before version mismatch is detected */
double get_version() {
  return(simile_version);
}

void do_updatemodel(void* handle, double time, int phase) {
  ((AME_model *)handle)->updatemodel(time, phase);
}

void do_evalmodel(void* handle, double time, int phase, BOOLEAN exo) {
  if (exo) {
    ((AME_model *)handle)->ext_evalmodel(time, phase);
  } else {
    ((AME_model *)handle)->int_evalmodel(time, phase);
  }
}

void do_exitmodel(void* handle) {
  ((AME_model *)handle)->do_exitmodel();
}


/* setstep: the model class instances contain an array of doubles called
dts representing the time steps at the various phases. This function reaches
in and sets one of them. */

void do_setstep(double time, int phase) {
  dts[phase] = time;
}

extern "C" 
#ifdef WIN32
__declspec( dllexport )
#endif
void* burrow_to(void* level, int** id_meta, int** dim_list) {
  while (**id_meta>0) { /* 0 means end of tree, -1 means vm level,
-2 means nested separate-dll submodel */
    level = ((submodeltype*)level)->get_pointer(step_list(id_meta,1),dim_list);
  }
  return(level);
};

/* This is called only when we create the type, to return model constants */
extern "C" 
#ifdef WIN32
__declspec( dllexport )
#endif
  int get_count(void* useClassPtr, void* ame_rand_ptr, 
void* release_graph_data_ptr, 
void* compare_instance_status_ptr, 
void* get_value_pointer_ptr, 
void* fetch_instance_ptr,
void* update_submodel_ptr,
void* eval_submodel_ptr,
void* search_from_ptr,
void* advance_ptr_ptr,
void* get_remote_value_ptr, int* phases, 
node_data_line** data_ptr, graph_data_type** graph_ptr,
int* arc_count, char*** arc_id_list) {
  /* Stub is telling us... */
  myClassPtr = useClassPtr;

  /* ...and also giving us function pointers to save us using the linker... */
  ame_rand_ref = (ame_rand_type*)ame_rand_ptr;
  release_graph_data_ref = (release_graph_data_type*)release_graph_data_ptr;
  compare_instance_status = (compare_instance_status_type*)compare_instance_status_ptr;
  get_value_pointer = (get_value_pointer_type*)get_value_pointer_ptr;
  fetch_instance_ref = (fetch_instance_type*)fetch_instance_ptr;
  update_submodel_ref = (update_submodel_type*)update_submodel_ptr;
  eval_submodel_ref = (eval_submodel_type*)eval_submodel_ptr;
  search_from_ref = (search_from_type*)search_from_ptr;
  advance_ptr_ref = (advance_ptr_type*)advance_ptr_ptr;
  get_remote_value = (get_remote_value_type*)get_remote_value_ptr;

  /* ...and we are telling stub... */
  *phases = phasecount;
  *data_ptr = nodedata;
  *graph_ptr = graphdata;
  *arc_count = (sizeof inputArcs)/sizeof(char*)-1; /* don't include filler */
  *arc_id_list = inputArcs;
  return((sizeof nodedata)/sizeof(node_data_line));
}

/**********************************************************************/

/*
con la LoadLibrary e la pstub sono inutili, facciamo rifermento direttamente alle orinali!
extern "C" double __stdcall GetVersion()
{
  return(get_version());
}
extern "C" void* __stdcall DoCreateModel(void)
{
return (void*)new AME_model;
}
*/

/* GetNodeCount.... in realta' torna la stessa cosa di get_count...
  ... ma per il momento e' troppo pesante e quindi questa 
e' piu' comoda per ora!!

--- dichiaramole __declspacc come piace a lui cosi' il simile+MinchW non rompe ----
*/
#ifdef WIN32
extern "C" __declspec( dllexport ) 
/*extern "C"  __stdcall */

int GetNodeCount(void* useClassPtr)
{
return((sizeof nodedata)/sizeof(node_data_line));
}

struct pass_data_line {
  char   name[16];
  int    datatype;
  int    eval;
  int    dims[32];
  int    path[32];
  int    graph;
  double min;
  double def;
  double max;
  int    compclass;
  char   caption[256];
};

extern "C" __declspec( dllexport ) 
/*extern "C" __stdcall */ int GetNodeData(int n,struct pass_data_line *PassStruct)
{ 
int i;
strcpy(PassStruct->name ,nodedata[n].name);
PassStruct->datatype =nodedata[n].datatype;
PassStruct->eval =nodedata[n].eval;
for(i=0;i<32;i++)
{
PassStruct->dims[i] =nodedata[n].dims[i];
PassStruct->path[i] =nodedata[n].path[i];
}
PassStruct->graph =nodedata[n].graph;
PassStruct->min =nodedata[n].min;
/* PassStruct->def =nodedata[n].def; */
PassStruct->max =nodedata[n].max;
PassStruct->compclass =nodedata[n].compclass;
strcpy(PassStruct->caption ,nodedata[n].caption);
return n;
}
#endif
