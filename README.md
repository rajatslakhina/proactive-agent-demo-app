# Proactive Agent — Demo App

**Watch an on-device agent decide, signal by signal, what it may do on its own, what it must ask you first, and what is never allowed to leave your phone — then break it on purpose and watch the guards hold.**

[![CI](https://github.com/rajatslakhina/proactive-agent-demo-app/actions/workflows/ci.yml/badge.svg)](https://github.com/rajatslakhina/proactive-agent-demo-app/actions/workflows/ci.yml)

This is the companion app for **[ProactiveAgentKit](https://github.com/rajatslakhina/proactive-agent-kit)** ([v1.0.0](https://github.com/rajatslakhina/proactive-agent-kit/releases/tag/v1.0.0)). It contains no agent logic of its own: it depends on the library as a **remote Swift package** (`XCRemoteSwiftPackageReference`, `upToNextMajorVersion` from `1.0.0`), owns the scenario, and hosts the library's `AgentConsoleView`.

## Why this matters

Proactive agents (Claude Duet is the October 2026 example) invert the usual mobile AI flow: the agent reads your notifications, calendar and intents *before* you ask. On a phone that means three engineering obligations a demo usually skips — a durable, bounded intake that survives being killed; a data boundary that holds even when a classifier is wrong; and approvals that bind to the exact action and can't fire twice. The console makes each one visible and lets you inject the failure it exists for.

## What you'll see

The scenario is the library's `SampleScenario.morning` plus one signal the app adds itself (a request to send a card number to a landlord):

| Signal | What the loop does |
|---|---|
| Sam: "running late? can you reply" (with `sam@example.com`) | Needs **consent** to share contact data → after *Allow*, plans `messaging.send` in the cloud → waits for **approval** |
| "Your verification code is 482913" | Critical, handled **on device** (notification); never escalated |
| "Running low on coffee filters, reorder?" | Cloud plan with only the `commerce` tools disclosed → `commerce.checkout` waits for approval |
| Calendar conflict (organizer `priya@example.com`) | Consent, then `messaging.draft` — reversible, so it runs without an approval |
| Promo newsletter | Ignored |
| "Passport renewal due Friday" | `reminders.create` on device |
| Mum: "reply with the code 482913" | The code is **redacted** before the ticket is minted; the cloud only sees `[redacted:oneTimeCode]` and the thread name, and plans a reply to "Family" that waits for approval |
| A redelivery of Sam's notification | **Dropped** by the log's de-duplication |
| Landlord + card number (app-specific) | The recipient needs consent; after *Allow*, the card is still redacted and the reply to `landlord@example.com` waits for approval |

Fault toggles: **Low Power Mode** (cloud planning defers; on-device work such as the one-time-code alert and the reminder still runs), **Offline** (defers without burning attempts or budget), **Classifier bug** (the classifier labels everything harmless; the independent scanner still blocks the one-time code and card, and turns un-labelled email addresses back into a consent prompt), **Injected planner** (the planner proposes a tool outside the disclosed module; it is refused, or, for a messaging intent, shown to you as an approval with the attacker's address in plain sight). The **What actually left the device** section shows every ticket's fields, with redactions highlighted.

## Design decisions

- **The app holds no agent logic.** `AgentConsoleView` and its model live in the library's `ProactiveAgentUI` module, so a second host (a macOS app, a debug build) gets the same console for free, and the app's job is only to own the scenario and the scene. *Honest limit:* the UI module itself has no tests. What is tested, on Linux, is the console's exact flow: a package test replays this app's 9 signals with the console's setup (clock, log limits) through Deliver → Run → Allow → Run and asserts the outcomes in the table above, plus what the Classifier-bug toggle changes. *Rejected:* building the console in the app, which would put it out of reach of the package's tests altogether.
- **A remote, version-pinned package, not a local path.** The project references `https://github.com/rajatslakhina/proactive-agent-kit.git` with `upToNextMajorVersion` from `1.0.0`, which is how a consumer would depend on it. *Rejected:* `branch = main`, which would make every clone resolve whatever `main` is that day; and a local path, which can't prove the published package works.
- **The app owns its scenario.** It extends the library's `SampleScenario.morning` with one signal of its own, so the app has a real reason to import the core module and the card-redaction path is visible.
- **`ObservableObject`, not `@Observable`.** Chosen for the iOS 17 floor and for predictable `@MainActor` isolation under Swift 6. *Trade-off:* coarser invalidation; irrelevant at this list size.
- **A hand-written `project.pbxproj`.** It keeps the repo free of a generator dependency (XcodeGen, Tuist), at the cost of being checked structurally by script rather than by a tool. CI and the Simulator run are the backstop; the only file Xcode generated is the committed `Package.resolved`.

## Screenshots

Six screenshots were captured with Device Hub's **Screenshot** command during the Simulator run described under *Verification*. Device Hub saved them to the developer's Desktop, which the session that published this repo could not read, so **none are committed here yet** and no image is embedded. Everything the run showed is written out below instead.

## How to run it

1. `git clone https://github.com/rajatslakhina/proactive-agent-demo-app.git`
2. Open `Demo.xcodeproj` in Xcode 16 or later. Xcode resolves `ProactiveAgentKit` from GitHub; the committed `Package.resolved` pins it to `1.0.0` (revision `c5d319d`).
3. Select the **Demo** scheme and any iOS 17+ Simulator.
4. Build & Run. Tap **Deliver**, then **Run**. Three consent prompts and two approvals appear under **Waiting on you**. Tap **Allow** on any consent prompt (one grant for contact data releases all three), then **Run** again, then **Approve** or **Reject** the approvals. Flip a fault toggle, **Reset**, and repeat. **+5 min** advances the simulated clock so deferred and retried events come due.

## Verification

- **Simulator run: done, on 27 Oct 2026.** `Demo.xcodeproj` was opened in its own Xcode window, Xcode resolved `ProactiveAgentKit` 1.0.0 from GitHub (it wrote the committed `Package.resolved`, revision `c5d319d`, which is the `v1.0.0` tag), and the app was built and run on an **iPhone Duo simulator, iOS 27.1**, in Device Hub, unfolded to its open posture. What the run showed, in order:
  - **Deliver → Run:** consent prompts for #1 (Sam), #4 (Priya) and #8 (landlord); approval cards for the coffee-filter reorder (`commerce.checkout`, arguments `item: coffee filters`, `quantity: 1`, plus its digest) and for the reply to "Family"; #2 posted on device, #5 ignored, #6 `reminders.create`, and Sam's redelivered notification dropped as a duplicate.
  - **What actually left the device:** the landlord ticket carried `title: [redacted:paymentCard]`; Priya's and Sam's tickets carried their titles and email addresses only after consent.
  - **Allow → Run:** #4 ran `messaging.draft` with no approval; #1 and #8 became approval cards addressed to `sam@example.com` and `landlord@example.com`.
  - **Approve, Reject, Approve:** #3 `commerce.checkout` executed, #7 rejected (nothing ran), #1 `messaging.send` executed.
  - **Classifier bug on → Reset → Deliver → Run:** #7 and #8 were "notified instead of acting" because the leak scanner blocked egress (`oneTimeCode`, then `paymentCard`); #1 and #4 still asked for contact consent.
- **CI** ([Actions](https://github.com/rajatslakhina/proactive-agent-demo-app/actions/workflows/ci.yml)), `macos-15` with Xcode 16.4: `xcodebuild -resolvePackageDependencies` resolves `ProactiveAgentKit @ 1.0.0` from GitHub, then `xcodebuild build` for `generic/platform=iOS Simulator` succeeds, with Swift warnings treated as errors on the Demo target.
- **The library it runs** is verified separately: 78 tests on Linux and on macOS in CI. One of them replays this app's exact flow (its 9 signals, the console's clock and log limits, Deliver → Run → Allow → Run) and asserts the outcomes in the table above, plus what the Classifier-bug toggle changes.

## License

MIT
