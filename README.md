# Audio Reaction Training

A simple Flutter app built to solve a personal training problem: getting randomised audio cues to react to during sprints and agility drills — without interrupting the music you're already listening to.

The idea is simple. You set up a session with a warm-up, a series of action blocks (each with one or more audio cues that fire randomly), delays between them, and a number of rounds. Hit play, pocket your phone, and the app fires cues through your earphones while Spotify (or whatever) keeps playing in the background. You react to the sound. That's it.

---

## The Problem It Solves

Most reaction training tools either require a partner, use visual cues that demand you watch a screen, cost money or pause your music. This app fires audio cues — directional calls, beeps, custom recordings — unpredictably, so you actually have to listen and react rather than anticipate. It mixes its audio on top of your music session using the correct iOS/Android audio session configuration so nothing gets interrupted.

---

## Features

- **Session builder** — compose a training sequence from warm-up, delay, and action blocks
- **Action blocks** — assign one or more audio cues per block; one fires at random each round
- **Custom recordings** — record your own cues directly in the app (e.g. "left", "right", "go")
- **Bundled sounds** — a library of default cues (beeps, chimes, bells, etc.) ready to use
- **Rounds & infinite mode** — run a fixed number of rounds or loop indefinitely
- **Plays over background music** — Spotify, Apple Music, etc. keep playing uninterrupted (only ducking)
- **Screen-lock safe** — the sequence continues when the device is locked or in your pocket
- **Swipe to delete, tap to edit** — simple session management on the home screen

---

## Ideas & Future Work

### 1. Randomised delay ranges
Next tp a fixed delay between blocks, let the user be able to set a minimum and maximum. The app can pick a random duration within that range each round, making the timing genuinely unpredictable and much harder to anticipate.

### 2. Visual drill patterns (drawing / images per session)
Let users attach a diagram to a session — drawn directly in the app or uploaded as an image (e.g. [flutter_drawing_board](https://pub.dev/packages/)flutter_drawing_board). Example use case: a half-circle of cones where each cone is labelled with a number or colour, and each label maps to a specific audio cue. The athlete sees the layout once before the session starts, then reacts purely by sound during training.

### 3. Text-to-speech cue generation
Instead of recording yourself saying "left" or "3", let the app generate the audio from typed text using a text-to-speech model. Faster setup, consistent pronunciation, and useful for anyone who doesn't want to record their own voice.

---

(**Not tested on a physical Apple device but considered during development.**)
