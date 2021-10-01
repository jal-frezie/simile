#include <time.h>

#define BUFSIZE 256
#ifdef _WIN32
#include <windows.h>
#include <tchar.h>
#define PIPENEW(ENDS) CreatePipe(ENDS, ENDS+1, NULL, 0)
#define PIPEREAD(SPOUT,BUF,COUNT) ReadFile(SPOUT,BUF,COUNT,&spareForCount,NULL)
#define PIPEWRITE(SPOUT,BUF,COUNT) WriteFile(SPOUT,BUF,COUNT,&spareForCount,NULL)
#define PIPECLOSE(SPOUT) CloseHandle(SPOUT)
long unsigned int spareForCount;
#else
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#define PIPENEW(ENDS) pipe(ENDS)
#define PIPEREAD(SPOUT,BUF,COUNT) read(SPOUT,BUF,COUNT)
#define PIPEWRITE(SPOUT,BUF,COUNT) write(SPOUT,BUF,COUNT)
#define PIPECLOSE(SPOUT) close(SPOUT)
#endif

#include <dllcalls.h>
#include <backend.h>

// eventually all model support code should go here to avoid user building it
int compare_instance_status (const int pointers[], const int ref_pointers[], 
			     int num) {
   int count;
   for (count=0; count<num; count++) {
     if (pointers[count]<ref_pointers[count]) return -1;
     if (pointers[count]>ref_pointers[count]) return 1;
   }
   return 0;
}

#define PASSUP_TIMER 1048576
thread_local int amWorker = 0;
thread_local int lazy = PASSUP_TIMER;

void setup_thread(int id) {
  setup_thread_randoms(1234567890, id);
  amWorker = id; // workers start from 1
}

// pipe to master or NULL if already there
// guaranteed never to be a valid file descriptor
TSPOUT homeCalling, phoneHome;

void InstanceOfModel::abort_check () {
  int valToSend = WORKER_QUERY_GUI;
  if (!lazy--) {
    lazy = PASSUP_TIMER;
    if (!amWorker) { // in master, save to prod Tcl
      if (stat_check(partner))
	throw -101;
    } else
      PIPEWRITE(phoneHome, (char*)&valToSend, sizeof(int));	
  }
}
#ifdef SIM_PAR_EXEC

int *timeReading;
int *timeWriting;
int *timeIdle;
long int *timers;
int *endPts;

long int now() {
  struct timespec tp;
  clock_gettime(CLOCK_MONOTONIC, &tp);
  return 1000000000l*tp.tv_sec+tp.tv_nsec;
}

// for use by generated code
int pipeRead(char* buf, int count) {
  int got;
  timers[amWorker] = now();
  got = PIPEREAD(homeCalling, buf, count);
  timeReading[amWorker] += (now()-timers[amWorker]);
  return got;
}

int pipeWrite(char* buf, int count) {
  int got;
  timers[amWorker] = now();
  got = PIPEWRITE(phoneHome, buf, count);
  timeWriting[amWorker] += (now()-timers[amWorker]);
  return got;
}

int reporting;

