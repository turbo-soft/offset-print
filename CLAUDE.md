# Offset Print — agent context

## What this is

Replacement website for **Offset Print d.o.o.** (Novi Sad, family-owned printer since 1990). Currently on Wix at `jpervaz.wixsite.com/offset-print-doo` — customer wants modern look + ability to self-edit text and images.

Project is at the "built, not yet deployed" stage. Local dev verified. Nothing has been pushed to GitHub or AWS.

## Stack & key decisions

- **Astro 6** + TypeScript strict + **Tailwind v4** (Vite plugin, no PostCSS) → 6 static routes, no SSR.
- **Sveltia CMS** at `/admin`, pinned to `0.157.1` with SRI hash. Edits Markdown directly in this repo.
- **Cloudflare Workers** runs `sveltia-cms-auth` (GitHub OAuth proxy). Lives on **agency** Cloudflare account permanently — not transferred to customer.
- **GitHub Actions** deploys via **OIDC** (no long-lived AWS keys). Trust pinned to `repo:<owner>/offset-print-site:ref:refs/heads/main`.
- **AWS** in customer account: S3 (private, OAC) + CloudFront + ACM + Route 53. Provisioned by Terraform in `infra/`.
- **Web3Forms** for contact form (free tier). Access key in GitHub secret `PUBLIC_WEB3FORMS_KEY`.
- **OpenStreetMap** for the contact map (static tile, not iframe) — avoids Google Maps tracking → no GDPR consent banner.
- **English only** site (decision made with user). Bilingual was offered, declined.
- **Custom error response returns HTTP 404**, not 200 — this is a static site, not an SPA.

## Visual design (chosen April 2026 after a 4-style preview round)

Customer compared 4 directions (Editorial / Industrial / Brand-led / Industrial × Brand) and picked the combined "Industrial × Brand" — formerly Style D, now canonical. Preview tree was deleted.

- **Palette** (in `src/styles/global.css` `@theme`):
  - `--color-paper: #f5f5f0` — warm off-white background
  - `--color-ink: #0f1f0a` — deep green-black text
  - `--color-ink-muted: #5a6155`
  - `--color-accent: #9bc73a` — **logo green**, used for primary CTAs, brand sections, hero metadata strip, footer hero strip
  - `--color-accent-deep: #6a8a26` — pill hover
  - `--color-accent-warm: #d97432` — **secondary orange**, used for typographic accents only (eyebrow labels, big numbered "01" on products, pull-quote rule, PDF download accents). Never on large surfaces.
  - `--color-rule: #dde0d0`
- **Type system**:
  - `--font-sans: Inter` — body
  - `--font-display: Space Grotesk` — headings (use class `.heading`)
  - `--font-mono: JetBrains Mono` — labels, technical metadata (use class `.label` or `font-mono`)
  - All three loaded from Google Fonts via `Base.astro`.
- **Component classes** (defined in `global.css` `@layer components`):
  - `.heading` — Space Grotesk 600, tight tracking, line-height 1.02
  - `.label` — JetBrains Mono uppercase 0.12em tracking, color = warm orange
  - `.pill` — green rounded CTA button; hover deepens
  - `.section-brand` — green panel with ink text (used for hero metadata strip, About stat block, Footer hero strip)
  - `.img-card` — rounded-xl image frame with subtle hover scale
- **Hero pattern**: full-screen (80vh) image with dark gradient overlay, tagline + CTAs at bottom-left, technical metadata band immediately below the image (FOUNDED · FACILITY · STAFF · CERT). See `src/components/Hero.astro`.
- **Page layout pattern**: 12-column grid (`max-w-7xl`); pages start with a 4/8 split — left column has a `// label` eyebrow, right column has the heading + body. Used on About, Products, Contact, Privacy.
- **Product gallery**: scroll-snap horizontal slider with rounded `bg-rule` placeholders (NOT `bg-ink` — dark green-black is too visible while images load). Big warm-orange numbered indicator + green nav buttons.

## Where things live

- `src/content.config.ts` — Astro Content Collections schemas (Astro 6 location, not the legacy `src/content/config.ts`).
- `src/content/pages/{home,about,products,contact,privacy}.md` — fixed pages (one file each).
- `src/content/products/*.md` — product category folder collection (currently 3: cardboard, corrugated, paper labels).
- `src/components/{Header,Footer,Hero,ProductCategory,ContactForm,SEO}.astro` + `src/layouts/Base.astro`.
- `src/pages/{index,about,products,contact,privacy,404}.astro`.
- `public/admin/{index.html,config.yml}` — Sveltia CMS shell + schema.
- `public/uploads/` — customer-uploaded images (committed to git).
- `.github/workflows/{deploy,resize-uploads}.yml` — CI deploy + image-size backstop.
- `infra/{main,variables,outputs,route53_extra_records}.tf` — Terraform.
- Plan file: `~/.claude/plans/i-have-the-customer-fluttering-micali.md`.

