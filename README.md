# Basically Brilliant Beginner — Working Site

The internal working site for **The Basically Brilliant Beginner** / **Council of the Root** —
a collaboration space for Linda Webster, Daniele Buatti and Bradley Dylan.

| Item | Value |
|------|-------|
| **Primary (Netlify)** | https://basically-brilliant-beginner.netlify.app |
| **Mirror (Vercel)** | https://basically-brilliant-beginner.vercel.app |
| **GitHub** | https://github.com/dbuatti/basically-brilliant-beginner |
| **Netlify** | https://app.netlify.com/projects/basically-brilliant-beginner |
| **Vercel** | https://vercel.com/daniele-buattis-projects/basically-brilliant-beginner |

> **This is the working site, not the public one.** Charming Divinations — Linda's
> public practice site — is a separate project:
> **https://charming-divinations.netlify.app**

---

## Deploying

```bash
git add -A
git commit -m "update"
git push origin main     # → GitHub Actions → Netlify, ~60s
```

Or manually:

```bash
netlify deploy --prod --dir=.
```

### Why two hosts
Vercel's Hobby tier caps deployments at **100 per day for the whole account**, and
that account also hosts several other active projects (`scales.os`,
`composerhub`, `fluffy-gibbon-nudge`). A push to this repo could sit rejected with
*"Deployment rate limited — retry in 24 hours"*. Netlify has no such cap, so
**Netlify is the primary** and GitHub Actions deploys to it on every push. Vercel
is kept as a mirror and catches up whenever quota allows.

---

## Pages

| Page | URL | What's on it |
|------|-----|---------------|
| **Landing** | `/` | Course overview, 5 elemental modules, Council sessions, team, central Join button |
| **Council Console** | `/pages/session` | Jitsi embedded, pre-join ritual checklist, session flow, recording guidance |
| **Music Hub** | `/pages/music` | Elemental compositions, collaboration workflow, musical keywords — **Linda & Daniele** |
| **Listen & Watch** | `/pages/media` | Recommended YouTube/podcasts, sectioned by element — **send Daniele links to add** |
| **Insight Timer** | `/pages/insight-timer` | Setup guide for Linda: application → recording → courses → live events → revenue |
| **Resources** | `/pages/resources` | Recording, Jitsi, Cal.com, MacWhisper, quick commands, platform comparison |
| **Council Sessions** | `/pages/council` | Session 1 notes, teaching points, visions, action items, next session prep |

**The one link to share with the group:**
`https://basically-brilliant-beginner.vercel.app/join` → redirects straight to the
Jitsi room. Per-element: `/join/water`, `/join/air`, etc.
(On Netlify the same paths work: `/join`.)

---

## Structure
```
landing-page/
├── index.html
├── pages/
│   ├── session.html         # Council Console — embedded Jitsi
│   ├── music.html          # Music Composition Hub
│   ├── media.html          # Listen & Watch
│   ├── insight-timer.html  # Linda's teacher-platform setup
│   ├── resources.html      # Technical resources
│   └── council.html        # Session notes
├── css/main.css
├── js/main.js
├── 404.html
├── netlify.toml            # Netlify build + clean-URL rewrites
├── vercel.json
└── .github/workflows/deploy.yml
```

---

## The recording stack

See `../Shared/Resources/` for the full set.

| File | Purpose |
|------|---------|
| `install_recording_tools.sh` | One-shot installer (non-destructive, backs up init.lua) |
| `record_meeting.sh` | CLI recorder with transcription |
| `audio_output.sh` | Switch output between normal and recording mode |
| `meeting_recorder.lua` | Hammerspoon module → `~/.hammerspoon/meeting_recorder.lua` |
| `AUDIO_RECORDING_SETUP.md` | The written guide |
| `jitsi_setup.md` | Jitsi recording, embedding, troubleshooting |

**Hammerspoon:** 🚀 menu → 🎙️ Council, or ⌘⌥⌃L → type "Council"
**Hotkey:** ⌘⌥⌃M toggles recording
**Recordings:** `~/Meet Recordings/`
**Transcribe:** 🚀 → 🎙️ Council → *Transcribe Latest Recording (MacWhisper)*

---

## Key links
- Jitsi room: `https://meet.jit.si/council-of-the-root`
- Cal.com booking: `https://cal.com/danielebuatti/council-session`
- Humanitix (Piano by Heart): `https://events.humanitix.com/pianobyheart`
- Insight Timer teacher signup: `https://insighttimer.com/teachers/join`
