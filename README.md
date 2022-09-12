# winftprecon

## What

winftprecon is a legacy Windows FTP service `SITE STATS` poller for enumeration purposes
When pentesting a range of legacy servers especially for older internal networks such as industrial networks, Microsoft FTP servers might show up where you have to find out which ones have the most activity for further attack. Other than doing IP ID increment analysis to see which servers are active when, legacy Microsoft FTP servers will keep track of what FTP commands are being used and allows interrogation of these stats per command. 

This means that a pentester or would be attacker would be able to find out what commands are being used the most and when. The attacker will know when uploads, downloads, deleting etc are being performed, when and how much. Based on this information the attacker knows what to attack further and where to focus their efforts, budget and time.

## A wild specimen from a past time 

An example form when Microsoft still had an FTP server that allowed this using the anonymous user:
```
Trying 198.105.232.1...
Connected to ftp.microsoft.com.
Escape character is '^]'.
220 ftp Microsoft FTP Service (Version 3.0).
USER FTP
331 Anonymous access allowed, send identity (e-mail name) as password.
PASS FTP
230-This is FTP.MICROSOFT.COM
230-Please see the dirmap.txt file for
230-more information.
230 Anonymous user logged in.
SITE STATS
200-ABOR : 302878
    ACCT : 6
    ALLO : 1
    APPE : 12
    CDUP : 180296
    CWD  : 2643776
    DELE : 969
    HELP : 2825
    LIST : 1960318
    MKD  : 763
    MODE : 315
    NLST : 58931
    NOOP : 539571
    PASS : 1593667
    PASV : 1428243
    PORT : 2120405
    PWD  : 1080190
    QUIT : 349168
    REIN : 13
    REST : 293760
    RETR : 1495575
    RMD  : 240
    RNFR : 158
    RNTO : 16
    SITE : 3933
    STAT : 6098
    STOR : 6566
    STRU : 550
    SYST : 381727
    TYPE : 3183166
    USER : 1610611
    XCWD : 21
    XMKD : 39
    XPWD : 1866
    XRMD : 23
200 End of stats.
QUIT
221 Thank you for using FTP.MICROSOFT.COM!
```
winftprecon.pl allows you to track these commands easily and stick them in a sqlite3 and/or flag file. Credentials are required for this to work combined with a legacy Microsoft FTP server. 

As mentioned, although Microsoft FTP is being retired in most places in favor of web based equivalents, internal networks, industrial networks and legacy networks will still run these kinds of legacy services.

This "tool", or sorry excuse for a shellscript wrapper I kept rewriting every gig, was inspired by the DEFCON 15 talk "Tactical Exploitation" by HD Moore and Valsmith.

## Running it

The following is an example on how to run the tool while making it log to a CSV file:
```
pwner@dropship:/tools/winftprecon.pl/$ winftprecon.pl -h 1.3.3.7 -p 21 -user anonymous  -pass ftp -logfile 1.3.3.7_21_site_stats.csv
```

The following is an example on how to run the tool while making it log to a sqlite3 database:
```
pwner@dropship:/tools/winftprecon.pl/$ winftprecon.pl -h 1.3.3.7 -p 21 -user anonymous  -pass ftp -sqlite3 1.3.3.7_21_site_stats.db
```

## Logging

So how does it log to the sqlite3 db?

winftprecon supports csv logging and/or sqlite3 logging to a database file of your choosing.  The database name is called "stats" with three fields, in sqlite terms this would be:
```
stats (id INTEGER PRIMARY KEY, ftpcmd TEXT, counter INTEGER, date TEXT)
```
You can use the `SELECT` and `COUNT` commands to query the data.

## Interpreting output
There's a TON of these FTP commands, which does which?

I suggest you take a look at the FTP RFC (a rividing read) or http://en.wikipedia.org/wiki/List_of_FTP_commands

The CSV file contains a timestamp and then the list of the ftp commands, one by one, followed by their counter value.  The idea is to import this csv into your favorite spreadsheet and do your graphs from there.

The sqlite3 database file is handier as all data can be approached through SQL.  As such, only the ftp commands that are encountered in the output of `SITE STATS` are considered and added.  The database is ordened by ftp command because at the end of the day, that's what we want to count.  The SQL commands `SELECT` and `COUNT` can help you in determining how many commands were issued during what timespan.  Use whatever you like to get statistics out of these.
