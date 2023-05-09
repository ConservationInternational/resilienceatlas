from pathlib import Path
from typing import List, Optional
from pydantic import BaseModel
from folium import TileLayer



class Category(BaseModel):
    name: str
    color: str
    description: Optional[str] = None
    icon: Optional[str] = None


class RasterData(BaseModel):
    dataset: str
    source: Path
    band: str
    category_map: List[Category]

    def legend(self):
        return [
            {"name": c.name, "color": c.color, "description": c.description}
            for c in self.category_map
        ]

    def color_map(self):
        return {c.name: c.color for c in self.category_map}


    def tile_url(self):




    def layer(self):
        return TileLayer(
            tiles=self.source,
            attr=self.dataset,
            name=self.dataset,
            overlay=True,
            control=True,
            opacity=1,
        )
