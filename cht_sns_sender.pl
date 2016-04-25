#!/usr/bin/perl
#
# This is the CHT Mobile SNS sender program 
# The program will take a filename as an arguement and send an SMS via CHT-Mobile SNS interface
# The SMS Meta File should look like this:
#
#     0910123123<CR>
#     The SMS message you want to send<CR>
#
# Then you invoke the program like this:
# ./cht_sns_sender.pl /path/to/sms_meta_file
#
# VERSION 1.0.0:
# 	First Version by Peter Cheng (Acom Networks) 2014-11-30
#

use IO::Socket;
# use DBI;

##### START: Constants
use constant SERV_CHECK		=> 0;
use constant SERV_SEND		=> 2;
use constant SEND_NOW		=> 100;
use constant NULL_BYTE		=> 0x00;
use constant CODETYPE_BIG_5	=> 1;
use constant CODETYPE_UNICODE	=> 8;
use constant DEBUG_MODE		=> 1;
use constant LOG_OFF		=> 1;
##### END: Constants

##### START: Program Settings Variables
# These are the CHT SNS variables
$server_ip = '10.1.66.100';
$server_port='8001';
$username = '13074';
$password = '13074';

$smsfile = $ARGV[0];

# Create this directory for detailed log files
$log_dir = '/home/logs/smsd/';
$program_name = 'smsd';
$version = '1.0.0';
$pid_no = $$;
##### END: Program Settings Variables


logger("START:Starting Program $program_name with PID $pid_no VERSION $version");

##### START: Read in the SMS file
if (!(-e $smsfile)) {
	logger("ERROR:The SMS Meta File '$smsfile' does not exist!");
	exit();
}

open(SMSFILE, "< $smsfile");
$msisdn = <SMSFILE>;
$mesg = <SMSFILE>;
chomp($msisdn);
chomp($mesg);
close(SMSFILE);

logger("INFO:SMSFILE:$smsfile:MSISDN:$msisdn:SMS_MESG:$mesg");
##### END: Read in the SMS file

##### START: Remove the SMS file
logger("INFO:Removing SMS Meta File $smsfile");
unlink $smsfile;
##### END: Remove the SMS file

##### START: Tail pad the username/password with nulls up to 9 characters
$username .= "\0" x (9 - length($username));
$password .= "\0" x (9 - length($password));
##### END: Tail pad the username/password with nulls up to 9 characters

##### START: Connect to CHT SNS server
$feedsock = IO::Socket::INET->new
(
        PeerAddr => $server_ip,
        PeerPort => $server_port,
        Proto => "tcp",
        Type => SOCK_STREAM,
	Timeout    => 10
) or die "Could not open port to CHT SNS Server!\n";
sleep 1;
##### END: Connect to CHT SNS server

##### START: Set IO Socket parameters
$feedsock->blocking(0);
$feedsock->autoflush(1);

$feedsock_block   = $feedsock->blocking() || 'undef';
$feedsock_timeout = $feedsock->timeout()  || 'undef';
$feedsock_autoflush = $feedsock->autoflush() || 'undef';
logger("DEBUG:Socket blocking = $feedsock_block") unless DEBUG_MODE;
logger("DEBUG:Socket timeout = $feedsock_timeout") unless DEBUG_MODE;
logger("DEBUG:Socket autoflush = $feedsock_autoflush") unless DEBUG_MODE;
##### END: Set IO Socket parameters

##### START: Login to SNS server
logger("INFO:Now logging into CHT SNS Server");

# Pad with nulls
$dummy_msisdn = "\0" x 13;
$mesgid = "\0" x 9;
$dummy_mesg = "\0" x 160;
$sendtime = "\0" x 13;

$login_string  = chr(SERV_CHECK) . chr(NULL_BYTE) . chr(NULL_BYTE) . chr(NULL_BYTE) . $username . $password . $dummy_msisdn . $mesgid . $dummy_mesg . $sendtime;
$dumpstring = dumpstring($login_string);
logpacket($login_string,"OUT") unless DEBUG_MODE;
logger("INFO:Sending login string to remote");
print $feedsock "$login_string";
#####

$code = 99;
$answer = '';
while (length($answer) == 0) {
	$feedsock->flush();
	$answer = <$feedsock>;
}

