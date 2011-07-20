/* cmx stands for c model extensions
This builds into a shared library which is loaded by Tcl when
AME starts up. Subsequently it can itself load other shared
libraries corresponding to compiled model programs, and allow
them to be executed etc by Tcl commands. */

#include <tcl.h>

#ifdef WIN32
#define FORUNIX 0
#else
#define FORUNIX 1
#endif
#include <locale.h>

// Definitions used in this code and the model code
#include <dllcalls.h>

// seeems OK for arrays to be globals? Then why not...[1]
char simileVersion[] = SIMILE_VERSION;
char globMess[255];

void showMess (const char* mess) {
  // Tcl_VarEval(globInterp, "tk_messageBox -title {c++ debug} -icon info -message {", mess, "} -type ok",
  // NULL);
  printf("%s\n", mess);
}

/* this simply makes up a tcl list of all the objects that
appear in the object table. */

int list(void* listType, Tcl_Interp *interp) {

  Tcl_Obj *resultPtr;
  char* find;
  int line, nodecount, gcount;
  node_data_line* node_data;

  resultPtr = Tcl_GetObjResult(interp);
  nodecount = get_node_count(listType);
  for (line=0; line<nodecount; line++) {
    node_data = get_data_line(listType, line);
    Tcl_ListObjAppendElement(interp, resultPtr, 
			     Tcl_NewStringObj(node_data->name, -1));
    for (gcount=0; gcount<node_data->ghost_count;++gcount) {
      Tcl_ListObjAppendElement(interp, resultPtr,
			       Tcl_NewStringObj(node_data->ghost_ref_ptrs[gcount].ghost, -1));
    }
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
    graphptr = find_graph_by_index(index, *graphdata);
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

    graphptr = find_graph_by_index(index, *graphdata);
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

FINDABLE int interfaceCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int error;
  void* modelType;

  if (argc < 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id node_id action ?parameters?");
    return TCL_ERROR;
  }

  memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
  char current[255];
  int dims[32], path[32];
  Tcl_Obj *resultPtr, *oneType;
  int action, count;
  node_data_line *data_line;
  enum_type_data *usedTypes[32], **usedTypePtr;

  error = Tcl_GetIntFromObj(interp, argv[3], &action);
  if (error != TCL_OK) {
    return error;
  } /* if(error) */

  if (!(data_line=searchinfo(Tcl_GetStringFromObj(argv[2], NULL), modelType,
			     current, dims, usedTypes))) {
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
				   Tcl_NewIntObj(data_line->path[count])) != 
	  TCL_OK) {
	return TCL_ERROR;
	}
    } while (data_line->path[count++]);
    break;

  case GETCLASS:
    resultPtr = Tcl_NewIntObj(data_line->compclass);
    break;

  case GETTYPE: // return old version
    resultPtr = Tcl_NewIntObj(-data_line->datatype);
    break;

  case GETEVAL:
    if (strcmp(data_line->name, Tcl_GetStringFromObj(argv[2], NULL)))
      // data line has different id, original must have been a ghost
      resultPtr = Tcl_NewIntObj(GHOST);
    else
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
    return do_graph(get_graph_base(modelType), interp, action, data_line->graph,
		    argc-1, argv+1);

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
   global even though they may refer to stuff by model type and instance

   This is no longer used...

void get_tcl_value_pointer(void* modelPtr, void* tgt, int paramId, 
			   int count, int* inds) {
  node_data_line* data_line;
  char caption[255];
  const char* varName;
  int dims[32], path[32];
  Tcl_Obj* valPtr;
  int stepIndex, rv;
  void* mSpare;
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
    default: // could be VALUELESS if getting number of instances for record 
             // submodel, INTEGER or ENUM(*)
         // if someone enters a float in a slider entry box or time series for
	 // an integer input, we want the nearest int value...
      serviceError = Tcl_GetDoubleFromObj(globInterp, valPtr, &makeInt);
      if (serviceError == TCL_OK) {
	*(int*)tgt = (int)(makeInt);
      }
      return;
    }
  }
}
*/
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

//connectRecord** connectDataPtr;
//int* connCountPtr;

FINDABLE int loadmodelCmd(ClientData clientData, Tcl_Interp *interp, 
			    int argc, Tcl_Obj *CONST argv[]) {
  char* fileName;
  char* nodeName;
  char* dllProblem;
  void* modelType;

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
    Tcl_SetObjResult(interp, Tcl_NewByteArrayObj((char*)&modelType, 
						 sizeof(void*)));
    break;
    
  default:
    Tcl_WrongNumArgs(interp, 1, argv, "filename node_id");
    return TCL_ERROR;
  }
  return TCL_OK;
}

