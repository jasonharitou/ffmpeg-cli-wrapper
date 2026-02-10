#!/usr/bin/env bash

INPUT="$1"

if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo "Usage: $0 <input.mkv>"
  exit 1
fi

command -v ffmpeg >/dev/null || { echo "ffmpeg not found"; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe not found"; exit 1; }

echo
echo "=== Inspecting media ==="
echo

################################
# Detect resolution
################################
IFS=',' read -r WIDTH HEIGHT < <(
  ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height \
  -of csv=p=0 "$INPUT"
)

echo "Source resolution: ${WIDTH}x${HEIGHT}"

################################
# Output target
################################
echo
echo "Select output target:"
echo "  (1) AV1 (archive / main encode)"
echo "  (2) iPad (HEVC 720p, stereo, small size)"
read -rp "Choice [1]: " TARGET
TARGET="${TARGET:-1}"

################################
# AV1 resolution logic (unchanged)
################################
SCALE_FILTER=""
TARGET_LABEL="4K"

if [[ "$TARGET" == "1" ]]; then
  if (( WIDTH <= 1920 )); then
    echo "Input is 1080p or lower → output forced to 1080p"
    TARGET_LABEL="1080p"
  else
    echo
    read -rp "Output resolution? (1) 1080p  (2) 4K [2]: " RES_CHOICE
    RES_CHOICE="${RES_CHOICE:-2}"

    if [[ "$RES_CHOICE" == "1" ]]; then
      SCALE_FILTER="-vf scale=1920:-2:flags=lanczos"
      TARGET_LABEL="1080p"
    fi
  fi
fi

################################
# Detect HDR (unchanged)
################################
HDR_TRANSFER=$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=color_transfer \
  -of default=nw=1:nk=1 "$INPUT")

if [[ "$HDR_TRANSFER" =~ (smpte2084|arib-std-b67) ]]; then
  HDR="yes"
  echo "HDR detected: Yes"
else
  HDR="no"
  echo "HDR detected: No"
fi

################################
# Preset selection (AV1 only)
################################
if [[ "$TARGET" == "1" ]]; then
  echo
  echo "Select content preset:"
  echo "  (1) Black & White"
  echo "  (2) Film-grained colour"
  echo "  (3) Modern colour (clean)"
  read -rp "Preset [3]: " PRESET
  PRESET="${PRESET:-3}"

  case "$PRESET" in
    1)
      echo "Using Black & White preset"
      AV1_OPTS=(-crf 28 -preset 4)
      ;;
    2)
      echo "Using Film-grained colour preset"
      AV1_OPTS=(-crf 30 -preset 4)
      ;;
    *)
      echo "Using Modern colour preset"
      AV1_OPTS=(-crf 30 -preset 4)
      ;;
  esac
fi

################################
# Audio tracks
################################
echo
echo "Audio tracks:"

mapfile -t AUDIO_STREAMS < <(
  ffprobe -v error -select_streams a \
  -show_entries stream=index,codec_name,channels,channel_layout:stream_tags=language,title \
  -of csv=p=0 "$INPUT"
)

for i in "${!AUDIO_STREAMS[@]}"; do
  IFS=',' read -r idx codec ch layout lang title <<< "${AUDIO_STREAMS[$i]}"
  echo "  [$i] stream $idx | ${lang:-und} | $codec | ${ch}ch (${layout:-?}) | ${title:-no title}"
done

echo
read -rp "Select audio tracks to include (comma separated): " AUDIO_SELECTION
IFS=',' read -ra AUDIO_IDX <<< "$AUDIO_SELECTION"

################################
# Subtitles
################################
echo
echo "Subtitle tracks:"

mapfile -t SUB_STREAMS < <(
  ffprobe -v error -select_streams s \
  -show_entries stream=index,codec_name:stream_tags=language \
  -of csv=p=0 "$INPUT"
)

for i in "${!SUB_STREAMS[@]}"; do
  IFS=',' read -r idx codec lang <<< "${SUB_STREAMS[$i]}"
  echo "  [$i] stream $idx | $codec | ${lang:-und}"
done

echo
read -rp "Select subtitle tracks to include (comma separated, blank for none): " SUB_SELECTION
IFS=',' read -ra SUB_IDX <<< "$SUB_SELECTION"

################################
# Preview & shutdown
################################
echo
read -rp "Preview 1 minute only? (y/n): " PREVIEW
echo
read -rp "Shut down after encode completes? (y/n): " DO_SHUTDOWN

################################
# Output naming
################################
BASENAME="$(basename "$INPUT" .mkv)"

if [[ "$TARGET" == "2" ]]; then
  OUTFILE="${BASENAME}-ipad-720p.mkv"
else
  OUTFILE="${BASENAME}-av1-${TARGET_LABEL}.mkv"
fi

################################
# Build ffmpeg command
################################
CMD=(ffmpeg -y -hide_banner -loglevel error -stats -nostdin)

[[ "$PREVIEW" =~ ^[Yy]$ ]] && CMD+=(-ss 00:10:00 -t 60)

CMD+=(-i "$INPUT")

################################
# Video
################################
if [[ "$TARGET" == "2" ]]; then
  CMD+=(
    -map 0:v:0
    -vf scale=-2:720
    -c:v libx265
    -pix_fmt yuv420p10le
    -profile:v main10
    -crf 24
    -preset slow
  )
else
  CMD+=(
    -map 0:v:0
    -c:v libsvtav1
    -pix_fmt yuv420p10le
    "${AV1_OPTS[@]}"
  )
  [[ -n "$SCALE_FILTER" ]] && CMD+=($SCALE_FILTER)
fi

################################
# Audio
################################
AOUT=0
for sel in "${AUDIO_IDX[@]}"; do
  CMD+=(-map 0:a:$sel)
  if [[ "$TARGET" == "2" ]]; then
    CMD+=(-c:a:$AOUT aac -ac:a:$AOUT 2 -b:a:$AOUT 128k)
  else
    CMD+=(-c:a:$AOUT copy)
  fi
  ((AOUT++))
done

################################
# Subtitles
################################
for sel in "${SUB_IDX[@]}"; do
  CMD+=(-map 0:s:$sel? -c:s copy)
done

CMD+=("$OUTFILE")

################################
# Run
################################
echo
echo "=== Starting encode ==="
echo "${CMD[*]}"
echo

"${CMD[@]}"
STATUS=$?

if [[ $STATUS -eq 0 && "$DO_SHUTDOWN" =~ ^[Yy]$ ]]; then
  echo "Encoding finished. Shutting down in 60 seconds."
  sleep 60
  sudo shutdown -h now
fi
