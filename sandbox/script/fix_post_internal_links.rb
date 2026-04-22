# Fix internal linking in SEO blog posts
# Replaces plain-text brand/product mentions with links to store pages
# Run: kamal app exec --reuse "bin/rails runner /rails/script/fix_post_internal_links.rb"

LINK_MAP = {
  # Brand pages
  'Duotone Evo SLS'      => '/t/brands/duotone-kiteboarding/kites',
  'Duotone Evo'          => '/t/brands/duotone-kiteboarding/kites',
  'Duotone Rebel SLS'    => '/t/brands/duotone-kiteboarding/kites',
  'Duotone Rebel'        => '/t/brands/duotone-kiteboarding/kites',
  'Duotone Dice SLS'     => '/t/brands/duotone-kiteboarding/kites',
  'Duotone Dice'         => '/t/brands/duotone-kiteboarding/kites',
  'Duotone Juice'        => '/t/brands/duotone-kiteboarding/kites',
  'Duotone Jaime SLS'    => '/t/brands/duotone-kiteboarding/kiteboards',
  'Duotone Jaime D/LAB'  => '/t/brands/duotone-kiteboarding/kiteboards',
  'Duotone Select SLS'   => '/t/brands/duotone-kiteboarding/kiteboards',
  'Duotone Gonzales'     => '/t/brands/duotone-kiteboarding/kiteboards',
  'Duotone Click Bar'    => '/t/brands/duotone-kiteboarding/kite-bars',
  'Duotone Whip D/LAB'   => '/t/brands/duotone-kiteboarding/kiteboards',
  'Duotone Apex Curv'    => '/t/brands/duotone-kiteboarding/harnesses',
  'Duotone Super_Star SLS' => '/t/brands/duotone-windsurfing/sails',
  'Duotone Super_Hero SLS' => '/t/brands/duotone-windsurfing/sails',
  'Duotone Super_Hero'   => '/t/brands/duotone-windsurfing/sails',
  'Duotone Warp_Foil'    => '/t/brands/duotone-windsurfing/sails',
  'Duotone Echo'         => '/t/brands/duotone-wing-foiling/wings',
  'Duotone Slick'        => '/t/brands/duotone-wing-foiling/wings',
  'Duotone Unit D/LAB'   => '/t/brands/duotone-wing-foiling/wings',
  'Duotone Spirit'       => '/t/brands/duotone-wing-foiling/foils',
  'Duotone Pace'         => '/t/brands/duotone-wing-foiling/boards',
  'Cabrinha Switchblade'  => '/t/brands/cabrinha/kites',
  'Cabrinha Moto X'      => '/t/brands/cabrinha/kites',
  'Cabrinha Moto'        => '/t/brands/cabrinha/kites',
  'Cabrinha Drifter'     => '/t/brands/cabrinha/kites',
  'Cabrinha FX'          => '/t/brands/cabrinha/kites',
  'Cabrinha Spectrum'    => '/t/brands/cabrinha/boards',
  'Cabrinha Unify'       => '/t/brands/cabrinha/bars',
  'NeilPryde Wizard'     => '/t/brands/neilpryde/wetsuits',
  'NeilPryde Fusion'     => '/t/brands/neilpryde/sails',
  'NeilPryde Atlas Pro'  => '/t/brands/neilpryde/sails',
  'NeilPryde RS:Flight'  => '/t/brands/neilpryde/sails',
  'Nobile NHP Carbon'    => '/t/brands/nobile/kiteboards',
  'Nobile NHP'           => '/t/brands/nobile/kiteboards',
  'ION Seek Amp'         => '/t/brands/ion/wetsuits',
  'ION Element'          => '/t/brands/ion/wetsuits',
  'ION Amaze Element'    => '/t/brands/ion/wetsuits',
  'ION Amaze'            => '/t/brands/ion/wetsuits',
  'ION Base'             => '/t/brands/ion/wetsuits',
  'ION Riot Curv'        => '/t/brands/ion/harnesses',
  'ION Apex'             => '/t/brands/ion/harnesses',
  'ION K-Pact'           => '/t/brands/ion-bike',
  'Gaastra Matrix'       => '/t/brands/gaastra/sails',
  'Gaastra Cosmic'       => '/t/brands/gaastra/sails',
  'Gaastra Boost'        => '/t/brands/gaastra/sails',
  'Point-7 AC-K'         => '/t/brands/point7/sails',
  'Point-7 AC-F'         => '/t/brands/point7/sails',
  'Point-7 Salt'         => '/t/brands/point7/sails',
  'Point-7 Spy'          => '/t/brands/point7/sails',
  'Fanatic Gecko'        => '/t/brands/fanatic-windsurfing/boards',
  'Fanatic Blast'        => '/t/brands/fanatic-windsurfing/boards',
  'Fanatic Falcon'       => '/t/brands/fanatic-windsurfing/boards',
  'Fanatic Grip'         => '/t/brands/fanatic-windsurfing/boards',
  'Fanatic Sky Wing'     => '/t/brands/duotone-wing-foiling/boards',
  'Fanatic Ray Air'      => '/t/brands/fanatic-sup/boards',
  'Fanatic Fly Air'      => '/t/brands/fanatic-sup/boards',
  'Fanatic Diamond Air'  => '/t/brands/fanatic-sup/boards',
  'Tabou Rocket'         => '/t/brands/tabou/boards',
  'JP Australia Super Ride' => '/t/brands/jp-australia-sup-windsurf-boards',
  'JP Super Ride'        => '/t/brands/jp-australia-sup-windsurf-boards',
  # Category pages
  'ION wetsuits'         => '/t/brands/ion/wetsuits',
  'ION harnesses'        => '/t/brands/ion/harnesses',
  'Duotone kites'        => '/t/brands/duotone-kiteboarding/kites',
  'Cabrinha kites'       => '/t/brands/cabrinha/kites',
  'NeilPryde sails'      => '/t/brands/neilpryde/sails',
}.freeze

# Sort by length descending so longer matches take priority (e.g., "Duotone Evo SLS" before "Duotone Evo")
SORTED_TERMS = LINK_MAP.keys.sort_by { |k| -k.length }

def add_links(html)
  return html if html.blank?

  linked = {}
  result = html.dup

  SORTED_TERMS.each do |term|
    url = LINK_MAP[term]
    next if linked[url] # Only one link per destination per post

    # Match term NOT already inside an <a> tag (skip if preceded by "> or href=")
    pattern = /(?<!["'>\/])(?<![a-zA-Z])(#{Regexp.escape(term)})(?![a-zA-Z])(?![^<]*<\/a>)/
    if result.match?(pattern)
      result.sub!(pattern, "<a href=\"#{url}\">\\1</a>")
      linked[url] = true
    end
  end

  result
end

updated = 0
Spree::Post.where.not(published_at: nil).each do |post|
  original = post.content.to_s
  next if original.blank?

  with_links = add_links(original)
  if with_links != original
    post.update!(content: with_links)
    link_count = with_links.scan('<a href=').count - original.scan('<a href=').count
    puts "#{post.slug}: +#{link_count} links"
    updated += 1
  else
    puts "#{post.slug}: no changes"
  end
end

puts "\nUpdated #{updated} posts with internal links"
