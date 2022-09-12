#!/usr/bin/perl -w
use strict;
use IO::Socket;
use Getopt::Long;

sub usage() {

        print "winftprecon.pl 0.9beta2 - Tom Van de Wiele (https://twitter.com/0xtosh) 2009\n";
	print "Usage: winftprecon.pl -h FTPHOST [-p FTPPORT ] -user USERNAME -pass PASSWORD [-sqlite3 SQLITE3_PATH] [-logfile LOGFILE.CSV -logdb LOGFILE.DB ]\n\n";
        if ($_[0] && $_[0] =~ /^booboo$/) {
                print "Must give host, user and pass as a minimum!\n";
        }
	exit(1);
}

if (@ARGV == 0) {
        usage();
}

my $host;
my $port;
my $user;
my $pass;
my $customlogfile;
my $customlogdb;
my $sqlite3;
# all the ones I observed by watching ftp.microsoft.com.  Add more here if you need/find them.
my %ftpcmds = ("ABOR",0,"ACCT",0,"ALLO",0,"APPE",0,"CDUP",0,"CWD",0,"DELE",0,"FEAT",0,"HELP",0,"LIST",0,"MDTM",0,"MKD",0,"MODE",0,"NLST",0,"NOOP",0,"OPTS",0,"PASS",0,"PASV",0,"PORT",0,"PWD",0,"QUIT",0,"REIN",0,"REST",0,"RETR",0,"RMD",0,"RNFR",0,"RNTO",0,"SITE",0,"SIZE",0,"STAT",0,"STOR",0,"STOU",0,"STRU",0,"SYST",0,"TYPE",0,"USER",0,"XCUP",0,"XCWD",0,"XMKD",0,"XPWD",0,"XRMD",0);
my %presentcmds;

if ( @ARGV > 0 ) {

   GetOptions('host|h:s'=> \$host,
              'port|p:s' => \$port,
              'user:s' => \$user,
              'pass:s' => \$pass,
              'logfile:s' => \$customlogfile,
              'logdb:s' => \$customlogdb,
              'sqlite3:s' => \$sqlite3)
            or print "Could not parse command line options!\n";
}

if (!$host || !$user || !$pass) {
	&usage("booboo");
}

my $outputdb = $customlogdb;
my $outputfile = $customlogfile;

if (!$sqlite3) {
	$sqlite3 = "/usr/bin/sqlite3";
}
my $foundlogfile = 0;
my $founddbfile = 0;
my $sqlinsertout;
my $sqlcreateout;
my $sqlerror = 0;
my $header = "TIMESTAMP\;";

print "winftprecon.pl beta0.9 - Tom Van de Wiele (0xtosh) 2009\n\n";

if (!$port) {
        print "No port specified, assuming good 'ol 21/TCP...\n";
        $port = 21;
}

if ($outputfile) {

	if (-e $outputfile) {
		$foundlogfile = 1;
		open (O, ">>$outputfile") or die "Could not append to existing file $outputfile! $!\n";
	}
	else {
		open (O, ">$outputfile") or die "Could not create $outputfile! $!\n";
		print "Created new log file $outputfile...\n";

		# print a header for the csv file
		foreach my $key (sort keys %ftpcmds) {
                	$header .= $key . "\;";
        	}
		chop($header);
		print O $header . "\n";
	}
}

if ($outputdb && -e $outputdb) {
	$founddbfile = 1;
}

if (!-e $sqlite3 || !-x $sqlite3) {
	print "/usr/bin/sqlite3 was not found or was found non-executable!  If not /usr/bin/sqlite3, try specifying the exact path!\nExiting...\n";
	exit(1);
}

my $sock = new IO::Socket::INET(
 
        PeerAddr => $host,
        PeerPort => $port,
        Proto => 'tcp') || die "Could not connect to $host on port $port: $!
";

