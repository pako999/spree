# Allow style and class attributes in ActionText content.
# Blog post HTML (stored via update_column by admin scripts) uses inline styles
# and CSS class names from the blog design system — these must not be stripped
# at render time. User-submitted content never reaches ActionText in this app.
Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_attributes.add('style')
  ActionText::ContentHelper.allowed_attributes.add('class')
  ActionText::ContentHelper.allowed_attributes.add('target')
  ActionText::ContentHelper.allowed_tags.add('section')
end
