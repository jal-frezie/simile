#include	<stdio.h>
#include	<string.h>
#include	<stdlib.h>
#include	<stdarg.h>
#include        <signal.h>
#include        <setjmp.h>
#include	<math.h>

#include <dllcalls.h>

/* Every dll has a variable to hold the id of the model type instance it
   represents */
void* myClassPtr;

    
int stop(int code) {
  throw code;
}

/* Pointers to functions in the stub: */
ame_rand_type* ame_rand_ref;
graphpoint_type* graphpoint_ref;
release_graph_data_type* release_graph_data_ref;
compare_instance_status_type* compare_instance_status;
get_value_pointer_type* get_value_pointer;
fetch_instance_type* fetch_instance_ref;
update_submodel_type* update_submodel_ref;
advance_submodel_type* advance_submodel_ref;
eval_submodel_type* eval_submodel_ref;
search_from_type* search_from_ref;
advance_ptr_type* advance_ptr_ref;
get_remote_value_type* get_remote_value;

/* Pass on calls to stub functions made directly by built model */

double ame_rand(double lo, double hi) {
  return (*ame_rand_ref)(lo, hi);
}

double graphpoint(double xval, int indx) {
  return (*graphpoint_ref)(xval, indx);
}

void release_graph_data(graph_data_type* graph) {
  (*release_graph_data_ref)(graph);
}

void* fetch_instance(char* inst) {
  return (*fetch_instance_ref)(inst);
}

void update_submodel(char* id, void* inst, double time, int step) {
  (*update_submodel_ref)(id, inst, time, step);
}

void advance_submodel(char* id, void* inst, double time, int step) {
  (*advance_submodel_ref)(id, inst, time, step);
}

void int_eval_submodel(char* id, void* inst, double time, int step) {
  int error;
  error = (*eval_submodel_ref)(id, inst, time, step, 0);
  if (error) {
    throw error;
  }
}

void ext_eval_submodel(char* id, void* inst, double time, int step) {
  int error;
  error = (*eval_submodel_ref)(id, inst, time, step, 1);
  if (error) {
    throw error;
  }
}

void search_from(void* top, int section, void* found) {
  (*search_from_ref)(top, section, found);
}

/* try doing this one locally */
void* advance_ptr(void* mType, void* mInst) {
  return (*advance_ptr_ref)(mType, mInst);
}

/* class definition and handling procedure for extra variables used in
   complicated integration methods */

class diffs {
public:
  diffs () {
    current_offset = 0;
    cumulative_value = 0;
  }
  ~diffs () {
  }
  double current_offset, cumulative_value;
};

double stage_incr (diffs*, int, double);
double step_incr (int, double);
int at_time_step ();
int loses (double, int);

/* abstract base class for submodels, with extractor virtual function */
class submodeltype {
public:
  virtual void* get_pointer(int id, int** dims) = 0;
};

/* Fn template for deleting a linked list of models -- if non-null, 
calls itself for the on pointer before deleting instance

template <class SMClass>
void delete_list (SMClass *ptr) {
  if (ptr) {
    delete_list(ptr->next);
    delete ptr;
  }
}

Above version is very elegant and recursive, but sadly causes stack
overflow for that very reason when deleting very long lists of
submodels. So instead...
*/

template <class SMClass>
void delete_list (SMClass *ptr) {
  SMClass *next_ptr;

  while (ptr) {
    next_ptr = ptr->next;
    delete ptr;
    ptr = next_ptr;
  }
}

double glob_element (double* arrptr, int phase) {
  return arrptr[phase];
}

template <class DestClass>
void collect (DestClass* dest, char* node_id, int id_count, ...) {
  va_list argptr;
  int *curIndices;
  int length;

  curIndices = new int[id_count];
  va_start(argptr, id_count);
  for (length=0; length<id_count; length++) {
    curIndices[length] = va_arg(argptr, int);
  }
  va_end(argptr);

  (*get_value_pointer)(dest, node_id, id_count, curIndices);
}
   
template <class SMClass>
BOOLEAN prune (SMClass **metaptr, int id_count, ...) {
  int status = 1, length;
  SMClass *submodelptr;
  va_list argptr;
  int *curIndices;

  curIndices = new int[id_count];
  va_start(argptr, id_count);
  for (length=0; length<id_count; length++) {
    curIndices[length] = va_arg(argptr, int);
  }
  va_end(argptr);
   
  while (*metaptr && 
	 (status = (*compare_instance_status)((*metaptr)->instanceid,
				   curIndices, id_count)) == -1) {
    submodelptr = *metaptr;
    *metaptr = submodelptr->next;
    delete submodelptr;
  };
  delete curIndices;
  return !status;
}

template <class SMClass>
void init_pop_member (SMClass *new_one, int index, int parent, int channel) {
  new_one->instanceid[0] = index;
  new_one->instanceid[1] = 0;
  new_one->parentId = parent;
  new_one->channelId = channel;
  new_one->new_instance = 1;
  new_one->next = 0;
}

