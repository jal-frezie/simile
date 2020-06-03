#include <time.h>

#ifdef _WIN32
#include <windows.h>
#define PIPENEW(ENDS) CreatePipe(ENDS, ENDS+1, NULL, 0)
#define PIPEREAD(SPOUT,BUF,COUNT) ReadFile(SPOUT,BUF,COUNT,&spareForCount,NULL)
#define PIPEWRITE(SPOUT,BUF,COUNT) WriteFile(SPOUT,BUF,COUNT,&spareForCount,NULL)
#define PIPECLOSE(SPOUT) CloseHandle(SPOUT)
#define TSPOUT HANDLE
long unsigned int spareForCount;
#else
#include <unistd.h>
#define PIPENEW(ENDS) pipe(ENDS)
#define PIPEREAD(SPOUT,BUF,COUNT) read(SPOUT,BUF,COUNT)
#define PIPEWRITE(SPOUT,BUF,COUNT) write(SPOUT,BUF,COUNT)
#define PIPECLOSE(SPOUT) close(SPOUT)
#define TSPOUT int
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

thread_local int amWorker = 0;
thread_local int lazy = 16384;

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
    lazy=16384;
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
  clock_gettime(CLOCK_MONOTONIC_RAW, &tp);
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
