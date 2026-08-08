# SAFETY_GOVERNANCE.md — Product Safety Rules

## When to read

Read for rankings, Guardian alerts, crash-like detection, live-drive UI, commentary around severe events, or real-world test design.

## 1. Do not incentivize dangerous driving

Telemetry may measure high speed/acceleration/lateral load, but the app must not make extreme values the competitive objective.

## 2. Live-drive distraction

- minimal controls;
- no interaction-heavy analysis while moving;
- do not prompt user to label events during drive;
- avoid attention-grabbing animations during live recording.

## 3. Crash-like detection

- use cautious wording: "possible crash" / "crash-like impact evidence";
- require corroboration and high confidence for remote alerts;
- do not claim injury/death;
- LLMs are excluded from the decision path.

## 4. Commentary

Humor is optional and post-event/replay oriented. It can react to risk but must not glorify or challenge users to repeat it.

## 5. Field testing

Never instruct testers to speed, deliberately crash, or perform dangerous maneuvers on public roads. Controlled safe environments, normal driving events, simulation, and datasets are preferred.

## 6. Limitations

The application is not an emergency-service replacement, legal driving assessment, insurance device, or certified crash detector. Product copy should not imply such certification.
