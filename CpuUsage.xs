// for GetSystemTimes
#define _WIN32_WINNT 0x0501

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "stdafx.h"
#include <windows.h>
#include <stdio.h>

#include "CpuUsage.h"

#include "const-c.inc"

#define SystemBasicInformation			0
#define SystemPerformanceInformation	2
#define SystemTimeInformation			3
#define ProcessBasicInformation			0

#define Li2Double(x) ((double)((x).HighPart) * 4.294967296E9 + (double)((x).LowPart))

typedef struct
{
	  DWORD   dwUnknown1;
	  ULONG   uKeMaximumIncrement;
	  ULONG   uPageSize;
	  ULONG   uMmNumberOfPhysicalPages;
	  ULONG   uMmLowestPhysicalPage;
	  ULONG   uMmHighestPhysicalPage;
	  ULONG   uAllocationGranularity;
	  PVOID   pLowestUserAddress;
	  PVOID   pMmHighestUserAddress;
	  ULONG   uKeActiveProcessors;
	  BYTE    bKeNumberProcessors;
	  BYTE    bUnknown2;
	  WORD    wUnknown3;
} SYSTEM_BASIC_INFORMATION;

typedef struct
{
	  LARGE_INTEGER		liIdleTime;
	  DWORD				dwSpare[76];
} SYSTEM_PERFORMANCE_INFORMATION;

typedef struct
{
	  LARGE_INTEGER liKeBootTime;
	  LARGE_INTEGER liKeSystemTime;
	  LARGE_INTEGER liExpTimeZoneBias;
	  ULONG			  uCurrentTimeZoneId;
	  DWORD     dwReserved;
} SYSTEM_TIME_INFORMATION;

// ntdll!NtQuerySystemInformation (NT specific!)
//
// The function copies the system information of the
// specified type into a buffer
//
// NTSYSAPI
// NTSTATUS
// NTAPI
// NtQuerySystemInformation(
//   IN   UINT   SystemInformationClass,   // information type
//   OUT  PVOID  SystemInformation,        // pointer to buffer
//   IN   ULONG  SystemInformationLength,  // buffer size in bytes
//   OUT  PULONG ReturnLength OPTIONAL     // pointer to a 32-bit
//										   // variable that receives
//										   // the number of bytes
//										   // written to the buffer
// );
typedef LONG (WINAPI *PROCNTQSI)(UINT,PVOID,ULONG,PULONG);

PROCNTQSI NtQuerySystemInformation;

/*=====================*/

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

BOOL GetProcessCmdLine(DWORD dwId,LPWSTR *wBuf);

/*=====================*/

