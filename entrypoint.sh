#!/bin/bash

# Define a function to handle termination signals
handle_term() {
  echo "Received termination signal. Shutting down gracefully..."
  kill $(jobs -p)
  exit 0
}

# Register the signal handlers
trap handle_term SIGTERM SIGINT SIGHUP

# Start the scheduler in background
(
  while true; do
    # Get current time
    current_minute=$(date +%M)
    current_hour=$(date +%H)
    
    # If it's the top of the hour (minute is 00)
    if [ "$current_minute" == "00" ]; then
      echo "Running hourly update at $(date)"
      python -m bgmi update --download
      
      # If it's midnight (00:00)
      if [ "$current_hour" == "00" ]; then
        echo "Running daily calendar update at $(date)"
        python -m bgmi cal --force-update
      fi
    fi
    
    # Wait for the next minute before checking again
    sleep 60
  done
) &

# Start the main application server
echo "Starting BGmi server..."
python -m bgmi.front.nice_server --host 0.0.0.0 --port 8080
