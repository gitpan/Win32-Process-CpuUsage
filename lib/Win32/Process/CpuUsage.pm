package Win32::Process::CpuUsage;

use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Win32::Process::CpuUsage ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.02';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Win32::Process::CpuUsage::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Win32::Process::CpuUsage', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Win32::Process::CpuUsage - Perl extension for getting a Windows process's CPU usage

=head1 SYNOPSIS

  use Win32::Process::CpuUsage;

  ($pid, $interval, $counts) = (4800, 1000, 3);

  $rs = Win32::Process::CpuUsage::GetProcessCpuUsage($pid, $interval, $counts, $prcCPU, $sysCPU);

  $rs = Win32::Process::CpuUsage::GetPidCommandLine($pid, $str);

  $usage = Win32::Process::CpuUsage::GetSystemCpuUsage($interval);

=head1 DESCRIPTION

This module is designed to constantly monitor a Windows process's CPU usage and system CPU usage. 
And it has some merged methods from other 2 modules. You can find out more about how the CPU
usage percentage computed from http://www.codeproject.com/KB/threads/Get_CPU_Usage.aspx.

=head1 METHODS

=head2 Win32::Process::CpuUsage::GetProcessCpuUsage($pid, $interval, $counts, $prcCPU, $sysCPU)

This method calculates the CPU usage based on process ID and time interval. The CPU usage means that within the specified
time, for example 1000 milliseconds, how much CPU time is used by the process and system. The values of CPU usage are printed
in DOS prompt for each calculation. The first value is the process CPU usage; the second one is system CPU usage.
The values in last calculation are returned to variables, $prcCPU and $sysCPU.

If the method is called successfully, the return value is 0, otherwise it is -1.

=over 4

=item * pid

Process ID

=item * interval

Time interval in millisecond is for how often the CPU usage is calculated. 1000 means 1 second.

=item * counts

Specify how many times to calculate the CPU Usage

=item * prcCPU

The process CPU usage in last calculation is returned to $prcCPU.

=item * sysCPU

The system CPU usage in last calculation is returned to $sysCPU.

=back

=head2 Win32::Process::CpuUsage::GetPidCommandLine($pid, $str)

Same method in Win32::Process::CommandLine. Please see details in that module.

=head2 Win32::Process::CpuUsage::GetSystemCpuUsage($interval)

Same as method "getCpuUsage" in Win32::SystemInfo::CpuUsage. Please see details in that module.

=head1 SEE ALSO

L<Win32::Process::CommandLine>

L<Win32::SystemInfo::CpuUsage>

=head1 AUTHOR

Jing Kang <kxj@cpan.org>

=cut