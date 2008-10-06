/* cmx stands for c model extensions
This builds into a shared library which is loaded by Tcl when
AME starts up. Subsequently it can itself load other shared
libraries corresponding to compiled model programs, and allow
them to be executed etc by Tcl commands. */

#include <signal.h> /* for killing stuck model execution */
#include <tcl.h>

#define	GETDIMS		0
#define	GETTYPE		1
#define	GETEVAL		2
#define	GETGRAPH	3
#define	SETGRAPH	4
#define	GETCAPTION	5
#define	GETMIN          6
#define	GETMAX	        8
#define GETPATH        10
#define GETCLASS       11
#define GETTRANS       12
#define GETSPEC        13
#define GETDESC        14
#define GETCOMMENT     15
#define	TEST	       99

#define READGRAPH      21
#define WRITEGRAPH     22
#define USEGRAPH       23

#define USE_MY_HMAC

#ifdef WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #undef WIN32_LEAN_AND_MEAN

    #define FORUNIX 0
/*
BOOL APIENTRY
DllEntryPoint(
    HINSTANCE hInst,		// Library instance handle.
    DWORD reason,		// Reason this function is being called.    LPVOID reserved)		// Not used.
    LPVOID reserved)		// Not used.
{
    return TRUE;
}
*/
int kill (int pid, int sig) {
  HANDLE procHandle;
  BOOL outcome;

  procHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
  outcome = TerminateProcess(procHandle, sig);
  CloseHandle(procHandle);
  return(outcome);
}

#else

#define FORUNIX 1

#endif
#include <locale.h>

// Definitions used in this code and the model code
#include <dllcalls.h>

char simileVersion[] = SIMILE_VERSION;

Tcl_Interp* globInterp;
int serviceError;
graph_data_type* tcl_graphdata;
char globMess[255];

void showMess (char* mess) {
  Tcl_VarEval(globInterp, "tk_messageBox -title {c++ debug} -icon info -message {", mess, "} -type ok",
	      NULL);
}

/* this simply makes up a tcl list of all the objects that
appear in the object table. */

int list(long int listType, Tcl_Interp *interp) {

  Tcl_Obj *resultPtr;
  char* find;
  int line, nodecount;
  node_data_line* node_data;

  resultPtr = Tcl_GetObjResult(interp);
  nodecount = get_node_count(listType);
  for (line=0; line<nodecount; line++) {
    node_data = get_data_line(listType, line);
/*    if (node_data->datatype == EXTERNAL) {
      list(get_node_model_id(node_data->name), interp);
      } else { */
      Tcl_ListObjAppendElement(interp, resultPtr, 
			       Tcl_NewStringObj(node_data->name, -1));
      //    }
  }
  return TCL_OK;
}

int do_graph(graph_data_type** graphdata, Tcl_Interp *interp, 
	     int action, int index, int argc, Tcl_Obj *CONST argv[]) {
  Tcl_Obj* resultPtr;
  graph_data_type* graphptr;
  char current[255];
  double xval;
  int error, count;

  resultPtr = Tcl_GetObjResult(interp);
  switch (action) {
  case READGRAPH:
    graphptr = find_graph(index, *graphdata);
    if (!graphptr) {
      Tcl_SetStringObj(resultPtr, 
		       "There is no graph associated with this component", -1);
      return TCL_ERROR;
    }
    sprintf(current, "%f %f %d %f %f %d %d %d",
            graphptr->xlow,
            graphptr->xhigh,
            graphptr->xspan,
            graphptr->ylow,
            graphptr->yhigh,
            graphptr->yspan,
            graphptr->range,
            graphptr->xsize);
    Tcl_SetStringObj(resultPtr, current, -1);

    for (count=0;count<graphptr->xsize;count++) {
      sprintf(current, " %d", graphptr->points[count]);
      Tcl_AppendStringsToObj(resultPtr, current, 
			     (char *)NULL);
			     }
    return TCL_OK;
  case WRITEGRAPH:
    if (argc < 12) {
      Tcl_SetStringObj(resultPtr, "At least 12 args needed to set graph!", -1);
      return TCL_ERROR;
    } /* if(error) */

    graphptr = find_graph(index, *graphdata);
    if (!graphptr) { /* add a new graph */
      graphptr = (graph_data_type*)malloc(sizeof(graph_data_type));
      graphptr->index = index;
      graphptr->next = *graphdata;
      *graphdata = graphptr;
    } else {
      release_graph_data(graphptr);
    }

    error = Tcl_GetDoubleFromObj(interp, argv[3], &(graphptr->xlow));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetDoubleFromObj(interp, argv[4], &(graphptr->xhigh));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[5], &(graphptr->xspan));
    if (error != TCL_OK) {

      return error;
    } /* if(error) */
    error = Tcl_GetDoubleFromObj(interp, argv[6], &(graphptr->ylow));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetDoubleFromObj(interp, argv[7], &(graphptr->yhigh));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[8], &(graphptr->yspan));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[9], &(graphptr->range));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    error = Tcl_GetIntFromObj(interp, argv[10], &(graphptr->xsize));
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    
    if (argc-1 != 10+graphptr->xsize) {
      sprintf(current, "Got %d args for graph of %d datapoints -- need %d",
	      argc-1, graphptr->xsize, 10+graphptr->xsize);
      Tcl_SetStringObj(resultPtr, current, -1);
      return TCL_ERROR;
    } /* if(error) */

    graphptr->points = (int*)malloc(sizeof(int)*graphptr->xsize);
    for(count=0;count<graphptr->xsize;count++) {
      Tcl_GetIntFromObj(interp, argv[count+11], &(graphptr->points[count]));
    }
    return TCL_OK;

 case USEGRAPH:
    error = Tcl_GetDoubleFromObj(interp, argv[3], &xval);
    if (error != TCL_OK) {
      return error;
    } /* if(error) */
    Tcl_SetDoubleObj(resultPtr, graphpoint(xval, *graphdata, index));
    return TCL_OK;

  default:
    sprintf(current, "graph_table does not support action %d", action);
    Tcl_SetStringObj(resultPtr, current, -1);
    return TCL_ERROR;
  } /* end(switch,action) */
}

int do_interface(Tcl_Interp *interp, int argc, Tcl_Obj *CONST argv[])
{
  char current[255];
  int dims[32], path[32];
  Tcl_Obj *resultPtr, *oneType;
  int error, action, count;
  node_data_line *data_line;
  long int tgtModel;
  enum_type_data *usedTypes[32], **usedTypePtr;

  error = Tcl_GetIntFromObj(interp, argv[2], &action);
  if (error != TCL_OK) {
    return error;
  } /* if(error) */

  if (!(data_line=searchinfo(Tcl_GetStringFromObj(argv[1], NULL), &tgtModel,
			     current, dims, path, usedTypes))) {
    sprintf(current, "noitem");
    resultPtr = Tcl_NewStringObj(current, -1);
    Tcl_SetObjResult(interp, resultPtr);
    return(TCL_OK);
  }
  switch (action) {
  case GETDIMS:
    count=0;
    resultPtr = Tcl_NewListObj(0, NULL);
    do {
      if (Tcl_ListObjAppendElement(interp, resultPtr, 
			       Tcl_NewIntObj(dims[count])) != TCL_OK) {
	return TCL_ERROR;
	}
    } while (dims[count++]);
    break;

  case GETPATH:
    count=0;
    resultPtr = Tcl_NewListObj(0, NULL);
    do {
      if (Tcl_ListObjAppendElement(interp, resultPtr, 
			       Tcl_NewIntObj(path[count])) != TCL_OK) {
	return TCL_ERROR;
	}
    } while (path[count++]);
    break;

  case GETCLASS:
    resultPtr = Tcl_NewIntObj(data_line->compclass);
    break;

  case GETTYPE: // return old version
    resultPtr = Tcl_NewIntObj(-data_line->datatype);
    break;

  case GETEVAL:
    resultPtr = Tcl_NewIntObj(data_line->eval);
    break;

  case GETMIN:
    resultPtr = Tcl_NewDoubleObj(data_line->min);
    break;

  case GETMAX:
    resultPtr = Tcl_NewDoubleObj(data_line->max);
    break;

  case GETGRAPH:
  case SETGRAPH:
    action = action + READGRAPH - GETGRAPH; // SETGRAPH becomes WRITEGRAPH
    return do_graph(get_graph_base(tgtModel), interp, action, data_line->graph,
		    argc, argv);

  case GETCAPTION:
    resultPtr = Tcl_NewStringObj(current, -1);
    break;

  case GETSPEC:
    resultPtr = Tcl_NewStringObj(data_line->strings[1], -1);
    break;

  case GETDESC:
    resultPtr = Tcl_NewStringObj(data_line->strings[2], -1);
    break;

  case GETCOMMENT:
    resultPtr = Tcl_NewStringObj(data_line->strings[3], -1);
    break;

  case GETTRANS:
    resultPtr = Tcl_NewListObj(0, NULL);
    usedTypePtr = usedTypes;
    while (*usedTypePtr) {
      oneType = Tcl_NewListObj(0, NULL);
      if ((*usedTypePtr)->count) {
	Tcl_ListObjAppendElement(interp, oneType, 
				 Tcl_NewStringObj((*usedTypePtr)->name, -1));
      }
      for (count=0; count<(*usedTypePtr)->count;count++) {
	Tcl_ListObjAppendElement(interp, oneType, 
			Tcl_NewStringObj((*usedTypePtr)->members[count], -1));
      }
      Tcl_ListObjAppendElement(interp, resultPtr, oneType);
      usedTypePtr += 1;
    }
    break;

  default:
    sprintf(current, "getvalue does not support action %d",
	    action);
    resultPtr = Tcl_NewStringObj(current, -1);
    Tcl_SetObjResult(interp, resultPtr);
    return TCL_ERROR;
  } /* end(switch,action) */
  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
} /* end(procedure,!(finished)) */