## Conventions / gotchas

- **Schema must stay in sync.** `src/content.config.ts` (Zod schemas) and `public/admin/config.yml` (Sveltia field defs) describe the same data twice. Change one → change the other in the same commit, or the build will fail or the CMS will save invalid frontmatter.
- **Tailwind v4 + `@layer` rules**: do NOT put unlayered CSS rules in `src/styles/global.css` that target HTML elements that Tailwind utilities also affect. Tailwind utilities sit in `@layer utilities`; unlayered rules win the cascade. (Already-fixed example: `a { color: inherit }` was overriding `text-paper` on link buttons. Tailwind preflight already provides this rule in `@layer base`.) If you add element-level CSS, wrap it in `@layer base { ... }`. Component utility classes (`.heading`, `.label`, `.pill`, `.section-brand`, `.img-card`) live in `@layer components`.
- **Two-accent rule (green + orange)**: `bg-accent` / `text-accent` (green) is reserved for primary brand moments — pill CTAs, the hero metadata band, the About stat block, the footer hero strip. `accent-warm` (orange via `text-accent-warm`, `border-accent-warm`, `bg-accent-warm`, or `.label`) is reserved for typographic accents — eyebrows, numbered indicators, pull-quote rule, document download icons. Never invert these. If you find yourself making a large surface orange or a body label green, reconsider.
- **MCP browser is in Docker** — can't reach `localhost`. Run dev with `npm run dev -- --host 0.0.0.0` and navigate to `http://172.17.0.1:4321/` (or whatever `ip -4 addr` shows for `docker0`).
- **Sveltia local dev** needs `npx decap-server` running in a second terminal (port 8081). Sveltia reuses Decap CMS's `local_backend` protocol — there is no separate `@sveltia/cms-proxy-server` package on npm. Without it `/admin` loads but can't read/write content. `local_backend: true` in `config.yml` already wires this up.
- **Sveltia version bumps are deliberate.** Pinning + SRI is intentional — bumping silently overnight is what "walk away" can't tolerate. To upgrade: change version in `public/admin/index.html`, regenerate SRI (`curl ... | openssl dgst -sha384 -binary | openssl base64 -A`), test in `/admin`, PR.
- **CMS image uploads have two-layer size cap**: client-side resize in Sveltia widget config + `resize-uploads.yml` Action backstop. The Action commits with `[resize-skip]` in the message to avoid re-triggering itself. Don't remove either layer — the customer will eventually upload a 12 MB iPhone photo.
- **Placeholder images** under `public/uploads/` and `public/uploads/products/` are red/black/grey JPGs generated via sharp during the local-verify pass. Customer or designer will replace them via the CMS.

## Workflow

```sh
npm run dev                          # localhost:4321
npm run dev -- --host 0.0.0.0        # if you need MCP browser access
npx decap-server                     # second terminal, only for /admin local dev (Sveltia uses Decap's local_backend protocol)
npm run build                        # → dist/
```

## Not done yet (needs user/customer or external setup)

1. **GitHub repo** — `git init` + push to a new repo (`offset-print-site`), customer gets owner role.
2. **Real assets** — logo at high resolution, real product photos, real social URLs.
3. **AWS account access** — `terraform apply` in `infra/`.
4. **GitHub OAuth App** — Client ID/Secret → set as Cloudflare Worker secrets.
5. **Cloudflare Worker** — deploy `sveltia-cms-auth`; update `base_url` in `public/admin/config.yml`.
6. **Web3Forms key** — sign up, set GitHub secret `PUBLIC_WEB3FORMS_KEY`, replace `REPLACE_ME_WEB3FORMS_KEY` in `ContactForm.astro` is via env so just the secret is needed.
7. **DNS audit + cutover** — dump current MX/SPF/DKIM/DMARC for `offsetprint.eu`, replicate in `infra/route53_extra_records.tf`, then flip nameservers. Skipping this kills `office@offsetprint.eu`.
8. **Analytics decision** — customer hasn't said yes/no. Plausible recommended; Privacy page wording assumes "no advertising trackers" so adding Plausible (no-cookie) is consistent.
9. **Replace placeholders** in `public/admin/config.yml`: `REPLACE_ME_OWNER` (GitHub owner), `REPLACE_ME_WORKER` (Cloudflare Worker subdomain).
