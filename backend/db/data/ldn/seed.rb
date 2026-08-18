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
#
# ── Ecoregion popup data ─────────────────────────────────────────────────────
# Run scripts/setup_ldn_data.sh for the complete loading workflow. The
# ldn:build_dimensions task creates ra_vector.ldn_dissolved_geometries, while
# the migration creates ra_nonspatial.ldn_ecoregion_stats and this seed
# populates it from each methodology's ecoregion summary CSV.
#
# Source files (one per methodology, from the counterbalancing AWS pipeline):
#   TrendsEarth_LDN_2000-2023_Trends.Earth_ecoregion_summary.csv
#   TrendsEarth_LDN_2000-2023_FAO-WOCAT_ecoregion_summary.csv
#   TrendsEarth_LDN_2000-2023_JRC_ecoregion_summary.csv
#
# The CSV files do not include a methodology column. This seed assigns values
# matching the dataset keys while loading each source file:
#   'trendsearth'  (Trends.Earth CSV)
#   'fao-wocat'    (FAO-WOCAT CSV)
#   'jrc'          (JRC CSV)
#
# Expected columns (matching the pipeline CSV output + added methodology):
#   eco_id                              INTEGER
#   methodology                         TEXT
#   gains_km2                           NUMERIC
#   losses_km2                          NUMERIC
#   total_area_km2                      NUMERIC
#   status_1_persistent_degradation_sqkm  NUMERIC
#   status_2_recent_degradation_sqkm      NUMERIC
#   status_3_baseline_degradation_sqkm    NUMERIC
#   status_4_stability_sqkm               NUMERIC
#   status_5_baseline_improvement_sqkm    NUMERIC
#   status_6_recent_improvement_sqkm      NUMERIC
#   status_7_persistent_improvement_sqkm  NUMERIC
#   deg_to_deg_sqkm   NUMERIC
#   deg_to_stable_sqkm NUMERIC
#   deg_to_imp_sqkm   NUMERIC
#   stable_to_deg_sqkm NUMERIC
#   stable_to_stable_sqkm NUMERIC
#   stable_to_imp_sqkm NUMERIC
#   imp_to_deg_sqkm   NUMERIC
#   imp_to_stable_sqkm NUMERIC
#   imp_to_imp_sqkm   NUMERIC
#   delta_ldn_km2                       NUMERIC
#   ldn_pct                             NUMERIC
# ────────────────────────────────────────────────────────────────────────────