/* Now for procedures that are called from the dll and therefore have to be
   global even though they may refer to stuff by model type and instance */

void get_tcl_value_pointer(void* modelPtr, void* tgt, int paramId, 
			   int count, int* inds) {
  node_data_line* data_line;
  char caption[255];
  const char* varName;
  int dims[32], path[32];
  Tcl_Obj* valPtr;
  int stepIndex, rv;
  long int mSpare;
  double makeInt;
  enum_type_data* usedTypes[32];
  char id[] = "dummy";

  data_line = searchinfo(id, &mSpare, caption, dims, path, usedTypes);
  strcpy(caption, data_line->name);
  strcpy(caption + strlen(caption), " { ");
  for (stepIndex = 0; count>stepIndex; ++stepIndex) {
    sprintf(caption + strlen(caption), "%d ", inds[stepIndex]); 
  }
  strcpy(caption + strlen(caption), "}");
  
  if (data_line->eval == TABLE) {
    varName = "paramData ";
  } else if (data_line->eval == INPUT) {
    if (data_line->datatype == FLAG) {
      varName = "checkStates ";
    } else if (data_line->datatype <= ENUM_BASE) {
      varName = "comboChoices ";
    } else {
      varName = "sliderVals ";
    }
  }
  if (Tcl_VarEval(globInterp, "BringParameter ", varName, caption, NULL) 
      == TCL_OK) {
    valPtr = Tcl_GetObjResult(globInterp);
    switch (data_line->datatype) {
    case FLAG:
      serviceError = Tcl_GetBooleanFromObj(globInterp, valPtr, (int*)tgt);
      return;
    case REAL:
      serviceError = Tcl_GetDoubleFromObj(globInterp, valPtr, (double*)tgt);
      return;
    default: /* could be VALUELESS if getting number of instances for record 
		submodel, INTEGER or ENUM(*) */
      /* if someone enters a float in a slider entry box or time series for
	 an integer input, we want the nearest int value... */
      serviceError = Tcl_GetDoubleFromObj(globInterp, valPtr, &makeInt);
      if (serviceError == TCL_OK) {
	*(int*)tgt = (int)(makeInt);
      }
      return;
    }
  }
}
      
Tcl_Obj* make_exec_error(Tcl_Interp* interp, const char* phase, 
			 const char* tgt,  double time, int step, 
			 char* complaint) {
  Tcl_Obj* errList;

  errList=Tcl_NewListObj(0, NULL);
  Tcl_ListObjAppendElement(interp, errList, 
			   Tcl_NewStringObj("tcl_model_err", -1));
  Tcl_ListObjAppendElement(interp, errList, Tcl_NewStringObj(phase, -1));
  Tcl_ListObjAppendElement(interp, errList, Tcl_NewStringObj(tgt, -1));
  Tcl_ListObjAppendElement(interp, errList, Tcl_NewDoubleObj(time));
  Tcl_ListObjAppendElement(interp, errList, Tcl_NewIntObj(step));
  Tcl_ListObjAppendElement(interp, errList, Tcl_NewStringObj(complaint, -1));
  return errList;
}

/* Here is code that has been added by hand to make these procedures available
as Tcl commands so the dialog box can call them as if it were a Tcl simulation.
 This one is called after a new dll has been built, to set the function
   pointers to the appropriate addresses in the dll. Some code is copied
   from TclLoadDl.c -- well, that works...if called without an arg it
unloads the model. Since the model dll now merely defines the model class, this
also causes an instance of it to be created. */

long int modelType;
long int modelHandle;

//connectRecord** connectDataPtr;
//int* connCountPtr;

FINDABLE int loadmodelCmd(ClientData clientData, Tcl_Interp *interp, 
			    int argc, Tcl_Obj *CONST argv[]) {
  char* fileName;
  char* nodeName;
  char* dllProblem;

  switch (argc) {
  case 3:
    fileName = Tcl_GetStringFromObj(argv[1], NULL);
    nodeName = Tcl_GetStringFromObj(argv[2], NULL);
    dllProblem = load_model(fileName, nodeName, &modelType);
    if (dllProblem) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj(dllProblem, -1));
      free(dllProblem);
      return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewLongObj(modelType));
    break;
    
  default:
    Tcl_WrongNumArgs(interp, 1, argv, "filename node_id");
    return TCL_ERROR;
  }
  return TCL_OK;
}

/* Create also sets up the tables required to get data out of one submodel
   instance into another */

FINDABLE int createmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
   int error;

   if (argc != 2) {
     Tcl_WrongNumArgs(interp, 1, argv, "model_id");
     return TCL_ERROR;
   }

   error = Tcl_GetLongFromObj(interp, argv[1], &modelType);
   if (error != TCL_OK) {
	return error;
   }
   modelHandle = fetch_top_instance(modelType);
   if (modelHandle) {
     Tcl_SetLongObj(Tcl_GetObjResult(interp), modelHandle);
     return TCL_OK;
   } else {
     Tcl_SetStringObj(Tcl_GetObjResult(interp), 
		      "Failed to create model instance", -1);
     return TCL_ERROR;
   }
}

/* This one creates an array to hold values for a model parameter and
   tells the model subsystem that it is to use this array to get
   values 

First two args are model type and instance, 3rd is node name */

FINDABLE int setparamarrayCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id");
    return TCL_ERROR;
  }
  
  if (use_array_for_params(Tcl_GetStringFromObj(argv[1], NULL))) {
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("Failed to make array for this node", -1));
    return TCL_ERROR;
  }
}

FINDABLE int cleartimeseriesCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id");
    return TCL_ERROR;
  }
  
  clear_time_point_elts(Tcl_GetStringFromObj(argv[1], NULL));
  return TCL_OK;
}
/*
FINDABLE int savetimepointCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  double time;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 2, argv, "node_id time");
    return TCL_ERROR;
  }
  
  error = Tcl_GetDoubleFromObj(interp, argv[2], &time);
  if (error != TCL_OK) {
    return error;
  }

  if (save_time_point(Tcl_GetStringFromObj(argv[1], NULL), time)) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("save_time_point: no array has been created for this node", -1));
    return TCL_ERROR;
  }
  return TCL_OK;
}
*/
FINDABLE int setwrapCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  double *time;

  if (argc != 2 && argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id ?time?");

    return TCL_ERROR;
  }
  
  if (time=get_wrap_ptr(Tcl_GetStringFromObj(argv[1], NULL)))
    if (argc == 3)
      return Tcl_GetDoubleFromObj(interp, argv[2], time);
    else {
      Tcl_SetObjResult(interp, Tcl_NewDoubleObj(*time));
      return TCL_OK;
    }
  else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("Failed to set wraparound time for this node", -1));
    return TCL_ERROR;
  }
}

FINDABLE int setfillCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error, *mtd;

  if (argc != 2 && argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id ?method?");

    return TCL_ERROR;
  }
  
  if (mtd=get_fill_ptr(Tcl_GetStringFromObj(argv[1], NULL)))
    if (argc == 3)
      return Tcl_GetIntFromObj(interp, argv[2], mtd);
    else {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(*mtd));
      return TCL_OK;
    }
  else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("Failed to set fill method for this node", -1));
    return TCL_ERROR;
  }
}

FINDABLE int settimepointarrayCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  double timePt;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id time");
    return TCL_ERROR;
  }
  
  error = Tcl_GetDoubleFromObj(interp, argv[2], &timePt);
  if (error != TCL_OK) {
    return error;
  }

  if (!create_time_point(Tcl_GetStringFromObj(argv[1], NULL), timePt)) {
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("create_time_point: no array has been created for this node", -1));
    return TCL_ERROR;
  }
}

// converts a Tcl list of integers into a 0-teminated c array of them
int  ints_from_list(Tcl_Interp *interp, Tcl_Obj *CONST obList, int indxs[]) {
  int i, count, error;
  Tcl_Obj* elt;

  if ((error = Tcl_ListObjLength(interp, obList, &count)) != TCL_OK)
    return error;
  for (i=0;i<count;i++) {
    if ((error = Tcl_ListObjIndex(interp, obList, i, &elt)) != TCL_OK)
      return error;
    if ((error = Tcl_GetIntFromObj(interp, elt, indxs + i)) != TCL_OK)
      return error;
  }
  indxs[i]=0; // terminate array with zero
  return TCL_OK;
}

FINDABLE int setrecordlistCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error, indxs[32], *dims;
  char* bloc;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id index_list value");
    return TCL_ERROR;
  }
  
  if ((error = ints_from_list(interp, argv[2], indxs)) != TCL_OK)
    return error;

  error = Tcl_GetIntFromObj(interp, argv[3], &count);
  if (error != TCL_OK) {
    return error;
  }
  bloc = get_param_ptr_and_dims(Tcl_GetStringFromObj(argv[1], NULL), &dims);
  if (!bloc) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_record_list: no array has been created for this node", -1));
    return TCL_ERROR;
  }
  if (set_bloc_record_count(bloc, dims, indxs, count)) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_record_list: number of indices does not correspond to a per-record submodel level", -1));
    return TCL_ERROR;
  }
  return TCL_OK;
}