/* Create also sets up the tables required to get data out of one submodel
   instance into another...or at least used to */

FINDABLE int createmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  void* modelType;
  void* modelHandle;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id");
    return TCL_ERROR;
  }
  
  memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  modelHandle = fetch_top_instance(modelType, interp);
  if (modelHandle) {
    // save interp for callbacks from instance
    Tcl_SetByteArrayObj(Tcl_GetObjResult(interp), (char*)&modelHandle, 
			sizeof(void*));
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
  void* modelInst;
  void* fpHandle;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "instance_id node_id");
    return TCL_ERROR;
  }
  
  memcpy(&modelInst, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  fpHandle = use_array_for_params(modelInst, 
				  Tcl_GetStringFromObj(argv[2], NULL));
  if (fpHandle) {
    Tcl_SetByteArrayObj(Tcl_GetObjResult(interp), (char*)&fpHandle, 
			sizeof(void*));
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("Failed to make array for this node", -1));
    return TCL_ERROR;
  }
}

FINDABLE int cleartimeseriesCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  void* fpHandle;
  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  clear_time_point_elts(fpHandle);
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
  void* fpHandle;
  double *time;

  if (argc != 2 && argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id ?time?");

    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  if (time=get_wrap_ptr(fpHandle))
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
  void* fpHandle;

  if (argc != 2 && argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id ?method?");

    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  if (mtd=get_fill_ptr(fpHandle))
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
  void* fpHandle;
  double timePt;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id time");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  error = Tcl_GetDoubleFromObj(interp, argv[2], &timePt);
  if (error != TCL_OK) {
    return error;
  }

  if (!create_time_point(fpHandle, timePt)) {
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
  indxs[i]=0; // terminate array
  return TCL_OK;
}

FINDABLE int setrecordlistCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error, indxs[32], *dims;
  void* fpHandle;
  char* bloc;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id index_list value");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  if ((error = ints_from_list(interp, argv[2], indxs)) != TCL_OK)
    return error;

  error = Tcl_GetIntFromObj(interp, argv[3], &count);
  if (error != TCL_OK) {
    return error;
  }
  bloc = get_param_ptr_and_dims(fpHandle, &dims);
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
  void* fpHandle;
  char* bloc;
  double timePt;

  if (argc != 5) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id index_list time value");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));

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
  switch (get_timepoint_ptr_and_dims(fpHandle, timePt, &bloc, &dims)) {
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
  void* fpHandle;
  double val;
  char* bloc;
  
  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id index_list value");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  error = Tcl_GetDoubleFromObj(interp, argv[3], &val);
  if (error != TCL_OK) {
    return error;
  }
  
  if ((error = ints_from_list(interp, argv[2], indxs)) != TCL_OK)
    return error;
  
  bloc = get_param_ptr_and_dims(fpHandle, &dims);
  if (!bloc) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("set_param_array_elt: no array has been created for this node", -1));
    return TCL_ERROR;
  }
  //sprintf(globMess, "setting element %d %d of %d %d in %lx to %lf",
  //	  indxs[0], indxs[1], dims[0], dims[1], (long unsigned int)bloc, val);
  //showMess(globMess);
  set_bloc_element(bloc, dims, indxs, val);
  return TCL_OK;
}

FINDABLE int markevtparamactiveCmd(ClientData clientData, Tcl_Interp *interp,
				int argc, Tcl_Obj *CONST argv[]) {
  int i, error, indxs[32], *dims;
  void* fpHandle;
  double val;
  char* bloc;
  
  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  mark_values_active(fpHandle);
  return TCL_OK;
}

/* For this one, we have all the data in a Tcl ByteArray object */

FINDABLE int setparamallCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error, indxs[32];
  void* fpHandle;
  void *sourcePtr, *destPtr;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id data indices");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  if ((error = ints_from_list(interp, argv[3], indxs)) != TCL_OK)
    return error;

  sourcePtr = Tcl_GetByteArrayFromObj(argv[2], &count);
  
  // OK, clever stuff (probably in shank) to go here...
  destPtr = get_param_data_space(fpHandle);
  memcpy(destPtr, sourcePtr, count);
  return TCL_OK;
}

