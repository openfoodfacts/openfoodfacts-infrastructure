#!/usr/bin/perl -w

=head1 LOG ANONYMIZER

This script takes a log file and anonymizes it
by replacing the IP addresses by a random IP address.

This is to be compliant to GDPR while keeping logs for eventual statistics.

Typically at some point in time, you would use this command on /var/log/nginx/mysite.log.*,
move anonimized logs to a backup directory,
and remove the original files.

=cut

use strict;
use warnings;

use Date::Parse qw(str2time);
use POSIX qw(strftime);

my $usage = "Usage: $0 < log file > [< log file > ...]\n";

die($usage) unless (scalar @ARGV);

sub int_to_ip($) {
    my $number = shift;
    # thank you cody
    my ($a, $b, $c, $d) = ($number >> 24, ($number >> 16) & 0xFF, ($number >> 8) & 0xFF, $number & 0xFF);
    return sprintf("%d.%d.%d.%d", $a, $b, $c, $d);
}

my %ip_to_anon = ();
my $ip_next = 2**24;

foreach my $fname (@ARGV) {
    my ($start, $end); # start and end dates in the log file
    print "Processing $fname\n";
    my $target = "$fname.anonymized.gz";
    my $modifier = "";
    my $pipe = "<";
    if ($fname =~ /\.gz$/) {
        $modifier = "gunzip -c ";
        $pipe = "-|";
    }
    open(my $IN, $pipe, "$modifier$fname") or die("Could not open $fname: $!");
    open(my $OUT, "|-", "gzip > $target") or die("Could not create $target: $!");
    while (my $line = <$IN>) {
        if ($line =~ /(^\S+) /) {
            if (not defined $ip_to_anon{$1}) {
                # create an anonymous ip
                $ip_to_anon{$1} = int_to_ip($ip_next++);
            }
            # substitute
            $line =~ s/(^\S+) /$ip_to_anon{$1} /;
        }
        if ($line =~ m<\[(\d+/\w+/\d+:\d{2}:\d{2}:\d{2} \+\d+)\]>) {
            my $line_epoch = str2time($1);
            $start = $line_epoch if !defined $start || $line_epoch < $start;
            $end = $line_epoch if !defined $end || $line_epoch > $end;
        }
        print $OUT $line;
	}
    close($IN);
    close($OUT);
    # rename target to reflect dates
    if ($start && $end) {
        my $start_str = strftime("%Y-%m-%d", gmtime($start));
        my $end_str = strftime("%Y-%m-%d", gmtime($end));;
        # put date after .log
        my $new_target = $target;
        # add time range but keep timestamp for the case of several rotation in a single day
        $new_target =~ s/^(.+)\.log(\..*)?$/$1.$start_str--$end_str.$start.anonymized.log.gz/;
        rename($target, $new_target) or print STDERR "Could not rename $target to $fname: $!";
    }
}