FINDABLE int settimepointrecordsCmd(ClientData clientData, Tcl_Interp *interp,
				    int argc, Tcl_Obj *CONST argv[]) {
  int count, error, indxs[32], *dims;
  char* bloc;
  double timePt;

  if (argc != 5) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id index_list time value");
    return TCL_ERROR;
  }
  
  if ((error = ints_from_list(interp, argv[2], indxs)) != TCL_OK)
    return error;

  error = Tcl_GetDoubleFromObj(interp, argv[3], &timePt);
  if (error != TCL_OK) {
    return error;
  }

  error = Tcl_GetIntFromObj(interp, argv[4], &count);
  if (error != TCL_OK) {
    return error;
  }
  switch (get_timepoint_ptr_and_dims(Tcl_GetStringFromObj(argv[1], NULL), 
				     timePt, &bloc, &dims)) {
  case 2:
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_tp_records: no array has been created for this node", -1));
    return TCL_ERROR;
  case 1:
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_tp_records: no array exists for this time point", -1));
    return TCL_ERROR;
  }
  if (set_bloc_record_count(bloc, dims, indxs, count)) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_tp_records: number of indices does not correspond to a per-record submodel level", -1));
    return TCL_ERROR;
  }
  return TCL_OK;
}

FINDABLE int setparamelementCmd(ClientData clientData, Tcl_Interp *interp,
				int argc, Tcl_Obj *CONST argv[]) {
  int i, error, indxs[32], *dims;
  double val;
  char* bloc;
  
  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id index_list value");
    return TCL_ERROR;
  }
  
  error = Tcl_GetDoubleFromObj(interp, argv[3], &val);
  if (error != TCL_OK) {
    return error;
  }
  
  if ((error = ints_from_list(interp, argv[2], indxs)) != TCL_OK)
    return error;
  
  bloc = get_param_ptr_and_dims(Tcl_GetStringFromObj(argv[1], NULL), &dims);
  if (!bloc) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_param_array_elt: no array has been created for this node", -1));
    return TCL_ERROR;
  }
//  sprintf(globMess, "setting element %d %d in %lx to %lf",
//	  indxs[0], indxs[1], bloc, val);
//  showMess(globMess);
  set_bloc_element(bloc, dims, indxs, val);
  return TCL_OK;
}

/* For this one, we have all the data in a Tcl ByteArray object */

FINDABLE int setparamallCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error, indxs[32];
  void *sourcePtr, *destPtr;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id data indices");
    return TCL_ERROR;
  }
  
  if ((error = ints_from_list(interp, argv[3], indxs)) != TCL_OK)
    return error;

  sourcePtr = Tcl_GetByteArrayFromObj(argv[2], &count);
  
  destPtr=use_array_for_params(Tcl_GetStringFromObj(argv[1], NULL));
  if (!destPtr) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("c_setparamall: no array can be created for this node", -1));
    return TCL_ERROR;
  }
  // OK, clever stuff (probably in shank) to go here...
  memcpy(destPtr, sourcePtr, count);
  return TCL_OK;
}

FINDABLE int getparamallCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error;
  char *nodeId;
  unsigned char *holder;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id");
    return TCL_ERROR;
  }
  
  nodeId = Tcl_GetStringFromObj(argv[1], NULL);
  if (count=param_array_size(nodeId)) { // assignment
    holder = Tcl_SetByteArrayLength(Tcl_GetObjResult(interp), count);
    memcpy(holder, use_array_for_params(nodeId), count);
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("c_getparamall: no array can be located for this node", -1));
    return TCL_ERROR;
  }
}

FINDABLE int settimepointelementCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error, indxs[32], *dims;
  double time, val;
  char* bloc;

  if (argc != 5) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id index_list time value");
    return TCL_ERROR;
  }
  
  error = Tcl_GetDoubleFromObj(interp, argv[3], &time);
  if (error != TCL_OK) {
    return error;
  }

  error = Tcl_GetDoubleFromObj(interp, argv[4], &val);
  if (error != TCL_OK) {
    return error;
  }

  if ((error = ints_from_list(interp, argv[2], indxs)) != TCL_OK)
    return error;
  switch (get_timepoint_ptr_and_dims(Tcl_GetStringFromObj(argv[1], NULL), time,
				     &bloc, &dims)) {
  case 2:
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_tp_element: no array has been created for this node", -1));
    return TCL_ERROR;
  case 1:
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_tp_element: no array exists for this time point", -1));
    return TCL_ERROR;
  }
  set_bloc_element(bloc, dims, indxs, val);
  return TCL_OK;
}

FINDABLE int settimepointallCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error, squirtPtr = 0, num_bytes, *dims;
  char *nodeId, *ptBytes;
  unsigned char *holder;
  double seekTime;
  Tcl_Obj* resultPtr;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id data");
    return TCL_ERROR;
  }
  
  nodeId = Tcl_GetStringFromObj(argv[1], NULL);
  if (count=param_array_size(nodeId)) {
    holder = Tcl_GetByteArrayFromObj(argv[2], &num_bytes);
//    sprintf(globMess, "Array has %d bytes, time points %d", num_bytes, count);
//    showMess(globMess);
    while (squirtPtr<num_bytes) {
// Needs new system
      seekTime = *(double*)(holder+squirtPtr);
      if (create_time_point(nodeId, seekTime)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("Failed to make array for this node", -1));
	return TCL_ERROR;
      }
      get_timepoint_ptr_and_dims(nodeId, seekTime, &ptBytes, &dims);
      // assume above works as we have just created it
      squirtPtr += sizeof(double);
      memcpy(ptBytes, holder+squirtPtr, count);
      squirtPtr += count;
    }
  } else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("No array can be located for this node", -1));
    return TCL_ERROR;
  }
  return TCL_OK;
}

FINDABLE int gettimepointallCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error, squirtPtr = 0, currentSize;
  char *nodeId;
  unsigned char *holder;
  void *ptBytes;
  double seekTime;
  Tcl_Obj* resultPtr;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "node_id");
    return TCL_ERROR;
  }
  
  nodeId = Tcl_GetStringFromObj(argv[1], NULL);
  if (count=param_array_size(nodeId)) { // assignment
    currentSize = (count + sizeof(double))/2;
    resultPtr = Tcl_NewObj();
    holder = Tcl_SetByteArrayLength(resultPtr, currentSize);
    seekTime = -1e100;
    // copy data for each timept to ByteArray, doubling its size if too small
    while (ptBytes = find_next_timept_space(nodeId, &seekTime)) { // assignment
      if (squirtPtr + count + sizeof(double) > currentSize) {
	holder = Tcl_SetByteArrayLength(resultPtr, currentSize=2*currentSize);
      }
      *(double*)(holder+squirtPtr) = seekTime;
      squirtPtr += sizeof(double);
      memcpy(holder+squirtPtr, ptBytes, count);
      squirtPtr += count;
    }
    // now trim to correct size
    Tcl_SetByteArrayLength(resultPtr, squirtPtr);
    Tcl_SetObjResult(interp, resultPtr);
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("c_gettimepointall: no array can be located for this node", -1));
    return TCL_ERROR;
  }
}

void get_string_for_error(char* spare, int error) {
  if (error == -101) {
    sprintf(spare, "abort request from the user");
  } else if (error < 0) {
    sprintf(spare, "Illegal operation signal %d", -error);
  } else {
    sprintf(spare, "User-defined interruption code %d", error);
  }
}

const char* name_in_line(long int modelType, int lineId) {
    node_data_line *nodeLine;

    if (lineId) {
      nodeLine = nodlin_from_id(modelType, lineId);
      return nodeLine->strings[0];
    } else return "external procedure";
}

FINDABLE int resetmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  char spare[256];
  int phase, error;
  excpData* errorBlk;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id phase");
    return TCL_ERROR;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], (long int *)&modelHandle);
  if (error != TCL_OK) {
    return error;
    
  }
  
  error = Tcl_GetIntFromObj(interp, argv[3], &phase);
  if (error != TCL_OK) {
    return error;
  }
  
  errorBlk = reset(modelType, modelHandle, phase);

  if (errorBlk) {
    get_string_for_error(spare, errorBlk->excpNo);
    Tcl_SetObjResult(interp, make_exec_error(interp, "resetmodel", 
					     name_in_line(modelType, 
							  errorBlk->targetId), 
					     0, phase, spare));
    return TCL_ERROR;
  } else {
    return TCL_OK;
  }
}

FINDABLE int executemodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  char spare[256];
  double starttime, endtime, errlim;
  int phase, error;
  excpData* errorBlk;

  if (argc != 7) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id phase start_time end_time error_limit");
    return TCL_ERROR;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], (long int *)&modelHandle);
  if (error != TCL_OK) {
    return error;
    
  }
  
  error = Tcl_GetIntFromObj(interp, argv[3], &phase);
  if (error != TCL_OK) {
    return error;
    
  }
  
  error = Tcl_GetDoubleFromObj(interp, argv[4], &starttime);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetDoubleFromObj(interp, argv[5], &endtime);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetDoubleFromObj(interp, argv[6], &errlim);
  if (error != TCL_OK) {
    return error;
  }
  
  errorBlk = execute(modelType, modelHandle, phase, starttime, &endtime, 
		     errlim);
  if (errorBlk) {
    if (errorBlk->excpNo == -100) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(0));
      return TCL_OK;
    } else if (errorBlk->excpNo == -99) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(-1));
      return TCL_OK;
    }
    get_string_for_error(spare, errorBlk->excpNo);
    Tcl_SetObjResult(interp, make_exec_error(interp, "evalmodel", 
					     name_in_line(modelType, 
							  errorBlk->targetId), 
					     endtime, 1, spare));
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewIntObj(1));
  return TCL_OK;
}

