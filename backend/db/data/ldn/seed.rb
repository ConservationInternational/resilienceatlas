# LDN (Land Degradation Neutrality) Site Scope Seed Script
#
# This seed creates an LDN site scope that extends the Trends.Earth site scope
# with LDN counterbalancing layers from the trends.earth ldn_docker pipeline.
#
# Run this from the backend directory:
#   bundle exec rails runner db/data/ldn/seed.rb
#
# Or within rails console:
#   load 'db/data/ldn/seed.rb'

module LdnSeeder
  TITILER_BASE = ENV.fetch("TITILER_URL", "https://staging.titiler.resilienceatlas.org")

  # SDG 15.3.1 COGs on GCS (same as trendsearth seed)
  SDG_COG_BASE = "https://storage.googleapis.com/trendsearth-public/unccd_reporting/2016-2023"

  # LDN Counterbalancing COGs on S3 (private bucket, TiTiler needs AWS credentials)
  LDN_S3_BUCKET = "trends.earth-private"
  LDN_S3_PREFIX = "counterbalancing"

  # Source references
  SOURCES = {
    zenodo: {
      source_type: "Data",
      reference: "Zvoleff, A., Antunes Daldegan, G., Noon, M., García, C. L., Teich, I., & Conservation International. (2025). Trends.Earth SDG Indicator 15.3.1 Datasets (1.2) [Data set]. Zenodo.",
      reference_short: "CI, FAO-WOCAT, JRC (2025)",
      url: "https://doi.org/10.5281/zenodo.17514520",
      version: "1.2",
      license: "CC BY 4.0"
    },
    gpgv2_addendum: {
      source_type: "Methodology",
      reference: "UNCCD (2025). Addendum to the Good Practice Guidance. SDG Indicator 15.3.1 Proportion of land that is degraded over total land area. Version 2.0. United Nations Convention to Combat Desertification.",
      reference_short: "UNCCD GPGv2 Addendum (2025)",
      url: "https://www.unccd.int/resources/manuals-and-guides/addendum-good-practice-guidance-sdg-indicator-1531-proportion-land",
      license: "Public"
    }
  }.freeze

  # Dataset/methodology info
  DATASET_INFO = {
    trendsearth: {
      name: "Trends.Earth",
      short_name: "TE",
      s3_folder: "TE",
      filename_mode: "Trends.Earth",
      description: "This layer uses the Trends.Earth Land Productivity Dynamics (LPD) methodology, which calculates productivity trends using MODIS NDVI data with a linear regression approach."
    },
    fao_wocat: {
      name: "FAO-WOCAT",
      short_name: "FAO",
      s3_folder: "FAO-WOCAT",
      filename_mode: "FAO-WOCAT",
      description: "This layer uses the FAO-WOCAT Land Productivity Dynamics (LPD) methodology, which applies a 5-class system based on long-term productivity state and trend analysis."
    },
    jrc: {
      name: "JRC",
      short_name: "JRC",
      s3_folder: "JRC",
      filename_mode: "JRC",
      description: "This layer uses the Joint Research Centre (JRC) Land Productivity Dynamics (LPD) methodology, which employs phenological metrics derived from SPOT-VGT and PROBA-V satellite data."
    }
  }.freeze

  # SDG 15.3.1 COG file names (on GCS)
  SDG_COGS = {
    trendsearth: "TrendsEarth_SDG15.3.1_2000-2023_Trends.Earth.tif",
    fao_wocat: "TrendsEarth_SDG15.3.1_2000-2023_FAO-WOCAT.tif",
    jrc: "TrendsEarth_SDG15.3.1_2000-2023_JRC.tif"
  }.freeze

  # SDG Band mapping (1-indexed, same as trendsearth seed)
  SDG_BANDS = {
    sdg_baseline: 1,
    lpd_baseline: 2,
    lc_baseline: 3,
    soc_baseline: 4,
    sdg_2019: 5,
    lpd_2019: 6,
    lc_2019: 7,
    soc_2019: 8,
    sdg_status_2019: 9,
    sdg_2023: 10,
    lpd_2023: 11,
    lc_2023: 12,
    soc_2023: 13,
    sdg_status_2023: 14
  }.freeze

  # LDN Counterbalancing output file suffixes
  LDN_SUFFIXES = {
    gains_losses: "gains_losses.tif",
    net_change_by_unit: "net_change_by_unit.tif"
  }.freeze

  # LDN Counterbalancing spatial scales
  LDN_SCALES = {
    ecoregion: {
      label: "Counterbalancing by ecoregion",
      filename_part: "ecoregion",
      info: "Counterbalancing assessed within WWF ecoregions",
      slug_part: "eco"
    },
    country_ecoregion: {
      label: "Counterbalancing by ecoregion and country",
      filename_part: "country_ecoregion",
      info: "Counterbalancing assessed within intersections of country boundaries and WWF ecoregions",
      slug_part: "ctry-eco"
    }
  }.freeze

  # ──────────────────────────────────────────────────────────────
  # Colormap interpolation helpers (must precede constant definitions)
  # ──────────────────────────────────────────────────────────────

  # Build a fine-grained TiTiler interval colormap by linearly
  # interpolating between the given color stops.
  #
  # @param stops [Array<Hash>]  ordered list of {value:, color: [r,g,b,a]}
  # @param steps_per_segment [Integer] interpolation steps between each pair
  # @return [Array] interval colormap with transparent bookends for nodata
  def self.interpolate_colormap(stops, steps_per_segment: 15)
    intervals = []
    # Transparent region below data range
    intervals << [[-32_768, stops.first[:value] - 1], [0, 0, 0, 0]]

    stops.each_cons(2) do |a, b|
      v0, c0 = a[:value], a[:color]
      v1, c1 = b[:value], b[:color]

      (0...steps_per_segment).each do |i|
        t0 = i.to_f / steps_per_segment
        t1 = (i + 1).to_f / steps_per_segment

        seg_start = (v0 + (v1 - v0) * t0).round
        seg_end = (v0 + (v1 - v0) * t1).round

        # Use the midpoint fraction for the color
        t_mid = (t0 + t1) / 2.0
        r = (c0[0] + (c1[0] - c0[0]) * t_mid).round
        g = (c0[1] + (c1[1] - c0[1]) * t_mid).round
        b_ch = (c0[2] + (c1[2] - c0[2]) * t_mid).round
        a_ch = (c0[3] + (c1[3] - c0[3]) * t_mid).round

        intervals << [[seg_start, seg_end], [r, g, b_ch, a_ch]]
      end
    end

    # Transparent region above data range
    intervals << [[stops.last[:value] + 1, 32_767], [0, 0, 0, 0]]
    intervals
  end

  # Generate an array of hex color strings for a choropleth legend bucket
  # by interpolating between the same color stops used for the map.
  #
  # @param stops [Array<Hash>]  ordered list of {value:, color: [r,g,b]}
  # @param steps [Integer] total number of legend swatches
  # @return [Array<String>] hex colors e.g. ["#9b2779", ..., "#006500"]
  def self.interpolate_legend_colors(stops, steps: 20)
    v_min = stops.first[:value].to_f
    v_max = stops.last[:value].to_f

    (0...steps).map do |i|
      # Map step index to value range
      v = v_min + (v_max - v_min) * i / (steps - 1).to_f

      # Find the surrounding stops
      seg_idx = stops.each_cons(2).find_index { |a, b| v.between?(a[:value], b[:value]) } || 0
      a, b = stops[seg_idx], stops[seg_idx + 1]

      t = (b[:value] == a[:value]) ? 0.0 : (v - a[:value]).to_f / (b[:value] - a[:value])
      r = (a[:color][0] + (b[:color][0] - a[:color][0]) * t).round
      g = (a[:color][1] + (b[:color][1] - a[:color][1]) * t).round
      bl = (a[:color][2] + (b[:color][2] - a[:color][2]) * t).round

      format("#%02x%02x%02x", r, g, bl)
    end
  end

  # ──────────────────────────────────────────────────────────────
  # Colormaps (aligned with trends.earth styles.json)
  # ──────────────────────────────────────────────────────────────

  # SDG colormaps — interval format covering full Int16 range
  # Ensures nodata (-32768) and any unmapped values render transparent
  SDG_COLORMAPS = {
    sdg_indicator: [
      [[-32768, -2], [0, 0, 0, 0]],
      [[-1, -1], [155, 39, 121, 255]],
      [[0, 0], [247, 247, 247, 255]],
      [[1, 1], [0, 101, 0, 255]],
      [[2, 32767], [0, 0, 0, 0]]
    ],
    sdg_status: [
      [[-32768, 0], [0, 0, 0, 0]],
      [[1, 1], [118, 42, 131, 255]],
      [[2, 2], [175, 141, 195, 255]],
      [[3, 3], [231, 212, 232, 255]],
      [[4, 4], [247, 247, 247, 255]],
      [[5, 5], [217, 240, 211, 255]],
      [[6, 6], [127, 191, 123, 255]],
      [[7, 7], [27, 120, 55, 255]],
      [[8, 32767], [0, 0, 0, 0]]
    ],
    lpd: [
      [[-32768, 0], [0, 0, 0, 0]],
      [[1, 1], [155, 39, 121, 255]],
      [[2, 2], [192, 116, 155, 255]],
      [[3, 3], [225, 185, 189, 255]],
      [[4, 4], [247, 247, 247, 255]],
      [[5, 5], [0, 101, 0, 255]],
      [[6, 32767], [0, 0, 0, 0]]
    ],
    land_cover: [
      [[-32768, -2], [0, 0, 0, 0]],
      [[-1, -1], [155, 39, 121, 255]],
      [[0, 0], [247, 247, 247, 255]],
      [[1, 1], [0, 101, 0, 255]],
      [[2, 32767], [0, 0, 0, 0]]
    ],
    soc: [
      [[-32768, -101], [0, 0, 0, 0]],
      [[-100, -11], [155, 39, 121, 255]],
      [[-10, 10], [247, 247, 247, 255]],
      [[11, 32767], [0, 101, 0, 255]]
    ]
  }.freeze

  # LDN Counterbalancing colormaps (from styles.json "LDN Counterbalancing" entries)
  #
  # Gains/losses: categorical -1/0/1 (styles.json "LDN Counterbalancing (gains and losses)")
  #   -1 = loss (#9b2779), 0 = neutral (#f7f7f7), 1 = gain (#006500)
  #
  # Achievement: zero-centered diverging (styles.json "LDN Counterbalancing (land type achievement)")
  #   Data is int16 scaled by 100: -10000 = -100%, 10000 = +100%
  #   min (#9b2779) → zero (#f7f7f7) → max (#006500)
  #   Discretized into intervals for TiTiler
  #
  # Land types: unique integer codes from a positional encoding of input layers
  LDN_COLORMAPS = {
    # Gains/losses: Int16, values -1/0/1, nodata=-32768
    # Use interval format covering full Int16 range so no gaps exist
    gains_losses: [
      [[-32768, -2], [0, 0, 0, 0]],
      [[-1, -1], [155, 39, 121, 255]],
      [[0, 0], [247, 247, 247, 255]],
      [[1, 1], [0, 101, 0, 255]],
      [[2, 32767], [0, 0, 0, 0]]
    ],
    # Net change by unit: Int16, values -10000..10000 (percentage × 100), nodata=-32768
    # Continuous diverging colormap — interpolated between 7 key color stops so
    # TiTiler renders a smooth gradient rather than flat categorical blocks.
    net_change_by_unit: interpolate_colormap(
      [
        {value: -10_000, color: [155, 39, 121, 255]},
        {value: -5_000, color: [196, 131, 155, 255]},
        {value: -500, color: [224, 187, 213, 255]},
        {value: 0, color: [247, 247, 247, 255]},
        {value: 500, color: [211, 236, 207, 255]},
        {value: 5_000, color: [127, 191, 123, 255]},
        {value: 10_000, color: [0, 101, 0, 255]}
      ],
      steps_per_segment: 15
    )
  }.freeze

  # ──────────────────────────────────────────────────────────────
  # Legends
  # ──────────────────────────────────────────────────────────────

  SDG_LEGENDS = {
    sdg_indicator: {
      type: "custom",
      data: [
        {name: "Degradation", value: "#9b2779"},
        {name: "Stable", value: "#f7f7f7"},
        {name: "Improvement", value: "#006500"}
      ]
    },
    sdg_status: {
      type: "custom",
      data: [
        {name: "Degradation (persistent)", value: "#762a83"},
        {name: "Degradation (recent)", value: "#af8dc3"},
        {name: "Degradation (baseline)", value: "#e7d4e8"},
        {name: "Stability", value: "#f7f7f7"},
        {name: "Improvement (baseline)", value: "#d9f0d3"},
        {name: "Improvement (recent)", value: "#7fbf7b"},
        {name: "Improvement (persistent)", value: "#1b7837"}
      ]
    },
    lpd: {
      type: "custom",
      data: [
        {name: "Declining", value: "#9b2779"},
        {name: "Early signs of decline", value: "#c0749b"},
        {name: "Stable but stressed", value: "#e1b9bd"},
        {name: "Stable", value: "#f7f7f7"},
        {name: "Increasing", value: "#006500"}
      ]
    },
    land_cover: {
      type: "custom",
      data: [
        {name: "Degradation", value: "#9b2779"},
        {name: "Stable", value: "#f7f7f7"},
        {name: "Improvement", value: "#006500"}
      ]
    },
    soc: {
      type: "custom",
      data: [
        {name: "Degradation (< -10%)", value: "#9b2779"},
        {name: "Stable (-10% to +10%)", value: "#f7f7f7"},
        {name: "Improvement (> +10%)", value: "#006500"}
      ]
    }
  }.freeze

  LDN_LEGENDS = {
    gains_losses: {
      type: "custom",
      data: [
        {name: "Loss", value: "#9b2779"},
        {name: "Neutral", value: "#f7f7f7"},
        {name: "Gain", value: "#006500"}
      ]
    },
    net_change_by_unit: {
      type: "choropleth",
      bucket: interpolate_legend_colors(
        [
          {value: -10_000, color: [155, 39, 121]},
          {value: -5_000, color: [196, 131, 155]},
          {value: -500, color: [224, 187, 213]},
          {value: 0, color: [247, 247, 247]},
          {value: 500, color: [211, 236, 207]},
          {value: 5_000, color: [127, 191, 123]},
          {value: 10_000, color: [0, 101, 0]}
        ],
        steps: 20
      ),
      min: "-100%",
      mid: "Balanced",
      max: "+100%"
    }
  }.freeze

  class << self
    def run
      puts "Starting LDN site scope seed..."

      cleanup_old_ldn_layers
      reset_sequences

      sources = create_sources
      site_scope = create_site_scope
      groups = create_layer_groups(site_scope)

      # LDN Counterbalancing layers (order 1 = top of TOC)
      create_ldn_layers(groups, sources)

      # SDG / LPD / LC / SOC layers (orders 2-5, same as trendsearth)
      create_sdg_layers(groups, sources)
      create_lpd_layers(groups, sources)
      create_land_cover_layers(groups["ldn-land-cover"], sources)
      create_soc_layers(groups["ldn-soil-organic-carbon"], sources)

      # Pre-computed statistical datasets for the analysis panel
      create_scope_datasets(site_scope)

      puts "LDN site scope seed completed successfully!"
    end

    # Remove old LDN layers that were created directly under the productivity
    # mode subcategories (before the scale sub-subcategories were added).
    def cleanup_old_ldn_layers
      old_slugs = DATASET_INFO.keys.flat_map do |key|
        mode = key.to_s.tr("_", "-")
        [
          "ldn-achievement-#{mode}",
          "ldn-gains-losses-#{mode}",
          "ldn-land-types-#{mode}"
        ] + LDN_SCALES.values.flat_map do |scale|
          [
            "ldn-land-types-#{mode}-#{scale[:slug_part]}"
          ]
        end
      end
      old_slugs.each do |slug|
        layer = Layer.find_by(slug: slug)
        next unless layer
        puts "  Removing old layer: #{slug}"
        Agrupation.where(layer_id: layer.id).destroy_all
        layer.destroy!
      end
    end

    def reset_sequences
      puts "Resetting PostgreSQL sequences..."
      %w[site_scopes layer_groups layers agrupations sources scope_datasets scope_dataset_geometries].each do |table|
        ActiveRecord::Base.connection.execute(
          "SELECT setval(pg_get_serial_sequence('#{table}', 'id'), COALESCE(MAX(id), 1)) FROM #{table}"
        )
      end
    end

    # ──────────────────────────────────────────────────────────────
    # Sources
    # ──────────────────────────────────────────────────────────────

    def create_sources
      puts "Creating sources..."
      sources = {}
      SOURCES.each do |key, config|
        source = Source.find_or_initialize_by(url: config[:url])
        source.assign_attributes(
          source_type: config[:source_type],
          reference: config[:reference],
          reference_short: config[:reference_short],
          license: config[:license],
          version: config[:version]
        )
        source.save!
        sources[key] = source
        puts "  Created source: #{config[:reference_short]}"
      end
      sources
    end

    # ──────────────────────────────────────────────────────────────
    # Site scope
    # ──────────────────────────────────────────────────────────────

    def create_site_scope
      puts "Creating LDN site scope..."
      site_scope = SiteScope.find_or_initialize_by(subdomain: "ldn")
      site_scope.assign_attributes(
        name: "Land Degradation Neutrality",
        linkback_text: "Powered by Trends.Earth",
        linkback_text_color: "#FFFFFF",
        color: "#C62828",
        has_analysis: true,
        has_gef_logo: true,
        latitude: 0,
        longitude: 0,
        zoom_level: 2,
        header_theme: "dark",
        header_color: "#5D5D5D",
        logo_url: "https://storage.googleapis.com/trendsearth-public/logo/trends_earth_logo_print_colored.png",
        linkback_url: "https://trends.earth"
      )
      if SiteScope.column_names.include?("favicon_url")
        site_scope.favicon_url = "/images/trends_earth_logo_square_200x200.png"
      end
      site_scope.save!
      puts "  Created site scope: #{site_scope.subdomain}"
      site_scope
    end

    # ──────────────────────────────────────────────────────────────
    # Layer groups (TOC)
    # ──────────────────────────────────────────────────────────────

    def create_layer_groups(site_scope)
      puts "Creating layer groups..."
      groups = {}

      # ── Top-level categories ──
      # LDN is order 1 (top of TOC), then SDG, LPD, LC, SOC follow
      categories = {
        "ldn-counterbalancing" => {
          name: "LDN",
          info: "Land Degradation Neutrality (LDN) counterbalancing assessment. Evaluates whether gains in natural capital offset losses within spatial planning units, per the UNCCD GPGv2 Addendum methodology.",
          order: 1
        },
        "ldn-sdg-indicator-15-3-1" => {
          name: "SDG Indicator 15.3.1",
          info: "SDG Indicator 15.3.1 measures the proportion of land that is degraded over total land area.",
          order: 2
        },
        "ldn-land-productivity" => {
          name: "Land Productivity",
          info: "Land Productivity Dynamics (LPD) measures changes in vegetation productivity over time.",
          order: 3
        },
        "ldn-land-cover" => {
          name: "Land Cover",
          info: "Land cover change degradation layers showing transitions between land cover classes.",
          order: 4
        },
        "ldn-soil-organic-carbon" => {
          name: "Soil Organic Carbon",
          info: "Soil organic carbon (SOC) change layers showing percentage change in soil carbon stocks.",
          order: 5
        }
      }

      categories.each do |slug, config|
        group = LayerGroup.find_or_initialize_by(slug: slug, site_scope_id: site_scope.id)
        group.assign_attributes(
          :super_group_id => nil,
          :active => true,
          "order" => config[:order],
          :name => config[:name],
          :info => config[:info]
        )
        group.save!
        groups[slug] = group
        puts "  Created category: #{slug}"
      end

      # ── LDN subcategories: Trends.Earth, FAO-WOCAT, JRC ──
      ldn_subcats = {
        "ldn-cb-trendsearth" => {name: "Trends.Earth", info: "LDN counterbalancing using Trends.Earth productivity methodology", order: 1},
        "ldn-cb-fao-wocat" => {name: "FAO-WOCAT", info: "LDN counterbalancing using FAO-WOCAT productivity methodology", order: 2},
        "ldn-cb-jrc" => {name: "JRC", info: "LDN counterbalancing using JRC productivity methodology", order: 3}
      }

      ldn_subcats.each do |slug, config|
        subgroup = LayerGroup.find_or_initialize_by(slug: slug, site_scope_id: site_scope.id)
        subgroup.assign_attributes(
          :super_group_id => groups["ldn-counterbalancing"].id,
          :layer_group_type => "subcategory",
          :active => true,
          "order" => config[:order],
          :name => config[:name],
          :info => config[:info]
        )
        subgroup.save!
        groups[slug] = subgroup
        puts "    Created LDN subgroup: #{slug}"

        # ── Sub-subcategories: counterbalancing scales ──
        scale_order = 1
        LDN_SCALES.each do |scale_key, scale_config|
          scale_slug = "#{slug}-#{scale_config[:slug_part]}"
          scale_group = LayerGroup.find_or_initialize_by(slug: scale_slug, site_scope_id: site_scope.id)
          scale_group.assign_attributes(
            :super_group_id => subgroup.id,
            :layer_group_type => "subcategory",
            :active => true,
            "order" => scale_order,
            :name => scale_config[:label],
            :info => scale_config[:info]
          )
          scale_group.save!
          groups[scale_slug] = scale_group
          puts "      Created LDN scale subgroup: #{scale_slug}"
          scale_order += 1
        end
      end

      # ── SDG subcategories ──
      sdg_subcats = {
        "ldn-sdg-trendsearth" => {name: "Trends.Earth", info: "SDG 15.3.1 calculated using Trends.Earth productivity methodology", order: 1},
        "ldn-sdg-fao-wocat" => {name: "FAO-WOCAT", info: "SDG 15.3.1 calculated using FAO-WOCAT productivity methodology", order: 2},
        "ldn-sdg-jrc" => {name: "JRC", info: "SDG 15.3.1 calculated using JRC productivity methodology", order: 3}
      }

      sdg_subcats.each do |slug, config|
        subgroup = LayerGroup.find_or_initialize_by(slug: slug, site_scope_id: site_scope.id)
        subgroup.assign_attributes(
          :super_group_id => groups["ldn-sdg-indicator-15-3-1"].id,
          :layer_group_type => "subcategory",
          :active => true,
          "order" => config[:order],
          :name => config[:name],
          :info => config[:info]
        )
        subgroup.save!
        groups[slug] = subgroup
        puts "    Created SDG subgroup: #{slug}"
      end

      # ── LPD subcategories ──
      lpd_subcats = {
        "ldn-lpd-trendsearth" => {name: "Trends.Earth", info: "Land Productivity Dynamics using Trends.Earth methodology", order: 1},
        "ldn-lpd-fao-wocat" => {name: "FAO-WOCAT", info: "Land Productivity Dynamics using FAO-WOCAT methodology", order: 2},
        "ldn-lpd-jrc" => {name: "JRC", info: "Land Productivity Dynamics using JRC methodology", order: 3}
      }

      lpd_subcats.each do |slug, config|
        subgroup = LayerGroup.find_or_initialize_by(slug: slug, site_scope_id: site_scope.id)
        subgroup.assign_attributes(
          :super_group_id => groups["ldn-land-productivity"].id,
          :layer_group_type => "subcategory",
          :active => true,
          "order" => config[:order],
          :name => config[:name],
          :info => config[:info]
        )
        subgroup.save!
        groups[slug] = subgroup
        puts "    Created LPD subgroup: #{slug}"
      end

      groups
    end

    # ──────────────────────────────────────────────────────────────
    # LDN Counterbalancing layers (top of TOC)
    # ──────────────────────────────────────────────────────────────

    def create_ldn_layers(groups, sources)
      puts "Creating LDN counterbalancing layers..."

      datasets = [
        {key: :trendsearth, group_slug: "ldn-cb-trendsearth"},
        {key: :fao_wocat, group_slug: "ldn-cb-fao-wocat"},
        {key: :jrc, group_slug: "ldn-cb-jrc"}
      ]

      both_sources = [sources[:zenodo], sources[:gpgv2_addendum]]

      datasets.each do |dataset|
        info = DATASET_INFO[dataset[:key]]
        is_trendsearth = dataset[:key] == :trendsearth

        LDN_SCALES.each do |scale_key, scale_config|
          scale_slug = "#{dataset[:group_slug]}-#{scale_config[:slug_part]}"
          group = groups[scale_slug]
          label = "TrendsEarth_LDN_2000-2023_#{info[:filename_mode]}_#{scale_config[:filename_part]}"
          mode_suffix = dataset[:key].to_s.tr("_", "-")
          scale_suffix = scale_config[:slug_part]

          # Net change after counterbalancing layer (top of each subcategory)
          layer = create_ldn_cog_layer(
            group: group,
            slug: "ldn-net-change-#{mode_suffix}-#{scale_suffix}",
            s3_folder: info[:s3_folder],
            filename: "#{label}_#{LDN_SUFFIXES[:net_change_by_unit]}",
            colormap: LDN_COLORMAPS[:net_change_by_unit],
            legend: LDN_LEGENDS[:net_change_by_unit],
            name: "Net change after counterbalancing (#{info[:short_name]})",
            info: "Net change after counterbalancing per spatial unit (ΔᵢLDN) using #{info[:name]} productivity data. Positive values indicate LDN achieved for that unit, negative values indicate not achieved.",
            description: "LDN counterbalancing net change layer showing ΔᵢLDN = Aᵢgains − Aᵢlosses per spatial unit i, expressed as a percentage.\n\nPositive values (green) indicate gains offset losses. Negative values (magenta) indicate losses exceed gains. LDN is achieved when ALL units have ΔᵢLDN ≥ 0.\n\n#{info[:description]}",
            active: is_trendsearth && scale_key == :ecoregion,
            order: 1,
            color: "#C62828",
            analysis_type: "histogram",
            sources: both_sources
          )
          puts "    Created layer: #{layer.slug}"

          # Gains & Losses layer
          layer = create_ldn_cog_layer(
            group: group,
            slug: "ldn-gains-losses-#{mode_suffix}-#{scale_suffix}",
            s3_folder: info[:s3_folder],
            filename: "#{label}_#{LDN_SUFFIXES[:gains_losses]}",
            colormap: LDN_COLORMAPS[:gains_losses],
            legend: LDN_LEGENDS[:gains_losses],
            name: "LDN Gains & Losses (#{info[:short_name]})",
            info: "Net gains and losses of natural capital per pixel using #{info[:name]} productivity data. Based on the 7-class SDG 15.3.1 status: losses map to persistent/recent degradation, gains to persistent/recent improvement.",
            description: "LDN counterbalancing gains and losses layer.\n\nPixel values: -1 = Loss (persistent or recent degradation), 0 = Neutral (baseline degradation, stable, or baseline improvement), 1 = Gain (recent or persistent improvement).\n\n#{info[:description]}",
            active: false,
            order: 2,
            color: "#C62828",
            sources: both_sources
          )
          puts "    Created layer: #{layer.slug}"
        end
      end
    end

    # ──────────────────────────────────────────────────────────────
    # SDG Indicator 15.3.1 layers
    # ──────────────────────────────────────────────────────────────

    def create_sdg_layers(groups, sources)
      puts "Creating SDG 15.3.1 layers..."

      datasets = [
        {key: :trendsearth, group_slug: "ldn-sdg-trendsearth"},
        {key: :fao_wocat, group_slug: "ldn-sdg-fao-wocat"},
        {key: :jrc, group_slug: "ldn-sdg-jrc"}
      ]

      datasets.each do |dataset|
        group = groups[dataset[:group_slug]]
        info = DATASET_INFO[dataset[:key]]

        status_sources = [sources[:zenodo], sources[:gpgv2_addendum]]
        data_sources = [sources[:zenodo]]
        order = 1

        # SDG 15.3.1 Status 2023 vs Baseline
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-sdg-15-3-1-status-2023-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:sdg_status_2023],
          colormap: SDG_COLORMAPS[:sdg_status],
          legend: SDG_LEGENDS[:sdg_status],
          name: "SDG 15.3.1 Status 2023 vs Baseline (#{info[:short_name]})",
          info: "SDG Indicator 15.3.1 status in 2023 compared to 2000-2015 baseline, using #{info[:name]} productivity data.",
          description: "SDG Indicator 15.3.1 measures the proportion of land that is degraded over total land area. This layer shows the status in 2023 relative to the 2000-2015 baseline period.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: status_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 Status 2019 vs Baseline
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-sdg-15-3-1-status-2019-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:sdg_status_2019],
          colormap: SDG_COLORMAPS[:sdg_status],
          legend: SDG_LEGENDS[:sdg_status],
          name: "SDG 15.3.1 Status 2019 vs Baseline (#{info[:short_name]})",
          info: "SDG Indicator 15.3.1 status in 2019 compared to 2000-2015 baseline, using #{info[:name]} productivity data.",
          description: "SDG Indicator 15.3.1 measures the proportion of land that is degraded over total land area. This layer shows the status in 2019 relative to the 2000-2015 baseline period.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: status_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 2008-2023
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-sdg-15-3-1-2008-2023-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:sdg_2023],
          colormap: SDG_COLORMAPS[:sdg_indicator],
          legend: SDG_LEGENDS[:sdg_indicator],
          name: "SDG Indicator 15.3.1 2008-2023 (#{info[:short_name]})",
          info: "SDG Indicator 15.3.1 for the 2008-2023 reporting period, using #{info[:name]} productivity data.",
          description: "SDG Indicator 15.3.1 showing land degradation for the 2008-2023 period.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 2004-2019
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-sdg-15-3-1-2004-2019-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:sdg_2019],
          colormap: SDG_COLORMAPS[:sdg_indicator],
          legend: SDG_LEGENDS[:sdg_indicator],
          name: "SDG Indicator 15.3.1 2004-2019 (#{info[:short_name]})",
          info: "SDG Indicator 15.3.1 for the 2004-2019 reporting period, using #{info[:name]} productivity data.",
          description: "SDG Indicator 15.3.1 showing land degradation for the 2004-2019 period.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 Baseline 2000-2015
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-sdg-15-3-1-baseline-2000-2015-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:sdg_baseline],
          colormap: SDG_COLORMAPS[:sdg_indicator],
          legend: SDG_LEGENDS[:sdg_indicator],
          name: "SDG Indicator 15.3.1 Baseline 2000-2015 (#{info[:short_name]})",
          info: "SDG Indicator 15.3.1 for the baseline period 2000-2015, using #{info[:name]} productivity data.",
          description: "SDG Indicator 15.3.1 baseline showing land degradation status during the 2000-2015 baseline period.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
      end
    end

    # ──────────────────────────────────────────────────────────────
    # Land Productivity Dynamics layers
    # ──────────────────────────────────────────────────────────────

    def create_lpd_layers(groups, sources)
      puts "Creating LPD layers..."

      datasets = [
        {key: :trendsearth, group_slug: "ldn-lpd-trendsearth"},
        {key: :fao_wocat, group_slug: "ldn-lpd-fao-wocat"},
        {key: :jrc, group_slug: "ldn-lpd-jrc"}
      ]

      datasets.each do |dataset|
        group = groups[dataset[:group_slug]]
        info = DATASET_INFO[dataset[:key]]
        data_sources = [sources[:zenodo]]
        order = 1

        # LPD 2008-2023
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-lpd-2008-2023-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:lpd_2023],
          colormap: SDG_COLORMAPS[:lpd],
          legend: SDG_LEGENDS[:lpd],
          name: "LPD 2008-2023 (#{info[:short_name]})",
          info: "Land Productivity Dynamics for the 2008-2023 period using #{info[:name]} methodology.",
          description: "Land Productivity Dynamics (LPD) measures changes in vegetation productivity over time.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # LPD 2004-2019
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-lpd-2004-2019-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:lpd_2019],
          colormap: SDG_COLORMAPS[:lpd],
          legend: SDG_LEGENDS[:lpd],
          name: "LPD 2004-2019 (#{info[:short_name]})",
          info: "Land Productivity Dynamics for the 2004-2019 period using #{info[:name]} methodology.",
          description: "Land Productivity Dynamics (LPD) measures changes in vegetation productivity over time.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # LPD Baseline 2001-2015
        layer = create_sdg_cog_layer(
          group: group,
          slug: "ldn-lpd-baseline-2001-2015-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: SDG_BANDS[:lpd_baseline],
          colormap: SDG_COLORMAPS[:lpd],
          legend: SDG_LEGENDS[:lpd],
          name: "LPD Baseline 2001-2015 (#{info[:short_name]})",
          info: "Land Productivity Dynamics for the baseline period 2001-2015 using #{info[:name]} methodology.",
          description: "Land Productivity Dynamics (LPD) baseline showing vegetation productivity trends during the 2001-2015 baseline period.\n\n#{info[:description]}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
      end
    end

    # ──────────────────────────────────────────────────────────────
    # Land Cover layers (Trends.Earth dataset only)
    # ──────────────────────────────────────────────────────────────

    def create_land_cover_layers(group, sources)
      puts "Creating Land Cover layers..."

      lc_base_desc = "Land cover degradation is assessed by comparing land cover maps from the baseline and reporting periods using ESA CCI land cover data processed by Trends.Earth."
      data_sources = [sources[:zenodo]]

      layer = create_sdg_cog_layer(
        group: group,
        slug: "ldn-lc-degradation-2015-2022",
        cog_key: :trendsearth,
        band: SDG_BANDS[:lc_2023],
        colormap: SDG_COLORMAPS[:land_cover],
        legend: SDG_LEGENDS[:land_cover],
        name: "Land Cover Degradation 2015-2022 (TE)",
        info: "Land cover change degradation indicator for 2015-2022 based on ESA CCI land cover data processed by Trends.Earth.",
        description: lc_base_desc,
        active: false,
        order: 1,
        color: "#FF9800",
        sources: data_sources
      )
      puts "    Created layer: #{layer.slug}"

      layer = create_sdg_cog_layer(
        group: group,
        slug: "ldn-lc-degradation-2015-2019",
        cog_key: :trendsearth,
        band: SDG_BANDS[:lc_2019],
        colormap: SDG_COLORMAPS[:land_cover],
        legend: SDG_LEGENDS[:land_cover],
        name: "Land Cover Degradation 2015-2019 (TE)",
        info: "Land cover change degradation indicator for 2015-2019 based on ESA CCI land cover data processed by Trends.Earth.",
        description: lc_base_desc,
        active: false,
        order: 2,
        color: "#FF9800",
        sources: data_sources
      )
      puts "    Created layer: #{layer.slug}"

      layer = create_sdg_cog_layer(
        group: group,
        slug: "ldn-lc-degradation-2000-2015",
        cog_key: :trendsearth,
        band: SDG_BANDS[:lc_baseline],
        colormap: SDG_COLORMAPS[:land_cover],
        legend: SDG_LEGENDS[:land_cover],
        name: "Land Cover Degradation Baseline 2000-2015 (TE)",
        info: "Land cover change degradation indicator for the 2000-2015 baseline period based on ESA CCI data processed by Trends.Earth.",
        description: "Land cover degradation for the baseline period (2000-2015) using ESA CCI land cover data.",
        active: false,
        order: 3,
        color: "#FF9800",
        sources: data_sources
      )
      puts "    Created layer: #{layer.slug}"
    end

    # ──────────────────────────────────────────────────────────────
    # Soil Organic Carbon layers (Trends.Earth dataset only)
    # ──────────────────────────────────────────────────────────────

    def create_soc_layers(group, sources)
      puts "Creating SOC layers..."

      soc_base_desc = "Soil organic carbon (SOC) change is estimated based on land cover transitions and associated changes in carbon stocks, using IPCC default carbon stock values processed by Trends.Earth."
      data_sources = [sources[:zenodo]]

      layer = create_sdg_cog_layer(
        group: group,
        slug: "ldn-soc-degradation-2015-2022",
        cog_key: :trendsearth,
        band: SDG_BANDS[:soc_2023],
        colormap: SDG_COLORMAPS[:soc],
        legend: SDG_LEGENDS[:soc],
        name: "SOC Change 2015-2022 (TE)",
        info: "Percentage change in soil organic carbon stocks for 2015-2022, processed by Trends.Earth.",
        description: "#{soc_base_desc}\n\nValues represent percentage change in SOC from baseline to target year. Degradation is defined as < -10%, stable as -10% to +10%, and improvement as > +10%.",
        active: false,
        order: 1,
        color: "#795548",
        analysis_type: "histogram",
        sources: data_sources
      )
      puts "    Created layer: #{layer.slug}"

      layer = create_sdg_cog_layer(
        group: group,
        slug: "ldn-soc-degradation-2015-2019",
        cog_key: :trendsearth,
        band: SDG_BANDS[:soc_2019],
        colormap: SDG_COLORMAPS[:soc],
        legend: SDG_LEGENDS[:soc],
        name: "SOC Change 2015-2019 (TE)",
        info: "Percentage change in soil organic carbon stocks for 2015-2019, processed by Trends.Earth.",
        description: "#{soc_base_desc}\n\nValues represent percentage change in SOC from baseline to target year. Degradation is defined as < -10%, stable as -10% to +10%, and improvement as > +10%.",
        active: false,
        order: 2,
        color: "#795548",
        analysis_type: "histogram",
        sources: data_sources
      )
      puts "    Created layer: #{layer.slug}"

      layer = create_sdg_cog_layer(
        group: group,
        slug: "ldn-soc-degradation-2000-2015",
        cog_key: :trendsearth,
        band: SDG_BANDS[:soc_baseline],
        colormap: SDG_COLORMAPS[:soc],
        legend: SDG_LEGENDS[:soc],
        name: "SOC Change Baseline 2000-2015 (TE)",
        info: "Percentage change in soil organic carbon stocks for the 2000-2015 baseline period, processed by Trends.Earth.",
        description: "Soil organic carbon (SOC) change for the baseline period (2000-2015) using IPCC default carbon stock values.",
        active: false,
        order: 3,
        color: "#795548",
        analysis_type: "histogram",
        sources: data_sources
      )
      puts "    Created layer: #{layer.slug}"
    end

    # ──────────────────────────────────────────────────────────────
    # Scope Datasets (pre-computed statistics from GeoPackage files)
    # ──────────────────────────────────────────────────────────────

    # Default directory containing GPKG files and lookup CSVs.
    # One level above Rails.root (backend/../) where the GPKGs live.
    # Override with LDN_DATA_DIR environment variable.
    DATA_DIR_DEFAULT = File.expand_path("../../..", __dir__)

    # LDN achievement category colours shared by all chart configs.
    CATEGORY_COLORS = {
      "Exceeding" => "#2ecc71",
      "Achieving" => "#f39c12",
      "Not achieving" => "#e74c3c"
    }.freeze

    # Methodology variants — GPKG filename fragment → human label.
    SCOPE_DATASET_VARIANTS = {
      "te" => {filename_mode: "Trends.Earth", label: "Trends.Earth"},
      "fao-wocat" => {filename_mode: "FAO-WOCAT", label: "FAO-WOCAT"},
      "jrc" => {filename_mode: "JRC", label: "JRC"}
    }.freeze

    # ── Dataset definitions ──
    #
    # Each key becomes the group_key on the resulting ScopeDataset.
    # :sql        — query against _gpkg_raw (the ogr2ogr-imported GPKG).
    # :dimension  — spatial aggregation level shown to the user.
    # :geometry_* — optional; when present, dissolved geometries are
    #   inserted into scope_dataset_geometries for map highlighting.
    SCOPE_DATASET_DEFS = {
      # ── 1. Ecoregion-level summary ──
      "ecoregion-summary" => {
        name_template: "Ecoregion LDN Summary (%{variant})",
        description_template: "LDN counterbalancing summary per ecoregion using %{variant} productivity methodology.",
        display_order: 1,
        dimension: "ecoregion",
        dimension_config: {unit_label: "Ecoregion", unit_id_column: "eco_id", name_column: "ecoregion"},
        schema_config: [
          {name: "eco_id", type: "integer", label: "Ecoregion ID"},
          {name: "ecoregion", type: "string", label: "Ecoregion"},
          {name: "biome", type: "string", label: "Biome"},
          {name: "realm", type: "string", label: "Realm"},
          {name: "gains_km2", type: "number", label: "Gains (km²)", format: ",.1f"},
          {name: "losses_km2", type: "number", label: "Losses (km²)", format: ",.1f"},
          {name: "delta_ldn_km2", type: "number", label: "Net Change (km²)", format: ",.1f"},
          {name: "total_area_km2", type: "number", label: "Total Area (km²)", format: ",.1f"},
          {name: "gains_pct", type: "number", label: "Gains (% of area)", format: ".1f"},
          {name: "losses_pct", type: "number", label: "Losses (% of area)", format: ".1f"},
          {name: "ldn_pct", type: "number", label: "LDN Achievement (%)", format: ".1f"},
          {name: "category", type: "category", label: "Category"}
        ],
        chart_config: [
          {
            id: "category-donut",
            type: "donut",
            title: "LDN Achievement",
            description: "Number of ecoregions by LDN achievement category.",
            valueKey: "category",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "count"
          },
          {
            id: "area-donut",
            type: "donut",
            title: "LDN Achievement (by percent of land area)",
            description: "Share of total land area by LDN achievement category.",
            valueKey: "total_area_km2",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "sum"
          },
          {
            id: "ecoregion-ldn-bar",
            type: "horizontalBar",
            title: "LDN Achievement by Ecoregion",
            description: "Percentage of LDN achievement per ecoregion. Top 10 and bottom 10 shown.",
            xAxis: {key: "ldn_pct", label: "LDN Achievement (%)"},
            yAxis: {key: "ecoregion", fallback: "eco_id", label: "Ecoregion"},
            colorBy: {key: "category", colors: CATEGORY_COLORS},
            sortBy: {key: "ldn_pct", order: "desc"},
            topN: 10,
            bottomN: 10,
            unitIdColumn: "eco_id"
          },
          {
            id: "gains-losses-scatter",
            type: "scatter",
            title: "Gains vs Losses by Ecoregion",
            description: "Each point is an ecoregion. Points above the diagonal have net positive change.",
            xAxis: {key: "losses_pct", label: "Losses (% of area)"},
            yAxis: {key: "gains_pct", label: "Gains (% of area)"},
            sizeKey: "ldn_pct",
            colorBy: {key: "category", colors: CATEGORY_COLORS},
            unitIdColumn: "eco_id",
            labelKey: "ecoregion"
          }
        ],
        sql: <<~SQL,
          SELECT eco_id, MAX(ecoregion) AS ecoregion, MAX(biome) AS biome, MAX(realm) AS realm,
            ROUND(SUM(gains_km2)::numeric, 1) AS gains_km2,
            ROUND(SUM(losses_km2)::numeric, 1) AS losses_km2,
            ROUND(SUM(delta_ldn_km2)::numeric, 1) AS delta_ldn_km2,
            ROUND(SUM(area_km2)::numeric, 1) AS total_area_km2,
            CASE WHEN SUM(area_km2) > 0
              THEN ROUND((SUM(gains_km2) / SUM(area_km2) * 100)::numeric, 1)
              ELSE 0 END AS gains_pct,
            CASE WHEN SUM(area_km2) > 0
              THEN ROUND((SUM(losses_km2) / SUM(area_km2) * 100)::numeric, 1)
              ELSE 0 END AS losses_pct,
            CASE WHEN SUM(area_km2) > 0
              THEN ROUND((SUM(delta_ldn_km2) / SUM(area_km2) * 100)::numeric, 1)
              ELSE 0 END AS ldn_pct,
            CASE WHEN SUM(delta_ldn_km2) > 0 THEN 'Exceeding'
                 WHEN SUM(delta_ldn_km2) = 0 THEN 'Achieving'
                 ELSE 'Not achieving' END AS category
          FROM _gpkg_raw WHERE eco_id IS NOT NULL
          GROUP BY eco_id ORDER BY eco_id
        SQL
        geometry_dimension: "ecoregion"
      },

      # ── 2. Country-level summary ──
      "country-summary" => {
        name_template: "Country LDN Summary (%{variant})",
        description_template: "LDN counterbalancing summary per country using %{variant} productivity methodology.",
        display_order: 2,
        dimension: "country",
        dimension_config: {unit_label: "Country", unit_id_column: "admin0_id", name_column: "country"},
        schema_config: [
          {name: "admin0_id", type: "integer", label: "Country ID"},
          {name: "admin0_iso", type: "string", label: "Country ISO"},
          {name: "country", type: "string", label: "Country"},
          {name: "gains_km2", type: "number", label: "Gains (km²)", format: ",.1f"},
          {name: "losses_km2", type: "number", label: "Losses (km²)", format: ",.1f"},
          {name: "delta_ldn_km2", type: "number", label: "Net Change (km²)", format: ",.1f"},
          {name: "total_area_km2", type: "number", label: "Total Area (km²)", format: ",.1f"},
          {name: "gains_pct", type: "number", label: "Gains (% of area)", format: ".1f"},
          {name: "losses_pct", type: "number", label: "Losses (% of area)", format: ".1f"},
          {name: "ldn_pct", type: "number", label: "LDN Achievement (%)", format: ".1f"},
          {name: "category", type: "category", label: "Category"}
        ],
        chart_config: [
          {
            id: "category-donut",
            type: "donut",
            title: "LDN Achievement",
            description: "Number of countries by LDN achievement category.",
            valueKey: "category",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "count"
          },
          {
            id: "area-donut",
            type: "donut",
            title: "LDN Achievement (by percent of land area)",
            description: "Share of total land area by LDN achievement category.",
            valueKey: "total_area_km2",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "sum"
          },
          {
            id: "country-ldn-bar",
            type: "horizontalBar",
            title: "LDN Achievement by Country",
            description: "Percentage of LDN achievement per country. Top 10 and bottom 10 shown.",
            xAxis: {key: "ldn_pct", label: "LDN Achievement (%)"},
            yAxis: {key: "country", fallback: "admin0_id", label: "Country"},
            colorBy: {key: "category", colors: CATEGORY_COLORS},
            sortBy: {key: "ldn_pct", order: "desc"},
            topN: 10,
            bottomN: 10,
            unitIdColumn: "admin0_id"
          },
          {
            id: "gains-losses-scatter",
            type: "scatter",
            title: "Gains vs Losses by Country",
            description: "Each point is a country. Points above the diagonal have net positive change.",
            xAxis: {key: "losses_pct", label: "Losses (% of area)"},
            yAxis: {key: "gains_pct", label: "Gains (% of area)"},
            sizeKey: "ldn_pct",
            colorBy: {key: "category", colors: CATEGORY_COLORS},
            unitIdColumn: "admin0_id",
            labelKey: "country"
          }
        ],
        sql: <<~SQL,
          SELECT r.admin0_id::int AS admin0_id, MAX(a.shape_group) AS admin0_iso, MAX(r.country) AS country,
            ROUND(SUM(r.gains_km2)::numeric, 1) AS gains_km2,
            ROUND(SUM(r.losses_km2)::numeric, 1) AS losses_km2,
            ROUND(SUM(r.delta_ldn_km2)::numeric, 1) AS delta_ldn_km2,
            ROUND(SUM(r.area_km2)::numeric, 1) AS total_area_km2,
            CASE WHEN SUM(r.area_km2) > 0
              THEN ROUND((SUM(r.gains_km2) / SUM(r.area_km2) * 100)::numeric, 1)
              ELSE 0 END AS gains_pct,
            CASE WHEN SUM(r.area_km2) > 0
              THEN ROUND((SUM(r.losses_km2) / SUM(r.area_km2) * 100)::numeric, 1)
              ELSE 0 END AS losses_pct,
            CASE WHEN SUM(r.area_km2) > 0
              THEN ROUND((SUM(r.delta_ldn_km2) / SUM(r.area_km2) * 100)::numeric, 1)
              ELSE 0 END AS ldn_pct,
            CASE WHEN SUM(r.delta_ldn_km2) > 0 THEN 'Exceeding'
                 WHEN SUM(r.delta_ldn_km2) = 0 THEN 'Achieving'
                 ELSE 'Not achieving' END AS category
          FROM _gpkg_raw r
          LEFT JOIN _adm0_lkp a ON r.admin0_id::int = a.id
          WHERE r.admin0_id IS NOT NULL
          GROUP BY r.admin0_id::int ORDER BY r.admin0_id::int
        SQL
        geometry_dimension: "country"
      },

      # ── 3. Biome-level summary ──
      "biome-summary" => {
        name_template: "Biome LDN Summary (%{variant})",
        description_template: "LDN counterbalancing summary per biome using %{variant} productivity methodology.",
        display_order: 3,
        dimension: "biome",
        dimension_config: {unit_label: "Biome", unit_id_column: "biome", name_column: "biome"},
        schema_config: [
          {name: "biome", type: "string", label: "Biome"},
          {name: "realm", type: "string", label: "Realm (primary)"},
          {name: "gains_km2", type: "number", label: "Gains (km²)", format: ",.1f"},
          {name: "losses_km2", type: "number", label: "Losses (km²)", format: ",.1f"},
          {name: "delta_ldn_km2", type: "number", label: "Net Change (km²)", format: ",.1f"},
          {name: "total_area_km2", type: "number", label: "Total Area (km²)", format: ",.1f"},
          {name: "ldn_pct", type: "number", label: "LDN Achievement (%)", format: ".1f"},
          {name: "category", type: "category", label: "Category"}
        ],
        chart_config: [
          {
            id: "category-donut",
            type: "donut",
            title: "LDN Achievement",
            description: "Number of biomes by LDN achievement category.",
            valueKey: "category",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "count"
          },
          {
            id: "area-donut",
            type: "donut",
            title: "LDN Achievement (by percent of land area)",
            description: "Share of total land area by LDN achievement category.",
            valueKey: "total_area_km2",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "sum"
          },
          {
            id: "biome-ldn-bar",
            type: "horizontalBar",
            title: "LDN Achievement by Biome",
            description: "Percentage of LDN achievement per biome.",
            xAxis: {key: "ldn_pct", label: "LDN Achievement (%)"},
            yAxis: {key: "biome", label: "Biome"},
            colorBy: {key: "category", colors: CATEGORY_COLORS},
            sortBy: {key: "ldn_pct", order: "desc"},
            unitIdColumn: "biome"
          }
        ],
        sql: <<~SQL,
          SELECT biome, MODE() WITHIN GROUP (ORDER BY realm) AS realm,
            ROUND(SUM(gains_km2)::numeric, 1) AS gains_km2,
            ROUND(SUM(losses_km2)::numeric, 1) AS losses_km2,
            ROUND(SUM(delta_ldn_km2)::numeric, 1) AS delta_ldn_km2,
            ROUND(SUM(area_km2)::numeric, 1) AS total_area_km2,
            CASE WHEN SUM(area_km2) > 0
              THEN ROUND((SUM(delta_ldn_km2) / SUM(area_km2) * 100)::numeric, 1)
              ELSE 0 END AS ldn_pct,
            CASE WHEN SUM(delta_ldn_km2) > 0 THEN 'Exceeding'
                 WHEN SUM(delta_ldn_km2) = 0 THEN 'Achieving'
                 ELSE 'Not achieving' END AS category
          FROM _gpkg_raw WHERE biome IS NOT NULL
          GROUP BY biome ORDER BY biome
        SQL
        geometry_dimension: "biome"
      },

      # ── 4. Country × Ecoregion summary ──
      "country-ecoregion-summary" => {
        name_template: "Country × Ecoregion LDN Summary (%{variant})",
        description_template: "LDN counterbalancing summary per country and ecoregion intersection using %{variant} productivity methodology.",
        display_order: 4,
        dimension: "country",
        dimension_config: {unit_label: "Country × Ecoregion", unit_id_column: "admin0_id", name_column: "country"},
        schema_config: [
          {name: "admin0_id", type: "integer", label: "Country ID"},
          {name: "admin0_iso", type: "string", label: "Country ISO"},
          {name: "country", type: "string", label: "Country"},
          {name: "eco_id", type: "integer", label: "Ecoregion ID"},
          {name: "ecoregion", type: "string", label: "Ecoregion"},
          {name: "biome", type: "string", label: "Biome"},
          {name: "realm", type: "string", label: "Realm"},
          {name: "gains_km2", type: "number", label: "Gains (km²)", format: ",.1f"},
          {name: "losses_km2", type: "number", label: "Losses (km²)", format: ",.1f"},
          {name: "delta_ldn_km2", type: "number", label: "Net Change (km²)", format: ",.1f"},
          {name: "total_area_km2", type: "number", label: "Total Area (km²)", format: ",.1f"},
          {name: "ldn_pct", type: "number", label: "LDN Achievement (%)", format: ".1f"},
          {name: "category", type: "category", label: "Category"}
        ],
        chart_config: [
          {
            id: "country-summary-table",
            type: "table",
            title: "Country-Level LDN Summary",
            description: "Aggregated LDN metrics per country. Click a row to highlight on the map.",
            groupBy: "admin0_id",
            labelKey: "country",
            columns: %w[country gains_km2 losses_km2 delta_ldn_km2 total_area_km2 ldn_pct],
            aggregation: {
              gains_km2: "sum", losses_km2: "sum", delta_ldn_km2: "sum",
              total_area_km2: "sum", ldn_pct: "weighted_avg:total_area_km2"
            },
            sortBy: {key: "delta_ldn_km2", order: "desc"}
          }
        ],
        sql: <<~SQL
          SELECT r.admin0_id::int AS admin0_id, MAX(a.shape_group) AS admin0_iso, MAX(r.country) AS country,
            r.eco_id, MAX(r.ecoregion) AS ecoregion, MAX(r.biome) AS biome, MAX(r.realm) AS realm,
            ROUND(SUM(r.gains_km2)::numeric, 1) AS gains_km2,
            ROUND(SUM(r.losses_km2)::numeric, 1) AS losses_km2,
            ROUND(SUM(r.delta_ldn_km2)::numeric, 1) AS delta_ldn_km2,
            ROUND(SUM(r.area_km2)::numeric, 1) AS total_area_km2,
            CASE WHEN SUM(r.area_km2) > 0
              THEN ROUND((SUM(r.delta_ldn_km2) / SUM(r.area_km2) * 100)::numeric, 1)
              ELSE 0 END AS ldn_pct,
            CASE WHEN SUM(r.delta_ldn_km2) > 0 THEN 'Exceeding'
                 WHEN SUM(r.delta_ldn_km2) = 0 THEN 'Achieving'
                 ELSE 'Not achieving' END AS category
          FROM _gpkg_raw r
          LEFT JOIN _adm0_lkp a ON r.admin0_id::int = a.id
          WHERE r.admin0_id IS NOT NULL AND r.eco_id IS NOT NULL
          GROUP BY r.admin0_id::int, r.eco_id
          ORDER BY r.admin0_id::int, r.eco_id
        SQL
      }

    }.freeze

    def create_scope_datasets(site_scope)
      puts "Creating scope datasets from GPKG files..."

      # Clean up old dataset slugs from previous seed versions
      %w[ecoregion-land-types country-ecoregion-land-types land-types].each do |old_key|
        SCOPE_DATASET_VARIANTS.each_key do |variant_slug|
          old_slug = "ldn-#{variant_slug}-#{old_key}"
          old_ds = ScopeDataset.find_by(site_scope: site_scope, slug: old_slug)
          next unless old_ds
          puts "  Removing old dataset: #{old_slug}"
          old_ds.scope_dataset_geometries.delete_all
          old_ds.destroy!
        end
      end

      # Clean up the shared land-types dataset (no longer used)
      old_lt = ScopeDataset.find_by(site_scope: site_scope, slug: "ldn-land-types")
      if old_lt
        puts "  Removing old dataset: ldn-land-types"
        old_lt.scope_dataset_geometries.delete_all
        old_lt.destroy!
      end

      data_dir = ENV.fetch("LDN_DATA_DIR", DATA_DIR_DEFAULT)

      # ── Per-variant statistical datasets ──
      SCOPE_DATASET_VARIANTS.each do |variant_slug, variant_info|
        gpkg_file = "TrendsEarth_LDN_2000-2023_#{variant_info[:filename_mode]}_country_ecoregion_land_types.gpkg"
        gpkg_path = File.join(data_dir, gpkg_file)

        unless File.exist?(gpkg_path)
          puts "  SKIP #{variant_slug}: GPKG not found at #{gpkg_path}"
          next
        end

        import_gpkg_to_postgis(gpkg_path, data_dir)

        SCOPE_DATASET_DEFS.each do |group_key, defn|
          slug = "ldn-#{variant_slug}-#{group_key}"
          rows = fetch_rows(defn[:sql])

          dataset = ScopeDataset.find_or_initialize_by(
            site_scope: site_scope,
            slug: slug
          )
          dataset.assign_attributes(
            name: defn[:name_template] % {variant: variant_info[:label]},
            description: defn[:description_template] % {variant: variant_info[:label]},
            data_type: "tabular",
            group_key: group_key,
            variant_label: variant_info[:label],
            dimension: defn[:dimension],
            dimension_config: defn[:dimension_config] || {},
            schema_config: defn[:schema_config],
            chart_config: defn[:chart_config],
            data: rows,
            display_order: defn[:display_order]
          )
          dataset.save!
          puts "  Created dataset: #{slug} (#{rows.size} rows)"

          copy_dissolved_geometries(dataset, defn[:geometry_dimension])
        end

        cleanup_gpkg_tables
      end
    end

    # ── Helper: create a layer from an S3 LDN COG ──

    def create_ldn_cog_layer(group:, slug:, s3_folder:, filename:, colormap:, legend:, name:, info:, description:, active:, order:, color:, analysis_type: "categorical", sources: [])
      cog_url = "s3://#{LDN_S3_BUCKET}/#{LDN_S3_PREFIX}/#{s3_folder}/#{filename}"

      layer_config = {
        type: "tileLayer",
        body: {
          source: cog_url,
          colormap: colormap,
          nodata: -32768,
          options: {}
        }
      }

      save_layer(
        group: group, slug: slug, layer_config: layer_config, legend: legend,
        name: name, info: info, description: description, active: active,
        order: order, color: color, analysis_type: analysis_type, sources: sources
      )
    end

    # ── Helper: create a layer from a GCS SDG COG (multi-band) ──

    def create_sdg_cog_layer(group:, slug:, cog_key:, band:, colormap:, legend:, name:, info:, description:, active:, order:, color:, analysis_type: "categorical", sources: [])
      cog_url = "#{SDG_COG_BASE}/#{SDG_COGS[cog_key]}"

      layer_config = {
        type: "tileLayer",
        body: {
          source: cog_url,
          bidx: band,
          colormap: colormap,
          nodata: -32768,
          options: {}
        }
      }

      save_layer(
        group: group, slug: slug, layer_config: layer_config, legend: legend,
        name: name, info: info, description: description, active: active,
        order: order, color: color, analysis_type: analysis_type, sources: sources
      )
    end

    # ── Helper: persist a Layer + Agrupation ──

    def save_layer(group:, slug:, layer_config:, legend:, name:, info:, description:, active:, order:, color:, analysis_type:, sources:)
      layer = Layer.find_or_initialize_by(slug: slug)
      layer.assign_attributes(
        :layer_group_id => group.id,
        :layer_type => "raster",
        :zindex => 100,
        :active => active,
        "order" => order,
        :dashboard_order => order,
        :color => color,
        :layer_provider => "cog",
        :opacity => 1.0,
        :published => true,
        :zoom_max => 18,
        :zoom_min => 0,
        :download => true,
        :analysis_suitable => true,
        :analysis_type => analysis_type,
        :layer_config => layer_config.to_json,
        :interaction_config => "{}",
        :name => name,
        :info => info,
        :legend => legend.to_json,
        :description => description
      )
      layer.save!

      if sources.any?
        layer.sources.clear
        sources.each { |source| layer.sources << source unless layer.sources.include?(source) }
      end

      Agrupation.where(layer_id: layer.id).where.not(layer_group_id: group.id).destroy_all
      agrupation = Agrupation.find_or_initialize_by(layer_id: layer.id, layer_group_id: group.id)
      agrupation.active = active
      agrupation.save!

      layer
    end

    # ── Helper: import a GPKG file into a PostGIS table via ogr2ogr ──

    def import_gpkg_to_postgis(gpkg_path, data_dir)
      require "csv"
      conn = ActiveRecord::Base.connection
      dbcfg = ActiveRecord::Base.connection_db_config.configuration_hash

      pg_host = dbcfg[:host] || "localhost"
      pg_port = dbcfg[:port] || 5432
      pg_db = dbcfg[:database]
      pg_user = dbcfg[:username]
      pg_pass = dbcfg[:password]

      puts "  Importing GPKG via ogr2ogr..."
      env = {"PGPASSWORD" => pg_pass.to_s}
      pg_dsn = "PG:host=#{pg_host} port=#{pg_port} dbname=#{pg_db} user=#{pg_user}"
      cmd = [
        "ogr2ogr", "-f", "PostgreSQL", pg_dsn,
        gpkg_path, "land_types",
        "-nln", "_gpkg_raw", "-overwrite",
        "-lco", "GEOMETRY_NAME=geom",
        "-lco", "FID=ogc_fid",
        "-nlt", "PROMOTE_TO_MULTI"
      ]
      raise "ogr2ogr failed for #{gpkg_path}" unless system(env, *cmd)

      # Add computed columns: area, realm, country
      puts "  Enriching with area, realm, and country..."
      conn.execute(<<~SQL)
        ALTER TABLE _gpkg_raw
          ADD COLUMN IF NOT EXISTS area_km2 double precision,
          ADD COLUMN IF NOT EXISTS realm text,
          ADD COLUMN IF NOT EXISTS country text;
      SQL
      conn.execute("UPDATE _gpkg_raw SET area_km2 = ST_Area(geom::geography) / 1e6")

      # Realm from ecoregion_key.csv
      eco_csv = ENV.fetch("LDN_ECOREGION_KEY") { File.join(data_dir, "ecoregion_key.csv") }
      if File.exist?(eco_csv)
        conn.execute("CREATE TEMP TABLE IF NOT EXISTS _eco_lkp (eco_id int, eco_name text, biome_num int, biome_name text, realm text)")
        conn.execute("TRUNCATE _eco_lkp")
        copy_csv_to_table(conn, "_eco_lkp", eco_csv)
        conn.execute("UPDATE _gpkg_raw r SET realm = e.realm FROM _eco_lkp e WHERE r.eco_id = e.eco_id")
        puts "  Realm lookup applied"
      end

      # Country name from admin0_key.csv
      admin0_csv = ENV.fetch("LDN_ADMIN0_KEY") { File.join(data_dir, "admin0_key.csv") }
      if File.exist?(admin0_csv)
        conn.execute("CREATE TEMP TABLE IF NOT EXISTS _adm0_lkp (id int, shape_group text, shape_name text, shape_type text)")
        conn.execute("TRUNCATE _adm0_lkp")
        copy_csv_to_table(conn, "_adm0_lkp", admin0_csv)
        conn.execute("UPDATE _gpkg_raw r SET country = a.shape_name FROM _adm0_lkp a WHERE r.admin0_id::int = a.id")
        puts "  Country lookup applied"
      end
    end

    # ── Helper: stream a local CSV into a temp table via COPY FROM STDIN ──

    def copy_csv_to_table(conn, table_name, csv_path)
      raw = conn.raw_connection
      raw.copy_data("COPY #{table_name} FROM STDIN CSV HEADER") do
        File.open(csv_path, "r") do |f|
          while (line = f.gets)
            raw.put_copy_data(line)
          end
        end
      end
    end

    # ── Helper: run a SQL query and return an Array of Hashes ──

    def fetch_rows(sql)
      ActiveRecord::Base.connection.exec_query(sql).to_a.map do |row|
        row.transform_values { |v| v.is_a?(BigDecimal) ? v.to_f : v }
      end
    end

    # ── Helper: copy pre-dissolved geometries from ldn_dissolved_geometries ──

    def copy_dissolved_geometries(dataset, dimension)
      return unless dimension

      conn = ActiveRecord::Base.connection
      exists = conn.select_value(
        "SELECT to_regclass('public.ldn_dissolved_geometries') IS NOT NULL"
      )
      unless exists
        puts "    SKIP geometries for #{dataset.slug}: run `rake ldn:dissolve_geometries` first"
        return
      end

      puts "    Copying dissolved geometries (#{dimension}) for #{dataset.slug}..."
      dataset.scope_dataset_geometries.delete_all

      conn.execute(<<~SQL)
        INSERT INTO scope_dataset_geometries
          (scope_dataset_id, unit_id, properties, geom, created_at, updated_at)
        SELECT
          #{dataset.id},
          unit_id,
          properties,
          geom,
          NOW(), NOW()
        FROM ldn_dissolved_geometries
        WHERE dimension = '#{conn.quote_string(dimension)}'
      SQL

      count = dataset.scope_dataset_geometries.count
      puts "    Copied #{count} geometries"
    end

    # ── Helper: drop temporary tables created during GPKG import ──

    def cleanup_gpkg_tables
      conn = ActiveRecord::Base.connection
      %w[_gpkg_raw _eco_lkp _adm0_lkp].each do |t|
        conn.execute("DROP TABLE IF EXISTS #{t}")
      end
    end
  end
end

# Run the seeder
LdnSeeder.run
