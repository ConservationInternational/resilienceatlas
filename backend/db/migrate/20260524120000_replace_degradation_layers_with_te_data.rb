# Replaces the existing subcategories of the main site scope's "Stressors and Shocks"
# "Degradation" category with two new subcategories:
#
# 1. "SDG Indicator 15.3.1" – contains the layers from the Trends.Earth site scope's
#    "SDG Indicator 15.3.1" > "Trends.Earth" subcategory (slug: sdg-trendsearth).
#
# 2. "Sub-indicators" – a subcategory with three subgroups, each referencing
#    Trends.Earth layers:
#      a. "Productivity"        ← TE scope "Land Productivity" > "Trends.Earth" (lpd-trendsearth)
#      b. "Land Cover"          ← TE scope "Land Cover" (land-cover)
#      c. "Soil Organic Carbon" ← TE scope "Soil Organic Carbon" (soil-organic-carbon)
#
# The three existing subcategories ("Changes in primary productivity",
# "Changes in land cover", "Changes in Soil organic carbon") and their
# agrupations and child groups are removed.
#
# Layers are shared between site scopes via new agrupations – the layer records
# themselves remain owned by the Trends.Earth scope and are not duplicated.
#
# This migration is reversible: `down` restores the original structure using the
# known IDs from the production seed (layers.rb).
class ReplaceDegradationLayersWithTeData < ActiveRecord::Migration[7.2]
  # Slugs for the new layer groups created in the main scope (site_scope_id = 1)
  SDG_SUBCATEGORY_SLUG = "degradation-sdg-15-3-1"
  SUBIND_SUBCATEGORY_SLUG = "degradation-sub-indicators"
  PROD_SUBGROUP_SLUG = "degradation-sub-ind-productivity"
  LC_SUBGROUP_SLUG = "degradation-sub-ind-land-cover"
  SOC_SUBGROUP_SLUG = "degradation-sub-ind-soc"

  # Slugs of the source layer groups in the Trends.Earth site scope
  TE_SDG_GROUP_SLUG = "sdg-trendsearth"
  TE_LPD_GROUP_SLUG = "lpd-trendsearth"
  TE_LC_GROUP_SLUG = "land-cover"
  TE_SOC_GROUP_SLUG = "soil-organic-carbon"

  def up
    # Ensure the unique index exists (required for ON CONFLICT in upsert_translation)
    ensure_layer_group_translations_unique_index

    now = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")

    # ── 1. Find the "Degradation" category in the main scope ─────────────────
    degradation_id = find_degradation_id
    unless degradation_id
      Rails.logger.warn "#{self.class.name}: 'Degradation' category not found in main scope. Aborting."
      return
    end

    # ── 2. Remove existing subcategories (and grandchildren) under Degradation ─
    remove_existing_children(degradation_id)

    # ── 3. Create "SDG Indicator 15.3.1" subcategory ─────────────────────────
    sdg_id = insert_layer_group(
      super_group_id: degradation_id,
      slug: SDG_SUBCATEGORY_SLUG,
      layer_group_type: "subcategory",
      order: 1,
      now: now
    )
    upsert_translation(sdg_id, "SDG Indicator 15.3.1", nil, now)

    # ── 4. Create "Sub-indicators" subcategory ────────────────────────────────
    subind_id = insert_layer_group(
      super_group_id: degradation_id,
      slug: SUBIND_SUBCATEGORY_SLUG,
      layer_group_type: "subcategory",
      order: 2,
      now: now
    )
    upsert_translation(subind_id, "Sub-indicators", nil, now)

    # ── 5. Create three subgroups under "Sub-indicators" ─────────────────────
    prod_id = insert_layer_group(
      super_group_id: subind_id,
      slug: PROD_SUBGROUP_SLUG,
      layer_group_type: "subgroup",
      order: 1,
      now: now
    )
    upsert_translation(prod_id, "Productivity", nil, now)

    lc_id = insert_layer_group(
      super_group_id: subind_id,
      slug: LC_SUBGROUP_SLUG,
      layer_group_type: "subgroup",
      order: 2,
      now: now
    )
    upsert_translation(lc_id, "Land Cover", nil, now)

    soc_id = insert_layer_group(
      super_group_id: subind_id,
      slug: SOC_SUBGROUP_SLUG,
      layer_group_type: "subgroup",
      order: 3,
      now: now
    )
    upsert_translation(soc_id, "Soil Organic Carbon", nil, now)

    # ── 6. Link Trends.Earth layers via agrupations ───────────────────────────
    te_scope_id = find_te_scope_id
    unless te_scope_id
      Rails.logger.warn "#{self.class.name}: Trends.Earth site scope not found. " \
                        "Layer groups created but no layers added."
      return
    end

    add_layers_from_te_group(TE_SDG_GROUP_SLUG, te_scope_id, sdg_id)
    add_layers_from_te_group(TE_LPD_GROUP_SLUG, te_scope_id, prod_id)
    add_layers_from_te_group(TE_LC_GROUP_SLUG, te_scope_id, lc_id)
    add_layers_from_te_group(TE_SOC_GROUP_SLUG, te_scope_id, soc_id)
  end

  def down
    now = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")

    # ── Remove the new groups and their translations / agrupations ────────────
    new_slugs_sql = [
      SDG_SUBCATEGORY_SLUG,
      SUBIND_SUBCATEGORY_SLUG,
      PROD_SUBGROUP_SLUG,
      LC_SUBGROUP_SLUG,
      SOC_SUBGROUP_SLUG
    ].map { |s| "'#{s}'" }.join(", ")

    new_ids = execute(<<-SQL.squish).map { |r| r["id"].to_i }
      SELECT id FROM layer_groups
      WHERE slug IN (#{new_slugs_sql}) AND site_scope_id = 1
    SQL

    if new_ids.any?
      id_list = new_ids.join(", ")
      execute("DELETE FROM agrupations           WHERE layer_group_id IN (#{id_list})")
      execute("DELETE FROM layer_group_translations WHERE layer_group_id IN (#{id_list})")
      execute("DELETE FROM layer_groups             WHERE id           IN (#{id_list})")
    end

    # ── Restore "Degradation" subcategories from original seed (layers.rb) ───
    degradation_id = find_degradation_id
    return unless degradation_id

    # "Changes in primary productivity" (seed id: 1034)
    prod_id = restore_layer_group(
      id: 1034,
      super_group_id: degradation_id,
      layer_group_type: "subcategory",
      order: 1,
      now: now
    )
    upsert_translation(prod_id, "Changes in primary productivity", nil, now)

    # "Sub-indicators" subgroup under "Changes in primary productivity" (seed id: 1158)
    subind_id = restore_layer_group(
      id: 1158,
      super_group_id: prod_id,
      layer_group_type: "subgroup",
      order: nil,
      now: now
    )
    upsert_translation(subind_id, "Sub-indicators", nil, now)

    # Agrupation: layer 1463 → "Changes in primary productivity"
    insert_agrupation_if_missing(1463, prod_id)

    # "Changes in land cover" (seed id: 1035)
    lc_id = restore_layer_group(
      id: 1035,
      super_group_id: degradation_id,
      layer_group_type: "subcategory",
      order: 2,
      now: now
    )
    upsert_translation(lc_id, "Changes in land cover", nil, now)

    # Agrupations: layers 1376, 1377, 1378 → "Changes in land cover"
    [1376, 1377, 1378].each { |lid| insert_agrupation_if_missing(lid, lc_id) }

    # "Changes in Soil organic carbon" (seed id: 1036)
    soc_id = restore_layer_group(
      id: 1036,
      super_group_id: degradation_id,
      layer_group_type: "subcategory",
      order: 3,
      now: now
    )
    upsert_translation(soc_id, "Changes in Soil organic carbon", nil, now)

    # Agrupations: layers 1379, 1380, 1381 → "Changes in Soil organic carbon"
    [1379, 1380, 1381].each { |lid| insert_agrupation_if_missing(lid, soc_id) }
  end

  private

  def find_degradation_id
    result = execute(<<-SQL.squish).first
      SELECT lg.id
      FROM layer_groups lg
      JOIN layer_group_translations lgt
        ON lgt.layer_group_id = lg.id AND lgt.locale = 'en'
      WHERE lg.site_scope_id = 1
        AND lg.layer_group_type = 'category'
        AND lgt.name = 'Degradation'
      LIMIT 1
    SQL
    result ? result["id"].to_i : nil
  end

  def find_te_scope_id
    result = execute(
      "SELECT id FROM site_scopes WHERE subdomain = 'trendsearth' LIMIT 1"
    ).first
    result ? result["id"].to_i : nil
  end

  # Ensures the unique index on (layer_group_id, locale) exists, required for ON CONFLICT
  def ensure_layer_group_translations_unique_index
    index_name = "index_layer_group_translations_on_layer_group_id_and_locale"

    # Check if index already exists
    index_exists = execute(<<-SQL.squish).first
      SELECT 1
      FROM pg_indexes
      WHERE tablename = 'layer_group_translations'
        AND indexname = '#{index_name}'
    SQL

    unless index_exists
      Rails.logger.info "#{self.class.name}: Creating missing unique index on layer_group_translations..."
      execute(<<-SQL.squish)
        CREATE UNIQUE INDEX IF NOT EXISTS #{index_name}
        ON layer_group_translations (layer_group_id, locale)
      SQL
    end
  end

  # Removes all direct children (subcategories) and grandchildren (subgroups)
  # of the given parent group within the main site scope.
  def remove_existing_children(parent_id)
    child_ids = execute(<<-SQL.squish).map { |r| r["id"].to_i }
      SELECT id FROM layer_groups
      WHERE super_group_id = #{parent_id} AND site_scope_id = 1
    SQL
    return if child_ids.empty?

    grandchild_ids = execute(<<-SQL.squish).map { |r| r["id"].to_i }
      SELECT id FROM layer_groups
      WHERE super_group_id IN (#{child_ids.join(", ")}) AND site_scope_id = 1
    SQL

    all_ids = (child_ids + grandchild_ids).uniq
    id_list = all_ids.join(", ")

    execute("DELETE FROM agrupations           WHERE layer_group_id IN (#{id_list})")
    execute("DELETE FROM layer_group_translations WHERE layer_group_id IN (#{id_list})")
    execute("DELETE FROM layer_groups             WHERE id           IN (#{id_list})")

    Rails.logger.info "#{self.class.name}: Removed #{all_ids.length} old layer group(s) under Degradation."
  end

  # Inserts a new layer_group record and returns its id.
  def insert_layer_group(super_group_id:, slug:, layer_group_type:, order:, now:)
    order_sql = order.nil? ? "NULL" : order.to_s
    result = execute(<<-SQL.squish).first
      INSERT INTO layer_groups
        (super_group_id, slug, layer_group_type, category, active, "order",
         icon_class, site_scope_id, created_at, updated_at)
      VALUES
        (#{super_group_id}, '#{slug}', '#{layer_group_type}', NULL, false,
         #{order_sql}, NULL, 1, '#{now}', '#{now}')
      RETURNING id
    SQL
    result["id"].to_i
  end

  # Re-inserts an old layer_group with its original seed id; does nothing if
  # the record already exists (e.g. migration run twice).
  def restore_layer_group(id:, super_group_id:, layer_group_type:, order:, now:)
    order_sql = order.nil? ? "NULL" : order.to_s
    execute(<<-SQL.squish)
      INSERT INTO layer_groups
        (id, super_group_id, slug, layer_group_type, category, active, "order",
         icon_class, site_scope_id, created_at, updated_at)
      VALUES
        (#{id}, #{super_group_id}, '', '#{layer_group_type}', NULL, false,
         #{order_sql}, NULL, 1, '#{now}', '#{now}')
      ON CONFLICT (id) DO NOTHING
    SQL
    id
  end

  # Inserts or updates the English translation for a layer_group.
  def upsert_translation(layer_group_id, name, info, now)
    safe_name = name.gsub("'", "''")
    info_sql = info.nil? ? "NULL" : "'#{info.gsub("'", "''")}'"
    execute(<<-SQL.squish)
      INSERT INTO layer_group_translations
        (layer_group_id, locale, name, info, created_at, updated_at)
      VALUES
        (#{layer_group_id}, 'en', '#{safe_name}', #{info_sql}, '#{now}', '#{now}')
      ON CONFLICT (layer_group_id, locale) DO UPDATE
        SET name = EXCLUDED.name, info = EXCLUDED.info, updated_at = EXCLUDED.updated_at
    SQL
  end

  # Copies all layers from a Trends.Earth layer group into the target group
  # by creating new agrupations in the main site scope.
  def add_layers_from_te_group(te_slug, te_scope_id, target_group_id)
    te_group = execute(<<-SQL.squish).first
      SELECT id FROM layer_groups
      WHERE slug = '#{te_slug}' AND site_scope_id = #{te_scope_id}
      LIMIT 1
    SQL

    unless te_group
      Rails.logger.warn "#{self.class.name}: TE group '#{te_slug}' not found. Skipping."
      return
    end

    te_group_id = te_group["id"].to_i
    layer_ids = execute(<<-SQL.squish).map { |r| r["layer_id"].to_i }
      SELECT layer_id FROM agrupations WHERE layer_group_id = #{te_group_id}
    SQL

    if layer_ids.empty?
      Rails.logger.info "#{self.class.name}: TE group '#{te_slug}' has no layers."
      return
    end

    layer_ids.each { |lid| insert_agrupation_if_missing(lid, target_group_id) }

    Rails.logger.info "#{self.class.name}: Linked #{layer_ids.length} layer(s) from " \
                      "TE '#{te_slug}' → group #{target_group_id}."
  end

  # Inserts an agrupation only when it does not already exist (no DB-level
  # unique constraint on the pair, so we guard with a SELECT first).
  def insert_agrupation_if_missing(layer_id, layer_group_id)
    exists = execute(<<-SQL.squish).first
      SELECT 1 FROM agrupations
      WHERE layer_id = #{layer_id} AND layer_group_id = #{layer_group_id}
      LIMIT 1
    SQL
    return if exists

    execute(<<-SQL.squish)
      INSERT INTO agrupations (layer_id, layer_group_id, active)
      VALUES (#{layer_id}, #{layer_group_id}, false)
    SQL
  end
end
