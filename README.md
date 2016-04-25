# CHT_SNS_SMS_Sender
A PERL program to send SMS via CHT SNS Protocol
This program will take a filename as command line paramters and sends the contents of the file to the CHT SNS (SMS Center).  
The contents of the file must be as the following:  
MSISDN\n  
SMS Message\n  

Sample:  
0910000123  
This is a sample SMS message  

Save the file (ex: /tmp/sendsms123) and then invoke the program:  
./cht_sns_sender.pl /tmp/sendsms123  

This will send out the SMS message  


