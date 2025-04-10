#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #undef WIN32_LEAN_AND_MEAN
#endif

// Definitions used in this code and the model code
#include <dllcalls.h>
// for talking to compiled models
#include <backend.h>
// class interface for c++ clients
#include <6d.h>

#ifdef _WIN32
    #define LOAD_DLL LoadLibrary
    #define UNLOAD_DLL FreeLibrary
    #define WHAT_WENT_WRONG GetErrorText
    #define FIND_FUNCTION GetProcAddress
/*
BOOL APIENTRY
DllEntryPoint(
    HINSTANCE hInst,		// Library instance handle.
    DWORD reason,		// Reason this function is being called.
    LPVOID reserved)		// Not used.
{
    return TRUE;
}
*/
char* GetErrorText() {
LPVOID lpMsgBuf;
FormatMessage( 
    FORMAT_MESSAGE_ALLOCATE_BUFFER | 
    FORMAT_MESSAGE_FROM_SYSTEM | 
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    GetLastError(),
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
    (LPTSTR) &lpMsgBuf,
    0,
    NULL 
);
return (char*)lpMsgBuf;
}

#else
    #include <signal.h>
    #include <dlfcn.h>

    #define LOAD_DLL safe_open
/* 'dummyunload' clause was used with macos because dlcompat didn't include
 * unload, but using -bundle instead of -dynamiclib to build the model seems to
 * make dlcompat, and dummyunload, unnecessary. Indeed it allows model
 * crosstalk on Intel macs, so is now never used.

#ifdef SIM_OPSYS_Darwin
#define UNLOAD_DLL dummyunload
int dummyunload(HINSTANCE unused) {
  return(1);
}
#else */
    #define UNLOAD_DLL !dlclose
// dlclose inverted cos it seems to return NULL when it works */
// #endif
    #define WHAT_WENT_WRONG (char*)dlerror
    #define FIND_FUNCTION dlsym

/* sig handler cos 64bit gcc code sigfpe's on 32bit machine */
jmp_buf s_env;

void exit_sighandler(int whatSig){
  if (whatSig == SIGFPE)
    longjmp(s_env, whatSig);
  else
    pthread_exit((void*)(intptr_t)-whatSig);
}

void* safe_open(char* fileName) {
  int error;

  signal(SIGFPE,exit_sighandler);
  error = setjmp(s_env);
  if (error) {
    return 0;
  } else {
    return dlopen(fileName, RTLD_NOW | RTLD_LOCAL);
  }
}
#endif

#include <portaudio.h>
// #include <sndfile.h> doing this stuff with our own code now
/*
 * Unix or Win64 (or Win32!) version: does not have min & max defined
 */

int s_min(int a, int b) {
  return a<b?a:b;
}
int s_max(int a, int b) {
  return a>b?a:b;
}

int nice_time() {
  timespec tim;
  clock_gettime(CLOCK_MONOTONIC, &tim);
  return 1000000*tim.tv_sec + tim.tv_nsec/1000;
}

char globMess[256];

// check for abort (and do non-intrusive gui action). Do not do this if the
// time point borders are happening frequently.

int stat_check(void* id) {
  return FALSE;
}


show_model_mess_type showModelMess;
void showModelMess(void* id, const char* content) {
  ((ExecutingModel*)id)->modelSpec->showMess(content);
}

/* utility procedures making no direct reference to model classes/instances */

graph_data_type* find_graph_by_index(int index, graph_data_type* use_gptr) {
  while (use_gptr && use_gptr->index != index) {
    use_gptr = use_gptr->next;
  }
  return(use_gptr);
}

double graphpoint(double xval, graph_data_type* graphdata, int index) {
	double interval, intersection;
	int spaces, lower;
	int *right, *left;
	graph_data_type *use_graph_pointer;
	
	use_graph_pointer = find_graph_by_index(index, graphdata);

	spaces = use_graph_pointer->xsize-1;
	/* Interval is distance from left of graph in point units */
	interval = spaces*(xval - use_graph_pointer->xlow)/
		(use_graph_pointer->xhigh - use_graph_pointer->xlow);
	switch (use_graph_pointer->range) {
	case 0: case 4: case 5: /* truncate to fit on graph */
	  interval = interval<0?0:(interval>spaces?spaces:interval);
	  break;
	case 2: case 6: /* wrap around graph range */
	  interval = spaces*(interval/spaces - floor(interval/spaces));
	  break;
	/* case 1: extrapolate end sections of graph */
	}
	/* right = use_graph_pointer->points;
	interval++;

	for (length=spaces;length;length--) {
		left = right;
		right++;
		if (--interval <= 1) break;
	}
	*/
	if (use_graph_pointer->range > 3) {
	  intersection = *(use_graph_pointer->points + 
			   s_max(0,s_min(spaces,(int)round(interval))));
	} else {
	  lower = s_max(0,s_min(spaces-1,(int)(interval)));
	  interval -= lower;
	  left = use_graph_pointer->points + lower;
	  right = use_graph_pointer->points + s_min(spaces,lower+1);
	  intersection = interval*(*right) + (1-interval)*(*left);
	}
	return use_graph_pointer->ylow + 
		(use_graph_pointer->yhigh - use_graph_pointer->ylow)*
		intersection/use_graph_pointer->yspan;

}

void release_graph_data(graph_data_type *graph_data_pointer) {
   free(graph_data_pointer->points);
}

#ifdef __OPENMP
#define PLUS_THREAD_NUM +omp_get_thread_num()
#else
#define PLUS_THREAD_NUM
#endif

#ifdef WIN32

#define RAND48_MULT_0   (0xe66d)
#define RAND48_MULT_1   (0xdeec)
#define RAND48_MULT_2   (0x0005)
#define RAND48_ADD      (0x000b)

unsigned int _rand48_mult[3] = {
		RAND48_MULT_0,
		RAND48_MULT_1,
		RAND48_MULT_2
};
unsigned short _rand48_add = RAND48_ADD;

void _dorand48(unsigned short xseed[3]) {
		unsigned long accu;
		unsigned short temp[2];

		accu = (unsigned long) _rand48_mult[0] * (unsigned long) xseed[0] +
		 (unsigned long) _rand48_add;
		temp[0] = (unsigned short) accu;        /* lower 16 bits */
		accu >>= sizeof(unsigned short) * 8;
		accu += (unsigned long) _rand48_mult[0] * (unsigned long) xseed[1] +
		 (unsigned long) _rand48_mult[1] * (unsigned long) xseed[0];
		temp[1] = (unsigned short) accu;        /* middle 16 bits */
		accu >>= sizeof(unsigned short) * 8;
		accu += _rand48_mult[0] * xseed[2] + _rand48_mult[1] * xseed[1] + _rand48_mult[2] * xseed[0];
		xseed[0] = temp[0];
		xseed[1] = temp[1];
		xseed[2] = (unsigned short) accu;
}

double erand48(unsigned short xseed[3]) {
		_dorand48(xseed);
		return ldexp((double) xseed[0], -48) +
			   ldexp((double) xseed[1], -32) +
			   ldexp((double) xseed[2], -16);
}

#endif
/*
void setup_randoms(unsigned int seed) {
   srand(seed);
}
double rand_fract() {
// some built-in random generators are not very accurate. In this
// case we may use several random numbers to get a random double.
    double fraction = 0, precise = 1;
    while (precise > 1e-16) {
	precise = precise/(RAND_MAX+1.0);
	fraction = fraction+precise*rand();
    }
    return fraction;
}
#else
*/
uint64_t seed_rand(int seed) {
  rand48seed shuttle;
  shuttle.use[0] = seed/65536;
  shuttle.use[1] = (unsigned short)fmod(seed,65536);
  shuttle.use[2] = 10000;
  return shuttle.set;
}

unsigned short init_rand_states[3];
BOOLEAN rand_inits_updated;
thread_local unsigned short rand_states[3];

void setup_randoms(unsigned int seed) {
  init_rand_states[0] = seed/65536;
  init_rand_states[1] = (unsigned short)fmod(seed,65536);
  init_rand_states[2] = 10000;
  setup_thread_randoms(seed, 0); // for tcl models
  rand_inits_updated = TRUE; // for c models
}

void setup_thread_randoms(unsigned int seed, int tNum) {
  rand_states[0] = init_rand_states[0];
  rand_states[1] = init_rand_states[1];
  rand_states[2] = init_rand_states[2] + tNum;
}

double rand_fract() {
  short unsigned int* xseed = rand_states;

  return erand48(rand_states);
}
/*
#endif
*/
double ame_rand(double lo, double hi) {
    return  lo + (hi-lo)*rand_fract();
}

double brand48_by_val(void* seed) {
  return erand48((unsigned short int*)seed);
}
/*
void playsound(const char* file) {
  char cmd[256];
#ifdef _WIN32
  // do something clever
  // // char shortBuffer[MAX_PATH];
  // char cmdBuff[MAX_PATH + 64];
  // GetShortPathName(file,shortBuffer,sizeof(shortBuffer));
  // sprintf(cmdBuff,"Open \"%s\" Type waveaudio Alias theWAV",shortBuffer);
  // sendCommand(cmdBuff);

  // sendCommand("Play theWAV Wait");

  snprintf(cmd, 256, "cmdwav.exe \"%s\" &", file);
  printf(cmd);
  WinExec(cmd, SW_HIDE);
#elif __APPLE__
  snprintf(cmd, 256, "afplay \"%s\" &", file);
  system(cmd);
#else
  snprintf(cmd, 256, "aplay -q \"%s\" &", file);
  system(cmd);
#endif
}

void play_at_vol(const char* file, double level) {

  char cmd[256];
#ifdef _WIN32
  // do something clever
  // // char shortBuffer[MAX_PATH];
  // char cmdBuff[MAX_PATH + 64];
  // GetShortPathName(file,shortBuffer,sizeof(shortBuffer));
  // sprintf(cmdBuff,"Open \"%s\" Type waveaudio Alias theWAV",shortBuffer);
  // sendCommand(cmdBuff);

  // sendCommand("Play theWAV Wait");

  snprintf(cmd, 256, "..\\..\\System\\bin\\sox.exe -v%lf \"%s\" -d -q", level, file);
  WinExec(cmd, SW_HIDE);
#elif __APPLE__
  snprintf(cmd, 256, "afplay -v %f \"%s\" &", level, file);
  system(cmd);
#else
  snprintf(cmd, 256, "AUDIODRIVER=alsa play -q -v %f \"%s\" &", level, file);
  system(cmd);
#endif
}
*/
int latestContext[32];

typedef struct sound_t {
  FILE *file;
  int evtTime;
  float volume;
  struct sound_t* next;
} sound;

typedef struct {
    uint16_t audio_format;
    uint16_t num_channels;
    uint32_t sample_rate;
    uint32_t byte_rate;
    uint16_t block_align;
    uint16_t bits_per_sample;
} WAV_FORMAT;

typedef struct wavListen_t {
  int id;
  PaStream* mic;
  char* file;
  WAV_FORMAT format;
  uint32_t data_size;
  uint32_t data_start;
  sound *playlist;
  struct wavListen_t* next;
} wavListen;
wavListen* audioChs = NULL;

// functions for reading and writing explicitly little-endian quantities
int16_t read_le16(uint8_t* buffer) {
    return (uint16_t)buffer[0] | ((uint16_t)buffer[1] << 8);
}

int32_t read_le32(uint8_t* buffer) {
    return (uint32_t)buffer[0] | ((uint32_t)buffer[1] << 8) | 
           ((uint32_t)buffer[2] << 16) | ((uint32_t)buffer[3] << 24);
}

static int pasimCallback(const void *inputBuffer, void *outputBuffer,
                          unsigned long framesPerBuffer,
                          const PaStreamCallbackTimeInfo* timeInfo,
                          PaStreamCallbackFlags statusFlags,
                          void *userData)
{
    wavListen *data = (wavListen*)userData;
    float *out = (float*)outputBuffer;
    int what_to_read = data->format.bits_per_sample/8;
    int bufSize = framesPerBuffer * data->format.num_channels;
    int num_read;
    int remaining;
    int result = paContinue;

    (void) inputBuffer;

    // if (!(data->playlist)) printf("Trying to play empty list!\n");
    // initialize buffer to zero

    uint8_t* in = new uint8_t[bufSize * what_to_read];
    //    printf("responding");
    memset(out, 0, bufSize * sizeof(float));

    sound** playlist = &(data->playlist); 
    while (*playlist) {
      int age = nice_time()-(*playlist)->evtTime;
      int samples = (uint64_t)data->format.sample_rate*age/1000000; // frames
      samples *= data->format.num_channels; // ensure channels time synced
      if (samples>bufSize) samples=bufSize;
      remaining = (data->data_start+data->data_size - ftell((*playlist)->file))
	/what_to_read;
      if (remaining>samples) remaining=samples;
      num_read = fread(in + what_to_read*(bufSize-samples), what_to_read,
		       remaining, (*playlist)->file);
      // Apply volume scaling and mixing
      for (int i = bufSize-samples; i < num_read+bufSize-samples; i++) {
	if (data->format.audio_format == 3) {	
	  out[i] += (*playlist)->volume* *(float*)(in + what_to_read*i);
	} else {
	  switch (what_to_read) {
	  case 2: {
	    out[i] += (*playlist)->volume*(float)read_le16(in + what_to_read*i)/32768;
	    break;
	  } case 3:
	  case 4:
	    out[i] += (*playlist)->volume*(float)read_le32(in + what_to_read*i)/2000000000;
	    break;
            // Add cases for other bit depths as needed
	  }
	}
      }
      if (num_read < samples) {
        fclose((*playlist)->file);
	delete *playlist;
	*playlist = (*playlist)->next; // hope it still there
	continue;
      } else {
	result = paContinue;
      }
      playlist = &((*playlist)->next);
    }
    delete [] in;
    return result;
}

