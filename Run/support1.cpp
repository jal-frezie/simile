#include	<stdarg.h>
#include        <signal.h>
#include        <setjmp.h>

#include <dllcalls.h>
#include <backend.h>

//graph_data_type** graph_data_pointer;


int InstanceOfModel::stop_on_id(int lineId, int code) {
  // this stops execution immediately
  //  throw InternalStop(lineId,code);
  // this causes it to stop at end of step
  userStop.targetId = lineId;
  report_context();
  return (userStop.excpNo = code);
}

InstanceOfModel* curInst;
int stop(int code) { 
// this one for use in procedurally user-defined functions
  return curInst->stop_on_id(0, code);
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

// add pointer to saved data before sampling sketch graph in shank
double InstanceOfModel::graph_lookup(double xval, int indx) {
  return graphpoint(xval, c_graphdata, indx);
}

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

template <class GridSMClass>
class nbrlist {
public:
  GridSMClass *payload;
  int instanceid[1];
  nbrlist *next;
};

template <class GridSMClass>
void fill_nbr_ptrs (GridSMClass* parent, GridSMClass* trail[], 
		    int trailPt, int shape, int trailLen) {
  int off, idx = 0;
  parent->nbrs = 0; // in case altering membership
  // shape is 0 for rect, 1 for hex odd row (to right), 2 for even row
  // nbr refs are added to the list in order, but bottom up so list has them
  // in reverse order -- hence search can break if too-low index found...
  for (off=0; off<4; ++off) {
    if (off==4-2*shape) continue;
    ++idx;
    GridSMClass* cur_nbr = trail[(trailPt+(off==3?-1:off))%trailLen];
    if (cur_nbr) {
      nbrlist <GridSMClass> *tempIntSat = new nbrlist <GridSMClass>;
      tempIntSat->instanceid[0] = idx;
      tempIntSat->payload = cur_nbr;
      tempIntSat->next = parent->nbrs;
      parent->nbrs = tempIntSat;
      
      tempIntSat = new nbrlist <GridSMClass>;
      tempIntSat->instanceid[0] = (shape?7:9)-idx;
      tempIntSat->payload = parent;
      tempIntSat->next = cur_nbr->nbrs;
      cur_nbr->nbrs = tempIntSat;
    }  // if (cur_nbr)
  } // for off,
  trail[trailPt%trailLen] = parent;
}

template <class GridSMClass>
void make_fixed_nbr_list (GridSMClass* parent, int shape, int rows, int columns,
			  int rowId, int columnId) {
  int idx = 0, oRow, oCol; 
  if (shape==1 || rowId%2==1) 
    --shape; // shape now as in last proc
  // order of addition is chosen to match what happens with vm grid
  parent->nbrs = NULL;
  for (oRow=-1; oRow<=1; ++oRow) {
    for (oCol=-1; oCol<=1; ++oCol) {
      if (oCol*(2*shape-3)==abs(oRow)) continue;
      ++idx;
      if (rowId+oRow>0 && rowId+oRow<=rows && 
	  columnId+oCol>0 && columnId+oCol<=columns) {
	nbrlist <GridSMClass> *tempIntSat = new nbrlist <GridSMClass>;
	tempIntSat->instanceid[0] = idx;
	tempIntSat->payload = parent+columns*oRow+oCol;
	tempIntSat->next = parent->nbrs;
	parent->nbrs = tempIntSat;
      }
    }
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
  // *(int*)dest = 3; return; // debug parameter setup
  va_start(argptr, id_count);
  for (length=0; length<id_count; length++) {
    curIndices[length] = va_arg(argptr, int);
  }
  va_end(argptr);

  handle_model_param_request(partner, dest, record_id, 
			       FALSE, id_count, curIndices);
}
   
template <class modeldata> 
void delay<modeldata>::empty () {
  series<modeldata> *where;
  
  while (head) {
    where = head ->next;
    delete head;
    head = where;
  }
}

template <class modeldata> 
void delay<modeldata>::insert (double when, modeldata what, double *expect) {
  series<modeldata> **where;
  if (what) {
    where = &head;
    while (*where && (*where)->timepoint<when) 
      where = &(*where)->next;
    *where = new series<modeldata>(when, what, *where);
  }
  if (head && head->timepoint<*expect)
    *expect = head->timepoint; // set prediction
}

template <class modeldata> 
modeldata delay<modeldata>::retract (double when, BOOLEAN clear) {
  modeldata unload;
  series<modeldata> *where;
  
  where = head;
  unload = 0;
  while (where && where->timepoint <= when) {
    unload = where->payload;
    where = where->next;
    if (clear) {
      delete head;
      head = where;
    }
  }
  return unload;
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
	 (status = compare_instance_status((*metaptr)->instanceid,
				   curIndices, id_count)) == -1) {
    submodelptr = *metaptr;
    *metaptr = submodelptr->next;
    delete submodelptr;
  };
  delete curIndices;
  return !status;
}
/*
template <class SMClass>
SMClass* locate (SMClass* ptr, int soughtIndex) {
  while (ptr && ptr->instanceid[0] != soughtIndex)
    ptr = ptr->next;
  return ptr;
}
*/
template <class SMClass>
SMClass* locate (SMClass* ptr, int id_count, ...) {
  int status = 1, length;
  va_list argptr;
  int *curIndices;

  curIndices = new int[id_count];
  va_start(argptr, id_count);
  for (length=0; length<id_count; length++) {
    curIndices[length] = va_arg(argptr, int);
  }
  va_end(argptr);
   
  while (ptr && 
	 (status = compare_instance_status(ptr->instanceid,
					   curIndices, id_count)) == -1) {
    ptr = ptr->next;
    // delete submodelptr;
  };
  delete curIndices;
  if (status) // no exact match
    return NULL;
  else
    return ptr;
}

template <class SMClass>
BOOLEAN locate_nbr (nbrlist <SMClass> *ptr, SMClass **metaptr, 
		    int soughtIndex) {
  while (ptr) {
    if (ptr->instanceid[0] == soughtIndex) {
       *metaptr = ptr->payload;
       return 1;
    }
    ptr = ptr->next;
  }
  return 0;
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
    // submodelptr->parentId = 0; // no need with in_progenitor
    submodelptr->baseptrs[0] = NULL;
    submodelptr->channelId = channelId; // (val from i_p_m)
    // from cond construct
    submodelptr->next = **meta;
    **meta = submodelptr;
    *meta = &(submodelptr->next);
  }; /* end(while,loop) */
  return lastIndx;
}
  
template <class SMClass>
void init_pop_member (SMClass *new_one, int index, int channel) {
  new_one->instanceid[0] = index;
  new_one->baseptrs[0] = NULL; // overwritten in generated code if has parent
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

void InstanceOfModel::setup_graph_data(
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
   graphptr->next = c_graphdata;
   c_graphdata = graphptr;

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

// declarations of procs in support.cpp
int pipeRead(int, char*, int);
int pipeWrite(int, char*, int);
