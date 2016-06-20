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
  def initialize(attributes, pdf_file_path)
    @layer         = attributes['layer']
    @source        = attributes['source'] if attributes['source'].present?
    @pdf_file_path = pdf_file_path
  end

  def generate_pdf_file
    Prawn::Document.generate(@pdf_file_path) do |pdf|
      # header
      pdf.bounding_box [pdf.bounds.left, pdf.bounds.top], width: pdf.bounds.width do
        pdf.font "Helvetica"
        pdf.text @layer['name'], align: :left, size: 20
        pdf.stroke_horizontal_rule
      end

      # footer
      pdf.bounding_box [pdf.bounds.left, pdf.bounds.bottom + 25], width: pdf.bounds.width do
        pdf.font "Helvetica"
        pdf.stroke_horizontal_rule
        pdf.move_down(5)
        pdf.text @layer['name'], size: 10
      end

      # Content
      pdf.bounding_box([pdf.bounds.left, pdf.bounds.top - 50], width: pdf.bounds.width, height: pdf.bounds.height - 100) do
        pdf.text "Info: #{@layer['info']}"
        pdf.move_down(20)
        pdf.table generated_table_data, width: pdf.bounds.width
      end
    end
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
      sh = ['Updated', "#{@source['last_updated']}"]
      si = ['Version', "#{@source['version']}"]
      sj = ['Spatial Resolution Units', "#{@source['spatial_resolution_units']}"]
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
    end

    table_data
  end
end
