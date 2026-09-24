#!/usr/bin/env bash
# =============================================================================
#  switch_audio.sh — Cycle the default PipeWire/PulseAudio output sink
# =============================================================================
#  Switches to the next available output device and moves any currently
#  playing streams across so audio does not get stuck on the old device.
#
#  Usage:  ./switch_audio.sh
# =============================================================================

set -euo pipefail

if ! command -v pactl >/dev/null 2>&1; then
  echo "pactl not found (is PulseAudio/PipeWire running?)" >&2
  exit 1
fi

CURRENT_SINK="$(pactl get-default-sink)"

# Pick the first sink that is not the current one.
NEXT_SINK="$(pactl list short sinks | awk '{print $2}' | grep -vx "$CURRENT_SINK" | head -n 1 || true)"

if [[ -z "$NEXT_SINK" ]]; then
  echo "No alternative audio sink found (current: $CURRENT_SINK)"
  exit 0
fi

pactl set-default-sink "$NEXT_SINK"

# Move all playing streams to the new sink.
pactl list short sink-inputs | awk '{print $1}' | while read -r stream; do
  pactl move-sink-input "$stream" "$NEXT_SINK"
done

echo "Switched audio sink: $CURRENT_SINK -> $NEXT_SINK"
