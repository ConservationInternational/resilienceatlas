# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :inet
#  last_sign_in_ip        :inet
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  first_name             :string
#  last_name              :string
#  phone                  :string
#  organization           :string
#  organization_role      :string
#

require 'rails_helper'

RSpec.describe User, type: :model do
  let!(:user) { create :user }

  it 'User is valid' do
    expect(user).to       be_valid
    expect(user.email).to be_present
  end

  it 'Count users' do
    expect(User.count).to eq(1)
  end
end
