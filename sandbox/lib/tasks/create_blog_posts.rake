namespace :spree do
  desc 'Create 5 SEO buying guide blog posts'
  task create_blog_posts: :environment do
    store = Spree::Store.default
    abort 'No default store found' unless store

    category = Spree::PostCategory.find_or_create_by!(store: store, title: 'Buying Guides') do |c|
      c.slug = 'buying-guides'
    end
    puts "Category: #{category.title}"

    author = Spree.admin_user_class.first
    puts "Author: #{author&.email || 'none'}"

    posts_data = [
      {
        title: 'Best Kiteboard for Beginners - Complete Guide',
        slug: 'best-kiteboard-for-beginners',
        meta_title: 'Best Kiteboard for Beginners 2026 | How to Choose Your First Board',
        meta_description: 'Find the perfect beginner kiteboard. Our expert guide covers board types, sizing, features, and top picks to help you start kitesurfing with confidence.',
        excerpt: 'Choosing your first kiteboard can be overwhelming. This guide breaks down everything you need to know about board types, sizes, and features to find the perfect beginner kiteboard.',
        content: <<~HTML
          <h2>How to Choose Your First Kiteboard</h2>
          <p>Selecting the right kiteboard as a beginner is one of the most important decisions you'll make in your kitesurfing journey. The right board will help you progress faster, have more fun, and stay safe on the water. In this comprehensive guide, we'll walk you through everything you need to know.</p>

          <h2>Types of Kiteboards</h2>
          <h3>Twin-Tip Kiteboards</h3>
          <p>Twin-tip kiteboards are the most popular choice for beginners and the standard board type in kitesurfing. They're symmetrical, meaning you can ride in both directions without switching your feet. This makes them incredibly forgiving and easy to learn on.</p>
          <p><strong>Best for:</strong> Beginners, freestyle, freeride, and all-around riding.</p>

          <h3>Directional Surfboards</h3>
          <p>Directional kite surfboards are shaped like traditional surfboards with a pointed nose and rounded tail. They're designed for wave riding and require more skill to use effectively.</p>
          <p><strong>Best for:</strong> Wave riding, experienced riders looking for a surfing feel.</p>

          <h3>Foil Boards</h3>
          <p>Foil boards have a hydrofoil attached underneath that lifts the board out of the water. They offer an incredible sensation of flying and are very efficient in light wind.</p>
          <p><strong>Best for:</strong> Light wind conditions, experienced riders seeking new challenges.</p>

          <h2>Kiteboard Size Guide</h2>
          <p>The size of your kiteboard depends primarily on your body weight and the wind conditions you'll be riding in. Here's a general guideline:</p>
          <ul>
            <li><strong>Under 65 kg:</strong> 132-136 cm board</li>
            <li><strong>65-80 kg:</strong> 136-140 cm board</li>
            <li><strong>80-95 kg:</strong> 140-145 cm board</li>
            <li><strong>Over 95 kg:</strong> 145-150 cm board</li>
          </ul>
          <p><strong>Pro tip:</strong> As a beginner, go one size larger than recommended. A bigger board provides more surface area, making it easier to get up on the water and maintain balance.</p>

          <h2>Key Features to Look For</h2>
          <h3>Rocker Profile</h3>
          <p>A flatter rocker makes the board faster and easier to get going, which is ideal for beginners. More rocker provides better wave performance but requires more power to get planing.</p>

          <h3>Flex Pattern</h3>
          <p>A medium flex board absorbs chop well and is comfortable to ride for longer sessions. Stiffer boards provide more pop for jumps but can be less forgiving for beginners.</p>

          <h3>Fins</h3>
          <p>Larger fins provide more grip and stability, making them perfect for beginners. As you progress, you can switch to smaller fins for less drag and more freedom in tricks.</p>

          <h3>Footstraps vs Boots</h3>
          <p>Start with adjustable footstraps. They're easier to get in and out of, and allow you to quickly release from the board if needed. Boots offer more control but are recommended for more advanced riders.</p>

          <h2>Our Top Picks for Beginners</h2>
          <p>Visit our <a href="/t/categories/kitesurfing/kiteboards">kiteboards collection</a> to browse our full range of beginner-friendly boards from top brands like Duotone, Cabrinha, and Nobile.</p>

          <h2>Frequently Asked Questions</h2>
          <h3>Can I use a used kiteboard as a beginner?</h3>
          <p>Absolutely! A well-maintained used board can save you money while you're learning. Just inspect it for delamination, deep scratches, or water damage before buying.</p>

          <h3>Do I need a different board for different conditions?</h3>
          <p>As a beginner, one good twin-tip board will cover all your needs. As you progress, you might want to add a surfboard for waves or a foil board for light wind days.</p>

          <h3>How long will my first kiteboard last?</h3>
          <p>With proper care, a quality kiteboard can last 3-5+ years. Rinse it with fresh water after each session and store it out of direct sunlight.</p>
        HTML
      },
      {
        title: 'Kite Size Chart - What Size Kite Do I Need?',
        slug: 'kite-size-chart-what-size-kite-do-i-need',
        meta_title: 'Kite Size Chart 2026 | What Size Kite Do I Need? Calculator & Guide',
        meta_description: 'Use our kite size chart to find the perfect kite size for your weight and wind conditions. Includes size calculator, wind range tables, and expert recommendations.',
        excerpt: 'Not sure what size kite you need? Use our comprehensive kite size chart and calculator to find the perfect kite for your weight and local wind conditions.',
        content: <<~HTML
          <h2>How to Choose the Right Kite Size</h2>
          <p>Choosing the correct kite size is essential for safe and enjoyable kitesurfing. The right size depends on two main factors: <strong>your body weight</strong> and <strong>wind speed</strong>. A kite that's too small won't generate enough power, while one that's too large can be dangerous and difficult to control.</p>

          <h2>Kite Size Chart by Weight and Wind Speed</h2>
          <p>Use this chart as a starting point. Kite sizes are in square meters (m²).</p>

          <h3>Rider Weight: 55-65 kg</h3>
          <ul>
            <li><strong>8-12 knots (light wind):</strong> 12-14 m²</li>
            <li><strong>12-18 knots (moderate):</strong> 9-12 m²</li>
            <li><strong>18-25 knots (strong):</strong> 7-9 m²</li>
            <li><strong>25+ knots (very strong):</strong> 5-7 m²</li>
          </ul>

          <h3>Rider Weight: 65-80 kg</h3>
          <ul>
            <li><strong>8-12 knots:</strong> 13-15 m²</li>
            <li><strong>12-18 knots:</strong> 10-13 m²</li>
            <li><strong>18-25 knots:</strong> 8-10 m²</li>
            <li><strong>25+ knots:</strong> 6-8 m²</li>
          </ul>

          <h3>Rider Weight: 80-95 kg</h3>
          <ul>
            <li><strong>8-12 knots:</strong> 14-17 m²</li>
            <li><strong>12-18 knots:</strong> 12-14 m²</li>
            <li><strong>18-25 knots:</strong> 9-12 m²</li>
            <li><strong>25+ knots:</strong> 7-9 m²</li>
          </ul>

          <h3>Rider Weight: 95+ kg</h3>
          <ul>
            <li><strong>8-12 knots:</strong> 15-19 m²</li>
            <li><strong>12-18 knots:</strong> 13-15 m²</li>
            <li><strong>18-25 knots:</strong> 10-13 m²</li>
            <li><strong>25+ knots:</strong> 8-10 m²</li>
          </ul>

          <h2>Quick Kite Size Formula</h2>
          <p>For a rough estimate, use this formula:</p>
          <p><strong>Kite Size (m²) = Your Weight (kg) ÷ Wind Speed (knots) × 2.2</strong></p>
          <p>Example: A 75 kg rider in 15 knots of wind: 75 ÷ 15 × 2.2 = <strong>11 m² kite</strong></p>

          <h2>How Many Kites Do I Need?</h2>
          <p>Most kiters own a <strong>quiver of 2-3 kites</strong> to cover their local wind range:</p>
          <ul>
            <li><strong>One kite setup:</strong> Choose a versatile mid-range size (10-12 m² for a 75 kg rider)</li>
            <li><strong>Two kite quiver:</strong> A small kite (7-9 m²) + a large kite (12-14 m²) covers most conditions</li>
            <li><strong>Three kite quiver:</strong> Small (7 m²) + Medium (10 m²) + Large (13 m²) covers everything</li>
          </ul>

          <h2>Kite Types and Their Wind Ranges</h2>
          <h3>Freeride Kites</h3>
          <p>The most versatile category with a wide wind range. Perfect for beginners and all-round riding. Examples: Duotone Evo, Cabrinha Switchblade.</p>

          <h3>Freestyle/Big Air Kites</h3>
          <p>Built for explosive power and big jumps. Slightly narrower wind range but incredible performance. Examples: Duotone Rebel, Cabrinha Contra.</p>

          <h3>Wave Kites</h3>
          <p>Quick turning and great drift for wave riding. Often one size smaller works well. Examples: Cabrinha Drifter, Duotone Neo.</p>

          <h2>Factors That Affect Your Kite Size Choice</h2>
          <ul>
            <li><strong>Board type:</strong> Foil boards need less power — go 2-3 m² smaller</li>
            <li><strong>Water conditions:</strong> Choppy water requires slightly more power</li>
            <li><strong>Skill level:</strong> Beginners should err on the smaller side for safety</li>
            <li><strong>Riding style:</strong> Wave riders prefer smaller, big air riders prefer larger</li>
          </ul>

          <p>Browse our complete <a href="/t/categories/kitesurfing/kites">kite collection</a> to find the perfect size for your needs. Our team is always happy to help you choose — just reach out!</p>
        HTML
      },
      {
        title: 'How to Choose a Wetsuit - Thickness & Size Guide',
        slug: 'how-to-choose-a-wetsuit-thickness-size-guide',
        meta_title: 'Wetsuit Guide 2026 | How to Choose Thickness, Size & Type',
        meta_description: 'Complete wetsuit buying guide. Learn how to choose the right wetsuit thickness for your water temperature, find your size, and pick the best type for your sport.',
        excerpt: 'Water temperature, thickness, fit, and material quality all matter when choosing a wetsuit. This guide helps you find the perfect wetsuit for kitesurfing, windsurfing, or any watersport.',
        content: <<~HTML
          <h2>Why the Right Wetsuit Matters</h2>
          <p>A well-fitting wetsuit is your most important piece of equipment after your kite or sail. It keeps you warm, protected, and comfortable so you can spend more time on the water. Choosing the wrong thickness or size can ruin your session — too thin and you'll freeze, too thick and you'll overheat and restrict your movement.</p>

          <h2>Wetsuit Thickness Guide by Water Temperature</h2>
          <p>Wetsuit thickness is measured in millimeters. The first number is the body thickness, the second is the arms/legs:</p>
          <ul>
            <li><strong>24°C+ (75°F+):</strong> Boardshorts/rashguard or 1-2mm shorty</li>
            <li><strong>20-24°C (68-75°F):</strong> 2mm full suit or 3/2mm</li>
            <li><strong>17-20°C (62-68°F):</strong> 3/2mm full suit</li>
            <li><strong>13-17°C (55-62°F):</strong> 4/3mm full suit</li>
            <li><strong>10-13°C (50-55°F):</strong> 5/3mm or 5/4mm full suit + boots</li>
            <li><strong>7-10°C (44-50°F):</strong> 5/4mm or 6/5mm + boots, gloves, hood</li>
            <li><strong>Below 7°C (44°F):</strong> 6/5mm or 6/4mm + full accessories</li>
          </ul>

          <h2>Types of Wetsuits</h2>
          <h3>Full Suits (Steamers)</h3>
          <p>Cover your entire body from ankles to wrists. The most common choice for kitesurfing and windsurfing in Europe. Available in all thickness ranges.</p>

          <h3>Shorties (Spring Suits)</h3>
          <p>Short arms and short legs, typically 2-3mm thick. Great for warm summer conditions when you need sun protection and light warmth.</p>

          <h3>Long Johns / Janes</h3>
          <p>Sleeveless full-length suits. Good for moderate conditions when you want arm freedom but leg warmth.</p>

          <h2>Wetsuit Fit Guide</h2>
          <p>A wetsuit should fit like a second skin — snug but not restrictive. Here's what to check:</p>
          <ul>
            <li><strong>No gaps:</strong> Water should not pool in the lower back, chest, or behind the knees</li>
            <li><strong>Full range of motion:</strong> You should be able to reach overhead and squat without restriction</li>
            <li><strong>Neck seal:</strong> Snug but not choking — you should be able to fit one finger inside the collar</li>
            <li><strong>No bunching:</strong> Excess material around joints causes chafing and lets water flush through</li>
          </ul>

          <h2>Key Features to Look For</h2>
          <h3>Seam Construction</h3>
          <ul>
            <li><strong>Flatlock seams:</strong> Budget-friendly, suitable for warmer water. Small holes let some water in.</li>
            <li><strong>Glued & blind-stitched (GBS):</strong> The standard for cold-water suits. Panels are glued together and stitched halfway through — no holes.</li>
            <li><strong>Sealed/taped seams:</strong> Premium option. GBS with liquid tape inside for maximum waterproofing.</li>
          </ul>

          <h3>Entry System</h3>
          <ul>
            <li><strong>Back zip:</strong> Easiest to get in and out of. Good for beginners.</li>
            <li><strong>Chest zip:</strong> Less water entry, more flexibility. The most popular choice for kitesurfers.</li>
            <li><strong>Zipperless:</strong> Maximum flexibility and warmth. Can be harder to put on.</li>
          </ul>

          <h3>Neoprene Quality</h3>
          <p>Premium neoprene (like Yamamoto) is lighter, stretchier, and warmer than standard neoprene. It costs more but makes a huge difference in comfort and performance.</p>

          <h2>Top Wetsuit Brands We Carry</h2>
          <p>Browse our <a href="/t/categories/wetsuits/men-wetsuits">men's wetsuits</a> and <a href="/t/categories/wetsuits/women-wetsuits">women's wetsuits</a> from ION, Neilpryde, and other premium brands.</p>
        HTML
      },
      {
        title: 'Wing Foil Beginner Guide - Everything You Need to Know',
        slug: 'wing-foil-beginner-guide',
        meta_title: 'Wing Foil Beginner Guide 2026 | How to Start Wing Foiling',
        meta_description: 'Complete beginner guide to wing foiling. Learn what equipment you need, how to choose your first wing and foil board, and tips to get up and riding fast.',
        excerpt: 'Wing foiling is the fastest-growing watersport in the world. This beginner guide covers everything from equipment selection to your first flights on the water.',
        content: <<~HTML
          <h2>What Is Wing Foiling?</h2>
          <p>Wing foiling (also called wingsurfing or wing surfing) combines a handheld inflatable wing with a hydrofoil board. The wing catches the wind to propel you, while the hydrofoil lifts you above the water for an incredible flying sensation. It's the fastest-growing watersport in the world — and for good reason.</p>

          <h2>Why Wing Foiling Is Perfect for Beginners</h2>
          <ul>
            <li><strong>Safe:</strong> No lines attached to you (unlike kitesurfing). Just let go of the wing if things go wrong.</li>
            <li><strong>Low wind:</strong> Works in lighter winds than kitesurfing (12+ knots to start)</li>
            <li><strong>Simple setup:</strong> Pump up the wing, attach the foil, and go. No launch assistance needed.</li>
            <li><strong>Versatile:</strong> Use the same equipment on lakes, rivers, and the ocean</li>
            <li><strong>Quick progression:</strong> Most people can ride within 5-10 sessions</li>
          </ul>

          <h2>Equipment You Need</h2>
          <h3>1. The Wing</h3>
          <p>An inflatable wing that you hold with handles or a boom. Size depends on wind and rider weight:</p>
          <ul>
            <li><strong>Under 70 kg:</strong> 4-5 m² wing for learning</li>
            <li><strong>70-85 kg:</strong> 5-6 m² wing for learning</li>
            <li><strong>85+ kg:</strong> 6-7 m² wing for learning</li>
          </ul>
          <p>Start with one mid-range size, then add smaller and larger wings as you progress.</p>

          <h3>2. The Board</h3>
          <p>Begin with a <strong>large, high-volume board</strong> (90-130 liters depending on your weight). More volume = more stability. You can downsize as your balance improves.</p>
          <ul>
            <li><strong>Under 70 kg:</strong> 80-100 liter board</li>
            <li><strong>70-85 kg:</strong> 95-120 liter board</li>
            <li><strong>85+ kg:</strong> 110-130 liter board</li>
          </ul>

          <h3>3. The Hydrofoil</h3>
          <p>The foil mounts under the board and has a front wing, rear wing, fuselage, and mast. For beginners:</p>
          <ul>
            <li><strong>Front wing:</strong> 1800-2200 cm² (larger = more lift at lower speeds)</li>
            <li><strong>Mast length:</strong> 60-75 cm (shorter = closer to water = less scary)</li>
            <li><strong>Material:</strong> Aluminum mast is affordable and durable for learning</li>
          </ul>

          <h3>4. Safety Gear</h3>
          <ul>
            <li><strong>Helmet:</strong> Essential while learning. You will fall.</li>
            <li><strong>Impact vest:</strong> Protects your ribs from the foil and board</li>
            <li><strong>Wetsuit:</strong> Appropriate for your local water temperature</li>
            <li><strong>Wing leash:</strong> Keeps the wing attached to your wrist</li>
            <li><strong>Board leash:</strong> Keeps the board nearby after a fall</li>
          </ul>

          <h2>Learning Steps</h2>
          <ol>
            <li><strong>Handle the wing on land:</strong> Practice sheeting in/out, turning, and body position on the beach</li>
            <li><strong>Prone on the board:</strong> Lie on the board with the wing, get comfortable</li>
            <li><strong>Kneeling:</strong> Kneel on the board while using the wing for power</li>
            <li><strong>Standing without foil:</strong> Stand up and ride the board flat on the water</li>
            <li><strong>First foil flights:</strong> Gradually increase speed until the foil lifts you up</li>
            <li><strong>Sustained foiling:</strong> Learn to control height and speed while foiling</li>
          </ol>

          <h2>Ready to Start?</h2>
          <p>Browse our <a href="/t/categories/wingfoil/wings">wings</a>, <a href="/t/categories/wingfoil/wing-boards">wing boards</a>, and <a href="/t/categories/wingfoil/wing-foils">wing foils</a> to build your complete setup. Our team can help you choose the right gear for your weight and local conditions.</p>
        HTML
      },
      {
        title: 'Complete Kitesurfing Gear Checklist - What Equipment Do You Need?',
        slug: 'kitesurfing-gear-checklist-equipment-guide',
        meta_title: 'Kitesurfing Equipment Checklist 2026 | Complete Gear Guide',
        meta_description: 'Complete kitesurfing gear checklist for beginners. Everything you need to start kitesurfing: kite, board, harness, wetsuit, safety gear, and accessories explained.',
        excerpt: 'Starting kitesurfing? Here is everything you need. From kites and boards to harnesses, wetsuits, and safety gear — your complete equipment checklist with buying advice.',
        content: <<~HTML
          <h2>The Complete Kitesurfing Equipment List</h2>
          <p>Getting into kitesurfing requires some investment in gear, but buying the right equipment from the start saves you money and frustration in the long run. Here's your complete checklist with buying advice for each item.</p>

          <h2>Essential Equipment</h2>

          <h3>1. Kite</h3>
          <p>The kite is your engine. It catches the wind and generates the power that pulls you across the water. As a beginner, you need one kite that covers your most common wind conditions.</p>
          <p><strong>Budget:</strong> €800-1,500 new / €400-800 used</p>
          <p><strong>What to look for:</strong> A freeride/all-round kite in the 10-12 m² range (for a 75 kg rider). Brands like Duotone, Cabrinha, and Nobile make excellent beginner-friendly kites.</p>
          <p>Read our <a href="/blog/kite-size-chart-what-size-kite-do-i-need">kite size guide</a> to find your perfect size.</p>

          <h3>2. Kite Bar and Lines</h3>
          <p>The bar connects you to the kite through 4 or 5 lines. Most kites come with a matching bar, but you can also buy them separately.</p>
          <p><strong>Budget:</strong> €300-500 (often included with the kite)</p>
          <p><strong>Key features:</strong> Quick-release safety system, adjustable line length (22-24m standard), depower strap.</p>

          <h3>3. Kiteboard</h3>
          <p>Your board is what you stand on. A twin-tip is the standard choice for beginners — it's symmetrical so you can ride in both directions.</p>
          <p><strong>Budget:</strong> €300-700 new / €150-400 used</p>
          <p><strong>What to look for:</strong> A 138-142 cm twin-tip for an average rider. Larger boards are easier to learn on.</p>
          <p>Read our <a href="/blog/best-kiteboard-for-beginners">beginner kiteboard guide</a> for detailed advice.</p>

          <h3>4. Harness</h3>
          <p>The harness wraps around your waist or seat and takes the strain of the kite off your arms. This is what makes kitesurfing possible for hours at a time.</p>
          <p><strong>Budget:</strong> €150-350</p>
          <p><strong>Types:</strong></p>
          <ul>
            <li><strong>Waist harness:</strong> Most popular for kitesurfing. Freedom of movement, sits on your lower back.</li>
            <li><strong>Seat harness:</strong> Wraps under your legs. Won't ride up. Great for beginners and heavier riders.</li>
          </ul>

          <h3>5. Wetsuit</h3>
          <p>Unless you're riding in the tropics, you'll need a wetsuit. Choose thickness based on your local water temperature.</p>
          <p><strong>Budget:</strong> €150-400</p>
          <p>Read our <a href="/blog/how-to-choose-a-wetsuit-thickness-size-guide">wetsuit guide</a> for detailed thickness recommendations.</p>

          <h2>Safety Equipment</h2>

          <h3>6. Helmet</h3>
          <p>A water sports helmet protects your head during crashes and from your own board. Highly recommended while learning.</p>
          <p><strong>Budget:</strong> €40-80</p>

          <h3>7. Impact Vest</h3>
          <p>Provides buoyancy and protects your ribs and back from impacts. Especially useful in shallow water or when learning jumps.</p>
          <p><strong>Budget:</strong> €60-120</p>

          <h3>8. Safety Knife / Hook Knife</h3>
          <p>A small line cutter that attaches to your harness. Essential in case you need to cut tangled lines in an emergency.</p>
          <p><strong>Budget:</strong> €10-20</p>

          <h2>Accessories</h2>

          <h3>9. Pump</h3>
          <p>You need a kite pump to inflate your kite before each session. Most kites come with one, but a quality dual-action pump saves time and effort.</p>
          <p><strong>Budget:</strong> €30-60</p>

          <h3>10. Board Leash (Optional)</h3>
          <p>Keeps your board attached to you when you fall. Useful for beginners but should only be used with a helmet and in uncrowded areas.</p>

          <h3>11. Neoprene Accessories</h3>
          <p>Depending on water temperature, you may need:</p>
          <ul>
            <li><strong>Wetsuit boots:</strong> €30-70 — for water below 15°C</li>
            <li><strong>Gloves:</strong> €25-50 — for water below 10°C</li>
            <li><strong>Hood:</strong> €20-40 — for water below 8°C</li>
          </ul>

          <h2>Total Budget Estimate</h2>
          <ul>
            <li><strong>New gear (complete setup):</strong> €2,000-3,500</li>
            <li><strong>Used gear (complete setup):</strong> €1,000-2,000</li>
            <li><strong>Mix of new and used:</strong> €1,500-2,500</li>
          </ul>

          <p>Browse our <a href="/t/categories/kitesurfing">complete kitesurfing collection</a> to find everything you need. We stock all major brands and offer expert advice to help you build the perfect setup.</p>
        HTML
      }
    ]

    posts_data.each do |data|
      post = Spree::Post.find_or_initialize_by(store: store, slug: data[:slug])
      post.assign_attributes(
        title: data[:title],
        meta_title: data[:meta_title],
        meta_description: data[:meta_description],
        post_category: category,
        author: author,
        published_at: Time.current
      )
      post.save!

      # ActionText fields
      post.update!(content: data[:content], excerpt: data[:excerpt])

      puts "Created: #{post.title}"
    end

    puts "\nDone! #{posts_data.size} blog posts created."
    puts "View them at: /admin/posts"
  end
end
