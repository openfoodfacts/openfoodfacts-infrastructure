#!/usr/bin/perl
#
use strict;

# init
my $systemName = "off1.free.org";
my $sendmail = "/usr/lib/sendmail -t";

my $mdstat = `cat /proc/mdstat`;

# email setup
my $emailTo='root@openfoodfacts.org';
my $emailFrom='root@openfoodfacts.org';
my $emailSubject="mdstat: probleme raid - $systemName";
my $emailBody = $mdstat;

if ($mdstat =~ /-|_/ ) {
        open(MAIL, "|$sendmail");
        print MAIL "To: $emailTo\n";
        print MAIL "From: $emailFrom\n";
        print MAIL "Subject: $emailSubject\n\n";
        print MAIL $emailBody;
        close(MAIL);
}
