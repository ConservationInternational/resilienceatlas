function initializeSpatialUpload() {
  const root = document.getElementById("spatial-upload");
  if (!root || root.dataset.initialized) return;
  root.dataset.initialized = "true";
  const el = (name) => document.getElementById(`upload-${name}`);
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
  const base = root.dataset.sessionsUrl;
  const multipart = root.dataset.multipartUrl;
  const chunkSize = 16 * 1024 * 1024;
  let session;
  let activeRequest;
  let cancelled = false;
  let timer;
  let previewMessage;
  let previewReady = false;
  let previewTimer;
  let transferring = false;

  async function json(url, method = "GET", data) {
    const response = await fetch(url, {
      method, credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf, "X-Requested-With": "XMLHttpRequest" },
      body: data === undefined ? undefined : JSON.stringify(data)
    });
    if (!response.headers.get("content-type")?.includes("application/json")) {
      throw new Error("The server did not return JSON. Your admin session may have expired; sign in and reopen this upload.");
    }
    const body = await response.json();
    if (!response.ok) throw new Error(body.error || `Request failed (${response.status})`);
    return body;
  }

  function failure(error) {
    el("error").textContent = error.message;
    el("transfer").disabled = false;
  }

  function render() {
    const openingConfiguration = el("configure").hidden && ["ready", "needs_input", "failed"].includes(session.status);
    el("status").textContent = `${session.stage || session.status} (upload #${session.id})`;
    el("error").textContent = session.error || "";
    el("metadata").textContent = JSON.stringify(session.metadata, null, 2);
    el("configure").hidden = !["ready", "needs_input", "failed"].includes(session.status);
    el("cancel").hidden = ["cancelled", "complete"].includes(session.status);
    el("retry").hidden = !["failed", "needs_input"].includes(session.status);
    el("start").hidden = !["uploading"].includes(session.status);
    el("rollback").hidden = !session.rollback_available;
    el("vector-options").hidden = session.import_type !== "vector";
    el("raster-options").hidden = session.import_type !== "cog";
    if (openingConfiguration) {
      for (const [key, id] of [["name", "name"], ["slug", "slug"], ["source_crs", "crs"], ["sublayer", "sublayer"],
        ["raster_kind", "raster-kind"], ["bidx", "bands"], ["rescale", "rescale"], ["nodata", "nodata"],
        ["colormap_name", "colormap"], ["legend", "legend"], ["color", "color"]]) {
        if (session.options[key] !== undefined) el(id).value = session.options[key];
      }
      const configuration = session.configuration;
      const inheritedPopup = configuration ? JSON.parse(configuration.interaction_config).output.map((field) => field.column) : session.metadata.fields || [];
      el("popup").value = (session.options.popup_fields || inheritedPopup).join(", ");
      if (configuration && session.import_type === "cog") {
        const body = JSON.parse(configuration.layer_config).body;
        for (const [key, id] of [["bidx", "bands"], ["rescale", "rescale"], ["nodata", "nodata"], ["colormap_name", "colormap"]]) {
          if (body[key] != null) el(id).value = body[key];
        }
        if (body.colormap) el("colormap-json").value = JSON.stringify(body.colormap);
      }
    }
    el("sublayers").replaceChildren();
    for (const layer of session.metadata.sublayers || []) {
      const option = document.createElement("option");
      option.value = typeof layer === "string" ? layer : layer.name;
      el("sublayers").append(option);
    }
    if (session.layer_url && session.status === "complete") {
      el("layer-link").href = session.layer_url;
      el("layer-link").textContent = "Open saved layer";
      el("layer-link").hidden = false;
    }
    if (["pending", "processing"].includes(session.status)) {
      clearTimeout(timer);
      timer = setTimeout(() => refresh().catch(failure), 2000);
    }
  }

  async function refresh() {
    session = await json(`${base}/${session.id}`);
    render();
  }

  async function action(name, data = {}) {
    session = await json(`${base}/${session.id}/${name}`, name === "configure" ? "PATCH" : "POST", data);
    render();
    return session;
  }

  function putPart(url, blob, offset, total) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      activeRequest = xhr;
      xhr.open("PUT", url);
      xhr.upload.onprogress = (event) => {
        el("progress").value = Math.round((offset + event.loaded) / total * 100);
        el("status").textContent = `${Math.min(offset + event.loaded, total).toLocaleString()} / ${total.toLocaleString()} bytes transferred`;
      };
      xhr.onload = () => {
        const etag = xhr.getResponseHeader("ETag");
        if (xhr.status >= 200 && xhr.status < 300 && etag) resolve(etag);
        else reject(new Error(`Part upload failed (${xhr.status}). Verify S3 CORS exposes ETag, then resume.`));
      };
      xhr.onerror = () => reject(new Error("Part upload interrupted. Reselect the same file and resume."));
      xhr.onabort = () => reject(new Error("Transfer stopped."));
      xhr.send(blob);
    });
  }

  el("type").addEventListener("change", () => {
    el("file").accept = el("type").value === "vector" ? ".gpkg,.geojson,.json,.zip" : ".tif,.tiff";
  });
  el("type").dispatchEvent(new Event("change"));
  el("start").addEventListener("submit", async (event) => {
    event.preventDefault();
    if (transferring) return;
    transferring = true;
    el("transfer").disabled = true;
    el("error").textContent = "";
    cancelled = false;
    try {
      const file = el("file").files[0];
      if (!file) throw new Error("Choose a file.");
      if (!session) {
        session = await json(base, "POST", {
          import_type: el("type").value, mode: el("mode").value, layer_id: root.dataset.layerId,
          name: el("name").value, slug: el("slug").value, file_name: file.name, file_size_bytes: file.size
        });
        const url = new URL(window.location.href);
        url.searchParams.set("resume", session.id);
        window.history.replaceState({}, "", url);
      }
      if (session.file_name !== file.name || session.file_size_bytes !== file.size) {
        throw new Error("This session belongs to a different file. Cancel it and start a new upload.");
      }
      if (session.metadata.transferred) {
        await action("process_file");
        return;
      }
      // Fingerprint includes file contents at both ends; a resumed transfer must match.
      const bytes = new Uint8Array(await new Blob([file.slice(0, 65536), file.slice(-65536)]).arrayBuffer());
      const hash = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))).map((b) => b.toString(16).padStart(2, "0")).join("");
      const fingerprintKey = `atlas-upload-${session.id}`;
      const fingerprint = localStorage.getItem(fingerprintKey);
      if (fingerprint && fingerprint !== hash) throw new Error("Reselected file does not match the original file.");
      localStorage.setItem(fingerprintKey, hash);
      const upload = await json(multipart, "POST", {
        filename: file.name, type: file.type || "application/octet-stream",
        metadata: { session_id: session.id, size: file.size, prefix: "staging" }
      });
      render();
      el("start").hidden = false;
      const query = `?key=${encodeURIComponent(upload.key)}`;
      const uploaded = await json(`${multipart}/${encodeURIComponent(upload.uploadId)}${query}&list=1`);
      const existing = new Map(uploaded.parts.map((part) => [part.PartNumber, part]));
      const parts = [];
      for (let offset = 0, number = 1; offset < file.size; offset += chunkSize, number++) {
        if (cancelled) return;
        const end = Math.min(file.size, offset + chunkSize);
          const previous = existing.get(number);
          const chunk = file.slice(offset, end);
          const digest = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", await chunk.arrayBuffer())))
            .map((byte) => byte.toString(16).padStart(2, "0")).join("");
          const partKey = `${fingerprintKey}-part-${number}`;
          const originalDigest = localStorage.getItem(partKey);
          if (previous && originalDigest !== digest) {
            throw new Error("Cannot safely resume: this part differs from the original file, or this browser has no saved fingerprint. Cancel and restart.");
          }
          localStorage.setItem(partKey, digest);
          let etag = previous?.Size === end - offset ? previous.ETag : null;
        if (!etag) {
          for (let attempt = 0; attempt < 3; attempt++) {
            try {
              const signed = await json(`${multipart}/${encodeURIComponent(upload.uploadId)}${query}&partNumbers[]=${number}`);
              etag = await putPart(signed.presignedUrls[number], chunk, offset, file.size);
              break;
            } catch (error) {
              if (cancelled || attempt === 2) throw error;
              await new Promise((resolve) => setTimeout(resolve, 1000 * (attempt + 1)));
            }
          }
        }
        parts.push({ PartNumber: number, ETag: etag });
        el("progress").value = end / file.size * 100;
      }
      if (cancelled) return;
      await json(`${multipart}/${encodeURIComponent(upload.uploadId)}/complete`, "POST", { key: upload.key, parts });
      await action("process_file");
    } catch (error) { failure(error); }
    finally { transferring = false; el("transfer").disabled = false; }
  });

  el("cancel").addEventListener("click", async () => {
    if (!window.confirm("Cancel this upload? The current live layer will not change.")) return;
    cancelled = true;
    activeRequest?.abort();
    clearTimeout(timer);
    try { await action("cancel"); } catch (error) { failure(error); }
  });
  el("retry").addEventListener("click", () => action("process_file").catch(failure));

  async function preview() {
    previewMessage = {
      type: "LAYER_PREVIEW", provider: session.configuration.layer_provider,
      layer_config: session.configuration.layer_config, bounds: session.metadata.bounds
    };
    el("preview").hidden = false;
    el("confirm").checked = false;
    const url = new URL(root.dataset.previewUrl);
    url.searchParams.set("adminOrigin", window.location.origin);
    if (el("map").src !== url.toString()) {
      previewReady = false;
      el("map").src = url.toString();
    } else {
      el("map").contentWindow.postMessage(previewMessage, url.origin);
    }
    el("confirm").disabled = !previewReady;
    clearTimeout(previewTimer);
    if (!previewReady) {
      previewTimer = setTimeout(() => failure(new Error("The frontend map preview did not start. Check FRONTEND_URL and frontend availability, then reload.")), 15000);
    }
    el("sample").textContent = "Loading the map application preview. Do not confirm until the layer renders.";
    await action("verify");
  }

  window.addEventListener("message", async (event) => {
    if (event.origin !== new URL(root.dataset.previewUrl).origin || event.source !== el("map").contentWindow) return;
    try {
      if (event.data?.type === "LAYER_PREVIEW_READY" && previewMessage) {
        previewReady = true;
        clearTimeout(previewTimer);
        el("confirm").disabled = false;
        el("map").contentWindow.postMessage(previewMessage, event.origin);
      } else if (event.data?.type === "LAYER_PREVIEW_ERROR") {
        previewReady = false;
        el("confirm").disabled = true;
        failure(new Error(event.data.message || "The map preview failed."));
      } else if (event.data?.type === "LAYER_PREVIEW_SAMPLE" && session) {
        if (session.import_type === "vector") {
          const properties = event.data.properties || {};
          const selected = session.options.popup_fields;
          el("sample").textContent = JSON.stringify(selected ? Object.fromEntries(Object.entries(properties).filter(([key]) => selected.includes(key))) : properties, null, 2);
        } else {
          const [lon, lat] = event.data.coordinate;
          el("sample").textContent = JSON.stringify(await json(`${base}/${session.id}/point?lon=${lon}&lat=${lat}`), null, 2);
        }
      }
    } catch (error) { failure(error); }
  });

  el("configure").addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      const config = {
        name: el("name").value || session.options.name,
        slug: el("slug").value || session.options.slug,
        source_crs: el("crs").value, sublayer: el("sublayer").value,
        raster_kind: el("raster-kind").value, color: el("color").value, replace_style: el("replace-style").checked,
        popup_fields: el("popup").value.split(",").map((value) => value.trim()).filter(Boolean)
      };
      if (session.import_type === "cog") {
        for (const [key, id] of [["bidx", "bands"], ["rescale", "rescale"], ["nodata", "nodata"], ["colormap_name", "colormap"]]) {
          config[key] = el(id).value;
        }
        config.colormap = el("colormap-json").value;
      }
      if (el("legend").value) config.legend = el("legend").value;
      const reprocess = session.status !== "ready" || config.source_crs !== (session.options.source_crs || "") ||
        config.sublayer !== (session.options.sublayer || "") || config.raster_kind !== (session.options.raster_kind || "continuous");
      await action("configure", config);
      if (reprocess) await action("process_file");
      else await preview();
    } catch (error) { failure(error); }
  });
  el("finalize").addEventListener("click", async () => {
    try {
      if (!el("confirm").checked) throw new Error("Review the preview and confirm before saving.");
      if (!previewReady) throw new Error("Wait for a working map preview before saving.");
      await action("finalize");
      el("preview").hidden = true;
    } catch (error) { failure(error); }
  });
  el("rollback").addEventListener("click", async () => {
    if (!window.confirm("Restore the previous source and configuration?")) return;
    try { await action("rollback"); } catch (error) { failure(error); }
  });
  if (root.dataset.resume) {
    session = { id: root.dataset.resume };
    refresh().then(() => {
      for (const [key, id] of [["name", "name"], ["slug", "slug"], ["source_crs", "crs"], ["sublayer", "sublayer"],
        ["raster_kind", "raster-kind"], ["bidx", "bands"], ["rescale", "rescale"], ["nodata", "nodata"],
        ["colormap_name", "colormap"], ["legend", "legend"], ["color", "color"]]) {
        if (session.options[key] !== undefined) el(id).value = session.options[key];
      }
      el("type").value = session.import_type;
      el("type").dispatchEvent(new Event("change"));
      if (session.options.popup_fields) el("popup").value = session.options.popup_fields.join(", ");
    }).catch(failure);
  }
  window.addEventListener("pagehide", () => { clearTimeout(timer); clearTimeout(previewTimer); activeRequest?.abort(); }, { once: true });
}

document.addEventListener("DOMContentLoaded", initializeSpatialUpload);
document.addEventListener("turbo:load", initializeSpatialUpload);
document.addEventListener("turbolinks:load", initializeSpatialUpload);
if (document.readyState !== "loading") initializeSpatialUpload();