FINDABLE int getparamallCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int count, error;
  void* fpHandle;
  char *nodeId;
  unsigned char *holder;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  count=param_array_size(fpHandle);
  holder = Tcl_SetByteArrayLength(Tcl_GetObjResult(interp), count);
  memcpy(holder, get_param_data_space(fpHandle), count);
  return TCL_OK;
}

FINDABLE int settimepointelementCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error, indxs[32], *dims;
  void* fpHandle;
  double time, val;
  char* bloc;

  if (argc != 5) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id index_list time value");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));

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
  switch (get_timepoint_ptr_and_dims(fpHandle, time, &bloc, &dims)) {
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
  void* fpHandle;
  char *ptBytes;
  unsigned char *holder;
  double seekTime;
  Tcl_Obj* resultPtr;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id data");
    return TCL_ERROR;
  }
  
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
  if (count=param_array_size(fpHandle)) {
    holder = Tcl_GetByteArrayFromObj(argv[2], &num_bytes);
//    sprintf(globMess, "Array has %d bytes, time points %d", num_bytes, count);
//    showMess(globMess);
    while (squirtPtr<num_bytes) {
// Needs new system
      seekTime = *(double*)(holder+squirtPtr);
      if (create_time_point(fpHandle, seekTime)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("Failed to make array for this node", -1));
	return TCL_ERROR;
      }
      get_timepoint_ptr_and_dims(fpHandle, seekTime, &ptBytes, &dims);
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
  void* fpHandle;
  unsigned char *holder;
  void *ptBytes;
  double seekTime;
  Tcl_Obj* resultPtr;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "param_id");
    return TCL_ERROR;
  }
  memcpy(&fpHandle, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
  if (count=param_array_size(fpHandle)) { // assignment
    currentSize = (count + sizeof(double))/2;
    resultPtr = Tcl_NewObj();
    holder = Tcl_SetByteArrayLength(resultPtr, currentSize);
    seekTime = -1e100;
    // copy data for each timept to ByteArray, doubling its size if too small
    while (ptBytes=find_next_timept_space(fpHandle, &seekTime)) { // assignment
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
  } else if (error == -99) {
    sprintf(spare, "discontinuity");
  } else if (error == -98) {
    sprintf(spare, "event");
  } else if (error < 0) {
    sprintf(spare, "Illegal operation signal %d", -error);
  } else {
    sprintf(spare, "User-defined interruption code %d", error);
  }
}

const char* name_in_line(void* modelType, int lineId) {
    node_data_line *nodeLine;

    if (lineId)
      if (nodeLine = nodlin_from_id(modelType, lineId))
	return nodeLine->strings[0];
      else
	return "limit event";
    else 
      return "external procedure";
}

FINDABLE int resetmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  char spare[256];
  int how_int, phase, error;
  excpData* errorBlk;
  void* modelType;
  void* modelHandle;
  double t0;

  if (argc != 6) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id initial_time integration_method phase");
    return TCL_ERROR;
  }
  
  memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  memcpy(&modelHandle, Tcl_GetByteArrayFromObj(argv[2], NULL), sizeof(void*));
  
  error = Tcl_GetDoubleFromObj(interp, argv[3], &t0);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetIntFromObj(interp, argv[4], &how_int);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetIntFromObj(interp, argv[5], &phase);
  if (error != TCL_OK) {
    return error;
  }
  errorBlk = reset(modelType, modelHandle, t0, how_int, phase);

  if (errorBlk) {
    get_string_for_error(spare, errorBlk->excpNo);
    Tcl_SetObjResult(interp, make_exec_error(interp, "resetmodel", 
					     name_in_line(modelType, 
							  errorBlk->targetId), 
					     t0, phase, spare));
    return TCL_ERROR;
  } else {
    return TCL_OK;
  }
}