FILE* read_wav_header(wavListen* wav) {
    FILE* file = fopen(wav->file, "rb");
    if (!file) {
      printf("Error opening file %s\n", wav->file);
        return 0;
    }

    char chunk_id[4];
    uint32_t chunk_size;
    char format[4];

    fread(chunk_id, sizeof(char), 4, file);
    fread(&chunk_size, sizeof(uint32_t), 1, file);
    fread(format, sizeof(char), 4, file);

    if (strncmp(chunk_id, "RIFF", 4) != 0 || strncmp(format, "WAVE", 4) != 0) {
        printf("Not a valid WAV file\n");
        fclose(file);
        return NULL;
    }

    while (1) {
        fread(chunk_id, sizeof(char), 4, file);
        fread(&chunk_size, sizeof(uint32_t), 1, file);

        if (strncmp(chunk_id, "fmt ", 4) == 0) {
            fread(&wav->format, sizeof(WAV_FORMAT), 1, file);
            fseek(file, chunk_size - sizeof(WAV_FORMAT), SEEK_CUR);
        } else if (strncmp(chunk_id, "data", 4) == 0) {
            wav->data_size = chunk_size;
	    wav->data_start = ftell(file);
            break;
        } else {
            fseek(file, chunk_size, SEEK_CUR);
        }
    }

    return file;
}

int play_sound_for(int graphId, double vol) {
    wavListen* soundCh = audioChs;
    while (soundCh) {
      if (soundCh->id == graphId) {
	sound* spin = new sound;
    /* Open the WAV file */
	spin->file = read_wav_header(soundCh);
	if (!spin->file) {
	  printf("Failed to read WAV file\n");
	  delete spin;
	  return 1;
	}
	spin->volume = vol;
	spin->next = soundCh->playlist;
	spin->evtTime = nice_time();
	soundCh->playlist = spin;
	// ...and stay in loop as one evt may have many sounds
      }
      soundCh = soundCh->next;
    }
    return 0;
}

int contextDepth = 0;

void report_events(int dimty, const int inds[], int evts,
		   const int ids[], const double sums[]) {
  int count;

  for (count=0;count<dimty;++count) {
    latestContext[count] = inds[count];
  }
  contextDepth = dimty;

  // now do commands associated with events
  for (count=0;count<evts;++count) {
    play_sound_for(ids[count], sums[count]);
  }
}

int retrieve_context(int** ctxPtr) {
  *ctxPtr = latestContext;
  return contextDepth;
}

void append_ints_to_null(int* dest, const int* src, int sep, int sep2) {
  while (*dest) { dest++; }
  if (sep) { *(dest++)=sep; }
  if (sep2) { *(dest++)=sep2; }
  do { *(dest++)= *src; } while (*src++);
}
/* This was used to throw exceptions when creating model instances -- these are
tricky for clients to handle, so instead we just report errors into a char**
class DllLossage {
 public:
  const char* action;
  char* fileName;
  char* wibble;
  
  DllLossage(const char* Action, char* FileName, char* Wibble) {
    action=Action;
    fileName=FileName;
    wibble=Wibble;
  }

  char* tell() {
    char* complaint;
    complaint = new char[256];
    sprintf(complaint, "couldn't %s file \"%s\": %s",
	action, fileName, wibble);
    return complaint;
  }
};
*/
  
BOOLEAN is_base_type(int dim) {
  return dim==VALUELESS||dim==REAL||dim==INTEGER||dim==FLAG||dim==UNSTABLE||
    dim==RECT_NBR||dim==HEX_NBR||dim<=ENUM_BASE;
}

int size_for_data_type(int dtype) { // only works if is_base_type
  switch (dtype) {
  case REAL:
    return sizeof(double);
  case FLAG:
    return sizeof(BOOLEAN);
  case UNSTABLE: // should not be used as does not appear in FP dims
  case VALUELESS:
    return 0;
  default: // INTEGER or enumerated type
    return sizeof(int);
  }
}

/* This takes a pointer into a dimension list, and returns the number
   of items rrepresented by that list, setting its second arg to point
   to the position in the dim list that specifies one data item in the
   bloc. */

int array_count(int* startDim, int** tgtDim) {
  /* sprintf(globMess, "doing array size, dim %d", *startDim);
     showMess(globMess); */
  if (*startDim>0)
    return (*startDim*array_count(startDim + 1, tgtDim));
  else {
    *tgtDim = startDim;
    return 1;
  }
}

// Creates space and initializes record counts to 0
char* init_space(int dimList[]) {
  int reps, count, *unit;
  sizeAndPtr* bloc;
  
  reps = array_count(dimList, &unit);
  if (*unit == OWNSIZED) {
    bloc = new sizeAndPtr[reps];
    for (count=0; count<reps; ++count)
      bloc[count].size = 0;
    return (char*)bloc;
  } else  // no more per-record levels
    return new char[reps*size_for_data_type(*unit)];
}

/* This and next few could be bundled into a class for the bloc data
void free_bloc_data(char* ptData, int* ptDims) {
  int reps, count, *subDims, saved;
  char* subData;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED or SPARSEARRAY
    if (*subDims==SPARSEARRAY) ++subDims; // advance to dim count slot
    saved = *subDims;
    for (count=0; count<reps; ++count) {
      // prepend size to remaining dims to create right size block
      *subDims = ((sizeAndPtr*)ptData)[count].size;
      free_bloc_data(((sizeAndPtr*)ptData)[count].ptr, subDims);
    }
    *subDims = saved; // restore original contents in case reusing dim list
  } else if (*subDims) // do not delete if empty
    delete ptData; // nothing else to do
}
*/
int free_bloc_level(char* ptData, int* ptDims, int offset) {
  // done by looking at call_for_each_val, which looked elsewhere
  int count;
  sizeAndPtr* convenience;
  int anyData;

  convenience = (sizeAndPtr*)ptData + offset;
  switch (ptDims[0]) {
  case OWNSIZED:
    for (count=0; count<convenience->size; ++count) {
      free_bloc_level(convenience->ptr, ptDims+1, count);
    }
    if (convenience->size) 
      delete [] convenience->ptr;
    return 1;
  case SPARSEARRAY:
    for (count=0; count<convenience->size; ++count) {
      free_bloc_level(convenience->ptr + sizeof(int)*ptDims[1]*(1+count),
		      // corrects for space taken up by indices
		      ptDims+2, count);
    }
    if (convenience->size) 
      delete [] convenience->ptr;
    return 1;
  default:
    int reps, *subDims;
    reps = array_count(ptDims, &subDims);
    if (!is_base_type(*subDims)) { // assume its OWNSIZED or SPARSEARRAY
      for (count=0; count<reps; ++count)
	anyData = free_bloc_level(ptData, subDims, reps*offset+count);
// this version was same but looped unnecessarily over numerical arrays
//    if (ptDims[0]>0) { // an array dimension
//      for (count=0; count<ptDims[0]; ++count)
//	anyData = free_bloc_level(ptData, ptDims+1, ptDims[0]*offset+count);
      return anyData;
    } else // a base data type (0 = dataless submodel)
      return *subDims; 
  }
}

// free_bloc_data frees all memory used in a structure
void free_bloc_data(char* ptData, int* ptDims) {
  if (free_bloc_level(ptData, ptDims, 0))
    delete [] ptData;
}

// copy_bloc_data duplicates a structure, allocating the required memory
// (doesn't work on SPARSEARRAY)
char* copy_bloc_data(char* source, int* ptDims) {
  int reps, count, *subDims;
  char* newData;
  
  if (!source)
    return NULL;
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED
    newData = new char[reps*sizeof(sizeAndPtr)];
    for (count=0; count<reps; ++count) {
      //substitute OWNSIZED to create right size block then put back
      *subDims = ((sizeAndPtr*)source)[count].size;
      ((sizeAndPtr*)newData)[count].size = *subDims;
      ((sizeAndPtr*)newData)[count].ptr = 
	copy_bloc_data(((sizeAndPtr*)source)[count].ptr, subDims);
    }
    *subDims = OWNSIZED;
  } else {
    count = reps*size_for_data_type(*subDims);
    newData = new char[count];
    memcpy(newData, source, count);
  }
  return newData;
}

// sum_bloc_data used for sound loudness
double sum_bloc_data(char* source, int* ptDims) {
  int reps, count, *subDims;
  double result = 0;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED
    for (count=0; count<reps; ++count) {
      //substitute OWNSIZED to create right size block then put back
      *subDims = ((sizeAndPtr*)source)[count].size;
      result += sum_bloc_data(((sizeAndPtr*)source)[count].ptr, subDims);
    }
    *subDims = OWNSIZED;
  } else {
    for (count=0;count<reps;++count) {
      switch (*subDims) {
      case REAL:
	result += ((double*)source)[count];
	break;
      case FLAG:
	result += ((unsigned char*)source)[count];
	break;
      default: // INTEGER or enumerated type
	result += ((int*)source)[count];
	break;
      }
    }
  }
  return result;
}

char* interpolate_bloc_data(char* loSource, char* hiSource, int* ptDims,
			    double interFract) {
  int reps, count, *subDims;
  char* newData;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED
    newData = new char[reps*sizeof(sizeAndPtr)];
    for (count=0; count<reps; ++count) {
      //substitute OWNSIZED to create right size block then put back
      *subDims = ((sizeAndPtr*)loSource)[count].size;
      ((sizeAndPtr*)newData)[count].size = *subDims;
      ((sizeAndPtr*)newData)[count].ptr = 
	interpolate_bloc_data(((sizeAndPtr*)loSource)[count].ptr, 
			      ((sizeAndPtr*)hiSource)[count].ptr, 
			      subDims, interFract);
    }
    *subDims = OWNSIZED;
  } else {
    count = reps*size_for_data_type(*subDims);
    newData = new char[count];
    if (*subDims == REAL)
      for (count=0; count<reps; ++count)
	*((double*)newData+count) = *((double*)hiSource+count)*interFract
	  + *((double*)loSource+count)*(1-interFract);
    else
      for (count=0; count<reps; ++count)
	*((int*)newData+count) = (int)round(*((int*)hiSource+count)*interFract
				    + *((int*)loSource+count)*(1-interFract));
  }
  return newData;
}

// this sets all the actual values in the structure to 0 without changing
// the size of anything -- used for cancelling events
void zero_bloc_data(char* dest, int* ptDims) {
  int reps, count, *subDims;
  char* newData;
  
  reps = array_count(ptDims, &subDims);
  if (!is_base_type(*subDims)) { // assume its OWNSIZED
    for (count=0; count<reps; ++count) {
      //substitute OWNSIZED to create right size block then put back
      *subDims = ((sizeAndPtr*)dest)[count].size;
      if (*subDims) // no values yet loaded
	zero_bloc_data(((sizeAndPtr*)dest)[count].ptr, subDims);
    }
    *subDims = OWNSIZED;
  } else {
    if (*subDims == REAL)
      for (count=0; count<reps; ++count)
	*((double*)dest+count) = 0;
    else
      for (count=0; count<reps; ++count)
	*((int*)dest+count) = 0;
  }
}

// locate_elt returns a pointer to one model value in the structure,
// given its indices. If there are fewer than the full number of
// indices, returns a pointer to the structure containing the values
// whose indices start with the given ones. (doesn't work on
// SPARSEARRAY and indeed cannot, because this structure may not
// exist.)
void* locate_elt(char* startPtr, int off, int* dimPtr, int* indxs) {
  sizeAndPtr* newRecord;

  // sprintf(globMess, "locate_elt array %lx off %d d0 %d d1 %d d2 %d indx %d", 
  // (long)startPtr, off, dimPtr[0], dimPtr[1], dimPtr[2], *indxs);
  // showMess(globMess);
  if (*dimPtr==OWNSIZED) {
    newRecord = (sizeAndPtr*)startPtr + off;
    if  (*indxs) // more indices, use to get value from a record submodel
      // bounds check, added in case getting variable params before setting
      if (indxs[0]>newRecord->size)
	return NULL;
      else
	return locate_elt(newRecord->ptr, (*indxs)-1, dimPtr+1, indxs+1);
    else // no more indices, we are looking for recordSet struct
      return newRecord;
  } else if (is_base_type(*dimPtr))
    return startPtr + off*size_for_data_type(*dimPtr);
  else
    return locate_elt(startPtr, *dimPtr*off+(*indxs)-1, dimPtr+1, indxs+1);
}

//! listable class for data to be loaded at a time point 

//! This contains
//! data in a char*, rather than a nodeValue structure, because the
//! dimSpecs are the same for all the time points of a parameter. All
//! members are private because all its operations are done by methods
//! of the FileParamData class.

class listTimePoint {
  friend class VarParamData;

  double when;
  char* dataPtr;
  listTimePoint *last, *next;

  listTimePoint(double time, int* dimSpecs) {
    when = time;
    dataPtr = init_space(dimSpecs);
    last = next = NULL;
  }      

  // delete contents when deleting parent class cos it has access to dims
  ~listTimePoint() {
  }

  listTimePoint* find_last_pt(double time) {
    if (next) {
      // printf("seeking after %lf for %lf\n", when, time);
      if (next->when<=time) {
	return next->find_last_pt(time);
      }
    }
    return this;
  }
};

// class for keeping track of arrays associated with parameters

FileParamData::FileParamData(ExecutingModel* instToUse, HCOMP newNodeId,
			     int* fullDims) {
  int sparePath[32];

  myModelExec = instToUse;
  nodeId = newNodeId;
  translate_dims(fullDims, sparePath, dataPtr.dimSpecs, 
		 myModelExec->modelSpec->nodedata[nodeId].datatype, -1);
  dataPtr.contents = init_space(dataPtr.dimSpecs);
  active = 1; // will never change except if event
  //    dataPtr.contents = new char[sparePath[0]];
  // now insert it into the list (at beginning)
  next = myModelExec->param_array_base;
  myModelExec->param_array_base = this;
}      

FileParamData::~FileParamData() {
  int size, count;
  char* innerSp;

  free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
  // now remove it from the list
  FileParamData** current = &(myModelExec->param_array_base);
  while (*current != this) current = &(*current)->next; // better be in there
  *current = next;
}

// These last two are actually called by the model code to get data