void InstanceOfModel::thread_mgr(void* (*worker_fn)(void*),
				 int phase, void* context, int loop,
				 int nThread, int nTask, double taper) {
  static TSPOUT go[2], come[2];
  int i, snf[2];
  static ModelThread** pThd;
  long int stopwatch;
  static long int smTotal = 0, clock;

  if (phase == -10) { // special exit value to tidy up threads
    PIPECLOSE(go[1]);
    for( i = 0; i < nThread; i++ ) {
      pthread_join(pThd[i]->thread, NULL);
      delete pThd[i];
    }
    free(timeReading);
    free(timeWriting);
    free(timeIdle);
    free(timers);

    free(endPts);
    return;
  }

  stopwatch = now();
  smTotal -= stopwatch;

  if (phase == -2) { // initialize the threads and comms
    printf("Threads: %d, tasks: %d, taper: %lf\n", nThread, nTask, taper);
    pThd = (ModelThread**)malloc(nThread*sizeof(void*));
    
    timeReading = (int*)malloc((nThread+1)*sizeof(int));
    timeWriting = (int*)malloc((nThread+1)*sizeof(int));
    timeIdle = (int*)malloc((nThread+1)*sizeof(int));
    timers = (long int*)malloc((nThread+1)*sizeof(long int));

    endPts = (int*)malloc(nTask*sizeof(int));
    
    PIPENEW(go);
    PIPENEW(come);
    amWorker = 0;
    // pipe ends used by worker thread
    homeCalling = go[0];
    phoneHome = come[1];
    
    timeReading[0] = timeWriting[0] = timeIdle[0] = 0;
    for( i = 0; i < nThread; i++ ) {
      pThd[i] = new ModelThread;
      pThd[i]->tid = i+1;
      pThd[i]->context = context;
      pthread_create(&(pThd[i]->thread), NULL, worker_fn, pThd[i]);
      timeReading[i+1] = timeWriting[i+1] = timeIdle[i+1] = reporting = 0;
    }

    for (i=0; i<nTask; ++i) {
      if (taper==1) { // general calculation breaks
	endPts[i] = loop*(i+1)/nTask;
      } else {
	endPts[i] = loop*(1-exp(-(i+1)*log(taper)/nTask))/(1-1/taper);
      }
    }
    // first task must be same size for all threads
    for (i=0;i<nThread-1;++i) {
      endPts[i] = (i+1)*endPts[nThread-1]/nThread;
    }
    printf("End points %d ... %d %d %d\n", endPts[0], endPts[nTask-3],
	   endPts[nTask-2], endPts[nTask-1]);
    clock = stopwatch;
  } // end initialization
  for( i = 0; i < nThread; i++ ) {
    pThd[i]->phase = phase;
    pThd[i]->context = context; // needed in initialization but may have changed
    // Start recording time as pipe reading overhead
    timers[i+1] = stopwatch;
  }
  snf[1] = 0;
  for (i=0; i<nTask; ++i) {
    snf[0] = snf[1]+1;
    snf[1] = endPts[i];
    PIPEWRITE(go[1], (char*)snf, 2*sizeof(int));
  }
  
  for (i=1; i<=nTask; ++i) {
    PIPEREAD(come[0], (char*)snf, sizeof(int));
    if (*snf == WORKER_QUERY_GUI) { // thread not finished, checking interrupt
      if (stat_check(partner))
	throw -101;
      --i; // do not count finish
    }
  }
  // Step is over, record idle times
  stopwatch = now();
  smTotal += stopwatch;
  for (i=1; i<=nThread; ++i) {
    timeIdle[i] += (stopwatch-timers[i]);
  }

  if (++reporting == 256) {
    for (i=1; i<=nThread; ++i) {
      timeReading[0] += timeReading[i];
      timeWriting[0] += timeWriting[i];
      timeIdle[0] += timeIdle[i];
      timeReading[i] = timeWriting[i] = timeIdle[i] = 0;
    }
    printf("Real %.3f, total %.3f, reading %.3f, writing %.3f, idle %.3f\n",
	   (stopwatch-clock)/1e9, nThread*smTotal/1e9, timeReading[0]/1e9,
	     timeWriting[0]/1e9, timeIdle[0]/1e9);
    reporting = 0;
    smTotal = 0;
    clock=stopwatch;
    timeReading[0] = timeWriting[0] = timeIdle[0] = 0;
  }
  // terminate threads -- do in exit?
  // close(payload.ports[1]);
  
  // for( i = 0; i < nThread; i++ ) {
  //   pthread_join(threads[i], NULL);
  // }
  
};
#endif

/*****************************************************************/
// STUFF FOR INCLUDING A REMOTE SUBMODEL BY PIPE INTERFACE       //
/*****************************************************************/
int setServerPipe (const char* pipeName, TSPOUT* service) {
#ifdef _WIN32
  // use named pupes
  char nbuffer[BUFSIZE] = "\\\\.\\pipe\\";
  strcat(nbuffer, pipeName);
  TCHAR *ttemp = new TCHAR[strlen(nbuffer)+1];
  _tcscpy(ttemp, nbuffer); // remember to free it
  *service = (TSPOUT)ttemp;
#else
  // UNIX -- use sockets
  struct sockaddr_un name;
  int connection_socket, ret;

  connection_socket = socket(AF_UNIX, SOCK_STREAM, 0);
  if (connection_socket == -1)
    return 70;  

  memset(&name, 0, sizeof(struct sockaddr_un));

  name.sun_family = AF_UNIX;
  strncpy(name.sun_path, pipeName, sizeof(name.sun_path) - 1);

  ret = bind(connection_socket, (const struct sockaddr *) &name,
	     sizeof(struct sockaddr_un));
  if (ret == -1)
    return 71;

  ret = listen(connection_socket, 20);
  if (ret == -1)
    return 72;

  *service = connection_socket;
#endif
  return 0;
}

