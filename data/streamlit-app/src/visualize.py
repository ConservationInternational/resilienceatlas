from typing import List
from folium import Map, LayerControl
from folium.plugins import Draw
from localtileserver import get_folium_tile_layer, TileClient
import pandas as pd
from plotly import express as px

from .data import RasterData


def create_map(
    center: List[float], zoom: int, layers: List[RasterData], controls: bool = False
) -> folium.Map:
    m = folium.Map(
        location=center,
        zoom_start=zoom,
        control_scale=True,
        tiles="https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png",
        attr='Map data: &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, <a href="http://viewfinderpanoramas.org">SRTM</a> | Map style: &copy; <a href="https://opentopomap.org">OpenTopoMap</a> (<a href="https://creativecommons.org/licenses/by-sa/3.0/">CC-BY-SA</a>)',  # noqa: E501
    )
    draw = Draw(
        export=False,
        position="topleft",
        draw_options={
            "polyline": False,
            "poly": False,
            "circle": False,
            "polygon": False,
            "marker": False,
            "circlemarker": False,
            "rectangle": True,
        },
    )
    draw.add_to(m)

    for layer in layers:
        layer.add_to(m)

    if controls:
        control = LayerControl(position="topright")
        control.add_to(m)

    return m


def create_stacked_bar(values, colors):
    # create a DataFrame with the items of the values dictionary
    df = pd.DataFrame(list(values.items()), columns=["label", "value"])
    df["y_axis"] = " "

    # create a horizontal bar chart for each category
    fig = px.bar(
        df,
        y="y_axis",
        x="value",
        color="label",
        color_discrete_map=colors,
        hover_data={"y_axis": False, "value": ":,.2f", "label": True},
    )

    fig.update_layout(title="Summary Metrics", showlegend=False, height=200, width=800)

    # remove x and y axis titles and x-axis tick labels
    fig.update_xaxes(title=None, showticklabels=False)
    fig.update_yaxes(title=None)

    return fig
