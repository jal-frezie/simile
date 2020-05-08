#include <pthread.h>

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

// for use by generated code
TSPOUT homeCalling, phoneHome;
int pipeRead(char* buf, int count) {
  return PIPEREAD(homeCalling, buf, count);
}

int pipeWrite(char* buf, int count) {
  return PIPEWRITE(phoneHome, buf, count);
}

thread_local int lazy = 16384;
thread_local int amWorker = 0;

void setup_thread(int id) {
  setup_thread_randoms(1234567890, id);
  amWorker = 1;
}

// pipe to master or NULL if already there
// guaranteed never to be a valid file descriptor
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

#define NUM_THREADS 6
#define NUM_TASKS 48

void InstanceOfModel::thread_mgr(void* (*worker_fn)(void*),
				 int phase, void* context, int loop) {
  static TSPOUT go[2], come[2];
  int i, snf[2];
  static ModelThread* pThd[NUM_THREADS];

  if (phase == -10) { // special exit value to tidy up threads
    PIPECLOSE(go[1]);
    for( i = 0; i < NUM_THREADS; i++ ) {
      pthread_join(pThd[i]->thread, NULL);
      delete pThd[i];
    }
    return;
  }

  if (phase == -2) { // initialize the threads and comms
    PIPENEW(go);
    PIPENEW(come);
    amWorker = 0;
    // pipe ends used by worker thread
    homeCalling = go[0];
    phoneHome = come[1];
    
    for( i = 0; i < NUM_THREADS; i++ ) {
      pThd[i] = new ModelThread;
      pThd[i]->tid = i+1;
      pThd[i]->context = context;
      pthread_create(&(pThd[i]->thread), NULL, worker_fn, pThd[i]);
    }
  } // end initialization
  for( i = 0; i < NUM_THREADS; i++ ) {
    pThd[i]->phase = phase;
  }
  snf[1] = 0;
  for (i=1; i<=NUM_TASKS; ++i) {
    snf[0] = snf[1]+1;
    snf[1] = loop*i/NUM_TASKS;
    PIPEWRITE(go[1], (char*)snf, 2*sizeof(int));
  }
  
  for (i=1; i<=NUM_TASKS; ++i) {
    PIPEREAD(come[0], (char*)snf, sizeof(int));
    if (*snf == WORKER_QUERY_GUI) { // thread not finished, checking interrupt
      if (stat_check(partner))
	throw -101;
      --i; // do not count finish
    }
  }
  // terminate threads -- do in exit?
  // close(payload.ports[1]);
  
  // for( i = 0; i < NUM_THREADS; i++ ) {
  //   pthread_join(threads[i], NULL);
  // }
  
};
