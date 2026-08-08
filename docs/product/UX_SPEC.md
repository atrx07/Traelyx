# Traelyx — UI, Interaction & Animation Specification

## When to read

Read relevant sections for UI, navigation, replay, design-system, accessibility, onboarding, or animation work. Do not read for isolated backend/ML training tasks.

## 1. Design identity

Desired feel:

> Minimal automotive instrumentation + rich analytical surfaces + restrained but delightful motion + clear hierarchy + personality.

Avoid:

- generic neon "gaming speedometer" styling;
- cluttered fleet dashboards;
- competitor imitation;
- decorative gradients that obscure semantic status;
- excessive animation during live driving.

## 2. Theme

Dark-first design is the MVP default because it suits night driving, OLED devices, and telemetry presentation.

Colors are semantic:

- calm/success color → stable/good/verified;
- amber/warning → noteworthy/degraded/risk increasing;
- red/severe → serious event/failure;
- brand accent (blue/purple family may be explored) → navigation/identity, not danger status.

Do not hardcode final palette until visual prototyping. Store final tokens centrally in `theme-tokens.json` or generated Dart tokens.

## 3. Typography

- Large numeric readouts must be glanceable.
- Use tabular figures where numerical alignment matters.
- Avoid tiny telemetry labels during motion.
- Preserve minimum accessible contrast and dynamic text handling.

## 4. Primary navigation

Target no more than five primary destinations:

1. **Drive** — recording/start state.
2. **Trips** — local history + trip details.
3. **DNA** — long-term driver profile/trends.
4. **Social** — friends/rankings/Guardian.
5. **You** — vehicles/account/settings/data.

Drive should be visually dominant. Exact labels may change with design testing.

## 5. Home / ready state

Keep it calm:

```text
Good evening

READY TO DRIVE
[ START ]

GPS       Excellent
Sensors   Calibrated
Battery   76%

Last Drive
27.4 km · DNA 86
```

The status is meaningful; do not show "Excellent" without thresholds defined in telemetry/confidence specs.

## 6. Live drive mode

Goals:

- minimum interaction;
- large primary metrics;
- no deep navigation while moving;
- recording state impossible to misunderstand;
- minimal map if enabled;
- show degraded recorder state prominently.

Potential content:

- current speed;
- trip time/distance;
- current recorder/sensor status;
- optional simple lateral/longitudinal load indicator;
- End Drive control protected from accidental taps.

The app should consider a reduced-interaction mode when movement is detected. Do not design features that encourage screen attention while driving.

## 7. Trip result "money shot"

The result screen should be visually shareable while remaining informational.

Information hierarchy:

1. trip identity/date;
2. Drive DNA/overall synthesis;
3. distance/time/basic telemetry;
4. telemetry confidence + integrity;
5. notable moments;
6. historical change;
7. replay;
8. deeper graphs/details.

## 8. Drive DNA visual language

Primary presentation should not rely solely on a generic radar chart.

Explore an original "signature" representation using rings/arcs/fingerprint-like geometry. Requirements:

- dimensions remain individually understandable;
- current vs baseline can be compared;
- uncertainty/insufficient history can be shown;
- animation from previous → current should be subtle and meaningful;
- accessibility must not depend on color alone.

## 9. Map behavior

### During drive

Minimal visual clutter. Avoid unnecessary POIs/labels if they distract.

### After drive / replay

Map is analytical:

- event points;
- scrub-to-time;
- map marker synchronized with graphs;
- selected event centers/frames appropriately;
- route styling may reflect confidence or event segments only if understandable.

## 10. Replay animation system

Replay should be pleasant enough to watch repeatedly.

Suggested sequence:

1. route overview frames entire trip;
2. camera transitions to start;
3. marker begins playback;
4. route progress animates;
5. graphs scrub on the same clock;
6. notable event point pulses subtly;
7. commentary bubble rises/anchors from the event location;
8. pausing preserves/selects the event;
9. opening the bubble can transition from joke → telemetry evidence;
10. final camera pulls back into trip summary.

Avoid visual chaos. Every animation must have a reason: state, time, emphasis, spatial relation, or delight.

## 11. Road-commentary bubble motion

Concept:

```text
┌─────────────────────────┐
│ this corner was         │
│ PERSONAL 😭             │
└───────────┬─────────────┘
            │
route ──────●─────────────
```

Behavior:

- anchored to actual event point;
- small route pulse at appearance;
- bubble springs/fades with controlled motion;
- connector makes spatial relation obvious;
- bubble collapses after an appropriate interval unless playback is paused;
- event detail expansion reveals actual telemetry.

Text streaming from a cloud narrator may be animated, but animation must handle latency/failure gracefully.

## 12. Commentary personalities

At minimum:

- Analyst;
- Chill;
- Supportive;
- Roast;
- Unhinged;
- Silent.

Exact names may be changed later. Serious Guardian/crash alerts are governed separately and must remain understandable.

## 13. Guardian UX

Permission clarity is mandatory. Example:

```text
Partner can:
✓ Receive possible-crash alerts
✓ Receive severe-driving alerts

Partner cannot:
✕ View your trip history
✕ Track you continuously
✕ View your speed

[ Edit permissions ]
```

Never use dark patterns to broaden sharing.

## 14. Account UX

Account creation is positioned as unlocking online features, not as the gate to the app.

Local→account flow should clearly state what will sync.

## 15. Settings information architecture

Suggested groups:

- Vehicle;
- Tracking;
- Scoring;
- Privacy;
- Guardian;
- Commentary;
- Appearance;
- Data & Export;
- Account;
- Developer / Diagnostics.

Do not turn settings into a dumping ground. Hide advanced provider/model tuning behind an Advanced section.

## 16. Commentary engine settings

Normal view:

```text
Engine
● Built-in narrator
○ Local AI
○ Cloud AI (bring your own key)
```

Advanced cloud view may expose provider/model/temperature/max tokens/timeout/fallback, but sensible automatic behavior should be default.

## 17. Accessibility

- Support reduced motion.
- Do not rely on color alone for severity/verification.
- Provide screen-reader labels for graphs/metrics where practical.
- Maintain adequate touch targets.
- Avoid flashing/strobing animation.
- Respect text scaling without breaking critical controls.

## 18. Copy tone

Core UI should be clean and trustworthy. Humor belongs primarily in optional commentary and non-critical celebratory surfaces.

Safety/errors/privacy copy should be direct and unambiguous.
