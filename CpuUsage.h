int
GetPidCommandLine(	int pid,
					SV* cmdParameter
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
