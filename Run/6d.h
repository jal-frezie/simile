/////////////////////////////////////////////////////////////////////////////
// 6-D interface: class-based access to functionality accessed by procedure //
// calls in 5-D.                                                            //
//////////////////////////////////////////////////////////////////////////////

#ifdef WIN32
#ifdef SHARELIB
#define CPPEXTDEC __declspec(dllexport)
#else
#define CPPEXTDEC __declspec(dllimport)
#endif
#else
#define HINSTANCE void*
#define CPPEXTDEC
#endif

//! Identifies of a component in either model class or model instance
typedef unsigned short int HCOMP;

class CPPEXTDEC ModelServer;

class CPPEXTDEC ExecutingModel;

class listTimePoint;

//! Data to be associated with a file parameter component in the model
class CPPEXTDEC FileParamData
{
 protected: // protected member items -- note Doxygen will not talk about these

  //! This is the model instance in which the parameter values apply
  ExecutingModel* myModelExec;

 public:
  //! Pointer to next structure in list, allows searching
  FileParamData* next;

  //! index number of the component within the model
  HCOMP nodeId;

  //! This contains the current values for the parameter
  nodeValues dataPtr;

 public: // public methods

  //! Constructor: args are:
  //! (0) ModelServer instance to which to apply these values
  //! (1) Line index of model component which gets the values in that instance
  //! (2) Dimension list in model format, passed for convenience
  FileParamData(ExecutingModel*, HCOMP, int*);

  //! Destructor: simple
  ~FileParamData();

 public:
  void extract_elt(void*, double, BOOLEAN, int*);
  void extract_record_count(void*, int, int*);
};

//! This is same as above but includes all extras for managing time points
class CPPEXTDEC VarParamData : public FileParamData {
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

  //! Time at which to start going through time points from 0 again (0 for none)
  double wrapAroundPoint;

  //! Specifies how to set parameter values at times between specified points
  int fillMethod;

  //! Unit size for indices of time series entries
  double seriesIdxUnits;

  //! valid for time series events only: 0 means no activity
  //! 1 means used and needs resetting
  //! 2 means set but not yet used
  int active;

 protected: // protected methods

  listTimePoint* roll_forward(listTimePoint*, int*);
  double update_from_points(double, double); // overrides FileParamData version

 public: // public methods

//! constructor: same as for parent but declared cos it has args
  VarParamData(ExecutingModel*, HCOMP, int*);

  //! Destructor 

  //! declared because this version also removes object from the 
  //! nextVP list
  ~VarParamData();

  //! Add a time point at the specified time; returns whether new
  listTimePoint* create_time_point(double);

  //! Data space for next point after given time, or NULL if after last
  char* FindNextTimePtSpace(double*);

  //! Data space for time point at given time, or NULL if none added
  char* GetTimePtDataSpace(double);

  //! Recursively remove all time points
  void ClearTimePtElements();

  //! Set up current data from time points as if running forward to time zero
  //! (argument is phase, result is time of first event, 0 if none)
  double ResetTimeSeries(double, int);

  //! Copy values from model into current data space if no time point zero

  //! This is needed in order that the variable parameters keep their initial
  //! value as defined in the model until they are set by a time point or user 
  //! action, otherwise
  //! the uninitialized current data space would be copied over them
  void back_copy_vars(double);

  //! delayed derived events use this to insert time points with their values
  //! Argument is time at which delayed event will occur
  void schedule_point(BOOLEAN, double);

  //! Set up current data from time points for time and direction 
  //! Arguments are time and dir (TRUE=forward), 
  //! result is time of next event (now if none)
  double UpdateTimeSeries(double, double);
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
  double freq;
  int seriesEvtSign;
  double nextSeriesEvt;
  // values for keeping track of GUI interaction and execution times
  int last_op;
  unsigned long int last_exit, last_update;
  unsigned long int took[8];

 public: // public attributes

  //! The model type of which this is an instance
  ModelServer* modelSpec;

  //! identification data passed by the client for use in callbacks
  void* clientRef;

  //! Time at which GUI was last updated with model execution status
  unsigned long int last_check;
  #define FLASH CLOCKS_PER_SEC/25 // 40ms
 
 protected: // protected methods
  void SetdT(int, double);
  void set_dts (int, double);
  int rk_update();
  void advance_time (int, double);
  int phase_for(double, double, int);
  BOOLEAN check_gui(double, int);

 public: // public methods

  //! Constructor takes model type object and client reference
  ExecutingModel(ModelServer*, void*);
  ~ExecutingModel();

