#include <stdio.h>
#include <string.h>
#include <time.h>
#include <openssl/md5.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN
#include <dllcalls.h>

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
#ifdef SIM_LICENSED
	if (!right_license(pUser, pSerial)) {
        	MessageBox (NULL, "You have entered the wrong license code for your name, organization and Simile version. This installation will now terminate. Please try again, ensuring you have the correct license code.", "Feedback", MB_OK);
		return(0);
	}
#endif
	return(1);
}

// prototype, __stdcall seems to need one 
FINDABLE EXPORT int __stdcall info_copy(
		HWND, HWND, const char*, char*,
		char*, char*, char*, char*);

// This writes a wee file with the supplied user name and company, and our own version
// number. It is called from the installation procedure.

FINDABLE EXPORT int __stdcall info_copy(
		HWND MainHandle, HWND DialogHandle,
		const char* pInstallDir, char* pSupportDir,
		char* pUser, char* pCompany, char* pSerial,
		char* pAdditionsl) {
	char destfile[256];
	FILE *recept;

	strcpy(destfile, pInstallDir);
	strcat(destfile, "\\Run\\userinfo.txt");
	recept = fopen(destfile, "w");
	fputs("prolog=sicstus", recept);
	fputs("\n", recept);
	fputs("interface=pipe", recept);
	fputs("\n", recept);

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
	fprintf(recept, "installtime=%ld :: %s", 
		(long)difftime(now,mktime(&unixdawn)), ctime(&now));
	fprintf(recept, "license=%s\n", pSerial);

	fputs(pUser, recept);
	fputs("\n", recept);
	fputs(pCompany, recept);
	fputs("\n", recept);
	fputs(SIMILE_VERSION, recept);
	fputs("\n", recept);
	fclose(recept);
	return(1);
}
