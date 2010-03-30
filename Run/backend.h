// Declaration for procedure types found in the model dll by the shank
typedef int getcount_type(void*, void*, void*, void* ,void*,
			  void*, void*, void*, void*,
			  int*, node_data_line**);
typedef double getversion_type(void);
typedef InstanceOfModel* createmodel_type(ExecutingModel*);
typedef void model_requests_file_param_type(void*, void*, int, int, int*);
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

class submodeltype {
public:
  virtual void* get_pointer(int id, int** dims) = 0;
};

// abstract base class for submodels, with extractor virtual function --
// these are actually made in the model code itself
class InstanceOfModel : public submodeltype {
public:
  excpData userStop;
  double adapt_maxerr;
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
  int loses(double, int);
  void collect(void*, int, int, ...);
};