  //! Set the length (double) of an execution step of depth int
  int SetStep(int, double);

  //! Create local data structure for a fixed parameter by serial number
  FileParamData* UseArrayForParams(HCOMP);

  //! Find local data structure for a fixed parameter by serial number
  FileParamData* FileParamForNodeNum(HCOMP);

  //! reset the model instance -- args are initial model time,
  //! integration method and action

  //! Actions are: -2 = initialize
  //! -1 == reload fixed parameters
  //! 0 == reset state variables etc
  //! +ve: re-evaluate derived variables for that time step
  excpData* ResetInstance(double, int, int);

  //! Execute the model -- args are int. method, start time,
  // pointer to end time, error limit and whether to pause on events

  //! End time passed as pointer; value overwritten if model stopped early
  //! Error limit controls adaptive timestep variation, 0 turns it off
  excpData* ExecuteInstance(int, double, double*, double, BOOLEAN);

  //! get results from model by node serial number in general c format
  nodeValues* GetRawValues(HCOMP);

  //! allow model to access parameter data; client should not call this
  void GetValuePointer(void*, int, int, BOOLEAN, int*);

  //! allow model to create time seris point; client should not call this
  void schedule(int, BOOLEAN, double);

  // allow model to update client during execution; client should not call
  BOOLEAN do_gui_check(double, int);
}; // End of class ExecutingModel

//! An instance of this class corresponds to a type of model with own executable

//! Perhaps it could be a class template for things like the above class?
class ModelServer 
{
  friend class ExecutingModel;
 protected: // protected attributes
  HINSTANCE handle;
  
  void *getcount,  *getversion, *createmodel;
  
 public: // public attributes
  //! Number of different time steps in model
  int phases;
  //! Pointer to start of list of graph data objects
  graph_data_type* c_graphdata;
  //! Number of components in model
  int nodecount;
  //! Array of info structures for components
  node_data_line* nodedata;
  
 protected: // protected methods
  int parent_line (int);
  int member_param_item(FileParamData**, int*);
  
 public:// public methods
  //! Constructor takes shared lib filename and pointer to string for error mess
  ModelServer(char*, char**);
  ~ModelServer();
  
  //! Creates a model instance of this type
  ExecutingModel* create(void*);

  //! Gets info by searching for ancestors of node identified by arg 1

  //! Arg 2 is full caption path /fee/fi/fo/foo
  //! Arg 3 is list of all dims of component's value
  //! Arg 4 is corresponding list of applicable enumerated types
  //! Client must make space for all of these
  node_data_line* SearchInfo(int, char *, int*, enum_type_data**);

  //! As above but lists all applicable enum types and does not convert dims
  int make_full_caption(int, char*, int*, enum_type_data**);

  //! Gets node serial number from old id (last arg set to submodel if ghost)
  int getinfo(char*, int*);

  //! Gets an integer property (arg2 = GETCLASS, GETTYPE, GETEVAL) for node
  int GetProperty(HCOMP, int);

  //! Gets a node string property (arg2 = 0:name, 1:spec, 2:desc, 3:comment)
  char* GetMetadataText(int, int);

  //! Gets node serial number from its full caption
  HCOMP CompFromCapt(char*);

  //! Gets file parameter object (either sort) from param node's serial number
  int param_item_from_id(FileParamData**, int);

  //! decodes 'graph id' property of node, returning relevant data line
  node_data_line* md_nodlin_from_id(int);

  //! gets node ids from full caption, including ghost node ids
  char* nodeModelAndId(char*);

  // Virtual callback functions: clients use a class that inherits ModelServer
  // and implements these, and the server calls them

  //! Get a parameter element: called if local array not created

  //! Arg 1 is client ref of instance requesting value
  //! Arg 2 is pointer to where client can stick it
  //! Arg 3 is simulation time at which it is required (0 if fixed param)
  //! Arg 4 is serial number of component needing value
  //! Arg 5 says how many array indices are given to pick the value
  //! Arg 6 points to array holding the indices
  virtual void get_value_pointer(void*, void*, double, int, int, int*) = 0;

  //! Inform the client about model progress: client returns nonzero to halt it

  //! Arg 1 is client supplied reference
  //! Arg 2 is time step being calculated
  //! Arg 3 is model time
  virtual int interact_gui(void*, int, double) = 0;

  //! What client is to do if model produces an error or debugging message
  virtual void showMess(const char*) = 0;
}; // End of class ModelServer
