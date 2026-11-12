/**
 * AWS Serverless ImageFlow - Responsive Image Gallery Component
 * Pure DOM construction, Blurhash visual placeholders, Copy CDN URL pills, Safe DOM.
 */

function renderGalleryView() {
  const container = document.createElement("div");

  // Section Header
  const headerCard = document.createElement("div");
  headerCard.className = "glass-card";

  const header = document.createElement("div");
  header.className = "section-header";

  const title = document.createElement("h2");
  title.className = "section-title";
  title.textContent = "Processed Images Gallery";

  const subtitle = document.createElement("p");
  subtitle.className = "section-subtitle";
  subtitle.textContent =
    "Images transformed into multiple resolutions, stored in S3, and served globally via CloudFront CDN.";

  header.appendChild(title);
  header.appendChild(subtitle);
  headerCard.appendChild(header);
  container.appendChild(headerCard);

  // Grid container
  const grid = document.createElement("div");
  grid.className = "gallery-grid";
  grid.id = "galleryGrid";

  container.appendChild(grid);

  // Fetch images from API Gateway / Mock Server
  loadGalleryItems(grid);

  return container;
}

async function loadGalleryItems(gridContainer) {
  try {
    const endpoint = `${CONFIG.apiUrl}/images?limit=20`;
    const res = await fetch(endpoint);
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    const data = await res.json();
    const images = data.images || [];

    while (gridContainer.firstChild) {
      gridContainer.removeChild(gridContainer.firstChild);
    }

    if (images.length === 0) {
      const emptyMsg = document.createElement("div");
      emptyMsg.className = "glass-card";
      emptyMsg.textContent = "No images processed yet. Navigate to 'Upload Pipeline' to process an image!";
      gridContainer.appendChild(emptyMsg);
      return;
    }

    images.forEach((img) => {
      gridContainer.appendChild(createImageCard(img));
    });
  } catch (err) {
    // If offline / local mock server not responding, display offline state cards
    loadFallbackImages(gridContainer);
  }
}

function createImageCard(img) {
  const card = document.createElement("div");
  card.className = "gallery-card";

  // Media wrapper
  const mediaWrapper = document.createElement("div");
  mediaWrapper.className = "card-media-wrapper";

  // Blurhash canvas placeholder
  const blurCanvas = document.createElement("canvas");
  blurCanvas.className = "card-blurhash";
  blurCanvas.width = 32;
  blurCanvas.height = 32;
  renderBlurhashPlaceholder(blurCanvas, img.blurhash || "L6PZfSi_.AyE");
  mediaWrapper.appendChild(blurCanvas);

  // Real image (thumbnail variant or preview)
  const variants = img.variants || [];
  const thumbKey = variants.find((v) => v.includes("thumbnail")) || variants[0] || img.original_key;
  const cdnUrl = `${CONFIG.cdnUrl}/${thumbKey}`;

  const imageEl = document.createElement("img");
  imageEl.className = "card-media-img";
  imageEl.alt = img.original_key || "Processed image";
  imageEl.loading = "lazy";
  imageEl.src = cdnUrl;

  imageEl.addEventListener("load", () => {
    imageEl.classList.add("loaded");
  });

  // Graceful fallback for local mock preview without real S3 bucket
  imageEl.addEventListener("error", () => {
    imageEl.style.display = "none";
    blurCanvas.style.filter = "none";
  });

  mediaWrapper.appendChild(imageEl);
  card.appendChild(mediaWrapper);

  // Card Body
  const body = document.createElement("div");
  body.className = "card-body";

  const meta = document.createElement("div");
  meta.className = "card-meta";

  const filename = document.createElement("div");
  filename.className = "card-filename";
  const rawName = (img.original_key || "image.jpg").split("/").pop();
  filename.textContent = rawName;

  const date = document.createElement("div");
  date.className = "card-date";
  const uploadTime = img.upload_date ? new Date(img.upload_date).toLocaleString() : "Recently uploaded";
  const sizeKb = img.file_size ? `${Math.round(img.file_size / 1024)} KB` : "Processed";
  date.textContent = `${uploadTime} • ${sizeKb}`;

  meta.appendChild(filename);
  meta.appendChild(date);
  body.appendChild(meta);

  // Variant Pills
  const variantsDiv = document.createElement("div");
  variantsDiv.className = "variants-container";

  const standardVariants = ["150x150 thumb", "400x400 prev", "800x800 web"];
  standardVariants.forEach((label) => {
    const pill = document.createElement("span");
    pill.className = "variant-pill";
    pill.textContent = label;
    variantsDiv.appendChild(pill);
  });
  body.appendChild(variantsDiv);

  // Actions
  const actions = document.createElement("div");
  actions.className = "card-actions";

  const copyBtn = document.createElement("button");
  copyBtn.type = "button";
  copyBtn.className = "cdn-pill-btn";
  copyBtn.textContent = "Copy CDN URL";
  copyBtn.addEventListener("click", () => {
    navigator.clipboard.writeText(cdnUrl).then(
      () => showToast(`Copied CloudFront URL to clipboard!`, "success"),
      () => showToast(`Failed to copy to clipboard`, "error")
    );
  });

  const downloadLink = document.createElement("a");
  downloadLink.className = "download-link";
  downloadLink.href = cdnUrl;
  downloadLink.target = "_blank";
  downloadLink.rel = "noopener noreferrer";
  downloadLink.textContent = "View";

  actions.appendChild(copyBtn);
  actions.appendChild(downloadLink);
  body.appendChild(actions);

  card.appendChild(body);
  return card;
}

function renderBlurhashPlaceholder(canvas, hash) {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  // Generate pseudo-deterministic pastel gradient based on hash string characters
  let seed = 0;
  for (let i = 0; i < hash.length; i++) {
    seed = (seed * 31 + hash.charCodeAt(i)) & 0xffffff;
  }

  const r1 = (seed >> 16) & 0xff;
  const g1 = (seed >> 8) & 0xff;
  const b1 = seed & 0xff;

  const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
  gradient.addColorStop(0, `rgb(${r1}, ${g1}, ${b1})`);
  gradient.addColorStop(1, `rgb(${Math.floor(b1 * 0.7)}, ${Math.floor(r1 * 0.7)}, ${Math.floor(g1 * 0.7)})`);

  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

function loadFallbackImages(gridContainer) {
  const fallback = [
    {
      image_id: "demo-1",
      original_key: "nature/mountain_sunrise.jpg",
      upload_date: new Date().toISOString(),
      file_size: 2048000,
      blurhash: "LEHLk~WB2yk8pyo0adR*.7kCMdnj",
      variants: ["thumbnail", "preview", "web"],
    },
    {
      image_id: "demo-2",
      original_key: "architecture/tokyo_skyline.jpg",
      upload_date: new Date().toISOString(),
      file_size: 3450000,
      blurhash: "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
      variants: ["thumbnail", "preview", "web"],
    },
  ];

  while (gridContainer.firstChild) {
    gridContainer.removeChild(gridContainer.firstChild);
  }

  fallback.forEach((img) => gridContainer.appendChild(createImageCard(img)));
}
