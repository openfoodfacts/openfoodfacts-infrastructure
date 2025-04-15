#!/usr/bin/perl -w

my %ua = ();

while (<STDIN>)
{
        if ($_ =~ /"([^"]+)".+"([^"]+)"/)
        {
                $ua{$2}++;
        }
}

foreach my $ua (sort { $ua{$a} <=> $ua{$b}} keys %ua)
{
        print "$ua\t$ua{$ua}\n";
}

