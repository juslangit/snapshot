# Snapshot

A photography game. One kampung morning, a camera with real settings, and a
client who wants three pictures.

You walk into a yard with a camera in your hands. A client has sent a brief —
three photographs, each with something specific they want. Aperture, shutter
speed and ISO do here exactly what they do on a real camera, and the pictures
are marked the same way: open the aperture and the background falls away, but
the frame fills with light; speed the shutter up to stop the hen mid-step and
the light drains out again; buy it back with ISO and the picture goes grainy.
That trade is the game.

Every score comes with the number it came from — *"the cat at 2.8 m; sharp from
2.7 m to 2.9 m"* — so a bad mark is a lesson rather than a verdict.

## Playing it

```sh
open -a Godot --args --path "$(pwd)"     # or press Play in the editor
```

| Control | What it does |
|---|---|
| `W A S D` | walk, `Shift` to hurry |
| mouse | look |
| `C` | crouch, and again to stand (`Ctrl` crouches while held) — a cat photographed from standing height is a picture of the top of a cat |
| `1` `2` | aperture, a full stop per press |
| `3` `4` | shutter speed |
| `5` `6` | ISO |
| `[` `]` | focus nearer / further |
| `F` | focus on whatever is in the middle of the frame, the way autofocus does |
| scroll | focal length, 24 mm to 135 mm |
| `Q` `E` | tilt the camera, `R` to level it |
| `G` | the thirds grid |
| `Tab` | switch to another shot on the brief |
| left click | take the picture |
| `Esc` | pause (and "back" on every menu screen) |

## How it is put together

| Where | What |
|---|---|
| `scripts/optics.gd` | the photography — exposure value, depth of field, hyperfocal distance, grain. No scene tree, all checked headless |
| `scripts/camera_body.gd` | the camera. Godot's physical camera attributes turn the dials into the picture; the photograph is built by rendering the exposure several times and averaging, so motion blur is real |
| `scripts/judge.gd` | the marking. Takes a Reading and a line of the brief and returns a score with a sentence for every mark |
| `scripts/brief.gd` | the three clients and their nine shots |
| `scripts/kampung.gd` | the yard, built from primitives, with downloaded props scaled by the height they should be in real life |
| `scripts/meter_probe.gd` | a 96×54 second view of the scene, used as the light meter so the viewfinder overlay cannot fool it |
| `dev/checks/` | five suites, 192 checks — run `tools/check.sh` |
| `dev/looks/` | harnesses that drive the real game and save screenshots into `dev/shots/`, which is how the art gets reviewed at all |

## Checks

```sh
./tools/check.sh
```

`_optics` and `_judge` are arithmetic and run headless. `_scene` builds the yard
and measures it. `_light` and `_flow` need a window, because one of them meters
a rendered frame and the other takes real photographs.

The check worth knowing about is `_light`. It stands where the first brief is
shot from, sets the camera to f/8 at 1/125 and ISO 100 — which is EV 13, a
bright morning — and insists the frame comes out near middle grey. Whenever
somebody repaints a wall, the light needs recalibrating, and that check is what
says so.

## Swapping the art

Every prop in the yard is a placeholder. `scripts/kampung.gd` scales each model
by the height it is supposed to be in real life, so replacing one is a matter of
dropping in a better mesh and leaving the height alone — the judge goes on
marking the same way, because it measures how much of the frame a subject fills
rather than how many units tall the model is.

Credits for the models and sounds are in `CREDITS.md`.