int FileParamData::extract_elt(void* tgt, int* indxs) {
  // do not do it if this is a variable parameter and we are initializing --
    // array not yet set so let model keep default value...in fact, save it in
    // the array for later
  void *insertionPt; 
  node_data_line* nodeLine;
  int dataSize;
  if (!dataPtr.contents or active>3) return 0; // no valid param data
  if (active==3 || active==1) --active; // mark it used
    insertionPt = locate_elt(dataPtr.contents, 0, dataPtr.dimSpecs, indxs);
    if (!insertionPt) return -1; // record pointers not yet made
    nodeLine = myModelExec->modelSpec->nodedata + nodeId;

    // this is not good for hierarchy -- make sure contents NULL when updaing
    // if (myModelExec->resetting<1 && nodeLine->eval == INPUT)
    //   if (!((VarParamData*)this)->curTimePoint) {
// 	free_bloc_data(dataPtr.contents, dataPtr.dimSpecs);
// 	dataPtr.contents = NULL;
 // 	return 0; // emptied data as no time point reached
    //   }
    
    if (myModelExec->resetting<1 && nodeLine->eval == INPUT)
      if (!((VarParamData*)this)->curTimePoint &&
	  (!myModelExec->keepingSliders || myModelExec->resetting==-2 ||
	   ((VarParamData*)this)->timePoints))
 	return 1; // good data already there?
    // back copy now done in blocks afterwards to make record spaces, but
    // avoid forward copying first
    // memcpy(insertionPt, tgt, size_for_type());
    dataSize = size_for_data_type(nodeLine->datatype);
    // printf("Copying %lf\n", *(double*)insertionPt);
    memcpy(tgt, insertionPt, dataSize);
    return 1; // parameter loaded successfully
  }

  int FileParamData::extract_record_count(void* tgt, int ic, int* indxs) {
    sizeAndPtr* insertionPt;
    int count, indxsWith0[32];

    // need zero at appropriate point in indxs to stop at record pointer
    for (count=0; count<ic; ++count) {
      indxsWith0[count] = indxs[count];
    }
    indxsWith0[count] = 0;
    insertionPt = (sizeAndPtr*)locate_elt(dataPtr.contents, 0, 
					  dataPtr.dimSpecs, indxsWith0);
    *(int*)tgt = insertionPt->size;
    return 1; //always succeeds?
  }
// end of FileParamData class

// start of VarParamData class
VarParamData::VarParamData(ExecutingModel* instToUse, HCOMP newNodeNum,
			   int* fullDims) 
  : FileParamData(instToUse, newNodeNum, fullDims) {
  timePoints = NULL;
  finalTimePoint = NULL;
  curTimePoint = NULL;
  fillMethod = USE_LAST;
  seriesIdxUnits = 1.0;
  int forClass = myModelExec->modelSpec->nodedata[nodeId].compclass;
  amEvent = (forClass == EVENT || forClass == SQUIRT);
  
  nextVP = myModelExec->varParamArrayBase;
  myModelExec->varParamArrayBase = this;
}

VarParamData::~VarParamData() {
  ClearTimePtElements();
  // now remove it from the list
  VarParamData** current = &(myModelExec->varParamArrayBase);
  while (*current != this) current = &(*current)->nextVP; // better be in there
  *current = nextVP;
}

BOOLEAN VarParamData::CopySeries(VarParamData* source) {
  timePoints = source->timePoints;
  finalTimePoint = source->finalTimePoint;
  wrapAroundPoint = source->wrapAroundPoint;
  seriesIdxUnits = source->seriesIdxUnits;
  return timePoints!=NULL;
}

BOOLEAN VarParamData::update_from_points(double nowInDays, double *next,
					nodeValues* destPtr, BOOLEAN fallback) {
  listTimePoint *loBound, *hiBound;
  int hiWraps = 0, newWraps = wraps;
  double now, later, interFract;
  node_data_line* ndRef = myModelExec->modelSpec->nodedata + nodeId;
  now = nowInDays/seriesIdxUnits;
  loBound = curTimePoint;
  if (loBound)
    hiBound = roll_forward(loBound, &hiWraps);
  else
    hiBound = timePoints; // first point
  //  if (next>=nowInDays) { move either way irrespective of step direction
    while (hiBound && now>=hiBound->when+hiWraps*wrapAroundPoint) {
      loBound = hiBound;
      newWraps = hiWraps;
      hiBound = roll_forward(loBound, &hiWraps);
    }
    //  } else {
    //    newWraps = wraps;
    while (loBound && now<loBound->when+newWraps*wrapAroundPoint) {
      hiBound = loBound;
      hiWraps = newWraps;
      loBound = loBound->last;
      if (wrapAroundPoint>0.0 && !loBound) {
	--newWraps;
	loBound = finalTimePoint;
      }
    }
    //  }
  if (fillMethod!=USE_LAST &&
      loBound && loBound->dataPtr && hiBound && hiBound->dataPtr) {
    interFract = (now-newWraps*wrapAroundPoint-loBound->when)/
      (hiBound->when+(hiWraps-newWraps)*wrapAroundPoint-loBound->when);
    //            sprintf(globMess, "lotime %lf hitime %lf Fract %lf", 
    //		    loBound->when, hiBound->when, interFract);
    //      showMess(globMess);
    if (fillMethod==INTERPOLATE && ndRef->datatype != FLAG) {
      if (!fallback) {
	curTimePoint = loBound; // cos that's what wraps refers to
	wraps = newWraps;
      }
      free_bloc_data(destPtr->contents, destPtr->dimSpecs);
      destPtr->contents = interpolate_bloc_data(loBound->dataPtr, 
					       hiBound->dataPtr, 
					       destPtr->dimSpecs, 
					       interFract);
      return true; // nothing has changed it yet
    }
    if (interFract>0.5) { // fillMethod is USE_CLOSEST
      loBound = hiBound;
      newWraps = hiWraps;
    }
  }
  if (amEvent) {
    if (!active) active=5; // back to standby
    if (active==4 || active==2) { // ready to write or clear
      if (--active == 1) // don't trust lazy evaluation
	zero_bloc_data(destPtr->contents, destPtr->dimSpecs);
    }
    if (hiBound) { // return time at which event will next happen
      later = (hiBound->when+hiWraps*wrapAroundPoint)*seriesIdxUnits;
      if (later<*next)
	*next = later;
    }
  }
  if (loBound && (fallback || loBound!=curTimePoint || newWraps!=wraps)) {
    // cannot tell if found next pt in fallback case,
    // need to re-clear anyway if no override to let default update it
    if (!fallback) {
      curTimePoint = loBound;
      wraps = newWraps;
    }
//     if (ndRef->compclass != EVENT && ndRef->compclass != SQUIRT ||
// 	now == loBound->when+newWraps*wrapAroundPoint) {
      // do not add data if discrete and we have missed the exact time
      // eg. by resetting to a later time
      // Actually do, it's better than not doing it!!
      free_bloc_data(destPtr->contents, destPtr->dimSpecs);
      destPtr->contents = copy_bloc_data(loBound->dataPtr, destPtr->dimSpecs);
      active=3;
//     }
  }
  if ((!loBound || !loBound->dataPtr) && !amEvent) {
    // these lines would mean slider actions are overwritten if no time
    // series data is active
    //free_bloc_data(destPtr->contents, destPtr->dimSpecs);
    //destPtr->contents = NULL;
    return false;
  }

  if (amEvent && active==3) {
    myModelExec->seriesEvtSign = ndRef->graph;
    // Now play sound for event if there is one
    double volume;
    play_sound_for(ndRef->graph,
		   sum_bloc_data(destPtr->contents, destPtr->dimSpecs));
  }

  return true;
}

listTimePoint* VarParamData::create_time_point(double time) {
  listTimePoint *lastTimePt, *thisTimePt, *nextTimePt;
  if (timePoints && timePoints->when<=time) {
    lastTimePt = timePoints->find_last_pt(time);
    if (lastTimePt->when==time) {
      return NULL; // a point already exists at this time
    } else { // lastTimePt is earlier than new one
      nextTimePt = lastTimePt->next;
      thisTimePt = new listTimePoint(time, dataPtr.dimSpecs);
      thisTimePt->next = lastTimePt->next;
      lastTimePt->next = thisTimePt;
      thisTimePt->last = lastTimePt;
      if (nextTimePt) {
	nextTimePt->last = thisTimePt;
      } else {
	finalTimePoint  = thisTimePt;
      }
    }
  } else {
    thisTimePt = new listTimePoint(time, dataPtr.dimSpecs);
    thisTimePt->next = timePoints;
    if (timePoints) {
      timePoints->last = thisTimePt;
    } else {
      finalTimePoint  = thisTimePt;
    }
    thisTimePt->last = NULL;
    timePoints = thisTimePt;
  }
  return thisTimePt; // new point has been created
}

// only used for saving byte array, so obsolescent
char* VarParamData::FindNextTimePtSpace(double* last_time) {
  listTimePoint* seek = timePoints->find_last_pt(*last_time);

  if (seek->when <= *last_time)
    seek = seek->next;
  if (seek) {
    *last_time = seek->when;
    return seek->dataPtr;
  }
  return NULL;
  /* old version duplicated effort
  while (seek) {
    if (seek->when>*last_time) {
      *last_time = seek->when;
      break;
    }
    seek = seek->next;
  }
  if (seek)
    return seek->dataPtr;
  else
    return NULL;
  */
}

  char** VarParamData::GetTimePtDataSpace (double time) {
    listTimePoint* timePt;

    if (timePoints) {
      if ((timePt = timePoints->find_last_pt(time))->when==time)
	return &(timePt->dataPtr);
    }
    return NULL;
  }

  listTimePoint* VarParamData::roll_forward(listTimePoint *bound, int *newWraps) {
    bound = bound->next;
    if (!bound && wrapAroundPoint>0.0) {
      ++*newWraps;
      bound = timePoints;
    }
    return bound;
  }

void VarParamData::ClearTimePtElements() {
  if (inheritSeries) {
    timePoints = NULL;
    inheritSeries = FALSE;
  } else
    while (timePoints) {
      curTimePoint = timePoints;
      timePoints = curTimePoint->next;
      free_bloc_data(curTimePoint->dataPtr, dataPtr.dimSpecs);
      delete(curTimePoint);
    }
  finalTimePoint = NULL;
  curTimePoint = NULL;
}

void VarParamData::InitTimeSeries(BOOLEAN cancelSliders) {
  //  if (!this) return // WTFN? Cos it makes release version crash!
  curTimePoint = NULL;
  wraps = 0;
  active = 2; // this will cause any current event data to be zeroed

    ExecutingModel* host = myModelExec->parent;
    while (host && !inheritSeries) {
      VarParamData* srcWotsit = host->varParamArrayBase;
      while (srcWotsit) {
	if (srcWotsit->nodeId == nodeId) {
	  if (amEvent)
	    CopySeries(srcWotsit);
	  if (srcWotsit->timePoints) inheritSeries = TRUE;
	  break;
	}
	srcWotsit = srcWotsit->nextVP;
      }
      host = host->parent;
    }
    if (!amEvent && dataPtr.contents && \
	(timePoints || inheritSeries || cancelSliders)) {
    free_bloc_data(dataPtr.contents,dataPtr.dimSpecs);
    dataPtr.contents = NULL;
  }
  if (nextVP) // does not crash
    nextVP->InitTimeSeries(cancelSliders);
}
/*
double VarParamData::UpdateTimeSeries(double now, double horizon) {
  double next_evt;

  next_evt = update_from_points(now, horizon);

  if (nextVP)  {
    next_evt = nextVP->UpdateTimeSeries(now, next_evt);  
  }
  return next_evt; 
}    
*/
int step_list(int **dim_list) {
  return *(*dim_list)++;
}

// FINDABLE EXPORT getpointer_type burrow_to;
// FINDABLE EXPORT void* burrow_to(void* level, int** id_meta, int** dim_list) {
// This has been messed with in a manner similar to do_evalmodel above
void* get_ptr(void* level, int** id_meta, int** dim_list) {
  int* lastDim;

  while (**id_meta>0) { /* 0 means end of tree, -1 means vm level */
    lastDim = *dim_list;
    // printf("gonna g_p id %d,%d... dims %d,%d\n",
    //     **id_meta, *(*id_meta+1), **dim_list, *(*dim_list+1));
    level = ((submodeltype*)level)->get_pointer(step_list(id_meta),dim_list);
    // note that if it is a vm submodel, level is set to a metapointer
    // so we had better not recurse
    if ((*lastDim == REQ_COUNT) && (*dim_list != lastDim)) { // moved on
      break;
    }
  }
  return(level);
};

InstanceOfModel* step_ptr(InstanceOfModel* ptr) {
  int next_handle[] = {1,0}, dimDum[] = {0}, *idler1, *idler2;

  idler1 = next_handle;
  idler2 = dimDum; // dummy dim needed to survive member count retreival test
  return *(InstanceOfModel**)(get_ptr(ptr, &idler1, &idler2));
}

int count_members(InstanceOfModel* ptr) {
  // do not recurse, there may be too many of them
  int count = 0;
  while(ptr) {
    ptr = step_ptr(ptr);
    ++count;
  }
  return count;
}

// put indices of current instance onto data blk
void fill_indices(InstanceOfModel* smHandle, int indxCount, 
		  char** insertionPt) {
  int idHandle[] = {2,0}, idIdx[1], *idler1, *idler2;

  for (idIdx[0] = 0; idIdx[0]<indxCount; ++idIdx[0]) {
    idler1 = idHandle;
    idler2 = idIdx;
    //    memcpy(*insertionPt, get_ptr(smHandle, &idler1, &idler2),
    //	   sizeof(int));
    *((int*)(*insertionPt)) = *((int*)(get_ptr(smHandle, &idler1, &idler2)))+1;
    *insertionPt += sizeof(int);
  }
}

int skip_vm_bounds(int** modelDimList) {
  int count = 0;
  while (*(++(*modelDimList)) != END_VM)
    ++count;
  return count;
}

// this is used by the ExecutingModel class to recurse through submodels
// to get values. Not a class member because it works at a lower level

