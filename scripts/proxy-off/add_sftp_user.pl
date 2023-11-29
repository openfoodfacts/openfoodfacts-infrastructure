#!/usr/bin/perl -w

use strict;
use warnings;

use String::MkPasswd qw(mkpasswd);
use Crypt::PasswdMD5 qw(unix_md5_crypt);
use Getopt::Long qw(GetOptions);


# sftp dir is in a ZFS dataset shared with off-pro
my $sftpdir = "/mnt/off-pro/sftp";
my $hostname = "sftp.openfoodfacts.org";

my $pubkey = "";
my $usage = "Usage: $0 [--dry-run] [--pubkey file] <user>\n\n" .
	"pubkey is a publickey string (including the key type prefix)\n";
my $user_help = "Only a to z letters, at least 3 letters";
GetOptions("pubkey=s" => \$pubkey) or die("$usage\n");

my $user = $ARGV[0];
if (not defined $user) {
	die("$usage\nError: Need user name $user_help.\n");
}

if ($user !~ /^[a-z]{3}([a-z]*)$/) {
	die("$usage\nError:Invalid user name: $user $user_help.\n");
}

print("This script was not really tested (yet), are you sure you want to do continue? (y/n)\n");
my $confirm = <STDIN>;
if ($confirm!~ /^y/i) {
	die("Aborting.\n");
}


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

my $user_dir = "$sftpdir/$user";

# we just need to create the user and add it to the sftp group
my @user_cmd = ("useradd", "$user", "-d", "$user_dir/data", "-g", "1006", "-M", "-N", "-p", $password_hash);
print("running: ". join(" ", @user_cmd) . "\n");
system(@user_cmd);
my @chown_cmd = ("chown", "-R", "$user:sftponly", "$user_dir/data");
print("running: " . join(" ", @chown_cmd) . "\n");
system(@chown_cmd);

# copy pub key if given, else just create the file
my $pub_key_file = "$sftpdir/${user}_authorized_keys";
open(my $FILE, '>>', $pub_key_file) or print("Error Could not open $pub_key_file: $!\n");
if (defined $FILE) {
	print($FILE,"\n$pubkey\n");
	close($FILE);
}

# note we don't need a ssh reload as the configuration is based on the group, 
# see confs/proxy-off/sshd_config/sftp.conf
# my @ssh_reload_cmd = ("systemctl", "reload", "ssh");
# print("running: " . join(" ", @ssh_reload_cmd) ."\n");
# system(@ssh_reload_cmd);

# get server keys to allow validation on first connection

my @keys = `ssh-keyscan $hostname | ssh-keygen -lf -`;
@keys = grep {$_ !~ '^#'} @keys;
my $keys_txt = join("", @keys);

# print mail content
print <<TXT

Nous avons mis en place un accès SFTP:

host: sftp.openfoodfacts.org
port: 22
login: $user
password: $password

empreinte des clés serveurs:
$keys_txt

Vous pouvez mettre les données et photos dans le répertoire data et y créer des sous-répertoires si besoin.

--

We have set up a SFTP access:

host: sftp.openfoodfacts.org
port: 22
login: $user
password: $password

server keys fingerprint:
$keys_txt

You can put data and photos in the data directory, and create sub directories if necessary.

TXT
;


