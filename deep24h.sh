#!/bin/bash

# --- Configuration ---
PYTHON_SCRIPT_NAME="rahul.py"
PYTHON_EXECUTABLE="python3" # or just "python" if that's your default for v3

DURATION_HOURS=5
# Delay in seconds between one run of rahul.py finishing/crashing and the next one starting.
DELAY_BETWEEN_PYTHON_RUNS_SECONDS=5
# Interval in seconds for the independent keep-alive ping message.
KEEP_ALIVE_PING_INTERVAL_SECONDS=60
# --- End Configuration ---

# Calculate end time
duration_seconds=$((DURATION_HOURS * 60 * 60))
start_time=$(date +%s) # Get current time in seconds since epoch
end_time=$((start_time + duration_seconds))

keep_alive_pinger_pid=""

# Function to start a simple keep-alive ping in the background
start_background_pinger() {
    ( # Run in a subshell
        while true; do
            # Check if the main script's end time has been reached
            if [ $(date +%s) -ge $end_time ]; then
                # echo "[$(date '+%Y-%m-%d %H:%M:%S')] Background Pinger: Main duration reached. Exiting pinger." # Optional
                break
            fi
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Terminal Keep-Alive Ping: Session active."
            
            # Sleep, but check frequently if we need to exit sooner than the full interval
            # This makes the pinger more responsive to the main script ending.
            for (( i=0; i<${KEEP_ALIVE_PING_INTERVAL_SECONDS}; i++ )); do
                sleep 1
                if [ $(date +%s) -ge $end_time ]; then break; fi
            done
        done
    ) & # Run the subshell in the background
    keep_alive_pinger_pid=$! # Store the PID of the background pinger
    # Disown the pinger so it doesn't get SIGHUP if the terminal closes (when script itself is nohup'd)
    disown "$keep_alive_pinger_pid" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Started background terminal keep-alive pinger (PID: ${keep_alive_pinger_pid})."
}

# Function to stop the keep-alive pinger
stop_background_pinger() {
    if [ -n "$keep_alive_pinger_pid" ] && ps -p "$keep_alive_pinger_pid" > /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping background terminal keep-alive pinger (PID: ${keep_alive_pinger_pid})."
        kill "$keep_alive_pinger_pid" 2>/dev/null || true # Send TERM signal
        # Give it a moment to exit gracefully
        sleep 1
        if ps -p "$keep_alive_pinger_pid" > /dev/null; then
             kill -9 "$keep_alive_pinger_pid" 2>/dev/null || true # Force kill if still running
        fi
        wait "$keep_alive_pinger_pid" 2>/dev/null # Clean up zombie process
        keep_alive_pinger_pid=""
    fi
}

# Trap signals to ensure the background pinger is stopped on exit
# SIGINT (Ctrl+C), SIGTERM (kill command), EXIT (normal script exit)
trap 'echo ""; echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] Script interrupted or finishing. Cleaning up..."; stop_background_pinger; exit 0' SIGINT SIGTERM EXIT

echo "---------------------------------------------------------------------"
echo "Combined Runner for '${PYTHON_SCRIPT_NAME}' with Terminal Keep-Alive"
echo "---------------------------------------------------------------------"
echo "Python Script: ${PYTHON_EXECUTABLE} ${PYTHON_SCRIPT_NAME}"
echo "Total duration: ${DURATION_HOURS} hours."
echo "Delay between Python runs: ${DELAY_BETWEEN_PYTHON_RUNS_SECONDS} seconds."
echo "Terminal keep-alive ping interval: ${KEEP_ALIVE_PING_INTERVAL_SECONDS} seconds."
echo "Started at: $(date)"
echo "Will stop all operations at approximately: $(date -d "@${end_time}")" # GNU date
# For macOS/BSD date: date -r "${end_time}"
echo "Press Ctrl+C to stop manually at any time."
echo "---------------------------------------------------------------------"
echo ""

# Start the background pinger
start_background_pinger

run_count=0
# Main loop for running the Python script
while [ $(date +%s) -lt $end_time ]; do
    current_time_s_loop_start=$(date +%s)
    remaining_seconds_loop_start=$((end_time - current_time_s_loop_start))

    if command -v gdate >/dev/null 2>&1; then
        remaining_hms=$(gdate -u -d "@${remaining_seconds_loop_start}" +%H:%M:%S)
    elif date --version >/dev/null 2>&1 && [[ $(date --version) == *"GNU coreutils"* ]]; then
        remaining_hms=$(date -u -d "@${remaining_seconds_loop_start}" +%H:%M:%S)
    else
        remaining_hms="${remaining_seconds_loop_start}s"
    fi

    run_count=$((run_count + 1))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting run #${run_count} of '${PYTHON_SCRIPT_NAME}'. Overall time remaining: ${remaining_hms}"

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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Main duration of ${DURATION_HOURS} hours reached. Not starting another Python run."
        break
    fi

    # Wait before the next run, but ensure we don't wait past the end_time
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for ${DELAY_BETWEEN_PYTHON_RUNS_SECONDS}s before next Python run (if time permits)..."
    actual_sleep_duration=$DELAY_BETWEEN_PYTHON_RUNS_SECONDS
    time_until_end=$((end_time - current_time_s_after_run))

    if [ $actual_sleep_duration -gt $time_until_end ]; then
        actual_sleep_duration=$time_until_end
    fi

    if [ $actual_sleep_duration -gt 0 ]; then
        sleep $actual_sleep_duration
    elif [ $time_until_end -le 0 ]; then # Double check if we are past end time
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No time left for further Python runs or delay."
        break
    fi
done

echo ""
echo "---------------------------------------------------------------------"
echo "Main script loop finished after (approximately) ${DURATION_HOURS} hours."
echo "Ended at: $(date)"
echo "Total runs of ${PYTHON_SCRIPT_NAME} attempted: ${run_count}"
echo "The background terminal pinger will also stop shortly (if not already)."
echo "---------------------------------------------------------------------"

# The EXIT trap will handle stopping the pinger.
exit 0