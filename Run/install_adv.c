/*
 * Copyright 2004 Caphyon LTD. All rights reserved.
 *
 * mailto: eng@caphyon.com
 * http://www.caphyon.com
 *
 */

// Serial Validation DLL.cpp : Defines the entry point for the DLL application.
//

#include <stdio.h>
#include <openssl/md5.h>
#define WIN32_LEAN_AND_MEAN		// Exclude rarely-used stuff from Windows headers
// Windows Header Files:

#include <windows.h>
#include <msi.h>
#include <msiquery.h>
#include <tchar.h>
#undef WIN32_LEAN_AND_MEAN

#define PIDKEY_LENGTH 100

/* This currently causes multiple definition error in libcrypto.a
BOOL WINAPI DllMain(HINSTANCE hModule, DWORD ul_reason_for_call,
                      LPVOID lpReserved)
{
  return TRUE;
}
*/
#ifndef _DEBUG
BOOL WINAPI __DllMainCRTStartup(HINSTANCE hModule, DWORD ul_reason_for_call,
                                LPVOID lpReserved)
{
  return DllMain(hModule, ul_reason_for_call, lpReserved);
}
#endif

int right_license(char* name, char* code) {
  char buffer[256];
  unsigned char md[MD5_DIGEST_LENGTH];
  /* String to use as secret */
  char secret[] = {79,84,70,75,38,105,124,88,51,54,105,71,102,41,110,126,96,94,112,49,57,85,71,96,47,114,38,48,83,49,71,0};
  char editions[][12] = {"teaching", "standard", "enterprise"};
  int count;
  
  if (!strcmp(code, "     -      (not required for evaluation edition)"))
    return 0; // nothing entered -- evaluation edition
  for (count=0; count<=3; ++count) {
    sprintf(buffer, "%s%%%s^%s", name, editions[count], secret);
    MD5((const unsigned char *)buffer, strlen(buffer), md);
    
    int i;
    static char buf[80];
    
    for (i=0; i<MD5_DIGEST_LENGTH; i++)
      sprintf(&(buf[i*2]),"%02x",md[i]);
    if (!strncmp(buf, code, 5) && !strncmp(buf+5, code+6, 5))
      return count+1;
  }
  return -1;
}

UINT __stdcall ValidateSerial_Sample(MSIHANDLE hInstall)
{
  TCHAR szUserName[PIDKEY_LENGTH];
  TCHAR szPidKey[PIDKEY_LENGTH];
  DWORD dwLen = sizeof(szPidKey) / sizeof(szPidKey[0]);

  ///retrieve the text entered by the user
  UINT res = MsiGetProperty(hInstall, _T("USERNAME"), szUserName, &dwLen);
  if(res != ERROR_SUCCESS)
  {
    //fail the installation
    return 1;
  }
  dwLen = sizeof(szPidKey) / sizeof(szPidKey[0]); // was overwritten, so reset
  res = MsiGetProperty(hInstall, _T("PIDKEY"), szPidKey, &dwLen);
  if(res != ERROR_SUCCESS)
  {
    //fail the installation
    return 1;
  }

  int snIsValid =  right_license(szUserName, szPidKey);
  TCHAR * serialValid = NULL;
  if (snIsValid >= 0)
    serialValid = _T("TRUE"); 
  else
  {
    //eventually say something to the user
    char explain[1023];
    sprintf(explain, "%.11s is not a valid serial number for %s\n",
	    szPidKey, szUserName);
    MessageBox(GetForegroundWindow(), _T(explain), 
		 _T("Message"), MB_ICONSTOP);

    serialValid = _T("FALSE");
  }

  res = MsiSetProperty(hInstall, _T("SERIAL_VALIDATION"), serialValid);
  if(res != ERROR_SUCCESS)
  {
    //fail the installation
    return 1;
  }

  //the validation succeeded - even the serial is wrong
  //if the SERIAL_VALIDATION was set to FALSE the installation will not continue

  // set key to trimmed version to write to file
  // -- causes problems in installer so fix file contents later
  // res = ::MsiSetProperty(hInstall, _T("PIDKEY"), _T(szPidKey));
  return 0;
}
