# SBTN Thresholds — Thresholds Site Scope Seed Script
#
# Creates a "thresholds" site scope with three categories (Exceedances,
# Thresholds, Baselines), four indicator sub-groups each, twelve CartoDB map
# layers, and three ScopeDatasets for the analysis panel.
#
# Prerequisites:
#   1. Run the Python preprocessor to generate sbtn_thresholds.csv:
#        python db/data/thresholds/preprocess.py
#   2. Upload sbtn_thresholds.csv to CartoDB as a table named "sbtn_thresholds"
#      so the map layers can JOIN against it.
#   3. The ldn_dissolved_geometries table must exist (run `rake ldn:build_dimensions`)
#      for the analysis panel geometries to be populated.
#
# Run from the backend directory:
#   bundle exec rails runner db/data/thresholds/seed.rb
#
# Or via Rake:
#   bundle exec rake thresholds:seed

module ThresholdsSeeder
  # ── Indicator definitions ──────────────────────────────────────────────────
  # col:              prefix used in sbtn_thresholds.csv column names
  # higher_is_better: true  → more is better (natural land cover, SOC)
  #                   false → less is better (nitrogen deposition, soil erosion)
  INDICATOR_DEFS = {
    natural_land: {
      label:            "Natural Land",
      col:              "natural_land",
      higher_is_better: true,
      unit:             "%",
      seq_breaks:       [8, 16, 24, 32, 40, 48, 56, 64, 70, 76, 82, 90],
      exc_breaks:       [-30, -20, -12, -7, -3, -1, 1, 3, 7, 12, 20, 30]
    },
    nitrogen_deposition: {
      label:            "Nitrogen Deposition",
      col:              "nitrogen_dep",
      higher_is_better: false,
      unit:             "kg N/ha/yr",
      seq_breaks:       [0.5, 1.5, 3, 5, 7, 10, 13, 16, 20, 26, 35, 48],
      exc_breaks:       [-12, -8, -5, -3, -1.5, -0.5, 0.5, 1.5, 3, 5, 8, 12]
    },
    soil_erosion: {
      label:            "Soil Erosion",
      col:              "soil_erosion",
      higher_is_better: false,
      unit:             "t/ha/yr",
      seq_breaks:       [0.2, 0.5, 1, 2, 3, 5, 7, 10, 14, 18, 25, 35],
      exc_breaks:       [-8, -6, -4, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 4, 6, 8]
    },
    soil_organic_carbon: {
      label:            "Soil Organic Carbon",
      col:              "soc",
      higher_is_better: true,
      unit:             "Mg C/ha",
      seq_breaks:       [20, 28, 36, 44, 52, 60, 68, 76, 84, 92, 105, 120],
      exc_breaks:       [-40, -25, -15, -8, -3, -1, 1, 3, 8, 15, 25, 40]
    }
  }.freeze

  # ── Category definitions ───────────────────────────────────────────────────
  CATEGORY_DEFS = {
    exceedances: {label: "Exceedance", suffix: "exceedance", order: 1,
                  description: "Difference between the current baseline value and threshold."},
    thresholds:  {label: "Threshold",  suffix: "threshold",  order: 2,
                  description: "Threshold value by ecoregion."},
    baselines:   {label: "Baseline",   suffix: "baseline",   order: 3,
                  description: "Current baseline values by ecoregion."}
  }.freeze

  # ── Color ramps (13 steps each, colorblind-safe) ───────────────────────────
  # Sequential Viridis: dark purple (low) → bright yellow (high).
  # Used for higher_is_better indicators (baselines / thresholds).
  # Perceptually uniform and safe for all forms of color vision deficiency.
  VIRIDIS_13 = %w[#440154 #481769 #472c7a #3b528b #2d718e #21908d #27ad81
                  #4dc36a #7fd34e #b8de29 #d8e219 #ece51c #fde725].freeze

  # Inverted Viridis: bright yellow (low = good) → dark purple (high = bad).
  # Used for lower_is_better indicators (less is better: low values are best).
  VIRIDIS_13_INV = VIRIDIS_13.reverse.freeze

  # Diverging Blue-Orange: deep blue (index 0, most-negative = best) →
  # white (index 6, near zero) → dark brown-orange (index 12, most-positive = worst).
  # Blue and orange are distinguishable by all forms of colorblindness.
  # For exceedances: negative = meeting/exceeding target; positive = failing.
  DIVERGING_13 = %w[#023858 #045a8d #0570b0 #3690c0 #74a9cf #d0e8f4 #f7f7f7
                    #fde8c8 #fdba6b #f77f2e #d4521a #a63603 #7f2704].freeze

  # ── Data file ─────────────────────────────────────────────────────────────
  DATA_CSV = File.join(__dir__, "sbtn_thresholds.csv").freeze

  # ── Temp table name ───────────────────────────────────────────────────────
  TEMP_TABLE = "_sbtn_thresholds".freeze

  # ── Entry point ───────────────────────────────────────────────────────────

  def self.run
    puts "Starting SBTN Thresholds site scope seed..."

    site_scope = create_site_scope
    groups     = create_layer_groups(site_scope)

    # Remove any stale per-indicator sub-groups from earlier seeds
    top_level_ids = groups.values.map(&:id)
    stale = LayerGroup.where(site_scope_id: site_scope.id)
                      .where.not(super_group_id: nil)
                      .where(super_group_id: top_level_ids)
    if stale.any?
      puts "Removing #{stale.count} stale sub-groups from previous seed..."
      stale.destroy_all
    end

    create_layers(groups)

    begin
      create_scope_datasets(site_scope)
    rescue => e
      puts "WARNING: Scope dataset creation failed (non-fatal): #{e.message}"
      puts "  Layers were created. Ensure sbtn_thresholds.csv exists and"
      puts "  ldn_dissolved_geometries is populated, then re-run."
    end

    puts "SBTN Thresholds seed completed successfully!"
  end

  # ── Site scope ────────────────────────────────────────────────────────────

  def self.create_site_scope
    puts "Creating site scope..."
    scope = SiteScope.find_or_initialize_by(subdomain: "thresholds")
    scope.assign_attributes(
      name:         "SBTN Thresholds",
      has_analysis: true,
      latitude:     0,
      longitude:    0,
      zoom_level:   2,
      header_theme: "ci-theme",
      header_color: "#2d6a4f",
      color:        "#2d6a4f"
    )
    scope.save!
    puts "  Site scope: #{scope.subdomain}"
    scope
  end

  # ── Layer groups ──────────────────────────────────────────────────────────

  def self.create_layer_groups(site_scope)
    puts "Creating layer groups..."
    groups = {}

    # Top-level category groups — all indicator layers nest directly here
    CATEGORY_DEFS.each do |cat_key, cat|
      slug = "thresholds-#{cat_key}"
      g = LayerGroup.find_or_initialize_by(slug: slug, site_scope_id: site_scope.id)
      g.assign_attributes(
        super_group_id: nil,
        active:         true,
        "order"      => cat[:order],
        name:           cat[:label],
        info:           cat[:description]
      )
      g.save!
      groups[slug] = g
      puts "  #{slug}"
    end

    groups
  end

  # ── CartoDB layers ────────────────────────────────────────────────────────

  def self.create_layers(groups)
    puts "Creating CartoDB layers..."

    layer_order = 1

    CATEGORY_DEFS.each do |cat_key, cat|
      ind_order = 1
      INDICATOR_DEFS.each do |ind_key, ind|
        col        = ind[:col]
        suffix     = cat[:suffix]
        value_col  = "#{col}_#{suffix}"
        cat_slug   = "thresholds-#{cat_key}"
        group      = groups[cat_slug]
        layer_slug = "sbtn-#{col.tr("_", "-")}-#{suffix}"

        # Only natural land exceedance is active by default
        active = (ind_key == :natural_land && cat_key == :exceedances)

        css         = build_css(value_col: value_col, cat_key: cat_key, ind: ind)
        query       = build_query(value_col: value_col, ind: ind)
        legend      = build_legend(value_col: value_col, cat_key: cat_key, ind: ind)
        inter_cfg   = build_interaction_config(ind: ind)
        interactivity = "eco_id, eco_name, biome_name, realm, " \
                        "#{col}_baseline, #{col}_threshold, #{col}_exceedance"

        layer = Layer.find_or_initialize_by(slug: layer_slug)
        layer.assign_attributes(
          layer_group_id:    group.id,
          layer_type:        "layer",
          layer_provider:    "cartodb",
          active:            active,
          "order"         => ind_order,
          dashboard_order:   ind_order,
          color:             "#2d6a4f",
          css:               css,
          query:             query,
          interactivity:     interactivity,
          interaction_config: inter_cfg,
          opacity:           1.0,
          zoom_max:          24,
          zoom_min:          0,
          published:         true,
          analysis_suitable: false,
          download:          false,
          legend:            legend,
          name:              "#{ind[:label]} — #{cat[:label]}",
          info:              "SBTN Thresholds: #{ind[:label]} #{cat[:label].downcase} " \
                             "by ecoregion (#{ind[:unit]})",
          description:       "#{cat[:description]} Indicator: #{ind[:label]}. Units: #{ind[:unit]}.",
          layer_config:      nil,
          analysis_body:     nil
        )
        layer.save!

        # Clean up stale agrupations within the same site scope
        scope_group_ids = LayerGroup.where(site_scope_id: group.site_scope_id).pluck(:id)
        Agrupation.where(layer_id: layer.id, layer_group_id: scope_group_ids)
                  .where.not(layer_group_id: group.id).destroy_all

        agrupation = Agrupation.find_or_initialize_by(layer_id: layer.id, layer_group_id: group.id)
        agrupation.active = active
        agrupation.save!

        puts "  #{layer_slug} (active=#{active})"
        ind_order += 1
        layer_order += 1
      end
    end
  end

  # ── Scope datasets (analysis panel) ──────────────────────────────────────

  def self.create_scope_datasets(site_scope)
    puts "Creating scope datasets..."

    raise "Data CSV not found: #{DATA_CSV}" unless File.exist?(DATA_CSV)

    conn = ActiveRecord::Base.connection

    # Load sbtn_thresholds.csv into a temp table
    conn.execute("DROP TABLE IF EXISTS #{TEMP_TABLE}")
    conn.execute(<<~SQL)
      CREATE TABLE #{TEMP_TABLE} (
        eco_id                  integer,
        ecoregion               text,
        natural_land_baseline   double precision,
        natural_land_threshold  double precision,
        natural_land_exceedance double precision,
        nitrogen_dep_baseline   double precision,
        nitrogen_dep_threshold  double precision,
        nitrogen_dep_exceedance double precision,
        soil_erosion_baseline   double precision,
        soil_erosion_threshold  double precision,
        soil_erosion_exceedance double precision,
        soc_baseline            double precision,
        soc_threshold           double precision,
        soc_exceedance          double precision
      )
    SQL
    copy_csv_to_table(conn, TEMP_TABLE, DATA_CSV)
    row_count = conn.select_value("SELECT count(*) FROM #{TEMP_TABLE}")
    puts "  Loaded #{row_count} rows into #{TEMP_TABLE}"

    display_order = 1
    CATEGORY_DEFS.each do |cat_key, cat|
      suffix = cat[:suffix]
      slug   = "thresholds-#{cat_key}"

      # Build column lists for this category
      value_cols = INDICATOR_DEFS.map { |_, ind| "#{ind[:col]}_#{suffix}" }
      schema_cols = value_cols.map { |vc| INDICATOR_DEFS.find { |_, d| vc.start_with?(d[:col]) }&.last }

      sql = <<~SQL
        SELECT
          eco_id,
          ecoregion,
          #{value_cols.map { |c| "ROUND(#{c}::numeric, 3) AS #{c}" }.join(",\n          ")}
        FROM #{TEMP_TABLE}
        ORDER BY eco_id
      SQL

      rows = fetch_rows(sql)

      schema_config = build_schema_config(cat_key: cat_key, suffix: suffix)
      chart_config  = build_chart_config(cat_key: cat_key, suffix: suffix)

      dataset = ScopeDataset.find_or_initialize_by(site_scope: site_scope, slug: slug)
      dataset.assign_attributes(
        name:             "SBTN #{cat[:label]} by Ecoregion",
        data_type:        "tabular",
        group_key:        cat_key.to_s,
        variant_label:    nil,
        dimension:        "ecoregion",
        dimension_config: {unit_label: "Ecoregion", unit_id_column: "eco_id", name_column: "ecoregion"},
        schema_config:    schema_config,
        chart_config:     chart_config,
        data:             rows,
        display_order:    display_order
      )
      dataset.save!
      puts "  #{slug}: #{rows.size} rows"

      copy_dissolved_geometries(dataset, "ecoregion", "eco_id")
      display_order += 1
    end

  ensure
    conn&.execute("DROP TABLE IF EXISTS #{TEMP_TABLE}")
  end

  # ── CSS helpers ───────────────────────────────────────────────────────────

  def self.build_css(value_col:, cat_key:, ind:)
    base = <<~CSS
      #ecoregions2017 {
        polygon-fill: #aaaaaa;
        polygon-opacity: 0.8;
        line-color: #ffffff;
        line-width: 0.3;
        line-opacity: 0.5;
      }
      #ecoregions2017 [#{value_col}=null] { polygon-fill: #aaaaaa; }
    CSS

    if cat_key == :exceedances
      exceedance_rules(value_col: value_col, ind: ind, base: base)
    else
      sequential_rules(value_col: value_col, ind: ind, base: base)
    end
  end

  def self.exceedance_rules(value_col:, ind:, base:)
    # For all indicators the sign already encodes direction:
    #   negative exceedance = meeting/exceeding the target = good → green
    #   positive exceedance = failing to meet the target   = bad  → red
    # DIVERGING_13[0] is the darkest green (lowest/most-negative bin).
    breaks = ind[:exc_breaks]
    css = breaks.each_with_index.map do |brk, i|
      if i == 0
        "  #ecoregions2017 [#{value_col} < #{brk}] { polygon-fill: #{DIVERGING_13[0]}; }"
      else
        "  #ecoregions2017 [#{value_col} >= #{breaks[i - 1]}][#{value_col} < #{brk}] { polygon-fill: #{DIVERGING_13[i]}; }"
      end
    end
    css << "  #ecoregions2017 [#{value_col} >= #{breaks.last}] { polygon-fill: #{DIVERGING_13[12]}; }"
    base + css.join("\n") + "\n"
  end

  def self.sequential_rules(value_col:, ind:, base:)
    breaks = ind[:seq_breaks]
    colors = ind[:higher_is_better] ? VIRIDIS_13 : VIRIDIS_13_INV
    css = breaks.each_with_index.map do |brk, i|
      if i == 0
        "  #ecoregions2017 [#{value_col} < #{brk}] { polygon-fill: #{colors[0]}; }"
      else
        "  #ecoregions2017 [#{value_col} >= #{breaks[i - 1]}][#{value_col} < #{brk}] { polygon-fill: #{colors[i]}; }"
      end
    end
    css << "  #ecoregions2017 [#{value_col} >= #{breaks.last}] { polygon-fill: #{colors[12]}; }"
    base + css.join("\n") + "\n"
  end

  # ── CartoDB SQL query ─────────────────────────────────────────────────────

  def self.build_query(value_col:, ind:)
    col = ind[:col]
    <<~SQL.strip
      SELECT
        e.cartodb_id,
        e.the_geom_webmercator,
        e.eco_id,
        e.eco_name,
        e.biome_name,
        e.realm,
        t.#{col}_baseline,
        t.#{col}_threshold,
        t.#{col}_exceedance
      FROM ecoregions2017 e
      LEFT JOIN sbtn_thresholds t ON e.eco_id::int = t.eco_id
    SQL
  end

  # ── Legend JSON ───────────────────────────────────────────────────────────

  def self.build_legend(value_col:, cat_key:, ind:)
    unit = ind[:unit]
    if cat_key == :exceedances
      breaks = ind[:exc_breaks]   # 12 elements → 13 bins
      {
        type:   "choropleth",
        bucket: DIVERGING_13,
        units:  unit,
        min:    "< #{breaks.first} (best)",
        mid:    "0 (target)",
        max:    "> #{breaks.last} (worst)"
      }.to_json
    else
      breaks = ind[:seq_breaks]   # 12 elements → 13 bins
      colors = ind[:higher_is_better] ? VIRIDIS_13 : VIRIDIS_13_INV
      # Use break at index 5 as a mid-point label (centre of the 13-bin ramp)
      mid_val = breaks[5]
      {
        type:   "choropleth",
        bucket: colors,
        units:  unit,
        min:    "< #{breaks.first}",
        mid:    "~#{mid_val}",
        max:    "> #{breaks.last}"
      }.to_json
    end
  end

  # ── Interaction config ────────────────────────────────────────────────────

  def self.build_interaction_config(ind:)
    col  = ind[:col]
    unit = ind[:unit]
    label = ind[:label]
    output = [
      {column: "eco_id",              property: "Ecoregion ID",                    prefix: "", sufix: "", type: "integer", format: nil},
      {column: "eco_name",            property: "Ecoregion",                        prefix: "", sufix: "", type: "string",  format: nil},
      {column: "biome_name",          property: "Biome",                            prefix: "", sufix: "", type: "string",  format: nil},
      {column: "realm",               property: "Realm",                            prefix: "", sufix: "", type: "string",  format: nil},
      {column: "#{col}_baseline",     property: "#{label} — Baseline (#{unit})",    prefix: "", sufix: "", type: "number",  format: "0.0"},
      {column: "#{col}_threshold",    property: "#{label} — Threshold (#{unit})",   prefix: "", sufix: "", type: "number",  format: "0.0"},
      {column: "#{col}_exceedance",   property: "#{label} — Exceedance (#{unit})",  prefix: "", sufix: "", type: "number",  format: "0.0"}
    ]
    {output: output}.to_json
  end

  # ── Schema & chart config for ScopeDatasets ───────────────────────────────

  def self.build_schema_config(cat_key:, suffix:)
    cols = [
      {name: "eco_id",    type: "integer", label: "Ecoregion ID"},
      {name: "ecoregion", type: "string",  label: "Ecoregion"}
    ]
    INDICATOR_DEFS.each do |_, ind|
      col_name = "#{ind[:col]}_#{suffix}"
      cols << {name: col_name, type: "number", label: "#{ind[:label]} (#{ind[:unit]})", format: ".3f"}
    end
    cols
  end

  def self.build_chart_config(cat_key:, suffix:)
    ind_cols = INDICATOR_DEFS.map { |_, ind| "#{ind[:col]}_#{suffix}" }
    [
      {
        id:      "#{cat_key}-table",
        type:    "table",
        title:   "All Ecoregions",
        columns: ["ecoregion"] + ind_cols
      }
    ]
  end

  # ── Generic helpers (mirrored from LDN seed) ──────────────────────────────

  def self.copy_csv_to_table(conn, table_name, csv_path)
    raw = conn.raw_connection
    raw.copy_data("COPY #{table_name} FROM STDIN CSV HEADER") do
      File.open(csv_path, "r") do |f|
        while (line = f.gets)
          raw.put_copy_data(line)
        end
      end
    end
  end

  def self.fetch_rows(sql)
    ActiveRecord::Base.connection.exec_query(sql).to_a.map do |row|
      row.transform_values { |v| v.is_a?(BigDecimal) ? v.to_f : v }
    end
  end

  def self.copy_dissolved_geometries(dataset, source, unit_key)
    conn = ActiveRecord::Base.connection
    exists = conn.select_value(
      "SELECT to_regclass('public.ldn_dissolved_geometries') IS NOT NULL"
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
end

# Run the seeder
ThresholdsSeeder.run
