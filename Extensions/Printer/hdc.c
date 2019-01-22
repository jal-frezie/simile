#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "hdc.h"

/****************************************************************
** HDC.C
**
** RCS Version $Revision: 1.1 $
** RCS Last Change Date: $Date: 2019/01/22 16:31:16 $
** Original Author: Michael I. Schwartz, mschwart@nyx.net
**
** Note: This is a work in progress. Please coordinate changes with
** the original author.
**
** RCS Change Summaries:
**   $Log: hdc.c,v $
**   Revision 1.1  2019/01/22 16:31:16  jaspert
**   Added windows printer sources
**   Attempt (badly) to use cmake package for .xlsx in Linux
**   Colour model inspector submodel sections
**
**   Revision 1.2  1999/10/24 22:35:16  Michael_Schwartz
**   Added a new function to support attaching to the support APIs
**   without having to link the DLL at load time.
**   This approach is a little crude (function pointers written out
**   as hex addresses), but has proven effective and not too
**   inefficient in testing
**
** Revision 1.1  1998/05/18  04:07:54  Michael_Schwartz
** Initial revision
**
**
** Usage (Program only):
**
** Usage (Tcl)
**  hdc addr name
**  hdc create addr type
**  hdc delete name
**  hdc list [-type type] [-match match]
**  hdc prefix type [newprefix]
**  hdc set name -addr addr -type type
**  hdc type name
**  hdc version
**  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
**************************************************************==*/
#if defined(__WIN32__) || defined (__WIN32S__) || defined (WIN32S)
# ifndef STATIC_BUILD
#   if defined(_MSC_VER)
#     define EXPORT(a,b) __declspec(dllexport) a b
#     define DllEntryPoint DllMain
#   else
#     if defined(__BORLANDC__)
#         define EXPORT(a,b) a _export b
#     else
#         define EXPORT(a,b) a b
#     endif
#   endif
# endif
 #if defined(_WIN64)
  #define PTR_LIKE_INT unsigned long long
  #define PTR_FROM_STR strtoull
 #else
  #define PTR_LIKE_INT unsigned long
  #define PTR_FROM_STR strtoul
 #endif
#else
#   define EXPORT(a,b) a b
#endif

#if TCL_MAJOR_VERSION == 7 && TCL_MINOR_VERSION <= 5
/* In this case, must replace Tcl_Alloc(), Tcl_Realloc(), and Tcl_Free()
** with ckalloc(), ckrealloc(), and ckfree()
*/

#define Tcl_Alloc(x)  ckalloc(x)
#define Tcl_Free(x)   ckfree(x)
#define Tcl_Realloc(x,y)  ckrealloc(x,y)

#endif

/****************************************************************
** Static functions amd data
****************************************************************/
struct hdc_value
{
  void *addr;
  int  type;
};

static unsigned long hdc_count = 0L;
static Tcl_HashTable hdcs;
static Tcl_HashTable hdcprefixes;
static char hdc_name [32+12+1];

static void Hdc_names_init(void);
static void Hdc_names_delete(void);
static const char *Hdc_build_name(int type);

static char version_string[] = "0.2.0.1";
static char hdc_command_name[] = "hdc";
static char usage[] = "Usage:\n"
  "\thdc addr name\n"
  "\thdc create addr type\n"
  "\thdc delete name\n"
  "\thdc list [-type type] [-match pattern]\n"
  "\thdc prefix type [newprefix]\n"
  "\thdc set name -addr addr -type type\n"
  "\thdc type name\n"
  "\thdc version\n"
;

/****************************************************************
** Public functions
****************************************************************/
/****************************************************************
** Tcl Script Functions
**
****************************************************************/