// dims starts off as the block sizes at each level of data nesting,
// but ass we recurse through this it gets replaced by the array of
// counts that are being incremented in the instances of this
// procedure from which the current one is being called
void fill_raw_values(InstanceOfModel* smHandle, int tree[],
		     int* use_dims, int dims[], int* dim_place,
		     char** insertionPt) {
  int count, dimty = 0; // value for RECORDS
  void* model_val_ptr;
  char *newBlk;
  
  // printf("fill_raw: case %d %d, dims %d %d %d %d, off %d fill %p\n",
// 	 use_dims[0], use_dims[1], dims[0], dims[1], dims[2], dims[3], 
// 	 dim_place - dims, *insertionPt);
  
  switch (*use_dims) {
  case START_VM:
    dimty = skip_vm_bounds(&use_dims); // and drop through, keeping this value
//  case RECORDS: // dimty will end up as 0
    --dimty; // and drop through
  case MEMBERS: // dimty will end up as 1
    ++dimty; 
    /* Count the number of instances in the submodel, multiply by size
       needed for each instance and its indices, alloc this and
       recurse to fill it up, and place count and pointer to new space
       in insertionPt. */
    smHandle = *(InstanceOfModel**)get_ptr(smHandle, &tree, &dims);
    count = count_members(smHandle);
    ((sizeAndPtr*)(*insertionPt))->size = count;
    if (count) // do not waste energy creating zero-length blox
      newBlk = new char[count*(dimty*sizeof(int) + dim_place[1])];
    ((sizeAndPtr*)(*insertionPt))->ptr = newBlk;
    *insertionPt += sizeof(sizeAndPtr);
    while (*tree++ != -1) {} // make relevant to current submodel
    while (smHandle) {
      fill_indices(smHandle, dimty, &newBlk);
      fill_raw_values(smHandle, tree,
		      use_dims+1, dim_place+1, dim_place+1, &newBlk);
      smHandle = step_ptr(smHandle);
    }
    break;
  case 0:
    model_val_ptr = get_ptr(smHandle, &tree, &dims);
    memcpy(*insertionPt, model_val_ptr, *dim_place);
    *insertionPt += *dim_place;
    break;
  case RECORDS:
    dimty = *dim_place; // save block size in case we need it again
    *dim_place = REQ_COUNT; // tells get_ptr to get made count
    int *tree_copy, *dims_copy;
    tree_copy = tree;
    dims_copy = dims; 
    count = *(int*)get_ptr(smHandle, &tree_copy, &dims_copy);
    ((sizeAndPtr*)(*insertionPt))->size = count;
    newBlk = new char[count*dim_place[1]];
    ((sizeAndPtr*)(*insertionPt))->ptr = newBlk;
    *insertionPt += sizeof(sizeAndPtr);
    *dim_place = dimty;
    // now overwrite dim to look like normal array, recurse, and put back
    if (count) { // 0 would not be interpreted as an array dim
      *use_dims=count;
      fill_raw_values(smHandle, tree, use_dims, dims, dim_place, &newBlk);
      *use_dims=RECORDS;
    }
    break;
  default: /* value is a dimension of the array we are accessing */
    count = *dim_place; // save block size in case we need it again
    for (*dim_place = 0; *use_dims > *dim_place; ++*dim_place) {
      fill_raw_values(smHandle, tree, use_dims+1, dims, dim_place+1, 
		      insertionPt);
    }
    *dim_place = count;
    break;
  }
}

class ModelServer;

// Implementation of class ExecutingModel
ExecutingModel::ExecutingModel(ModelServer* newModelSpec, void* yourRef) {
    modelSpec = newModelSpec;
    parent = NULL;
    children = NULL;
    clientRef = yourRef;
    loadedInst = modelSpec->createmodel(this);
    //sprintf(globMess, "This is XM %lx of M %lx being created with IOM %lx", 
//	    (long)this, (long)modelSpec, (long)loadedInst);
    //showMess(globMess);
    param_array_base = NULL;
    varParamArrayBase = NULL;
}

ExecutingModel::~ExecutingModel() {
  xmList* sibling;
  
  while (children) { // assignment intentional
    delete children->now;
    // deletion of child instance will point children to next child
  }
  if (parent) { // snip this out of parent's child list
    xmList** siblingPtr = &(parent->children);
    while (sibling = *siblingPtr) { // assignment intentional
      if (sibling->now == this) break;
      siblingPtr = &(sibling->next);
    }
    if (sibling) {
      *siblingPtr = sibling->next;
      delete sibling;
    } else
      printf("Could not find %p in children of %p\n", this, parent);
  }
  while (param_array_base) delete param_array_base;
  // Above line is correct -- deleting a param item causes it to be snipped out
  // of the list, so list head is NULL when all are snipped. Var params have
  // their own list but are also included in all-param list...
  // delete loadedInst;
}

ExecutingModel* ExecutingModel::AddGroupMember(void* usersRef) {
  xmList* oldChild = children;

  children = new xmList;
  children->next = oldChild;

  children->now = new ExecutingModel(modelSpec, usersRef);
  children->now->parent = this;
  for (int ph=1; ph<=modelSpec->phases;++ph)
    children->now->SetStep(ph, steps[ph]);
  VarParamData* oldVP = varParamArrayBase;
  while (oldVP) {
    children->now->UseArrayForParams(oldVP->nodeId);
    oldVP = oldVP->nextVP;
  }
  return children->now;
}

void* reset_grp_instance(void* clientData) {
  void* retVal;
  xmList* args = (xmList*)clientData;
  ExecutingModel *payload = args->now;
  ExecutingModel *parmSrc = payload->parent;
  pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);
  if (parmSrc)
    payload->set_completion(0); // get no data from vms
  else 
    parmSrc = payload; // doing top level instance, parms from self
  memcpy(rand_states, args->randKeeper, 3*sizeof(unsigned short));
  retVal = payload->ResetInstance(parmSrc->initTime,
				  parmSrc->howInt,
				  parmSrc->topPhase);
  memcpy(args->randKeeper, rand_states, 3*sizeof(unsigned short));
  // If this is the top level we will be doing a timed wait so we need to send
  // a signal
  if (payload->parent)
    payload->set_completion(1); // get data from vms
  else 
    payload->signal_complete(args); // does the following
  return retVal;
}

void* execute_grp_instance(void* clientData) {
  void* retVal;
  xmList* args = (xmList*)clientData;
  ExecutingModel *payload = args->now;
  ExecutingModel *parmSrc = payload->parent;
  pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);
  if (parmSrc)
    payload->set_completion(0); // get no data from vms
  else 
    parmSrc = payload; // doing top level instance, parms from self
  memcpy(rand_states, args->randKeeper, 3*sizeof(unsigned short));
  retVal = payload->ExecuteInstance(parmSrc->howInt,
				    parmSrc->initTime,
				    parmSrc->finalTime,
				    parmSrc->errLim,
				    parmSrc->pauseRange,
				    parmSrc->pauseEvt);
  memcpy(args->randKeeper, rand_states, 3*sizeof(unsigned short));
  // If this is the top level we will be doing a timed wait so we need to send
  // a signal
  if (payload->parent)
    payload->set_completion(1); // get data from vms
  else 
    payload->signal_complete(args); // does the following
  return retVal;
}

void ExecutingModel::LaunchThreads(void* thread_action(void*)) {
  xmList* aChild = children;
  while (aChild) {
    pthread_create(&aChild->thredd, NULL, thread_action, aChild);
    aChild = aChild->next;
  }
}

pthread_t supervisorId;
void ExecutingModel::WrapUpThreads(excpData* userDefStop) {
  void *clientResult = NULL;
  // struct timespec ts;

  xmList* aChild = children;
  while (aChild) {
    /* clang does not have pt_tj_np so dream up some other way of coping with 
    an endless child job...eg, create a separate thread to try to join them
    that can be killed after a certain time

    if (pthread_equal(pthread_self(), supervisorId)) {
      // am supervisor so keep checking gui while awaiting others
      clock_gettime(CLOCK_REALTIME, &ts);
      while (aChild->thredd) {
	ts.tv_nsec += 40000000; // 40ms
	if (ts.tv_nsec >= 1000000000) {
	  ts.tv_nsec -= 1000000000;
	  ts.tv_sec += 1;
	}
	if (!pthread_timedjoin_np(aChild->thredd, &clientResult, &ts))
	  aChild->thredd = 0; // success, go to next one
	else
	  if (do_gui_check(0,0)) break; // else keep waiting for this one
      }
      if (aChild->thredd) {
	// left loop at user req, kill all remaining threads
	while (aChild) {
	  pthread_kill(aChild->thredd, SIGTERM);
	  aChild = aChild->next;
	}
	userDefStop->excpNo = -101;
	break;
      }
    } else
    */
    aChild->now->paused = paused;
    pthread_join(aChild->thredd, &clientResult);
    if (clientResult) {
      *userDefStop = *(excpData*)clientResult; // copy it up?
      userDefStop->completed = 0; // parent will not be
    }
    aChild = aChild->next;
  }
}

excpData* ExecutingModel::ResetInstance(double init_time, int how_int, 
					int top_phase) {
  int tweak_phase;
  excpData* retVal = NULL;
  void *clientResult;

  if (rand_inits_updated) {
    setup_thread_randoms(0, 0);
  }
  if (top_phase<=0 && varParamArrayBase) {
    varParamArrayBase->InitTimeSeries(how_int!=-1 || top_phase==-2);
  }

  // kick off threads to reset child instances
  initTime = init_time;
  howInt = how_int;
  topPhase = top_phase;
  xmList* aChild = children;
  while (aChild) {
    pthread_create(&aChild->thredd, NULL, reset_grp_instance, aChild);
    aChild = aChild->next;
  }

  SetdT(0, 9); // start prediction cycle
  for (tweak_phase=1; tweak_phase <= 7; tweak_phase++) {
    SetdT( tweak_phase,steps[tweak_phase]);
  }
  resetting = top_phase;
  keepingSliders = (how_int == -1);
  if (top_phase<=0) {
    last_op = 0;
    last_exit = last_update = last_check = 0; // reset timekeeping
    for (tweak_phase=1; tweak_phase <= 7; tweak_phase++) {
      lts[tweak_phase]=init_time;
      took[tweak_phase]=0;
      SetdT( -tweak_phase,init_time);
    }
    thisTsPosn = init_time;
    seriesEvtSign = 0;
    nextSeriesEvt = UpdateTimeSeries(init_time, INFINITY);
    // hope we are going forwards
  } else {
    set_dts(top_phase, init_time);
  }
  loadedInst->event_predict = init_time+steps[1]; // just initialize  
  freq = steps[modelSpec->phases];

  (loadedInst->userStop).targetId = 0;
  (loadedInst->userStop).excpSource = this;
  if (loadedInst->do_evalmodel(top_phase)) {
    //printf("Back in the shank\n");
    retVal = &(loadedInst->userStop);
    retVal->excpSource = this;
  }
  // reset successful: now do back copy if needed -- not now because letting
  // model default persist
//   else if (top_phase<1 && varParamArrayBase) {
//     varParamArrayBase->back_copy_vars(); // does all
//   }
  aChild = children;
  while (aChild) {
    pthread_join(aChild->thredd, &clientResult);
    if (clientResult)
      retVal = (excpData*)clientResult;
    aChild = aChild->next;
  }
  return retVal;
}

void ExecutingModel::RepeatReset(double init_time) {
  // varParamArrayBase->InitTimeSeries(); function no longer used
}

