#include <stdio.h>
#include <string.h>
#include <time.h>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN
#include <dllcalls.h>

// prototype, __stdcall seems to need one 
FINDABLE int __stdcall info_copy(
		HWND, HWND, const char*, char*,
		char*, char*, char*, char*);

// This writes a wee file with the supplied user name and company, and our own version
// number. It is called from the installation procedure.

FINDABLE int __stdcall info_copy(
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

