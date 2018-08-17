namespace :map_menu_entry do
  task create: :environment do
    gef = MapMenuEntry.create! label: 'GEF-funded Projects', position: 1
    country = MapMenuEntry.create! label: 'Country Atlases', position: 2
    vital = MapMenuEntry.create! label: 'Vital Signs', position: 3
    regions = MapMenuEntry.create! label: 'Regions', position: 4
    themes = MapMenuEntry.create! label: 'Themes', position: 5

    MapMenuEntry.create! label: 'Trends.Earth',
                         link: 'https://maps.trends.earth/map',
                         position: 1, parent: gef
    MapMenuEntry.create! label: 'GEF-IAP-Food Security',
                         link: 'https://foodsecurityiap.resilienceatlas.org/map',
                         position: 2, parent: gef

    MapMenuEntry.create! label: 'Madagascar',
                         link: 'https://madagascar.resilienceatlas.org/map',
                         position: 1, parent: country
    MapMenuEntry.create! label: 'South Africa',
                         link: 'https://southafrica.resilienceatlas.org/map',
                         position: 2, parent: country
    MapMenuEntry.create! label: 'Indonesia',
                         link: 'https://indonesia.resilienceatlas.org/map',
                         position: 3, parent: country
    MapMenuEntry.create! label: 'Ethiopia',
                         link: 'https://ethiopia.resilienceatlas.org/map',
                         position: 4, parent: country
    MapMenuEntry.create! label: 'Democratic Republic of Congo',
                         link: 'https://drc.resilienceatlas.org/map',
                         position: 5, parent: country


    MapMenuEntry.create! label: 'Ghana',
                         link: 'http://ghana.vitalsigns.org/explore-atlas-ghana',
                         position: 1, parent: vital
    MapMenuEntry.create! label: 'Rwanda',
                         link: 'http://rwanda.vitalsigns.org/explore-atlas-rwanda',
                         position: 2, parent: vital
    MapMenuEntry.create! label: 'Tanzania',
                         link: 'http://tanzania.vitalsigns.org/explore-atlas-tanzania',
                         position: 3, parent: vital
    MapMenuEntry.create! label: 'Uganda',
                         link: 'http://uganda.vitalsigns.org/explore-atlas-uganda',
                         position: 4, parent: vital
    MapMenuEntry.create! label: 'Indicators',
                         link: 'https://indicators.resilienceatlas.org/map',
                         position: 5, parent: vital
    MapMenuEntry.create! label: 'DSSG',
                         link: 'https://dssg.resilienceatlas.org/map',
                         position: 6, parent: vital

    MapMenuEntry.create! label: 'Africa',
                         link: 'https://africa.resilienceatlas.org/map',
                         position: 1, parent: regions
    MapMenuEntry.create! label: 'Asia',
                         link: 'https://asia.resilienceatlas.org/map',
                         position: 2, parent: regions
    MapMenuEntry.create! label: 'Amazonia',
                         link: 'https://amazonia.resilienceatlas.org/map',
                         position: 3, parent: regions

    MapMenuEntry.create! label: 'Prioritization',
                         link: 'https://prioritization.resilienceatlas.org/map',
                         position: 1, parent: regions
    MapMenuEntry.create! label: 'Intensification',
                         link: 'https://intensification.resilienceatlas.org/map',
                         position: 2, parent: regions
  end
end
