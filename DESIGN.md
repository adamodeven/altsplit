# altsplit — design

A personal iPhone workout tracker built around a two-week alternating split,
with an accountability layer that is hard to ignore.

**Target: iOS 26**, SwiftUI + SwiftData, Liquid Glass design language.

## Principles

1. **Today is the app.** The home screen answers "what am I doing right now"
   and lets you act on it without navigating.
2. **One tap for anything daily.** Supplements, starting a workout, completing
   a set. If it happens every day it does not get a nav push.
3. **Stable geometry.** Home screen boxes never resize or reflow based on
   state. Muscle memory beats information density.
4. **Honest data.** A missed workout is recorded as missed. A snoozed alarm is
   recorded as snoozed. There is no pause mode — if you miss a week, you missed
   a week, and the record says so. Adherence numbers are only useful if they
   can go down.
5. **Local first.** No accounts, no server, no social features.

---

## The split

### Weekly shape

The weekly skeleton is identical in both phases. Only the exercises differ.

| Day | Groups | Session type |
|-----|--------|--------------|
| Mon | biceps, back | lifting |
| Tue | legs, shoulders | lifting |
| Wed | chest, triceps | lifting |
| Thu | — | rest |
| Fri | erg | cardio |
| Sat | double (focused group) | lifting |
| Sun | — | rest |

Phase A and phase B hit the same groups on the same days with **different
exercises** — different regions of the muscle, or a different stimulus
(plyometric / eccentric / isometric / tempo).

Because the shape is shared, it is defined once. A and B are two exercise
pools hanging off each day slot, not two independent programs.

### Phase resolution

```
phase = (weeksSince(anchorDate)) % 2      // 0 = A, 1 = B
```

Calendar-anchored, **not** completion-anchored. The split is a rhythm; a
missed week does not desync training from the calendar, it just logs as
missed. A manual "shift phase" control in settings covers the case where you
deliberately want to repeat a week.

### The double day

Saturday doubles a muscle group chosen by current goals.

**Resolution rule: the double serves the *other* phase's exercises for the
focused group.** In an A week focusing shoulders, Saturday runs phase B's
shoulder pool. No extra data entry, and the double is guaranteed to be a
different stimulus rather than a repeat.

The focus is a persistent setting (`currentFocus: MuscleGroup`) changed when
you decide it should be. The app prompts to reconfirm every 4 weeks so it
cannot go stale unnoticed. When picking, show trailing-4-week set volume per
group so the choice is informed by what you have actually been neglecting.

The double can also resolve to a second erg.

---

## Exercise typing

Two orthogonal axes. Conflating them is the mistake.

**`type`** determines *what the logging UI shows*:

| type | Logged fields |
|------|---------------|
| `.lift` | weight × reps, rest |
| `.hold` | duration, optional added weight |
| `.bodyweight` | reps, optional added weight |
| `.erg` | distance, time, split (per 500m), stroke rate |
| `.cardio` | distance, time |