int* arrange_indices(int id_count, ...) {
  int length;
  va_list argptr;
  int *curIndices;

  curIndices = new int[id_count+1];
  va_start(argptr, id_count);
  for (length=0; length<id_count; length++) {
    curIndices[length] = va_arg(argptr, int);
  }
  va_end(argptr);
  curIndices[length] = 0;
  return curIndices;
}

BOOLEAN import_boolean(int level, void* topInstPtr, int arcId, int* indices) {
  BOOLEAN* gotValue;
  gotValue = (BOOLEAN*)(*get_remote_value)(myClassPtr, topInstPtr, level,
					arcId, indices);
  delete(indices);
  if (gotValue) {
    return *gotValue;
  } else {
    return 0;
  }
}
  
int import_int(int level, void* topInstPtr, int arcId, int* indices) {
  int* gotValue;
  gotValue = (int*)(*get_remote_value)(myClassPtr, topInstPtr, level,
				    arcId, indices);
  delete(indices);
  if (gotValue) {
    return *gotValue;
  } else {
    return 0;
  }
}
  
double import_real(int level, void* topInstPtr, int arcId, int* indices) {
  double* gotValue;
  gotValue = (double*)(*get_remote_value)(myClassPtr, topInstPtr, level,
				       arcId, indices);
  delete(indices);
  if (gotValue) {
    return *gotValue;
  } else {
    return 0.0;
  }
}
  
void* import_ptr(int level, void* topInstPtr,
		 int arcId, int* indices) {
  void** gotValue;
  gotValue = (void**)(*get_remote_value)(myClassPtr, topInstPtr, level, 
				      arcId, indices);
  delete(indices);
  if (gotValue) {
    return *gotValue;
  } else {
    return NULL;
  }
}
/*  
void insert_graph_data(
   graph_data_type *graph_data_pointer,
   double xlow,
   double xhigh,
   int xspan,
   double ylow,
   double yhigh,
   int yspan,
	int range,
   int size,
   int *array_data) {

   graph_data_pointer->xlow = xlow;
   graph_data_pointer->xhigh = xhigh;
   graph_data_pointer->xspan = xspan;
   graph_data_pointer->ylow = ylow;
   graph_data_pointer->yhigh = yhigh;
   graph_data_pointer->yspan = yspan;
   graph_data_pointer->range = range;
   graph_data_pointer->xsize = size;
   graph_data_pointer->points = array_data;
}
*/
graph_data_type** graph_data_pointer;

void setup_graph_data(
   int index,
   double xlow,
   double xhigh,
   int xspan,
   double ylow,
   double yhigh,
   int yspan,
	int range,
   int xsize, ...) {

   va_list argptr;
   int length,right;
   int *array_data;

   //   array_data = (int *)(malloc(xsize*sizeof(int)));
   array_data = new int[xsize];
   
   va_start(argptr, xsize);
   right = va_arg(argptr, int);

   for (length=0;length<xsize;length++) {
	array_data[length] = right;
	right = va_arg(argptr,int);
   }
   va_end(argptr);

   *graph_data_pointer = new graph_data_type(index, *graph_data_pointer);
   (*graph_data_pointer)->xlow = xlow;
   (*graph_data_pointer)->xhigh = xhigh;
   (*graph_data_pointer)->xspan = xspan;
   (*graph_data_pointer)->ylow = ylow;
   (*graph_data_pointer)->yhigh = yhigh;
   (*graph_data_pointer)->yspan = yspan;
   (*graph_data_pointer)->range = range;
   (*graph_data_pointer)->xsize = xsize;
   (*graph_data_pointer)->points = array_data;
}

/*
 * Unix version: does not have min & max defined
 */
int min(int a, int b) {
  return a<b?a:b;
}
double min(int a, double b) {
  return a<b?a:b;
}
double min(double a, int b) {
  return a<b?a:b;
}
double min(double a, double b) {
  return a<b?a:b;
}
int max(int a, int b) {
  return a>b?a:b;
}
double max(int a, double b) {
  return a>b?a:b;
}
double max(double a, int b) {
  return a>b?a:b;
}
double max(double a, double b) {
  return a>b?a:b;
}

/* Some c++ do not allow either abs to be overloaded with doubles, or fabs
   with ints, so translate to myabs which works for both */

int myabs(int a) {
  return abs(a);
}
double myabs(double a) {
  return fabs(a);
}

/* Do same for pow, just in case -- absolute power corrupts absolutely */
int mypow(int a, int b) {
  return int(pow(a,b));
}
double mypow(int a, double b) {
  return pow(a,b);
}
double mypow(double a, int b) {
  return pow(a,b);
}
double mypow(double a, double b) {
  return pow(a,b);
}

int step_list(int **dim_list, int unused) {
  return *(*dim_list)++;
}

void discard_instance(void* instanceId) {
}
