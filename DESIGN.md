# altsplit — design

A personal iPhone workout tracker built around a two-week alternating split,
with an accountability layer that is hard to ignore.

## Principles

1. **Today is the app.** The home screen answers "what am I doing right now"
   and lets you act on it without navigating.
2. **One tap for anything daily.** Supplements, starting a workout, completing
   a set. If it happens every day it does not get a nav push.
3. **Honest data.** A missed workout is recorded as missed, not omitted. A
   snoozed reminder is recorded as snoozed. Adherence numbers are only useful
   if they can go down.
4. **Local first.** No accounts, no server, no social features.

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
(plyometric / isometric / eccentric / tempo).

Because the shape is shared, it is defined once. A and B are two exercise
pools hanging off each day slot, not two independent programs.

### Phase resolution

```
phase = (weeksSince(anchorDate) / 1) % 2   // 0 = A, 1 = B
```

Calendar-anchored, **not** completion-anchored. The split is a rhythm; a
missed week should not permanently desync training from the calendar. A
manual "shift phase" control in settings covers the case where you genuinely
want to repeat a week.

### The double day

Saturday doubles a muscle group chosen by current goals.

**Resolution rule: the double serves the *other* phase's exercises for the
focused group.** In an A week focusing shoulders, Saturday runs phase B's
shoulder pool. This needs no extra data entry and guarantees the double is a
different stimulus rather than a repeat.

The focus is a persistent setting (`currentFocus: MuscleGroup`) that changes
when you decide it should. The app prompts to reconfirm every 4 weeks so it
cannot go stale unnoticed — that prompt doubles as an accountability
touchpoint. When picking, show trailing-4-week set volume per group so the
choice is informed by what you have actually been neglecting.

### Erg day

Rowing is logged as distance / time / split / stroke rate, not sets and reps.
`sessionType` is a first-class enum from day one (`lifting` | `cardio`) with
separate logging screens and separate "last time" comparisons. A Saturday
double is occasionally a second erg, so the double day must be able to
resolve to a cardio session too.

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
    sessionType: .lifting | .cardio | .rest | .double
    poolA: [PlannedExercise]
    poolB: [PlannedExercise]

Exercise
  name: String
  muscleGroup: MuscleGroup
  modality: .standard | .plyometric | .isometric | .eccentric | .tempo
  equipment: Equipment

PlannedExercise
  exercise: Exercise
  targetSets: Int
  targetRepRange: ClosedRange<Int>
  notes: String?

WorkoutSession
  date: Date
  phase: .a | .b
  status: .completed | .missed | .partial
  sessionType: .lifting | .cardio
  entries: [SetEntry] | cardioResult: CardioResult

SetEntry
  exercise: Exercise
  setIndex: Int
  weight: Double
  reps: Int
  rpe: Double?
  isWarmup: Bool

CardioResult
  distanceMeters: Int
  duration: TimeInterval
  avgSplit: TimeInterval        // per 500m
  avgStrokeRate: Int?

CheckIn                           // weight + photo, atomically
  date: Date
  weight: Measurement<UnitMass>
  photoRef: String               // app container, not camera roll
  cycleIndex: Int

SupplementLog
  date: Date
  protein: Bool
  creatine: Bool