FINDABLE int setstepCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
   double starttime;
   int phase;
   int error;

   if (argc != 4) {
     Tcl_WrongNumArgs(interp, 1, argv, "model_id interval/phase step_id");
     return TCL_ERROR;
   }

   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetDoubleFromObj(interp, argv[2], &starttime);
   if (error != TCL_OK) {
	return error;
   }

   error = Tcl_GetIntFromObj(interp, argv[3], &phase);
   if (error != TCL_OK) {
	return error;
   }

   Tcl_SetIntObj(Tcl_GetObjResult(interp), 
		 setstep(modelType, starttime, phase));
   return TCL_OK;
}

/* exit model: unload all dlls. If the handle is nonzero, free its data
   structures first (though this probably gets done when the dlls are unloaded
*/

FINDABLE int exitmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  char* dllProblem;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id");
    return TCL_ERROR;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[1], &modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], &modelHandle);
  if (error != TCL_OK) {
    return error;
  }
  
  dllProblem = myexit(modelType, modelHandle);
  if (dllProblem) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj(dllProblem, -1));
    free(dllProblem);
    return TCL_ERROR;
  }
  return TCL_OK;
}

FINDABLE int getnodeidCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  char* nodeId;
  
  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id caption");
    return TCL_ERROR;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[1], &modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  nodeId = getNodeId(modelType, Tcl_GetStringFromObj(argv[2], NULL));
  if (nodeId) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj(nodeId, -1));
    return TCL_OK;
  } else {
    Tcl_AppendResult(interp, "No node with caption string ",
		     Tcl_GetStringFromObj(argv[2], NULL), " found.",
		     (char*)NULL);
    return TCL_ERROR;
  }
}

FINDABLE int interfaceCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
   int error;
  if (argc < 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id node_id action ?parameters?");
    return TCL_ERROR;
  }

   error = Tcl_GetLongFromObj(interp, argv[1], (long int *)&modelType);
   if (error != TCL_OK) {
	return error;
   }

  return do_interface(interp, argc-1, argv+1);
}

FINDABLE int graphCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int action, index, error;

  if (argc < 3) {
    Tcl_WrongNumArgs(interp, 2, argv, "graph_id");
    return TCL_ERROR;
  }

  error = Tcl_GetIntFromObj(interp, argv[1], &action);
  if (error != TCL_OK) {
    return error;
  } /* if(error) */

  error = Tcl_GetIntFromObj(interp, argv[2], &index);
  if (error != TCL_OK) {
    return error;
  } /* if(error) */

  return do_graph(&tcl_graphdata, interp, action, index, argc, argv);
}

/* This does the same as compare_instance_status with Tcl_Obj lists instead
of arrays. It will put shorter lists in front of longer, though they should
always be the same length. */

int obj_compare_instance_status(Tcl_Obj* Obj, Tcl_Obj* RefObj) {
  int count, num1, num2, val1, val2;
  Tcl_Obj **objVals, **refVals;

  Tcl_ListObjGetElements(NULL, Obj, &num1, &objVals);

  Tcl_ListObjGetElements(NULL, RefObj, &num2, &refVals);
  for (count=0; count<num1 && count<num2; count++) {


    Tcl_GetIntFromObj(NULL, Obj, &val1);
    Tcl_GetIntFromObj(NULL, RefObj, &val2);
    if (val1<val2) return -1;
    if (val1>val2) return 1;
  }
  if (count<num1) return 1;
  if (count<num2) return -1;
  return 0;
}



/* This picks a Tcl_Obj from a list by matching its index (preceeding
element) with another obj. Returns empty obj if not found. ArrayVals
is the list of alternating index and value structures set by an I/O
tool. LocalSubObj is the index structure of the model list component
we are accessing. */

Tcl_Obj* pick_elt_vals(Tcl_Obj** arrayVals, int arrayLength, 
		       Tcl_Obj* localSubObj, int* arrayPosn) {
  int status;

  while (*arrayPosn<arrayLength) {
    status = obj_compare_instance_status(arrayVals[*arrayPosn], localSubObj);
    if (status==1) {
      /* Next input index too great: no input for this component */
      return Tcl_NewListObj(0, NULL);
    }
    /* Otherwise advance pointer */
    *arrayPosn += 2;
    if (status==0) {
      /* Last input index matches: return corresponding element */
      return arrayVals[*arrayPosn - 1];
    }
    /* Next input index too small: no component for this input. Try next. */
  }
  /* No more inputs in list, so none for this component */
  return Tcl_NewListObj(0, NULL);
}

/* This takes a model type and instance, list of integers and pointer into
that list, and returns, let us say, the first unused model index if the integers match the model's 
indices as far as the pointer, 0 if that is all the indices, and -1 if there
is a mismatch before the pointer

Change for 4.8: we put a 0 at the end of the dims so we do not need one at the
end of each model instance's ids */

int match_type(long int localType, long int smHandle, int dims[], 
	       int* dim_place) {
  int id_handle[] = {2,0}, *cur_place, *short_tree, *id_ptr, id_val, id_count;
  short_tree = id_handle;
  id_count = 0;
  id_ptr = &id_count;
  cur_place = dims;
  while (cur_place < dim_place) {
    id_val = *(int *)(get_ptr(localType, smHandle, &short_tree, 
					&id_ptr));
    if (id_val != *(cur_place++)) {
      return -1;
    }
    ++id_count;
    id_ptr = &id_count;
    short_tree = id_handle;
  }
  if (*cur_place) {
    return *(int *)(get_ptr(localType, smHandle, &short_tree, &id_ptr));
  }
  return 0;
}

/* next two call one another so one needs to be declared in advance */
Tcl_Obj* fill_value(long int, long int, int[], int, int*, int[], int*, 
		    Tcl_Obj*);

Tcl_Obj* fill_list_value(long int localType, long int* smHandle, int tree[], 
			 int type, int* use_dims, int dims[], int* dim_place) {
  Tcl_Obj *localObj, *localSubObj;
  int next_handle[] = {1,0}, match, arrayOut, *short_tree;
  localObj = Tcl_NewListObj(0, NULL);
  while (*smHandle && 
	 (match = match_type(localType, *smHandle, dims, dim_place)) != -1) {
    if (match == 0) {
      localObj = fill_value(localType, *smHandle, tree, type, use_dims, 
			    dim_place+1, dim_place+1, NULL);
      short_tree = next_handle;
      *smHandle = *(long int*)(get_ptr(localType, *smHandle, &short_tree, 
						  NULL));
    } else {
      *dim_place=match;
      localSubObj = fill_list_value(localType, smHandle, tree, type,
				    use_dims, dims, dim_place+1);
      Tcl_ListObjLength(NULL, localSubObj, &arrayOut);
      if (arrayOut) {
	Tcl_ListObjAppendElement(NULL, localObj, Tcl_NewIntObj(match));
	Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
      }
    }
  }
  return(localObj);
}

/* fill_value extracts a list of values from the model. Type is the full id
path to the component whose values we are after. use_dims is array of array
sizes which we are to get all the values from. Dims is an array of ints
for the indices in the arrays we are getting values from, and dim_place is the
pointer into this array where we can add more values as we go through the loops
up to the sizes specified in use_dims. */

Tcl_Obj* fill_value(long int localType, long int smHandle, int tree[], 
		    int type, int* use_dims, int dims[], int* dim_place, 
		    Tcl_Obj* nVs) {
  Tcl_Obj *localObj, *indObj, *localSubObj, **arrayVals, *eltVals;
  void* model_val_ptr;
  int *new_tree;
  int arrayLength, arrayPosn, arrayOut;
  int next_handle[] = {1,0}, id_handle[] = {2,0};


  // dimension count for pops/records: overwritten for vm, unused for fm/sep
  *(dim_place+1)=1;
  new_tree = dim_place+2;

  switch (*use_dims) {
  case SEPARATE:

    new_tree = tree;
    while (*new_tree++ != SEPARATE) {}

    smHandle = *(long int*)(get_ptr(localType, smHandle, &tree, &dims));
    localType = *(new_tree++);
    return(fill_value(localType, smHandle, new_tree, type, 
		      use_dims+1, dim_place, dim_place, nVs));
  case START_VM:
    new_tree = dim_place+1;
    while (*++use_dims != END_VM) {
      *(new_tree++)=1;
    }
  case MEMBERS:
  case RECORDS:
    *new_tree = 0; // end expected dimensions for vm instances
    new_tree = tree;
    while (*new_tree++ != -1) {}

    smHandle = *(long int*)(get_ptr(localType, smHandle, &tree, &dims));
    localObj = fill_list_value(localType, &smHandle, new_tree, type, 
			       use_dims+1, dim_place+1, dim_place+1);
    break;
  case 0:
    model_val_ptr = get_ptr(localType, smHandle, &tree, &dims);
    switch (type) {
    case VALUELESS:
      localObj = Tcl_NewStringObj("sm", -1);
      break;
    case REAL:
      localObj = Tcl_NewDoubleObj(*(double *)model_val_ptr);
      if (nVs) {
	Tcl_GetDoubleFromObj(NULL, nVs, (double *)model_val_ptr);
      }
      // following needs Tcl >= 8.5, replace %g with new arg
      //      localObj = Tcl_Format(NULL, "%g", 1, &localObj);
      break;
    case FLAG:
      localObj = Tcl_NewBooleanObj(*(int *)model_val_ptr);
      if (nVs) {
	Tcl_GetBooleanFromObj(NULL, nVs, (int *)model_val_ptr);
      }
      break;
      /*    case EXTERNAL:
      localObj = Tcl_NewStringObj("ex", -1);
      break;
      */
    default: // INTEGER or ENUM(*)
      localObj = Tcl_NewIntObj(*(int *)model_val_ptr);
      if (nVs) {
	Tcl_GetIntFromObj(NULL, nVs, (int *)model_val_ptr);
      }
      break;
    }
    break;
  default: /* value is a dimension of the array we are accessing */
    localObj = Tcl_NewListObj(0, NULL);
    if (nVs) {
      Tcl_ListObjGetElements(NULL, nVs, &arrayLength, &arrayVals);
      arrayPosn = 0;
    } else {
      eltVals = NULL;
    }
    for (*dim_place = 0; *use_dims > *dim_place; ++*dim_place) {
      indObj = Tcl_NewIntObj(*dim_place+1);
      if (nVs) {
	eltVals = pick_elt_vals(arrayVals, arrayLength, indObj, &arrayPosn);
      }
      localSubObj = fill_value(localType, smHandle, 
		tree, type, use_dims+1, dims, dim_place+1, eltVals);
      Tcl_ListObjLength(NULL, localSubObj, &arrayOut);
      if (arrayOut) {
	Tcl_ListObjAppendElement(NULL, localObj, indObj);
	Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
      }
    }
    break;
  }
  return(localObj);
}

