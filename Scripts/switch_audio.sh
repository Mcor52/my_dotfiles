#!/bin/bash

# 1. Get the current default sink name
CURRENT_SINK=$(pactl get-default-sink)

# 2. Get the name of the 'other' sink
# This assumes you have two main outputs.
NEXT_SINK=$(pactl list short sinks | awk '{print $2}' | grep -v "$CURRENT_SINK" | head -n 1)

# 3. Switch to the next sink
pactl set-default-sink "$NEXT_SINK"

# 4. Optional: Move all currently playing streams to the new sink
# (This stops audio from 'getting stuck' on the old device)
pactl list short sink-inputs | awk '{print $1}' | while read stream; do
    pactl move-sink-input "$stream" "$NEXT_SINK"
done
