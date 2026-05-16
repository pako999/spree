require 'rqrcode'
require 'prawn'

class QrLabelService
  LABEL_WIDTH = 150
  LABEL_HEIGHT = 100

  def self.generate_png(racket)
    qr = RQRCode::QRCode.new(racket.qr_code)
    qr.as_png(size: 300, border_modules: 2).to_s
  end

  def self.generate_pdf(racket)
    qr_png = generate_png(racket)

    Prawn::Document.new(page_size: [LABEL_WIDTH, LABEL_HEIGHT], margin: 5) do |pdf|
      pdf.image StringIO.new(qr_png), width: 60, position: :left
      pdf.move_up 55

      pdf.bounding_box([65, pdf.cursor], width: 75) do
        pdf.font_size(7) do
          pdf.text racket.qr_code, style: :bold
          pdf.text "#{racket.brand} #{racket.model}", size: 6
          pdf.text racket.racket_type.name, size: 5
          pdf.text racket.racket_type.category.upcase, size: 5
        end
      end
    end.render
  end

  def self.generate_batch_pdf(rackets)
    Prawn::Document.new(page_size: 'A4', margin: 20) do |pdf|
      rackets.each_with_index do |racket, i|
        pdf.start_new_page if i > 0 && (i % 10).zero?

        col = i % 2
        row = (i / 2) % 5
        x = col * 280
        y = pdf.bounds.top - (row * 150)

        pdf.bounding_box([x, y], width: 260, height: 140) do
          pdf.stroke_bounds
          qr_png = generate_png(racket)
          pdf.image StringIO.new(qr_png), width: 80, at: [5, 135]

          pdf.bounding_box([90, 130], width: 160) do
            pdf.text racket.qr_code, size: 12, style: :bold
            pdf.move_down 4
            pdf.text "#{racket.brand} #{racket.model}", size: 10
            pdf.text racket.racket_type.name, size: 9
            pdf.text racket.racket_type.category.upcase, size: 8, color: '666666'
          end
        end
      end
    end.render
  end
end
