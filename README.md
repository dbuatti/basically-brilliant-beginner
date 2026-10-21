# Basically Brilliant Beginner — Landing Page

Static site for **The Basically Brilliant Beginner** / **Council of the Root**.

## 🌍 Live Site
**https://basically-brilliant-beginner.vercel.app**

| Page | URL |
|------|-----|
| Landing | https://basically-brilliant-beginner.vercel.app/ |
| Music Hub | https://basically-brilliant-beginner.vercel.app/pages/music |
| Insight Timer | https://basically-brilliant-beginner.vercel.app/pages/insight-timer |
| Resources | https://basically-brilliant-beginner.vercel.app/pages/resources |
| Council Sessions | https://basically-brilliant-beginner.vercel.app/pages/council |

## Stack
- Pure HTML / CSS / vanilla JS
- No framework, no build step
- Deployed to Vercel via GitHub (auto-deploy on push to `main`)

## Structure
```
landing-page/
├── index.html              # Main landing page
├── vercel.json             # Vercel config (clean URLs, headers, caching)
├── package.json            # Optional - local dev server
├── .gitignore
├── css/
│   └── main.css            # All styles
├── js/
│   └── main.js             # Nav toggle, scroll reveal, parallax
├── pages/
│   ├── music.html          # Music Composition Hub
│   ├── insight-timer.html  # Insight Timer setup guide for Linda
│   ├── resources.html      # Technical resources library
│   └── council.html        # Council session notes
└── assets/                 # Images, audio samples (if added)
```

## Local Preview

```bash
# Python (built into macOS)
python3 -m http.server 8080

# Or with Vercel CLI (best - matches production)
npm i -g vercel
vercel dev
```

Then open http://localhost:8080

## Deploy to Vercel

**Already deployed.** GitHub → Vercel auto-deploy is live on `main`.

### Making Changes
```bash
cd landing-page
# edit files
git add -A
git commit -m "Update council notes"
git push origin main
# Vercel auto-deploys within ~60 seconds
```

### Manual Deploy (if needed)
```bash
vercel --prod
```

### Project Details
- **Vercel Project:** `basically-brilliant-beginner` (team: `daniele-buattis-projects`)
- **GitHub Repo:** https://github.com/dbuatti/basically-brilliant-beginner
- **Dashboard:** https://vercel.com/daniele-buattis-projects/basically-brilliant-beginner
- **Deployment Protection:** Disabled (public access)

## Custom Domain

After deployment:
1. Vercel Dashboard → **Settings** → **Domains**
2. Add your domain
3. Update DNS (A record `76.76.21.21` or CNAME `cname.vercel-dns.com`)

## Pages & Navigation

| Route | Page | Purpose |
|-------|------|---------|
| `/` | index.html | Landing — elements, council, team, hubs |
| `/pages/music` | music.html | Music Composition Hub |
| `/pages/insight-timer` | insight-timer.html | Insight Timer setup guide |
| `/pages/resources` | resources.html | Resources library |
| `/pages/council` | council.html | Council session notes |

`vercel.json` has `cleanUrls: true` so `.html` extensions are hidden.

## Editing

### Colours
Edit the CSS custom properties at the top of `css/main.css`:
```css
:root {
  --color-water: #4a9fd4;
  --color-air:   #a8d0e6;
  --color-fire:  #e87d4a;
  --color-earth: #a68a64;
  --color-spirit:#c9b896;
  --color-accent:#d4a574;
}
```

### Content
All copy is inline in the HTML. Find the section and edit directly.

### Adding a new page
1. Copy `pages/resources.html` as a template
2. Change the `nav__link--active` class to the new page
3. Add a link in the nav of every other page
4. Push to GitHub — Vercel auto-deploys

## Key Links Configured

| Service | URL |
|---------|-----|
| Jitsi (main room) | `https://meet.jit.si/council-of-the-root` |
| Jitsi (water) | `https://meet.jit.si/council-of-the-root-water` |
| Cal.com booking | `https://cal.com/danielebuatti/council-session` |
| Humanitix (Piano by Heart) | `https://events.humanitix.com/pianobyheart` |
| Insight Timer teacher | `https://insighttimer.com/teachers/join` |

**Update these** in the HTML when accounts change.

## Performance Notes

- No external JS dependencies (only Google Fonts)
- CSS/JS cached for 1 year via Vercel headers
- `preconnect` to Google Fonts for faster load
- CSS custom properties for easy theming
- `prefers-reduced-motion` support for accessibility
- Mobile responsive with hamburger nav