void make_sub_block_sizes(int *dims, int *sizes) {
  int usedDims = 1;
  switch (dims[0]) {
  case SPARSEARRAY:
    usedDims = 2;
  case OWNSIZED:
    make_sub_block_sizes(dims+usedDims, sizes+1);
    sizes[0] = sizeof(int) + sizeof(void*);
    break;
  case REAL:
    sizes[0] = sizeof(double);
    break;
  case FLAG:
    sizes[0] = sizeof(BOOLEAN);
    break;
  case VALUELESS:
    sizes[0] = 0;
    break;
  default: // dimension, INTEGER or enumerated type
    if (dims[0]>0) {
      make_sub_block_sizes(dims+1, sizes+1);
      sizes[0]=sizes[1]*dims[0];
    } else
      sizes[0] = sizeof(int);
  }
}

/* next two call convert_to_tcl, which calls them, so declare in advance */
Tcl_Obj* convert_to_tcl(int*, int*, char*);

Tcl_Obj* append_list_members(int dimty, int depth, int* dims, int* indices, 
			     int* subBlocks, int *members, char** block) {
  Tcl_Obj *localObj, *localSubObj;
  int count;
  if (depth==dimty) {
    if (*members) {
      *block += dimty*sizeof(int);
      localObj = convert_to_tcl(dims, subBlocks, *block);
      *block += subBlocks[0];
      --*members;
    } else {
      localObj = Tcl_NewListObj(0, NULL);
    }
  } else {
    localObj = Tcl_NewListObj(0, NULL);
    while (*members) {
      for (count=0; count<depth; ++count) {
	if (((int*)*block)[count]!=indices[count]) return(localObj);
      }
      indices[depth] = ((int*)*block)[depth];
      localSubObj = append_list_members(dimty, depth+1, dims, indices,
					subBlocks, members, block);
      Tcl_ListObjLength(NULL, localSubObj, &count); // re-use count variable
      if (count) {
	Tcl_ListObjAppendElement(NULL, localObj, Tcl_NewIntObj(indices[depth]));
	Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
      }
    }
  }
  return(localObj);
}

Tcl_Obj* append_array_members(int membership, int* dims, int* subBlocks, 
			      char* block) {
  Tcl_Obj *localObj, *indObj, *localSubObj;
  int offset, arrayOut;
  
  localObj = Tcl_NewListObj(0, NULL);
  for (offset = 0; membership > offset; ++offset) {
    indObj = Tcl_NewIntObj(offset+1);
    localSubObj = convert_to_tcl(dims, subBlocks, block+offset*subBlocks[0]);
    Tcl_ListObjLength(NULL, localSubObj, &arrayOut);
    if (arrayOut) {
      Tcl_ListObjAppendElement(NULL, localObj, indObj);
      Tcl_ListObjAppendElement(NULL, localObj, localSubObj);
    }
  }
  return localObj;
}
  
Tcl_Obj* convert_to_tcl(int* dims, int* subBlocks, char* block) {
  Tcl_Obj *localObj;
  int membership, *indices;
  char *newBlock, *blockEnd;

  if (dims[0] > 0) { // it's an array bound
    localObj = append_array_members(dims[0], dims+1, subBlocks+1, block);
  } else {
    switch (dims[0]) {
    case OWNSIZED:
      membership = *(int *)block;
      newBlock = *(char**)(block + sizeof(int));
      localObj = append_array_members(membership, dims+1, subBlocks+1, newBlock);
      free(newBlock);
      break;
    case SPARSEARRAY: 
      // need clevers to nest indices; see old stuff
      membership = *(int *)block;
      newBlock = *(char**)(block + sizeof(int));
      block = newBlock;
      indices = (int*)malloc(sizeof(int)*dims[1]);
      blockEnd = block+membership*(dims[1]*sizeof(int)+subBlocks[1]);
      localObj = append_list_members(dims[1], 0, dims+2, indices, subBlocks+1,
				     &membership, &block);
      free(indices);
      free(newBlock);
      break;
    case VALUELESS:
      localObj = Tcl_NewStringObj("sm", -1);
      break;
    case REAL:
      localObj = Tcl_NewDoubleObj(*(double *)block);
      break;
    case FLAG:
      localObj = Tcl_NewBooleanObj(*(int *)block);
      break;
    default: /* INTEGER or ENUM(*) */
      localObj = Tcl_NewIntObj(*(int *)block);
    }
  }
  return localObj;
}

FINDABLE int extractCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  Tcl_Obj *resultPtr, *newData;
  int iPosn, error;

  char spare[256];
  int dims[32], path[32];
  long int mSpare;
  enum_type_data* usedTypes[32];
  nodeValues* c_result;

  error = Tcl_GetLongFromObj(interp, argv[1], &modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], &modelHandle);
  if (error != TCL_OK) {
    return error;
  }
  int count;
  node_data_line *data_line;
  int current_dims[32];

  if (clientData) {
    iPosn = 5;
    newData = argv[4];
  } else {
    iPosn = 4;
    newData = NULL;
  }

  for (count=0;count+iPosn<argc;count++) {
	Tcl_GetIntFromObj(interp, argv[count+iPosn], current_dims + count);
  }
  /*  resultPtr = Tcl_NewObj();

  if (!(data_line=searchinfo(Tcl_GetStringFromObj(argv[3], NULL), 
			     &mSpare, spare, dims, path, usedTypes))) {
    resultPtr = Tcl_NewStringObj("novalue", -1);
  } else {
    resultPtr = fill_value(modelType, modelHandle, path, data_line->datatype, 
			   dims+count, current_dims, current_dims+count,
			   newData);
  }
  */
  c_result = get_raw_values(Tcl_GetStringFromObj(argv[3], NULL), modelHandle);
  if (c_result) {
    int subBlocks[32];
    make_sub_block_sizes(c_result->dimSpecs, subBlocks);
    resultPtr = convert_to_tcl(c_result->dimSpecs, subBlocks, c_result->contents);
    free(c_result->contents);
    free(c_result);
  } else
    resultPtr = Tcl_NewStringObj("novalue", -1);
  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}