static int Hdc(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcAddr(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcCreate(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcDelete(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcList(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcPrefix(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcSet(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcType(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcVersion(ClientData data, Tcl_Interp *interp, int argc, char **argv);
static int HdcFunctionVector (ClientData data, Tcl_Interp *interp, int argc, char **argv);

/****************************************************************
** Tcl C Functions
**
****************************************************************/

/* Exported symbols */
#if defined(__WIN32__) || defined (__WIN32S__) || defined (WIN32S)
#ifndef STATIC_BUILD
BOOL APIENTRY DllEntryPoint (HINSTANCE hInstance, DWORD reason, LPVOID lpCmdLine)
{
  switch (reason)
  {
    case DLL_PROCESS_ATTACH:
      break;
    case DLL_THREAD_ATTACH:
      break;
    case DLL_PROCESS_DETACH:
      /* Release all the memory allocated by the images */
      Hdc_names_delete();
      break;
    case DLL_THREAD_DETACH:
      break;
  }
  /* Don't do anything, so just return true */
  return TRUE;
}
#endif
#endif

EXTERN EXPORT(int,Hdc_Init) (Tcl_Interp *interp)
{
  /* Possible usage: hdc addr name, hdc type name, hdc delete name
     hdc create addr type, hdc list, hdc set?
  */

  #if defined(USE_TCL_STUBS)
    Tcl_InitStubs(interp, TCL_VERSION, 0 );
  #endif

  Hdc_names_init();

  Tcl_CreateCommand (interp, hdc_command_name, Hdc, 0, 0);
  Tcl_PkgProvide (interp, hdc_command_name, version_string);
  
  return TCL_OK;
}

EXTERN EXPORT(const char *,Hdc_Create) (Tcl_Interp *interp, void *ptr, int type)
{
  struct hdc_value *pval;
  const char *name;
  Tcl_HashEntry *entry;
  int status;
  
  pval = (struct hdc_value *)Tcl_Alloc(sizeof(struct hdc_value));
  if (pval == 0)
  {
    return 0;
  }
  pval->addr = ptr;
  pval->type = type;

  name = Hdc_build_name(type);
  if ( ( entry = Tcl_CreateHashEntry(&hdcs, name, &status)) != 0 )
    Tcl_SetHashValue(entry, (ClientData)pval);
  return name;
}

EXTERN EXPORT(int,Hdc_Valid) (Tcl_Interp *interp, const char *hdcname, int type)
{
  struct hdc_value *val;
  Tcl_HashEntry *data;

  if ( (data = Tcl_FindHashEntry(&hdcs, hdcname)) != 0 )
  {
    val = (struct hdc_value *)Tcl_GetHashValue(data);

    if ( type <= 0 || val->type == type )
      return 1;
  }
  return 0;
}

EXTERN EXPORT(int,Hdc_Delete) (Tcl_Interp *interp, const char *hdcname)
{
  struct hdc_value *val;
  Tcl_HashEntry *data;

  if ( (data = Tcl_FindHashEntry(&hdcs, hdcname)) != 0 )
  {
    val = (struct hdc_value *)Tcl_GetHashValue(data);

    Tcl_DeleteHashEntry(data);
    Tcl_Free((void *)val);
    return 1;
  }
  return 0;
}

EXTERN EXPORT(void *,Hdc_Get) (Tcl_Interp *interp, const char *hdcname)
{
  struct hdc_value *val;
  Tcl_HashEntry *data;

  if ( (data = Tcl_FindHashEntry(&hdcs, hdcname)) != 0 )
    val = (struct hdc_value *)Tcl_GetHashValue(data);
  else
    return 0;

  return val->addr;
}

EXTERN EXPORT(int,Hdc_TypeOf) (Tcl_Interp *interp, const char *hdcname)
{
  struct hdc_value *val;
  Tcl_HashEntry *data;

  if ( (data = Tcl_FindHashEntry(&hdcs, hdcname)) != 0 )
    val = (struct hdc_value *)Tcl_GetHashValue(data);

  return val->type;
}

EXTERN EXPORT(const char *,Hdc_PrefixOf) (Tcl_Interp *interp, int type, const char *newprefix)
{
  const char *prefix;
  Tcl_HashEntry *data;

  if ( (data = Tcl_FindHashEntry(&hdcprefixes, (char *)type)) != 0 )
    prefix = (const char *)Tcl_GetHashValue(data);
    
  if ( newprefix )
  {
    char *cp;
    int siz, len;
    
    siz = strlen(newprefix);
    len = siz > 32 ? 32 : siz;
    
    if ( (cp = (char *)Tcl_Alloc(len+1)) != 0 )
    {
      int newptr = 0;
      
      strncpy (cp, newprefix, len);
      cp[len] = '\0';
      if ( data == 0 )
        data = Tcl_CreateHashEntry(&hdcprefixes,(char *)type,&newptr);
      Tcl_SetHashValue(data, (ClientData)cp);
      prefix = cp;
    }
  }

  return prefix;
}

/*
*/
EXTERN EXPORT(int,Hdc_List) (Tcl_Interp *interp, int type, const char *out[], int *poutlen)
{
  Tcl_HashEntry *ent;
  Tcl_HashSearch srch;
  int i=0;
  const char *cp;
  int retval = 0;
  struct hdc_value *val;
  
  for ( ent = Tcl_FirstHashEntry(&hdcs, &srch); ent !=0; ent=Tcl_NextHashEntry(&srch))
  {
    if ( (cp = Tcl_GetHashKey(&hdcs, ent)) != 0 )
    {
      if ( i < *poutlen )
      {
        if ( (val = (struct hdc_value *)Tcl_GetHashValue(ent) ) != 0 )
        {
          if ( type <= 0 || type == val->type )
          {
            out[i++] = cp;
            retval++;
          }
        }
      }
    }
  }
  *poutlen = i;
  return retval;
}

/****************************************************************
** Tcl script handlers
****************************************************************/
static int Hdc(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  static struct cmdstruct
  {
    const char *name;
    int (*func)(ClientData data, Tcl_Interp *interp, int argc, char **argv);
  } subcommands[] =
  {
    { "addr",     HdcAddr },
    { "create",   HdcCreate },
    { "delete",   HdcDelete },
    { "FunctionVector", HdcFunctionVector },
    { "list",     HdcList },
    { "prefix",   HdcPrefix },
    { "set",      HdcSet },
    { "type",     HdcType },
    { "version",  HdcVersion },
  };
  int i;

  argc--;
  argv++;

  if (argc > 0 )
    for (i=0; i < sizeof(subcommands)/sizeof(subcommands[0]); i++ )
      if ( strcmp(subcommands[i].name, argv[0]) == 0 )
        return subcommands[i].func(data,interp,argc-1, argv+1);
  Tcl_SetResult(interp, usage, TCL_STATIC);
  return TCL_ERROR;
}

static int HdcCreate(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  PTR_LIKE_INT addr;
  int type;
  char *cp;
  const char *name;
  
  if (argc != 2)
  {
    Tcl_SetResult(interp, usage, TCL_STATIC);
    return TCL_ERROR;
  }

  addr = PTR_FROM_STR(argv[0], &cp, 0);
  if (cp == argv[0]) /* Couldn't parse address */
  {
    Tcl_AppendResult(interp, "Address not understood\n", usage, 0);
    return TCL_ERROR;
  }
  if ( (type = atoi(argv[1])) <= 0 )
  {
    Tcl_AppendResult(interp, "Type not understood\n", usage, 0);
    return TCL_ERROR;
  }
  name = Hdc_Create(interp, (void *)addr, type);
  if ( name == 0 )
    return TCL_ERROR;

  Tcl_SetResult(interp, (char *)name, TCL_VOLATILE);
  return TCL_OK;
}

static int HdcAddr(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  char address[(sizeof(void *)/sizeof(long))*11 +1];
  void *addr;

  if ( argc <= 0 )
  {
    Tcl_SetResult(interp, usage, TCL_STATIC);
    return TCL_ERROR;
  }
  if ( Hdc_Valid(interp, argv[0], 0) == 0 )
  {
    Tcl_AppendResult(interp, "Invalid Hdc\n", usage, 0);
    return TCL_ERROR;
  }
  addr = Hdc_Get(interp, argv[0]);
  sprintf(address, "0x%lx", addr);
  Tcl_SetResult(interp, address, TCL_VOLATILE);
  return TCL_OK;
}

static int HdcType(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  char value[11 +1];
  int type;

  if ( argc <= 0 )
  {
    Tcl_SetResult(interp, usage, TCL_STATIC);
    return TCL_ERROR;
  }
  if ( Hdc_Valid(interp, argv[0], 0) == 0 )
  {
    Tcl_AppendResult(interp, "Invalid Hdc\n", usage, 0);
    return TCL_ERROR;
  }
  type = Hdc_TypeOf(interp, argv[0]);
  sprintf(value, "%d", type);
  Tcl_SetResult(interp, value, TCL_VOLATILE);
  return TCL_OK;
}

static int HdcDelete(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  if ( argc <= 0 )
  {
    Tcl_SetResult(interp, usage, TCL_STATIC);
    return TCL_ERROR;
  }
  if ( Hdc_Valid(interp, argv[0], 0) == 0 )
  {
    Tcl_AppendResult(interp, "Invalid Hdc\n", usage, 0);
    return TCL_ERROR;
  }
  Hdc_Delete(interp, argv[0]);
  return TCL_OK;
}

static int HdcList(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  Tcl_HashEntry *ent;
  Tcl_HashSearch srch;
  int i;
  const char *cp;
  struct hdc_value *val;

  int istype = 0;
  int type;
  int ismatch = 0;
  char *match;

  while (argc > 0)
  {
    if ( strcmp(*argv, "-type" ) == 0 )
    {
      if (--argc > 0 )
      {
        istype = 1;
        type = atoi(*++argv);
      }
    }
    else if ( strcmp(*argv, "-match" ) == 0 )
    {
      if ( --argc > 0 )
      {
        ismatch = 1;
        match = *++argv;
      }
    }
    argc--;
    argv++;
  }
  
  for ( ent = Tcl_FirstHashEntry(&hdcs, &srch); ent !=0; ent=Tcl_NextHashEntry(&srch))
  {
    if ( (cp = Tcl_GetHashKey(&hdcs, ent)) != 0 )
    {
      if ( (val = (struct hdc_value *)Tcl_GetHashValue(ent) ) != 0 )
      {
        if ( istype == 0 || type <= 0 || type == val->type )
        {
          /* All that's left is the match part! */
          if ( ismatch == 0 || Tcl_StringMatch((char *)cp, match) )
            Tcl_AppendElement(interp, (char *)cp);
        }
      }
    }
  }
  return TCL_OK;
}

static int HdcPrefix(ClientData d, Tcl_Interp *interp, int argc, char **argv)
{
  int type;
  const char *newprefix=0;
  Tcl_HashEntry *data;
  int status;
  const char *prefix;
  
  if ( argc <= 0 )
  {
    Tcl_SetResult(interp, usage, TCL_STATIC);
    return TCL_ERROR;
  }
  type = atoi(argv[0]);
  if ( argc > 1)
    newprefix=argv[1];

  if ( type <= 0 )
  {
    Tcl_AppendResult(interp, "Type must be postive integer\n", usage, 0);
    return TCL_ERROR;
  }

  if ( newprefix )
  {
    char *cp;
    if ( (cp = (char *)Tcl_Alloc(strlen(newprefix))) != 0 )
    {
      strcpy (cp, newprefix);
      if ( (data = Tcl_CreateHashEntry(&hdcprefixes, (char *)type, &status)) != 0 )
        Tcl_SetHashValue(data, (ClientData)cp);
    }    
  }

  if ( (data = Tcl_FindHashEntry(&hdcprefixes, (char *)type)) != 0 )
    prefix = (const char *)Tcl_GetHashValue(data);
  else
    prefix = "hdc";

  Tcl_SetResult(interp, (char *)prefix, TCL_STATIC);
  return TCL_OK;
}

static int HdcSet(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  Tcl_SetResult(interp, "Sorry, not implemented yet!", TCL_STATIC);
  return TCL_ERROR;
}

static int HdcVersion(ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  Tcl_AppendResult(interp, "hdc version: ", version_string, 0);
  return TCL_OK;
}

/****************************************************************
** Other internal functions
****************************************************************/
static void Hdc_names_init(void)
{
  static int initialized = 0;

  if ( !initialized )
  {
    initialized = 1;
    Tcl_InitHashTable(&hdcs, TCL_STRING_KEYS);           /* name will look up structure */
    Tcl_InitHashTable(&hdcprefixes, TCL_ONE_WORD_KEYS); /* Type will look up prefix */
  }
}

static void Hdc_names_delete(void)
{
  Tcl_HashEntry *ent;
  Tcl_HashSearch srch;
  void *val;
  
  for ( ent = Tcl_FirstHashEntry(&hdcs, &srch); ent !=0; ent=Tcl_NextHashEntry(&srch))
  {
    if ( (val = Tcl_GetHashValue(ent) ) != 0 )
      Tcl_Free(val);
  }
  Tcl_DeleteHashTable(&hdcs);

  for ( ent = Tcl_FirstHashEntry(&hdcprefixes, &srch); ent !=0; 
        ent=Tcl_NextHashEntry(&srch))
  {
    if ( (val = Tcl_GetHashValue(ent) ) != 0 )
      Tcl_Free(val);
  }
  Tcl_DeleteHashTable(&hdcprefixes);
}

static const char *Hdc_build_name(int type)
{
  const char *prefix;
  Tcl_HashEntry *data;
  int status;
  
  if ( (data = Tcl_FindHashEntry(&hdcprefixes, (char *)type)) != 0 )
    prefix = (const char *)Tcl_GetHashValue(data);
  else
  {
    char *cp;
    prefix = "hdc";
    if ( (cp = (char *)Tcl_Alloc(4)) != 0 )
    {
      strcpy (cp, prefix);
      if ( (data = Tcl_CreateHashEntry(&hdcprefixes, (char *)type, &status)) != 0 )
        Tcl_SetHashValue(data, (ClientData)cp);
    }
  }

  sprintf(hdc_name, "%s%ld", prefix, ++hdc_count);
  return hdc_name;
}

/****************************************************************
** This function is intended to provide a way to load the functions
** within the HDC package without creating a "PATH" dependency on
** finding hdc.dll.
** Instead, the using application will "package require hdc",
** and then issue "hdc FunctionVector", and interpret the
** result as pointers to functions in a given order
** (NB: would it be better to output pairs (name/pointer) to make
** the order irrelevant or would that just add to the confusion?)
****************************************************************/
static int HdcFunctionVector (ClientData data, Tcl_Interp *interp, int argc, char **argv)
{
  char buffer[4096]; /* Plenty big */
  /* Order of output:
  ** Hdc_Create
  ** Hdc_Delete
  ** Hdc_Get
  ** Hdc_TypeOf
  ** Hdc_PrefixOf
  ** Hdc_List
  ** Hdc_Valid
  */
  sprintf(buffer, "0x%lx 0x%lx 0x%lx 0x%lx 0x%lx 0x%lx 0x%lx",
          (PTR_LIKE_INT)Hdc_Create,
          (PTR_LIKE_INT)Hdc_Delete,
          (PTR_LIKE_INT)Hdc_Get,
          (PTR_LIKE_INT)Hdc_TypeOf,
          (PTR_LIKE_INT)Hdc_PrefixOf,
          (PTR_LIKE_INT)Hdc_List,
          (PTR_LIKE_INT)Hdc_Valid);
  Tcl_SetResult(interp, buffer, TCL_VOLATILE);
  return TCL_OK;
}