void run_external(const char* cmd) {
  // needed because just calling system() complains return value is not used
  // even though command ends in '&' so always always always returns 0
  if (system(cmd)) {}
}

int getClientPipe (TSPOUT service, TSPOUT* data_socket) {
#ifdef _WIN32
  // use named pupes
      *data_socket = CreateNamedPipe( 
	  (LPCTSTR)service,             // pipe name 
          PIPE_ACCESS_DUPLEX,       // read/write access 
          PIPE_TYPE_MESSAGE |       // message type pipe 
          PIPE_READMODE_MESSAGE |   // message-read mode 
          PIPE_WAIT,                // blocking mode 
          PIPE_UNLIMITED_INSTANCES, // max. instances  
          BUFSIZE,                  // output buffer size 
          BUFSIZE,                  // input buffer size 
          0,                        // client time-out 
          NULL);                    // default security attribute 

      if (*data_socket == INVALID_HANDLE_VALUE) 
      {
          printf("CreateNamedPipe failed, GLE=%d.\n", GetLastError()); 
          return -1;
      }
      BOOL fConnected = ConnectNamedPipe(*data_socket, NULL) ? 
         TRUE : (GetLastError() == ERROR_PIPE_CONNECTED); 
 
      if (fConnected)
	return 0;
      else
	return 73;
#else
  // UNIX -- use sockets
  *data_socket = accept(service, NULL, NULL);
  if (*data_socket == -1)
    return 73;
#endif
  return 0;
}

extern int nodecount;
extern node_data_line nodedata[];

int find_graph(int graph) {
  for (int nodeLine=0; nodeLine<nodecount; ++nodeLine)
    if (nodedata[nodeLine].graph == graph) return nodeLine;
  return -1;
}

int find_member(char* member, enum_type_data *dimType) {
  int ordinal;
  
  for (ordinal=0; ordinal<dimType->count;++ordinal)
    if (strcmp(member, dimType->members[ordinal])==0) return ordinal;
  return -1;
}

int get_BOOLEAN_from_pipe(TSPOUT where, BOOLEAN* what) {
  int ness=PIPEREAD(where, (char*)what, sizeof(BOOLEAN));
  //  printf("Recvd %d\n", *what);
  return ness;
}
int get_int_from_pipe(TSPOUT where, int* what) {
  int ness=PIPEREAD(where, (char*)what, sizeof(int));
  // printf("Recvd %d\n", *what);
  return ness;
}
int get_double_from_pipe(TSPOUT where, double* what) {
  int ness=PIPEREAD(where, (char*)what, sizeof(double));
  // printf("Recvd %lf\n", *what);
  return ness;
}
int get_array_from_pipe(TSPOUT where, void* what, int count) {
  int ness=PIPEREAD(where, (char*)what, count);
  // printf("Recvd %d bytes\n", ness);
  int rem = count-ness;
  if (rem>0) get_array_from_pipe(where, (char*)what+ness, rem);
  return count;
}
int get_chars_from_pipe(TSPOUT where, char* what) {
  unsigned char length;
  get_BOOLEAN_from_pipe(where, &length); // length may be more than 1 byte for longer strs
  get_array_from_pipe(where, what, length);
  what[length] = 0; // terminate the string
  // printf("Recvd %s\n", what);
  return length;
}
int get_member_from_pipe(TSPOUT where, int graph, const char* ETid, int* what) {
  int mdDims[32], nTypes, curType;
  enum_type_data *types[32];
  char instName[BUFSIZE];

  int nodeLine = find_graph(graph);
  nTypes = make_full_caption(nodeLine, instName, mdDims, types);
  for (curType=0; curType<nTypes; ++curType)
    if (strcmp(types[curType]->name, ETid)==0) break;
  get_chars_from_pipe(where, instName);
  *what = find_member(instName, types[curType])+1;
  return 1;
}
int put_BOOLEAN_in_pipe(TSPOUT where, BOOLEAN what) {
  int ness=PIPEWRITE(where, (char*)&what, sizeof(BOOLEAN));
  // printf("Sent %d\n", what);
  return ness;
}
int put_int_in_pipe(TSPOUT where, int what) {
  int ness=PIPEWRITE(where, (char*)&what, sizeof(int));
  // printf("Sent %d\n", what);
  return ness;
}
int put_double_in_pipe(TSPOUT where, double what) {
  int ness=PIPEWRITE(where, (char*)&what, sizeof(double));
  // printf("Sent %lf\n", what);
  return ness;
}
int put_array_in_pipe(TSPOUT where, void* what, int count) {
  int ness=PIPEWRITE(where, (char*)what, count);
  // printf("Sent %d bytes\n", ness);
  return ness;
}
int put_chars_in_pipe(TSPOUT where, char* what) {
  int length;
  length = strlen(what);
  put_BOOLEAN_in_pipe(where, (BOOLEAN)length); // length may be more than 1 byte for longer strs
  put_array_in_pipe(where, what, length);
  // printf("Sent %s\n", what);
  return length;
}
int put_member_in_pipe(TSPOUT where, int graph, const char* ETid, int what) {
  int mdDims[32], nTypes, curType;
  enum_type_data *types[32];
  char instName[BUFSIZE];

  int nodeLine = find_graph(graph);
  nTypes = make_full_caption(nodeLine, instName, mdDims, types);
  for (curType=0; curType<nTypes; ++curType)
    if (strcmp(types[curType]->name, ETid)==0) break;
  return put_chars_in_pipe(where, types[curType]->members[what-1]);
}

