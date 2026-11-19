# Audio test fixtures

16 kHz, mono, 16-bit PCM WAV (44-byte header). Used by
`test/services/zone_recordings_test.dart`.

| File | Contents |
|---|---|
| `gunshots_near_16k.wav` | "Gunshots 8.ogg" from Wikimedia Commons (public domain), resampled to 16 kHz, after a 3 s lead-in of -50 dBFS noise. The same noise bed is added under the recording. |
| `gunshots_distant_16k.wav` | A controlled "distant" version of the same recording: -14 dB, 2.5 kHz one-pole low-pass (no direct high frequencies), plus 0.9 s exponentially decaying reverb at +3 dB relative to the direct sound, over the same noise bed. |

The distant file is synthetic. It stands in for a shot from another lane,
not a measured one; replace or add real range recordings when available.
