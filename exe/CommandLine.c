// CommandLine.cpp : Defines the entry point for the DLL application.
//
// /DWIN32 /DNDEBUG /D_CONSOLE /D_MBCS
//
#include "stdafx.h"
#include "commandline.h"

#define ProcessBasicInformation 0
#define BUF_SIZE 512

typedef struct
{
    USHORT Length;
    USHORT MaximumLength;
    PWSTR  Buffer;
} UNICODE_STRING, *PUNICODE_STRING;

typedef struct
{
    ULONG          AllocationSize;
    ULONG          ActualSize;
    ULONG          Flags;
    ULONG          Unknown1;
    UNICODE_STRING Unknown2;
    HANDLE         InputHandle;
    HANDLE         OutputHandle;
    HANDLE         ErrorHandle;
    UNICODE_STRING CurrentDirectory;
    HANDLE         CurrentDirectoryHandle;
    UNICODE_STRING SearchPaths;
    UNICODE_STRING ApplicationName;
    UNICODE_STRING CommandLine;
    PVOID          EnvironmentBlock;
    ULONG          Unknown[9];
    UNICODE_STRING Unknown3;
    UNICODE_STRING Unknown4;
    UNICODE_STRING Unknown5;
    UNICODE_STRING Unknown6;
} PROCESS_PARAMETERS, *PPROCESS_PARAMETERS;

typedef struct
{
    ULONG               AllocationSize;
    ULONG               Unknown1;
    HINSTANCE           ProcessHinstance;
    PVOID               ListDlls;
    PPROCESS_PARAMETERS ProcessParameters;
    ULONG               Unknown2;
    HANDLE              Heap;
} PEB, *PPEB;

typedef struct
{
    DWORD ExitStatus;
    PPEB  PebBaseAddress;
    DWORD AffinityMask;
    DWORD BasePriority;
    ULONG UniqueProcessId;
    ULONG InheritedFromUniqueProcessId;
}   PROCESS_BASIC_INFORMATION;

typedef LONG (WINAPI *PROCNTQSIP)(HANDLE,UINT,PVOID,ULONG,PULONG);

PROCNTQSIP NtQueryInformationProcess;

BOOL GetProcessCmdLine(DWORD dwId,LPWSTR wBuf,DWORD dwBufLen);

// for process time
FILETIME   ftCreation, ftExit, ftKernel, ftUser;
SYSTEMTIME stKernel, stUser, stUTC, stLocal;
ULARGE_INTEGER span;

