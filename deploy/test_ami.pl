#!/usr/bin/perl
# Test AMI authentication
use IO::Socket::INET;

my $host = shift || 'localhost';
my $port = 5038;
my $user = shift || 'cronsend';
my $pass = 'AmiV1c1d@l2026';

print "Connecting to $host:$port...\n";
my $sock = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => $port,
    Timeout  => 5,
) or die "Cannot connect: $!";

# Read banner
my $banner = <$sock>;
chomp $banner;
print "Banner: $banner\n";

# Send login
print $sock "Action: Login\r\nUsername: $user\r\nSecret: $pass\r\n\r\n";

# Read response (up to 5 lines)
for (1..5) {
    my $line = <$sock>;
    last unless defined $line;
    chomp $line;
    print "Response: $line\n";
    last if $line =~ /Authentication (accepted|failed)/i;
}
close $sock;
print "Done\n";