excpData* ExecutingModel::ExecuteInstance(int how_int, double start, 
					  double end, double errlim,
					  BOOLEAN pause_out_of_range,
					  BOOLEAN pause_on_events) {
  double xtime, aim_for, recover, evtError, newFreq, minFreq;
  int big_phase, wee_phase, a_phase, keeper, z;
  BOOLEAN made_step, first_pass;
  // printf("xm %d %lf-%lf at %lf\n", how_int, start, end, errlim);
  // showMess(globMess);
  // temporary arrangement until we move this function into the instance

  initTime = start;
  howInt = how_int;
  finalTime = end;
  errLim = errlim;
  pauseRange = pause_out_of_range;
  pauseEvt = pause_on_events;
  paused = 0;
  
  if (rand_inits_updated) {
    setup_thread_randoms(0, 0);
  }
  LaunchThreads(execute_grp_instance);
  
  excpData* userDefStop = &(loadedInst->userStop);
  userDefStop->excpSource = this;

  userDefStop->excpNo = 0;
  xtime = start;
  if (errlim) {
    minFreq = errlim;
  } else {
    minFreq = 1;
  }
  if (minFreq>1e-6*steps[modelSpec->phases]) 
    minFreq = 1e-6*steps[modelSpec->phases];

  while ((end-xtime)/steps[1]>0) { // step only affects sign
    made_step = 0;
    first_pass = 1;
    big_phase = phase_for(xtime, freq, modelSpec->phases);
    wee_phase = modelSpec->phases+1;
    // that is the biggest phase we will try to run, we may not succeed
    
    // If an event has happened and changed a state variable, we need
    // an extra update to make it actually change, followed by a
    // propagate to get the model consistent, so derivatives of
    // changed states come out right...so far, works but last() set
    // 2wice

    if (userDefStop->targetId || seriesEvtSign) { 
      // an event is waiting to take effect
      a_phase = wee_phase;
      set_dts(big_phase, xtime); // zero explicit ref to dt() in model
      resetting = big_phase;
      // advance_time(big_phase, 0); // unsets event(nextSeries)
      SetdT(0, 10+(how_int==RUNGE_KUTTA)); 
      loadedInst->updatemodel(big_phase); // b_p needed to apply squirt
      SetdT(0, (how_int==RUNGE_KUTTA)); // start prediction cycle
      // next eval will also do event driven population channels --
      // so all channels should be emptied in subphase?
      if (loadedInst->do_evalmodel(wee_phase)) break;
      // b_p needed to cancel series event
      // now make sure next bit happens
      // resetting = 0;
    } else
      a_phase = big_phase;
    //    if (resetting < 1 && !errlim)
      // resetting or have just done an event -- set a finish time very close 
      // so limit events will be re-predicted before they happen.
      // Not needed if adaptive as it then goes back for missed ones
      // -- feature removed as having a few slightly larger errors with 
      // closely-spaced events is not as bad as always getting an extra step 
      // at 1e-7 after resetting -- see mmc_twingrid.sml
      // nextSeriesEvt = xtime+minFreq;
    resetting = big_phase;

    while(!made_step) {
      // aim for next predicted event if closer than end
      // printf("Freq %f; end %f; series %f; e_p %f xt %f\n", 
      // freq, *end, nextSeriesEvt, loadedInst->event_predict, xtime);
      aim_for = end;
      if (first_pass && (aim_for-nextSeriesEvt-minFreq/2)/freq>0) 
	aim_for = nextSeriesEvt;
      if ((aim_for-loadedInst->event_predict-minFreq/2)/freq>0) 
	aim_for = loadedInst->event_predict;

      // stretch interval to hit end if necssary
      if (xtime/freq+1.0625>aim_for/freq) {
	freq = aim_for-xtime;
	if (freq/minFreq<1)
	  freq = minFreq;
      }
      xtime+=freq;

      set_dts(big_phase, xtime);
      
      switch (how_int) {
      case EULER:
	if (first_pass) {
	  recover = 0.5;
	  SetdT(0,0);
	} else {
	  SetdT(0,-1);
	}
	loadedInst->updatemodel(a_phase);
	advance_time(big_phase, 1); // sets nextSeriesEvt
	break;
      case RUNGE_KUTTA:
	if (first_pass) {
	  recover = 0.0625;
	  SetdT(0,1);
	} else {
	  SetdT(0,-2);
	}
	for (z=big_phase;z<modelSpec->phases;++z) {
	  loadedInst->dts[z] = ldts[z]*2;
	}
	loadedInst->updatemodel(a_phase);
	for (z=big_phase;z<modelSpec->phases;++z) {
	  loadedInst->dts[z] = ldts[z];
	}
	rk_update(big_phase); // returns if any err so excpNo kept
	break;
      }
      if (userDefStop->excpNo) break; // from inner loop
      first_pass = 0;
      userDefStop->targetId = 0;
      if (!errlim) {
	freq = steps[modelSpec->phases]; // no need to keep short step
	break;
      } // from while(!made_step) loop

      /* tweak to allow events to be placed precisely in time. Clear maxerr
	 before the final rate calculation, and allow threshold detection 
	 to increase it to the amount by which the threshold is crossed. */
      evtError = 0; // errlim*recover;
      SetdT(0, 10+(how_int==RUNGE_KUTTA)); 
      loadedInst->event_predict = xtime+freq; //  horizon not important
      if (loadedInst->do_evalmodel(wee_phase))
	break; // from inner loop
      // event error is time by which new prediction earlier or later
      evtError = xtime-loadedInst->event_predict;
      // now, if this error is too great, we wish to shorten the step
      // -- no need to undo anything -- and try again
      newFreq = freq;
      if (evtError > errlim) {
	newFreq = loadedInst->event_predict - (xtime-freq);
	if (newFreq/minFreq<1)
	  newFreq = minFreq;

      }
      // Now, type 10/11 act will not actually fire events so we can check for
      // continuous errors too
      loadedInst->adapt_maxerr = 0;
      loadedInst->updatemodel(wee_phase); // ts[0] still 10
	  
      if (loadedInst->adapt_maxerr>errlim) {
	if (!newFreq || newFreq/freq>0.5) // from event error
	  newFreq = freq/2;
      }

      if (newFreq/freq < 1) { // error too great; put comps back and try shorter
	if (freq/minFreq > 1) { // not already short as we can go
	  advance_time(big_phase, -1); // back to start
	  xtime-=freq;
	  freq = newFreq;
	  big_phase = phase_for(xtime, freq, modelSpec->phases);
	} else {
	  // reached max freq limit; could be compartment or event
	  userDefStop->excpNo = -99;
	  break;
	}
      } else {
	made_step = 1;
	if (freq!=steps[modelSpec->phases] &&			\
	    loadedInst->adapt_maxerr<=errlim*recover) {
	  // low error; try longer next time if poss
	  if (freq/steps[modelSpec->phases] < 0.5)
	    freq = 2*freq;
	  else
	    freq = steps[modelSpec->phases];
	} // lengthen time step
      } // timestep too short or not
    } // made progress
    // printf("Moved forward %f units\n", freq);

    wavListen* soundCh = audioChs;
    while (soundCh) {
      // moved a whole time step, do sound 
      nodeValues* ldata;
      float buffer[2];

      if (!soundCh->file) { // wav file played by events, ignore
      int nodNo = modelSpec->md_nodlin_from_id(soundCh->id) -
	modelSpec->nodedata;
      ldata = GetRawValues(nodNo);
      // send it
      int *typeLocn = ldata->dimSpecs;
      if (*typeLocn>0) //array, treat 1st two vals as L and R
	typeLocn += 1;
      if (*typeLocn == INTEGER)
	printf("Sample %d at %lf\n", *((int*)ldata->contents), xtime);
      else { // it is real
	buffer[0] = *((double*)ldata->contents);
	if (typeLocn == ldata->dimSpecs)
	  buffer[1] = buffer[0];
	else
	  buffer[1] = *(((double*)ldata->contents)+1);
      }
      delete ldata;
      // write(wavListen.mic, buffer, 4);
      // printf("Sounding %f\n", buffer[0]);
      PaError err = Pa_WriteStream(soundCh->mic, buffer, 1);
      if (err != paNoError && err != -9980) { // ignore underrun if poss
          fprintf( stderr, "An error occurred while using the portaudio stream\n" );
	  fprintf( stderr, "Error number: %d\n", err );
	  fprintf( stderr, "Error message: %s\n", Pa_GetErrorText( err ) );
	  userDefStop->excpNo = -89;
      }
      }
      soundCh = soundCh->next;
    }

    if (userDefStop->excpNo) break; // from outer loop
    SetdT(0, 5+(how_int==RUNGE_KUTTA)); 
    // now limit events will actually affect the model
    userDefStop->targetId = 0; // will be what actually fired
    loadedInst->event_predict = xtime + 1.125*freq; // > max for next step 
    // limit of period of interest
    if (loadedInst->do_evalmodel(big_phase)) break;
    //      (*advancemodel)(id, big_phase);
//    if (loadedInst->event_prev_sign) {
      //if so, run eval again in subphase to set up new predictions
//      SetdT(0, (how_int==RUNGE_KUTTA)); 
//      if (userDefStop->excpNo=loadedInst->do_evalmodel(wee_phase)) 
//	break;
//    }
    if (pause_on_events && userDefStop->targetId) {
      // -- bodge -- make sure trigger moves out of limit
      // freq = steps[modelSpec->phases]; // reset freq too
      userDefStop->excpNo = -98;
      break;
      //	printf("Event %d at %f\n", userDefStop->targetId, xtime);
    }
    if (pause_out_of_range) {
      keeper = userDefStop->targetId; // incase event to finish next step
      userDefStop->targetId = 0;
      // calling update with step 5/6 checks values within range
      loadedInst->ctxCount = 0;
      loadedInst->updatemodel(wee_phase);
      if (userDefStop->targetId) {
	report_events(loadedInst->ctxCount, loadedInst->ctxSaved,
		      0, NULL, NULL);
	if (userDefStop->targetId>0)
	  userDefStop->excpNo = -97;
	else {
	  userDefStop->targetId =-userDefStop->targetId;
	  userDefStop->excpNo = -96;
	}
	break;
      }
      userDefStop->targetId = keeper;
    }
    if (paused) {
    // always go to make sure time is right
      userDefStop->excpNo = -100;
      break;
    }
  } // finished executing

 windup:
  WrapUpThreads(userDefStop);

  if (userDefStop->excpNo) {
    return userDefStop;
  }
  return NULL;
}

void incr_time(timespec *ts, int by_ms) {
  ts->tv_nsec += 1000000*by_ms;
  if (ts->tv_nsec >= 1000000000) {
    ts->tv_nsec -= 1000000000;
    ts->tv_sec += 1;
  }
}

void ExecutingModel::set_completion(int status) {
  loadedInst->userStop.completed = status;
}

void ExecutingModel::start_in_thread(void *action(void *)) {
  xmList *topList = &modelSpec->topArgs; // need to persist

  topList->now = this;
  topList->next = NULL;

  set_completion(0);
  pthread_mutex_init(&topList->mtx, 0);
  pthread_cond_init(&topList->cond, 0);
  pthread_mutex_lock(&topList->mtx);
  pthread_create(&topList->thredd, NULL, action, topList);
}

void ExecutingModel::signal_complete(xmList* args) {
    set_completion(1);
    pthread_mutex_lock(&args->mtx);
    set_completion(2);
    pthread_cond_signal(&args->cond);
    pthread_mutex_unlock(&args->mtx);
}

excpData* ExecutingModel::check_thread(int cancel, int max_wait) {
  xmList *topList = &modelSpec->topArgs; // need to have persisted
  excpData* clientResult = &loadedInst->userStop;
  timespec ts;
  int ping;

  paused = (cancel>1);
  if (pthread_kill(topList->thredd, 0)) { // health check failed
    ping = 0;
  } else {
    clock_gettime(CLOCK_REALTIME, &ts);
    if (max_wait>=0)
      incr_time(&ts, max_wait);
    ping = pthread_cond_timedwait(&topList->cond, &topList->mtx, &ts);
    clientResult->timeOfCrime = lts[modelSpec->phases];
  }
  if (ping == ETIMEDOUT) { // still running
    if (cancel>2) { // user has lost patience
      //ping = pthread_cancel(topList->thredd); does not work on Mac
      // kill(getpid(), SIGINFO);
#ifdef __MACH__
      // SIM_OPSYS_Darwin currently not working as means of detecting MacOS!
      pthread_mutex_unlock(&topList->mtx); // allow it to complete
      pthread_kill(topList->thredd, SIGINFO); // will be caught and cause exit
#else
      pthread_cancel(topList->thredd); // does not work on Mac
#endif
      pthread_join(topList->thredd, NULL);
      clientResult->completed = 2;
      clientResult->excpNo = -101; // terminated
    } else {
      // model still running, so no result but we still need to return time
      return clientResult;
    }
  } else
    pthread_join(topList->thredd, (void **)&clientResult);
  pthread_cond_destroy(&topList->cond);
  pthread_mutex_destroy(&topList->mtx);
  rand_inits_updated = FALSE;
  return clientResult;
}

int ExecutingModel::phase_for(double current, double step, int so_far) {
    int try_now, try_current;
    double last, next, next_step;

    if (so_far==1) {
      return 1;
    }
    try_now = so_far-1;
    next_step = steps[try_now];
    last = current+step/2;
    next = last+step;

    try_current = (int)floor(last/next_step);
    if (try_current == (int)floor(next/next_step)) {
      return so_far;
    } else {
      return phase_for(next_step*try_current, next_step, try_now);
    }
  }

int ExecutingModel::rk_update(int curPhase) {
  int wee_phase;
    InstanceOfModel* id = loadedInst;

    wee_phase=modelSpec->phases+1;
    advance_time(curPhase, 0.5);
    SetdT( 0,2);
    if (id->do_evalmodel(wee_phase)) return 1;
    id->updatemodel(wee_phase);
    SetdT( 0,3);
    if (id->do_evalmodel(wee_phase)) return 1;
    id->updatemodel(wee_phase);
    advance_time(curPhase, 0.5);
    SetdT( 0,4);
    if (id->do_evalmodel(wee_phase)) return 1;
    id->updatemodel(wee_phase);
    SetdT( 0,1);
    return 0;
  }

void ExecutingModel::set_dts (int phase, double current) {
    int tweak_phase;
    for (tweak_phase=phase; tweak_phase<=modelSpec->phases; tweak_phase++) {
      ldts[tweak_phase]=current-lts[tweak_phase];
      SetdT(tweak_phase,ldts[tweak_phase]); 
      // dts should only be global but im lazy
    }
  }
  
void ExecutingModel::advance_time (int phase, double fraction) {
    int tweak_phase;
    double series_pt;

    // series_pt = lts[phases]+ldts[phases]*fraction/2; 
    // load values for middle of interval as they apply throughout it...no
    for (tweak_phase=phase; tweak_phase<=modelSpec->phases; tweak_phase++) {
      lts[tweak_phase]=lts[tweak_phase]+ldts[tweak_phase]*fraction;
      SetdT(-tweak_phase,lts[tweak_phase]); 
      // ts should only be global but im lazy
    }
    // time value is chosen to work with RK so series pt should do the same
    series_pt = lts[modelSpec->phases];
    seriesEvtSign = 0;
    nextSeriesEvt = ((series_pt >= thisTsPosn)?1:-1)*INFINITY;
    nextSeriesEvt = UpdateTimeSeries(series_pt, nextSeriesEvt);
    thisTsPosn = series_pt;
  }

double ExecutingModel::UpdateTimeSeries(double series_pt, double nextSeriesEvt)
{
  VarParamData *paramCursor, *srcCursor;
  BOOLEAN inRange;
  
  paramCursor = varParamArrayBase;
  while (paramCursor) {
    nodeValues* destPtr = &(paramCursor->dataPtr);
    ExecutingModel* defaultHolder = parent;
    inRange = paramCursor->update_from_points(series_pt, &nextSeriesEvt,
						    destPtr, false);
    while (defaultHolder && !inRange) {
      srcCursor = defaultHolder->varParamArrayBase;
      while (srcCursor && srcCursor->nodeId != paramCursor->nodeId)
	srcCursor = srcCursor->nextVP;
      if (!srcCursor) {
	printf("TNH: node %d has var data in child but not parent!\n",
	       paramCursor->nodeId);
	return 0;
      }
      inRange = srcCursor->update_from_points(series_pt, &nextSeriesEvt,
						    destPtr, true);
      defaultHolder = defaultHolder->parent;
      }
    paramCursor = paramCursor->nextVP;
  }
  return nextSeriesEvt;
}
/*
void ExecutingModel::set_evt_cmd(char* nodeId, char* cmd) {
  int spare;
  EvtCmdData *going, **insert;
  node_data_line* nodlin;
  double min,max;

  nodlin = modelSpec->nodedata + modelSpec->getinfo(nodeId, &spare);
  insert = &EvtCmdList;
  while (*insert) { // if evt had a command, remove it
    going = *insert;
    if (going->gphId == nodlin->graph) {
      *insert = going->next;
      delete going;
    } else
      insert = &(going->next);
  }
  if (*cmd) { // command non-null
    going = new EvtCmdData;
    min = nodlin->min;
    max = nodlin->max;
    if (nodlin->datatype==REAL && (min==-1e100 || max==1e100) ||
	nodlin->datatype==INTEGER && (min==-268435455 || max==268435455)) {
      going->min = 0;
      going->max = 1;
    } else {
      going->min = min;
      going->max = max;
    }
    going->gphId = nodlin->graph;
    // printf("Added cmd %s for %d\n", cmd, insert->gphId);
    going->cmd = strdup(cmd);
    going->next = NULL;
    *insert = going;
  }
}

*/
#define FRAMES_PER_BUFFER 1024

