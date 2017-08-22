#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>

#ifdef WIN32
#include <process.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN

#ifdef USE_SEMAPHORE
HANDLE g_hSemaphore;
#else
int kill (int pid, int sig) {
  HANDLE procHandle;
  BOOL outcome;
  DWORD       dwExitCode;
  
  procHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
  if (sig) {
    outcome = TerminateProcess(procHandle, sig);
    CloseHandle(procHandle);
    return(outcome);
  } else {
    GetExitCodeProcess( procHandle, &dwExitCode );
    if (!pid || dwExitCode == STILL_ACTIVE) {
      return(0);
    } else {
      return(-1);
    }
  }
}
 
void pause () {
  while (1) {
    Sleep(30000);
  }
}
#endif
#endif
FILE* pip;
char fname[256];
char mess[256];

int main(int argc, char* argv[]) {
#ifdef USE_SEMAPHORE
	/*
	http://msdn.microsoft.com/library/default.asp?url=/library/en-us/dllproc/base/createsemaphore.asp
	The state of a semaphore is signaled when its count is greater than zero and nonsignaled when it 
	is zero.  The count is decreased by one whenever a wait function releases a thread that was 
	waiting for the semaphore.

	Any thread of the calling process can specify the semaphore-object handle in a call to one of the 
	wait functions. The single-object wait functions return when the state of the specified object is 
	signaled. When a wait function returns, the waiting thread is released to continue its execution.

	Multiple processes can have handles of the same semaphore object, enabling use of the object for 
	interprocess synchronization. A process can specify the name of a semaphore object in a call to 
	the OpenSemaphore or CreateSemaphore function. 

	Use the CloseHandle function to close the handle. The system closes the handle automatically 
	when the process terminates. The semaphore object is destroyed when its last handle has been closed
	*/
	
	
	// Create semaphore with name Local\SimilePestSemaphore. Names are needed for other processes to 
	// find the semaphore. The "Local\" means that it is only 
	// available to the  current user on XP or Terminal Services in versions of NT (including Win 2000). 
	// However, names in Windows 95, 98 and Me, and the NT family earlier than XP not running 
	// Terminal Services cannot contain a "\". 
	// On Windows NT 4.0 without Terminal Services, and earlier versions of Windows NT, the 
	// functions for creating or opening these objects fail if you specify a name containing the 
	// backslash character (\).
	// Windows 2000:  If Terminal Services is not running, the "Global\" and "Local\" prefixes 
	// are ignored. The remainder of the name can contain any character except the backslash character.
	
	// So, initially we'll try the Local\ prefix and if CreateSemaphore fails we'll drop the prefix
	// CreateSemaphore function creates or opens a named or unnamed semaphore object.
	// If Local\SimilePestSemaphore doesn't exist, create it with a count of zero (non-signalled, 
	// blocking). If Local\SimilePestSemaphore exists another relay.exe instance will have decreased 
	// the count to zero to block that process.
	g_hSemaphore = CreateSemaphore(
     	NULL, // Security attributes
     	0, // no free resources (Simile or Pest)
     	1, // max resources Simile or Pest
     	"Local\\SimilePestSemaphore"); // name for other process to find semaphore (Local\ = current user only)
     	
  	/*
  	If the function succeeds, the return value is a handle to the semaphore object. If the named 
  	semaphore object existed before the function call, the function returns a handle to the 
  	existing object and GetLastError returns ERROR_ALREADY_EXISTS.

	If the function fails, the return value is NULL. To get extended error information, call 
	GetLastError.
	*/   	
  	if (g_hSemaphore == NULL) {
   		if (GetLastError() == ERROR_INVALID_HANDLE ) {
	   		// drop the Local\ prefix to the name in case OS is Windows 4 (95 etc) or <= NT 4 
	   		// and so "\" causing failure
			g_hSemaphore = CreateSemaphore(
     			NULL, // Security attributes
     			0, // no free resources (Simile or Pest)
     			1, // max resources Simile or Pest
     			"SimilePestSemaphore"); // name for other process to find semaphore
    	} else {
   		    printf("CreateSemaphore error: %d\n", GetLastError());
   		 	exit(EXIT_FAILURE);
   		 	// DWORD GetLastError() == ERROR_INVALID_HANDLE
		 }
  	} else {  
   		//printf("Semaphore created or found: %d\n", GetLastError());
   		if (GetLastError() == ERROR_ALREADY_EXISTS) { // not actually an error
   			// printf("Semaphore found: %d\n", GetLastError());
  			// The semaphore already existed, release it, incrementing the count to allow
  			// the other process to continue.
	  		ReleaseSemaphore(g_hSemaphore, 1, NULL);      		
  			// Whenever a wait function releases a thread that was waiting for the semaphore, the count
  			// is decreased by one. So in this case the count will be zero and so blocking.
  			// This process can now block itself by waiting for the semaphore.
	   	}	   	
	}  
    WaitForSingleObject(g_hSemaphore,30000);
    puts("Bye");
#else
  int oldpid, error;
  char eof_string[80];

  if (argc > 1) {
    strcpy(fname, argv[1]);
  } else {
    strcpy(fname, "pestmsgs.txt");
  }    

  pip = fopen(fname, "r");
    if (pip == NULL) {
	  printf("Error opening file %s for reading", fname);
	  return 1;
  }
  fscanf(pip, "%d", &oldpid);
  fclose(pip);
  if (kill(oldpid,0)==-1) {
    puts("Sender process is already dead");
    return 1;
  }

  if (argc > 2 && !strcmp(argv[2], "done")) {
    if (oldpid) {
      kill(oldpid, SIGINT);
    }
    return 0;
  }
    
  pip = fopen(fname, "w");
  if (pip == NULL) {
	  puts("Error opening file for writing");
	  return 1;
  }
  fprintf(pip, "%d\n", (int)getpid());
  if (argc > 2) {
    fputs(argv[2], pip);
  } else {
    fputs("Go", pip);
  }    
  fclose(pip);

  if (oldpid) {
    kill(oldpid, SIGINT);
  }
  pause();
// waiting on console input makes it stop when calling process dies, but may
// do odd things to the stuff that displays data from the PEST pipeline
  // fgets(eof_string, 80, stdin);
#endif
}