/* Old versio using regularData
double scaleIntProc(void* access) {
  return (double)(*(int*)access);
}

double scaleDoubleProc(void* access) {
  return (*(double*)access);
}

void addDSorted(int* discCount, double** dPtrDiscList, double newVal) {
  double *spareArr;
  int count, exp, bigexp;

  spareArr = *dPtrDiscList;
  // straight search could be replaced by binary if more speed needed
  for (count=0; count<*discCount; ++count) {
    if (newVal==spareArr[count]) {
      return;
    } else if (newVal<spareArr[count]) {
      break;
    }
  }
  if (*discCount>=16 && frexp(*discCount,&bigexp)<frexp((*discCount)-1,&exp)) {
    *dPtrDiscList = new double[(int)(ldexp(1,bigexp))];
    memmove(*dPtrDiscList, spareArr, count*sizeof(double));
  }
  memmove(*dPtrDiscList+count+1, spareArr+count, 
	  (*discCount-count)*sizeof(double));
  (*dPtrDiscList)[count] = newVal;
  ++(*discCount);
  if (*dPtrDiscList!=spareArr) delete(spareArr);
}
  
void addISorted(int* discCount, int** dPtrDiscList, int newVal) {
  int *spareArr;
  int count, exp, bigexp;

  spareArr = *dPtrDiscList;
  // straight search could be replaced by binary if more speed needed
  for (count=0; count<*discCount; ++count) {
    if (newVal==spareArr[count]) {
      return;
    } else if (newVal<spareArr[count]) {
      break;
    }
  }
  if (*discCount>=16 && frexp(*discCount,&bigexp)<frexp((*discCount)-1,&exp)) {
    *dPtrDiscList = new int[(int)(ldexp(1,bigexp))];
    memmove(*dPtrDiscList, spareArr, count*sizeof(int));
  }
  memmove(*dPtrDiscList+count+1, spareArr+count, 
	  (*discCount-count)*sizeof(int));
  (*dPtrDiscList)[count] = newVal;
  ++(*discCount);
  if (*dPtrDiscList!=spareArr) delete(spareArr);
}

FINDABLE int extractBinCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int error;
  double (*scaleProc) (void*);
  double valfor0, valfor255, valspan, dval;
  long int accessTool;
  unsigned char* tgt;
  int* progress;
  int cursor, count, size;
  Tcl_Obj *resultPtr, *spareObjPtr;
  void* valAccessed;

  double *dDiscList;
  int discCount, *iDiscList;

  if (clientData) {
    // listing distinct vals
    if (argc != 4) {
      Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id caption");
      return TCL_ERROR;
    }
  } else {
    if (argc != 6) {
      Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id caption lower_limit upper_limit");
      return TCL_ERROR;
    }

    error = Tcl_GetDoubleFromObj(interp, argv[4], &valfor0);
    if (error != TCL_OK) {
      return error;
    }
    
    error = Tcl_GetDoubleFromObj(interp, argv[5], &valfor255);
    if (error != TCL_OK) {
      return error;
    }
  }

  error = Tcl_GetLongFromObj(interp, argv[1], &modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], &modelHandle);
  if (error != TCL_OK) {
    return error;
  }

  accessTool = createRegularData();
  if (rdSetToNodeValue(accessTool, modelType, modelHandle,
				     Tcl_GetStringFromObj(argv[3], NULL))) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("Failed to attach access tool to this component.", -1));
    return TCL_ERROR;
  }

  valspan=valfor255-valfor0; // set to span
  cursor = rdDimensionality(accessTool);
  if (rdDatatype(accessTool)==REAL) {
    scaleProc = scaleDoubleProc;
  } else {
    scaleProc = scaleIntProc;
  }
  progress = new int[cursor];
  size = 1;
  for (count=cursor-1;count>=0;--count) {
    size=size*rdBound(accessTool,count);
    progress[count]=0;
  }
  resultPtr = Tcl_NewObj();
  if (!clientData) {
    if (valspan) {
      Tcl_SetByteArrayLength(resultPtr, size);
    } else { // no span: get values as floats
      Tcl_SetByteArrayLength(resultPtr, size*sizeof(double));
    }
    tgt = Tcl_GetByteArrayFromObj(resultPtr, NULL);
  } else {
    dDiscList = new double[16];
    iDiscList = new int[16];
  }

  progress[cursor-1]=-1; // carefully avoid overrun at end
  discCount=0;
  for (count=0; count<size;++count) {
    cursor=rdDimensionality(accessTool)-1;
    while (++progress[cursor]==rdBound(accessTool,cursor)) {
      progress[cursor--]=0;
    }
    valAccessed = rdLocateElement(accessTool,progress);
    if (clientData) {
      if (rdDatatype(accessTool)==REAL) {
	addDSorted(&discCount, &dDiscList, *(double *)valAccessed);
      } else {
	addISorted(&discCount, &iDiscList, *(int*)valAccessed);
      }
    } else {
      dval=(*scaleProc)(valAccessed);
      if (valspan) {
	tgt[count] = (unsigned char)(dval<valfor0?0:(dval>=valfor255?255:
					 (255*(dval-valfor0)/valspan)));
      } else { // no span: get values as doubles
	((double*)tgt)[count]=dval;
      }
    }
  }
  // if doing discrete, make tcl array of results and free space
  if (clientData) {
    for (count=0; count<discCount; ++count) {
      if (rdDatatype(accessTool)==REAL) {
	spareObjPtr = Tcl_NewDoubleObj(dDiscList[count]);
      } else {
	spareObjPtr = Tcl_NewIntObj(iDiscList[count]);
      }
      Tcl_ListObjAppendElement(interp, resultPtr, spareObjPtr);
    }
    delete dDiscList;
    delete iDiscList;
  }
  Tcl_SetObjResult(interp, resultPtr);
  deleteRegularData(accessTool);
  // might want to keep some of these if doing this every time step
  return TCL_OK;
}

New version using nodeValues structure -- first its callback procs */

void add_to_size(void* spareValue, int spareOffset, void* sizePtr) {
  // sizePtr is actually an integer pointer
  ++(*(int*)sizePtr);
}

// structures to treat last arg of callback as 
typedef struct addSorted_pt {
  int baseType;
  int *discCount;
  double **dPtrDiscList;
} addSortedParms;

// only doubles work for now, add ints to this later
void addSorted(void* values, int offset, addSortedParms* cbData) {
  //void addDSorted(int* discCount, double** dPtrDiscList, double newVal) {
  double *spareArr, **dPtrDiscList, newVal;
  int count, exp, bigexp, *discCount;

  if (cbData->baseType == REAL) 
    newVal = ((double*)values)[offset];
  else 
    newVal = ((int*)values)[offset];
  discCount = cbData->discCount;
  dPtrDiscList = cbData->dPtrDiscList;

  spareArr = *dPtrDiscList;
  // straight search could be replaced by binary if more speed needed
  for (count=0; count<*discCount; ++count) {
    if (newVal==spareArr[count]) {
      return;
    } else if (newVal<spareArr[count]) {
      break;
    }
  }
  if (*discCount>=16 && frexp(*discCount,&bigexp)<frexp((*discCount)-1,&exp)) {
    *dPtrDiscList = (double*)malloc(sizeof(double)*(int)(ldexp(1,bigexp)));
    memmove(*dPtrDiscList, spareArr, count*sizeof(double));
  }
  memmove(*dPtrDiscList+count+1, spareArr+count, 
	  (*discCount-count)*sizeof(double));
  (*dPtrDiscList)[count] = newVal;
  ++(*discCount);
  if (*dPtrDiscList!=spareArr) free(spareArr);
}

// structures to treat last arg of callback as 
typedef struct convert_pt {
  int baseType;
  unsigned char** tgtPtr;
  double *valfor0, *valfor255;
} convertParms;

void convert_to_byte(void* values, int offset, convertParms* cbData) {
  unsigned char** tgtPtr;
  double valfor0, valfor255, thisVal;

  valfor0 = *cbData->valfor0;
  valfor255 = *cbData->valfor255;
  if (cbData->baseType == REAL) 
    thisVal = ((double*)values)[offset];
  else 
    thisVal = ((int*)values)[offset];

//  sprintf(globMess, "Span is %lf to %lf; off %d, val %lf", valfor0, valfor255,
//	  offset, values[offset]);
//  showMess(globMess);
  *((*cbData->tgtPtr)++) =
    (unsigned char)(thisVal<valfor0?0:(thisVal>=valfor255?255:
				       (255*(thisVal-valfor0)/
					(valfor255-valfor0))));
}

void move_to_double(double* values, int offset, double** tgtPtr) {
  *((*tgtPtr)++) = values[offset];
}

FINDABLE int extractBinCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int error;
  double valfor0, valfor255, valspan, dval;
  nodeValues* accessTool;
  unsigned char* tgt;
  int* progress;
  int baseType, count, size;
  Tcl_Obj *resultPtr, *spareObjPtr;
  void* valAccessed;
  char* nodeId;
  char* myClientData[32];

  double *dDiscList;
  int discCount, *iDiscList;

  if (clientData) {
    // listing distinct vals
    if (argc != 4) {
      Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id caption");
      return TCL_ERROR;
    }
  } else {
    if (argc != 6) {
      Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id caption lower_limit upper_limit");
      return TCL_ERROR;
    }

    error = Tcl_GetDoubleFromObj(interp, argv[4], &valfor0);
    if (error != TCL_OK) {
      return error;
    }
    
    error = Tcl_GetDoubleFromObj(interp, argv[5], &valfor255);
    if (error != TCL_OK) {
      return error;
    }
  }

  error = Tcl_GetLongFromObj(interp, argv[1], &modelType);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetLongFromObj(interp, argv[2], &modelHandle);
  if (error != TCL_OK) {
    return error;
  }

  nodeId = getNodeId(modelType, Tcl_GetStringFromObj(argv[3], NULL));
  if (!nodeId) {
    Tcl_AppendResult(interp, "No node with caption string ",
		     Tcl_GetStringFromObj(argv[2], NULL), " found.",
		     (char*)NULL);
    return TCL_ERROR;
  }
  accessTool = get_raw_values(nodeId, modelHandle); 
  // just got nodeId so assume it works!

  valspan=valfor255-valfor0; // set to span

  count = 0;
  while (accessTool->dimSpecs[count]>=0) ++count; //stop at base data type
  baseType=accessTool->dimSpecs[count];

  size = 0;
  call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		    add_to_size, (void*)&size);
  // this increments size once for each value

  resultPtr = Tcl_NewObj();
  if (!clientData) {
    if (valspan) {
      Tcl_SetByteArrayLength(resultPtr, size);
    } else { // no span: get values as floats
      Tcl_SetByteArrayLength(resultPtr, size*sizeof(double));
    }
    tgt = Tcl_GetByteArrayFromObj(resultPtr, NULL);
  } else {
    dDiscList = (double*)malloc(sizeof(double)*16);
    iDiscList = (int*)malloc(sizeof(int)*16);
  }

  discCount=0;
  if (clientData) {
    ((addSortedParms*)myClientData)->baseType = baseType; 
    ((addSortedParms*)myClientData)->discCount = &discCount; 
    ((addSortedParms*)myClientData)->dPtrDiscList = &dDiscList;
    call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
		      (valCallback*)addSorted, myClientData);
  } else {
    ((convertParms*)myClientData)->tgtPtr = &tgt; 
    // not sure why I must cast a pointer rather than the structure itself
    // must be passed every call so increment it
    if (valspan) {
      ((convertParms*)myClientData)->baseType = baseType; 
      ((convertParms*)myClientData)->valfor0 = &valfor0;
      ((convertParms*)myClientData)->valfor255 = &valfor255;
	call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0, 
			  (valCallback*)convert_to_byte, myClientData);
    } else { // no span: get values as doubles
	call_for_each_val(accessTool->dimSpecs, accessTool->contents, 0,
			  (valCallback*)move_to_double, &tgt);
    }
  }

  // if doing distinct vals, make tcl array of results and free space
  // (new for 5.3; first val is total member count)
  if (clientData) {
    Tcl_ListObjAppendElement(interp, resultPtr, Tcl_NewIntObj(size));
    for (count=0; count<discCount; ++count) {
      if (baseType==REAL) {
	spareObjPtr = Tcl_NewDoubleObj(dDiscList[count]);
      } else {
	spareObjPtr = Tcl_NewIntObj(iDiscList[count]);
      }
      Tcl_ListObjAppendElement(interp, resultPtr, spareObjPtr);
    }
    free(dDiscList);
    free(iDiscList);
  }
  Tcl_SetObjResult(interp, resultPtr);
  free_bloc_data(accessTool->contents, accessTool->dimSpecs);
  free(accessTool);
  return TCL_OK;
}

