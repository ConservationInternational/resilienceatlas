# == Schema Information
#
# Table name: layers
#
#  id                        :integer          not null, primary key
#  layer_group_id            :integer
#  name                      :string           not null
#  slug                      :string           not null
#  layer_type                :string
#  zindex                    :integer
#  active                    :boolean
#  order                     :integer
#  color                     :string
#  info                      :text
#  layer_provider            :string
#  css                       :text
#  interactivity             :text
#  opacity                   :float
#  query                     :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  locate_layer              :boolean          default(FALSE)
#  icon_class                :string
#  published                 :boolean          default(TRUE)
#  legend                    :text
#  zoom_max                  :integer          default(100)
#  zoom_min                  :integer          default(0)
#  dashboard_order           :integer
#  download                  :boolean          default(FALSE)
#  dataset_shortname         :string
#  dataset_source_url        :text
#  source_id                 :integer
#  title                     :string
#  start_date                :datetime
#  end_date                  :datetime
#  spatial_resolution        :string
#  spatial_resolution_units  :string
#  temporal_resolution       :string
#  temporal_resolution_units :string
#  data_units                :string
#  update_frequency          :string
#  version                   :string
#  processing                :string
#
# Table name: sources
#
#  id              :integer          not null, primary key
#  source_type     :string
#  reference       :string
#  reference_short :string
#  url             :string
#  contact_name    :string
#  contact_email   :string
#  license         :string
#  last_updated    :datetime
#  version         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class PdfFile
  def initialize(attributes, pdf_file_path, domain, site_name)
    @layer         = attributes['layer']
    @source        = attributes['source'] if attributes['source'].present?
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
    layer = ['LAYER', "ID: #{@layer['id']}"]

    a = ['Source ID', "#{@layer['source_id']}"]
    b = ['Layer Type', "#{@layer['layer_type']}"]
    c = ['Updated', "#{@layer['last_updated']}"]
    d = ['Start Date', "#{@layer['start_date']}"]
    e = ['End Date', "#{@layer['end_date']}"]
    f = ['Spatial Resolution', "#{@layer['spatial_resolution']}"]
    g = ['Spatial Resolution Units', "#{@layer['spatial_resolution_units']}"]
    h = ['Temporal Resolution', "#{@layer['temporal_resolution']}"]
    i = ['Spatial Resolution Units', "#{@layer['temporal_resolution_units']}"]
    j = ['Data Units', "#{@layer['data_units']}"]
    k = ['Update Frequency', "#{@layer['update_frequency']}"]
    l = ['Layer Version', "#{@layer['version']}"]
    m = ['Processing', "#{@layer['processing']}"]

    if @source
      source = ['SOURCE', "ID: #{@source['id']}"]

      sa = ['Source Type', "#{@source['source_type']}"]
      sb = ['Reference', "#{@source['reference']}"]
      sc = ['Reference Short', "#{@source['reference_short']}"]
      sd = ['URL', "#{@source['url']}"]
      se = ['Contact Name', "#{@source['contact_name']}"]
      sf = ['Contact Email', "#{@source['contact_email']}"]
      sg = ['License', "#{@source['license']}"]
      sh = ['License URL', "#{@source['license_url']}"]
      si = ['Updated', "#{@source['last_updated']}"]
      sj = ['Version', "#{@source['version']}"]
      sk = ['Spatial Resolution Units', "#{@source['spatial_resolution_units']}"]
    end

    table_data = Array.new
    table_data << layer
    table_data << a
    table_data << b
    table_data << c
    table_data << d
    table_data << e
    table_data << f
    table_data << g
    table_data << h
    table_data << i
    table_data << j
    table_data << k
    table_data << l
    table_data << m

    if @source
      table_data << source
      table_data << sa
      table_data << sb
      table_data << sc
      table_data << sd
      table_data << se
      table_data << sf
      table_data << sg
      table_data << sh
      table_data << si
      table_data << sj
      table_data << sk
    end

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
