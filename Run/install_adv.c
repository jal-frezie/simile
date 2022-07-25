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
#include <string.h>
#include <stdlib.h>
#include "sha-256.h"

#define PIDKEY_LENGTH 256

/* This currently causes multiple definition error in libcrypto.a
BOOL WINAPI DllMain(HINSTANCE hModule, DWORD ul_reason_for_call,
                      LPVOID lpReserved)
{
  return TRUE;
}
*/

int my_hmac2(char* digest, const char* key, const char* text) {
  char* k_ipad;
  char k_opad[128];

  k_ipad = (char*)malloc(strlen(text)+80);
  int count;
  for (count=strlen(key)-1; count>=0; count--) {
    k_ipad[count]=key[count]^0x36;
    k_opad[count]=key[count]^0x5c;
  }
  for (count=strlen(key); count<64; count++) {
    k_ipad[count]=0x36;
    k_opad[count]=0x5c;
  }

  strcpy(k_ipad+64, text);
  calc_sha_256(k_opad+64, k_ipad, strlen(text)+64);
  free(k_ipad);

  calc_sha_256(digest, k_opad, 64+SIZE_OF_SHA_256_HASH);
  return 0;
}
static const char *Base64Digits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

int Base64Encode(const char* pSrc, int nLenSrc, char* pDst, int nLenDst)
{
    int nLenOut = 0;

    while (nLenSrc > 0) {
        if (nLenDst < 4) return(0); // error

        // read up to three source bytes (24 bits) 
        int len = 0;
        char s1 = pSrc[len++];
        char s2 = (nLenSrc > 1) ? pSrc[len++] : 0;
        char s3 = (nLenSrc > 2) ? pSrc[len++] : 0;
        pSrc += len;
        nLenSrc -= len;

        //------------------ lookup the right digits for output
        pDst[0] = Base64Digits[(s1 >> 2) & 0x3F];
        pDst[1] = Base64Digits[(((s1 & 0x3) << 4) | ((s2 >> 4) & 0xF)) & 0x3F];
        pDst[2] = Base64Digits[(((s2 & 0xF) << 2) | ((s3 >> 6) & 0x3)) & 0x3F];
        pDst[3] = Base64Digits[s3 & 0x3F];

        //--------- end of input handling
        if (len < 3) {  // less than 24 src bits encoded, pad with '='
          pDst[3] = L'=';
          if (len == 1)
            pDst[2] = L'=';
        }

        nLenOut += 4;
        pDst += 4;
        nLenDst -= 4;
    }

    if (nLenDst > 0) *pDst = 0;

    return (nLenOut);
}

int right_license(const char* name, const char* code) {
  char buffer[256];
  unsigned char md[256];
  int count, len;

  /* String to use as secret */
  char secret[] = "Excel must die, lest the planet fry";
  char editions[][12] = {"teaching", "standard", "enterprise"};
  
  for (count=0; count<3; ++count) {
    len = sprintf(buffer, "%s%%%s", name, editions[count]);
    // method using libcrypto -- we don't need that any more
    //    HMAC(EVP_sha256(), secret, strlen(secret), buffer, len,
    //	 md, &len); // should read len before writing it!
    //    EVP_EncodeBlock(buffer, md, len); // convert to base64, reuse buffer

    my_hmac2(md, secret, buffer);
    Base64Encode(md, SIZE_OF_SHA_256_HASH, buffer, 256);
    if (!strncmp(buffer, code, 5) && !strncmp(buffer+16, code+6, 5))
      return count;
  }

  return -1;
}

#ifdef WIN32
#ifndef _DEBUG
/*
BOOL WINAPI __DllMainCRTStartup(HINSTANCE hModule, DWORD ul_reason_for_call,
                                LPVOID lpReserved)
{
  return DllMain(hModule, ul_reason_for_call, lpReserved);
}
*/
#endif

#ifndef _WIN64
#include <stringapiset.h>
#include <wchar.h>

#define WIN32_LEAN_AND_MEAN // Exclude rarely-used stuff from Windows headers
// Windows Header Files:
#include <windows.h>
#include <msi.h>
#include <msiquery.h>
#include <tchar.h>
#undef WIN32_LEAN_AND_MEAN

UINT __stdcall ValidateSerial_Sample(MSIHANDLE hInstall)
{
  TCHAR szUserName[PIDKEY_LENGTH];
  TCHAR szPidKey[PIDKEY_LENGTH];
  WCHAR convdName[PIDKEY_LENGTH];
  char trimmed[PIDKEY_LENGTH];
  DWORD dwLen = sizeof(szPidKey) / sizeof(szPidKey[0]);
  int snIsValid, count;

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

 if (!strcmp(szPidKey, "     -      (not required for evaluation edition)"))
    snIsValid = 0; // nothing entered -- evaluation edition
  else {
  // First we must convert this to utf-16 (Unicode wide chars) before carrying
  // out the check
    count = MultiByteToWideChar(CP_ACP, 0, szUserName, -1, convdName,
				PIDKEY_LENGTH);

    // next, emulate buggy Tcl behaviour
    //    for (count=0; count<=wcslen(convdName); ++count) {
    //      trimmed[count] = convdName[count] & 0xff;
    //    }
    // Bug is fixed as of v7 so just convert to utf-8 which is what
    // Tcl and PHP are using

    WideCharToMultiByte(CP_UTF8, 0, convdName, count, trimmed, PIDKEY_LENGTH,
			NULL, NULL);

    snIsValid =  right_license(trimmed, szPidKey);
  }
  TCHAR * serialValid = NULL;
  if (snIsValid >= 0)
    serialValid = _T("TRUE"); 
  else
  {
  //eventually say something to the user
    char explain[1023];
    sprintf(explain,
	    "%.11s is not a valid serial number for %s (%d %d %d %d %d %d)\n",
	    szPidKey, szUserName, (int)trimmed[0], (int)trimmed[1],
	    (int)trimmed[2], (int)trimmed[3], (int)trimmed[4], count);
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

UINT __stdcall SaveUserInfo_Sample(MSIHANDLE hInstall) {
  TCHAR szPidKey[PIDKEY_LENGTH];
  TCHAR *startPt, *brkPt;
  DWORD dwLen = sizeof(szPidKey) / sizeof(szPidKey[0]);
  FILE* pip;
  int part;

  ///retrieve the file location
  UINT res = MsiGetProperty(hInstall, _T("CustomActionData"), szPidKey,
			    &dwLen);
  brkPt = strchr(szPidKey, '|');
  *brkPt++ = 0;
  pip = fopen(szPidKey, "w");
  if (pip == NULL) {
    printf("Error opening file %s for writing", szPidKey);
    return 1;
  }
  fprintf(pip, "gnu\n");
  fprintf(pip, "pipe\n");
  fprintf(pip, "1275478189 :: Wed Jun 02 12:29:49 BST 2010\n");
  
  for (part=0; part<3; ++part) {
    startPt = brkPt;
    brkPt = strchr(startPt, '|');
    *brkPt++ = 0;
    fprintf(pip, "%s\n", startPt);
  }
  fprintf(pip, "%s\n", brkPt);
  // No final | so do not search again
  fclose(pip);
  return 0;
}
#endif
#endif
