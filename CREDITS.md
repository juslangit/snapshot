# Credits

Snapshot is built in Godot 4.7.2. The house, the shed wall, the fence, the
laundry, the ground and every blade of grass are built from primitives in
`scripts/kampung.gd`. Everything below came from somewhere else.

## Models

All from Sketchfab, all under Creative Commons Attribution (CC BY 4.0), which
requires the credit below and permits commercial use.

| In the game | Model | Author |
|---|---|---|
| the cat | [Cat Sitting](https://sketchfab.com/3d-models/f668e55f12d8460f898545855b0f244d) | Chaitanya Krishnan |
| the banana trees | [Banana Tree (Low Poly)](https://sketchfab.com/3d-models/97a50ee6d93d4d8cb2c455a64a6d17c2) | EmiyaSyahriel |
| the well | [Old Well with Hanging Bucket](https://sketchfab.com/3d-models/7fa29793eff14a7587ee0af15446a675) | Glowbox 3D |
| the kettle | [Chinese Kettle](https://sketchfab.com/3d-models/f1a02a32791a44c8b97b71360abb8e31) | Tejay21 |
| the hen | [Handpainted rooster and hen](https://sketchfab.com/3d-models/34b79d3f8adb43c583d08babf3ef6dc0) | Enkarra |

Each model keeps its own `ATTRIBUTION.md` beside it in
`assets/sketchfab/<name>/`, written by the `sketchfab` tool when it was
downloaded, so provenance travels with the file.

## Sound

All from Freesound, all released under CC0 (public domain — no credit required,
but recorded here anyway because somebody made them).

| In the game | Sound | Author |
|---|---|---|
| the shutter | [shutter click canon eos 5D mark ii or iii](https://freesound.org/people/chrisvink/sounds/270435/) | chrisvink |
| the dial clicks | the same recording, trimmed to 80 ms | chrisvink |
| the morning | [morning_birds_ambience](https://freesound.org/people/vibe_crc/sounds/50619/) | vibe_crc |
| the rooster | [Fowl - Chicken, Rooster Crow](https://freesound.org/people/TheKingOfGeeks360/sounds/839538/) | TheKingOfGeeks360 |

The originals are kept in `assets/audio/freesound/` with a `SOURCES.md`; the
files the game actually loads are the PCM conversions beside them, because
Godot cannot import a 24-bit WAV.

## Sky

[Kloofendal 38d Partly Cloudy (Pure Sky)](https://polyhaven.com/a/kloofendal_38d_partly_cloudy_puresky)
by Greg Zaal and Jarod Guest, from Poly Haven, CC0 (no credit required). Used at
4k with the sun disc clamped out of it
(`assets/polyhaven/hdri/kloofendal_38d_partly_cloudy_puresky_4k_sunless.hdr`),
because the yard's sun is the calibrated `Sun` light and the sky is only there
to be looked at.

## The photography

The formulas in `scripts/optics.gd` are the standard ones — the exposure value
equation, the thin-lens depth of field formulas, the hyperfocal distance, and a
0.029 mm circle of confusion for a 35 mm frame. They are checked in
`dev/checks/_optics.gd` against published depth of field and hyperfocal tables
and against the sunny 16 rule, so the game teaches the same numbers a
photographer would use.
