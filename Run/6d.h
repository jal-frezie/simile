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

class listTimePoint;

//! Data to be associated with a file parameter component in the model
class FileParamData
{
 protected: // protected member items -- note Doxygen will not talk about these

  //! This is the model instance in which the parameter values apply
  ExecutingModel* myModelExec;

 public:
  //! Pointer to next structure in list, allows searching
  FileParamData* next;

  //! index number of the component within the model
  int nodeNum;

  //! This contains the current values for the parameter
  nodeValues dataPtr;

  //! Specifies how to set parameter values at times between specified points

  //! This is in the base class because the NO_FILL method indicates
  //! that we are not dealing with a variable parameter with time points
  int fillMethod;

 public: // public methods

  //! Constructor: args are:
  //! (0) Model instance to which to apply these values
  //! (1) Line index of model component which gets the values in that instance
  //! (2) Dimension list in model format, passed for convenience
  FileParamData(ExecutingModel*, int, int*);

  //! Destructor: simple
  ~FileParamData();

 public:
  void extract_elt(void*, int*);
  void extract_record_count(void*, int, int*);
};

//! This is same as above but includes all extras for managing time points
class VarParamData : public FileParamData {
  // private attributes

  //! Start of a linked list of values to apply at time points

  //! These are only present for variable parameters, and they are always kept 
  //!in time order
  listTimePoint* timePoints;

  //! Last entry in linked list of valus to apply at time points
  listTimePoint* finalTimePoint;

  //! Member of list whose time was most recently passed by simulation
  listTimePoint* curTimePoint;

 public: // public attributes
  //! Pointer to next structure in list, allows searching

  //! This is in addition to the pointers which link all file
  //! parameters, allowing searching for only the variable parameters
  VarParamData* nextVP;

  //! Number of times wrapAroundPoint reached before loading curTimePoint
  int wraps;

  //! Time at which to start going through time points from 0 again
  double wrapAroundPoint;

 protected: // protected methods

  listTimePoint* roll_forward(listTimePoint*, int*);
  void update_from_points(int, double); // overrides FileParamData version

 public: // public methods

//! constructor: same as for parent but declared cos it has args
  VarParamData(ExecutingModel*, int, int*);

  //! Destructor 

  //! declared because this version also removes object from the 
  //! nextVP list
  ~VarParamData();

  //! Add a time point at the specified time; returns whether new
  BOOLEAN create_time_point(double);

  //! Data space for next point after given time, or NULL if after last
  char* FindNextTimePtSpace(double*);

  //! Data space for time point at given time, or NULL if none added
  char* GetTimePtDataSpace(double);

  //! Recursively remove all time points
  void ClearTimePtElements();

  //! Set up current data from time points as if running forward to time zero
  void ResetTimeSeries();

  //! Copy values from model into current data space if no time point zero

  //! This is needed in order that the variable parameters keep their initial
  //! value as defined in the model until they are set by a time point or user 
  //! action, otherwise
  //! the uninitialized current data space would be copied over them
  void back_copy_vars();

  //! Set up current data from time points for time and direction (TRUE=forward)
  void UpdateTimeSeries(double, BOOLEAN);
};

//! Class for model instances

//! Each model instance has its own data, its own set of parameter values and 
//! its own execution state
class ExecutingModel
{
  friend class FileParamData;
  friend class VarParamData;

 protected: // protected attributes
  InstanceOfModel* loadedInst;
  FileParamData* param_array_base;
  VarParamData* varParamArrayBase;
  // state of execution
  double steps[8];
  double lts[8], ldts[8], thisTsPosn;
  int resetting;
  int adapt_doublings;
  // values for keeping track of GUI interaction and execution times
  int last_op;
  unsigned long int last_exit, last_update;
  unsigned long int took[8];

 public: // public attributes
  Model* modelSpec;
  void* clientRef;
  unsigned long int last_check;
  #define FLASH CLOCKS_PER_SEC/25 // 40ms
 
 protected: // protected methods
  void SetdT(int, double);
  void set_dts (int, double);
  int rk_update();
  void advance_time (int, double);
  int phase_for(double, double, int);

 public: // public methods
  ExecutingModel(Model*, void*);
  ~ExecutingModel();

  int SetStep(int, double);

  // set up model data
  FileParamData* FileParamForNodeNum(int);
  FileParamData* UseArrayForParams(int);

  // control model execution
  excpData* ResetInstance(int, int);
  excpData* ExecuteInstance(int, double, double*, double);

  // allow model to access data
  void GetValuePointer(void*, int, int, int*);

  // get results from model
  nodeValues* GetRawValues(int);

  // interact with client during execution
  BOOLEAN check_gui(double, int);
}; // End of class ExecutingModel

class Model 
{
  friend class ExecutingModel;

  HINSTANCE handle;

/*  int inArcCount;
  char** inArcList; */
  //  enum_data_type *enumtypedata;

  getcount_type *getcount;
  getversion_type *getversion;
  createmodel_type *createmodel;
/* Matching set of declarations for the pointers by which we will access
   these functions locally */

//  updatemodel_type *updatemodel;
//  advancemodel_type *advancemodel;
//  evalmodel_type *evalmodel;
  int parent_line (int);

public:
  Model(char*, char**);
  ~Model();

  ExecutingModel* create(void*);
  excpData* executemodel(ExecutingModel*, int, double, double*, double);

  //getpointer_type *getpointer;
  int make_full_caption(int, char *, int*, enum_type_data**);
  node_data_line* SearchInfo(int, char *, int*, enum_type_data**);

  int phases;
  /* Time series info exists only for each model class, so thisTsPosn
     remembers for what time the series have been set up, so we know
     what to do when setting them up for a different instance which
     may be at a different time...not sure that ever worked...but now 
     everything should be in the instance
  double lts[8], ldts[8], thisTsPosn;
  */
  graph_data_type* c_graphdata;
  int nodecount;
  node_data_line* nodedata;
  // channelRecord* channelData; only used in top model
  // excpData* userDefStop; // set by stop function in model
  int getinfo(char*, int*);
  int GetProperty(int, int);
  char* GetMetadataText(int, int);
  int NodeNumFromCapt(char*);
  int param_item_from_id(FileParamData**, int);
  node_data_line* md_nodlin_from_id(int);
  int member_param_item(FileParamData**, int*);
}; // End of class Model
