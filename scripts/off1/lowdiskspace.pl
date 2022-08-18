#!/usr/bin/perl
#
# lowdiskspacewarning.pl
#
use strict;
use Filesys::DiskFree;

# init
my $sendmail = "/usr/lib/sendmail -t";

# file system to monitor
my @dirFilesystems = ("/home/", "/srv/", "/", "/mongodb");
my $systemName = "off1";

# low diskspace warning threshhold
my $warningThreshhold=10 ; # in percent

foreach my $dirFilesystem (@dirFilesystems) {

# fs disk freespace
my $fsHandle = new Filesys::DiskFree;
$fsHandle->df();
my $fsSpaceAvail = $fsHandle->avail($dirFilesystem);
my $fsSpaceTotal = $fsHandle->total($dirFilesystem);
my $fsSpaceUsed = $fsHandle->used($dirFilesystem);
my $fsSpaceAvailPct = (($fsSpaceAvail) / ($fsSpaceAvail+$fsSpaceUsed)) * 100.0;

# email setup
my $emailTo='root@openfoodfacts.org';
my $emailFrom='root@openfoodfacts.org';
my $emailSubject="Espace disque faible : $systemName";
my $emailBody = sprintf("WARNING Low Disk Space on '$systemName $dirFilesystem': %0.2f%%\n", $fsSpaceAvailPct);

# If free space is below threshhold, e-mail a warning message.
if ($fsSpaceAvailPct < $warningThreshhold) {
        open(MAIL, "|$sendmail");
        print MAIL "To: $emailTo\n";
        print MAIL "From: $emailFrom\n";
        print MAIL "Subject: $emailSubject\n\n";
        print MAIL $emailBody;
        close(MAIL);
}

}
