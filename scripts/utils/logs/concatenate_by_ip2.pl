#!/usr/bin/perl -w

my %ip_count = ();
my %ip_distinct_count = ();
my $total = 0;

while (<STDIN>)
{
    if ($_ =~ /(^\d+\.\d+)\.\d+\.\d+ /)
    {
        $total++;
        $ip_count{$1}++;
        $ip_distinct_count{$1} = {} unless defined $ip_distinct_count{$1};
        $ip_distinct_count{$1}->{$&}++;
    }
}
foreach my $ip (sort { $ip_count{$a} <=> $ip_count{$b}} keys %ip_count)
{
    printf "%8s\t%d\t%.2f %% of reqs\t%d distinct ips\n", $ip, $ip_count{$ip}, ($ip_count{$ip} / $total * 100), (scalar keys %{$ip_distinct_count{$ip}});
}
print "total: $total\n";
print "ips: " . (scalar keys %ip_count) . "\n";
