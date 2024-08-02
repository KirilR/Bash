#!/bin/bash

LOG_FILE=/root/temp2/testlog

# empty array i parser-time forma fukciata
log_entries=()
date_to_epoch() {
    date --date "$1" +"%s"
}

# chetem poslednite 100 reda
while read -r line; do
    # Add the full line to the array
    log_entries+=("$line")
done < <(tail -n 100 "$LOG_FILE")

echo "${#log_entries[@]}"
tobemail=""
current_time=$(date +"%Y.%m.%d %H:%M:%S")
#tva dolu go pravim zashtoto date to epoh funkciata im nujda ot toia format
current_time=$(echo "$current_time" | sed 's/\./-/g')
t2=$(date_to_epoch "$current_time")
for line in "${log_entries[@]}"; do
log_date=$(echo "$line" | awk -F '::' '{print $1}')
raw_data=$(echo "$line" | awk -F '::' '{print substr($0, index($0, $2))}')
log_date=$(echo "$log_date" | sed 's/\./-/g')
echo $log_date -tvae log datatata
#echo $raw_data - tva e raw datata
epoch=$(date_to_epoch "$log_date")
time_diff=$((t2 - epoch))
if ((time_diff >= 0 && time_diff <= 600)); then
    #printf "Date %s is within the last 10 minutes.\n"
    #printf "%s\n" "$raw_data"
    tobemail+="$raw_data\n"
    fi
done
if [[ -n $tobemail ]]; then
    echo -e "$tobemail" | mail -s "There are some new logs in the error log" exampleKiro@mail.com
    tobemail=""
fi