FINDABLE int executemodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  char spare[256];
  double starttime, endtime, errlim;
  BOOLEAN evt_pause;
  int how_int, error;
  excpData* errorBlk;
  Tcl_Obj* working;
  void* modelType;
  void* modelHandle;

  if (argc != 8) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id integration_method start_time end_time error_limit pause_on_events");
    return TCL_ERROR;
  }
  
  memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));  
  memcpy(&modelHandle, Tcl_GetByteArrayFromObj(argv[2], NULL), sizeof(void*));
  
  error = Tcl_GetIntFromObj(interp, argv[3], &how_int);
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
  
  error = Tcl_GetBooleanFromObj(interp, argv[7], &evt_pause);
  if (error != TCL_OK) {
    return error;
  }
  
  errorBlk = execute(modelType, modelHandle, how_int, starttime, &endtime, 
		     errlim, evt_pause);
  error = 1; //i.e., no error
  if (errorBlk) {
    switch (errorBlk->excpNo) {
    case -100:
      error = 0;
      break;
      //    case -99:
      //error = -1;
      //break;
    default:
      get_string_for_error(spare, errorBlk->excpNo);
      Tcl_SetObjResult(interp, make_exec_error(interp, "evalmodel", 
					       name_in_line(modelType, 
							    errorBlk->targetId),
					       endtime, 1, spare));
      return TCL_ERROR;
    }
  }
  working = Tcl_NewIntObj(error);
  Tcl_ListObjAppendElement(interp, working, Tcl_NewDoubleObj(endtime)); 
  Tcl_SetObjResult(interp, working);
  return TCL_OK;
}

FINDABLE int setstepCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  double starttime;
  int phase;
  int error;
  void* modelInst;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "instance_id interval/phase step_id");
    return TCL_ERROR;
  }
  
  memcpy(&modelInst, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
  error = Tcl_GetDoubleFromObj(interp, argv[2], &starttime);
  if (error != TCL_OK) {
    return error;
  }
  
  error = Tcl_GetIntFromObj(interp, argv[3], &phase);
  if (error != TCL_OK) {
    return error;
  }
  
  Tcl_SetIntObj(Tcl_GetObjResult(interp), 
		setstep(modelInst, starttime, phase));
  return TCL_OK;
}

/* exit model: unload all dlls. If the handle is nonzero, free its data
   structures first (though this probably gets done when the dlls are unloaded
*/

FINDABLE int exitmodelCmd(ClientData clientData, Tcl_Interp *interp,
	int argc, Tcl_Obj *CONST argv[]) {
  int error;
  char* dllProblem;
  void* modelType;
  void* modelHandle;

  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id");
    return TCL_ERROR;
  }
  
  memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  memcpy(&modelHandle, Tcl_GetByteArrayFromObj(argv[2], NULL), sizeof(void*));
  
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
  void* modelType;
  
  if (argc != 3) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id caption");
    return TCL_ERROR;
  }
  
  memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
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

FINDABLE int graphCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int action, index, error;
  static graph_data_type* tcl_graphdata;

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
end of each model instance's ids

No longer used: they have been replaced by get_raw_values which are turned
into Tcl by unpacker.c

