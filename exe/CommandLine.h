int
GetPidCommandLine(	int pid,
					char* cmdParameter
					);

int 
GetProcessCpuUsage(	unsigned long dwId, 
					int intvlTime, 
					int counts, 
					int* prcCPU, 
					int* sysCPU
					);