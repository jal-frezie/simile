#include	<stdarg.h>
#include        <signal.h>
#include        <setjmp.h>

#include <dllcalls.h>
#include <backend.h>

graph_data_type** graph_data_pointer;

/* Pointers to functions in the stub: */
ame_rand_type* ame_rand_ref;
graphpoint_type* graphpoint_ref;
release_graph_data_type* release_graph_data_ref;
compare_instance_status_type* compare_instance_status;
model_requests_file_param_type* model_requests_file_param;
/* fetch_instance_type* fetch_instance_ref;
update_submodel_type* update_submodel_ref;
advance_submodel_type* advance_submodel_ref;
eval_submodel_type* eval_submodel_ref;
search_from_type* search_from_ref;
advance_ptr_type* advance_ptr_ref;
get_remote_value_type* get_remote_value;
*/

stat_check_type* stat_check;
show_model_mess_type* suppShowMess;

// excpData userStop;

struct InternalStop
{
  int lineNo;
  int userCode;

  InternalStop(int l, int c) {
    lineNo = l;
    userCode = c;
  }
};

int stop_on_id(int lineId, int code) {
  throw InternalStop(lineId,code);
//  userStop.targetId = lineId;
//  return (userStop.excpNo = code);
}

int stop(int code) { 
// this one for use in procedurally user-defined functions
  stop_on_id(0, code);
}

int lazy = 16384;
void abort_check (InstanceOfModel* instId) {
  if (!lazy--) {
    lazy=16384;
    if (stat_check(instId->partner)) {
      throw -101;
    }
  }
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
/* Special functions for getting values from lists according to contents of
   other lists -- because Simile uses implicit casts but this takes pointers,
   it has to cast explicitly */

template <class ResultClass, class PayloadClass, class CompareClass>
void assign_if_max(CompareClass sample, PayloadClass payload,
		   CompareClass* runner, ResultClass* pick) {
  if (sample>*runner) {
    *runner = sample;
    *pick = (ResultClass)payload;
  }
}

template <class ResultClass, class PayloadClass, class CompareClass>
void assign_if_min(CompareClass sample, PayloadClass payload,
		   CompareClass* runner, ResultClass* pick) {
  if (sample<*runner) {
    *runner = sample;
    *pick = (ResultClass)payload;
  }
}

/* Pass on calls to stub functions made directly by built model */

double ame_rand(double lo, double hi) {
  return (*ame_rand_ref)(lo, hi);
}

double graphpoint(double xval, int indx) {
  return (*graphpoint_ref)(xval, *graph_data_pointer, indx);
}
/*
void release_graph_data(graph_data_type* graph) {
  (*release_graph_data_ref)(graph);
}
*/
/*
void* fetch_instance(char* inst) {
  return (*fetch_instance_ref)(inst);
}

void update_submodel(char* id, void* inst, int step) {
  (*update_submodel_ref)(id, inst, step);
}

void advance_submodel(char* id, void* inst, int step) {
  (*advance_submodel_ref)(id, inst, step);
}

void int_eval_submodel(char* id, void* inst, int step) {
  int error;
  error = (*eval_submodel_ref)(id, inst, step, 0);
  if (error) {
    throw error;
  }
}

void ext_eval_submodel(char* id, void* inst, int step) {
  int error;
  error = (*eval_submodel_ref)(id, inst, step, 1);
  if (error) {
    throw error;
  }
}

void search_from(void* top, int section, void* found) {
  (*search_from_ref)(top, section, found);
}

// try doing this one locally
void* advance_ptr(void* mType, void* mInst) {
  return (*advance_ptr_ref)(mType, mInst);
}
*/
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
/*
double glob_element (double* arrptr, int phase) {
  return arrptr[phase];
}
*/
void InstanceOfModel::collect (void* dest, int record_id, int id_count, ...) {
  va_list argptr;
  int curIndices[32];
  int length;

  va_start(argptr, id_count);
  for (length=0; length<id_count; length++) {
    curIndices[length] = va_arg(argptr, int);
  }
  va_end(argptr);

  (*model_requests_file_param)(partner, dest, record_id, id_count, curIndices);
  // time value is dummy, there because we share the function definition
  // with the client side, which uses it
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
int init_pop (SMClass*** meta, double crNode, int ptCount, int channelId) {
  SMClass* submodelptr;
  int lastIndx;

  lastIndx = ptCount + max(0,(int)crNode);
  while (ptCount<lastIndx) {
    ++ptCount;
    if (prune(*meta, 1, ptCount)) { 
      // from cond construct -- note new indx
      submodelptr = **meta;
      submodelptr->new_instance = 0;
      **meta = submodelptr->next;
    } else { /* Instance exists */
      submodelptr = new SMClass;
      submodelptr->instanceid[0] = ptCount;
      submodelptr->new_instance = 1;
    }; /* end(cond,Instance exists) */
    submodelptr->parentId = 0; // all new
    submodelptr->channelId = channelId; // (val from i_p_m)
    // from cond construct
    submodelptr->next = **meta;
    **meta = submodelptr;
    *meta = &(submodelptr->next);
  }; /* end(while,loop) */
  return lastIndx;
}
  
template <class SMClass>
void init_pop_member (SMClass *new_one, int index, int parent, int channel) {
  new_one->instanceid[0] = index;
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
/*
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
*/
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
   graph_data_type* graphptr;

   //   array_data = (int *)(malloc(xsize*sizeof(int)));
   array_data = new int[xsize];
   
   va_start(argptr, xsize);
   right = va_arg(argptr, int);

   for (length=0;length<xsize;length++) {
	array_data[length] = right;
	right = va_arg(argptr,int);
   }
   va_end(argptr);

   graphptr = new graph_data_type;
   graphptr->index = index;
   graphptr->next = *graph_data_pointer;
   *graph_data_pointer = graphptr;

   graphptr->xlow = xlow;
   graphptr->xhigh = xhigh;
   graphptr->xspan = xspan;
   graphptr->ylow = ylow;
   graphptr->yhigh = yhigh;
   graphptr->yspan = yspan;
   graphptr->range = range;
   graphptr->xsize = xsize;
   graphptr->points = array_data;
}
/*
enum_data_type** enum_data_pointer;

void setup_enum_type_data(
   char *host, int mem_count, char* name, ...) {

   char* right;
   va_list argptr;
   int length;
   char** array_data;

   //   array_data = (int *)(malloc(xsize*sizeof(int)));
   array_data = new char*[mem_count];
   
   va_start(argptr, name);
   right = va_arg(argptr, char*);

   for (length=0;length<mem_count;length++) {
	array_data[length] = right;
	right = va_arg(argptr, char*);
   }
   va_end(argptr);

   *enum_data_pointer = new enum_data_type(host, name, mem_count, array_data, 
					   *enum_data_pointer);
}

/* Some c++ do not allow either abs to be overloaded with doubles, or fabs
   with ints, so translate to myabs which works for both */

int myabs(int a) {
  return abs(a);
}
double myabs(double a) {
  return fabs(a);
}

/* Do same for pow, just in case -- absolute power corrupts absolutely -- 
actually not, cos an int to an int can also be a float if 2nd is -ve */

int step_list(int **dim_list, int unused) {
  return *(*dim_list)++;
}

BOOLEAN requests_record_count(int *dim_list) {
  return (*dim_list == REQ_COUNT);
}

void discard_instance(void* instanceId) {
}

int following(int lo) {
  return lo+1;
}

int preceding(int lo) {
  return lo-1;
}

int first(int lo) {
  return lo==1;
}