int GetPidCommandLine(int pid, char* cmdParameter){
	int    dwBufLen = BUF_SIZE*2;
	WCHAR  wstr[BUF_SIZE]   = {'\0'};
	char   mbch[BUF_SIZE*2] = {'\0'};
	DWORD  nOut, dwMinSize;
	HANDLE hOut;
	
    //printf("  Call GetPidCommandLine, pid: %i, %i\n", pid, dwBufLen);

    NtQueryInformationProcess = (PROCNTQSIP)GetProcAddress(
                                            GetModuleHandle("ntdll"),
                                            "NtQueryInformationProcess"
                                            );
    if (!NtQueryInformationProcess){ return -1;}

    if (! GetProcessCmdLine(pid, wstr, dwBufLen)){
		cmdParameter = '\0';

		#ifdef _DEBUG
	    printf("  Error: cannot get %i's command line string\n", pid);
		#endif
		return 0;
	}else
		#ifdef _DEBUG
	    wprintf(L"  %i's unicode command line string: %d byte %s\n", pid, wcslen(wstr), wstr);
		#endif

		//count the byte number for second call, dwMinSize is length
		dwMinSize = WideCharToMultiByte(CP_OEMCP, 0, wstr, -1, NULL, 0, NULL, NULL);
		
		//convert utf16 to multibyte and save to mbch
		dwMinSize = WideCharToMultiByte(CP_OEMCP, 0, (PWSTR)wstr, -1, mbch, dwMinSize, NULL, NULL);

#ifdef _DEBUG
		//write the utf16 string to a file
		hOut = CreateFile("_pidCmdLine.txt", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
		if (hOut == INVALID_HANDLE_VALUE) {
			printf ("Cannot open output file. Error: %x\n", GetLastError ());
			return -1;
		}

		//make sure no over buffer
		if(wcslen(wstr) < BUF_SIZE){
			if(WriteFile (hOut, wstr, wcslen(wstr) * 2, &nOut, NULL)){
				printf("\n  write %i byte to _pidCmdLine.txt that is in unicode\n", nOut);
			}
		}
		CloseHandle (hOut);
#endif

		//copy to return buffer
		strncpy(cmdParameter, mbch, dwMinSize);

		#ifdef _DEBUG
		printf("  convert unicode to MB string: %s \n", mbch);
		#endif

		return dwMinSize;
}

BOOL GetProcessCmdLine(DWORD dwId,LPWSTR wBuf,DWORD dwBufLen)
{
    LONG                      status;
    HANDLE                    hProcess;
    PROCESS_BASIC_INFORMATION pbi;
    PEB                       Peb;
    PROCESS_PARAMETERS        ProcParam;
    DWORD                     dwDummy;
    DWORD                     dwSize;
    LPVOID                    lpAddress;
    BOOL                      bRet  = FALSE;
	BOOL					  bTime = FALSE;
    // Get process handle
    hProcess = OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ,FALSE,dwId);
    if (!hProcess)
       return FALSE;

	if (GetProcessTimes(hProcess, &ftCreation, &ftExit, &ftKernel, &ftUser) == TRUE){

		//bTime = FileTimeToLocalFileTime(&ftCreation, &stUTC);
		//bTime = SystemTimeToTzSpecificLocalTime(NULL, &stUTC, &stLocal);
		bTime = FileTimeToSystemTime(&ftCreation, &stUTC);
		if (! bTime) goto cleanup;

		GetSystemTime(&stLocal);
		
		//span = stLocal - ftCreation;
		printf("%s\n",  "get time");
		
	}
    // Retrieve information
    status = NtQueryInformationProcess( hProcess,
                                        ProcessBasicInformation,
                                        (PVOID)&pbi,
                                        sizeof(PROCESS_BASIC_INFORMATION),
                                        NULL
                                      );


    if (status)
       goto cleanup;

    if (!ReadProcessMemory( hProcess,
                            pbi.PebBaseAddress,
                            &Peb,
                            sizeof(PEB),
                            &dwDummy
                          )
       )
       goto cleanup;

    if (!ReadProcessMemory( hProcess,
                            Peb.ProcessParameters,
                            &ProcParam,
                            sizeof(PROCESS_PARAMETERS),
                            &dwDummy
                          )
       )
       goto cleanup;

    lpAddress = ProcParam.CommandLine.Buffer;
    dwSize = ProcParam.CommandLine.Length;

    if (dwBufLen<dwSize)
       goto cleanup;

    if (!ReadProcessMemory( hProcess,
                            lpAddress,
                            wBuf,
                            dwSize,
                            &dwDummy
                          )
       )
       goto cleanup;


    bRet = TRUE;

cleanup:

    CloseHandle (hProcess);


    return bRet;
}

__int64 CalcFileTime ( FILETIME time1, FILETIME time2 )
{
	__int64 a = time1.dwHighDateTime << 32 | time1.dwLowDateTime ;
	__int64 b = time2.dwHighDateTime << 32 | time2.dwLowDateTime ;
	return   (b - a);
}

