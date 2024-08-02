# Bash
Really simple - read last  lines of an error log and if the entry is within 10minutes sent an email

This particular code is capable of checking log of this type:
2024.07.11 20:37:12::ERROR MESSAGE -lorem ipsum a
2024.07.31 09:09:53::ERROR MESSAGE -lorem ipsum b
2024.07.31 09:15:06::ERROR MESSAGE -lorem ipsum c
2024.07.31 09:20:19::ERROR MESSAGE -lorem ipsum d
2024.07.31 09:25:31::ERROR MESSAGE -lorem ipsum e

But every other type of log where timeSTamp is present could be further adjusted.

Of course we will need following components installed on the server:
mailx
and working configured smtp relay - for example postfix

In order to be used for monitoring purposes also - the script could be scheduled as a cron job

