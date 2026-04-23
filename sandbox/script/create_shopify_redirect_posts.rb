# Create blog posts for old Shopify URLs that are still getting traffic.
# These posts replace content that was on the Shopify store.
# The routes.rb 301 redirect handles /blogs/news/:slug → /en/posts/:slug
#
# Run: kamal app exec --reuse "bin/rails runner /rails/script/create_shopify_redirect_posts.rb"

store = Spree::Store.find(2)

POSTS = [
  {
    slug: 'the-ultimate-guide-to-windsurfing-shoes',
    title: 'The Ultimate Guide to Windsurfing Shoes',
    meta_title: 'Windsurfing Shoes Guide 2026 — Best Boots & Sizing',
    meta_description: 'The ultimate guide to windsurfing shoes: neoprene boots vs reef walkers, thickness by temperature, sizing tips and our top picks for 2026.',
    body: <<~HTML
      <h2>Why You Need Windsurfing Shoes</h2>
      <p>Cold feet end sessions faster than any other discomfort. Windsurf shoes — whether neoprene boots, reef walkers, or hybrid designs — protect your feet from cold water, sharp rocks, reef, sea urchins, and the constant pressure of footstraps on bare skin. Even in warm water, a thin reef shoe prevents the cuts and bruises that ruin tomorrow's session.</p>

      <h2>Types of Windsurfing Shoes</h2>
      <h3>Neoprene Boots (2mm–6mm)</h3>
      <p>Full neoprene boots are the standard choice for windsurfing in cold water. They insulate against heat loss, protect the sole and ankle, and provide grip on wet board surfaces. Available in round-toe (warmer, more comfortable) and split-toe (better footstrap feel) designs.</p>
      <p>Choose thickness based on water temperature:</p>
      <ul>
      <li><strong>2mm:</strong> Mild conditions (18–22°C) — reef protection with minimal insulation</li>
      <li><strong>3mm:</strong> Spring/autumn (14–18°C) — the most versatile thickness for European sailing</li>
      <li><strong>5mm:</strong> Cold water (8–14°C) — serious insulation for winter sessions</li>
      <li><strong>6mm:</strong> Extreme cold (below 8°C) — maximum warmth, paired with hooded wetsuit</li>
      </ul>

      <h3>Reef Walkers (1–2mm)</h3>
      <p>Thin-soled shoes designed for warm-water protection. They guard against coral cuts, sea urchins, and hot sand without adding warmth you don't need. Ideal for tropical windsurfing destinations like Egypt, Caribbean, and Southeast Asia.</p>

      <h3>Split-Toe vs Round-Toe</h3>
      <p><strong>Split-toe boots</strong> separate the big toe from the other toes, providing better grip and tactile feedback in footstraps. Most serious windsurfers prefer split-toe for the improved board feel — you can sense strap pressure more precisely, which matters during planing and manoeuvres.</p>
      <p><strong>Round-toe boots</strong> keep all toes together. They are warmer and more comfortable for walking. Better for casual sailors and very cold conditions where warmth is the priority.</p>

      <h2>How to Size Windsurfing Shoes</h2>
      <p>Windsurf boots should fit <strong>snug but not painful</strong>:</p>
      <ul>
      <li>Neoprene stretches when wet — buy for a tight dry fit</li>
      <li>Your toes should touch the end of the boot without curling</li>
      <li>No air gaps around the ankle — loose boots cause blisters and let cold water in</li>
      <li>If between sizes, go smaller — neoprene gives 3–5mm after break-in</li>
      <li>Widen your footstraps slightly to accommodate the boot thickness</li>
      </ul>

      <h2>Our Top Windsurfing Shoe Picks for 2026</h2>
      <h3>Best All-Round: <a href="/t/brands/ion/boots">ION Ballistic 3/2mm Split Toe</a></h3>
      <p>The 3/2mm thickness covers the widest temperature range for European sailing. Split-toe design gives excellent strap feel. Reinforced sole protects against rocks without adding bulk.</p>

      <h3>Best for Cold Water: <a href="/t/brands/ion/boots">ION Ballistic 6/5mm Round Toe</a></h3>
      <p>Maximum insulation for winter sessions. Sealed seams, thermal lining, and a thick sole that blocks cold from below.</p>

      <h3>Best for Warm Water: ION Plasma 1.5mm Reef Walker</h3>
      <p>Thin, light, and barely noticeable on your feet. Protects soles from reef and rocks without adding heat. Perfect for Red Sea, Canary Islands, and Caribbean windsurfing.</p>

      <h2>Caring for Your Windsurfing Shoes</h2>
      <ul>
      <li><strong>Rinse</strong> in fresh water after every session</li>
      <li><strong>Turn inside-out</strong> to dry — inner lining dries faster with air exposure</li>
      <li><strong>Never use heat</strong> — radiators and dryers destroy neoprene</li>
      <li><strong>Store dry</strong> in a ventilated space</li>
      <li><strong>Replace</strong> when the sole wears through or seams leak consistently</li>
      </ul>

      <h2>FAQ</h2>
      <p>Q: Can I windsurf barefoot?<br>A: In warm water with sandy bottom, yes. But reef, rocks, cold water, or extended footstrap use all benefit from shoes.</p>
      <p>Q: Do windsurf boots fit in standard footstraps?<br>A: Yes — adjust straps slightly wider. Split-toe boots fit better in tight straps.</p>
      <p>Q: How long do windsurf boots last?<br>A: 1–3 seasons depending on usage and care. Replace when grip is compromised.</p>
    HTML
  },
  {
    slug: 'duotone-evo-sls-2026-buyer-s-guide',
    title: "Duotone Evo SLS 2026 Buyer's Guide",
    meta_title: "Duotone Evo SLS 2026 Review & Buyer's Guide",
    meta_description: "Duotone Evo SLS 2026 buyer's guide: specs, sizes, who it's for, how it compares, and why it's the world's best all-round kite. Shop at Surf Store.",
    body: <<~HTML
      <h2>Why the Duotone Evo Is the World's Most Popular Kite</h2>
      <p>The <a href="/t/brands/duotone-kiteboarding/kites">Duotone Evo</a> has been the best-selling all-round kite globally for over five years — and the 2026 SLS version continues that dominance. The reason is simple: no other kite does everything this well. It freerides, it boosts, it foils, it handles gusty conditions, it relaunches effortlessly, and it makes beginners feel safe while giving advanced riders room to push limits.</p>
      <p>The SLS (Stiff Lite Skin) construction adds a carbon-reinforced canopy that holds its shape under load, delivering more consistent power, faster turning, and better upwind angle than the standard Evo. It's the sweet spot between the standard construction and the ultra-premium D/LAB.</p>

      <h2>2026 Evo SLS Specifications</h2>
      <table>
      <thead><tr><th>Size</th><th>Span (m)</th><th>Weight (kg)</th><th>Wind Range (kts, 80kg)</th><th>Best For</th></tr></thead>
      <tbody>
      <tr><td>5m</td><td>6.8</td><td>2.3</td><td>28–40+</td><td>Storm sessions, small kite tricks</td></tr>
      <tr><td>7m</td><td>8.1</td><td>2.9</td><td>22–35</td><td>Strong wind freeride, wave</td></tr>
      <tr><td>9m</td><td>9.2</td><td>3.4</td><td>16–28</td><td>Core wind range, all-round</td></tr>
      <tr><td>10m</td><td>9.7</td><td>3.7</td><td>14–25</td><td>Medium wind, most sessions</td></tr>
      <tr><td>12m</td><td>10.6</td><td>4.2</td><td>10–20</td><td>Light wind, foiling</td></tr>
      <tr><td>14m</td><td>11.5</td><td>4.8</td><td>8–16</td><td>Ultra light wind</td></tr>
      </tbody>
      </table>

      <h2>Who Should Buy the Evo SLS?</h2>
      <p><strong>Beginners progressing beyond lessons:</strong> The Evo's massive depower range and easy relaunch make it the safest high-performance kite for riders still building skills. You'll never outgrow it.</p>
      <p><strong>Freeriders who want one quiver:</strong> If you ride twin-tip and foil in the same session, the Evo transitions between both seamlessly. No other kite handles this range as naturally.</p>
      <p><strong>Riders in gusty conditions:</strong> The Evo absorbs gusts better than almost any kite on the market. In thermals, offshore gusts, or variable coastal wind, the Evo keeps you riding comfortably while other kites become demanding.</p>

      <h2>Evo SLS vs Evo D/LAB</h2>
      <p>The D/LAB adds full carbon canopy construction — lighter by approximately 300g per size and noticeably stiffer in the canopy. The performance gains are real but subtle: slightly faster turning, marginally better upwind, and a more direct feel. For riders who kite 60+ days per year, the D/LAB premium is justified. For everyone else, <strong>SLS is the better value</strong> — delivering 90% of D/LAB performance at a significantly lower price.</p>

      <h2>Evo vs Other All-Round Kites</h2>
      <p>The Evo's closest competitor is the <a href="/t/brands/cabrinha/kites">Cabrinha Switchblade</a>. Both are excellent all-rounders with wide wind ranges. The key differences: the Evo has lighter bar pressure and faster turning; the Switchblade generates more low-end power and has floatier hangtime. For foiling, the Evo has the edge. For light-wind twin-tip, the Switchblade pulls harder. Both are outstanding kites — you can read our <a href="/en/posts/cabrinha-switchblade-vs-duotone-evo">detailed Switchblade vs Evo comparison</a>.</p>

      <h2>What Size Evo Should I Buy?</h2>
      <p>For your first Evo, choose the size that covers your most common wind range:</p>
      <ul>
      <li><strong>70kg rider, 15–25 knots:</strong> 9m</li>
      <li><strong>80kg rider, 15–25 knots:</strong> 10m</li>
      <li><strong>90kg rider, 15–25 knots:</strong> 11m or 12m</li>
      </ul>
      <p>A two-kite quiver of 9m + 12m covers 10–30 knots for most 80kg riders. Check our <a href="/en/posts/what-size-kite-do-i-need">complete kite size guide</a> for a detailed chart.</p>

      <h2>What Bar to Use</h2>
      <p>The Evo works with the <a href="/t/brands/duotone-kiteboarding/kite-bars">Duotone Click Bar</a> in both 4-line and 5-line configurations. We recommend the Click Bar in 22m line length for all-round use. 24m lines add depower range for light wind; 19m lines give faster kite response for wave riding.</p>

      <h2>FAQ</h2>
      <p>Q: Is the Evo good for freestyle?<br>A: Functional but not optimal. For dedicated unhooked freestyle, the <a href="/t/brands/duotone-kiteboarding/kites">Duotone Dice SLS</a> is purpose-built with more direct feedback and stiffer response.</p>
      <p>Q: Can I use the 2026 Evo with a 2024 Click Bar?<br>A: Yes — Duotone maintains cross-season bar compatibility.</p>
      <p>Q: How long does an Evo SLS last?<br>A: With proper care (rinse, dry, store deflated out of UV), 3–5 seasons of regular use. SLS construction holds its shape longer than standard.</p>
      <p>Q: Does Surf Store stock all Evo sizes?<br>A: We stock the full size range from 5m to 14m in SLS. D/LAB available on order. <a href="/t/brands/duotone-kiteboarding/kites">Browse all Duotone kites</a>.</p>
    HTML
  }
]

POSTS.each do |data|
  post = Spree::Post.find_or_initialize_by(slug: data[:slug])
  post.store = store
  post.title = data[:title]
  post.meta_title = data[:meta_title]
  post.meta_description = data[:meta_description]
  post.content = data[:body]
  post.published_at ||= Time.current
  post.save!
  puts "OK: #{post.slug} (id: #{post.id})"
rescue => e
  puts "FAIL: #{data[:slug]} => #{e.message[0, 120]}"
end
