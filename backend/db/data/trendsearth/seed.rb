# Trends.Earth Seed Script
# Run this from the backend directory:
#   bundle exec rails runner db/data/trendsearth/seed.rb
#
# Or within rails console:
#   load 'db/data/trendsearth/seed.rb'

module TrendsEarthSeeder
  TITILER_BASE = ENV.fetch("TITILER_URL", "https://staging.titiler.resilienceatlas.org")
  COG_BASE = "https://storage.googleapis.com/trendsearth-public/unccd_reporting/2016-2023"

  # Source references (will create Source records)
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

  # Dataset descriptions for info pages
  DATASET_INFO = {
    trendsearth: {
      name: "Trends.Earth",
      short_name: "TE",
      description: "This layer uses the Trends.Earth Land Productivity Dynamics (LPD) methodology, which calculates productivity trends using MODIS NDVI data with a linear regression approach."
    },
    fao_wocat: {
      name: "FAO-WOCAT",
      short_name: "FAO",
      description: "This layer uses the FAO-WOCAT Land Productivity Dynamics (LPD) methodology, which applies a 5-class system based on long-term productivity state and trend analysis."
    },
    jrc: {
      name: "JRC",
      short_name: "JRC",
      description: "This layer uses the Joint Research Centre (JRC) Land Productivity Dynamics (LPD) methodology, which employs phenological metrics derived from SPOT-VGT and PROBA-V satellite data."
    }
  }.freeze

  # COG file names
  COGS = {
    trendsearth: "TrendsEarth_SDG15.3.1_2000-2023_Trends.Earth.tif",
    fao_wocat: "TrendsEarth_SDG15.3.1_2000-2023_FAO-WOCAT.tif",
    jrc: "TrendsEarth_SDG15.3.1_2000-2023_JRC.tif"
  }.freeze

  # Band mapping (1-indexed)
  BANDS = {
    sdg_baseline: 1,       # SDG 15.3.1 baseline 2000-2015
    lpd_baseline: 2,       # LPD 2001-2015
    lc_baseline: 3,        # Land cover 2000-2015
    soc_baseline: 4,       # SOC 2000-2015
    sdg_2019: 5,           # SDG 15.3.1 2004-2019
    lpd_2019: 6,           # LPD 2005-2019
    lc_2019: 7,            # Land cover 2004-2019
    soc_2019: 8,           # SOC 2004-2019
    sdg_status_2019: 9,    # SDG status 2019 vs baseline
    sdg_2023: 10,          # SDG 15.3.1 2008-2023
    lpd_2023: 11,          # LPD 2009-2023
    lc_2023: 12,           # Land cover 2008-2023
    soc_2023: 13,          # SOC 2008-2023
    sdg_status_2023: 14    # SDG status 2023 vs baseline
  }.freeze

  # Colormaps for TiTiler (JSON format)
  # Stable color (#f7f7f7 = [247, 247, 247]) is consistent across all layer types
  COLORMAPS = {
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
    # SOC values are percentages: <-10 = degraded, -10 to 10 = stable, >10 = improvement
    soc: {
      "-32768" => [0, 0, 0, 0],      # NoData (transparent)
      "-100" => [155, 39, 121, 255], # Severe degradation
      "-10" => [155, 39, 121, 255],  # Degradation threshold
      "-9" => [247, 247, 247, 255],  # Stable (start)
      "0" => [247, 247, 247, 255],   # Stable (center)
      "9" => [247, 247, 247, 255],   # Stable (end)
      "10" => [0, 101, 0, 255],      # Improvement threshold
      "100" => [0, 101, 0, 255]      # Strong improvement
    }
  }.freeze

  # Legend configurations (JSON format for database)
  # Frontend uses "custom" type with "data" array containing {name, value} objects
  # Stable color (#f7f7f7) is consistent across all layer types to match status layers
  LEGENDS = {
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

  class << self
    def run
      puts "Starting Trends.Earth seed..."

      # Fix PostgreSQL sequences if they're out of sync with existing data
      reset_sequences

      sources = create_sources
      site_scope = create_site_scope
      groups = create_layer_groups(site_scope)
      create_layers(groups, sources)

      puts "Trends.Earth seed completed successfully!"
    end

    def reset_sequences
      puts "Resetting PostgreSQL sequences..."
      %w[site_scopes layer_groups layers agrupations sources].each do |table|
        ActiveRecord::Base.connection.execute(
          "SELECT setval(pg_get_serial_sequence('#{table}', 'id'), COALESCE(MAX(id), 1)) FROM #{table}"
        )
      end
    end

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

    def create_site_scope
      puts "Creating site scope..."

      site_scope = SiteScope.find_or_initialize_by(subdomain: "trendsearth")
      site_scope.assign_attributes(
        name: "Trends.Earth",  # Globalize translates this
        linkback_text: "Powered by Trends.Earth",  # Globalize translates this
        color: "#C62828",  # Highlight color from Trends.Earth logo (red)
        has_analysis: true,
        has_gef_logo: true,
        latitude: 0,
        longitude: 0,
        zoom_level: 2,
        header_theme: "dark",  # Dark theme for medium gray background
        header_color: "#5D5D5D",  # Medium gray background
        logo_url: "https://storage.googleapis.com/trendsearth-public/logo/trends_earth_logo_print_colored.png",
        linkback_url: "https://trends.earth"
      )
      site_scope.save!

      puts "  Created site scope: #{site_scope.subdomain}"
      site_scope
    end

    def create_layer_groups(site_scope)
      puts "Creating layer groups..."

      groups = {}

      # Four top-level categories (no root group needed)
      categories = {
        "sdg-indicator-15-3-1" => {
          name: "SDG Indicator 15.3.1",
          info: "SDG Indicator 15.3.1 measures the proportion of land that is degraded over total land area.",
          order: 1
        },
        "land-productivity" => {
          name: "Land Productivity",
          info: "Land Productivity Dynamics (LPD) measures changes in vegetation productivity over time.",
          order: 2
        },
        "land-cover" => {
          name: "Land Cover",
          info: "Land cover change degradation layers showing transitions between land cover classes.",
          order: 3
        },
        "soil-organic-carbon" => {
          name: "Soil Organic Carbon",
          info: "Soil organic carbon (SOC) change layers showing percentage change in soil carbon stocks.",
          order: 4
        }
      }

      categories.each do |slug, config|
        group = LayerGroup.find_or_initialize_by(
          slug: slug,
          site_scope_id: site_scope.id
        )
        group.assign_attributes(
          super_group_id: nil,
          active: true,
          "order" => config[:order],
          name: config[:name],
          info: config[:info]
        )
        group.save!
        groups[slug] = group
        puts "  Created category: #{slug}"
      end

      # SDG Indicator subcategories (by dataset/methodology)
      sdg_subcategories = {
        "sdg-trendsearth" => {name: "Trends.Earth", info: "SDG 15.3.1 calculated using Trends.Earth productivity methodology", order: 1},
        "sdg-fao-wocat" => {name: "FAO-WOCAT", info: "SDG 15.3.1 calculated using FAO-WOCAT productivity methodology", order: 2},
        "sdg-jrc" => {name: "JRC", info: "SDG 15.3.1 calculated using JRC productivity methodology", order: 3}
      }

      sdg_subcategories.each do |slug, config|
        subgroup = LayerGroup.find_or_initialize_by(
          slug: slug,
          site_scope_id: site_scope.id
        )
        subgroup.assign_attributes(
          super_group_id: groups["sdg-indicator-15-3-1"].id,
          layer_group_type: "subcategory",
          active: true,
          "order" => config[:order],
          name: config[:name],
          info: config[:info]
        )
        subgroup.save!
        groups[slug] = subgroup
        puts "    Created subgroup: #{slug}"
      end

      # Land Productivity subcategories (by dataset/methodology)
      lpd_subcategories = {
        "lpd-trendsearth" => {name: "Trends.Earth", info: "Land Productivity Dynamics using Trends.Earth methodology", order: 1},
        "lpd-fao-wocat" => {name: "FAO-WOCAT", info: "Land Productivity Dynamics using FAO-WOCAT methodology", order: 2},
        "lpd-jrc" => {name: "JRC", info: "Land Productivity Dynamics using JRC methodology", order: 3}
      }

      lpd_subcategories.each do |slug, config|
        subgroup = LayerGroup.find_or_initialize_by(
          slug: slug,
          site_scope_id: site_scope.id
        )
        subgroup.assign_attributes(
          super_group_id: groups["land-productivity"].id,
          layer_group_type: "subcategory",
          active: true,
          "order" => config[:order],
          name: config[:name],
          info: config[:info]
        )
        subgroup.save!
        groups[slug] = subgroup
        puts "    Created subgroup: #{slug}"
      end

      # Clean up old groups that are no longer needed
      old_slugs = %w[sdg-15-3-1-datasets sdg-status-2023 sdg-status-2019 sdg-baseline-2000-2015 lpd-2008-2023 lpd-2005-2019 lpd-baseline-2001-2015]
      old_slugs.each do |slug|
        old_group = LayerGroup.find_by(slug: slug, site_scope_id: site_scope.id)
        if old_group
          old_group.destroy
          puts "    Removed old group: #{slug}"
        end
      end

      groups
    end

    def create_layers(groups, sources)
      puts "Creating layers..."

      # SDG Indicator 15.3.1 layers (uses subgroups)
      create_sdg_layers(groups, sources)

      # Land Productivity layers (uses subgroups)
      create_lpd_layers(groups, sources)

      # Land Cover layers
      create_land_cover_layers(groups["land-cover"], sources)

      # Soil Organic Carbon layers
      create_soc_layers(groups["soil-organic-carbon"], sources)
    end

    def create_sdg_layers(groups, sources)
      # Datasets map to subgroups
      datasets = [
        {key: :trendsearth, group_slug: "sdg-trendsearth"},
        {key: :fao_wocat, group_slug: "sdg-fao-wocat"},
        {key: :jrc, group_slug: "sdg-jrc"}
      ]

      datasets.each do |dataset|
        group = groups[dataset[:group_slug]]
        dataset_name = DATASET_INFO[dataset[:key]][:name]
        dataset_short = DATASET_INFO[dataset[:key]][:short_name]
        dataset_desc = DATASET_INFO[dataset[:key]][:description]
        is_trendsearth = dataset[:key] == :trendsearth
        order = 1

        # Status layers get both sources (data + methodology)
        status_sources = [sources[:zenodo], sources[:gpgv2_addendum]]
        # Non-status layers get just the data source
        data_sources = [sources[:zenodo]]

        # SDG 15.3.1 Status 2023 (Band 14) - only Trends.Earth active by default
        layer = create_layer(
          group: group,
          slug: "sdg-15-3-1-status-2023-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:sdg_status_2023],
          colormap_key: :sdg_status,
          legend_key: :sdg_status,
          name: "SDG 15.3.1 Status 2023 vs Baseline (#{dataset_short})",
          info: "SDG Indicator 15.3.1 status in 2023 compared to 2000-2015 baseline, using #{dataset_name} productivity data. Methodology based on UNCCD GPGv2 Addendum.",
          description: "SDG Indicator 15.3.1 measures the proportion of land that is degraded over total land area. This layer shows the status in 2023 relative to the 2000-2015 baseline period.\n\n#{dataset_desc}",
          active: is_trendsearth,  # Only Trends.Earth status 2023 is active by default
          order: order,
          color: "#C62828",
          sources: status_sources
        )
        puts "  Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 Status 2019 (Band 9)
        layer = create_layer(
          group: group,
          slug: "sdg-15-3-1-status-2019-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:sdg_status_2019],
          colormap_key: :sdg_status,
          legend_key: :sdg_status,
          name: "SDG 15.3.1 Status 2019 vs Baseline (#{dataset_short})",
          info: "SDG Indicator 15.3.1 status in 2019 compared to 2000-2015 baseline, using #{dataset_name} productivity data. Methodology based on UNCCD GPGv2 Addendum.",
          description: "SDG Indicator 15.3.1 measures the proportion of land that is degraded over total land area. This layer shows the status in 2019 relative to the 2000-2015 baseline period.\n\n#{dataset_desc}",
          active: false,
          order: order,
          color: "#C62828",
          sources: status_sources
        )
        puts "  Created layer: #{layer.slug}"
        order += 1

        # SDG Indicator 15.3.1 2008-2023 (Band 10)
        layer = create_layer(
          group: group,
          slug: "sdg-15-3-1-2008-2023-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:sdg_2023],
          colormap_key: :sdg_indicator,
          legend_key: :sdg_indicator,
          name: "SDG Indicator 15.3.1 2008-2023 (#{dataset_short})",
          info: "SDG Indicator 15.3.1 for the 2008-2023 reporting period, using #{dataset_name} productivity data.",
          description: "SDG Indicator 15.3.1 showing land degradation for the 2008-2023 period.\n\n#{dataset_desc}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "  Created layer: #{layer.slug}"
        order += 1

        # SDG Indicator 15.3.1 2004-2019 (Band 5)
        layer = create_layer(
          group: group,
          slug: "sdg-15-3-1-2004-2019-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:sdg_2019],
          colormap_key: :sdg_indicator,
          legend_key: :sdg_indicator,
          name: "SDG Indicator 15.3.1 2004-2019 (#{dataset_short})",
          info: "SDG Indicator 15.3.1 for the 2004-2019 reporting period, using #{dataset_name} productivity data.",
          description: "SDG Indicator 15.3.1 showing land degradation for the 2004-2019 period.\n\n#{dataset_desc}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "  Created layer: #{layer.slug}"
        order += 1

        # SDG 15.3.1 Baseline 2000-2015 (Band 1)
        layer = create_layer(
          group: group,
          slug: "sdg-15-3-1-baseline-2000-2015-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:sdg_baseline],
          colormap_key: :sdg_indicator,
          legend_key: :sdg_indicator,
          name: "SDG Indicator 15.3.1 Baseline 2000-2015 (#{dataset_short})",
          info: "SDG Indicator 15.3.1 for the baseline period 2000-2015, using #{dataset_name} productivity data.",
          description: "SDG Indicator 15.3.1 baseline showing land degradation status during the 2000-2015 baseline period.\n\n#{dataset_desc}",
          active: false,  # Not loaded by default - only Status 2023 (TE) is loaded
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "  Created layer: #{layer.slug}"
      end
    end

    def create_lpd_layers(groups, sources)
      # Datasets map to subgroups
      datasets = [
        {key: :trendsearth, group_slug: "lpd-trendsearth"},
        {key: :fao_wocat, group_slug: "lpd-fao-wocat"},
        {key: :jrc, group_slug: "lpd-jrc"}
      ]

      datasets.each do |dataset|
        group = groups[dataset[:group_slug]]
        dataset_name = DATASET_INFO[dataset[:key]][:name]
        dataset_short = DATASET_INFO[dataset[:key]][:short_name]
        dataset_desc = DATASET_INFO[dataset[:key]][:description]
        data_sources = [sources[:zenodo]]
        order = 1

        # LPD 2009-2023 (Band 11) - all inactive by default (only SDG status and baseline are active)
        layer = create_layer(
          group: group,
          slug: "lpd-2009-2023-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:lpd_2023],
          colormap_key: :lpd,
          legend_key: :lpd,
          name: "LPD 2009-2023 (#{dataset_short})",
          info: "Land Productivity Dynamics for the 2009-2023 period using #{dataset_name} methodology.",
          description: "Land Productivity Dynamics (LPD) measures changes in vegetation productivity over time.\n\n#{dataset_desc}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "  Created layer: #{layer.slug}"
        order += 1

        # LPD 2005-2019 (Band 6)
        layer = create_layer(
          group: group,
          slug: "lpd-2005-2019-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:lpd_2019],
          colormap_key: :lpd,
          legend_key: :lpd,
          name: "LPD 2005-2019 (#{dataset_short})",
          info: "Land Productivity Dynamics for the 2005-2019 period using #{dataset_name} methodology.",
          description: "Land Productivity Dynamics (LPD) measures changes in vegetation productivity over time.\n\n#{dataset_desc}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "  Created layer: #{layer.slug}"
        order += 1

        # LPD Baseline 2001-2015 (Band 2)
        layer = create_layer(
          group: group,
          slug: "lpd-baseline-2001-2015-#{dataset[:key].to_s.tr("_", "-")}",
          cog_key: dataset[:key],
          band: BANDS[:lpd_baseline],
          colormap_key: :lpd,
          legend_key: :lpd,
          name: "LPD Baseline 2001-2015 (#{dataset_short})",
          info: "Land Productivity Dynamics for the baseline period 2001-2015 using #{dataset_name} methodology.",
          description: "Land Productivity Dynamics (LPD) baseline showing vegetation productivity trends during the 2001-2015 baseline period.\n\n#{dataset_desc}",
          active: false,
          order: order,
          color: "#C62828",
          sources: data_sources
        )
        puts "  Created layer: #{layer.slug}"
      end

      # Clean up old LPD layer slugs
      old_slugs = %w[lpd-2008-2023-trendsearth lpd-2008-2023-fao-wocat lpd-2008-2023-jrc]
      old_slugs.each do |slug|
        old_layer = Layer.find_by(slug: slug)
        if old_layer
          Agrupation.where(layer_id: old_layer.id).destroy_all
          old_layer.destroy
          puts "    Removed old layer: #{slug}"
        end
      end
    end

    def create_land_cover_layers(group, sources)
      # Land cover only uses Trends.Earth dataset
      # Layer order: newest first (reverse chronological)
      # Land cover uses ESA CCI data processed by Trends.Earth
      lc_base_desc = "Land cover degradation is assessed by comparing land cover maps from the baseline and reporting periods using ESA CCI land cover data processed by Trends.Earth."
      data_sources = [sources[:zenodo]]

      layer = create_layer(
        group: group,
        slug: "lc-degradation-2015-2022",
        cog_key: :trendsearth,
        band: BANDS[:lc_2023],
        colormap_key: :land_cover,
        legend_key: :land_cover,
        name: "Land Cover Degradation 2015-2022 (TE)",
        info: "Land cover change degradation indicator for 2015-2022 based on ESA CCI land cover data processed by Trends.Earth.",
        description: lc_base_desc,
        active: false,  # Only SDG status and baseline are active
        order: 1,
        color: "#FF9800",
        sources: data_sources
      )
      puts "  Created layer: #{layer.slug}"

      layer = create_layer(
        group: group,
        slug: "lc-degradation-2015-2019",
        cog_key: :trendsearth,
        band: BANDS[:lc_2019],
        colormap_key: :land_cover,
        legend_key: :land_cover,
        name: "Land Cover Degradation 2015-2019 (TE)",
        info: "Land cover change degradation indicator for 2015-2019 based on ESA CCI land cover data processed by Trends.Earth.",
        description: lc_base_desc,
        active: false,
        order: 2,
        color: "#FF9800",
        sources: data_sources
      )
      puts "  Created layer: #{layer.slug}"

      layer = create_layer(
        group: group,
        slug: "lc-degradation-2000-2015",
        cog_key: :trendsearth,
        band: BANDS[:lc_baseline],
        colormap_key: :land_cover,
        legend_key: :land_cover,
        name: "Land Cover Degradation Baseline 2000-2015 (TE)",
        info: "Land cover change degradation indicator for the 2000-2015 baseline period based on ESA CCI data processed by Trends.Earth.",
        description: "Land cover degradation for the baseline period (2000-2015) using ESA CCI land cover data.",
        active: false,
        order: 3,
        color: "#FF9800",
        sources: data_sources
      )
      puts "  Created layer: #{layer.slug}"

      # Clean up old layer slugs
      %w[lc-degradation-2015-2023 lc-degradation-2008-2023 lc-degradation-2004-2019].each do |slug|
        old_layer = Layer.find_by(slug: slug)
        if old_layer
          Agrupation.where(layer_id: old_layer.id).destroy_all
          old_layer.destroy
          puts "    Removed old layer: #{slug}"
        end
      end
    end

    def create_soc_layers(group, sources)
      # SOC only uses Trends.Earth dataset
      # Layer order: newest first (reverse chronological)
      soc_base_desc = "Soil organic carbon (SOC) change is estimated based on land cover transitions and associated changes in carbon stocks, using IPCC default carbon stock values processed by Trends.Earth."
      data_sources = [sources[:zenodo]]

      layer = create_layer(
        group: group,
        slug: "soc-degradation-2015-2022",
        cog_key: :trendsearth,
        band: BANDS[:soc_2023],
        colormap_key: :soc,
        legend_key: :soc,
        name: "SOC Change 2015-2022 (TE)",
        info: "Percentage change in soil organic carbon stocks for 2015-2022, processed by Trends.Earth.",
        description: "#{soc_base_desc}\n\nValues represent percentage change in SOC from baseline to target year. Degradation is defined as < -10%, stable as -10% to +10%, and improvement as > +10%.",
        active: false,  # Only SDG status and baseline are active
        order: 1,
        color: "#795548",
        analysis_type: "histogram",
        sources: data_sources
      )
      puts "  Created layer: #{layer.slug}"

      layer = create_layer(
        group: group,
        slug: "soc-degradation-2015-2019",
        cog_key: :trendsearth,
        band: BANDS[:soc_2019],
        colormap_key: :soc,
        legend_key: :soc,
        name: "SOC Change 2015-2019 (TE)",
        info: "Percentage change in soil organic carbon stocks for 2015-2019, processed by Trends.Earth.",
        description: "#{soc_base_desc}\n\nValues represent percentage change in SOC from baseline to target year. Degradation is defined as < -10%, stable as -10% to +10%, and improvement as > +10%.",
        active: false,
        order: 2,
        color: "#795548",
        analysis_type: "histogram",
        sources: data_sources
      )
      puts "  Created layer: #{layer.slug}"

      layer = create_layer(
        group: group,
        slug: "soc-degradation-2000-2015",
        cog_key: :trendsearth,
        band: BANDS[:soc_baseline],
        colormap_key: :soc,
        legend_key: :soc,
        name: "SOC Change Baseline 2000-2015 (TE)",
        info: "Percentage change in soil organic carbon stocks for the 2000-2015 baseline period, processed by Trends.Earth.",
        description: "Soil organic carbon (SOC) change for the baseline period (2000-2015) using IPCC default carbon stock values.",
        active: false,
        order: 3,
        color: "#795548",
        analysis_type: "histogram",
        sources: data_sources
      )
      puts "  Created layer: #{layer.slug}"

      # Clean up old layer slugs
      %w[soc-degradation-2015-2023 soc-degradation-2008-2023 soc-degradation-2004-2019].each do |slug|
        old_layer = Layer.find_by(slug: slug)
        if old_layer
          Agrupation.where(layer_id: old_layer.id).destroy_all
          old_layer.destroy
          puts "    Removed old layer: #{slug}"
        end
      end
    end

    private

    def create_layer(group:, slug:, cog_key:, band:, colormap_key:, legend_key:, name:, info:, description:, active:, order:, color:, analysis_type: "categorical", sources: [])
      cog_url = "#{COG_BASE}/#{COGS[cog_key]}"
      colormap = COLORMAPS[colormap_key]
      legend = LEGENDS[legend_key]

      layer_config = {
        type: "tileLayer",
        body: {
          url: "#{TITILER_BASE}/tiles/WebMercatorQuad/{z}/{x}/{y}?url=#{CGI.escape(cog_url)}&bidx=#{band}&colormap={{colormap}}"
        },
        params: {
          colormap: colormap
        }
      }

      layer = Layer.find_or_initialize_by(slug: slug)
      layer.assign_attributes(
        layer_group_id: group.id,
        layer_type: "raster",
        zindex: 100,
        active: active,
        "order" => order,
        dashboard_order: order,  # Match order for frontend sorting
        color: color,
        layer_provider: "cog",
        opacity: 1.0,
        published: true,
        zoom_max: 18,
        zoom_min: 0,
        download: true,
        analysis_suitable: true,
        analysis_type: analysis_type,
        layer_config: layer_config.to_json,
        interaction_config: "{}",
        # Globalize translated attributes
        name: name,
        info: info,
        legend: legend.to_json,
        description: description
      )
      layer.save!

      # Link sources to layer (clear existing and add new)
      if sources.any?
        layer.sources.clear
        sources.each { |source| layer.sources << source unless layer.sources.include?(source) }
      end

      # Clean up any stale agrupations for this layer and create/update the correct one
      Agrupation.where(layer_id: layer.id).where.not(layer_group_id: group.id).destroy_all
      agrupation = Agrupation.find_or_initialize_by(layer_id: layer.id, layer_group_id: group.id)
      agrupation.active = active
      agrupation.save!

      layer
    end
  end
end

# Run the seeder
TrendsEarthSeeder.run