**`modality`** is a descriptive tag: `.standard`, `.plyometric`, `.eccentric`,
`.isometric`, `.tempo`. It drives A/B differentiation and filtering ("show me
all my eccentric chest work").

The axes correlate but are not the same. A plyometric push-up is
`type: .bodyweight, modality: .plyometric` — logged exactly like a normal
push-up. A wall sit is `type: .hold, modality: .isometric` — logged in
seconds. Tempo bench is `type: .lift, modality: .tempo` with a tempo string in
notes.

---

## Data model

```
Program
  anchorDate: Date
  currentFocus: MuscleGroup

WeekTemplate                       // defined once, shared by both phases
  DayTemplate
    weekday: Weekday
    groups: [MuscleGroup]
    slotKind: .lifting | .cardio | .rest | .double
    poolA: [PlannedExercise]
    poolB: [PlannedExercise]

Exercise
  name: String
  type: .lift | .hold | .bodyweight | .erg | .cardio
  modality: .standard | .plyometric | .eccentric | .isometric | .tempo
  muscleGroup: MuscleGroup?        // nil for erg/cardio
  equipment: Equipment
  isUserCreated: Bool

PlannedExercise
  exercise: Exercise
  targetSets: Int
  targetReps: ClosedRange<Int>?    // nil for .hold / .erg / .cardio
  targetDuration: TimeInterval?
  restSeconds: Int
  notes: String?

WorkoutSession
  date: Date
  phase: .a | .b
  status: .completed | .missed | .partial
  entries: [SetEntry]
  cardioResult: CardioResult?

SetEntry
  exercise: Exercise
  setIndex: Int
  weight: Double?                  // canonical KILOGRAMS, always
  reps: Int?
  duration: TimeInterval?
  rpe: Double?
  isWarmup: Bool
  completedAt: Date?

CardioResult
  distanceMeters: Int
  duration: TimeInterval
  avgSplit: TimeInterval           // per 500m
  avgStrokeRate: Int?

CheckIn                            // weight + photo, atomically
  date: Date
  weight: Measurement<UnitMass>
  photoRef: String                 // app container, not camera roll
  cycleIndex: Int

SupplementLog
  date: Date
  protein: Bool
  creatine: Bool
```

---

## Navigation

Three tabs in the Liquid Glass tab bar. On iOS 26 the tab bar picks up the
glass treatment automatically; use `.tabBarMinimizeBehavior(.onScrollDown)` on
scrolling screens so charts and long lists get the full display.

| Tab | Purpose |
|-----|---------|
| **Home** | Today. Bento grid. |
| **Progress** | Body, lifting, and erg progress. Graphs. |
| **Builder** | Split editor and exercise library. |

---

## Home — bento grid

**Static box sizing. Boxes never resize, reflow, or appear/disappear based on
state.** A box with nothing to report shows a resting state at the same
footprint. This is the whole point: the workout button is always in the same
place under your thumb.

```
┌─────────────────────────────────────┐
│  WEEK B · TUESDAY                   │
│  Legs + Shoulders                   │   full width
│  5 exercises · ~48 min              │   tap → start workout
│                                     │   long press → preview
└─────────────────────────────────────┘
┌────────────────┐ ┌──────────────────┐
│   PROTEIN      │ │   CREATINE       │   side by side
│      ○         │ │       ●          │   tap → toggle
│   7 day streak │ │   26 / 30 days   │
└────────────────┘ └──────────────────┘
┌─────────────────────────────────────┐
│  WEIGH IN + PHOTO DUE               │   full width
│  Cycle 7 · last: 181.4 lb           │   tap → progress
└─────────────────────────────────────┘
```

The third box is the state-swapping one, and it swaps **content only**:

- *Due:* prompt to weigh in, tap opens the capture sheet.
- *Not due:* current weight, trend arrow, days until next check-in. Tap opens
  the Progress tab.

Interaction detail:

- **Tap the workout box** → straight into the active workout logger. No
  intermediate confirm screen.
- **Long press the workout box** → `.contextMenu(preview:)` showing the full
  exercise list for the day, so you can see what's coming without committing.
- **Tap a supplement box** → toggles immediately with a symbol transition. No
  confirmation, tap again to undo.

### Liquid Glass treatment

- Wrap the grid in a `GlassEffectContainer` so adjacent boxes blend and morph
  correctly rather than each compositing independently.
- `.glassEffect(.regular, in: .rect(corner: .concentric))` on each box.
  Concentric corners keep the radii visually consistent with the display
  corners and with nested content.
- `.glassEffect(.regular.interactive())` on the tappable boxes so they respond
  to touch with the standard glass deformation.
- Tint the workout box on a training day, leave it untinted on a rest day —
  colour carries the state, geometry does not move.
- `.buttonStyle(.glassProminent)` for the primary action inside the active
  workout screen.
- Background: `.backgroundExtensionEffect()` so content bleeds correctly under
  the tab bar and status bar rather than sitting in a letterbox.

Verify the exact modifier signatures against the current SDK when building —
the Liquid Glass APIs moved between betas.

---

## Accountability

iOS 26 offers a materially better primitive than earlier versions.

### AlarmKit — the hard tier

`AlarmKit` (new in iOS 26) schedules real alarms: they break through silent
mode and Focus, present alarm-style UI, and support a countdown plus custom
actions — without the Critical Alerts entitlement Apple will not grant a
personal app. This is the correct mechanism for the things that must not be
missed.

Use alarms for:

- **Workout start** on training days.
- **Weigh-in morning** at the start of each A-week.

An alarm's action should deep-link straight into the relevant screen, and the
alarm cancels the moment the task is completed.

### Notifications — the soft tier

Standard `UNUserNotificationCenter` for things that deserve a nudge but not a
klaxon:

- Protein / creatine, evening, with **notification actions** so they can be
  checked off without launching the app.
- Focus reconfirmation every 4 weeks.
- Cycle review at the end of each B-week.

An escalating cascade (schedule 3, cancel the remainder on completion) still
applies here, but it is now the fallback tier rather than the main event.

### Badge

Badge count = open items today (workout not logged, supplements not taken,
check-in due). Set via `UNUserNotificationCenter.setBadgeCount(_:)`.

### Honesty

Snoozes are logged. Missed sessions are written as `.missed` rather than
omitted. There is no pause or vacation mode.

---

## Weight + photo

Atomic at the model layer — there is no valid `CheckIn` with a nil weight or
a nil photo. Single sheet, save disabled until both exist.

- **Every 2 weeks, aligned to the cycle** — Monday morning of each A-week.
  Every photo is implicitly labelled "start of cycle N" and the timeline is
  evenly spaced by construction.
- **Onion-skin overlay.** Ghost the previous photo at ~30% opacity in the
  viewfinder so pose, distance, and framing match. Without this the photos are
  not comparable six months out, which defeats the point.
- **App container storage**, not the camera roll, with file protection on.
  The section sits behind Face ID.
- **One pose** (front) to start. Additional poses optional per check-in. Three
  is better data but materially higher friction, and friction kills this habit.

---

## Progress tab

The payoff screen. Build it early — it is the only thing that repays two weeks
of compliance, and it is what makes the habit stick.

**Body**
- Weight trend line with a rolling average overlay, photo thumbnails pinned
  along the time axis.
- Two-up photo compare with a date scrubber. Default to first-vs-latest,
  because that comparison is the most motivating one available.
- Cycle-over-cycle weight delta.

**Lifting**
- Estimated 1RM trend per exercise (Epley), which is the cleanest single
  progress signal across varying rep schemes.
- Volume per muscle group per cycle, as stacked bars — also feeds the double
  day focus decision.
- Personal-record feed: every time a set beats its previous best, it lands
  here. Cheap to compute, disproportionately motivating.
- A/B comparison: phase A vs phase B performance on the same muscle group.

**Erg**
- Split trend over time, distance-normalised so a 2k and a 5k are comparable.
- Distance accumulated per cycle.
- Best efforts per standard distance (500m / 1k / 2k / 5k / 10k).

**Adherence**
- Sessions completed vs planned per cycle.
- Supplement consistency, 30-day window.
- Current streak and longest streak.

Swift Charts throughout. iOS 26 adds `Chart3D`; ignore it here — 3D charts
would hurt readability for every series in this app.

---

## Builder tab

### Split editor

- Pick muscle groups per weekday.
- For each day, edit the phase A pool and the phase B pool side by side, so
  the differentiation between them is visible while you make it.
- Add exercises from the library, set target sets / reps / rest.
- Reorder within a day.
- Set the double day focus.

### Exercise library

- Preloaded with a solid default library covering the standard movements for
  each muscle group, plus erg pieces.
- Add custom exercises with type, modality, muscle group, and equipment.
- Filter by muscle group, type, modality, equipment.
- Each exercise shows where it is used in the split and its history, so you
  can tell at a glance whether it is actually earning its slot.
- User-created exercises are flagged so a library refresh never overwrites
  them.

---

## Stack

- SwiftUI + SwiftData
- iOS 26 minimum
- Local-first, no server, no accounts
- Swift Charts for the progress tab
- AlarmKit for the hard reminder tier
- App icon built in Icon Composer, so it renders correctly with the Liquid
  Glass icon treatment (clear / tinted / dark variants)

### Provisioning

Free provisioning covers all of v1: the app, SwiftData, local notifications,
and AlarmKit.

It does not cover App Groups (and therefore widgets and Control Center
controls), HealthKit, or CloudKit. It also requires re-signing every 7 days,
which is disqualifying long-term for an app meant to be relied on daily — so
the $99 is a "when I start living in it" purchase, not a "before I start"
purchase.

---

## Scope

**v1 — free provisioning**

- Program definition, phase resolution, double-day resolution
- Bento home
- Active workout logger (lift / hold / bodyweight)
- Supplement toggles
- Weight + photo check-in with onion-skin
- AlarmKit alarms + notification soft tier + badge
- Builder: split editor and exercise library
- Progress: body and lifting

**v2 — after the $99**

- Widgets and Control Center controls
- **Live Activity on weigh-in days**, persisting until the check-in is
  recorded
- Live Activity rest timer during workouts
- HealthKit (write workouts for ring credit, read bodyweight)
- CloudKit private sync

**v3**

- Erg-specific logging depth and erg progress charts
- Focus suggestions computed from trailing volume
- Plate maths, supersets, warmup auto-generation
- **One-tap lb ⇄ kg switching** (see below)

### Unit switching

One-tap toggle between pounds and kilograms, settable per workout and
changeable *dynamically* — mid-session during an active workout, or
afterwards when reviewing it.

Design constraints this implies:

- **Weight is stored canonically in kilograms, always.** The toggle is a
  display and entry-conversion concern that never mutates stored values, so
  flipping units mid-workout cannot corrupt history and every chart stays
  comparable regardless of what was typed. This needs to be true from the
  first line of the logger — retrofitting a canonical unit after real data
  exists is a migration, so it is noted here despite the feature itself being
  later.
- Preference persists on the `WorkoutSession` (so a session reviewed later
  reads back the way it was entered), over a global default in settings.
- Display rounding to sensible increments — 0.5 lb, 0.25 kg — while keeping
  full precision stored. Converted values otherwise render as noise like
  "83.91 kg".
- Plate maths, when it arrives, has to follow the active unit: 45/25/10/5/2.5
  lb versus 20/15/10/5/2.5 kg are different plate sets, not a conversion of
  one another.