```

`modality` being first-class is what makes the A/B distinction queryable
later ("show me all my eccentric chest work").

---

## Accountability

iOS has no true persistent notification. What actually works, in order of
effectiveness:

- **Escalating cascade.** Schedule 3–4 notifications (e.g. 18:00, 19:30,
  21:00); cancel the remainder the instant the task is checked off. One
  notification is nothing. Three that keep coming back is accountability.
  This is the primary mechanism.
- **Time Sensitive interruption level.** Breaks through Focus modes. Needs
  only an Xcode entitlement, unlike Critical Alerts which require Apple
  approval that a personal app will not get. *(Paid account.)*
- **Notification actions.** Check off protein / creatine directly from the
  notification without launching the app.
- **Badge count** = open items today.
- **Live Activity** during an active workout — rest timer on the lock screen
  and Dynamic Island. 8-hour cap is not a constraint here. *(Paid account.)*
- **Widget in an incomplete state.** Passive, constant, on the home screen.
  *(Paid account — needs App Groups.)*

Snoozes are logged, not free. Four snoozes on a weigh-in should be visible.

### Reminder schedule

| Trigger | Cadence |
|---------|---------|
| Workout | On training days, cascade starting late afternoon |
| Protein / creatine | Daily cascade, evening |
| Weight + photo | Monday morning of each A-week (every 2 weeks) |
| Focus reconfirm | Every 4 weeks |
| Cycle review | Sunday night at end of each B-week |

---

## Weight + photo

Enforced atomic at the model layer — there is no valid `CheckIn` with a nil
weight or a nil photo. Single sheet, save disabled until both exist.

- **Onion-skin overlay.** Ghost the previous photo at ~30% opacity in the
  viewfinder so pose, distance, and framing match. Without this the photos
  are not comparable six months out, which defeats the point.
- **App container storage**, not the camera roll, with file protection on.
  The whole section sits behind Face ID.
- **One pose** to start (front). Additional poses optional per check-in —
  three poses is better data but materially higher friction, and friction is
  the thing that kills this habit.
- Aligned to the cycle, so every photo is implicitly labelled "start of cycle
  N" and the timeline is evenly spaced.

**Payoff view** (build this early, not as a v2 nicety — it is the entire
reason the habit sticks): weight trend chart with photo thumbnails pinned
along the time axis, plus a two-up compare with a date scrubber.

---

## Supplements

Trivially simple data; the surfaces are the point.

- Home screen toggles, one tap each
- Notification actions
- Control Center / Lock Screen / Action Button controls *(paid account)*
- Interactive widget *(paid account)*
- App Shortcut → "Hey Siri, log creatine"

Creatine is about saturation, so the useful stat is "26 of the last 30 days"
rather than a streak. Protein powder reads better as a streak.

---

## Home screen

Everything above the fold. No navigation for anything daily.

```
┌─────────────────────────────┐
│ WEEK B · TUESDAY            │
│ Legs + Shoulders            │
│ [    START WORKOUT     ]    │
├─────────────────────────────┤
│ ☐ Protein    ☐ Creatine     │
├─────────────────────────────┤
│ ⚠ Weigh-in + photo due      │   (only when due)
├─────────────────────────────┤
│ Cycle adherence: 9/10       │
└─────────────────────────────┘
```

Rest days render a rest state and keep the supplement row. Never a blank
hole, or the app stops being a daily habit on Thursdays and Sundays.

---

## Active workout

Strong-like. Pre-loaded from today's resolved template, so there is no
"choose a workout" step.

- **"Last time" prefill comes from the same exercise**, not the same day.
  Week B chest is a different pool from Week A chest, so "last chest day" is
  a meaningless comparison.
- Auto-start rest timer on set completion.
- Screen stays awake during a session.
- Inline previous performance: "last time: 3×8 @ 135".
- Partial sessions save as `.partial` rather than being discarded.

---

## Stack

- SwiftUI + SwiftData
- iOS 18 minimum (required for Control Center controls in phase 2)
- Local-first, no server, no accounts
- CloudKit private database for sync/backup *(paid account)*
- HealthKit: write workouts for Fitness ring credit, read bodyweight *(paid
  account)*

### Provisioning constraints

Free provisioning supports the whole of v1: the app itself, standard local
notifications, and local SwiftData.

It does **not** support App Groups (and therefore widgets and Control Center
controls), HealthKit, CloudKit, or Time Sensitive notifications. It also
requires re-signing every 7 days, which is disqualifying for an app meant to
be relied on daily.

The $99/yr account is what unlocks phase 2. Worth buying at the point the app
becomes something you live in rather than something you are building.

---

## Scope

**v1 — buildable on free provisioning**

- A/B program definition and phase resolution
- Today view
- Active lifting workout logging
- Supplement toggles
- Weight + photo check-in with onion-skin
- Escalating local notifications

**v2 — needs the paid account**

- Widgets and Control Center controls
- Live Activity rest timer
- HealthKit and CloudKit sync
- Time Sensitive notifications

**v3**

- Erg-specific logging and cardio history
- Volume and progression charts
- Focus suggestions from trailing volume
- Photo comparison scrubber