if ($founddbfile == 0 && $outputdb) {
	print "Creating sqlite3 db file: $outputdb\n";	
	$sqlcreateout = `$sqlite3 $outputdb "create table stats (id INTEGER PRIMARY KEY, ftpcmd TEXT, counter INTEGER, date TEXT);"`;
	if ($sqlcreateout) {
		print "Something went wrong with creating the db with sqlite3?\n";
	}
}

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
$mon  += 1;
my $timestamp="%02d/%02d/%04d %02d:%02d:%02d";
my $okgo = 0;
my $firstdisplay = 0;

my @presentcmds;

print "Logging in and fetching SITE STATS output...\n";
print $sock "USER $user\n";
sleep(1);
print $sock "PASS $pass\n";
sleep(1);
print $sock "SITE STATS\n";
sleep(1);
print $sock "QUIT\n";

while(<$sock>) {

	# clear the CR/LF, UNIX and windows style
	chomp($_);
	s/\r|\n//g;

 	if ($_ =~ /^5[0-9][0-9].*(login|password|authentication).*$/) {	
		print "Authentication failed.  Manually check your credentials, got a 5xx somewhere related to auth...\n";
		print "Exiting...\n";
		exit(1);
	}

	if ($_ =~ /^\s*5[0-9][0-9].*SITE STATS.*/) {

                print "Host $host does not support SITE STATS!  Are you sure this is a Windows FTP service?\n";
		print "Exiting...\n";
                exit(1);

        }	
	else {
		if ($_ =~ /([A-Z]{3,4})\s+:\s+([0-9]*)$/) {

			# print it only once
			if ($okgo == 0) {
				print "Got SITE STATS, parsing ...\n";
				$okgo = 1;
			}

			if ($firstdisplay == 0) {
		
				$firstdisplay = 1;	
                		printf ("Time of FTP STATS status:  %02d/%02d/%04d %02d:%02d:%02d\n\n", $mday, $mon, $year, $hour, $min, $sec);
				print ("Host:  $host\n\n");
				print ("FTP command - Counter Value\n---------------------------\n");
			}

                	printf ("$1 : $2\n");

			# if we want csv logging
			if ($customlogfile) {

				# put it in our hash, we're doing this line by line so we need to see what cmds are present before we print out a line
				$presentcmds{$1} = $2;	
			}			

			# is we want sqlite logging
			if ($customlogdb) {
		
				$sqlinsertout = sprintf ("$sqlite3 $outputdb \"insert into stats (id,ftpcmd,counter,date) values (NULL,\'$1\',$2,\\\"%02d/%02d/%04d %02d:%02d:%02d\\\");\"\n", $mday, $mon, $year, $hour, $min, $sec);
                		my $sqlinject = `$sqlinsertout`;
				if ($sqlinject) {	
					$sqlerror = 1;
				}
			}
        	}
	} 
}

if ($customlogdb) {

	if ($sqlerror == 1) {
		print "Sqlite3 returned a problem, SQL data possibly not inserted! Check the db\n";  
	}
	else {
		print "\nData inserted into sqlite3 db... \n";
	}
}

if ($customlogfile) {

	# fill in the values for which we have ftp commands
	foreach my $key (sort keys %ftpcmds) {

		$ftpcmds{$key} = $presentcmds{$key};
	}

	# run through them and make sure we set the ones we didn't find to 0 to have consistency in our csv file
	
	foreach my $key (sort keys %ftpcmds) {

		if (!$ftpcmds{$key}) {
        		$ftpcmds{$key} = 0;
		}	
	}

	# finally, construct the line and print it to our file

	my $line2write = "";
	
	foreach my $key (sort keys %ftpcmds) {
		$line2write .= $ftpcmds{$key} . "\;";	
	}
	chop($line2write);
	if ($foundlogfile == 1) {
		print "Appending to file $outputfile...\n";
	}
	else {
		print "Writing to file $outputfile...\n";
	}
	printf O ("%02d/%02d/%04d %02d:%02d:%02d;$line2write\n", $mday, $mon, $year, $hour, $min, $sec);

}
close ($sock);
print "\nDone.\n";

close(O); 
#EOF
