#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdlib.h> /* for rand procedure used by tcl models */
#include <time.h>

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

/* data types */
#define	VALUELESS	0
#define REAL            1
#define INTEGER         2
#define FLAG            3
#define EXTERNAL        4

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

#define SIMILE_VERSION	"4.9"

#ifdef WIN32
    #ifdef SHARELIB
	#define EXTDEC __declspec( dllexport )
    #else
	#define EXTDEC __declspec( dllimport )
    #endif
    #define EXPORT __declspec( dllexport )
#else
    #define EXTDEC
    #define EXPORT
#endif
#define FINDABLE extern "C"

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
  char* name;
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
  char caption[256];
} node_data_line; /* end(class,node_data_line) */

typedef struct connectRecord_t {
  char* TopArc;
  char* TopNode;
  char* SourceNode;
  int DestCount;
  char** Dests;
} connectRecord;

/* this is defined in the stub, which is loaded as a library...well it
   used to be, but now once the stub has loaded the dll it just sends
   over the pointers to all the functions used by the dll (the other
   method didn't work in win98) */

typedef double ame_rand_type(double, double);
typedef BOOLEAN interact_gui_type(void*, int, double);
typedef double graphpoint_type(double, graph_data_type*, int);
typedef void release_graph_data_type(graph_data_type*);
typedef int compare_instance_status_type (const int*, const int*, int);
typedef void get_value_pointer_type(void*, void*, int, int, int*);
typedef void* fetch_instance_type(char*);
typedef void update_submodel_type(char*, void*, double, int);
typedef void advance_submodel_type(char*, void*, double, int);
typedef int eval_submodel_type(char*, void*, double, int, BOOLEAN);
typedef void search_from_type(void*, int, void*);
typedef void* advance_ptr_type(void*, void*);
typedef void* get_remote_value_type(void*, void*, int, int, int*);
typedef int stat_check_type(void*);

typedef void showMess_type(char*);

/* These are for passing procedure addresses in the shim to the shank */

// typedef void get_value_pointer_type(void*, char*, int, int*);
// (its same as above)

/* Defined in the shank, used by the shim */
EXTDEC char* load_model(char*, char*, char*, long int*);
EXTDEC void* use_array_for_params(char*, long int, void*);
EXTDEC int clear_time_point_elts(char*);
EXTDEC int set_wrap(char*, double);
EXTDEC void* create_time_point(char*, double, void*);
EXTDEC int set_record_list(char*, int*, int);
EXTDEC int set_param_array_elt(char*, double, int*);
EXTDEC int set_time_point_elt(char*, double, double, int*);
EXTDEC get_value_pointer_type get_value_pointer;
EXTDEC int get_node_count(long int);
EXTDEC node_data_line* get_data_line(long int, int);
EXTDEC long int get_node_model_id(char*);
EXTDEC void release_graph_data(graph_data_type*);
EXTDEC double graphpoint(double, graph_data_type*, int);
EXTDEC double rand_fract();
EXTDEC graph_data_type** get_graph_base(long int);
EXTDEC void easy_capt(long int, int, char*);
EXTDEC node_data_line* searchinfo(char*, long int,
				  int*, int*, enum_type_data**);
EXTDEC long int fetch_top_instance(long int, char*);

EXTDEC int reset(long int, long int, int);
EXTDEC int execute(long int, long int, int, double, double*, double);
EXTDEC int setstep(long int, double, int);
EXTDEC char* myexit(long int, long int);

EXTDEC void* instance_ptr_from_id(long int);
EXTDEC void* get_ptr(long int, void*, int**, int**);
EXTDEC char* getNodeId(long int, char*);

EXTDEC void proc_pointers_for_shank(get_value_pointer_type*,
				    interact_gui_type*, showMess_type*, 
				    char*, connectRecord***, int**);

/* defined in the shank for use by other clients -- note we may later want
to use regularData items to describe simple c++ arrays, which is why we 
create them and then set them to a model item */

class regularData {
  BOOLEAN start_at_one;
  int dimensionality;
  int spacings[32];
  int bounds[32];
  char* top;
  
 public:
  regularData();
  ~regularData();
  int set_to_model_value(long int model_id, long int instance_id,
			  char* caption);
  void* locate_element(int* indices);
};
