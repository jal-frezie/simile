#include <stdio.h>
#include <sys/types.h>
#include <signal.h>

#ifdef WIN32
#include <process.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN

int kill (int pid, int sig) {
  HANDLE procHandle;
  BOOL outcome;
  
  procHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
  outcome = TerminateProcess(procHandle, sig);
  CloseHandle(procHandle);
  return(outcome);
}
 
void pause () {
  while (1) {
    Sleep(30000);
  }
}

#endif

main() {
  char fname[] = "pidpod";
  FILE* pip;
  int oldpid;
  pip = fopen(fname, "r");
  fscanf(pip, "%d", &oldpid);
  fclose(pip);
  pip = fopen(fname, "w");
  fprintf(pip, "%d", (int)getpid());
  fclose(pip);

  if (oldpid) {
    kill(oldpid, 15);
  }
  pause();
}