FINDABLE int listobjCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
   int error;
   long int modelType;

   if (argc != 2) {
     Tcl_WrongNumArgs(interp, 1, argv, "model_id");
     return TCL_ERROR;
   }
   error = Tcl_GetLongFromObj(interp, argv[1], &modelType);
   if (error != TCL_OK) {
	return error;
   }

   return list(modelType, interp);
}

FINDABLE int randseedCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
   int seed, error;

   if (argc != 2) {
     Tcl_WrongNumArgs(interp, 1, argv, "seed");
     return TCL_ERROR;
   }
   error = Tcl_GetIntFromObj(interp, argv[1], &seed);
   if (error != TCL_OK) {
	return error;
   }
   srand(seed);
   return TCL_OK;
}

FINDABLE int random01Cmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
    Tcl_Obj *resultPtr;

   if (argc != 1) {
     Tcl_WrongNumArgs(interp, 1, argv, "");
     return TCL_ERROR;
   }
    resultPtr = Tcl_GetObjResult(interp);
    Tcl_SetDoubleObj(resultPtr, rand_fract());
   return TCL_OK;
}

void respond_to_param_req(void* modelId, void* modelSlot, int paramId, 
			  int indCount, int* indices) {
  Tcl_BackgroundError(globInterp);
}

BOOLEAN outeract_gui(void* id, BOOLEAN stop_chk, double now) {
  BOOLEAN response;

  Tcl_Obj* feedbackCmd;
  if (stop_chk) {
    feedbackCmd = Tcl_NewStringObj("InteractGUI", -1);
    Tcl_ListObjAppendElement(globInterp, feedbackCmd,
			     Tcl_NewLongObj((long int)id));
    Tcl_ListObjAppendElement(globInterp, feedbackCmd, Tcl_NewDoubleObj(now));
    Tcl_ListObjAppendElement(globInterp, feedbackCmd, Tcl_NewIntObj(stop_chk));
  } else {
    feedbackCmd = Tcl_NewStringObj("AbortCheck", -1);
    Tcl_ListObjAppendElement(globInterp, feedbackCmd,
			     Tcl_NewLongObj((long int)id));
  }
  Tcl_EvalObjEx(globInterp, feedbackCmd, 0);
  Tcl_GetIntFromObj(globInterp, Tcl_GetObjResult(globInterp), &response);
  return response;
}
/*
FINDABLE int SetConnDBCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  int count, count2, spare, error;
  Tcl_Obj** EltPtr;
  Tcl_Obj** PairPtr;
  Tcl_Obj** destObjs;
  connectRecord* currConnect;
   if (argc != 2) {
     Tcl_WrongNumArgs(interp, 1, argv, "connection_list");
     return TCL_ERROR;
   }
   // Move strings from the arg to a more easily searchable data structure

   error = Tcl_ListObjGetElements(interp, argv[1], connCountPtr, &EltPtr);
   if (error != TCL_OK) {
     return error;
   }
   *connectDataPtr = new connectRecord[*connCountPtr];

   for (count=0; *connCountPtr>count; count++) {
     error = Tcl_ListObjGetElements(interp, EltPtr[count], &spare, &PairPtr);
     if (error != TCL_OK) {
       return error;
     }
     if (spare != 4) {
       Tcl_SetObjResult(interp, Tcl_NewStringObj("set_connection_database items need four elements each!", -1));
       return TCL_ERROR;
     }
     currConnect = &(*connectDataPtr)[count];
     currConnect->TopArc = strdup(Tcl_GetStringFromObj(PairPtr[0], NULL));
     currConnect->TopNode = strdup(Tcl_GetStringFromObj(PairPtr[1], NULL));
     currConnect->SourceNode = strdup(Tcl_GetStringFromObj(PairPtr[2], NULL));
     error = Tcl_ListObjGetElements(interp, PairPtr[3], 
				    &(currConnect->DestCount),
				    &destObjs);
     if (error != TCL_OK) {
       return error;
     }
     currConnect->Dests = new char*[currConnect->DestCount];
     for (count2=0; currConnect->DestCount>count2; count2++) {
       currConnect->Dests[count2] = strdup(Tcl_GetStringFromObj
					   (destObjs[count2], NULL));
     }

   }
   return TCL_OK;
}
*/
/* String to use as secret */
char secret[] = "R^6tf*Y}@?>H(U(ddJ(::{><Lu8H*G";
#ifdef SIM_EVALUATION
char edition[]="evaluation";
#endif
#ifdef SIM_TEACHING
char edition[]="teaching";
#endif
#ifdef SIM_STANDARD
char edition[]="standard";
#endif
#ifdef SIM_ENTERPRISE
char edition[]="enterprise";
#endif

void crash (Tcl_Interp *interp, const char *cause) {
 /* oh dear. */
 /* oh dear, oh dear. */
  Tcl_VarEval(interp, "ShowMessage {Authorization failure} error {Bad ", cause, " authorization. Simile will now exit.} ok", NULL);
  Tcl_Exit(-1);
}	 
#ifdef USE_MY_HMAC
int my_md5(Tcl_Interp *interp, Tcl_Obj* text) {
  Tcl_Obj* argv[3];
  int result;

  /* First we must make up our command for doing MD5. This will involve direct 
     invocation of the Trf library routine with Tcl objects. */
  Tcl_CmdInfo info;
  Tcl_ObjCmdProc* md5ObjProc;
  ClientData md5ObjClientData;

  if (! Tcl_GetCommandInfo(interp, "::md5", &info)) {
    Tcl_AppendResult(interp, "unknown command \"", "::md5", "\"", NULL);
    return TCL_ERROR;
  }
  md5ObjProc = info.objProc;
  md5ObjClientData = info.objClientData;

  argv[0] = Tcl_NewStringObj("::md5", -1);
  Tcl_IncrRefCount(argv[0]);  
  argv[1] = Tcl_NewStringObj("--", -1);
  Tcl_IncrRefCount(argv[1]);  



  argv[2] = text;
  Tcl_IncrRefCount(argv[2]);  

  result = (*md5ObjProc)(md5ObjClientData, interp, 3, argv);

  Tcl_DecrRefCount(argv[2]);  
  Tcl_DecrRefCount(argv[1]);  
  Tcl_DecrRefCount(argv[0]);  

  return result;
}

int my_hash(Tcl_Interp *interp, Tcl_Obj *textObj) {
  Tcl_Obj* md5Target;

  if (my_md5(interp, textObj) == TCL_ERROR) {
    return TCL_ERROR;
  }
  md5Target = Tcl_NewStringObj("::hex -mode encode -- ", -1);
  Tcl_ListObjAppendElement(interp, md5Target, Tcl_GetObjResult(interp));
  if (Tcl_EvalObjEx(interp, md5Target, 0) == TCL_ERROR) {
    return TCL_ERROR;
  }
  return Tcl_VarEval(interp, "string tolower ",
	      Tcl_GetStringResult(interp), NULL);
}
      
int my_hmac(Tcl_Interp *interp, const char* key, const char* text) {
  char* k_ipad;
  char k_opad[96];
  Tcl_Obj* md5Target;

  k_ipad = (char*)malloc(strlen(text)+80);
  int count;
  for (count=strlen(key)-1; count>=0; count--) {
    k_ipad[count]=key[count]^0x36;
    k_opad[count]=key[count]^0x5c;
  }
  for (count=strlen(key); count<64; count++) {
    k_ipad[count]=0x36;
    k_opad[count]=0x5c;
  }

  strcpy(k_ipad+64, text);
  my_md5(interp, Tcl_NewStringObj(k_ipad, strlen(text)+64));
  
  free(k_ipad);

  md5Target = Tcl_NewStringObj(k_opad, 64);
  Tcl_AppendObjToObj(md5Target, Tcl_GetObjResult(interp));
  return my_hash(interp, md5Target);
}
#endif    
/* This gets the authorisation code that is needed for a particular combination
   of original simile edition and Prolog model specification */

