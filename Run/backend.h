// special integers sent between mgr and worker threads
#define WORKER_QUERY_GUI -1

#ifdef _WIN32
   #define TSPOUT handle_for_win32
   typedef void* TSPOUT;
#else
   #define TSPOUT int
#endif

// class definition and handling procedure for extra variables used in
// complicated integration methods

class diffs {
public:
  diffs () {
    t1 = 0;
    t2 = 0;
    t3 = 0;
  }
  ~diffs () {
  }
  double t1, t2, t3;
};

typedef struct evt_diffs_type {
  double t1, t2;
  int status;
} evt_diffs;

template <class modeldata> class delay;

template <class modeldata> class series {
  friend class delay<modeldata>;

  double timepoint;
  modeldata payload;
  series *next;

  series(double when, modeldata what, series *where) {
    timepoint = when;
    payload = what; // addapt if it's ever to be an array
    next = where;
  }
};

template <class modeldata> class delay {
  friend class series<modeldata>;
  series<modeldata> *head;

 public:
  delay () {
    head = NULL;
  }

  ~delay () {
    series<modeldata> *where = head;
    while (where) {
      where = head->next;
      delete head;
    }
  }

  void empty ();
  void insert (double when, modeldata what, double *expect);
  modeldata retract (double when, BOOLEAN clear);
};

class submodeltype {
public:
  virtual void* get_pointer(int id, int** dims) = 0;
};

class vm_submodeltype : public submodeltype {
public:
  BOOLEAN new_instance;
};

// Binary search tree node with pointer to submodel instance
class bstree_node {
 public:
  bstree_node () {
    parent = left = right = NULL;
    data = NULL;
  }

  bstree_node *parent, *left, *right;
  int level;
  submodeltype* data;
};

#ifdef SIM_PAR_EXEC
class ModelThread {
public:
  int tid;
  pthread_t thread;
  int phase;
  void* context;
};
#endif

// abstract base class for submodels, with extractor virtual function --
// these are actually made in the model code itself
class ExecutingModel; // defined in 6d.h
class InstanceOfModel : public submodeltype {
public:
  virtual ~InstanceOfModel() {};
  // Above stops memory leak in Windows but causes crash in Linux
  // (reinstated 2014, no major Linux crashability or leakage noted since)
  // however, try calling do_exitmodel instead which calls real destructor
  excpData userStop;
  double adapt_maxerr, event_predict;
  // diffs *event_cur_sign, *event_prev_sign;
  // above saves identity of predicted events as pointer to their structure
  ExecutingModel* partner;
  double ts[8], dts[8];
  void* loopIndexPtrs[32];
  int loopIndexCounts[32];
  int ctxSaved[32], ctxCount;
  int activeEvtCount, activeEvtIds[256];
  double activeEvtSums[256];
  void* spares[1024];
  //! Pointer to start of list of graph data objects
  graph_data_type* c_graphdata;

  // functions called by host module
  virtual int do_evalmodel(int) = 0;
  
  // functions implemented by model code
  virtual void advancemodel (int) = 0;
  virtual void updatemodel (int) = 0;
  virtual void evalmodel (int) = 0;
  virtual void do_exitmodel () = 0;

  // support functions called by model code
  double stage_incr (double, diffs*, int, double, int, double, double, int);
  int check_limit(double, double, double, int, int, int, evt_diffs*);
  template <class modeldata> 
    modeldata retract_from_pipe(delay<modeldata>*, int);
  template <class modeldata> 
    void insert_to_pipe(delay<modeldata>*, double, modeldata);
  int loses(double, int);
  void collect(void*, int, int, ...);
  int stop_on_id(int, int);
  int stop(int);
  void report_context(void);
  template <class modeldata>
    modeldata flag_derived_event(int graphId, modeldata magnitude);
  void setup_graph_data(int, double, double, int, double, double,
			int, int, int, ...);
  double  graph_lookup(double, int);
  void abort_check(void);
  void thread_mgr(void* (*)(void*), int, void*, int, int, int, double);
  int parent_line(int);
};

// Declaration for procedure types found in the model dll by the shank
typedef double getversion_type(void);
typedef int getcount_type(graph_data_type**, char**, int*, node_data_line**);
typedef InstanceOfModel* createmodel_type(ExecutingModel*);

FINDABLE EXPORT getversion_type get_version;
FINDABLE EXPORT getcount_type get_count;
// above should load all arg data types so no need to include below
// but that doesnt seem to work...
FINDABLE EXPORT createmodel_type do_createmodel;
FINDABLE make_full_caption_type make_full_caption;

// New in v6.903: declaration for procedures found in the shank by the model dll
EXPORT double ame_rand(double, double);
EXPORT uint64_t seed_rand(int);
// EXPORT double graphpoint(double, graph_data_type*, int);
// no need, is declared in dllcalls.h for use by shim)
int compare_instance_status (const int[], const int[],  int);
EXPORT void report_events(int, const int[], int, const int[], const double[]);
EXPORT int handle_model_param_request(void*, void*, int, int, int*);
EXPORT int stat_check(void*);

int setServerPipe(const char*, TSPOUT*);
void run_external(BOOLEAN*, const char*);
int getClientPipe(TSPOUT, TSPOUT*);
int get_client_indices(TSPOUT, int, int[]);
int exchPipe(TSPOUT, char*, int, int);
int get_int_from_pipe(TSPOUT, int*);
int get_double_from_pipe(TSPOUT, double*);
int get_array_from_pipe(TSPOUT, void*, int);
int get_chars_from_pipe(TSPOUT, char*);
int get_member_from_pipe(TSPOUT, int, const char*, int*);
int put_BOOLEAN_in_pipe(TSPOUT, BOOLEAN);
int put_int_in_pipe(TSPOUT, int);
int put_double_in_pipe(TSPOUT, double);
int put_array_in_pipe(TSPOUT, void*, int);
int put_member_in_pipe(TSPOUT, int, const char*, int);

void exit_sighandler(int);
