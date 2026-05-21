# frozen_string_literal: true

# Wraps the GA4 Data API (google-analytics-data gem).
#
# Required environment variables:
#   GA4_PROPERTY_ID                    — numeric GA4 property ID (e.g. "123456789")
#   GOOGLE_APPLICATION_CREDENTIALS_JSON — service account JSON as a single string
#
# The service account must have "Viewer" access in GA4 Admin → Property Access Management.
class GoogleAnalyticsService
  CACHE_TTL = 5.minutes

  def initialize
    @property_id = ENV["GA4_PROPERTY_ID"]
    @credentials_json = ENV["GOOGLE_APPLICATION_CREDENTIALS_JSON"]
  end

  def configured?
    @property_id.present? && @credentials_json.present?
  end

  # Deep link into the GA4 property report when the property ID is known.
  def analytics_url
    if @property_id.present?
      "https://analytics.google.com/analytics/web/#/p#{@property_id}/reports/overview"
    else
      "https://analytics.google.com"
    end
  end

  # Returns a hash with :metrics (sessions/active_users/page_views) and
  # :top_pages (array of {path:, views:}).  Results are cached for CACHE_TTL.
  # Returns nil on any error so the dashboard degrades gracefully.
  def fetch_summary(days: 30)
    return nil unless configured?

    Rails.cache.fetch("google_analytics_summary_#{days}d", expires_in: CACHE_TTL) do
      call_api(days: days)
    end
  rescue => e
    Rails.logger.error("GoogleAnalyticsService#fetch_summary failed: #{e.class}: #{e.message}")
    nil
  end

  private

  def call_api(days:)
    require "google/analytics/data"

    credentials = JSON.parse(@credentials_json)

    client = Google::Analytics::Data::V1beta::AnalyticsData::Client.new do |config|
      config.credentials = credentials
    end

    property = "properties/#{@property_id}"
    date_range = {start_date: "#{days}daysAgo", end_date: "today"}

    summary = client.run_report(
      property: property,
      date_ranges: [date_range],
      metrics: [
        {name: "sessions"},
        {name: "activeUsers"},
        {name: "screenPageViews"}
      ]
    )

    pages = client.run_report(
      property: property,
      date_ranges: [date_range],
      dimensions: [{name: "pagePath"}],
      metrics: [{name: "screenPageViews"}],
      order_bys: [{metric: {metric_name: "screenPageViews"}, desc: true}],
      limit: 10
    )

    row = summary.rows&.first
    metrics = if row
      {
        sessions: row.metric_values[0].value.to_i,
        active_users: row.metric_values[1].value.to_i,
        page_views: row.metric_values[2].value.to_i
      }
    else
      {sessions: 0, active_users: 0, page_views: 0}
    end

    top_pages = pages.rows&.map { |r|
      {path: r.dimension_values[0].value, views: r.metric_values[0].value.to_i}
    } || []

    {metrics: metrics, top_pages: top_pages, fetched_at: Time.current}
  end
end
