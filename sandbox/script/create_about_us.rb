# Create About Us page as a Spree::Post with brand links
# Run: kamal app exec --reuse "bin/rails runner /rails/script/create_about_us.rb"

store = Spree::Store.find(2)

post = Spree::Post.find_or_initialize_by(slug: 'about-us')
post.store = store
post.title = 'About Surf Store'
post.meta_title = 'About Surf Store — Europe\'s Water Sports Specialist'
post.meta_description = 'Surf Store is a European water sports shop specialising in kitesurfing, windsurfing, wing foiling, SUP & wetsuits. Authorised dealer for Duotone, Cabrinha, ION & more.'
post.published_at ||= Time.current
post.content = <<~HTML
  <h2>Your Water Sports Partner Since Day One</h2>
  <p>Surf Store is a specialist water sports retailer based in Maribor, Slovenia, serving riders across Europe. We stock, test, and sell equipment for kitesurfing, windsurfing, wing foiling, stand-up paddleboarding, and mountain biking — from beginner packages to pro-level race gear.</p>
  <p>We're not a generic outdoor store. Every product we carry has been evaluated by our team — riders who spend 100+ days on the water each year. When we recommend a kite size, a wetsuit thickness, or a foil setup, it's based on first-hand experience in real conditions, not marketing copy.</p>

  <h2>What We Do</h2>
  <ul>
  <li><strong>Expert advice</strong> — our team rides the gear we sell. WhatsApp, email, or visit us in store for personalised recommendations</li>
  <li><strong>Free EU shipping</strong> on orders over €99 — fast delivery across Europe</li>
  <li><strong>Full manufacturer warranty</strong> on all products — we're authorised dealers, not grey market</li>
  <li><strong>Pre-delivery inspection</strong> — kites are unfolded, boards are checked, rigs are verified before shipping</li>
  <li><strong>After-sales support</strong> — spare parts, repairs, and warranty claims handled directly</li>
  </ul>

  <h2>Our Brands</h2>
  <p>We carry the full 2026 collections from the world's leading water sports brands. Every brand below is an authorised dealership — meaning full warranty, genuine products, and direct manufacturer support.</p>

  <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 16px; margin: 24px 0;">
    <a href="/t/brands/duotone-kiteboarding" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Duotone Kiteboarding</strong><br>
      <span style="color: #6B7280;">Kites, bars, boards & harnesses</span>
    </a>
    <a href="/t/brands/duotone-windsurfing" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Duotone Windsurfing</strong><br>
      <span style="color: #6B7280;">Sails, masts, booms & boards</span>
    </a>
    <a href="/t/brands/duotone-wing-foiling" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Duotone Wing Foiling</strong><br>
      <span style="color: #6B7280;">Wings, foils & boards</span>
    </a>
    <a href="/t/brands/cabrinha" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Cabrinha</strong><br>
      <span style="color: #6B7280;">Kites, bars & kiteboards</span>
    </a>
    <a href="/t/brands/neilpryde" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">NeilPryde</strong><br>
      <span style="color: #6B7280;">Windsurf sails, wetsuits & wings</span>
    </a>
    <a href="/t/brands/fanatic-windsurfing" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Fanatic</strong><br>
      <span style="color: #6B7280;">Windsurf & SUP boards</span>
    </a>
    <a href="/t/brands/ion" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">ION</strong><br>
      <span style="color: #6B7280;">Wetsuits, harnesses & protection</span>
    </a>
    <a href="/t/brands/gaastra" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Gaastra</strong><br>
      <span style="color: #6B7280;">Windsurf sails & kites</span>
    </a>
    <a href="/t/brands/jp-australia-sup-windsurf-boards" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">JP Australia</strong><br>
      <span style="color: #6B7280;">Windsurf & SUP boards</span>
    </a>
    <a href="/t/brands/nobile" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Nobile</strong><br>
      <span style="color: #6B7280;">Kiteboards & foils</span>
    </a>
    <a href="/t/brands/point7" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Point-7</strong><br>
      <span style="color: #6B7280;">Windsurf sails</span>
    </a>
    <a href="/t/brands/tabou" style="display: block; padding: 20px; border: 1px solid #E5E7EB; border-radius: 8px; text-decoration: none; color: inherit;">
      <strong style="font-size: 18px;">Tabou</strong><br>
      <span style="color: #6B7280;">Windsurf boards</span>
    </a>
  </div>

  <h2>Visit Our Store</h2>
  <p><strong>Surf Store</strong><br>
  Maribor, Slovenia<br>
  Email: <a href="mailto:info@surf-store.com">info@surf-store.com</a><br>
  WhatsApp: Available for quick advice and sizing questions</p>
  <p>Whether you're buying your first kite or upgrading to a D/LAB race setup, our team is here to help. We respond to WhatsApp messages within 10 minutes on working days.</p>

  <h2>Why Buy From Surf Store?</h2>
  <p><strong>Authorised dealer status</strong> means you get genuine products with full manufacturer warranty — not grey market imports with voided coverage. We buy directly from Boards & More (Duotone, Fanatic, ION), Cabrinha, NeilPryde, Nobile, and Point-7.</p>
  <p><strong>Real expertise</strong> means our recommendations are based on actual riding experience. We test gear at Lake Garda, Slovenian coast spots, and on kite trips across Europe. When we say a 7m Evo SLS handles 20–30 knots for an 80kg rider, it's because we've ridden that exact combination.</p>
  <p><strong>European focus</strong> means we understand EU wind conditions, water temperatures, and shipping logistics. Our warehouse ships to every EU country with tracked delivery, typically arriving in 2–5 working days.</p>
HTML

post.save!
puts "OK: #{post.slug} (id: #{post.id})"
