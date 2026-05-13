# Offset Print — website

Custom site for Offset Print d.o.o. (Novi Sad), replacing the previous Wix site. Static Astro site, hosted on the customer's AWS account, content edited via Sveltia CMS at `/admin`.

---

## For the customer — how to edit the site

1. Go to **https://offsetprint.eu/admin/**.
2. Click **Login with GitHub** and sign in once. (You'll need a GitHub account; ask us if you don't have one.)
3. Pick a page on the left (Home, About, Products, Contact, Privacy) or open **Product categories** to edit a product entry.
4. Change text. To swap an image, click the image field, choose a new file from your computer.
5. Click **Save**.
6. The site updates automatically in about 60 seconds. Refresh the page to see it live.

**Tips**
- Keep image files under 5 MB. If you upload a giant phone photo, we'll downsize it for you in the background.
- The structure of the site is fixed — you can change words and pictures, but adding new pages or columns is a developer job.
- If something looks wrong after saving, ask us — every change is in version history and can be rolled back.

---

## For developers

### Stack

- **Astro 6** (TypeScript strict, static output) + Tailwind CSS v4
- **Sveltia CMS** at `/admin` (config in `public/admin/`), Git-backed
- **Cloudflare Worker** running [`sveltia-cms-auth`](https://github.com/sveltia/sveltia-cms-auth) — GitHub OAuth proxy. Lives on our agency Cloudflare account, not the customer's.
- **GitHub Actions** for build + deploy via OIDC (no long-lived AWS keys)
- **AWS** in the customer's account: S3 (private) + CloudFront (with OAC) + ACM + Route 53. Provisioned by Terraform in `infra/`.
- **Web3Forms** for the contact form (free tier, ~50 submissions/month, sends to office@offsetprint.eu)

### Local dev

```sh
npm install
npm run dev          # localhost:4321
npx decap-server                # in another terminal — lets the local /admin write to your repo (Sveltia uses Decap's local_backend protocol)
```

The CMS at `localhost:4321/admin` will use the local proxy automatically (`local_backend: true` in `public/admin/config.yml`).

### Build

```sh
npm run build        # outputs dist/
npm run preview      # serves dist/ locally
```

### Repository layout

```
.
├── .github/workflows/
│   ├── deploy.yml              build + S3 sync + CF invalidate
│   └── resize-uploads.yml      sharp downsize backstop on public/uploads/
├── infra/                      Terraform for AWS + Route 53 (see infra/README.md)
├── public/
│   ├── admin/                  Sveltia CMS shell + config
│   ├── uploads/                customer-uploaded images (committed to git)
│   └── robots.txt
└── src/
    ├── content.config.ts       Astro Content Collections schema
    ├── content/
    │   ├── pages/              one md per page (home, about, products, contact, privacy)
    │   └── products/           one md per product category
    ├── layouts/Base.astro
    ├── components/             Header, Footer, Hero, ProductCategory, ContactForm, SEO
    ├── styles/global.css       Tailwind v4 + design tokens
    └── pages/                  one .astro per route
```

The CMS schema in `public/admin/config.yml` and the content collection schema in `src/content.config.ts` must stay in sync. Changing one without the other will break either the CMS UI or the build.

### Deploying

Pushes to `main` trigger `.github/workflows/deploy.yml`. The workflow:

1. Builds the site with `PUBLIC_WEB3FORMS_KEY` from secrets.
2. Assumes an IAM role via OIDC (trust pinned to this repo's `main`).
3. Two-pass S3 sync: long cache for `_astro/*`, short cache for HTML.
4. CloudFront invalidation `/*`.

Required GitHub repository **variables**:
- `AWS_DEPLOY_ROLE_ARN` — `terraform output -raw deploy_role_arn`
- `CLOUDFRONT_DISTRIBUTION_ID` — `terraform output -raw cloudfront_distribution_id`

Required GitHub repository **secrets**:
- `PUBLIC_WEB3FORMS_KEY` — Web3Forms access key (from web3forms.com).

### Provisioning AWS

See `infra/README.md`. Order is: `terraform apply` → set GitHub variables/secret → push to `main` → verify on the raw CloudFront URL → DNS cutover.

**Critical:** before flipping nameservers to Route 53, audit the existing zone (especially MX/SPF/DKIM/DMARC) and replicate it in `infra/route53_extra_records.tf`. Switching DNS without replicating MX kills `office@offsetprint.eu`.

### Upgrading Sveltia CMS

`public/admin/index.html` pins the version + SRI hash. To upgrade:

```sh
NEW=0.158.0  # or whatever
curl -sL https://unpkg.com/@sveltia/cms@$NEW/dist/sveltia-cms.js \
  | openssl dgst -sha384 -binary | openssl base64 -A
```

Update both the URL and the `integrity=` attribute in `public/admin/index.html`. Open `/admin` locally, log in, save a test edit. Then PR.

### Internal handover (don't lose track of)

- **Cloudflare account**: which workspace owns the `sveltia-cms-auth` Worker.
- **GitHub OAuth App**: which GitHub account owns it; Client ID/Secret are stored as Worker secrets.
- **Web3Forms account**: which email registered the form key; key is in this repo's GitHub Secrets.