void set_wav_cmd(ModelServer* mSpec, const char* nodeId, const char* toPlay) {
  PaStreamParameters outputParameters;
  PaError err;
  int refId, spare;
  wavListen **audioPtr = &audioChs, *audioCh = NULL;

  //  refId = modelSpec->getinfo(nodeId, &spare);
  refId = mSpec->nodedata[mSpec->getinfo(nodeId, &spare)].graph;
  while (*audioPtr) {
    if ((*audioPtr)->id == refId) {
      audioCh = *audioPtr;
      if (!strcmp("/none/", toPlay)) { 
	Pa_StopStream(audioCh->mic);
	Pa_CloseStream(audioCh->mic);
	*audioPtr = audioCh->next; // snip it out
	delete audioCh;
	continue; // avoid advancing pointer again
      }
      if (audioCh->file && !strcmp(audioCh->file, toPlay) ||
	  !audioCh->file && !strcmp("/model/", toPlay)) {
	return; // already doing this, no action
      }
    }
    audioPtr = &((*audioPtr)->next);
  }
  
  if (!strcmp("/none/", toPlay)) {
    if (!audioChs) { // all waves closed, release player
      Pa_Terminate();
    }
    return;
  }
  
  if (!audioChs) { // No waves playing, kick off server
    err = Pa_Initialize();
    if( err != paNoError ) goto error;
  }

  audioCh = new wavListen;
  audioCh->id = refId;
  audioCh->next = audioChs;
  audioChs = audioCh;

    if (!strcmp("/model/", toPlay)) {
      audioCh->file = NULL;
      outputParameters.device = Pa_GetDefaultOutputDevice(); // default output device
      outputParameters.channelCount = 2;       // stereo output
      outputParameters.sampleFormat = paFloat32; // 32 bit floating point output
      outputParameters.suggestedLatency = 0.050; // Pa_GetDeviceInfo( outputParameters.device )->defaultLowOutputLatency;
      outputParameters.hostApiSpecificStreamInfo = NULL;

	err = Pa_OpenStream(&(audioCh->mic),
			    NULL, // no input
			    &outputParameters,
			    44100,
			    1,
			    0,
			    NULL, // no callback, use blocking API
			    NULL ); // no callback, so no callback userData
	if( err != paNoError ) goto error;
	
	err = Pa_StartStream(audioCh->mic);
	if( err != paNoError ) goto error;
    } else {
      // set up a wav file playback -- no sound yet...
      audioCh->file = strdup(toPlay);
      audioCh->playlist = NULL;
      if (play_sound_for(audioCh->id, 0.1)) goto error;
	    
      err = Pa_OpenDefaultStream(&audioCh->mic,
                               0,          /* no input channels */
                               audioCh->format.num_channels,
                               paFloat32,  /* 32 bit floating point output */
                               audioCh->format.sample_rate,
                               FRAMES_PER_BUFFER,
                               pasimCallback,
                               audioCh);
      if( err != paNoError ) goto error;
	
      err = Pa_StartStream(audioCh->mic);
      if( err != paNoError ) goto error;
    }
    return;

error:
  delete audioCh;
  audioChs = audioChs->next; // remove failed channel
    fprintf( stderr, "An error occurred while using the portaudio stream\n" );
    fprintf( stderr, "Error number: %d\n", err );
    fprintf( stderr, "Error message: %s\n", Pa_GetErrorText( err ) );
    // Print more information about the error.
    if( err == paUnanticipatedHostError )
    {
        const PaHostErrorInfo *hostErrorInfo = Pa_GetLastHostErrorInfo();
        fprintf( stderr, "Host API error = #%ld, hostApiType = %d\n", hostErrorInfo->errorCode, hostErrorInfo->hostApiType );
        fprintf( stderr, "Host API error = %s\n", hostErrorInfo->errorText );
    }
    Pa_Terminate();
    return;
}

graph_data_type* ExecutingModel::GetSketchGraphs() {
  return loadedInst->c_graphdata;
}

void ExecutingModel::ExitInstance () {
  loadedInst->do_exitmodel();
}

// new version: is member of model-execution class and takes numerical node id
nodeValues* ExecutingModel::GetRawValues(HCOMP nodeId) {
  int sparePath[32], fullDims[32], indices[32];
  char spareCapt[255], *insertionPt;
  nodeValues* newBlk;

  newBlk = new nodeValues;
  modelSpec->SearchInfo(nodeId, spareCapt, fullDims, newBlk->enumKey);
  // find first dimension not a positive integer
  translate_dims(fullDims, indices, newBlk->dimSpecs, 
		 modelSpec->nodedata[nodeId].datatype, 
		 loadedInst->userStop.completed);

  if (indices[0]) {
    insertionPt = newBlk->contents = new char[indices[0]];
    *sparePath = 0; // copy path data because f_r_v could overwrite it
    append_ints_to_null(sparePath, modelSpec->nodedata[nodeId].path, 0, 0);
    fill_raw_values(loadedInst, sparePath, 
		    fullDims, indices, indices, &insertionPt);
  } else
    newBlk->contents = NULL;
  return newBlk;
}

BOOLEAN ExecutingModel::do_gui_check(double model_time, int actionType) {
  printf("d_g_c t %lf a %d\n", model_time, actionType);
  return modelSpec->interact_gui(clientRef, actionType, model_time);
}

VarParamData* ExecutingModel::UseArrayForVarParam(HCOMP nodeNum, int* fullDims)
{
  xmList* variant = children;
  while (variant) {
    variant->now->UseArrayForVarParam(nodeNum, fullDims);
    variant = variant->next;
  }
  return new VarParamData(this, nodeNum, fullDims);      
}

FileParamData* ExecutingModel::UseArrayForParams(HCOMP nodeNum) {
  int fullDims[32], evalProp;
  char spareCapt[255];
  enum_type_data *spareTypes[32]; // might need for reading files

  // use searchinfo because we want the ET dims translated to numbers
  modelSpec->SearchInfo(nodeNum, spareCapt, fullDims, spareTypes);
  // make the appropriate kind of file parameter
  evalProp = modelSpec->GetProperty(nodeNum, GETEVAL);
  if (evalProp == INPUT)
    // need to make for children so they can get values for different times
    // (is separate procedure to reduce searches)
    return UseArrayForVarParam(nodeNum, fullDims);
  else
    return new FileParamData(this, nodeNum, fullDims);
}

int ExecutingModel::FillValuePointer(void* modelSlot, int paramId,
				     int ic, int* indxs) {
  FileParamData* paramArrayItem;

  paramArrayItem = param_array_base;
  if (modelSpec->param_item_from_id(&paramArrayItem, paramId))
    return paramArrayItem->extract_elt(modelSlot, indxs);
  else {
    // couldn't find id, try to find a member parameter
    // first get its nodeline
    node_data_line *nodeLine;
    nodeLine = modelSpec->md_nodlin_from_id(paramId);
    paramArrayItem = param_array_base;
    if (modelSpec->member_param_item(&paramArrayItem, nodeLine->path))
      // found a parameter inside this submodel, get record count
      return paramArrayItem->extract_record_count(modelSlot, ic, indxs);
    else if (parent)
      // No data for it in this instance, pass request up default hierarchy
      return parent->FillValuePointer(modelSlot, paramId, ic, indxs);
    else if (nodeLine->strings[1]) // exists, there is an equation for this
      return 0;
    else
      return modelSpec->get_value_pointer(clientRef, modelSlot, thisTsPosn,
			       paramId, ic, indxs);
    
  }
  // sprintf(globMess, "Think we got %d (%lf)", *(int*)modelSlot, *(double*)modelSlot);
  // showMess(globMess);

}

int entitled(char* clientEdn, char* modelIdent) {
  char modelEdn[16];
  time_t modelTime;
  int modelCompCount, maxCompCount;
  char* whereToLook, whereToStop;

  sscanf(strstr(modelIdent, "size="), "size=%d", &modelCompCount);
  if (modelCompCount<=25)
    return 0; // it's small fry

  sscanf(strstr(modelIdent, "date="), "date=%ld", &modelTime);
  whereToLook = strstr(modelIdent, "edition=")+8;
  if (!strncmp(clientEdn, whereToLook, 8) && difftime(time(NULL), modelTime)<60)
    return 1; // model generated recently by same edition -- OK
  if (!strncmp(clientEdn, "enterprise", 10) || 
      !strncmp(whereToLook, "enterprise", 10))
    return 2; // that will do nicely, sir

  if (!strncmp(clientEdn, "evaluation", 10) || 
      !strncmp(whereToLook, "evaluation", 10))
    return -1; // too big for import/export by evaluation edn

  if (modelCompCount<=50)
    return 3; // teaching edn ok

  if (!strncmp(clientEdn, "teaching", 8) || 
      !strncmp(whereToLook, "teaching", 8))
    return -2; // too big for import/export by teaching edn

  if (!strncmp(clientEdn, whereToLook, 8))
    return 4; // model big but both are standard (or some other!?) edn

  return -3; // one edition is not one we have created
}
  
// Implementation of class ModelServer
ModelServer::ModelServer(char* fileName, char* clientEdn, char** complaint) {
    *complaint = NULL;
#ifdef JOIN_AT_HIP
    getversion = get_version;
    getcount = get_count;
    createmodel = do_createmodel;
#else
    handle = LOAD_DLL(fileName);
    if (!handle) {
      *complaint = strdup(WHAT_WENT_WRONG());
      return;
    }
    getversion = (getversion_type*)FIND_FUNCTION(handle, "get_version");
    // this does nothing but return the version number, so it can be checked 
    // even if different versions change the args to getcount()
    if (getversion == NULL) {
      *complaint = new char[256];
      snprintf(*complaint, 256, "the shared object is probably not a Simile model");
      return;
    }
    // Version number is AME version = simile version + 4
    if (fabs(getversion()-4-MDL_OBJ_VERS)>0.00001) {
      *complaint = new char[256];
      snprintf(*complaint, 256, "client is for version %.4f but model is %.4f", 
	      MDL_OBJ_VERS, getversion()-4);
      return;
    }
/* sprintf(globMess, "Loaded %ld", handle);
showMess(globMess); */

    getcount = (getcount_type*)FIND_FUNCTION(handle, "get_count");
    createmodel = (createmodel_type*)FIND_FUNCTION(handle, "do_createmodel");
    make_full_caption =
      (make_full_caption_type*)FIND_FUNCTION(handle, "make_full_caption");
#endif
    nodecount = getcount(NULL, &identStr, &phases, &nodedata);
    // Now check if this client is entitled to run it
    if (entitled(clientEdn, identStr)<0) {
      *complaint = new char[256];
      snprintf(*complaint, 256, "%s edition cannot use this model", clientEdn);
      return;
    }
  }

ModelServer::~ModelServer() {
  if (handle && !UNLOAD_DLL(handle)) {
    // cannot use showMess because deleting object
    printf("Failed to unload shared library: %s\n", WHAT_WENT_WRONG());
  }
  // if (channelData) delete channelData;
}

  /* Next bit is really boring...and possibly needles...but I feel I have to
     make class procedures for the things loaded from the model dll rather than
     trying to refer to procedure variables in the model class directly */

ExecutingModel* ModelServer::create(void* yourRef) {
  supervisorId = pthread_self(); // toplevel instances only created in master
    // Do not return raw instance -- just create a wrapper object with fields
    // for raw instance and model type object
  return new ExecutingModel(this, yourRef);
}
/*
int ModelServer::parent_line (int line) {
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
      
int ModelServer::make_full_caption(int line, char *result, int* dims,
			 enum_type_data** types) {
    // New version which does not depend on the nodedata array being in
    // any particular order -- and returns the whole caption
    int parent, typesSoFar, count;

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
    
    append_ints_to_null(dims, nodedata[line].dims, 0, 0);
    return typesSoFar;
    }
  
    int find_et_struct(int fake_dim) {
    enum_data_type* seeker = enumtypedata;
    while (fake_dim++ < -10) {
      seeker = seeker->next;
    }
    return 3;
  }
  */

int ModelServer::getinfo(const char* node_id, int* gLine) {
    int count, gcount;
    char* ghosts;
    ghost_ref_data* gpair;

    *gLine = -1;
    for (count=0;nodecount>count;++count) {
      if (!strcmp(node_id, nodedata[count].name))
	return count; // found node line
      for (gcount=0;gcount<nodedata[count].ghost_count;++gcount) {
	gpair = nodedata[count].ghost_ref_ptrs + gcount;
	if (!strcmp(node_id, gpair->ghost)) {
	  *gLine = count;
	  return getinfo(gpair->base, &count); // count is spare
	}
      }
    }
    return -1;
  }

int ModelServer::GetProperty(HCOMP line, int propertyId) {
  switch (propertyId) {
    case GETTYPE:
      return nodedata[line].datatype;
    case GETVARIABLEID:
      return nodedata[line].graph;
    case GETEVAL:
      return nodedata[line].eval;
    case GETCLASS:
      return nodedata[line].compclass;
    case GETGRAPH:
      return nodedata[line].graph;
    default:
      return BADTYPE;
    }
}

const char* ModelServer::GetMetadataText(int line, int propertyId) {
  switch (propertyId) {
    case GETINTERNALID:
      return nodedata[line].name;
    case GETSPEC:
      return nodedata[line].strings[1];
    case GETDESC:
      return nodedata[line].strings[2];
    case GETCOMMENT:
      return nodedata[line].strings[3];
    default:
      return NULL;
    }
}

int ModelServer::param_item_from_id(FileParamData** start, int paramId) {
  if (!*start) {
    return 0;
  } else if (nodedata[(*start)->nodeId].graph==paramId)
    return 1;
  else {
    *start = (*start)->next;
    return param_item_from_id(start, paramId);
  }
}

/* New version of nodeModelAndId returns number
   -- who knows, maybe one day it will work intelligently? */
