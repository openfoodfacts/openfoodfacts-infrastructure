#!/usr/bin/perl -w

my %ip = ();
my $total = 0;

while (<STDIN>)
{
	if ($_ =~ /(^\S+) /)
	{
		$ip{$1}++;
		$total++;
	}
}

foreach my $ip (sort { $ip{$a} <=> $ip{$b}} keys %ip)
{
print "$ip\t$ip{$ip}\t" . ($ip{$ip} / $total * 100) . "% \n";
}