int GetProcessCpuUsage(unsigned long dwId, int intvlTime, int counts, int* prcCPU, int* sysCPU)
{
    BOOL	rst = FALSE;
    HANDLE	hProcess=0;
	SYSTEMTIME st;
	int	iCtl =0;
	double pctSys, pctPrc;
	__int64 dwProcessTime, dwPrcKTime, dwPrcUTime, dwSysIdle, dwSysKrnl, dwSysUser;

	FILETIME pftCreation, pftExit, ft;

	//for process times, previous and current
	FILETIME pftKernel, pftUser, cftKernel, cftUser;

	//for system  times
	FILETIME pStIdle, pStKernel, pStUser;
	FILETIME cStIdle, cStKernel, cStUser;
 
	//PROCESS_MEMORY_COUNTERS pmc;
	//====================

	// Get process handle
    hProcess = OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ, FALSE, dwId);
    if (!hProcess) return -1;

	GetSystemTime(&st);              // gets current time
	SystemTimeToFileTime(&st, &ft);  // converts to file time format

	// for the first time
	if (GetProcessTimes(hProcess, &pftCreation, &pftExit, &pftKernel, &pftUser) == FALSE ) return -1;
	if (GetSystemTimes(&pStIdle,  &pStKernel,   &pStUser) == FALSE ) return -1;
	//hEvent = CreateEvent (NULL,FALSE,FALSE,NULL); 

	/* if ( GetProcessMemoryInfo( hProcess, &pmc, sizeof(pmc)) )    {
        printf( "\tPageFaultCount: 0x%08X\n", pmc.PageFaultCount );
        printf( "\tPeakWorkingSetSize: 0x%08X\n",  pmc.PeakWorkingSetSize );
        printf( "\tWorkingSetSize: 0x%08X\n", pmc.WorkingSetSize );
        printf( "\tQuotaPeakPagedPoolUsage: 0x%08X\n",  pmc.QuotaPeakPagedPoolUsage );
        printf( "\tQuotaPagedPoolUsage: 0x%08X\n",      pmc.QuotaPagedPoolUsage );
        printf( "\tQuotaPeakNonPagedPoolUsage: 0x%08X\n",  pmc.QuotaPeakNonPagedPoolUsage );
        printf( "\tQuotaNonPagedPoolUsage: 0x%08X\n",  pmc.QuotaNonPagedPoolUsage );
        printf( "\tPagefileUsage: 0x%08X\n", pmc.PagefileUsage ); 
        printf( "\tPeakPagefileUsage: 0x%08X\n",  pmc.PeakPagefileUsage );
    } */

	while(1){
		Sleep(intvlTime);	// wait miliseconds second

		if (GetProcessTimes(hProcess, &pftCreation, &pftExit, &cftKernel, &cftUser) == FALSE ) return -1;
		dwPrcKTime = CalcFileTime(pftKernel, cftKernel);
		dwPrcUTime = CalcFileTime(pftUser, cftUser);
		dwProcessTime = dwPrcKTime + dwPrcUTime;

		if (GetSystemTimes(&cStIdle, &cStKernel, &cStUser) == FALSE ) return -1;
		dwSysIdle = CalcFileTime(pStIdle,   cStIdle);
		dwSysKrnl = CalcFileTime(pStKernel, cStKernel);
		dwSysUser = CalcFileTime(pStUser,   cStUser);

		pctSys = (dwSysKrnl + dwSysUser - dwSysIdle) * 100.0 / ( dwSysKrnl + dwSysUser) + 0.5;
		pctPrc = dwProcessTime * 100.0 / ( dwSysKrnl + dwSysUser) + 0.5;

		*sysCPU = (int)pctSys;
		*prcCPU = (int)pctPrc;
		printf("%3d%% %3d%% \n", *prcCPU, *sysCPU);

		pftKernel = cftKernel;
		pftUser	  = cftUser;

		pStIdle   = cStIdle;
		pStKernel = cStKernel;
		pStUser	  = cStUser;

		if( ++iCtl >= counts){
			return 0;
			CloseHandle( hProcess );
		}
	}
}

//#ifdef TESTING
int main(int argc, char** argv){
	int	  nByte=0, pid, prcCPU, sysCPU;
	char  mbch[BUF_SIZE*2] = {'\0'};

	if(argc < 2 ) return 1;

	sscanf(argv[1], "%lu" ,&pid);
	//nByte = GetPidCommandLine(pid, mbch);
	//printf("\n  total %i byte, mbch length %d, %s\n", nByte, strlen(mbch), mbch);

	//int GetProcessCpuUsage(DWORD dwId, int intvlTime, int counts, int* prcCPU, int* sysCPU)

	nByte = GetProcessCpuUsage(pid, 1150, 20, &prcCPU, &sysCPU);
	printf("  CPU Usage: %d %d\n", prcCPU, sysCPU);

	return 0;
}
//#endif
