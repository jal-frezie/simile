#include <pthread.h>

#ifdef _WIN32
#include <windows.h>
int spareForCount;
#define PIPENEW(ENDS) CreatePipe(ENDS, ENDS+1, NULL, 0)
#define PIPEREAD(SPOUT,BUF,COUNT) ReadFile(SPOUT,BUF,COUNT,spareForCount,NULL)
#define PIPEWRITE(SPOUT,BUF,COUNT) WriteFile(SPOUT,BUF,COUNT,spareForCount,NULL)
#else
#include <unistd.h>
#define PIPENEW(ENDS) pipe(ENDS)
#define PIPEREAD(SPOUT,BUF,COUNT) read(SPOUT,BUF,COUNT)
#define PIPEWRITE(SPOUT,BUF,COUNT) write(SPOUT,BUF,COUNT)
#endif

#include <dllcalls.h>
#include <backend.h>

// for use by generated code
int pipeRead(int spout, char* buf, int count) {
  return PIPEREAD(spout, buf, count);
}

int pipeWrite(int spout, char* buf, int count) {
  return PIPEWRITE(spout, buf, count);
}

thread_local int lazy = 16384, phoneHome = -1;

void setup_thread(int id, int mic) {
  setup_thread_randoms(1234567890, id);
  phoneHome = mic;
}

// pipe to master or NULL if already there
// guaranteed never to be a valid file descriptor
void InstanceOfModel::abort_check () {
  int valToSend = WORKER_QUERY_GUI;
  if (!lazy--) {
    lazy=16384;
    if (phoneHome == -1) { // in master, save to prod Tcl
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
  static int go[2], come[2];
  int i, snf[2];
  static ModelThread* pThd[NUM_THREADS];

  if (phase == -10) { // special exit value to tidy up threads
    close(go[1]);
    for( i = 0; i < NUM_THREADS; i++ ) {
      pthread_join(pThd[i]->thread, NULL);
      delete pThd[i];
    }
    return;
  }

  if (phase == -2) { // initialize the threads and comms
    PIPENEW(go);
    PIPENEW(come);
    phoneHome = -1; // guaranteed never to be a valid file descriptor
    
    for( i = 0; i < NUM_THREADS; i++ ) {
      pThd[i] = new ModelThread;
      pThd[i]->tid = i+1;
      pThd[i]->go = go[0]; // only copy pipe ends needed by thread
      pThd[i]->come = come[1];
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
