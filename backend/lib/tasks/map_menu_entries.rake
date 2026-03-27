namespace :map_menu_entry do
  task create: :environment do
    gef = MapMenuEntry.create! label: "GEF-funded Projects", position: 1
    country = MapMenuEntry.create! label: "Country Atlases", position: 2
    regions = MapMenuEntry.create! label: "Regions", position: 3
    _themes = MapMenuEntry.create! label: "Themes", position: 4

    MapMenuEntry.create! label: "Trends.Earth",
      link: "https://maps.trends.earth/map",
      position: 1, parent: gef
    MapMenuEntry.create! label: "GEF-IAP-Food Security",
      link: "https://foodsecurityiap.resilienceatlas.org/map",
      position: 2, parent: gef

    MapMenuEntry.create! label: "Madagascar",
      link: "https://madagascar.resilienceatlas.org/map",
      position: 1, parent: country
    MapMenuEntry.create! label: "South Africa",
      link: "https://southafrica.resilienceatlas.org/map",
      position: 2, parent: country
    MapMenuEntry.create! label: "Indonesia",
      link: "https://indonesia.resilienceatlas.org/map",
      position: 3, parent: country
    MapMenuEntry.create! label: "Ethiopia",
      link: "https://ethiopia.resilienceatlas.org/map",
      position: 4, parent: country
    MapMenuEntry.create! label: "Democratic Republic of Congo",
      link: "https://drc.resilienceatlas.org/map",
      position: 5, parent: country

    MapMenuEntry.create! label: "Africa",
      link: "https://africa.resilienceatlas.org/map",
      position: 1, parent: regions
    MapMenuEntry.create! label: "Asia",
      link: "https://asia.resilienceatlas.org/map",
      position: 2, parent: regions
    MapMenuEntry.create! label: "Amazonia",
      link: "https://amazonia.resilienceatlas.org/map",
      position: 3, parent: regions

    MapMenuEntry.create! label: "Prioritization",
      link: "https://prioritization.resilienceatlas.org/map",
      position: 1, parent: regions
    MapMenuEntry.create! label: "Intensification",
      link: "https://intensification.resilienceatlas.org/map",
      position: 2, parent: regions
  end
end
