unless AdminUser.exists?(email: "admin@cigrm.com")
  AdminUser.create!(email: "admin@cigrm.com", password: "c1grm.pass", password_confirmation: "c1grm.pass")
end
if SiteScope.all.size == 0
  SiteScope.create!(name: "CIGRP", id: 1, header_theme: "Resilience")
  SiteScope.create!(name: "VS Indicators", id: 2, header_theme: "Indicators")
  SiteScope.create!(name: "VS Tanzania", id: 3, header_theme: "Tanzania")
  SiteScope.create!(name: "VS Ghana", id: 4, header_theme: "Ghana")
  SiteScope.create!(name: "VS Uganda", id: 5, header_theme: "Uganda")
  SiteScope.create!(name: "VS Rwanda", id: 6, header_theme: "Rwanda")
end