module LdnSeeder
  TITILER_BASE = ENV.fetch("TITILER_URL", "https://staging.titiler.resilienceatlas.org")

  LDN_ECOREGION_LOOKUP_PATH = "/api/scope-datasets/ldn-ecoregion-at-point"

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
      short_name: "FAO-WOCAT",
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
      label: "Net change (counterbalancing by ecoregion)",
      by: "by ecoregion",
      filename_part: "ecoregion",
      info: "Counterbalancing assessed within WWF ecoregions",
      slug_part: "eco"
    },
    country_ecoregion: {
      label: "Net change (counterbalancing by ecoregion and country)",
      by: "by ecoregion and country",
      filename_part: "country_ecoregion",
      info: "Counterbalancing assessed within intersections of country boundaries and WWF ecoregions",
      slug_part: "ctry-eco"
    }
  }.freeze

  # ──────────────────────────────────────────────────────────────
  # Colormaps (aligned with trends.earth styles.json)
  # ──────────────────────────────────────────────────────────────

  # Colormaps for TiTiler tile rendering.
  # Categorical layers use inline dicts (small enough for query strings).
  # Continuous layers use named colormaps registered in TiTiler (see app.py).
  SDG_COLORMAPS = {
    sdg_indicator: {"-1" => [155, 39, 121, 255], "0" => [247, 247, 247, 255], "1" => [0, 101, 0, 255]},
    sdg_status: {
      "1" => [118, 42, 131, 255],
      "2" => [175, 141, 195, 255],
      "3" => [231, 212, 232, 255],
      "4" => [247, 247, 247, 255],
      "5" => [217, 240, 211, 255],
      "6" => [127, 191, 123, 255],
      "7" => [27, 120, 55, 255]
    },
    lpd: {
      "1" => [155, 39, 121, 255],
      "2" => [192, 116, 155, 255],
      "3" => [225, 185, 189, 255],
      "4" => [247, 247, 247, 255],
      "5" => [0, 101, 0, 255]
    },
    land_cover: {"-1" => [155, 39, 121, 255], "0" => [247, 247, 247, 255], "1" => [0, 101, 0, 255]},
    soc: "ra_soc_change"
  }.freeze

  LDN_COLORMAPS = {
    gains_losses: {"-1" => [155, 39, 121, 255], "0" => [247, 247, 247, 255], "1" => [0, 101, 0, 255]},
    net_change_by_unit: "ra_net_change"
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
      type: "choropleth",
      bucket: [
        "#9b2779", "#a84b87", "#b56f95", "#c1839e", "#c4939b",
        "#cda3a8", "#d4b3b5", "#dbc3c2", "#e0bbd5", "#e8cdd8",
        "#f0dfdb", "#f7f7f7", "#edf3e5", "#d3ecce", "#c0e4b5",
        "#a6d99b", "#8dcb82", "#73bc68", "#5aad4f", "#419e35",
        "#006500"
      ],
      min: "-100%",
      mid: "Stable",
      max: "+100%"
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
      bucket: [
        "#9b2779", "#a84b87", "#b56f95", "#c1839e", "#c4939b",
        "#cda3a8", "#d4b3b5", "#dbc3c2", "#e0bbd5", "#e8cdd8",
        "#f7f7f7",
        "#edf3e5", "#e1efda", "#d3ecce", "#c0e4b5", "#a6d99b",
        "#8dcb82", "#73bc68", "#5aad4f", "#419e35", "#006500"
      ],
      min: "-100%",
      mid: "Balanced",
      max: "+100%"
    }
  }.freeze

  class << self
    def run
      puts "Starting LDN site scope seed..."

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
      begin
        create_scope_datasets(site_scope)
      rescue => e
        puts "WARNING: Scope dataset creation failed (non-fatal): #{e.message}"
        puts "  Layers were created successfully. To load scope datasets, ensure"
        puts "  CSV files are available at LDN_DATA_DIR and re-run the seed."
      end

      puts "LDN site scope seed completed successfully!"
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
          name: "Land Degradation Neutrality (LDN)",
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

      # ── LDN subcategories: counterbalancing scales ──
      ldn_scale_order = 1
      LDN_SCALES.each do |scale_key, scale_config|
        slug = "ldn-cb-#{scale_config[:slug_part]}"
        subgroup = LayerGroup.find_or_initialize_by(slug: slug, site_scope_id: site_scope.id)
        subgroup.assign_attributes(
          :super_group_id => groups["ldn-counterbalancing"].id,
          :layer_group_type => "subcategory",
          :active => true,
          "order" => ldn_scale_order,
          :name => scale_config[:label],
          :info => scale_config[:info]
        )
        subgroup.save!
        groups[slug] = subgroup
        puts "    Created LDN subgroup: #{slug}"
        ldn_scale_order += 1
      end

      # ── Gains & Losses subcategory (bottom of LDN TOC) ──
      gl_subgroup = LayerGroup.find_or_initialize_by(slug: "ldn-cb-gains-losses", site_scope_id: site_scope.id)
      gl_subgroup.assign_attributes(
        :super_group_id => groups["ldn-counterbalancing"].id,
        :layer_group_type => "subcategory",
        :active => true,
        "order" => ldn_scale_order,
        :name => "LDN Gains and losses (per pixel)",
        :info => "Per-pixel gains and losses of natural capital based on the 7-class SDG 15.3.1 status."
      )
      gl_subgroup.save!
      groups["ldn-cb-gains-losses"] = gl_subgroup
      puts "    Created LDN subgroup: ldn-cb-gains-losses"

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

      both_sources = [sources[:zenodo], sources[:gpgv2_addendum]]

      LDN_SCALES.each do |scale_key, scale_config|
        group_slug = "ldn-cb-#{scale_config[:slug_part]}"
        group = groups[group_slug]
        scale_suffix = scale_config[:slug_part]
        order = 1

        DATASET_INFO.each do |dataset_key, info|
          is_trendsearth = dataset_key == :trendsearth
          mode_suffix = dataset_key.to_s.tr("_", "-")
          label = "TrendsEarth_LDN_2000-2023_#{info[:filename_mode]}_#{scale_config[:filename_part]}"

          # Net change after counterbalancing layer (one per methodology)
          layer = create_ldn_cog_layer(
            group: group,
            slug: "ldn-net-change-#{mode_suffix}-#{scale_suffix}",
            s3_folder: info[:s3_folder],
            filename: "#{label}_#{LDN_SUFFIXES[:net_change_by_unit]}",
            colormap: LDN_COLORMAPS[:net_change_by_unit],
            legend: LDN_LEGENDS[:net_change_by_unit],
            name: "Net change (#{scale_config[:by]}, #{info[:short_name]})",
            info: "Net change after counterbalancing per spatial unit (ΔᵢLDN) using #{info[:name]} productivity data. Positive values indicate LDN achieved for that unit, negative values indicate not achieved.",
            description: "LDN counterbalancing net change layer showing ΔᵢLDN = Aᵢgains − Aᵢlosses per spatial unit i, expressed as a percentage.\n\nPositive values (green) indicate gains offset losses. Negative values (magenta) indicate losses exceed gains. LDN is achieved when ALL units have ΔᵢLDN ≥ 0.\n\n#{info[:description]}",
            active: is_trendsearth && scale_key == :ecoregion,
            order: order,
            color: "#C62828",
            analysis_type: "histogram",
            methodology: dataset_key.to_s.tr("_", "-"),
            sources: both_sources
          )
          puts "    Created layer: #{layer.slug}"
          order += 1
        end
      end

      # Gains & Losses layers (one per methodology — same across scales)
      parent_group = groups["ldn-cb-gains-losses"]
      gl_order = 1
      DATASET_INFO.each do |dataset_key, info|
        mode_suffix = dataset_key.to_s.tr("_", "-")
        label = "TrendsEarth_LDN_2000-2023_#{info[:filename_mode]}_#{LDN_SCALES[:ecoregion][:filename_part]}"
        layer = create_ldn_cog_layer(
          group: parent_group,
          slug: "ldn-gains-losses-#{mode_suffix}",
          s3_folder: info[:s3_folder],
          filename: "#{label}_#{LDN_SUFFIXES[:gains_losses]}",
          colormap: LDN_COLORMAPS[:gains_losses],
          legend: LDN_LEGENDS[:gains_losses],
          name: "LDN gains and losses (per pixel, #{info[:short_name]})",
          info: "Net gains and losses of natural capital per pixel using #{info[:name]} productivity data. Based on the 7-class SDG 15.3.1 status: losses map to persistent/recent degradation, gains to persistent/recent improvement.",
          description: "LDN counterbalancing gains and losses layer.\n\nPixel values: -1 = Loss (persistent or recent degradation), 0 = Neutral (baseline degradation, stable, or baseline improvement), 1 = Gain (recent or persistent improvement).\n\n#{info[:description]}",
          active: false,
          order: gl_order,
          color: "#C62828",
          methodology: dataset_key.to_s.tr("_", "-"),
          sources: both_sources
        )
        puts "    Created layer: #{layer.slug}"
        gl_order += 1
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
          slug: "sdg-15-3-1-status-2023-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
          sources: status_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 Status 2019 vs Baseline
        layer = create_sdg_cog_layer(
          group: group,
          slug: "sdg-15-3-1-status-2019-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
          sources: status_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 2008-2023
        layer = create_sdg_cog_layer(
          group: group,
          slug: "sdg-15-3-1-2008-2023-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 2004-2019
        layer = create_sdg_cog_layer(
          group: group,
          slug: "sdg-15-3-1-2004-2019-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 Baseline 2000-2015
        layer = create_sdg_cog_layer(
          group: group,
          slug: "sdg-15-3-1-baseline-2000-2015-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
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
          slug: "lpd-2008-2023-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # LPD 2004-2019
        layer = create_sdg_cog_layer(
          group: group,
          slug: "lpd-2004-2019-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
          sources: data_sources
        )
        puts "    Created layer: #{layer.slug}"
        order += 1

        # LPD Baseline 2001-2015
        layer = create_sdg_cog_layer(
          group: group,
          slug: "lpd-baseline-2001-2015-#{dataset[:key].to_s.tr("_", "-")}",
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
          methodology: dataset[:key].to_s.tr("_", "-"),
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
        slug: "lc-degradation-2015-2022",
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
        slug: "lc-degradation-2015-2019",
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
        slug: "lc-degradation-2000-2015",
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
        slug: "soc-degradation-2015-2022",
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
        slug: "soc-degradation-2015-2019",
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
        slug: "soc-degradation-2000-2015",
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
      "Exceeding" => "#4dac26",
      "Achieving" => "#006500",
      "Not achieving" => "#9b2779"
    }.freeze

    # 3-class land condition colours (baseline / period breakdowns).
    CONDITION_COLORS = {
      "Degraded" => "#e74c3c",
      "Stable" => "#f39c12",
      "Improved" => "#2ecc71"
    }.freeze

    # 9-cell transition matrix colours (baseline → period).
    TRANSITION_COLORS = {
      "Degraded → Degraded" => "#c0392b",
      "Degraded → Stable" => "#e67e22",
      "Degraded → Improved" => "#27ae60",
      "Stable → Degraded" => "#d35400",
      "Stable → Stable" => "#f1c40f",
      "Stable → Improved" => "#2ecc71",
      "Improved → Degraded" => "#e74c3c",
      "Improved → Stable" => "#f9e79f",
      "Improved → Improved" => "#1e8449"
    }.freeze

    # Methodology variants — S3 folder name → human label.
    SCOPE_DATASET_VARIANTS = {
      "te" => {filename_mode: "Trends.Earth", label: "Trends.Earth", methodology: "trendsearth"},
      "fao-wocat" => {filename_mode: "FAO-WOCAT", label: "FAO-WOCAT", methodology: "fao-wocat"},
      "jrc" => {filename_mode: "JRC", label: "JRC", methodology: "jrc"}
    }.freeze

    # ── Dataset definitions ──
    #
    # Each key becomes the group_key on the resulting ScopeDataset.
    # :sql        — query against temp stats tables (_eco_stats / _country_eco_stats)
    #               joined with key tables (_eco_key / _eco_country_key).
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
          {name: "ldn_pct", type: "number", label: "Net Change (%)", format: ".1f"},
          {name: "category", type: "category", label: "Category"},
          {name: "baseline_degraded_sqkm", type: "number", label: "Baseline Degraded (km²)", format: ",.1f"},
          {name: "baseline_stable_sqkm", type: "number", label: "Baseline Stable (km²)", format: ",.1f"},
          {name: "baseline_improved_sqkm", type: "number", label: "Baseline Improved (km²)", format: ",.1f"},
          {name: "period_degraded_sqkm", type: "number", label: "Period Degraded (km²)", format: ",.1f"},
          {name: "period_stable_sqkm", type: "number", label: "Period Stable (km²)", format: ",.1f"},
          {name: "period_improved_sqkm", type: "number", label: "Period Improved (km²)", format: ",.1f"},
          {name: "deg_to_deg_sqkm", type: "number", label: "Degraded → Degraded (km²)", format: ",.1f"},
          {name: "deg_to_stable_sqkm", type: "number", label: "Degraded → Stable (km²)", format: ",.1f"},
          {name: "deg_to_imp_sqkm", type: "number", label: "Degraded → Improved (km²)", format: ",.1f"},
          {name: "stable_to_deg_sqkm", type: "number", label: "Stable → Degraded (km²)", format: ",.1f"},
          {name: "stable_to_stable_sqkm", type: "number", label: "Stable → Stable (km²)", format: ",.1f"},
          {name: "stable_to_imp_sqkm", type: "number", label: "Stable → Improved (km²)", format: ",.1f"},
          {name: "imp_to_deg_sqkm", type: "number", label: "Improved → Degraded (km²)", format: ",.1f"},
          {name: "imp_to_stable_sqkm", type: "number", label: "Improved → Stable (km²)", format: ",.1f"},
          {name: "imp_to_imp_sqkm", type: "number", label: "Improved → Improved (km²)", format: ",.1f"}
        ],
        chart_config: [
          {
            id: "ecoregion-count-pie",
            type: "donut",
            title: "LDN Achievement (by ecoregion)",
            description: "Number of ecoregions achieving and not achieving LDN.",
            methodology_note: "Ecoregions are classified into three categories based on the net change percentage (gains − losses as % of total area): 'Exceeding' (> 5%), 'Achieving' (0–5%), or 'Not achieving' (< 0%). Net change is the difference between areas that improved in land condition and areas that degraded during the analysis period.",
            valueKey: "category",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "count",
            tooltipUnit: "ecoregions"
          },
          {
            id: "area-pie",
            type: "donut",
            title: "LDN Achievement (by land area)",
            description: "Total land area (km²) achieving and not achieving LDN.",
            methodology_note: "Each ecoregion's total land area is placed in the 'Exceeding', 'Achieving', or 'Not achieving' bucket based on its net change percentage (> 5%, 0–5%, or < 0% respectively). The chart shows the sum of area in each bucket, not the area that changed.",
            valueKey: "total_area_km2",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "sum",
            tooltipUnit: "km²"
          },
          {
            id: "ecoregion-table",
            type: "table",
            title: "All Ecoregions",
            columns: %w[ecoregion biome realm ldn_pct delta_ldn_km2 gains_km2 losses_km2 total_area_km2 baseline_degraded_sqkm period_degraded_sqkm]
          }
        ],
        sql: <<~SQL,
          SELECT s.eco_id, k.eco_name AS ecoregion, k.biome_name AS biome, k.realm,
            ROUND(s.gains_km2::numeric, 1) AS gains_km2,
            ROUND(s.losses_km2::numeric, 1) AS losses_km2,
            ROUND(s.delta_ldn_km2::numeric, 1) AS delta_ldn_km2,
            ROUND(s.total_area_km2::numeric, 1) AS total_area_km2,
            CASE WHEN s.total_area_km2 > 0
              THEN ROUND((s.gains_km2 / s.total_area_km2 * 100)::numeric, 1)
              ELSE 0 END AS gains_pct,
            CASE WHEN s.total_area_km2 > 0
              THEN ROUND((s.losses_km2 / s.total_area_km2 * 100)::numeric, 1)
              ELSE 0 END AS losses_pct,
            ROUND(s.ldn_pct::numeric, 1) AS ldn_pct,
            CASE WHEN s.ldn_pct > 5 THEN 'Exceeding' WHEN s.ldn_pct >= 0 THEN 'Achieving' ELSE 'Not achieving' END AS category,
            ROUND((COALESCE(s.deg_to_deg_sqkm,0) + COALESCE(s.deg_to_stable_sqkm,0) + COALESCE(s.deg_to_imp_sqkm,0))::numeric, 1) AS baseline_degraded_sqkm,
            ROUND((COALESCE(s.stable_to_deg_sqkm,0) + COALESCE(s.stable_to_stable_sqkm,0) + COALESCE(s.stable_to_imp_sqkm,0))::numeric, 1) AS baseline_stable_sqkm,
            ROUND((COALESCE(s.imp_to_deg_sqkm,0) + COALESCE(s.imp_to_stable_sqkm,0) + COALESCE(s.imp_to_imp_sqkm,0))::numeric, 1) AS baseline_improved_sqkm,
            ROUND((COALESCE(s.deg_to_deg_sqkm,0) + COALESCE(s.stable_to_deg_sqkm,0) + COALESCE(s.imp_to_deg_sqkm,0))::numeric, 1) AS period_degraded_sqkm,
            ROUND((COALESCE(s.deg_to_stable_sqkm,0) + COALESCE(s.stable_to_stable_sqkm,0) + COALESCE(s.imp_to_stable_sqkm,0))::numeric, 1) AS period_stable_sqkm,
            ROUND((COALESCE(s.deg_to_imp_sqkm,0) + COALESCE(s.stable_to_imp_sqkm,0) + COALESCE(s.imp_to_imp_sqkm,0))::numeric, 1) AS period_improved_sqkm,
            ROUND(COALESCE(s.deg_to_deg_sqkm, 0)::numeric, 1) AS deg_to_deg_sqkm,
            ROUND(COALESCE(s.deg_to_stable_sqkm, 0)::numeric, 1) AS deg_to_stable_sqkm,
            ROUND(COALESCE(s.deg_to_imp_sqkm, 0)::numeric, 1) AS deg_to_imp_sqkm,
            ROUND(COALESCE(s.stable_to_deg_sqkm, 0)::numeric, 1) AS stable_to_deg_sqkm,
            ROUND(COALESCE(s.stable_to_stable_sqkm, 0)::numeric, 1) AS stable_to_stable_sqkm,
            ROUND(COALESCE(s.stable_to_imp_sqkm, 0)::numeric, 1) AS stable_to_imp_sqkm,
            ROUND(COALESCE(s.imp_to_deg_sqkm, 0)::numeric, 1) AS imp_to_deg_sqkm,
            ROUND(COALESCE(s.imp_to_stable_sqkm, 0)::numeric, 1) AS imp_to_stable_sqkm,
            ROUND(COALESCE(s.imp_to_imp_sqkm, 0)::numeric, 1) AS imp_to_imp_sqkm
          FROM _eco_stats s
          JOIN _eco_key k ON s.eco_id = k.eco_id AND k.is_pa = 0
          ORDER BY s.eco_id
        SQL
        geometry_source: "ecoregion",
        geometry_unit_key: "eco_id"
      },

      # ── 2. Country × Ecoregion summary (country-first with ecoregion drill-down) ──
      "country-ecoregion-summary" => {
        name_template: "Country LDN Summary (%{variant})",
        description_template: "LDN counterbalancing results per country using %{variant} productivity methodology.",
        display_order: 2,
        dimension: "country",
        dimension_config: {unit_label: "Country", unit_id_column: "admin0_id", name_column: "country"},
        schema_config: [
          {name: "admin0_id", type: "integer", label: "Country ID"},
          {name: "country_code", type: "string", label: "Country ISO"},
          {name: "country", type: "string", label: "Country"},
          {name: "gains_km2", type: "number", label: "Gains (km²)", format: ",.1f"},
          {name: "losses_km2", type: "number", label: "Losses (km²)", format: ",.1f"},
          {name: "gains_pct", type: "number", label: "Gains (% of area)", format: ".1f"},
          {name: "losses_pct", type: "number", label: "Losses (% of area)", format: ".1f"},
          {name: "delta_ldn_km2", type: "number", label: "Net Change (km²)", format: ",.1f"},
          {name: "total_area_km2", type: "number", label: "Total Area (km²)", format: ",.1f"},
          {name: "ldn_pct", type: "number", label: "Net Change (%)", format: ".1f"},
          {name: "category", type: "category", label: "Category"},
          {name: "agg_category", type: "category", label: "Aggregate Category"},
          {name: "baseline_degraded_sqkm", type: "number", label: "Baseline Degraded (km²)", format: ",.1f"},
          {name: "baseline_stable_sqkm", type: "number", label: "Baseline Stable (km²)", format: ",.1f"},
          {name: "baseline_improved_sqkm", type: "number", label: "Baseline Improved (km²)", format: ",.1f"},
          {name: "period_degraded_sqkm", type: "number", label: "Period Degraded (km²)", format: ",.1f"},
          {name: "period_stable_sqkm", type: "number", label: "Period Stable (km²)", format: ",.1f"},
          {name: "period_improved_sqkm", type: "number", label: "Period Improved (km²)", format: ",.1f"},
          {name: "deg_to_deg_sqkm", type: "number", label: "Degraded → Degraded (km²)", format: ",.1f"},
          {name: "deg_to_stable_sqkm", type: "number", label: "Degraded → Stable (km²)", format: ",.1f"},
          {name: "deg_to_imp_sqkm", type: "number", label: "Degraded → Improved (km²)", format: ",.1f"},
          {name: "stable_to_deg_sqkm", type: "number", label: "Stable → Degraded (km²)", format: ",.1f"},
          {name: "stable_to_stable_sqkm", type: "number", label: "Stable → Stable (km²)", format: ",.1f"},
          {name: "stable_to_imp_sqkm", type: "number", label: "Stable → Improved (km²)", format: ",.1f"},
          {name: "imp_to_deg_sqkm", type: "number", label: "Improved → Degraded (km²)", format: ",.1f"},
          {name: "imp_to_stable_sqkm", type: "number", label: "Improved → Stable (km²)", format: ",.1f"},
          {name: "imp_to_imp_sqkm", type: "number", label: "Improved → Improved (km²)", format: ",.1f"}
        ],
        chart_config: [
          {
            id: "country-count-pie",
            type: "donut",
            title: "LDN Achievement (by country)",
            description: "Number of countries achieving and not achieving LDN.",
            methodology_note: "A country is classified as 'Achieving' only if every ecoregion within its borders has a net positive change (gains − losses ≥ 0 km²). This is a strict criterion: even a single net-negative ecoregion marks the entire country as 'Not achieving'.",
            valueKey: "category",
            categoryKey: "category",
            colors: CATEGORY_COLORS,
            aggregation: "count",
            tooltipUnit: "countries"
          },
          {
            id: "country-agg-count-pie",
            type: "donut",
            title: "Net Change (by country, aggregate)",
            description: "Number of countries with positive vs. negative aggregate net change (gains − losses).",
            methodology_note: "Countries are classified into three categories based on aggregate net change percentage: 'Exceeding' (> 5%), 'Achieving' (0–5%), or 'Not achieving' (< 0%). Gains in one ecoregion can offset losses in another. This chart reflects the aggregate balance.",
            valueKey: "agg_category",
            categoryKey: "agg_category",
            colors: CATEGORY_COLORS,
            aggregation: "count",
            tooltipUnit: "countries"
          },
          {
            id: "area-pie",
            type: "donut",
            title: "LDN Achievement (by land area)",
            description: "Total land area (km²) achieving and not achieving LDN.",
            methodology_note: "Each country's total land area is placed in the 'Exceeding', 'Achieving', or 'Not achieving' bucket based on that country's aggregate net change percentage (> 5%, 0–5%, or < 0%). This is the same criterion used in the 'Net Change (by country, aggregate)' chart above. The chart shows the sum of land area in each bucket.",
            valueKey: "total_area_km2",
            categoryKey: "agg_category",
            colors: CATEGORY_COLORS,
            aggregation: "sum",
            tooltipUnit: "km²"
          },
          {
            id: "country-table",
            type: "table",
            title: "All Countries",
            columns: %w[country ldn_pct delta_ldn_km2 gains_km2 losses_km2 total_area_km2 baseline_degraded_sqkm period_degraded_sqkm]
          }
        ],
        sql: <<~SQL
          SELECT k.country_id AS admin0_id, k.country_code, k.country_name AS country,
            ROUND(SUM(s.gains_km2)::numeric, 1) AS gains_km2,
            ROUND(SUM(s.losses_km2)::numeric, 1) AS losses_km2,
            CASE WHEN SUM(s.total_area_km2) > 0
              THEN ROUND((SUM(s.gains_km2) / SUM(s.total_area_km2) * 100)::numeric, 1)
              ELSE 0 END AS gains_pct,
            CASE WHEN SUM(s.total_area_km2) > 0
              THEN ROUND((SUM(s.losses_km2) / SUM(s.total_area_km2) * 100)::numeric, 1)
              ELSE 0 END AS losses_pct,
            ROUND(SUM(s.delta_ldn_km2)::numeric, 1) AS delta_ldn_km2,
            ROUND(SUM(s.total_area_km2)::numeric, 1) AS total_area_km2,
            CASE WHEN SUM(s.total_area_km2) > 0
              THEN ROUND((SUM(s.delta_ldn_km2) / SUM(s.total_area_km2) * 100)::numeric, 1)
              ELSE 0 END AS ldn_pct,
            CASE WHEN MIN(s.delta_ldn_km2) >= 0 THEN 'Achieving'
                 ELSE 'Not achieving' END AS category,
            CASE WHEN SUM(s.total_area_km2) > 0 AND (SUM(s.delta_ldn_km2) / SUM(s.total_area_km2) * 100) > 5 THEN 'Exceeding'
                 WHEN SUM(s.delta_ldn_km2) >= 0 THEN 'Achieving'
                 ELSE 'Not achieving' END AS agg_category,
            ROUND(SUM(COALESCE(s.deg_to_deg_sqkm,0) + COALESCE(s.deg_to_stable_sqkm,0) + COALESCE(s.deg_to_imp_sqkm,0))::numeric, 1) AS baseline_degraded_sqkm,
            ROUND(SUM(COALESCE(s.stable_to_deg_sqkm,0) + COALESCE(s.stable_to_stable_sqkm,0) + COALESCE(s.stable_to_imp_sqkm,0))::numeric, 1) AS baseline_stable_sqkm,
            ROUND(SUM(COALESCE(s.imp_to_deg_sqkm,0) + COALESCE(s.imp_to_stable_sqkm,0) + COALESCE(s.imp_to_imp_sqkm,0))::numeric, 1) AS baseline_improved_sqkm,
            ROUND(SUM(COALESCE(s.deg_to_deg_sqkm,0) + COALESCE(s.stable_to_deg_sqkm,0) + COALESCE(s.imp_to_deg_sqkm,0))::numeric, 1) AS period_degraded_sqkm,
            ROUND(SUM(COALESCE(s.deg_to_stable_sqkm,0) + COALESCE(s.stable_to_stable_sqkm,0) + COALESCE(s.imp_to_stable_sqkm,0))::numeric, 1) AS period_stable_sqkm,
            ROUND(SUM(COALESCE(s.deg_to_imp_sqkm,0) + COALESCE(s.stable_to_imp_sqkm,0) + COALESCE(s.imp_to_imp_sqkm,0))::numeric, 1) AS period_improved_sqkm,
            ROUND(SUM(COALESCE(s.deg_to_deg_sqkm, 0))::numeric, 1) AS deg_to_deg_sqkm,
            ROUND(SUM(COALESCE(s.deg_to_stable_sqkm, 0))::numeric, 1) AS deg_to_stable_sqkm,
            ROUND(SUM(COALESCE(s.deg_to_imp_sqkm, 0))::numeric, 1) AS deg_to_imp_sqkm,
            ROUND(SUM(COALESCE(s.stable_to_deg_sqkm, 0))::numeric, 1) AS stable_to_deg_sqkm,
            ROUND(SUM(COALESCE(s.stable_to_stable_sqkm, 0))::numeric, 1) AS stable_to_stable_sqkm,
            ROUND(SUM(COALESCE(s.stable_to_imp_sqkm, 0))::numeric, 1) AS stable_to_imp_sqkm,
            ROUND(SUM(COALESCE(s.imp_to_deg_sqkm, 0))::numeric, 1) AS imp_to_deg_sqkm,
            ROUND(SUM(COALESCE(s.imp_to_stable_sqkm, 0))::numeric, 1) AS imp_to_stable_sqkm,
            ROUND(SUM(COALESCE(s.imp_to_imp_sqkm, 0))::numeric, 1) AS imp_to_imp_sqkm
          FROM _country_eco_stats s
          JOIN _eco_country_key k ON s.admin0_id = k.country_id AND s.eco_id = k.eco_id AND k.is_pa = 0
          GROUP BY k.country_id, k.country_code, k.country_name
          ORDER BY k.country_id
        SQL
      },

      # ── 3. Ecoregion breakdown by country ──
      "country-ecoregion-detail" => {
        name_template: "Ecoregion Breakdown by Country (%{variant})",
        description_template: "LDN counterbalancing results per ecoregion within each country using %{variant} productivity methodology. Each ecoregion is assessed only within the portion of its land area that falls inside the given country.",
        display_order: 3,
        dimension: "country",
        dimension_config: {unit_label: "Country", unit_id_column: "admin0_id", name_column: "country"},
        schema_config: [
          {name: "admin0_id", type: "integer", label: "Country ID"},
          {name: "eco_id", type: "integer", label: "Ecoregion ID"},
          {name: "country", type: "string", label: "Country"},
          {name: "ecoregion", type: "string", label: "Ecoregion"},
          {name: "ldn_pct", type: "number", label: "Net Change (%)", format: ".1f"},
          {name: "delta_ldn_km2", type: "number", label: "Net Change (km²)", format: ",.1f"},
          {name: "gains_km2", type: "number", label: "Gains (km²)", format: ",.1f"},
          {name: "losses_km2", type: "number", label: "Losses (km²)", format: ",.1f"},
          {name: "total_area_km2", type: "number", label: "Total Area (km²)", format: ",.1f"},
          {name: "baseline_degraded_sqkm", type: "number", label: "Degraded at Baseline (km²)", format: ",.1f"},
          {name: "period_degraded_sqkm", type: "number", label: "Degraded in 2023 (km²)", format: ",.1f"}
        ],
        chart_config: [
          {
            id: "country-ecoregion-table",
            type: "table",
            title: "All Ecoregions (by Country)",
            columns: %w[country ecoregion ldn_pct delta_ldn_km2 gains_km2 losses_km2 total_area_km2 baseline_degraded_sqkm period_degraded_sqkm]
          }
        ],
        sql: <<~SQL
          SELECT k.country_id AS admin0_id, s.eco_id, k.country_name AS country, k.eco_name AS ecoregion,
            ROUND(s.ldn_pct::numeric, 1) AS ldn_pct,
            ROUND(s.delta_ldn_km2::numeric, 1) AS delta_ldn_km2,
            ROUND(s.gains_km2::numeric, 1) AS gains_km2,
            ROUND(s.losses_km2::numeric, 1) AS losses_km2,
            ROUND(s.total_area_km2::numeric, 1) AS total_area_km2,
            ROUND((COALESCE(s.deg_to_deg_sqkm,0) + COALESCE(s.deg_to_stable_sqkm,0) + COALESCE(s.deg_to_imp_sqkm,0))::numeric, 1) AS baseline_degraded_sqkm,
            ROUND((COALESCE(s.deg_to_deg_sqkm,0) + COALESCE(s.stable_to_deg_sqkm,0) + COALESCE(s.imp_to_deg_sqkm,0))::numeric, 1) AS period_degraded_sqkm
          FROM _country_eco_stats s
          JOIN _eco_country_key k ON s.admin0_id = k.country_id AND s.eco_id = k.eco_id AND k.is_pa = 0
          ORDER BY k.country_name, k.eco_name
        SQL
      }

    }.freeze

    def create_scope_datasets(site_scope)
      puts "Creating scope datasets from statistics CSVs..."

      data_dir = ENV.fetch("LDN_DATA_DIR", DATA_DIR_DEFAULT)

      eco_key_csv = File.join(data_dir, "pa_ecoregion_key.csv")
      country_key_csv = File.join(data_dir, "pa_ecoregion_country_key.csv")

      unless File.exist?(eco_key_csv) && File.exist?(country_key_csv)
        missing = [eco_key_csv, country_key_csv].reject { |f| File.exist?(f) }
        puts "  SKIP scope datasets: key CSV(s) not found: #{missing.map { |f| File.basename(f) }.join(", ")}"
        puts "  (Run scripts/setup_ldn_data.sh to generate these files for full LDN analysis functionality)"
        return
      end

      # Import key CSVs once (shared across all variants)
      import_key_csvs(data_dir)

      # ── Per-variant statistical datasets ──
      SCOPE_DATASET_VARIANTS.each do |variant_slug, variant_info|
        eco_stats_csv = File.join(data_dir, "TrendsEarth_LDN_2000-2023_#{variant_info[:filename_mode]}_ecoregion_summary.csv")
        country_eco_stats_csv = File.join(data_dir, "TrendsEarth_LDN_2000-2023_#{variant_info[:filename_mode]}_country_ecoregion_summary.csv")

        unless File.exist?(eco_stats_csv)
          puts "  SKIP #{variant_slug}: ecoregion stats CSV not found at #{eco_stats_csv}"
          next
        end

        import_stats_csvs(eco_stats_csv, country_eco_stats_csv)
        persist_ecoregion_stats(variant_info[:methodology])

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

          copy_dissolved_geometries(dataset, defn[:geometry_source], defn[:geometry_unit_key])
        end

        cleanup_stats_tables
      end

      cleanup_key_tables
    end

    # ── Helper: create a layer from an S3 LDN COG ──

    def create_ldn_cog_layer(group:, slug:, s3_folder:, filename:, colormap:, legend:, name:, info:, description:, active:, order:, color:, analysis_type: "categorical", sources: [], methodology: nil)
      cog_url = "s3://#{LDN_S3_BUCKET}/#{LDN_S3_PREFIX}/#{s3_folder}/#{filename}"

      body = {
        source: cog_url,
        nodata: -32768,
        options: {}
      }

      if colormap.is_a?(String)
        body[:colormap_name] = colormap
      else
        body[:colormap] = colormap
      end

      layer_config = {
        type: "tileLayer",
        body: body
      }

      save_layer(
        group: group, slug: slug, layer_config: layer_config, legend: legend,
        name: name, info: info, description: description, active: active,
        order: order, color: color, analysis_type: analysis_type, sources: sources,
        interaction_config: build_ldn_interaction_config(methodology: methodology)
      )
    end

    # ── Helper: create a layer from a GCS SDG COG (multi-band) ──

    def create_sdg_cog_layer(group:, slug:, cog_key:, band:, colormap:, legend:, name:, info:, description:, active:, order:, color:, analysis_type: "categorical", sources: [], methodology: nil)
      cog_url = "#{SDG_COG_BASE}/#{SDG_COGS[cog_key]}"

      body = {
        source: cog_url,
        bidx: band,
        nodata: -32768,
        options: {}
      }

      if colormap.is_a?(String)
        body[:colormap_name] = colormap
      else
        body[:colormap] = colormap
      end

      layer_config = {
        type: "tileLayer",
        body: body
      }

      save_layer(
        group: group, slug: slug, layer_config: layer_config, legend: legend,
        name: name, info: info, description: description, active: active,
        order: order, color: color, analysis_type: analysis_type, sources: sources,
        interaction_config: build_ldn_interaction_config(methodology: methodology)
      )
    end

    # ── Helper: build interaction_config for ecoregion popup ──
    #
    # Generates a local API interaction config that shows ecoregion metadata
    # (eco_id, eco_name, biome, realm) on popup click. When `methodology` is
    # non-nil the lookup also returns joined `ldn_ecoregion_stats` values for
    # that methodology when the table is available.
    #
    # The `responseFormat: "rows"` flag tells LayerPopup.jsx to parse the API
    # response as `{ rows: [...] }` even though the layer provider is 'cog'.
    # Column names match TrendsEarth_LDN_2000-2023_*_ecoregion_summary.csv output.
    # Baseline degraded area is computed as deg_to_deg + deg_to_stable + deg_to_imp
    # (all land classified degraded during the 2000-2015 baseline, regardless of
    # subsequent trajectory). status_3_baseline_degradation_sqkm alone is
    # insufficient because deg_to_imp transitions appear in status_6, not status_3.
    def build_ldn_interaction_config(methodology: nil)
      if methodology
        output = [
          {column: "eco_id", property: "Ecoregion ID", type: "integer"},
          {column: "eco_name", property: "Ecoregion", type: "string"},
          {column: "biome_name", property: "Biome", type: "string"},
          {column: "realm", property: "Realm", type: "string"},
          {column: "total_area_km2", property: "Total area (km²)", type: "number", format: "0,0"},
          {column: "baseline_degraded_sqkm", property: "Baseline degraded (km²)", type: "number", format: "0,0"},
          {column: "gains_km2", property: "Gains (km²)", type: "number", format: "0,0"},
          {column: "losses_km2", property: "Losses (km²)", type: "number", format: "0,0"},
          {column: "delta_ldn_km2", property: "Net change (km²)", type: "number", format: "0,0"},
          {column: "ldn_pct", property: "Net change (%)", type: "number", format: "0.0"}
        ]
        config = {
          url: "#{LDN_ECOREGION_LOOKUP_PATH}?lat={{lat}}&lng={{lng}}&methodology={{methodology}}",
          responseFormat: "rows",
          params: {methodology: methodology}
        }
      else
        output = [
          {column: "eco_id", property: "Ecoregion ID", type: "integer"},
          {column: "eco_name", property: "Ecoregion", type: "string"},
          {column: "biome_name", property: "Biome", type: "string"},
          {column: "realm", property: "Realm", type: "string"}
        ]
        config = {
          url: "#{LDN_ECOREGION_LOOKUP_PATH}?lat={{lat}}&lng={{lng}}",
          responseFormat: "rows"
        }
      end
      {output: output, config: config}.to_json
    end

    # ── Helper: persist a Layer + Agrupation ──

    def save_layer(group:, slug:, layer_config:, legend:, name:, info:, description:, active:, order:, color:, analysis_type:, sources:, interaction_config: nil)
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
        :interaction_config => interaction_config || "{}",
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

      # Only clean up stale agrupations within the SAME site scope.
      # This preserves agrupations from other site scopes so a layer can
      # be shared across trendsearth and LDN without interference.
      scope_group_ids = LayerGroup.where(site_scope_id: group.site_scope_id).pluck(:id)
      Agrupation.where(layer_id: layer.id, layer_group_id: scope_group_ids)
        .where.not(layer_group_id: group.id).destroy_all

      agrupation = Agrupation.find_or_initialize_by(layer_id: layer.id, layer_group_id: group.id)
      agrupation.active = active
      agrupation.save!

      layer
    end

    # ── Helper: import key CSVs (shared across all variants) ──

    def import_key_csvs(data_dir)
      conn = ActiveRecord::Base.connection

      eco_key_csv = File.join(data_dir, "pa_ecoregion_key.csv")
      country_key_csv = File.join(data_dir, "pa_ecoregion_country_key.csv")

      # Sanitize key CSVs: strip ".0" float suffixes from integer columns
      # (pandas may write int columns as floats when NaN is present)
      [eco_key_csv, country_key_csv].each do |csv_path|
        system("sed", "-i", 's/\.0,/,/g; s/\.0$//', csv_path)
      end

      # Ecoregion key
      conn.execute(<<~SQL)
        CREATE TEMP TABLE IF NOT EXISTS _eco_key (
          unit_id    int,
          is_pa      int,
          eco_id     int,
          eco_name   text,
          biome_num  int,
          biome_name text,
          realm      text
        ) ON COMMIT PRESERVE ROWS
      SQL
      conn.execute("TRUNCATE _eco_key")
      copy_csv_to_table(conn, "_eco_key", eco_key_csv)
      puts "  Imported _eco_key: #{conn.select_value("SELECT count(*) FROM _eco_key")} rows"

      # Country-ecoregion key
      conn.execute(<<~SQL)
        CREATE TEMP TABLE IF NOT EXISTS _eco_country_key (
          unit_id      int,
          is_pa        int,
          eco_id       int,
          eco_name     text,
          biome_num    int,
          biome_name   text,
          realm        text,
          country_id   int,
          country_code text,
          country_name text
        ) ON COMMIT PRESERVE ROWS
      SQL
      conn.execute("TRUNCATE _eco_country_key")
      copy_csv_to_table(conn, "_eco_country_key", country_key_csv)
      puts "  Imported _eco_country_key: #{conn.select_value("SELECT count(*) FROM _eco_country_key")} rows"
    end

    # ── Helper: import per-mode statistics CSVs into temp tables ──

    def import_stats_csvs(eco_stats_csv, country_eco_stats_csv)
      conn = ActiveRecord::Base.connection

      # Ecoregion stats (comma-delimited)
      conn.execute(<<~SQL)
        CREATE TEMP TABLE IF NOT EXISTS _eco_stats (
          eco_id                                int,
          gains_km2                             double precision,
          losses_km2                            double precision,
          total_area_km2                        double precision,
          status_1_persistent_degradation_sqkm  double precision,
          status_2_recent_degradation_sqkm      double precision,
          status_3_baseline_degradation_sqkm    double precision,
          status_4_stability_sqkm               double precision,
          status_5_baseline_improvement_sqkm    double precision,
          status_6_recent_improvement_sqkm      double precision,
          status_7_persistent_improvement_sqkm  double precision,
          deg_to_deg_sqkm                       double precision,
          deg_to_stable_sqkm                    double precision,
          deg_to_imp_sqkm                       double precision,
          stable_to_deg_sqkm                    double precision,
          stable_to_stable_sqkm                 double precision,
          stable_to_imp_sqkm                    double precision,
          imp_to_deg_sqkm                       double precision,
          imp_to_stable_sqkm                    double precision,
          imp_to_imp_sqkm                       double precision,
          delta_ldn_km2                         double precision,
          ldn_pct                               double precision
        ) ON COMMIT PRESERVE ROWS
      SQL
      conn.execute("TRUNCATE _eco_stats")
      copy_csv_to_table(conn, "_eco_stats", eco_stats_csv)
      puts "  Imported _eco_stats: #{conn.select_value("SELECT count(*) FROM _eco_stats")} rows"

      # Country-ecoregion stats (comma-delimited)
      if File.exist?(country_eco_stats_csv)
        conn.execute(<<~SQL)
          CREATE TEMP TABLE IF NOT EXISTS _country_eco_stats (
            admin0_id                             int,
            eco_id                                int,
            gains_km2                             double precision,
            losses_km2                            double precision,
            total_area_km2                        double precision,
            status_1_persistent_degradation_sqkm  double precision,
            status_2_recent_degradation_sqkm      double precision,
            status_3_baseline_degradation_sqkm    double precision,
            status_4_stability_sqkm               double precision,
            status_5_baseline_improvement_sqkm    double precision,
            status_6_recent_improvement_sqkm      double precision,
            status_7_persistent_improvement_sqkm  double precision,
            deg_to_deg_sqkm                       double precision,
            deg_to_stable_sqkm                    double precision,
            deg_to_imp_sqkm                       double precision,
            stable_to_deg_sqkm                    double precision,
            stable_to_stable_sqkm                 double precision,
            stable_to_imp_sqkm                    double precision,
            imp_to_deg_sqkm                       double precision,
            imp_to_stable_sqkm                    double precision,
            imp_to_imp_sqkm                       double precision,
            delta_ldn_km2                         double precision,
            ldn_pct                               double precision
          ) ON COMMIT PRESERVE ROWS
        SQL
        conn.execute("TRUNCATE _country_eco_stats")
        copy_csv_to_table(conn, "_country_eco_stats", country_eco_stats_csv)
        puts "  Imported _country_eco_stats: #{conn.select_value("SELECT count(*) FROM _country_eco_stats")} rows"
      end
    end

    def persist_ecoregion_stats(methodology)
      conn = ActiveRecord::Base.connection
      unless conn.select_value("SELECT to_regclass('ra_nonspatial.ldn_ecoregion_stats') IS NOT NULL")
        puts "  WARNING: ra_nonspatial.ldn_ecoregion_stats not found — run pending migrations first"
        return
      end

      conn.execute(
        ActiveRecord::Base.sanitize_sql_array(
          ["DELETE FROM ra_nonspatial.ldn_ecoregion_stats WHERE methodology = ?", methodology]
        )
      )
      conn.execute(<<~SQL)
        INSERT INTO ra_nonspatial.ldn_ecoregion_stats (
          methodology, eco_id, gains_km2, losses_km2, total_area_km2,
          deg_to_deg_sqkm, deg_to_stable_sqkm, deg_to_imp_sqkm,
          delta_ldn_km2, ldn_pct
        )
        SELECT
          #{conn.quote(methodology)}, eco_id, gains_km2, losses_km2, total_area_km2,
          deg_to_deg_sqkm, deg_to_stable_sqkm, deg_to_imp_sqkm,
          delta_ldn_km2, ldn_pct
        FROM _eco_stats
      SQL
      puts "  Refreshed ra_nonspatial.ldn_ecoregion_stats for #{methodology}"
    end

    # ── Helper: stream a local CSV into a table via COPY FROM STDIN ──

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

    # ── Helper: copy geometries from ldn_dissolved_geometries ──
    # Projects unit_id from the properties JSON so higher-level views
    # (biome, realm, country) reuse ecoregion-level polygons with a
    # shared unit_id — no ST_Union needed.

    def copy_dissolved_geometries(dataset, source, unit_key)
      return unless source

      conn = ActiveRecord::Base.connection
      exists = conn.select_value(
        "SELECT to_regclass('ra_vector.ldn_dissolved_geometries') IS NOT NULL"
      )
      unless exists
        puts "    SKIP geometries for #{dataset.slug}: run `rake ldn:build_dimensions` first"
        return
      end

      puts "    Copying geometries (#{source} → #{unit_key}) for #{dataset.slug}..."
      dataset.scope_dataset_geometries.delete_all

      conn.execute(<<~SQL)
        INSERT INTO scope_dataset_geometries
          (scope_dataset_id, unit_id, properties, geom, created_at, updated_at)
        SELECT
          #{dataset.id},
          properties ->> '#{conn.quote_string(unit_key)}',
          properties,
          geom,
          NOW(), NOW()
        FROM ldn_dissolved_geometries
        WHERE dimension = '#{conn.quote_string(source)}'
      SQL

      count = dataset.scope_dataset_geometries.count
      puts "    Copied #{count} geometries"
    end

    # ── Helper: drop per-variant stats temp tables ──

    def cleanup_stats_tables
      conn = ActiveRecord::Base.connection
      %w[_eco_stats _country_eco_stats].each do |t|
        conn.execute("DROP TABLE IF EXISTS #{t}")
      end
    end

    # ── Helper: drop shared key tables (after all variants are done) ──

    def cleanup_key_tables
      conn = ActiveRecord::Base.connection
      %w[_eco_key _eco_country_key].each do |t|
        conn.execute("DROP TABLE IF EXISTS #{t}")
      end
    end
  end
end

# Run the seeder
LdnSeeder.run
