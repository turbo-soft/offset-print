import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const seo = z
  .object({
    title: z.string().optional(),
    description: z.string().optional(),
    og_image: z.string().optional(),
  })
  .optional();

const home = defineCollection({
  loader: glob({ pattern: 'home.md', base: './src/content/pages' }),
  schema: z.object({
    hero_image: z.string(),
    hero_image_alt: z.string(),
    hero_tagline: z.string(),
    hero_metadata: z
      .array(z.object({ label: z.string(), value: z.string() }))
      .default([]),
    intro_heading: z.string(),
    intro_subheading: z.string(),
    intro_body: z.string(),
    cta_links: z
      .array(z.object({ label: z.string(), href: z.string() }))
      .default([]),
    seo,
  }),
});

const about = defineCollection({
  loader: glob({ pattern: 'about.md', base: './src/content/pages' }),
  schema: z.object({
    hero_image: z.string().optional(),
    hero_image_alt: z.string().optional(),
    history_heading: z.string(),
    intro_quote: z.string().optional(),
    intro_quote_author: z.string().optional(),
    history_text: z.string(),
    facility_text: z.string(),
    staff_count: z.number().int().positive(),
    certifications: z.array(z.string()).min(1),
    env_heading: z.string(),
    env_text: z.string(),
    business_policy_heading: z.string().optional(),
    documents: z
      .array(z.object({ label: z.string(), file: z.string() }))
      .default([]),
    seo,
  }),
});

const products = defineCollection({
  loader: glob({ pattern: 'products.md', base: './src/content/pages' }),
  schema: z.object({
    intro_heading: z.string(),
    intro_text: z.string(),
    fsc_callout: z.string(),
    seo,
  }),
});

const productCategories = defineCollection({
  loader: glob({ pattern: '*.md', base: './src/content/products' }),
  schema: z.object({
    order: z.number().int(),
    title: z.string(),
    description: z.string(),
    gallery: z
      .array(z.object({ src: z.string(), alt: z.string() }))
      .default([]),
    notes: z.string().optional(),
  }),
});

const contact = defineCollection({
  loader: glob({ pattern: 'contact.md', base: './src/content/pages' }),
  schema: z.object({
    address_line1: z.string(),
    address_line2: z.string(),
    phones: z.array(z.string()).min(1),
    fax: z.string().optional(),
    email: z.string().email(),
    map_lat: z.number(),
    map_lng: z.number(),
    map_zoom: z.number().int().default(15),
    form_intro: z.string(),
    seo,
  }),
});

const privacy = defineCollection({
  loader: glob({ pattern: 'privacy.md', base: './src/content/pages' }),
  schema: z.object({
    title: z.string(),
    last_updated: z.string(),
    seo,
  }),
});

export const collections = {
  home,
  about,
  products,
  productCategories,
  contact,
  privacy,
};
