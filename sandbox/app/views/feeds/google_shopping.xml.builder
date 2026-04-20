xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'

xml.rss(version: '2.0', 'xmlns:g' => 'http://base.google.com/ns/1.0') do
  xml.channel do
    xml.title     @store_name
    xml.link      FeedsController::STORE_URL
    xml.description 'Windsurf, SUP, kite, wing and surf gear'

    @items.each do |item|
      xml.item do
        xml.tag! 'g:id',                      item[:id]
        xml.tag! 'g:item_group_id',           item[:item_group_id]           if item[:item_group_id].present?
        xml.tag! 'g:title',                   item[:title]
        xml.tag! 'g:description',             item[:description]             if item[:description].present?
        xml.tag! 'g:link',                    item[:link]
        xml.tag! 'g:image_link',              item[:image_link]              if item[:image_link].present?
        xml.tag! 'g:price',                   item[:price]
        xml.tag! 'g:availability',            item[:availability]
        xml.tag! 'g:condition',               item[:condition]
        xml.tag! 'g:brand',                   item[:brand]                   if item[:brand].present?
        xml.tag! 'g:gtin',                    item[:gtin]                    if item[:gtin].present?
        xml.tag! 'g:mpn',                     item[:mpn]                     if item[:mpn].present?
        xml.tag! 'g:google_product_category', item[:google_product_category] if item[:google_product_category].present?
        xml.tag! 'g:color',                   item[:color]                   if item[:color].present?
        xml.tag! 'g:size',                    item[:size]                    if item[:size].present?
        xml.tag! 'g:gender',                  item[:gender]                  if item[:gender].present?
      end
    end
  end
end