int get_client_indices(TSPOUT where, int sm_graph_id, int destIdcs[]) {
  char instName[BUFSIZE];
  int nodeLine, mdDims[32], curDim, place, nTypes;
  enum_type_data *types[32];

  // first, translate that graph id to a node line
  nodeLine = find_graph(sm_graph_id);
  
  // plunder the metadata
  nTypes = make_full_caption(nodeLine, instName, mdDims, types);
  // instName set to submodel caption path -- not used

  place=0;
  while (curDim = mdDims[place]) { // assignment
    // while (curDim = mdDims[place]) {} // assignment
    if (curDim > ENUM_BASE) // numerical dimension, boring
      get_int_from_pipe(where, destIdcs + place);
    else { // enumerated type dimension, rock'n'roll
      get_chars_from_pipe(where, instName);
      destIdcs[place] = find_member(instName, types[ENUM_BASE-curDim]);
     if (destIdcs[place] == -1) return 78; // none match, raise issue
    }
    ++destIdcs[place]; // convert to treehugger convention
    ++place;
  }
  return 0;
}

int parent_line (int line) {
  int count, level, test, *path;
  path = nodedata[line].path;
  for (count=0;nodecount>count;count++) {
    level = 0;
    while ( (test = nodedata[count].path[level]) ) {
      if (test != path[level++]) {
	break;
      }
      
    }
    if (!test && path[level] && (!path[level+1] || 
				 (path[level+1]<0 && !path[level+2]))) {
      return(count);
    }
  }
  return(-1);
}

int make_full_caption(int line, char *result, int* dims,
			 enum_type_data** types) {
    // New version which does not depend on the nodedata array being in
    // any particular order -- and returns the whole caption
  int parent, typesSoFar, count, dimCount=0;
  for (count=0; count<nodedata[line].enum_type_count; ++count) {
    types[count]=&(nodedata[line].enum_type_ptrs[count]);
  }
  if ((parent = parent_line(line)) >= 0) {
    typesSoFar = count+make_full_caption(parent, result, dims, types+count);
    strcat(result, "/");
  } else {
    *result = (char)NULL;
    *dims = 0;
    typesSoFar = count;
  }
  // correct earlier enum type references to take account of this level
  count = 0;
  while (dims[count]) {
    if (dims[count] <= ENUM_BASE) {
      dims[count] = dims[count] - nodedata[line].enum_type_count;
    }
    count++;
  }
  // add this levels caption unless it is top
  if (parent>=0  || nodedata[line].compclass != SUBMODEL)
    strcat(result, nodedata[line].strings[0]);
  
  do dims[count]=nodedata[line].dims[dimCount++];
  while (dims[count++]);
// add this levels type data -- reverse order cos outer models start list
    // for (count=nodedata[line].enum_type_count-1;count>=0;--count) {
    // types[typesSoFar++]=&(nodedata[line].enum_type_ptrs[count]);
    // } ...not any more
  return typesSoFar;
}

