#!/usr/bin/perl -w

use strict;

use String::MkPasswd qw(mkpasswd);
use Crypt::PasswdMD5 qw(unix_md5_crypt);


my $user = $ARGV[0];

if (not defined $user) {
	die("Need user name (only a to z letters, at least 3 letters)\n");
}

if ($user !~ /^[a-z]{3}([a-z]*)$/) {
	die("Invalid user name: $user (only a to z letters, at least 3 letters.\n");
}

my $sftpdir = "/home/sftp";

if (-e "$sftpdir/$user") {
	die("Directory $sftpdir/$user already exists.\n");
}

mkdir("$sftpdir/$user", 0755) or die("Could not create dir $sftpdir/$user : $!\n");
mkdir("$sftpdir/$user/data", 0755) or die("Could not create dir $sftpdir/$user/data : $!\n");

my $password = mkpasswd(-minspecial=>0); 

my @salt = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );

sub gensalt {
 my $count = shift;
 my $salt;
 for (1..$count) {
  $salt .= (@salt)[rand @salt];
 }
 return $salt;
}

my $password_hash = unix_md5_crypt($password, gensalt(8));

system("useradd", "$user", "-d", "/home/sftp/$user/data", "-g", "1006", "-M", "-N", "-p", $password_hash);
system("chown", "-R", "$user:sftponly", "/home/sftp/$user/data");

open (my $OUT, ">>", "/etc/ssh/sshd_config");
print $OUT <<CONF

Match User $user
	ChrootDirectory /home/sftp/$user
	X11Forwarding no
	AllowTcpForwarding no
	ForceCommand internal-sftp
CONF
;

close($OUT);

system("systemctl", "restart", "sshd");

print <<TXT

Nous avons mis en place un accès SFTP:

host: sftp.openfoodfacts.org
port: 22
login: $user
password: $password

Vous pouvez mettre les données et photos dans le répertoire data et y créer des sous-répertoires si besoin.

--

We have set up a SFTP access:

host: sftp.openfoodfacts.org
port: 22
login: $user
password: $password

You can put data and photos in the data directory, and create sub directories if necessary.

TXT
;


