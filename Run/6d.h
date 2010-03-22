/////////////////////////////////////////////////////////////////////////////
// 6-D interface: class-based access to functionality accessed by procedure //
// calls in 5-D.                                                            //
//////////////////////////////////////////////////////////////////////////////

#ifdef WIN32
#else
#define HINSTANCE void*
#endif

class Model;

class ExecutingModel;

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
  ExecutingModel* partner;
  double ts[8], dts[8];

  virtual void advancemodel (int phase) = 0;
  virtual void updatemodel (int phase) = 0;
  virtual void evalmodel (int phase) = 0;
  virtual void do_exitmodel () = 0;

  // support functions called by model code
  double stage_incr (diffs*, int, double, double);
  int loses(double, int);
  void collect(void*, int, int, ...);
};

class listTimePoint;

class FileParamData
{
 public:
  FileParamData* next;
  ExecutingModel* myModelExec;
  int nodeNum;
  nodeValues dataPtr;
  listTimePoint* timePoints;
  listTimePoint* finalTimePoint;
  listTimePoint* curTimePoint;
  int fillMethod;
  double wrapAroundPoint;
  int wraps;

  FileParamData(ExecutingModel*, int);
  ~FileParamData();

  int space_used();
  char* create_time_point(double);
  char* time_point_exists(double);
  listTimePoint* roll_forward(listTimePoint*, int*);
  void update_from_points(int, double);
  void back_copy_vars();
  void ResetTimeSeries();
  void UpdateTimeSeries(double, BOOLEAN);
  void extract_elt(void*, int*);
  void extract_record_count(void*, int, int*);
};

class ExecutingModel
{
 public:
  ExecutingModel(Model*, void*);
  ~ExecutingModel();

  Model* modelSpec;
  void* clientRef;
  InstanceOfModel* loadedInst;
  FileParamData* param_array_base;
 

  double steps[8];
  int SetStep(int, double);
  void SetdT(int, double);
  int phase_for(double, double, int);

  FileParamData* UseArrayForParams(int);

  excpData* ResetInstance(int, int);
  excpData* ExecuteInstance(int, double, double*, double);

  void GetValuePointer(void*, int, int, int*);

  nodeValues* GetRawValues(int);
}; // End of class ExecutingModel

// Declaration for procedure types found in the model dll by the shank
typedef int getcount_type(void*, void*, void*, void* ,void*,
			  void*, void*, void*, void*,
			  int*, node_data_line**, double**);
typedef double getversion_type(void);
typedef InstanceOfModel* createmodel_type(ExecutingModel*);
typedef int setstep_type(InstanceOfModel*, double, int);
typedef void updatemodel_type(InstanceOfModel*, int);
typedef void advancemodel_type(void*, int);
typedef int evalmodel_type(InstanceOfModel*, int);
typedef void* getpointer_type(void*, int**, int**);
typedef void exitmodel_type(InstanceOfModel*);

class Model 
{
  friend class ExecutingModel;

  HINSTANCE handle;
  int count, count2, count3;
  int adapt_doublings;

/*  int inArcCount;
  char** inArcList; */
  //  enum_data_type *enumtypedata;

  getcount_type *getcount;
  getversion_type *getversion;
  createmodel_type *createmodel;
/* Matching set of declarations for the pointers by which we will access
   these functions locally */

  updatemodel_type *updatemodel;
//  advancemodel_type *advancemodel;
  evalmodel_type *evalmodel;
  int rk_update(ExecutingModel*);
  void set_dts (ExecutingModel*, int, double);
  void advance_time (ExecutingModel*, int, double);
  int parent_line (int);

public:
  Model(char*, char**);
  ~Model();

  ExecutingModel* create(void*);
  excpData* executemodel(ExecutingModel*, int, double, double*, double);

  getpointer_type *getpointer;
  setstep_type *setstepmodel;
  exitmodel_type *exitmodel;
  int make_full_caption(int, char *, int*, enum_type_data**);

  int phases;
  /* Time series info exists only for each model class, so thisTsPosn
     remembers for what time the series have been set up, so we know
     what to do when setting them up for a different instance which
     may be at a different time */
  double lts[8], ldts[8], thisTsPosn;
  graph_data_type* c_graphdata;
  int nodecount;
  node_data_line* nodedata;
  int *connLines;
  // channelRecord* channelData; only used in top model
  double* adapt_maxerr;
  // excpData* userDefStop; // set by stop function in model
  int getinfo(char*, int*);
  int GetProperty(int, int);
  char* GetMetadataText(int, int);
  int NodeNumFromCapt(char*);
}; // End of class Model

///// STOPGAP
void add_to_list(Model*, char*);
