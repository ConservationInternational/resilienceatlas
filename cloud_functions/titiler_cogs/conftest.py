"""Root conftest.py – adds the project root to sys.path so that the
``titiler_cogs`` package is importable when running pytest from
``cloud_functions/titiler_cogs/``.
"""
import sys
import os

# Ensure the directory that CONTAINS the titiler_cogs package is on sys.path.
# Directory layout:
#   cloud_functions/titiler_cogs/        ← project root (this file lives here)
#     titiler_cogs/                      ← importable Python package
#       __init__.py
#       app.py
sys.path.insert(0, os.path.dirname(__file__))
