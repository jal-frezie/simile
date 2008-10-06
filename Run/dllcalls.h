#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdlib.h> /* for rand procedure used by tcl models */
#include <time.h>
#include <omp.h>

/* Primitives
---------- */
#define	FALSE		0
#define	TRUE		1

#define BOOLEAN         int
/* possibly needed for Unix */

/* component types */
#define	SUBMODEL	0
#define VARIABLE        1
#define COMPARTMENT     2
#define FLOW            3
#define CONDITION       4
#define CREATION        5
#define REPRODUCTION    6
#define IMMIGRATION     7
#define LOSS            8
#define ALARM           9

/* data types -- zero or negative as they will end lists of dimensions */
#define	VALUELESS	0
#define REAL            -1
#define INTEGER         -2
#define FLAG            -3
#define OWNSIZED        -4
#define SPARSEARRAY     -5
#define ENUM_BASE       -10

/* source of value */
#define EXOGENOUS       0
#define DERIVED         1
#define TABLE           2
#define INPUT           3
#define SPLIT           4
#define GHOST           5

/* special dimensions */
#define RECORDS        -1
#define MEMBERS        -2
#define SEPARATE       -3
#define START_VM       -4
#define END_VM         -5

/* integration methods */
#define EULER           0
#define RUNGE_KUTTA     1

/* fill methods for time series */
#define USE_LAST        0
#define USE_CLOSEST     1
#define INTERPOLATE     2

#define SIMILE_VERSION	"5.3"
#define NEST 32

#ifdef __cplusplus
    #define FINDABLE extern "C"
#else
    #define FINDABLE
#endif
#ifdef WIN32
    #ifdef SHARELIB
	#define EXTDEC FINDABLE __declspec( dllexport )
    #else
	#define EXTDEC FINDABLE __declspec( dllimport )
    #endif
    #define EXPORT FINDABLE __declspec( dllexport )
#else
    #define EXTDEC FINDABLE
    #define EXPORT FINDABLE
#endif
/* type declaration for structure representing a graph */

typedef struct graph_data_type_t {
   double xlow;
   double xhigh;
   int xspan;
   double ylow;
   double yhigh;
   int yspan;
	int range;
   int xsize; /* assume I can't initialize it here */
   int* points;

   int index;
   struct graph_data_type_t* next;
   /*
   graph_data_type(int newIndex, graph_data_type* prev) {
     index = newIndex;
     next = prev;
   }

   ~graph_data_type() {
     delete(points);
     if (next) {
       delete(next);
     }
   }
   */
} graph_data_type; /* end of graph data type decl */


graph_data_type* find_graph (int index, graph_data_type* use_graph_pointer) {
  while (use_graph_pointer && use_graph_pointer->index != index) {
    use_graph_pointer = use_graph_pointer->next;
  }
  return(use_graph_pointer);
}
/*
class enum_data_type {
public:
  char* host;
  char* name;
  int mem_count;
  char** mems;

  enum_data_type* next;

  enum_data_type(char* newHost, char* newName,
		 int newMC, char** newMems, enum_data_type* prev) {
    host = newHost;
    name = newName;
    mem_count = newMC;
    mems = newMems;
    next = prev;
  }

   ~enum_data_type() {
     delete(mems);
     if (next) {
       delete(next);
     }
   }
}; /* end of enum data type decl */

/* above to be phased out -- we now have... */
typedef struct enum_type_data_t {
  int count;
  const char* name;
  char** members;
} enum_type_data; /* end of enum type data type decl */

/* This declares the structure used by the generated code to hold metadata
about model components. It is repeated in the stub ame_cmx.cpp to access fields
outside the dll. */

typedef struct node_data_line_t {
  char name[16];
  int datatype;
  int enum_type_count;
  enum_type_data* enum_type_ptrs;
  int eval;
  int dims[32];
  int path[32];
  int graph;
  double min;
  double max;
  int compclass;
  char *strings[4];
} node_data_line; /* end(class,node_data_line) */
/*
typedef struct connectRecord_t {
  char* TopArc;
  char* TopNode;
  char* SourceNode;
  int DestCount;
  char** Dests;
} connectRecord;
*/

// class for storing data about exceptions while model is running
typedef struct excpData_t {
  int excpNo;
  int targetId;
} excpData;

// Declaration for procedure types found in the model dll by the shank
typedef int getcount_type(void*, void*, void*, void* ,void*,
			  void*, void*, void*, void*,
			  int*, node_data_line**, double**, excpData**);
typedef double getversion_type(void);
typedef void* createmodel_type(void);
typedef int setstep_type(double, int);
typedef void updatemodel_type(void*, int);
typedef void advancemodel_type(void*, int);
typedef int evalmodel_type(void*, int);
typedef void* getpointer_type(void*, int**, int**);
typedef void exitmodel_type(void*);

