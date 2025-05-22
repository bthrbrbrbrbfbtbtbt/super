#!/bin/bash

# --- Configuration ---
PYTHON_SCRIPT_NAME="rahul.py"
PYTHON_EXECUTABLE="python3" # or just "python" if that's your default for v3

DURATION_HOURS=4
# Delay in seconds between one run of rahul.py finishing and the next one starting.
# This prevents hammering the system if rahul.py exits very quickly (e.g., due to an error).
DELAY_BETWEEN_RUNS_SECONDS=5
# --- End Configuration ---

# Calculate end time
duration_seconds=$((DURATION_HOURS * 60 * 60))
start_time=$(date +%s) # Get current time in seconds since epoch
end_time=$((start_time + duration_seconds))

echo "----------------------------------------------------------"
echo "Continuous Runner for: ${PYTHON_SCRIPT_NAME}"
echo "----------------------------------------------------------"
echo "This script will run '${PYTHON_EXECUTABLE} ${PYTHON_SCRIPT_NAME}' repeatedly."
echo "Total duration: ${DURATION_HOURS} hours."
echo "Delay between runs: ${DELAY_BETWEEN_RUNS_SECONDS} seconds."
echo "Started at: $(date)"
echo "Will stop attempting new runs at approximately: $(date -d "@${end_time}")" # GNU date
# For macOS/BSD date: date -r "${end_time}"
echo "Press Ctrl+C to stop manually at any time."
echo "----------------------------------------------------------"
echo ""

run_count=0
while [ $(date +%s) -lt $end_time ]; do
    current_time_s=$(date +%s)
    remaining_seconds=$((end_time - current_time_s))

    if command -v gdate >/dev/null 2>&1; then
        remaining_hms=$(gdate -u -d "@${remaining_seconds}" +%H:%M:%S)
    elif date --version >/dev/null 2>&1 && [[ $(date --version) == *"GNU coreutils"* ]]; then
        remaining_hms=$(date -u -d "@${remaining_seconds}" +%H:%M:%S)
    else
        remaining_hms="${remaining_seconds}s"
    fi

    run_count=$((run_count + 1))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting run #${run_count} of '${PYTHON_SCRIPT_NAME}'. Time remaining: ${remaining_hms}"

    # Execute the Python script
    ${PYTHON_EXECUTABLE} ${PYTHON_SCRIPT_NAME}
    exit_status=$? # Capture the exit status of the Python script

    if [ $exit_status -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: ${PYTHON_SCRIPT_NAME} exited with status ${exit_status}."
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${PYTHON_SCRIPT_NAME} finished successfully (exit status ${exit_status})."
    fi

    # Check if time is up *after* the script has run
    current_time_s_after_run=$(date +%s)
    if [ $current_time_s_after_run -ge $end_time ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Duration of ${DURATION_HOURS} hours reached. Not starting another run."
        break
    fi

    # Wait before the next run, but ensure we don't wait past the end_time
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for ${DELAY_BETWEEN_RUNS_SECONDS}s before next run (if time permits)..."
    actual_sleep_duration=$DELAY_BETWEEN_RUNS_SECONDS
    if [ $((current_time_s_after_run + DELAY_BETWEEN_RUNS_SECONDS)) -gt $end_time ]; then
        actual_sleep_duration=$((end_time - current_time_s_after_run))
    fi

    if [ $actual_sleep_duration -gt 0 ]; then
        sleep $actual_sleep_duration
    elif [ $((end_time - current_time_s_after_run)) -le 0 ]; then # Double check if we are past end time
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No time left for further runs or delay."
        break
    fi
done

echo ""
echo "----------------------------------------------------------"
echo "Continuous runner script finished after (approximately) ${DURATION_HOURS} hours."
echo "Ended at: $(date)"
echo "Total runs of ${PYTHON_SCRIPT_NAME} attempted: ${run_count}"
echo "----------------------------------------------------------"

exit 0