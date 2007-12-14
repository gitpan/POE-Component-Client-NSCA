use Test::More tests => 9;

BEGIN {	use_ok( 'POE::Component::Client::NSCA' ) };

use Socket;
use POE qw(Wheel::SocketFactory Filter::Stream);
use Data::Dumper;

my $encryption = 0;

POE::Session->create(
  package_states => [
	'main' => [qw(
			_start 
			_stop
			_server_error 
			_server_accepted 
			_response 
			_client_error 
			_client_input
			_client_flush
	)],
  ],
);

$poe_kernel->run();
exit 0;

sub _start {
  my ($kernel,$heap) = @_[KERNEL,HEAP];
  $heap->{factory} = POE::Wheel::SocketFactory->new(
	BindAddress => '127.0.0.1',
        SuccessEvent => '_server_accepted',
        FailureEvent => '_server_error',
  );
  my $port = ( unpack_sockaddr_in $heap->{factory}->getsockname() )[0];

  my $check = POE::Component::Client::NSCA->send_nsca( 
	host  => '127.0.0.1',
        port  => $port,
        event => '_response',
        password => 'cow',
        encryption => $encryption,
        context => { thing => 'moo' },
        message => {
                        host_name => 'bovine',
                        return_code => 0,
                        plugin_output => 'The cow went moo',
        },

  );

  isa_ok( $check, 'POE::Component::Client::NSCA' );

  return;
}

sub _stop {
  pass('Everything stopped okay');
  return;
}

sub _response {
  my ($kernel,$heap,$res) = @_[KERNEL,HEAP,ARG0];
  delete $heap->{factory};
  ok( $res->{success}, 'Success!' );
  ok( ( $res->{message} and ref $res->{message} eq 'HASH' ), 'Message was okay' );
  ok( $res->{context}, 'Got the context' );
  ok( $res->{host}, 'Got host back' );
  return;
}

sub _server_error {
  die "Shit happened\n";
}

sub _server_accepted {
  my ($kernel,$heap,$socket) = @_[KERNEL,HEAP,ARG0];
  my $wheel = POE::Wheel::ReadWrite->new(
	Handle => $socket,
	Filter => POE::Filter::Stream->new(),
	InputEvent => '_client_input',
        ErrorEvent => '_client_error',
	FlushedEvent => '_client_flush',
  );
  $heap->{clients}->{ $wheel->ID() } = $wheel;
  pass('Connection from client');
  my $init_packet;
  srand( time() );
  $init_packet .= int rand(10) for 0 .. 127;
  $init_packet .= pack 'N', time();
  $wheel->put( $init_packet );
  return;
}

sub _client_flush {
  my ($heap,$wheel_id) = @_[HEAP,ARG0];
  return;
}

sub _client_error {
  my ( $heap, $wheel_id ) = @_[ HEAP, ARG3 ];
  delete $heap->{clients}->{$wheel_id};
  return;
}

sub _client_input {
  my ($kernel,$heap,$input,$wheel_id) = @_[KERNEL,HEAP,ARG0,ARG1];
  pass('Yay got a check from the client');
  return;
}
