# Trends.Earth Site Scope Setup

This directory contains scripts to set up the Trends.Earth site scope in Resilience Atlas with SDG 15.3.1 datasets.

## Data Sources

The layers use Cloud Optimized GeoTIFF (COG) files from Zenodo:
- **Zenodo DOI**: [10.5281/zenodo.17514520](https://doi.org/10.5281/zenodo.17514520)
- **Google Cloud Storage**: https://storage.googleapis.com/trendsearth-public/

### Available Datasets

1. **Trends.Earth** - SDG 15.3.1 calculated using Trends.Earth productivity methodology
2. **FAO-WOCAT** - SDG 15.3.1 using FAO-WOCAT Land Productivity Dynamics
3. **JRC** - SDG 15.3.1 using JRC Land Productivity Dynamics

Each dataset contains 14 bands:
- Band 1: SDG 15.3.1 for baseline (2000-2015)
- Band 2: Land Productivity Dynamics (2001-2015)
- Band 3: Land cover degradation (2000-2015)
- Band 4: Soil organic carbon degradation (2000-2015)
- Band 5-8: Same indicators for 2004-2019 period
- Band 9: SDG 15.3.1 status in 2019 vs baseline
- Band 10-13: Same indicators for 2008-2023 period
- Band 14: SDG 15.3.1 status in 2023 vs baseline

## Categories

1. **SDG Indicator 15.3.1** - Combined indicator showing land degradation
2. **Land Productivity** - Land Productivity Dynamics layers
3. **Land Cover** - Land cover degradation layers
4. **Soil Organic Carbon** - SOC change layers

## Files

| File | Description |
|------|-------------|
| `seed.rb` | Ruby ActiveRecord seed script |
| `README.md` | This documentation |

## Usage

### Option 1: Rails runner

```bash
cd backend
bundle exec rails runner db/data/trendsearth/seed.rb
```

### Option 2: Via Docker (development)

```bash
docker compose -f docker-compose.dev.yml run --rm backend \
  bundle exec rails runner db/data/trendsearth/seed.rb
```

### Option 3: Via Docker (test)

```bash
docker compose -f docker-compose.test.yml run --rm backend-test \
  bundle exec rails runner db/data/trendsearth/seed.rb
```

## Layers Created

| Category | Layer | Dataset | Band |
|----------|-------|---------|------|
| SDG Indicator 15.3.1 | SDG 15.3.1 Status 2023 | Trends.Earth | 14 |
| SDG Indicator 15.3.1 | SDG 15.3.1 Status 2023 | FAO-WOCAT | 14 |
| SDG Indicator 15.3.1 | SDG 15.3.1 Status 2023 | JRC | 14 |
| Land Productivity | LPD 2008-2023 | Trends.Earth | 11 |
| Land Productivity | LPD 2008-2023 | FAO-WOCAT | 11 |
| Land Productivity | LPD 2008-2023 | JRC | 11 |
| Land Cover | LC Degradation 2015-2023 | Trends.Earth | 12 |
| Land Cover | LC Degradation 2000-2015 | Trends.Earth | 3 |
| Soil Organic Carbon | SOC Change 2015-2023 | Trends.Earth | 13 |
| Soil Organic Carbon | SOC Change 2000-2015 | Trends.Earth | 4 |

## Prerequisites

1. TiTiler must be deployed with the `trendsearth-public` GCS bucket whitelisted:
   - Add `gs://trendsearth-public` to `TITILER_ALLOWED_BUCKETS` GitHub variable
   - Redeploy TiTiler

2. The Resilience Atlas database must be running and accessible.

## Layer Styling

Layer styles follow the Trends.Earth color conventions from:
https://github.com/ConservationInternational/trends.earth/blob/main/LDMP/data/styles.json

### Color Schemes

**SDG 15.3.1 Indicator**:
- `-1` (Degradation): `#9b2779` (magenta)
- `0` (Stable): `#ffffe0` (light yellow)
- `1` (Improvement): `#006500` (dark green)

**SDG 15.3.1 Status** (7-class):
- `1` (Degradation persistent): `#762a83`
- `2` (Degradation recent): `#af8dc3`
- `3` (Degradation baseline): `#e7d4e8`
- `4` (Stability): `#f7f7f7`
- `5` (Improvement baseline): `#d9f0d3`
- `6` (Improvement recent): `#7fbf7b`
- `7` (Improvement persistent): `#1b7837`

**Land Productivity Dynamics** (5-class):
- `1` (Declining): `#9b2779`
- `2` (Early signs of decline): `#c0749b`
- `3` (Stable but stressed): `#e1b9bd`
- `4` (Stable): `#ffffe0`
- `5` (Increasing): `#006500`