int match_type(void* localType, void* smHandle, int dims[], 
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

// next two call one another so one needs to be declared in advance

Tcl_Obj* fill_value(void*, void*, int[], int, int*, int[], int*, 
		    Tcl_Obj*);

Tcl_Obj* fill_list_value(void* localType, void** smHandle, int tree[], 
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
      *smHandle = *(void**)(get_ptr(localType, *smHandle, &short_tree, 
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

// fill_value extracts a list of values from the model. Type is the full
// id path to the component whose values we are after. use_dims is array
// of array sizes which we are to get all the values from. Dims is an
// array of ints for the indices in the arrays we are getting values
// from, and dim_place is the pointer into this array where we can add
// more values as we go through the loops up to the sizes specified in
// use_dims.

Tcl_Obj* fill_value(void* localType, void* smHandle, int tree[], 
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

    smHandle = *(void**)(get_ptr(localType, smHandle, &tree, &dims));
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

    smHandle = *(void**)(get_ptr(localType, smHandle, &tree, &dims));
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
    //case EXTERNAL:
    //  localObj = Tcl_NewStringObj("ex", -1);
    //  break;
    default: // INTEGER or ENUM(*)
      localObj = Tcl_NewIntObj(*(int *)model_val_ptr);
      if (nVs) {
	Tcl_GetIntFromObj(NULL, nVs, (int *)model_val_ptr);
      }
      break;
    }
    break;
  default: // value is a dimension of the array we are accessing
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
*/
FINDABLE int freeDataHandleCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  int error;
  nodeValues* toFree;

  if (argc != 2) {
    Tcl_WrongNumArgs(interp, 1, argv, "data_handle");
    return TCL_ERROR;
  }
  
  memcpy(&toFree, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  
  free_bloc_data(toFree->contents, toFree->dimSpecs);
  free(toFree);
  return TCL_OK;
}

FINDABLE int handleDataCmd(ClientData clientData, Tcl_Interp *interp,
		 int argc, Tcl_Obj *CONST argv[]) {
  Tcl_Obj *resultPtr, *newData;
  int error;
  /*
  char spare[256];
  int dims[32], path[32];
  void* mSpare;
  enum_type_data* usedTypes[32];
  */
  nodeValues* c_result;
  void* modelType;
  void* modelHandle;

  if (argc != 4) {
    Tcl_WrongNumArgs(interp, 1, argv, "model_id instance_id node_id");
    return TCL_ERROR;
  }
  
  memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));
  memcpy(&modelHandle, Tcl_GetByteArrayFromObj(argv[2], NULL), sizeof(void*));
  /* int count;
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
  resultPtr = Tcl_NewObj();

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
    Tcl_SetObjResult(interp, Tcl_NewByteArrayObj((char*)&c_result, sizeof(void*)));
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("component has no data", -1));
    return TCL_ERROR;
  }
}

FINDABLE int listobjCmd(ClientData clientData, Tcl_Interp *interp, 
		int argc, Tcl_Obj *CONST argv[]) {
   int error;
   void* modelType;

   if (argc != 2) {
     Tcl_WrongNumArgs(interp, 1, argv, "model_id");
     return TCL_ERROR;
   }
   memcpy(&modelType, Tcl_GetByteArrayFromObj(argv[1], NULL), sizeof(void*));

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
   setup_randoms(seed);
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

void respond_to_param_req(void* clientRef, void* modelSlot, double reqTime,
			  int paramId, int indCount, int* indices) {
  printf("Unwanted parameter value request at %lf\n", reqTime);
  Tcl_BackgroundError((Tcl_Interp*)clientRef);
}

BOOLEAN outeract_gui(void* ref, BOOLEAN stop_chk, double now) {
  BOOLEAN response;
  Tcl_Interp* globInterp = (Tcl_Interp*)ref;
  Tcl_Obj* feedbackCmd;

  Tcl_VarEval(globInterp, "update", NULL); // allow display to tell us if idle
  if (!Tcl_GetVar(globInterp, "::dispDone", 0))
    return 0; // do not wait for GUI if busy
  if (stop_chk) {
    feedbackCmd = Tcl_NewStringObj("OuteractGUI", -1);
    Tcl_ListObjAppendElement(globInterp, feedbackCmd, Tcl_NewDoubleObj(now));
    Tcl_ListObjAppendElement(globInterp, feedbackCmd, Tcl_NewIntObj(stop_chk));
  } else {
    feedbackCmd = Tcl_NewStringObj("OuterCheck", -1);
  }
  Tcl_EvalObjEx(globInterp, feedbackCmd, 0);

  /* if anything like this at all is done, it will communicate with tsv's */
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

  proc_pointers_for_shank(respond_to_param_req, outeract_gui, showMess);
  sprintf(pkgName, "%d.%d", TCL_MAJOR_VERSION, TCL_MINOR_VERSION);
  /* Use the Tcl Stubs mechanism */
  Tcl_InitStubs(interp, pkgName, 0);
  Tcl_CreateObjCommand(interp, "loadmodel", loadmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_createmodel", createmodelCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "c_createparamarray", setparamarrayCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
    
  Tcl_CreateObjCommand(interp, "newc_settimepointarray", settimepointarrayCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_setrecordlist", setrecordlistCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_settimepointrecords", 
		       settimepointrecordsCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_cleartimeseries", cleartimeseriesCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  /*
  Tcl_CreateObjCommand(interp, "c_savetimepoint", savetimepointCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  */
  Tcl_CreateObjCommand(interp, "newc_setparamelement", setparamelementCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_setwraparoundtime", setwrapCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_setfillmethod", setfillCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_settimepointelement", 
		       settimepointelementCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_markevtparamactive", 
		       markevtparamactiveCmd,
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  // next four were used for byte-array params so will not bother to update
  // to 6-D interface
  Tcl_CreateObjCommand(interp, "newc_setparamall", setparamallCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_getparamall", getparamallCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_settimepointall", settimepointallCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "newc_gettimepointall", gettimepointallCmd, 
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
  
  Tcl_CreateObjCommand(interp, "handle_data", handleDataCmd, (ClientData)NULL,
		       (Tcl_CmdDeleteProc *)NULL);
  
  Tcl_CreateObjCommand(interp, "free_data_handle", freeDataHandleCmd, 
		       (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  
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
  // sprintf(pkgName + strlen(pkgName), ".%s.%d", simileVersion, FORUNIX);
  return Tcl_PkgProvide(interp, "Ame_dll", pkgName);
}
