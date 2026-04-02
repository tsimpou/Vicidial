#!/usr/bin/perl
open(my $fh, '<', '/etc/astguiclient.conf') or die "Cannot open: $!";
while (my $line = <$fh>) {
    chomp $line;
    if ($line =~ /^VARDB_server/) {
        my $v = $line;
        $v =~ s/.*=//gi;
        print "VARDB_server=[$v]\n";
    }
    if ($line =~ /^VARDB_database/) {
        my $v = $line;
        $v =~ s/.*=//gi;
        print "VARDB_database=[$v]\n";
    }
    if ($line =~ /^VARDB_user/) {
        my $v = $line;
        $v =~ s/.*=//gi;
        print "VARDB_user=[$v]\n";
    }
    if ($line =~ /^VARDB_pass/) {
        my $v = $line;
        $v =~ s/.*=//gi;
        print "VARDB_pass=[$v]\n";
    }
}
close($fh);
print "Done\n";
