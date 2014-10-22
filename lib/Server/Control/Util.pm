package Server::Control::Util;
use IO::Socket;
use Proc::Killfam;
use Proc::ProcessTable;
use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(
  trim
  is_port_active
  process_listening_to_port
  something_is_listening_msg
  kill_my_children
);

eval { require Unix::Lsof };
my $have_lsof = $Unix::Lsof::VERSION;

sub trim {
    my ($str) = @_;

    for ($str) { s/^\s+//; s/\s+$// }
    return $str;
}

# Return boolean indicating whether $port:$bind_addr is active
#
sub is_port_active {
    my ( $port, $bind_addr ) = @_;

    return IO::Socket::INET->new(
        PeerAddr => $bind_addr,
        PeerPort => $port
    ) ? 1 : 0;
}

# Return the Proc::ProcessTable::Process that is listening to $port and
# $bind_addr. Return undef if no process is listening or we cannot determine
# the process
#
sub process_listening_to_port {
    my ( $port, $bind_addr ) = @_;

    return undef unless $have_lsof;
    $bind_addr = defined($bind_addr) ? "(?:$bind_addr|\\*)" : '.*';
    if ( my $lr = eval { Unix::Lsof::lsof( "-P", "-i", "TCP" ) } ) {
        if (
            my ($row) =
            grep { $_->[1] =~ /^$bind_addr:$port$/ && $_->[2] =~ /^IP/ }
            $lr->get_arrayof_rows( "process id", "file name", "file type" )
          )
        {
            my $pid    = $row->[0];
            my $ptable = new Proc::ProcessTable();
            if ( my ($proc) = grep { $_->pid == $pid } @{ $ptable->table } ) {
                return $proc;
            }
        }
    }
    return undef;
}

# Return a message like "something is listening to foo:1234", with a
# qualifier about which process is listening if we can determine that
#
sub something_is_listening_msg {
    my ( $port, $bind_addr ) = @_;

    my $proc = process_listening_to_port( $port, $bind_addr );
    my $qualifier =
      $proc
      ? sprintf( ' (possibly pid %d - "%s")', $proc->pid, $proc->cmndline )
      : "";
    sprintf( "something%s is listening to %s:%d",
        $qualifier, $bind_addr, $port );
}

# Kill all children of this process - for test cleanup.  NOTE: Doesn't work
# with apache and other servers that end up with ppid=1
#
sub kill_my_children {
    my $pt = new Proc::ProcessTable;
    if ( my @child_pids = Proc::Killfam::get_pids( $pt->table, $$ ) ) {
        if ( $ENV{TEST_VERBOSE} ) {
            printf STDERR "sending TERM to %s\n", join( ", ", @child_pids );
        }
        Proc::Killfam::killfam( 15, @child_pids );
    }
}

1;
