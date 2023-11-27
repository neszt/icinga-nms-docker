package Smokeping::probes::OpenSSHMikrotikPing;

=head1 301 Moved Permanently

This is a Smokeping probe module. Please use the command

C<smokeping -man Smokeping::probes::OpenSSHMikrotikPing>

to view the documentation or the command

C<smokeping -makepod Smokeping::probes::OpenSSHMikrotikPing>

to generate the POD document.

=cut

use strict;

use base qw(Smokeping::probes::basefork);
use Net::OpenSSH;
use Carp;
use Data::Dumper;

my $e = "=";
sub pod_hash {
	return {
		name => <<DOC,
Smokeping::probes::OpenSSHMikrotikPing - Mikrotik SSH Mikrotik Probe for SmokePing
DOC
		description => <<DOC,
Connect to Mikrotik via OpenSSH to run ping commands.
This probe uses the "extended ping" of the Mikrotik Mikrotik.  You have
the option to specify which interface the ping is sourced from as well.
DOC
		notes => <<DOC,
${e}head2 Mikrotik configuration

The Mikrotik device should have a username/password configured, as well as
the ability to connect to the VTY(s).

Make sure to connect to the remote host once from the commmand line as the
user who is running smokeping. On the first connect ssh will ask to add the
new host to its known_hosts file. This will not happen automatically so the
script will fail to login until the ssh key of your Mikrotik box is in the
known_hosts file.

${e}head2 Requirements

This module requires the  L<Net::OpenSSH> and L<IO::Pty>.
DOC
		authors => <<'DOC',
Vladimir Ivaschenko L<lt>vi@maks.netL</gt> http://www.hazard.maks.net,
based on plugins by Tobias Oetiker L<lt>tobi@oetiker.chL<gt>,
and L<Smokeping::probes::TelnetJunOSPing> by S H A N L<lt>shanali@yahoo.comL<gt>.
DOC
	}
}

sub new($$$) {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = $class->SUPER::new(@_);

	# no need for this if we run as a cgi
	unless ( $ENV{SERVER_SOFTWARE} ) {
		$self->{pingfactor} = 1000; # Gives us a good-guess default
		print "### assuming you are using an Mikrotik reporting in milliseconds\n";
	};

	return $self;
}

sub ProbeDesc($) {
	my $self = shift;
	my $bytes = $self->{properties}{packetsize};
	return "Mikrotik - ICMP Echo Pings ($bytes Bytes)";
}

sub pingone ($$) {
	my $self = shift;
	my $target = shift;
	my $source = $target->{vars}{source};
	my $dest = $target->{vars}{host};
	my $psource = $target->{vars}{psource};
	my @output = ();
	my $login = $target->{vars}{mikrotikuser};
	my $password = $target->{vars}{mikrotikpass};
	my $bytes = $self->{properties}{packetsize};
	my $pings = $self->pings($target);
	my $vrf = $target->{vars}{vrf};

	# do NOT call superclass ... the ping method MUST be overwriten
	my %upd;
	my @args = ();

	my $ssh = Net::OpenSSH->new(
		$source,
		$login ? ( user => $login ) : (),
		$password ? ( password => $password ) : (),
		timeout => 60,
	);
	if ($ssh->error) {
		warn "OpenSSHMikrotikPing connecting $source: ".$ssh->error."\n";
		return undef;
	};

	my $extraparam;
	if ( $vrf ) {
		$extraparam .= " routing-table=$vrf ";
	};

	if ( $psource ) {
		$extraparam .= " src-address=$psource ";
	};

	@output = $ssh->capture("/ping $dest count=$pings size=$bytes $extraparam");

	my @times = ();
	for (@output) {
		chomp;
		# 10.123.123.1							   56  64 60ms
		/$dest.*\s(\d+)ms/ and push @times,$1;
	}
	@times = map {sprintf "%.10e", $_ / $self->{pingfactor}} sort {$a <=> $b} @times;
	open (F, ">>/tmp/mtik-deb.txt");
	print F Dumper(\@output);
	print F Dumper(\@times);
	close (F);
	return @times;
}

sub probevars {
	my $class = shift;
	return $class->_makevars($class->SUPER::probevars, {
		packetsize => {
			_doc => <<DOC,
The (optional) packetsize option lets you configure the packetsize for
the pings sent.
DOC
			_default => 100,
			_re => '\d+',
			_sub => sub {
				my $val = shift;
				return "ERROR: packetsize must be between 12 and 64000"
					unless $val >= 12 and $val <= 64000;
				return undef;
			},
		},
	});
}

sub targetvars {
	my $class = shift;
	return $class->_makevars($class->SUPER::targetvars, {
		_mandatory => [ 'mikrotikuser', 'mikrotikpass', 'source' ],
		source => {
			_doc => <<DOC,
The source option specifies the Mikrotik device that is going to run the ping commands.  This
address will be used for the ssh connection.
DOC
			_example => "192.168.2.1",
		},
		psource => {
			_doc => <<DOC,
The (optional) psource option specifies an alternate IP address or
Interface from which you wish to source your pings from.  Routers
can have many many IP addresses, and interfaces.  When you ping from a
router you have the ability to choose which interface and/or which IP
address the ping is sourced from.  Specifying an IP/interface does not
necessarily specify the interface from which the ping will leave, but
will specify which address the packet(s) appear to come from.  If this
option is left out the Mikrotik Device will source the packet automatically
based on routing and/or metrics.  If this doesn't make sense to you
then just leave it out.
DOC
			_example => "192.168.2.129",
		},
		mikrotikuser => {
			_doc => <<DOC,
The mikrotikuser option allows you to specify a username that has ping
capability on the Mikrotik Device.
DOC
			_example => 'user',
		},
		mikrotikpass => {
			_doc => <<DOC,
The mikrotikpass option allows you to specify the password for the username
specified with the option mikrotikuser.
DOC
			_example => 'password',
		},
		vrf => {
			_doc => <<DOC,
The vrf option specifies which routing table to use
DOC
			_example => 'officevrf',
		},

	});
}

1;
