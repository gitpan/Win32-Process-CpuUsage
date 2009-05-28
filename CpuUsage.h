int
GetPidCommandLine(	int pid,
					char* cmdParameter
					);

int
GetProcessCpuUsage(	unsigned long dwId,
					int intvlTime,
					int counts,
					SV* prcCPU,
					SV* sysCPU
					);

int
GetSystemCpuUsage( int interval
					);
