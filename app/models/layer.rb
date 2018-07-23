# == Schema Information
#
# Table name: layers
#
#  id                        :integer          not null, primary key
#  layer_group_id            :integer
#  slug                      :string           not null
#  layer_type                :string
#  zindex                    :integer
#  active                    :boolean
#  order                     :integer
#  color                     :string
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
#  zoom_max                  :integer          default(100)
#  zoom_min                  :integer          default(0)
#  dashboard_order           :integer
#  download                  :boolean          default(FALSE)
#  dataset_shortname         :string
#  dataset_source_url        :text
#  start_date                :datetime
#  end_date                  :datetime
#  spatial_resolution        :string
#  spatial_resolution_units  :string
#  temporal_resolution       :string
#  temporal_resolution_units :string
#  update_frequency          :string
#  version                   :string
#  analysis_suitable         :boolean          default(FALSE)
#  analysis_query            :text
#

require 'zip'

class Layer < ActiveRecord::Base
  has_and_belongs_to_many :sources

  has_many :agrupations,  dependent: :destroy
  has_many :layer_groups, through: :agrupations,  dependent: :destroy

  accepts_nested_attributes_for :agrupations, allow_destroy: true
  accepts_nested_attributes_for :sources, allow_destroy: true

  translates :name, :info, :legend, :title, :data_units, :processing, :description
  active_admin_translates :name, :info, :legend, :title, :data_units, :processing, :description do; end

  default_scope { with_translations(I18n.locale) }
  scope :site, -> (site) { eager_load([layer_groups: :super_group]).
    where(layer_groups: { site_scope_id: site }) }

  def self.fetch_all(options={})
    if options[:site_scope]
      site_scope = options[:site_scope].to_i
    else
      site_scope = 1
    end
    layers = Layer.all
    layers = layers.site(site_scope)
  end

  def clone!
    l = self.clone
    new_layer = Layer.new(l.attributes.except("id"))
    new_layer.name = "#{self.name} _copy_ #{DateTime.now}"
    new_layer.save!
    return new_layer
  end

  def zip_attachments(options, domain, site_name=nil, subdomain=nil)
    site_name = site_name.present? ? site_name : 'Conservation International'

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

    zipfile = zipfile_name(subdomain)

    return false   if !download?
    return zipfile if File.exists?(zipfile) && date_valid?(subdomain)

    layer_file = open(URI.encode(layer_url).to_s) if layer_url

    ::Zip::OutputStream.open(zipfile) do |zip|
      if layer_file
        layer_name = file_name ? file_name : "#{self.name.parameterize}-extra"
        zip.put_next_entry("#{layer_name}.#{file_format}")
        zip.write IO.read(layer_file.path)
      end

      layer_attr = {}
      layer_attr['layer']   = attributes
      layer_attr['sources'] = sources.map { |s| s.attributes } if sources.any?

      pdf_file = PdfFile.new(layer_attr, pdf_file_path, domain, site_name)
      pdf_file.generate_pdf_file

      zip.put_next_entry("#{pdf_file_name}")
      zip.write IO.read(pdf_file_path)
      File.delete(pdf_file_path)
    end

    zipfile
  end

  private

    def date_valid?(subdomain)
      file_date    = File.basename(zipfile_name(subdomain), '.zip').split('-date-').last
      self_date    = self.updated_at.to_date.to_s.parameterize
      source_date  = self.sources.map { |s| s.updated_at.to_date.to_s.parameterize }.compact.flatten.max if sources.any?
      objects_date = [self_date, source_date].compact.max

      return true if file_date >= objects_date
    end

    def zipfile_name(subdomain)
      "#{Rails.root}/downloads/#{self.name.parameterize}-date-#{DateTime.now.to_date.to_s.parameterize}-#{subdomain}.zip"
    end

    def pdf_file_path
      "#{Rails.root}/downloads/#{pdf_file_name}"
    end

    def pdf_file_name
      "#{self.name.parameterize}.pdf"
    end
end
