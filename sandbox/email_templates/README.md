# Email Templates

This directory contains HTML email templates for Surf-Store campaigns.

## Product Announcement 2026

**File:** `product_announcement_2026.html`

A professional product announcement email template showcasing the 2026 gear lineup from Duotone, ION, Cabrinha, Point-7, and Gaastra.

### Design Features

- **Responsive layout** optimized for mobile and desktop
- **Brand-aligned styling** matching surf-store.com design system
- **Beige background** (#F0EFE9) with minimalist black text
- **Hero section** with customizable image and headline
- **Product grid** featuring 2 handpicked products with pricing
- **Trust indicators** highlighting: Free EU shipping, 14-day returns, Expert support
- **Social links** (Instagram, Facebook, YouTube)
- **Unsubscribe link** for compliance

### Color Palette

- Background: `#F0EFE9` (Beige)
- Primary: `#000000` (Black)
- Accent: `#C73528` (Dark Red, for category label)
- Border: `#E9E7DC` (Light Beige)
- Text: `#555555` / `#666666` (Grey tones)

### Usage

1. **In Klaviyo:** Create a new email template, copy the HTML content into the editor
2. **In Shopify:** Use as a reference for Shopify email campaigns
3. **Template variables:** Supports Liquid template syntax for dynamic content:
   - `{{ email_title }}` — Email subject line
   - `{{ preview_text }}` — Preheader text
   - `{{ shop.address.company }}` — Store name
   - `{{ unsubscribe_url }}` — Unsubscribe link
   - `{{ "now" | date: "%Y" }}` — Current year

### Customization

To customize for different campaigns:

1. Update image URLs:
   - `https://www.surf-store.com/email/hero-2026.jpg` (hero image)
   - `https://www.surf-store.com/email/product-1.jpg` (product images)

2. Update product links and pricing in the product cards section

3. Modify the main headline and description in the "Hero text" section

4. Adjust social media links in the footer

### Mobile Responsiveness

The template includes responsive CSS with mobile breakpoint at `600px`. Key mobile changes:
- Padding adjusted for smaller screens
- Font sizes scaled down
- Product grid stacks vertically
- Button widths adjust to 100%

### Email Client Compatibility

Tested for compatibility with:
- Gmail
- Outlook
- Apple Mail
- Mobile clients (iOS Mail, Gmail app)

Uses XHTML 1.0 Transitional doctype and inline styles for maximum compatibility.

## Integration with Klaviyo

To use with Klaviyo (via API or UI):

1. Create a new email template in Klaviyo
2. Select "Custom HTML" editor
3. Paste the HTML content
4. Configure template variables in Klaviyo
5. Test preview in different clients
6. Set up campaign or flow to use template

## Notes

- All links default to www.surf-store.com (update base domain if needed)
- Product images should be optimized JPGs for faster load times
- Hero image recommended: 600px wide, ~300px height
- Product card images recommended: 260px square
