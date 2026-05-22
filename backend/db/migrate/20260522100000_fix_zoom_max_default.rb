class FixZoomMaxDefault < ActiveRecord::Migration[7.2]
  def up
    # The previous default of 100 is invalid — the model validates zoom_max <= 24.
    # Any rows with zoom_max > 24 are clamped to 24 before changing the default.
    execute "UPDATE layers SET zoom_max = 24 WHERE zoom_max > 24"
    change_column_default :layers, :zoom_max, from: 100, to: 24
  end

  def down
    change_column_default :layers, :zoom_max, from: 24, to: 100
  end
end
