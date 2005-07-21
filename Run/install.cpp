#include <stdio.h>
#include <string.h>
#include <time.h>
#include <openssl/md5.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN
#include <dllcalls.h>

HKEY Key;

int right_license(char* name, char* code) {
	char buffer[256];
	unsigned char md[MD5_DIGEST_LENGTH];
	/* String to use as secret */
	char secret[] = "R^6tf*Y}@?>H(U(ddJ(::{><Lu8H*G";
	#ifdef SIM_EVALUATION
	char edition[]="evaluation";
	#endif
	#ifdef SIM_TEACHING
	char edition[]="teaching";
	#endif
	#ifdef SIM_STANDARD
	char edition[]="standard";
	#endif
	#ifdef SIM_ENTERPRISE
	char edition[]="enterprise";
	#endif

	sprintf(buffer, "%s%%%s^%s", name, edition, secret);
	MD5((const unsigned char *)buffer, strlen(buffer), md);

	int i;
	static char buf[80];

	for (i=0; i<MD5_DIGEST_LENGTH; i++)
		sprintf(&(buf[i*2]),"%02x",md[i]);
	return(!strcmp(buf, code));
}

// prototype, __stdcall seems to need one 
FINDABLE EXPORT int __stdcall license_check(
		HWND, HWND, const char*, char*,
		char*, char*, char*, char*);

// Test for abort behaviour
FINDABLE EXPORT int __stdcall license_check(
		HWND MainHandle, HWND DialogHandle,
		const char* pInstallDir, char* pSupportDir,
		char* pUser, char* pCompany, char* pSerial,
		char* pAdditionsl) {
	char buffer[256];
#ifdef SIM_LICENSED
	if (!right_license(pUser, pSerial)) {
        	MessageBox (NULL, "You have entered the wrong license code for your name, organization and Simile version. This installation will now terminate. Please try again, ensuring you have the correct license code.", "Feedback", MB_OK);
		return(0);
	}
#endif
	if (RegCreateKeyEx(HKEY_LOCAL_MACHINE, 
			   "Software\\Simulistics\\Simile", 0, NULL, 
			   REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, 
			   NULL, &Key, NULL)==0) {
	    if (pUser != NULL) RegSetValueEx(Key, "licensee_name", 0, REG_SZ, (CONST BYTE*)pUser, strlen(pUser)+1);
	    if (pCompany != NULL) RegSetValueEx(Key, "licensee_corp", 0, REG_SZ, (CONST BYTE*)pCompany, strlen(pCompany)+1);
	    if (pSerial != NULL) RegSetValueEx(Key, "license_code", 0, REG_SZ, (CONST BYTE*)pSerial, strlen(pSerial)+1);

	    struct tm unixdawn;
	    time_t now;
	    unixdawn.tm_year=1970-1900;
	    unixdawn.tm_mon=0;
	    unixdawn.tm_mday=1;
	    unixdawn.tm_hour=0;
	    unixdawn.tm_min=0;
	    unixdawn.tm_sec=0;
	    unixdawn.tm_isdst=0;
	    now=time(NULL);
	    sprintf(buffer, "%ld :: %s", 
		(long)difftime(now,mktime(&unixdawn)), ctime(&now));
	    RegSetValueEx(Key, "install_time", 0, REG_SZ, (CONST BYTE*)buffer, strlen(pSerial)+1);
	    RegCloseKey(Key);
	    return(1);
	} else {
	    MessageBox (NULL, "The bloody thing has failed to get a key for writing the registry. You might as well go home...", "Feedback", MB_OK);
	    return(0);
	}
}