if (length($answer) > 0) {
	$packet_length = length($answer);
	logpacket($answer,"IN") unless DEBUG_MODE;
	$code = ord(substr($answer,0,1));
	logger("INFO:CODE:SNS return code=$code");
	$buffer = substr($answer,29,160);
	$buffer =~ s/\x00+//; ;
	$buffer_len = length($buffer);
	logger("INFO:BUFFER:$buffer (length = $buffer_len)");
}
if ($code == 0) {
	logger("INFO:Successfully logged into CHT SNS server (code=$code)");
} else {
	logger("ERROR:Cannot login to CHT SNS server (code=$code)");
	logger("ERROR:EXIT:Terminating program");
	close($feedsock);
	exit();
}

##### END: Login to SNS server

##### START: Send message
$mesg_len = length($mesg);
$mesg_len_hex = sprintf("%x",$mesg_len);
logger("INFO:Sending SMS message to $msisdn");
logger("INFO:MSISDN:$msisdn:MESG:$mesg:LENGTH:$mesg_len:HEX:$mesg_len_hex");
$mesg_len_out = pack "c", $mesg_len;


# Pad with nulls
$msisdn .= "\0" x (13 - length($msisdn));
$mesgid = "\0" x 9;
$mesg .= "\0" x (160 - length($mesg));
$sendtime = "\0" x 13;

$sendmsg_string  = chr(SERV_SEND) . chr(CODETYPE_BIG_5) . $mesg_len_out . chr(SEND_NOW) . $username . $password . $msisdn . $mesgid . $mesg . $sendtime;
$dumpstring = dumpstring($sendmsg_string);
logpacket($sendmsg_string,"OUT") unless DEBUG_MODE;
logger("INFO:Sending SERV_SEND string to remote");
print $feedsock "$sendmsg_string";

$code = 99;
$answer = '';
while (length($answer) == 0) {
	$feedsock->flush();
	$answer = <$feedsock>;
}

if (length($answer) > 0) {
	$packet_length = length($answer);
	logpacket($answer,"IN") unless DEBUG_MODE;
	$code = ord(substr($answer,0,1));
	logger("INFO:CODE:SNS return code=$code");
	$buffer = substr($answer,29,160);
	$buffer =~ s/\x00+//; ;
	$buffer_len = length($buffer);
	logger("INFO:BUFFER:$buffer (length = $buffer_len)");
}
if ($code == 0) {
	logger("INFO:Successfully sent SMS to CHT SNS server (code=$code)");
	logger("INFO:MESG_ID:$buffer");
} else {
	logger("ERROR:Cannot send SMS to CHT SNS server (code=$code)");
	logger("ERROR:EXIT:Terminating program");
	close($feedsock);
	exit();
}

##### END: Send message
logger("EXIT:Ending Program with normal shutdown");
exit();










##### SUB START: logger

sub logger {

	local @logarray = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900; $mon++; $mon = sprintf("%02d", $mon); $mday = sprintf("%02d", $mday);
	$sec = sprintf("%02d", $sec); $min = sprintf("%02d", $min); $hour = sprintf("%02d", $hour);
	my $timestring;
	my $datestring = $year . '-' . $mon . '-' . $mday;
	$timestring = $datestring . ' ' . $hour . ':' . $min . ':' . $sec;

	local $log_file = $log_dir . $program_name . '-' . $datestring . '.log';

	local $logline = $logarray[0];
	open (LOG, ">> $log_file") unless LOG_OFF;
	print LOG "$timestamp $pid_no $logline\n" unless LOG_OFF;
	close(LOG) unless LOG_OFF;
	if (LOG_OFF) {
		print "$timestring $pid_no $logline\n";
	}
}

##### END SUB: logger




##### START SUB: dumpstring

sub dumpstring {
	@dumpdata_string = @_;
	my $string_length = length($dumpdata_string[0]);
	# print "$dumpdata_string[0]\n";
	$return_string = "RAW PROTOCOL: ";
	for ($count = 0;$count < $string_length; $count++) {
		$count_string = $count;
 		if (length($count_string) == 1) {
			$count_string = "00" . $count_string;
		}
		if (length($count_string) == 2) {
			$count_string = "0" . $count_string;
		}
		$dec_value = ord(substr($dumpdata_string[0],$count,1));

		$return_string .=  "<" . $count_string . ">[" . sprintf("%02d", $dec_value) . "]-";
	}
	return $return_string;
}

##### END SUB: dumpstring


##### START SUB: logpacket

sub logpacket {

	local @param_array = @_;

	local $packet_length = length($param_array[0]);
	if ($param_array[1] eq "IN") {
		logger("INFO:PACKET_IN:Receiving packet size of $packet_length bytes");
	} else {
		logger("INFO:PACKET_OUT:Sending packet size of $packet_length bytes");
	}
	local $hexdump = dumpstring("$param_array[0]");
	logger("DEBUG: $hexdump");
}

##### END SUB: logpacket


