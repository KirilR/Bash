#!/bin/bash

#locations of the help files that are going to be used during the check
# replace the current LOG_FILE with the path to the file you would like to "observe"
#STORED_DATA_FILE - plays the role of file where the new log entries ("younger" than 12 hours and unique) are stored so that by every script execution if within the log there are 
#re-occurung events sneding a new duplicated alarm to be prevened (new alarm for the same event will be sent only if the issue exist more than 12hours) - here the time is adjustable with #the "twelve_hours_ago" variable

LOG_FILE=/tmp/tempk/testlog
STORED_DATA_FILE=/tmp/tempk/stored_data.txt
EMAIL_SENT_HISTORY_FILE=/tmp/tempk/email_history.txt

# Arrays to store log entries and encountered logs and one additional empty array used for check and wiping up the STORED_DATA_FILE
log_entries=()
encountered_logs=()
new_encountered_logs=()

# Function to convert date to epoch
#epoch is actually the times in seconds since 1970-01-01 00:00 UTC - that is the way linux handles times, times-differences, etc
date_to_epoch() {
    date --date "$1" +"%s" 2>/dev/null
}

# Function to sanitize log data (removing special characters since otherwise the string comparison used to store the already processed alaram in STORED_DATA_FILE doesn`t work well )
sanitize_data() {
    echo "$1" | sed 's/[^a-zA-Z0-9 ]//g'
}

# Prepare variables
# those variables are going to be used while reading the log, tobeemail will take some value only if some new log is found (a log that is either not present in STORED_DATA_FILE and its #timestamp is within 10 minutes)
#t2 = that is the current time and date converted in seconds so that we can use it for comparison later
#twelve_hours_ago - variable with seconds from now minus 
tobemail=""
current_time=$(date +"%Y-%m-%d %H:%M:%S")
t2=$(date_to_epoch "$current_time")
twelve_hours_ago=$(date_to_epoch "$(date -d '12 hours ago' +"%Y-%m-%d %H:%M:%S")")

# get the encountered logs from file if it exists
if [[ -s $STORED_DATA_FILE ]]; then
    while IFS= read -r log_entry; do
        encountered_logs+=("$log_entry")
    done < "$STORED_DATA_FILE"

    # remove encountered logs to keep only those within the last 12 hours
    for encountered_log in "${encountered_logs[@]}"; do
        encountered_log_date=$(echo "$encountered_log" | awk -F '::' '{print $1}')
        encountered_log_date=$(echo "$encountered_log_date" | sed 's/\./-/g')  # convert dots to dashes so that date_to_epoch() needs it so
        encountered_log_epoch=$(date_to_epoch "$encountered_log_date")

        if [[ "$encountered_log_epoch" -ge "$twelve_hours_ago" ]]; then
            new_encountered_logs+=("$encountered_log") #filling up the new_encountered_logs just to filter the entries older than 12 hours
        fi
    done

    # replacing encountered_logs with the pruned list
    encountered_logs=("${new_encountered_logs[@]}")
    new_encountered_logs=()  # Clear the new_encountered_logs array for reuse
fi

#NOW - once we are done with checking the old strings/logs we are going to check whether there are new entries in the log file
# Read the last 100 lines from the log file
#keep in mind that we are reading only the last 100 lines of the log here due to the characteristics of this log where it is not expected at all to have more than 5-6 logs within 10minutes
#therefore here reading the last 100 lines is just to make sure that we are not going to miss a potential log
#if we should observer another log we must take into consideration its nature
while read -r line; do
    log_entries+=("$line")
done < <(tail -n 100 "$LOG_FILE")

echo "Number of log entries: ${#log_entries[@]}" #just echo-ing log einties for debug purposes

# Process log entries - once we have the entries lets check if there is some new log within last 10minutes

for line in "${log_entries[@]}"; do
    log_date=$(echo "$line" | awk -F '::' '{print $1}') #extract the time stamp of the log before the first "::"
    log_date=$(echo "$log_date" | sed 's/\./-/g')  #adjust it to be convertable in seconds
    raw_data=$(echo "$line" | awk -F '::' '{print substr($0, index($0, $2))}') # get the error message 
    sanitized_raw_data=$(sanitize_data "$raw_data")  # clear the error message from bad characters

    # get the time_diff between time now and the time of the entries
    epoch=$(date_to_epoch "$log_date")
    if [[ -n "$epoch" ]]; then
        time_diff=$((t2 - epoch))

        # check if log entry is within the last 10 minutes
        if ((time_diff >= 0 && time_diff <= 600)); then
            # check if sanitized raw_data is already in the encountered_logs array
            found=false
            for encountered_log in "${encountered_logs[@]}"; do
                encountered_log_raw_data=$(echo "$encountered_log" | awk -F '::' '{print substr($0, index($0, $2))}')
                sanitized_encountered_log_raw_data=$(sanitize_data "$encountered_log_raw_data")
                
                if [[ "$sanitized_raw_data" == "$sanitized_encountered_log_raw_data" ]]; then #if the same string is found do nothing
                    found=true
                    break
                fi
            done

            # If sanitized data is not found, send email and add to encountered logs
            if [[ "$found" == false ]]; then
                tobemail+="$raw_data\n"
                encountered_logs+=("$line") # fill up the array
            fi
        fi
    else
        echo "Invalid date found: $log_date - Skipping" # script is expected never to get to here!
    fi
done

# Send the email if there are new logs, check if there is something in tobemail
if [[ -n $tobemail ]]; then
    echo -e "$tobemail" | mail -s "There are some new logs in the error log" kiril.razpopov@dxc.com
    # Log the email content with timestamp to the history file
    echo "$(date) - Email sent with the following content:" >> "$EMAIL_SENT_HISTORY_FILE"
    echo -e "$tobemail" >> "$EMAIL_SENT_HISTORY_FILE"
    echo "------------------------" >> "$EMAIL_SENT_HISTORY_FILE"
fi

# print the encountered logs to be saved - for dev reasons
echo "Encountered logs to be saved:"
printf "%s\n" "${encountered_logs[@]}"

# save the updated encountered logs to file - the whole process repeats itself every X minutes
printf "%s\n" "${encountered_logs[@]}" > "$STORED_DATA_FILE"

#based on the variables"adjustments" here it script should be run every 10 minutes since it searches for logs not older than 10 minutes
# make a cron job with these settings: */10 * * * * /path/to/monscript.sh >/dev/null 2>&1