HCOMP ModelServer::CompFromCapt(char* seeknode) {
  int count;
  char test[255];
  int dims[32];
  enum_type_data* types[32];

  for (count = 1; nodecount>count; ++count) {
    make_full_caption(count, test, dims, types);
	  
    if (!strcmp(seeknode, test)) {
      return (HCOMP)(count);
    }
  }
  // Node with given caption not found...
  return 0;
}

int ModelServer::member_param_item(FileParamData** start, const int* parentPath) {
  node_data_line* nLine;

  if (!*start)
    return 0; // no children found
  else {
    nLine = nodedata + (*start)->nodeId;
    if (nLine->eval == TABLE) { // and fixed, is child?
      int count = -1;
      while (parentPath[++count])
	if (nLine->path[count] != parentPath[count])
	  break; // found difference
      if (!parentPath[count]) // got to end without difference, result!
	return 2;
    }
  }
  *start = (*start)->next;
  return  member_param_item(start, parentPath); // keep looking
}

node_data_line* ModelServer::md_nodlin_from_id(int paramId) {
    int count;
    node_data_line *nodeLine;
    for (count=0; count<nodecount; ++count) {
      nodeLine = nodedata + count;
      if (nodeLine->graph==paramId) return nodeLine;
    }
    return NULL;
}

int ExecutingModel::SetStep(int phase, double step) {
  steps[phase] = step;
  xmList* aChild = children;
  while (aChild) {
    aChild->now->SetStep(phase, step);
    aChild = aChild->next;
  }
  return modelSpec->phases;
}

void ExecutingModel::SetdT(int phase, double starttime) {
  if (modelSpec->phases>=abs(phase)) {
    if (phase>0) { /* lazy */
      loadedInst->dts[phase] = starttime;
    } else {
      loadedInst->ts[-phase] = starttime;
    }
  }
}

FileParamData* ExecutingModel::FileParamForNodeNum(HCOMP seekNodeId) {
  FileParamData* check = param_array_base;
  while (check) {
    if (check->nodeId == seekNodeId)
      return check;
    check = check->next;
  }
  return NULL;
}
// End of implementation of class ExecutingModel

FileParamData* param_array_item(ExecutingModel* xm, char* seekNodeId) {
  int seekNodeNum, spareInt;

  // all params are for same model instance so convert nodeId to line number
  // using model spec from first
  seekNodeNum = xm->modelSpec->getinfo(seekNodeId, &spareInt);
  return xm->FileParamForNodeNum(seekNodeNum);
}
    
void* use_array_for_params(void* xmHandle, char* nodeId) {
  FileParamData* arrSlot;
  int lineFromNodeId, spareInt, seekNodeNum;
  ExecutingModel* recipient = (ExecutingModel*)xmHandle;

  // sprintf(globMess, "use_array_for_params node %s", nodeId);
  // showMess(globMess);

  if (!(arrSlot=param_array_item(recipient, nodeId))) {
    lineFromNodeId = recipient->modelSpec->getinfo(nodeId, &spareInt);
    arrSlot = recipient->UseArrayForParams(lineFromNodeId);
    if (!arrSlot) { // no failure condition made yet
      delete arrSlot;
      return 0;
    }
    // these now done in constructor
    // arrSlot->next = param_array_base;
    // param_array_base = arrSlot;
  }

  return arrSlot;
}

void forget_param_array(void* fpHandle) {
  delete (FileParamData*)fpHandle;
}

void* get_param_data_space(void* fpHandle) {
  return ((FileParamData*)fpHandle)->dataPtr.contents;
}
			   
int space_used(int* dims, char* data, char** toFill) {
  int *base, reps, count, total = 0;
  sizeAndPtr* convenience;

  reps = array_count(dims, &base);
  if (is_base_type(*base)) {
    reps *= size_for_data_type(*base);
    if (toFill) {
      memcpy(*toFill, data, reps);
      *toFill += reps;
    }
    return reps;
  } else { // assume its OWNSIZED
    for (count=0; count<reps; ++count) {
      convenience = (sizeAndPtr*)data + count;
      //substitute OWNSIZED to create right size block then put back
      *base = convenience->size;
      total += sizeof(int);
      if (toFill) {
	memcpy(*toFill, &convenience->size, sizeof(int));
	*toFill += sizeof(int);
      }
      total += space_used(base, convenience->ptr, toFill);
    }
    *base = OWNSIZED;
    return total;
  }
}

int param_array_size(void* fpHandle) {
  nodeValues* nV;

  nV = &((FileParamData*)fpHandle)->dataPtr;
  return space_used(nV->dimSpecs, nV->contents, NULL);
}

void copy_param_data(char* holder, void* fpHandle) {
  nodeValues* nV;

  nV = &((FileParamData*)fpHandle)->dataPtr;
  space_used(nV->dimSpecs, nV->contents, &holder);
}

char* restore_param(int* dims, unsigned char** src) {
  int reps, *subDims, count;
  sizeAndPtr* convenience;
  char* newData;

  reps = array_count(dims, &subDims);
  if (is_base_type(*subDims)) {
    count = reps*size_for_data_type(*subDims);
    newData = new char[count];
    memcpy(newData, *src, count);
    *src += count;
  } else { // assume its OWNSIZED
    newData = new char[reps*sizeof(sizeAndPtr)];
    for (count=0; count<reps; ++count) {
       convenience = (sizeAndPtr*)newData + count;
      //substitute OWNSIZED to create right size block then put back
       *subDims = *(int*)(*src);
       *src += sizeof(int);
       convenience->size = *subDims;
       convenience->ptr = restore_param(subDims, src);
    }
    *subDims = OWNSIZED;
  }
  return newData;
}

void* paste_param_data(void* fpHandle, unsigned char* holder) {
  nodeValues* nV;

  nV = &((FileParamData*)fpHandle)->dataPtr;
  nV->contents = restore_param(nV->dimSpecs, &holder);
  return nV;
}

void clear_time_point_elts(void* fpHandle) {
  ((VarParamData*)fpHandle)->ClearTimePtElements();
}

double* get_wrap_ptr(void* fpHandle) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;

  return &arrSlot->wrapAroundPoint;
}

int* get_fill_ptr(void* fpHandle) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;

  return &arrSlot->fillMethod;
}

double* get_interval_ptr(void* fpHandle) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;

  return &arrSlot->seriesIdxUnits;
}

int create_time_point(void* fpHandle, double time) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;

  arrSlot->create_time_point(time);
  return 0;
}

void* find_next_timept_space(void* fpHandle, double* last_time) {
  return ((VarParamData*)fpHandle)->FindNextTimePtSpace(last_time);
}

char* get_param_ptr_and_dims(void* fpHandle, int** dimSlot) {
  nodeValues* arrSlot = &((FileParamData*)fpHandle)->dataPtr;

  *dimSlot = arrSlot->dimSpecs;
  if (!arrSlot->contents) // currently set to default
    //     arrSlot->contents = init_space(*dimSlot);
    arrSlot->contents = ((FileParamData*)fpHandle)->myModelExec->GetRawValues(((FileParamData*)fpHandle)->nodeId)->contents;
  return arrSlot->contents;
}

char** get_timepoint_ptr_and_dims(void* fpHandle, double time, 
				 int** dimSlot) {
  VarParamData* arrSlot = (VarParamData*)fpHandle;
  char** ptData;

  *dimSlot = arrSlot->dataPtr.dimSpecs;
  return arrSlot->GetTimePtDataSpace(time);
}

void mark_values_active(void* fpHandle, int wait) {
  ((VarParamData*)fpHandle)->active = wait;
}

int set_bloc_record_count(char* ptData, int* ptDims, int* indxs, int length) {
  sizeAndPtr* newRecord;
  int* subDims;

  newRecord = (sizeAndPtr*)locate_elt(ptData, 0, ptDims, indxs);
    // before going any further, check we are actually at a record list level
  subDims = ptDims;
  while (*indxs) {
    subDims += 1;
    indxs += 1;
  }
  if (*subDims != OWNSIZED) return 1; // we are not
  
  if (newRecord->size) {
    delete [] newRecord->ptr;
  }
  //substitute OWNSIZED to create right size block then put back
  *subDims = newRecord->size = length;
  newRecord->ptr = init_space(subDims);
  *subDims = OWNSIZED;
  return 0;
}

int insert_to_array(char* contents, double val, int* dimSpecs, int* indxs,
		    int base) {
  void* insertionPt;
  
  insertionPt = locate_elt(contents, 0, dimSpecs, indxs);
  switch (base) {
  case REAL:
    *(double*)insertionPt = val;
    break;
  case FLAG:
    *(BOOLEAN*)insertionPt = (BOOLEAN)val;
    break;
  default: // INTEGER or enumerated type
    *(int*)insertionPt = (int)val;
    break;
  }
  //sprintf(globMess, "inserted %lf to space at %d %d", val, indxs[0], indxs[1]);
  //showMess(globMess);
  return 0;
}

void set_bloc_element(char* ptData, int* ptDims, int* indxs, double value) {
  // Because Simile input tools may not supply all the dimensions of the 
  // parameter array, this has to work out how many dimensions are supplied
  // and fill all the elements for which these are the innermost indices.
  int count, haveDims, needDims, makeDims, useDims[32], recBounds[32], done = 0;
  for (count=31; count>=0; count--) {
    if (!indxs[count]) {
      // in versions 5.5-5.8 this expected indxs to be terminated with a -ve,
      // but they are generated by ints_from_list and the Tcl values do not
      // contain a -ve (even for per-records) so it should be 0 to avoid bugs
      haveDims = count;
    }
    if (is_base_type(ptDims[count])) {
      needDims = count;
      haveDims = count; // avoid having too many
    }
  }
  makeDims = needDims-haveDims;
  //sprintf(globMess, "have %d need %d (val %lf)", haveDims,needDims,value);
  //showMess(globMess);
  for (count = 0; count<needDims; count++) {
    if (count<makeDims) {
      recBounds[count] = ptDims[count];
      useDims[count] = 1;
    } else {
      useDims[count] = indxs[count-makeDims];
    }
  }
  // next bit iterates over all combinations of outer dimensions
  while (!done) {
    insert_to_array(ptData, value, ptDims, useDims, ptDims[needDims]);
    for (count = makeDims-1; count>=0; count--) {
      if (useDims[count] == 1 && ptDims[count] == OWNSIZED) {
	useDims[count] = 0; // tells locate_elt to get record count
	recBounds[count] = 
	  ((sizeAndPtr*)locate_elt(ptData, 0, ptDims, useDims))->size;
	useDims[count] = 1; // back to normal
      }
      if (++useDims[count]<=recBounds[count]) break;
      useDims[count] = 1;
    }
    done = count==-1;
  }
}

int handle_model_param_request(void* instId, void* modelSlot, int paramId, 
				int ic, int* indxs) {
//  sprintf(globMess, "h_m_p_t to location %lx for exmod %lx node %d count %d indx0 %d indx1 %d", (long)modelSlot, (long)instId, paramId, ic, indxs[0], indxs[1]);
//  showMess(globMess);
  return ((ExecutingModel*)instId)->FillValuePointer(modelSlot, paramId, ic, indxs);
}

/* This finds node ids from captions globally. It runs through a model
comparing each caption with what we are after, and as well as returning if
it finds it, it continues inside any separate submodel it comes across whose
caption fits the start of what we are after (after trimming the portion found
from the search string, less the submodel itself -- note it may be an issue
that the submodel name is searched for in both models )

char* ModelServer::nodeModelAndId(char* seeknode) {
  int count, gcount, lcount, spare;
  char test[255], *tail;
  int dims[32];
  enum_type_data* types[32];
  node_data_line* bottomLine;
  ghost_ref_data* gpair;

  //sprintf(globMess, "Looking for %s", seeknode);
  //showMess(globMess);
  for (count = 0; nodecount>count; ++count) {
    make_full_caption(count, test, dims, types);
    //sprintf(globMess, "Got base %s", test);
    //showMess(globMess);
	  
    if (!strcmp(seeknode, test)) {
      return(nodedata[count].name);
    }
    
    // rest is dedicated to finding ghost nodes, which should only be tried 
    // if base is not found, if at all, so have put in new loop
  }
  for (count = 0; nodecount>count; ++count) {
    make_full_caption(count, test, dims, types);
    if (strstr(seeknode, test) != seeknode) continue;
    // test is initial substring
    tail = seeknode + strlen(test);
    if (*tail != '/') continue;
    tail += 1;
    for (gcount=0;nodedata[count].ghost_count>gcount;++gcount) {
      gpair = nodedata[count].ghost_ref_ptrs + gcount;
      lcount = getinfo(gpair->base, &spare);
      //sprintf(globMess, "Got ghost %s", nodedata[lcount].strings[0]);
      //showMess(globMess);
      if (!strcmp(tail, nodedata[lcount].strings[0])) {
	return(gpair->ghost);
      }
    }
  }
  // Node with given caption not found...
  return NULL;
}
*/
const char *falseTxt = (const char*)"false";
const char *trueTxt = (const char*)"true";
const char *booleanMems[2] = {falseTxt, trueTxt};
const char rectkey_txt[] = "rectkey", ne_txt[] = "ne", n_txt[] = "n", nw_txt[] = "nw", e_txt[] = "e", se_txt[] = "se", s_txt[] = "s", sw_txt[] = "sw", w_txt[] = "w";
const char* rectkey_mems[8] = {sw_txt,s_txt,se_txt,w_txt,e_txt,nw_txt,n_txt,ne_txt};
const char hexkey_txt[] = "hexkey", h1_txt[] = "1h", h11_txt[] = "11h", h3_txt[] = "3h", h5_txt[] = "5h", h7_txt[] = "7h", h9_txt[] = "9h";
const char* hexkey_mems[6] = {h7_txt, h5_txt, h9_txt, h3_txt, h11_txt, h1_txt};
enum_type_data noType = {0, NULL, NULL}, 
  boolDataType = {1, falseTxt, &trueTxt},
  boolDimType = {2, "boolean", (const char**)booleanMems},
  hexkeyType = {6, hexkey_txt, hexkey_mems},
  rectkeyType = {8, rectkey_txt, rectkey_mems};

