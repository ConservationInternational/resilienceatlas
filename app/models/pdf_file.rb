class PdfFile
  def initialize(attributes, pdf_file_path, domain, site_name)
    @layer         = attributes['layer']
    @sources       = attributes['sources'] if attributes['sources'].present?
    @pdf_file_path = pdf_file_path
    @domain        = URI.parse(domain)
    @site_name     = site_name
  end

  def generate_pdf_file
    Prawn::Document.generate(@pdf_file_path) do |pdf|
      # header
      pdf.bounding_box [pdf.bounds.left, pdf.bounds.top], width: pdf.bounds.width do
        theme = SiteScope.find_by(name: @site_name).try(:header_theme)

        case theme
        when 'vs-theme'
          b_color = '636363'
          padding = 15
          logo    = 'logo-vs.png'
          color   = 'FFFFFF'
        else
          b_color = 'FFFFFF'
          padding = 0
          logo    = 'logo-ci.png'
          color   = 'DDDDDD'
        end

        pdf.font 'Helvetica'
        pdf.font_size 15
        pdf.table generated_table_header(logo), width: pdf.bounds.width, cell_style: { border_width: 0,
                                                                                       border_color: 'FFFFFF',
                                                                                       text_color: color,
                                                                                       padding: padding,
                                                                                       background_color: b_color
                                                                                     } do
          column(1).style align: :right
        end
        pdf.move_down(20)
      end

      # Content
      pdf.bounding_box([pdf.bounds.left, pdf.bounds.top - 50], width: pdf.bounds.width, height: pdf.bounds.height - 100) do
        pdf.move_down(10)
        pdf.font 'Helvetica'
        pdf.text "Layer: #{@layer['name']}", size: 10
        pdf.move_down(5)
        pdf.font_size 8
        pdf.text "Info: #{eval(@layer['info'])[:description] rescue @layer['info']}"
        pdf.move_down(5)
        pdf.text "Source: #{eval(@layer['info'])[:source] rescue @layer['info']}"
        pdf.move_down(10)
        pdf.table generated_table_data, width: pdf.bounds.width, row_colors: ['F6F6F6', 'FFFFFF'], cell_style: { border_width: 0,
                                                                                                                 border_color: 'F0F0F0',
                                                                                                                 text_color: '333333'
                                                                                                               }
        pdf.move_down(10)
      end

      # footer
      pdf.bounding_box [pdf.bounds.left, pdf.bounds.bottom + 25], width: pdf.bounds.width do
        pdf.font 'Helvetica'
        pdf.font_size 7
        pdf.stroke_horizontal_rule
        pdf.move_down(5)
        pdf.table generated_table_footer, width: pdf.bounds.width, cell_style: { border_width: 0,
                                                                                 border_color: 'FFFFFF',
                                                                                 text_color: '333333',
                                                                                 padding: 0
                                                                               } do
          column(1).style align: :right
        end
      end
    end
  end

  def generated_table_header(logo)
    image_file = Rails.root.join("app/assets/images/#{logo}")

    header_left_0  = { image: open(image_file), fit: [100, 50] }
    header_right_0 = @site_name

    header_a = [header_left_0, "#{header_right_0}"]

    table_data = Array.new
    table_data << header_a

    table_data
  end

  def generated_table_data
    table_data = Array.new
    table_data << ['LAYER', "ID: #{@layer['id']}"]
    table_data << ['Source ID', "#{@layer['source_id']}"]
    table_data << ['Layer Type', "#{@layer['layer_type']}"]
    table_data << ['Updated', "#{@layer['last_updated']}"]
    table_data << ['Start Date', "#{@layer['start_date']}"]
    table_data << ['End Date', "#{@layer['end_date']}"]
    table_data << ['Spatial Resolution', "#{@layer['spatial_resolution']}"]
    table_data << ['Spatial Resolution Units', "#{@layer['spatial_resolution_units']}"]
    table_data << ['Temporal Resolution', "#{@layer['temporal_resolution']}"]
    table_data << ['Spatial Resolution Units', "#{@layer['temporal_resolution_units']}"]
    table_data << ['Data Units', "#{@layer['data_units']}"]
    table_data << ['Update Frequency', "#{@layer['update_frequency']}"]
    table_data << ['Layer Version', "#{@layer['version']}"]
    table_data << ['Processing', "#{@layer['processing']}"]

    @sources.map do |source|
      table_data << ['','']
      table_data << ['','']
      table_data << ['SOURCE', "ID: #{source['id']}"]
      table_data << ['Source Type', "#{source['source_type']}"]
      table_data << ['Reference', "#{source['reference']}"]
      table_data << ['Reference Short', "#{source['reference_short']}"]
      table_data << ['URL', "#{source['url']}"]
      table_data << ['Contact Name', "#{source['contact_name']}"]
      table_data << ['Contact Email', "#{source['contact_email']}"]
      table_data << ['License', "#{source['license']}"]
      table_data << ['License URL', "#{source['license_url']}"]
      table_data << ['Updated', "#{source['last_updated']}"]
      table_data << ['Version', "#{source['version']}"]
      table_data << ['Spatial Resolution Units', "#{source['spatial_resolution_units']}"]
    end if @sources.present?

    table_data
  end

  def generated_table_footer
    footer_left_0  = "#{@site_name} - #{@domain.host}"
    footer_left_1  = "resilience@conservation.org"
    footer_right_0 = Time.now.to_formatted_s(:short)

    footer_a = ["#{footer_left_0}", "#{footer_right_0}"]
    footer_b = ["#{footer_left_1}", ""]

    table_data = Array.new
    table_data << footer_a
    table_data << footer_b

    table_data
  end
end
