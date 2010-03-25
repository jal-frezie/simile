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