node_data_line* ModelServer::SearchInfo(int lineNum, char* caption, 
			   int* dims, enum_type_data** usedTypes) {
  enum_type_data *thisType, *localTypes[128];
  int dimCount, usedCount, iType;
  node_data_line* bottomLine;

  /* botch: when getting info on a new separate submodel, we don't
     want references to enumerated types in parent models to crash it,
     so fill the array with null types */
  for (usedCount=0; usedCount<128; ++usedCount) {
    localTypes[usedCount]=&noType;
  }	
  make_full_caption(lineNum, caption, dims, localTypes);
  usedCount=dimCount=0;
    while (dims[dimCount]) {
//      sprintf(globMess, "dim %d is %d", dimCount, dims[dimCount]);
//      showMess(globMess);
      if (dims[dimCount] <= ENUM_BASE) {
	thisType = localTypes[ENUM_BASE-dims[dimCount]];
//	printf("chaining type %s\n", thisType->name);
	usedTypes[usedCount++] = thisType;
	dims[dimCount] = thisType->count;
      } else if (dims[dimCount] == FLAG) {
	usedTypes[usedCount++] = &boolDimType;
	dims[dimCount] = 2;
      } else if (dims[dimCount] == RECT_NBR) {
	usedTypes[usedCount++] = &rectkeyType;
	dims[dimCount] = 8;
      } else if (dims[dimCount] == HEX_NBR) {
	usedTypes[usedCount++] = &hexkeyType;
	dims[dimCount] = 6;
      } else if (dims[dimCount]==START_VM || 
		 dims[dimCount]==END_VM) {
      } else {
	usedTypes[usedCount++] = &noType;
      }
      ++dimCount;
    }
    bottomLine = nodedata + lineNum;
    if (bottomLine->datatype <= ENUM_BASE) {
      thisType = localTypes[ENUM_BASE-bottomLine->datatype];
//      sprintf(globMess, "type is %d, setting result %d to %s", 
//              bottomLine->datatype, usedCount, thisType->name);
//      showMess(globMess);
      usedTypes[usedCount++] = thisType;
    } else if (bottomLine->datatype == FLAG) {
      usedTypes[usedCount++] = &boolDataType;
    } else if (bottomLine->datatype == RECT_NBR) {
      usedTypes[usedCount++] = &rectkeyType;
    } else if (bottomLine->datatype == HEX_NBR) {
      usedTypes[usedCount++] = &hexkeyType;
    } else {
      usedTypes[usedCount++] = &noType;
    }
  // }
  usedTypes[usedCount] = NULL;
  return bottomLine;
}

/* translate_dims: this takes the dimensions of the node's data as
returned by the model, and converts them to those used in the data
structure. The main difference is that in the data structure, a
variable-membership model identifier is followed by its dimensionality
(1 for population models) while per-record submodels do not have this
extra value.

A parallel array is also passed which gets the size of the data block
needed at each level, making it quicker to fill the actual structure.

If we are making a structure for a file parameter, we re-use data
across instances of conditional and population models (we cannot cope
with changes in membership otherwise), so leave out level info for
these if skip_vms is set.
*/
void translate_dims(int fromModel[], int blockSizes[], int structDims[],
		    int dataType, int vm_action) {
  int defDimty = 1; // will be used unchanged if case MEMBERS
  structDims[0] = OWNSIZED; // will not be set if case RECORDS
  switch (fromModel[0]) {
  case START_VM: // count dims to FINISH_VM and insert SPARSEARRAY of them
    defDimty = skip_vm_bounds(&fromModel);
  case MEMBERS: // or START_VM
    switch (vm_action) {
    case 0: // getting data while model running: unavailable
      structDims[0] = UNSTABLE;
      blockSizes[0] = 0;
      return;
    case -1: // making dims for parameter value: leave out level
      translate_dims(fromModel+1, blockSizes, structDims, dataType, vm_action);
      return;
    default: // insert level
      structDims[0] = SPARSEARRAY;
      structDims[1] = defDimty;
      structDims += 1;
    }
    // and drop through
  case RECORDS: // or  MEMBERS or START_VM
    blockSizes[0] = sizeof(sizeAndPtr);
    break;
  case 0: // dimensions finished, insert type and its size (could alloc dims!)
    structDims[0] = dataType;
    blockSizes[0] = size_for_data_type(dataType);
    return;
  default: // an array dimension, or RECORDS
    structDims[0] = fromModel[0];
  }
  translate_dims(fromModel+1, blockSizes+1, structDims+1, dataType, vm_action);
  // now set size if a multiple of the next one...
  if (fromModel[0]>0) 
    blockSizes[0] = blockSizes[1]*fromModel[0];
}

// Start of 5-D interface for straight-C clients

// function pointers for callbacks

interact_gui_type* fivedee_interact_gui;
get_value_pointer_type* fivedee_get_value_pointer;
showMess_type* fivedee_showMess;

// procedure that is called by shim when it is loaded to supply pointers
// to its callback procedures

void proc_pointers_for_shank(get_value_pointer_type* get_value_pointer_ptr,
			     interact_gui_type* interact_gui_ptr,
			     showMess_type* showMess_ptr) {
  fivedee_get_value_pointer = get_value_pointer_ptr;
  fivedee_interact_gui = interact_gui_ptr;
  fivedee_showMess = showMess_ptr;

  // this is only called once so is sensible place to make sure int signal
  // sent from gui thread goes to model execution thread. No need for now as
  // pthread_kill can direct it there.
  //sigset_t set;
  //sigemptyset(&set);
  //sigaddset(&set, SIGINFO);
  //pthread_sigmask(SIG_BLOCK, &set, NULL);
}

// Derived class which instantiates the callback procedures to those supplied
// by proc_pointers_for_shank
class ModelFor5D: public ModelServer {
public:
  ModelFor5D(char* fileName, char* hostEdn, char** complaint) : 
    ModelServer(fileName, hostEdn, complaint)
  {
  }

  ~ModelFor5D() {
  }
  
  int get_value_pointer(void* ref, void* slot, double time,
				int paramId, int ic, int* indxs) {
    return fivedee_get_value_pointer(ref, slot, time, paramId, ic, indxs);
  }

  int interact_gui(void* ref, int action, double modelTime) {
    return fivedee_interact_gui(ref, action, modelTime);
  }
  
  void showMess(const char* toShow) {
    fivedee_showMess(toShow);
  }
}; // End of class ModelFor5D

// Now here are the procedures which a 5-D client (such as Simile) will call

// This one creates a new kind of model from the saved executable
char* load_model(char* fileName, char* hostEdn, void** modelType) {
  ModelFor5D* newModel;
  char* complaint;

  newModel = new ModelFor5D(fileName, hostEdn, &complaint);
  if (complaint) {
    delete newModel; // will unload dll if one has been loaded
    return complaint;
  }
  *modelType = newModel;
  return NULL;
}

// create a model instance
void* fetch_top_instance(void* modelType, void* clientRef) {
  ExecutingModel* justMade;

  // 5-D callbacks have the client data set to the instance
  justMade = ((ModelFor5D*)modelType)->create(clientRef);
  return justMade;
}

// create a group member for a model instance
void* fetch_group_member(void* instanceType, void* clientRef) {
  ExecutingModel* justMade;

  // 5-D callbacks have the client data set to the instance
  justMade = ((ExecutingModel*)instanceType)->AddGroupMember(clientRef);
  return justMade;
}

void delete_instance(void* instanceType) {
  delete (ExecutingModel*)instanceType;
}

// get metadata: deprecated as each attribute should be sought individually
node_data_line* searchinfo(char* node, void* tgtModel, char* caption, 
			   int* dims, enum_type_data** usedTypes) {
  int ghostLine;
  node_data_line* bottomLine;
  char localCapt[255];

  int lineNum = ((ModelFor5D*)tgtModel)->getinfo(node, &ghostLine);
  if (lineNum == -1) return NULL;
  if (ghostLine>-1) {
    ((ModelFor5D*)tgtModel)->make_full_caption(ghostLine, caption, 
					       dims, usedTypes);
  }
  bottomLine = ((ModelFor5D*)tgtModel)->SearchInfo(lineNum, localCapt, 
						dims, usedTypes);
  if (ghostLine>-1) { // append base tail to ghost submodel caption
    strcat(caption, "/");
    strcat(caption, bottomLine->strings[0]);
  } else
    strcpy(caption, localCapt);
  return bottomLine;
}

/* utility procedures for accessing model data */

int get_node_count(void* type) {
  return ((ModelFor5D*)type)->nodecount;
}

node_data_line* get_data_line(void* type, int line) {
  return &((ModelFor5D*)type)->nodedata[line];
}

graph_data_type* get_graph_base(void* instanceId) {
  return ((ExecutingModel*)instanceId)->GetSketchGraphs();
}

// get a node data line from the 'graph' number of the node
node_data_line* nodlin_from_id(void* modelId, int paramId) {
  return ((ModelFor5D*)modelId)->md_nodlin_from_id(paramId);
}

void add_wave_command(void* instanceId, char* nodeId, char* toPlay) {
  set_wav_cmd(((ExecutingModel*)instanceId)->modelSpec, nodeId, toPlay);
}

void clear_wav_commands(ModelFor5D* modelId) {
  // now clear all sounds
  for (int i=0; i<modelId->nodecount; ++i) {
    set_wav_cmd(modelId, modelId->nodedata[i].name, "/none/");
  }
}

// dumb it down even further for emscripten clients that do not know how to get
// fields from structures -- the 4-D interface?

const char* name_from_nodlin(node_data_line* line) {
  return line->name;
}

const char* eqn_from_nodlin(node_data_line* line) {
  return line->strings[1];
}

const double min_from_nodlin(node_data_line* line) {
  return line->min;
}

const double max_from_nodlin(node_data_line* line) {
  return line->max;
}

const int class_from_nodlin(node_data_line* line) {
  return line->compclass;
}

const int type_from_nodlin(node_data_line* line) {
  return line->datatype;
}

const int eval_from_nodlin(node_data_line* line) {
  return line->eval;
}

const char* units_from_nodlin(node_data_line* line) {
  return line->strings[2];
}

int* ds_from_nodvals(nodeValues* nodVals) {
  return nodVals->dimSpecs;
}

void* ct_from_nodvals(nodeValues* nodVals) {
  return nodVals->contents;
}

int size_from_sznptr(sizeAndPtr* szPtr) {
  return szPtr->size;
}

void* ptr_from_sznptr(sizeAndPtr* szPtr) {
  return szPtr->ptr;
}

// setstep: the model class instances contain an array of doubles called
// dts representing the time steps at the various phases. This function reaches
// in and sets one of them. Returns phase count. Node that ts[0] is set to
// the integration step being done: 0 for Euler, 1-4 for the four stages of RK

int setstep(void* instId, double starttime, int phase) {
  return ((ExecutingModel*)instId)->SetStep(phase, starttime);
}

/* filling a structure of this type is going to be a straight copy of the Tcl
   list builder in the shim, cos it's the easiest way to think through it */

nodeValues* get_raw_values(char* nodeId, void* instance_id) {
  int nodeNum, spareNum;

  nodeNum = ((ExecutingModel*)instance_id)->modelSpec->getinfo(nodeId, 
							       &spareNum);
  if (nodeNum==-1)
    return NULL;
  return ((ExecutingModel*)instance_id)->GetRawValues(nodeNum);
}

void go_reset(void* modelType, void* modelHandle, double t0, int how_int,
	      int top_phase) {
  xmList topList;
  topList.next = NULL;
  ExecutingModel* convenience = (ExecutingModel*)modelHandle;
  topList.now = convenience;
  convenience->initTime = t0;
  convenience->howInt = how_int;
  convenience->topPhase = top_phase;
  // if tp is -2, initialize pseudos
  if (top_phase == -2) {
    timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    unsigned int rnd=(1000000007*(intptr_t)pthread_self()+now.tv_nsec);
    setup_randoms(rnd);
  }
  //return ((ExecutingModel*)modelHandle)->ResetInstance(t0, how_int, top_phase);
  convenience->start_in_thread(reset_grp_instance);
}

void repeat_reset(void* modelType, void* modelHandle, double t0) {
  ((ExecutingModel*)modelHandle)->RepeatReset(t0);
}

void go_execute(void* modelType, void* modelHandle, int how_int,
		double starttime, double endtime, double errlim,
		BOOLEAN lmt_pause, BOOLEAN evt_pause) {
  ExecutingModel* convenience = (ExecutingModel*)modelHandle;

  convenience->initTime = starttime;
  convenience->howInt = how_int;
  convenience->finalTime = endtime;
  convenience->errLim = errlim;
  convenience->pauseRange = lmt_pause;
  convenience->pauseEvt = evt_pause;
  //return ((ExecutingModel*)modelHandle)->ExecuteInstance(how_int, starttime, 
//							 endtime, errlim,
//							 lmt_pause, evt_pause);
  convenience->start_in_thread(execute_grp_instance);
}

excpData* check_action(void* modelType, void* modelHandle,
		       int cancel, int max_wait) {
  return ((ExecutingModel*)modelHandle)->check_thread(cancel, max_wait);
}

// single-threaded versions for external clients
excpData* reset(void* modelType, void* modelHandle, double t0, int how_int,
	      int top_phase) {
  return ((ExecutingModel*)modelHandle)->ResetInstance(t0, how_int, top_phase);
}

excpData* execute(void* modelType, void* modelHandle, int how_int,
		  double starttime, double endtime, double errlim,
		  BOOLEAN lmt_pause, BOOLEAN evt_pause) {
  return ((ExecutingModel*)modelHandle)->ExecuteInstance(how_int, starttime, 
							 endtime, errlim,
							 lmt_pause, evt_pause);
}

// This deletes a model instance and/or a class -- both when used in Simile
char* myexit(void* modelType, void* modelHandle) {  
  if (modelHandle) {
    ((ExecutingModel*)modelHandle)->ExitInstance();
    // swap below cmd for above at next minor version increment
    delete (ExecutingModel*)modelHandle;
  }
  if (modelType) {
    clear_wav_commands((ModelFor5D*)modelType);
    delete (ModelFor5D*)modelType;
  }
  return NULL; // message displayed in destructor cos it is not allowed
  // to have params or retval
}

const char* getNodeId(void* modelType, char* capt) {
  int tgtIndex;

  tgtIndex = ((ModelServer*)modelType)->CompFromCapt(capt);
  return ((ModelServer*)modelType)->nodedata[tgtIndex].name;
}
