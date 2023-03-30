# == Schema Information
#
# Table name: agrupations
#
#  id             :bigint           not null, primary key
#  layer_id       :bigint
#  layer_group_id :bigint
#  active         :boolean          default(FALSE)
#
FactoryBot.define do
  factory :agrupation do
    layer
    layer_group
  end
end
