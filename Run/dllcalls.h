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
#define ENUMERATED      5

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

#define SIMILE_VERSION	"4.0"

/* type declaration for structure representing a graph */

class graph_data_type {
public:
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
   graph_data_type* next;

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

}; /* end of graph data type decl */

graph_data_type* find_graph (int index, graph_data_type* use_graph_pointer) {
  while (use_graph_pointer && use_graph_pointer->index != index) {
    use_graph_pointer = use_graph_pointer->next;
  }
  return(use_graph_pointer);
}

/* This declares the structure used by the generated code to hold metadata
about model components. It is repeated in the stub ame_cmx.cpp to access fields
outside the dll. */

class node_data_line {
public:
  char name[16];
  int datatype;
  int eval;
  int dims[32];
  int path[32];
  int graph;
  double min;
  double max;
  int compclass;
  char caption[256];
}; /* end(class,node_data_line) */

/* this is defined in the stub, which is loaded as a library...well it
   used to be, but now once the stub has loaded the dll it just sends
   over the pointers to all the functions used by the dll (the other
   method didn't work in win98) */

typedef double ame_rand_type(double, double);
typedef double graphpoint_type(double, int);
typedef void release_graph_data_type(graph_data_type*);
typedef int compare_instance_status_type (const int*, const int*, int);
typedef void get_value_pointer_type(void*, char*, int, int*);
typedef void* fetch_instance_type(char*);
typedef void update_submodel_type(char*, void*, double, int);
typedef void advance_submodel_type(char*, void*, double, int);
typedef int eval_submodel_type(char*, void*, double, int, BOOLEAN);
typedef void search_from_type(void*, int, void*);
typedef void* advance_ptr_type(void*, void*);
typedef void* get_remote_value_type(void*, void*, int, int, int*);
