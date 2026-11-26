class RefreshVectorTileEncoding < ActiveRecord::Migration[8.1]
  def up
    Layer.where(layer_provider: "martin").in_batches(of: 100) do |batch|
      TilePolicyLifecycle.refresh!(batch.to_a, reason: "vector_tile_binary_encoding_changed")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Do not restore cached text-encoded vector tiles"
  end
end
