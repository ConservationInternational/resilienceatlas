resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

// IP address
resource "google_compute_global_address" "ip_address" {
  name         = "${var.name}-lb"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

# ------------------------------------------------------------------------------
# Load balancer config rules
# ------------------------------------------------------------------------------

# HTTPS + certificate handling
resource "google_compute_global_forwarding_rule" "load-balancer-forwarding-rule-https" {
  name                  = "${var.name}-lb-forwarding-rule-https"
  target                = google_compute_target_https_proxy.load-balancer-https-proxy.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.ip_address.address
}

resource "google_compute_target_https_proxy" "load-balancer-https-proxy" {
  name             = "${var.name}-lb-https-proxy"
  url_map          = google_compute_url_map.load-balancer-url-map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.load-balancer-certificate.id]
}

resource "google_compute_managed_ssl_certificate" "load-balancer-certificate" {
  name = "${var.name}-lb-cert"

  managed {
    domains = [
      "histogram.${var.domain}",
      "downloadimage.${var.domain}",
      "rasterinteraction.${var.domain}"
    ]
  }
}

# HTTP redirection to HTTPS
resource "google_compute_url_map" "http-redirect" {
  name = "${var.name}-http-redirect"

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"  // 301 redirect
    strip_query            = false
    https_redirect         = true  // this is the magic
  }
}

resource "google_compute_target_http_proxy" "http-redirect" {
  name    = "${var.name}-http-redirect"
  url_map = google_compute_url_map.http-redirect.self_link
}

resource "google_compute_global_forwarding_rule" "http-redirect" {
  name       = "${var.name}-http-redirect"
  target     = google_compute_target_http_proxy.http-redirect.self_link
  ip_address = google_compute_global_address.ip_address.address
  port_range = "80"
}

# ------------------------------------------------------------------------------
# Load balancer core (URL mapping)
# ------------------------------------------------------------------------------
resource "google_compute_url_map" "load-balancer-url-map" {
  name        = "${var.name}-lb"
  description = "Load balancer for ${var.name}"

  default_url_redirect {
    https_redirect = true
    host_redirect  = var.domain
    strip_query    = true
  }

  host_rule {
    hosts        = ["histogram.${var.domain}"]
    path_matcher = "histogram"
  }

  path_matcher {
    name            = "histogram"
    default_service = google_compute_backend_service.histogram_service.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.histogram_service.id
    }
  }

  host_rule {
    hosts        = ["downloadimage.${var.domain}"]
    path_matcher = "downloadimage"
  }

  path_matcher {
    name            = "downloadimage"
    default_service = google_compute_backend_service.download_image_service.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.download_image_service.id
    }
  }

  host_rule {
    hosts        = ["rasterinteraction.${var.domain}"]
    path_matcher = "rasterinteraction"
  }

  path_matcher {
    name            = "rasterinteraction"
    default_service = google_compute_backend_service.raster_interaction_service.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.raster_interaction_service.id
    }
  }
}

resource "google_compute_region_network_endpoint_group" "cloudrun_histogram_neg" {
  name                  = "${var.name}-histogram-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = var.histogram_service_name
  }
}

resource "google_compute_region_network_endpoint_group" "cloudrun_download_image_neg" {
  name                  = "${var.name}-download-image-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = var.download_image_service_name
  }
}

resource "google_compute_region_network_endpoint_group" "cloudrun_raster_interaction_neg" {
  name                  = "${var.name}-raster-interaction-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = var.raster_interaction_service_name
  }
}

resource "google_compute_backend_service" "histogram_service" {
  name        = "${var.name}-histogram-service"
  description = "${var.name} histogram service"

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_histogram_neg.id
  }
}

resource "google_compute_backend_service" "download_image_service" {
  name        = "${var.name}-download-image-service"
  description = "${var.name} download_image service"

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_download_image_neg.id
  }
}

resource "google_compute_backend_service" "raster_interaction_service" {
  name        = "${var.name}-raster-interaction-service"
  description = "${var.name} raster_interaction service"

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_raster_interaction_neg.id
  }
}