/* this is defined in the stub, which is loaded as a library...well it
   used to be, but now once the stub has loaded the dll it just sends
   over the pointers to all the functions used by the dll (the other
   method didn't work in win98) */

typedef double ame_rand_type(double, double);
typedef BOOLEAN interact_gui_type(void*, BOOLEAN, double);
typedef double graphpoint_type(double, graph_data_type*, int);
typedef void release_graph_data_type(graph_data_type*);
typedef int compare_instance_status_type (const int*, const int*, int);
typedef void get_value_pointer_type(void*, void*, int, int, int*);
/*
typedef void* fetch_instance_type(char*);
typedef void update_submodel_type(char*, void*, int);
typedef void advance_submodel_type(char*, void*, int);
typedef int eval_submodel_type(char*, void*, int, BOOLEAN);
typedef void search_from_type(void*, int, void*);
typedef void* advance_ptr_type(void*, void*);
typedef void* get_remote_value_type(void*, void*, int, int, int*);
*/
typedef int stat_check_type(void*);

typedef void showMess_type(char*);

/* These are for passing procedure addresses in the shim to the shank */

// typedef void get_value_pointer_type(void*, char*, int, int*);
// (its same as above)

/* Defined in the shank, used by the shim */
EXTDEC char* load_model(char*, char*, long int*);
EXTDEC void* use_array_for_params(char*);
EXTDEC int param_array_size(char*);
EXTDEC int clear_time_point_elts(char*);
EXTDEC double* get_wrap_ptr(char*);
EXTDEC int* get_fill_ptr(char*);
EXTDEC int create_time_point(char*, double);
EXTDEC void* find_next_timept_space(char*, double*);
//EXTDEC int set_record_list(char*, int*, int);
//EXTDEC int set_tp_records(char*, int*, double, int);
//EXTDEC int set_param_array_elt(char*, double, int*);
//EXTDEC int set_time_point_elt(char*, double, double, int*);
EXTDEC char* get_param_ptr_and_dims(char*, int**);
EXTDEC int get_timepoint_ptr_and_dims(char*, double, char**, int**);
EXTDEC void free_bloc_records(char*, int*);
EXTDEC int set_bloc_record_count(char*, int*, int*, int);
EXTDEC void set_bloc_element(char*, int*, int*, double);

EXTDEC get_value_pointer_type get_value_pointer;
EXTDEC int get_node_count(long int);
EXTDEC node_data_line* get_data_line(long int, int);
EXTDEC long int get_node_model_id(char*);
EXTDEC void release_graph_data(graph_data_type*);
EXTDEC graphpoint_type graphpoint;
EXTDEC double rand_fract();
EXTDEC graph_data_type** get_graph_base(long int);
EXTDEC node_data_line* searchinfo(char*, long int*, char*, 
				  int*, int*, enum_type_data**);
EXTDEC node_data_line* nodlin_from_id(long int, int);
EXTDEC long int fetch_top_instance(long int);

EXTDEC excpData* reset(long int, long int, int);
EXTDEC excpData* execute(long int, long int, int, double, double*, double);
EXTDEC int setstep(long int, double, int);
EXTDEC char* myexit(long int, long int);

EXTDEC void* get_ptr(long int, long int, int**, int**);
EXTDEC char* getNodeId(long int, char*);

EXTDEC void proc_pointers_for_shank(get_value_pointer_type*, interact_gui_type*,
				    showMess_type*, char*);

/* new class that will hold any set of values for a model component, hopefully
   replacing the regularData class. */

typedef struct nodeValues_t {
  int dimSpecs[32];
  char* contents;
} nodeValues;

// convenience class for accessing levels consisting of size and pointer
typedef struct sizeAndPtr_t {
  int size;
  char* ptr;
} sizeAndPtr;

// procedure called for each value in a nodeValues
typedef void valCallback(void*, int, void*);

// use of nodeValues class
EXTDEC nodeValues* get_raw_values(char*, long int);
EXTDEC void translate_dims(int[], int[], int[], int, BOOLEAN);
EXTDEC void call_for_each_val(int*, char*, int, valCallback, void*);
EXTDEC void free_bloc_data(char*, int*);

/* use of regularData class (replaced by above)
EXTDEC long int createRegularData (void);
EXTDEC void deleteRegularData (long int);
EXTDEC int rdSetToNodeValue(long int, long int, long int, char*);
EXTDEC int rdDimensionality(long int);
EXTDEC int rdDatatype(long int);
EXTDEC int rdBound(long int, int);
EXTDEC void* rdLocateElement(long int old, int* indices);
*/
