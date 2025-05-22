#!/bin/bash

# --- Configuration ---
DURATION_HOURS=5
INTERVAL_SECONDS=60 # How often to print a keep-alive message (e.g., every 60 seconds)
# --- End Configuration ---

# Calculate end time
duration_seconds=$((DURATION_HOURS * 60 * 60))
start_time=$(date +%s) # Get current time in seconds since epoch
end_time=$((start_time + duration_seconds))

echo "----------------------------------------------------------"
echo "Deepnote Terminal Keep-Alive Script"
echo "----------------------------------------------------------"
echo "This script will attempt to keep the terminal session active by printing periodic messages."
echo "It will run for: ${DURATION_HOURS} hours."
echo "It will print a message every: ${INTERVAL_SECONDS} seconds."
echo "Started at: $(date)"
echo "Will end at approximately: $(date -d "@${end_time}")" # GNU date specific
# For macOS/BSD date, you might need: date -r "${end_time}"
echo "Press Ctrl+C to stop manually at any time."
echo "----------------------------------------------------------"
echo "" # Newline for readability

count=0
while [ $(date +%s) -lt $end_time ]; do
    current_time_s=$(date +%s)
    remaining_seconds=$((end_time - current_time_s))

    # Format remaining time (HH:MM:SS)
    if command -v gdate >/dev/null 2>&1; then # Check for GNU date (often gdate on macOS)
        remaining_hms=$(gdate -u -d "@${remaining_seconds}" +%H:%M:%S)
    elif date --version >/dev/null 2>&1 && [[ $(date --version) == *"GNU coreutils"* ]]; then # Check if default date is GNU
        remaining_hms=$(date -u -d "@${remaining_seconds}" +%H:%M:%S)
    else # Fallback for non-GNU date (e.g. macOS default) - just show seconds
        remaining_hms="${remaining_seconds}s"
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ping ${count}. Terminal session active. Remaining: ${remaining_hms}"

    # Determine how long to sleep
    sleep_duration=$INTERVAL_SECONDS
    if [ $((current_time_s + INTERVAL_SECONDS)) -gt $end_time ]; then
        sleep_duration=$((end_time - current_time_s))
    fi

    if [ $sleep_duration -gt 0 ]; then
        sleep $sleep_duration
    elif [ $remaining_seconds -le 0 ]; then
        break
    fi
    count=$((count + 1))
done

echo ""
echo "----------------------------------------------------------"
echo "Keep-alive script finished after ${DURATION_HOURS} hours."
echo "Ended at: $(date)"
echo "----------------------------------------------------------"

exit 0