int GetPidCommandLine(int pid, SV* cmdParameter){
	DWORD dwMinSize;
#ifdef _DEBUG
	HANDLE hOut;
	DWORD  nOut;
#endif
	LPWSTR  wstr = 0;
	char   *mbch = 0;

    //printf("  Call GetPidCommandLine, pid: %i, %i\n", pid, dwBufLen);

    NtQueryInformationProcess = (PROCNTQSIP)GetProcAddress(
                                            GetModuleHandle("ntdll"),
                                            "NtQueryInformationProcess"
                                            );
    if (!NtQueryInformationProcess){ return -1;}

    if (! GetProcessCmdLine(pid, &wstr)){
		return -1;

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
		mbch = (char*) malloc(dwMinSize);
		if (!mbch) return -1;

		dwMinSize = WideCharToMultiByte(CP_OEMCP, 0, (PWSTR)wstr, -1, mbch, dwMinSize, NULL, NULL);

#ifdef _DEBUG
		//write the utf16 string to a file
		hOut = CreateFile("_pidCmdLine.txt", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
		if (hOut == INVALID_HANDLE_VALUE) {
			printf ("Cannot open output file. Error: %x\n", GetLastError ());
			return -1;
		}

		if(WriteFile (hOut, wstr, wcslen(wstr) * 2, &nOut, NULL)){
			printf("\n  write %i byte to _pidCmdLine.txt that is in unicode\n", nOut);
		}
		CloseHandle (hOut);
#endif

		#ifdef _DEBUG
		printf("  convert unicode to MB string: %s \n", mbch);
		#endif

		//copy to return buffer
		sv_setpv(cmdParameter, mbch);
		free(mbch);
		free(wstr);
		return dwMinSize;
}

BOOL GetProcessCmdLine(DWORD dwId, LPWSTR *wBuf)
{
    LONG                      status;
    HANDLE                    hProcess;
    PROCESS_BASIC_INFORMATION pbi;
    PEB                       Peb;
    PROCESS_PARAMETERS        ProcParam;
    DWORD                     dwDummy;
    DWORD                     dwSize;
    LPVOID                    lpAddress;
    BOOL                      bRet = FALSE;
	*wBuf = 0;

    // Get process handle
    hProcess = OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ,FALSE,dwId);
    if (!hProcess)
       return FALSE;

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
	// Add two bytes for the nulls (unicode character is 2 bytes, i think).
	*wBuf = (LPWSTR)malloc(dwSize+2);

    if (!*wBuf)
       goto cleanup;
    /* write command line into wBuf */
    if (!ReadProcessMemory( hProcess,
                            lpAddress,
                            *wBuf,
                            dwSize,
                            &dwDummy
                          )
       )
       goto cleanup;
    ((char*)(*wBuf))[dwSize] = '\0';
    ((char*)(*wBuf))[dwSize+1] = '\0';
    bRet = TRUE;

cleanup:

    CloseHandle (hProcess);


    return bRet;
}
/*=====================*/

int GetSystemCpuUsage(int interval)
{
	SYSTEM_PERFORMANCE_INFORMATION	SysPerfInfo;
	SYSTEM_TIME_INFORMATION			SysTimeInfo;
	SYSTEM_BASIC_INFORMATION		SysBaseInfo;
	double				dbIdleTime;
	double				dbSystemTime;
	LONG				status;
	LARGE_INTEGER		liOldIdleTime = {0,0};
	LARGE_INTEGER		liOldSystemTime = {0,0};

	int iCtl=0, percentage=0;

	NtQuerySystemInformation = (PROCNTQSI)GetProcAddress(
								GetModuleHandle("ntdll"),
								"NtQuerySystemInformation"
								);
	if(!NtQuerySystemInformation)
	return -1;

	// get number of processors in the system
	status = NtQuerySystemInformation(SystemBasicInformation,&SysBaseInfo,sizeof(SysBaseInfo),NULL);
	if(status != NO_ERROR)
	return -1;

	//printf("\n getting CPU Usage\n");
	//while(!_kbhit())

	while(1)
	{
		// get new system time
		status = NtQuerySystemInformation(SystemTimeInformation,&SysTimeInfo,sizeof(SysTimeInfo),0);
		if(status!=NO_ERROR)
		return -1;

		// get new CPU's idle time
		status = NtQuerySystemInformation(SystemPerformanceInformation,&SysPerfInfo,sizeof(SysPerfInfo),NULL);
		if(status != NO_ERROR)
		return -1;

		// if it's a first call - skip it
		if(liOldIdleTime.QuadPart != 0)
		{
			// CurrentValue = NewValue - OldValue
			dbIdleTime   = Li2Double(SysPerfInfo.liIdleTime)     - Li2Double(liOldIdleTime);
			dbSystemTime = Li2Double(SysTimeInfo.liKeSystemTime) - Li2Double(liOldSystemTime);

			// CurrentCpuIdle = IdleTime / SystemTime
			dbIdleTime = dbIdleTime / dbSystemTime;

			// CurrentCpuUsage% = 100 - (CurrentCpuIdle * 100) / NumberOfProcessors
			dbIdleTime = 100.0 - dbIdleTime * 100.0 / (double)SysBaseInfo.bKeNumberProcessors + 0.5;

			//+ 0.5, result is same in task manager
			percentage= (UINT)(dbIdleTime);

			//printf("\b\b\b\b%3d%%", percentage);
			if(iCtl > 0 ) return percentage;
		}

		// store new CPU's idle and system time
		liOldIdleTime   = SysPerfInfo.liIdleTime;
		liOldSystemTime = SysTimeInfo.liKeSystemTime;

		// wait one second
		Sleep(interval);
		iCtl++;
	}
	return 0;
}

/*=====================*/

__int64 CalcFileTime ( FILETIME time1, FILETIME time2 )
{
	__int64 a = time1.dwHighDateTime << 32 | time1.dwLowDateTime ;
	__int64 b = time2.dwHighDateTime << 32 | time2.dwLowDateTime ;
	return   (b - a);
}

int _GetProcessCpuUsage(unsigned long dwId, int intvlTime, int counts, int* prcCPU, int* sysCPU)
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


MODULE = Win32::Process::CpuUsage		PACKAGE = Win32::Process::CpuUsage

INCLUDE: const-xs.inc

int
GetSystemCpuUsage(interval)
INPUT:
	int interval
CODE:
	RETVAL 	= GetSystemCpuUsage(interval);
OUTPUT:
	RETVAL


int
GetProcessCpuUsage(dwId, intvlTime, counts, prcCPU, sysCPU)
	unsigned long dwId
	int intvlTime
	int counts
	SV* prcCPU
	SV* sysCPU
INIT:
	int prc;
	int sys;
CODE:
	prc = -1;
	sys = -1;

	RETVAL = _GetProcessCpuUsage(dwId, intvlTime, counts, &prc, &sys);
	//printf("%d\n", prc);
	//printf("%d\n", sys);

	sv_setiv(prcCPU, prc);
	sv_setiv(sysCPU, sys);
OUTPUT:
	RETVAL
	prcCPU
	sysCPU


int
GetPidCommandLine(pid, cmdParameter)
	int pid
	SV* cmdParameter
CODE:
    sv_setsv(cmdParameter, newSV(0));
	RETVAL 	= GetPidCommandLine(pid, cmdParameter);
OUTPUT:
	cmdParameter
	RETVAL
