# FFmpeg Encode Script (AV1 / HEVC presets)

This script is an interactive FFmpeg wrapper for encoding MKV files with careful control over video quality, grain preservation, audio/subtitle selection, and optional preview or shutdown behavior.

It is designed for high-quality archival encodes first, with predictable results rather than maximum speed.

## Features

- Automatic source inspection (resolution, HDR detection)
- Interactive resolution selection (1080p / 4K)
- Content-aware presets:
  -- Black & White
  -- Film-grained colour
  -- Modern clean colour
- Manual selection of:
  -- Audio tracks (copied losslessly)
  -- Subtitle tracks (copied losslessly)
- Optional 1-minute preview encode
- Optional system shutdown after completion (requires sudo)
- 10-bit video output for reduced banding
- No filtering that would destroy film grain

## Requirements
- ffmpeg
- ffprobe
- Bash (Linux / macOS)

## AV1 encoding requires:
- libsvtav1 support in FFmpeg

## Usage
./av1_encode_helper.sh input.mkv


If no input file is provided, the script will exit with a usage message.

How it works
1. Media inspection

Detects source resolution

Detects HDR transfer characteristics (PQ / HLG)

2. Resolution handling

Sources ≤1080p are forced to 1080p output

Higher-resolution sources prompt for:

1080p downscale

or native 4K

Scaling uses Lanczos when enabled.

3. Content presets

You’ll be prompted to select a content preset:

Preset	Use case
Black & White	Older films, high grain
Film-grained colour	Cinematic colour with texture
Modern colour	Clean digital sources

Each preset adjusts AV1 parameters to balance compression and grain retention.

4. Audio handling

All available audio tracks are listed

You select which tracks to include

Selected tracks are copied without re-encoding

This preserves original quality and avoids sync issues.

5. Subtitle handling

All subtitle tracks are listed

Optional selection

Selected subtitles are copied as-is

If no subtitles are selected, none are included.

6. Preview mode

If enabled:

Encodes a 60-second segment starting at 10 minutes

Useful for quick quality checks before a full encode

7. Output

Output file is named automatically:

<basename>-av1-<resolution>.mkv


Examples:

FilmName-av1-1080p.mkv

FilmName-av1-4K.mkv

8. Shutdown option

If enabled, the system will shut down 60 seconds after a successful encode.

Useful for long overnight runs.

Notes & Design Philosophy

Quality and consistency are prioritised over speed

Grain is preserved — no denoising or sharpening is applied

GPU acceleration is intentionally not used

10-bit output is always enabled to reduce banding

Audio and subtitles are never altered unless explicitly requested

Caveats

Encoding can be slow, especially for 4K content

AV1 playback requires compatible hardware or software players

This script assumes MKV input

License

Personal use. Modify freely.
But as-is, this should be exactly what future-you wants to read 👍

