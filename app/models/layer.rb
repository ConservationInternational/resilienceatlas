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

require 'zip'

class Layer < ActiveRecord::Base
  belongs_to :source, inverse_of: :layers, required: false

  has_many :agrupations,  dependent: :destroy
  has_many :layer_groups, through: :agrupations,  dependent: :destroy

  accepts_nested_attributes_for :agrupations, allow_destroy: true

  scope :site, -> (site) { eager_load([layer_groups: :super_group]).where(layer_groups:{site_scope_id: site}) }

  def self.fetch_all(options={})
    if options[:site_scope]
      site_scope = options[:site_scope].to_i
    else
      site_scope = 1
    end
    layers = Layer.all
    layers = layers.site(site_scope)
  end

  def zip_attachments(options)
    download_path   = options['download_path']  if options['download_path'].present?
    download_query  = options['q']              if options['q'].present?
    download_format = options['with_format']    if options['with_format'].present?
    file_format     = options['file_format']    if options['file_format'].present?

    file_name       = if options['filename'].present?
                        options['filename']
                      elsif options['download_path'].present? && URI(options['download_path']).query.present?
                        query_path = URI(options['download_path']).query
                        filename   = query_path.split('=')[1] if query_path.split('=')[0].include?('filename')
                        filename
                      end

    layer_url  = "#{download_path}"       if download_path
    layer_url += "&q=#{download_query}"   if download_query
    layer_url += "&format=#{file_format}" if download_format

    zipfile = zipfile_name

    return false   if !download?
    return zipfile if File.exists?(zipfile) && date_valid?

    layer_file = open(URI.encode(layer_url).to_s) if layer_url

    ::Zip::OutputStream.open(zipfile) do |zip|
      if layer_file
        layer_name = file_name ? file_name : "#{self.name.parameterize}-extra"
        zip.put_next_entry("#{layer_name}.#{file_format}")
        zip.write IO.read(layer_file.path)
      end

      layer_attr = {}
      layer_attr['layer']  = attributes
      layer_attr['source'] = source.attributes if source_id.present?

      pdf_file = PdfFile.new(layer_attr, pdf_file_path)
      pdf_file.generate_pdf_file

      zip.put_next_entry("#{pdf_file_name}")
      zip.write IO.read(pdf_file_path)
      File.delete(pdf_file_path)
    end

    zipfile
  end

  private

    def date_valid?
      file_date    = File.basename(zipfile_name, '.zip').split('-date-').last
      self_date    = self.updated_at.to_date.to_s.parameterize
      source_date  = self.source.updated_at.to_date.to_s.parameterize if source
      objects_date = [self_date, source_date].compact.max

      return true if file_date >= objects_date
    end

    def zipfile_name
      "#{Rails.root}/downloads/#{self.name.parameterize}-date-#{DateTime.now.to_date.to_s.parameterize}.zip"
    end

    def pdf_file_path
      "#{Rails.root}/downloads/#{pdf_file_name}"
    end

    def pdf_file_name
      "#{self.name.parameterize}.pdf"
    end
end
