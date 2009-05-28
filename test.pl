use Win32::Process;
use Win32::Process::CpuUsage;

my $i = 0;

while($i < 3){
	$i++;
	my $usage = Win32::Process::CpuUsage::GetSystemCpuUsage(1000);
	print "$i: cpu usage $usage\n";
}

#int GetPidCommandLine(int pid, char* cmdParameter)
my ($str, $pid);

$txtFile = "t/Win32-Process-CpuUsage.t";
$notepad = $ENV{'SystemRoot'} . "\\system32\\notepad.exe";

if(-e $txtFile){
	#start notepad.exe boot.ini
	Win32::Process::Create($gProcessObj,
	"$notepad",
	"$notepad $txtFile",
	0,
	NORMAL_PRIORITY_CLASS,
	"." ) ;

	$pid = $gProcessObj->GetProcessID();
	$exitCode = $gProcessObj->GetExitCode($exitCode);
	print "  notepad.exe started with pid $pid\n";

	sleep 1;
	$rs  = Win32::Process::CpuUsage::GetPidCommandLine($pid, $str);

	print "  return code is the length of command line (include \\0) : $rs\n  command line of pid $pid: $str\n" ;

	print  (($str =~ /Win32-Process-CpuUsage/) ? 'ok' : 'fail');

	print "\nprcCPU \t sysCPU\n" ;	
	$usage = Win32::Process::CpuUsage::GetProcessCpuUsage($pid, 1000, 3, $prcCPU, $sysCPU);
	print "  $prcCPU    $sysCPU\n" ;
	print  ($usage == 0 ? 'ok' : 'fail');

	$gProcessObj->Kill(8);
}
