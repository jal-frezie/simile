// Declaration for procedure types found in the model dll by the shank
typedef int getcount_type(void*, void*, void* ,void*,
			  void*, void*, void*, void*,
			  char**, int*, node_data_line**);
typedef double getversion_type(void);
typedef InstanceOfModel* createmodel_type(ExecutingModel*);
typedef void model_requests_file_param_type(void*, void*, int, 
					    BOOLEAN, int, int*);

//typedef int setstep_type(InstanceOfModel*, double, int);
//typedef void updatemodel_type(InstanceOfModel*, int);
//typedef void advancemodel_type(void*, int);
//typedef int evalmodel_type(InstanceOfModel*, int);
//typedef void* getpointer_type(void*, int**, int**);
//typedef void exitmodel_type(InstanceOfModel*);

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
    series<modeldata> *where;
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

// abstract base class for submodels, with extractor virtual function --
// these are actually made in the model code itself
class InstanceOfModel : public submodeltype {
public:
  //  virtual ~InstanceOfModel() {}
  // Above stops memory leak in Windows but causes crash in Linux
  excpData userStop;
  double adapt_maxerr, event_predict;
  // diffs *event_cur_sign, *event_prev_sign;
  // above saves identity of predicted events as pointer to their structure
  ExecutingModel* partner;
  double ts[8], dts[8];

  // functions called by host module
  virtual int do_evalmodel(int) = 0;
  
  // functions implemented by model code
  virtual void advancemodel (int phase) = 0;
  virtual void updatemodel (int phase) = 0;
  virtual void evalmodel (int phase) = 0;
  virtual void do_exitmodel () = 0;

  // support functions called by model code
  double stage_incr (diffs*, int, double, double, int);
  int check_limit(double, double, double, int, int, int, diffs*);
  template <class modeldata> 
    modeldata retract_from_pipe(delay<modeldata>*, int);
  template <class modeldata> 
    void insert_to_pipe(delay<modeldata>*, double, modeldata);
  int loses(double, int);
  void collect(void*, int, int, ...);
  int stop_on_id(int, int);
  int stop(int);
};
