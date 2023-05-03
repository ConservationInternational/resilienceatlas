# simple_streamlit_app.py
import os
from pathlib import Path
from typing import List
import streamlit as st
import palettable
import logging
import streamlit.logger
import requests
from folium import Map, LayerControl, Marker
from folium.raster_layers import TileLayer
from folium.plugins import Draw
from streamlit_folium import st_folium

# Then set our logger in a normal way
logging.basicConfig(
    level=logging.DEBUG,
    format=" %(name)s :: %(levelname)-8s :: [%(filename)s:%(lineno)d] :: %(message)s",
    force=True,
)  # Change these settings for your own purpose, but keep force=True at least.

streamlit_handler = logging.getLogger("streamlit")
streamlit_handler.setLevel(logging.INFO)


def create_map(center: List[float], zoom: int) -> Map:
    m = Map(
        location=center,
        zoom_start=zoom,
        control_scale=True,
        tiles="https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        attr='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',  # noqa: E501
    )
    Draw(
        export=False,
        position="topleft",
        draw_options={
            "polyline": False,
            "poly": False,
            "circle": False,
            "polygon": True,
            "marker": False,
            "circlemarker": False,
            "rectangle": True,
        },
    ).add_to(m)

    return m


def setup_layer(data_path):
    logging.info("Setting up layer")
    logging.info(data_path.name)
    logging.info(str(data_path.exists()))
    # url = f"http://localhost:8080/tiles/cog/tiles/{{z}}/{{x}}/{{y}}.png?url=/usr/src/app/data/processed/{data_path.name}"
    url = f"http://localhost:8080/tiles/cog/tiles/{{z}}/{{x}}/{{y}}.png?url=https://resilience-atlas.s3.amazonaws.com/cog/globcover_cog_test.tif"
    return TileLayer(
        tiles=url,
        attr=" asdf ad",
        name="test",
        overlay=True,
        control=True,
        show=True,
    )


def on_data_loaded(m: Map, map_container):
    palette = st.session_state.get("color_palette", "Blues_r")
    layer_data = Path(st.session_state.data_list)
    with map_container:
        map_container.empty()
        Marker(location=(30, 20), popup="test").add_to(m)
        layer = setup_layer(layer_data)
        layer.add_to(m)
        LayerControl().add_to(m)
        return st_folium(m, key="init", width=1300, height=600)


@st.cache_data
def load_cog_list():
    current_dir = Path(os.getcwd())
    data_path = "data/processed"
    child = current_dir.joinpath(data_path).glob("./*.tif")
    return [x for x in child if x.is_file()]


@st.cache_data
def get_palettes():
    palettes = dir(palettable.matplotlib)[:-16]
    return ["matplotlib." + p for p in palettes]


def app():
    m = create_map(center=[25.0, 55.0], zoom=3)
    cog_list = load_cog_list()
    palletes = get_palettes()

    st.title("Visualize Raster Datasets")
    st.markdown(
        """
    An interactive web app for visualizing local raster datasets and Cloud Optimized GeoTIFF ([COG](https://www.cogeo.org)). The app was built using [streamlit](https://streamlit.io), [leafmap](https://leafmap.org), and [localtileserver](https://github.com/banesullivan/localtileserver).
    """
    )
    try:
        with st.sidebar:
            with st.form("my_form", clear_on_submit=False):
                st.selectbox(
                    "Select a sample Cloud Opitmized GeoTIFF (COG)",
                    cog_list,
                    key="data_list",
                )
                st.selectbox("Select a color palette", palletes, key="color_palette")
                # Every form must have a submit button.
                st.form_submit_button("Submit")

            # ensure progress bar resides at top of sidebar and is invisible initially
            progress_bar = st.progress(0)
            progress_bar.empty()
            # Create an empty container for the plotly figure
            text_container = st.empty()

            # Create an empty container for the plotly figure
            fig_container = st.empty()

        with st.container():
            map_container = st.empty()

            output = on_data_loaded(m, map_container)

        geojson = None
        if output["all_drawings"] is not None:
            if len(output["all_drawings"]) != 0:
                if output["last_active_drawing"] is not None:
                    # get latest modified drawing
                    geojson = output["last_active_drawing"]
                    logging.info(geojson)

    except Exception as e:
        logging.exception(e)
        pass


app()