FINDABLE int GetAuthCodeCmd(ClientData clientData, Tcl_Interp *interp, 
			      int argc, Tcl_Obj *CONST argv[]) {
   if (argc != 2) {
     Tcl_WrongNumArgs(interp, 1, argv, "source_string");
     return TCL_ERROR;
   }
   /* set ModelText [mime::getbody $Part($Model)] */
   if (Tcl_VarEval(interp, "set hvfe587gw938 [mime::getbody ", 

	       Tcl_GetStringFromObj(argv[1], NULL), "]", NULL) != TCL_OK) {
     return TCL_ERROR;
   }
   /* regexp {edition=([^,]*),} $ModelText all putativeEdition */
   if (Tcl_VarEval(interp, 
		   "regexp {edition=([^,]*),} $hvfe587gw938 all h76rt4g7",
		   NULL) != TCL_OK) {
     return TCL_ERROR;
   }
   if (strcmp(edition, Tcl_GetVar(interp, "h76rt4g7", 0))) {
     crash(interp, "edition");
   }
#ifdef USE_MY_HMAC
   return my_hmac(interp, secret, Tcl_GetVar(interp, "hvfe587gw938", 0));
#else
   /*    ::sha1::hmac "Expensive" $ModelText */
   return Tcl_VarEval(interp, "::md5::hmac ", secret, " $hvfe587gw938", NULL);
#endif
}   

/* This bit exists solely to make our lives difficult, especially if we are
thinking of ripping off Simulistics, Inc. A special security code is generated
from our little secret -- after checking that the edition specified is right */

FINDABLE int CheckAuthCodeCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "source_string");
    return TCL_ERROR;
  }
  /* set ModelText [mime::getbody $Part($Model)] */
  if (Tcl_VarEval(interp, "set hvfe587gw938 [mime::getbody ", 
		  Tcl_GetStringFromObj(argv[1], NULL), "]", NULL) != TCL_OK) {
    return TCL_ERROR;
  }
#ifdef USE_MY_HMAC
  if (my_hmac(interp, secret, Tcl_GetVar(interp, "hvfe587gw938", 0)) != TCL_OK) {
    return TCL_ERROR;
  }
#else
  if (Tcl_VarEval(interp, "::md5::hmac ", secret, " $hvfe587gw938", NULL) != TCL_OK) {
    return TCL_ERROR;
  }
#endif

  /* check it matches what we got before */
  if (strcmp(Tcl_GetVar(interp, "AuthCode", 0), Tcl_GetStringResult(interp))) {
    crash(interp, "model");
  }
  
  /* Also if we are evaluation, it was not written by enterprise and it has 
     more than 30 lines beginning 'node...' there are grounds to suspect foul
     play...actually it might not be their fault so don't do this...
  if (strcmp("evaluation", edition)) {
    return TCL_OK;
  }
  if (strcmp("enterprise", Tcl_GetVar(interp, "h76rt4g7", 0))) {
    return TCL_OK;
  }
  if (Tcl_VarEval(interp, "regexp -all {node\(node} $hvfe587gw938",
		  NULL) != TCL_OK) {
    return TCL_ERROR;
  }
  Tcl_GetIntFromObj(interp, Tcl_GetObjResult(interp), &trouble);
  if (trouble > 30) {
    crash();
    } */
  return TCL_OK;
}

FINDABLE int GetVersionCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 1) {
    Tcl_WrongNumArgs(interp, 1, argv, "");
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewStringObj(simileVersion, -1));
  return TCL_OK;
}

FINDABLE int killmodelCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  int error, pid;
  Tcl_Obj* resultPtr;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "pid");
    return TCL_ERROR;
  }
  error = Tcl_GetIntFromObj(interp, argv[1], &pid);
  if (error != TCL_OK) {
    return error;
  }
  resultPtr = Tcl_GetObjResult(interp);
  Tcl_SetIntObj(resultPtr, kill(pid, SIGTERM));
  return TCL_OK;
}

int licenseRight (Tcl_Interp *interp) {
  /* If this version requires a license then check we have the right
     one...

     if (Tcl_VarEval(interp, "::md5::hmac ", secret, 
      " $userinfo(name)@$userinfo(corp)%$userinfo(edn)", NULL) != TCL_OK) {

      Above used hmac but now we just append the secret and hash because
      it needs to be generated by PHP 
      ...so for a while it looked like this: */
#ifdef SIM_LICENSED
#ifdef USE_MY_HMAC
  Tcl_Obj* dataCombo;
  const char* offered;

  dataCombo = Tcl_GetVar2Ex(interp, "userinfo", "name", TCL_LEAVE_ERR_MSG);
  if (dataCombo) {
    dataCombo = Tcl_DuplicateObj(dataCombo);
  } else {
    return -1;
  }
  Tcl_AppendStringsToObj(dataCombo, "%", edition, "^", secret, NULL);
  if (my_hash(interp, dataCombo) == TCL_ERROR) {
    return -1;
  }
#else
  if (Tcl_VarEval(interp, "::md5::md5 $userinfo(name)%$userinfo(edn)^", 
		  secret, NULL) != TCL_OK) {
    /* raise another error so user doesnt see secret in trace */
    Tcl_VarEval(interp, "::md5::md5 $userinfo(name)%$userinfo(edn)^<secret>", 
		NULL);
    return -1;
  }
#endif

  /* check it matches what we got before */
  offered = Tcl_GetVar2(interp, "userinfo", "license_code", 0);
  if (!offered || strncmp(offered, Tcl_GetStringResult(interp), 10)) {
//    Tcl_AppendResult(interp, " is license code", (char *)NULL);
//    return -1;
    return 0;
  }
#endif
  return 1;
}

FINDABLE int loadcmdsCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
  if (argc != 1) {
    Tcl_WrongNumArgs(interp, 1, argv, "");
    return TCL_ERROR;
  }

  /* Data about version etc held in dll for safety and convenience:
     these will become globals because we are not in the scope of a
     procedure */
  Tcl_SetVar2Ex(interp, "userinfo", "final_expiry", 
		Tcl_NewLongObj(SIM_FINAL_EXPIRY), 0);
  Tcl_SetVar2Ex(interp, "userinfo", "days_after_install", 
		Tcl_NewIntObj(SIM_DAYS_AFTER_INSTALL), 0);
  switch (licenseRight(interp)) {
  case -1:
    return TCL_ERROR;
  case 0:
    crash(interp, "program");
  }

  Tcl_CreateObjCommand(interp, "loadmodel", loadmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_createmodel", createmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_setparamarray", setparamarrayCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
    
  Tcl_CreateObjCommand(interp, "c_settimepointarray", settimepointarrayCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_setrecordlist", setrecordlistCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_settimepointrecords", settimepointrecordsCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_cleartimeseries", cleartimeseriesCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  /*
  Tcl_CreateObjCommand(interp, "c_savetimepoint", savetimepointCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  */
  Tcl_CreateObjCommand(interp, "c_setparamelement", setparamelementCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_setparamall", setparamallCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_getparamall", getparamallCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_setwraparoundtime", setwrapCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_setfillmethod", setfillCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_settimepointelement", settimepointelementCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_settimepointall", settimepointallCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_gettimepointall", gettimepointallCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_resetmodel", resetmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_executemodel", executemodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_setstepmodel", setstepCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_exitmodel", exitmodelCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "getvalue", interfaceCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "graph_table", graphCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract", extractCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "insert", extractCmd, (ClientData)1,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "extract_binary", extractBinCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "distinct_values", extractBinCmd, 
		       (ClientData)1, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "getnodeid", getnodeidCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "listobjects", listobjCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "randseed", randseedCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "random01", random01Cmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  /*  Tcl_CreateObjCommand(interp, "c_set_connection_database", SetConnDBCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  */
  Tcl_CreateObjCommand(interp, "get_auth_code", GetAuthCodeCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "check_auth_code", CheckAuthCodeCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "get_simile_verson", GetVersionCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_killmodel", killmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  return TCL_OK;
}
 
FINDABLE int testlicenseCmd(ClientData clientData, Tcl_Interp *interp, 
			    int argc, Tcl_Obj *CONST argv[]) {
  int answer;
  answer = licenseRight(interp);
  if (answer == -1) {
    return TCL_ERROR;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewIntObj(answer));
    return TCL_OK;
  }
}

/*
 * The following declarations refer to internal Tk routines.  These
 * interfaces are available for use, but are not supported.
 */

//EXTERN void		TkConsoleCreate _ANSI_ARGS_((void));
//EXTERN int		TkConsoleInit _ANSI_ARGS_((Tcl_Interp *interp));

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AppInit --
 *

 *	This procedure performs application-specific initialization.
 *	Most applications, especially those that incorporate additional
 *	packages, will have their own version of this procedure.

 *
 * Results:
 *	Returns a standard Tcl completion code, and leaves an error
 *	message in interp->result if an error occurs.
 *
 * Side effects:
 *	Depends on the startup script.
 *
 * Note: 'version' is a global variable defined in the model,
 * and incremented for each new model program created -- this
 * should allow successive models to be built and executed in
 * c.
 *----------------------------------------------------------------------
 */

FINDABLE EXPORT int Ame_dll_Init(Tcl_Interp *interp) {
  char pkgName[16];

  globInterp = interp;
  proc_pointers_for_shank(respond_to_param_req, outeract_gui, showMess, 
			  simileVersion);
  sprintf(pkgName, "%d.%d", TCL_MAJOR_VERSION, TCL_MINOR_VERSION);
  /* Use the Tcl Stubs mechanism */
  Tcl_InitStubs(interp, pkgName, 0);
  Tcl_SetVar2(interp, "userinfo", "edn", edition, 0);
  Tcl_CreateObjCommand(interp, "c_testlicense", testlicenseCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(interp, "loadcommands", loadcmdsCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  sprintf(pkgName, "%d.%d.%s.%d", TCL_MAJOR_VERSION, TCL_MINOR_VERSION, 
	  simileVersion, FORUNIX);
  return Tcl_PkgProvide(interp, "Ame_dll", pkgName);
}
