// Tailwind CSS v4 - Minimal config for content paths only
// Theme configuration has been moved to app/assets/tailwind/application.css
const { execSync } = require('child_process');

// Resolve the spree_storefront gem path automatically
let storefrontPath = process.env.SPREE_STOREFRONT_PATH;
if (!storefrontPath) {
  try {
    storefrontPath = execSync('bundle show spree_storefront', { encoding: 'utf-8' }).trim();
  } catch (e) {
    storefrontPath = '/usr/local/lib/ruby/gems/4.0.0/gems/spree_storefront-5.3.2';
  }
}

module.exports = {
  content: [
    'public/*.html',
    'app/helpers/**/*.rb',
    'app/javascript/**/*.js',
    'app/views/spree/**/*.erb',
    'app/views/devise/**/*.erb',
    'app/views/themes/**/*.erb',
    storefrontPath + '/app/helpers/**/*.rb',
    storefrontPath + '/app/javascript/**/*.js',
    storefrontPath + '/app/views/themes/**/*.erb',
    storefrontPath + '/app/views/spree/**/*.erb',
    storefrontPath + '/app/views/devise/**/*.erb'
  ]
}
