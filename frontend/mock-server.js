/**
 * Serverless ImageFlow - Local UI Mock Server
 *
 * Runs a standalone HTTP server without AWS credentials or external dependencies.
 * Serves the SPA frontend and simulates API Gateway & S3 responses for local testing.
 *
 * Usage:
 *   node frontend/mock-server.js
 *   Open http://localhost:3000 in your browser.
 */

const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3000;
const FRONTEND_DIR = __dirname;

// Initial mock image store
const mockImages = [
  {
    image_id: "img-nature-01",
    original_key: "nature/mountain_sunrise.jpg",
    file_size: 2458120,
    content_type: "image/jpeg",
    upload_date: new Date(Date.now() - 3600000 * 4).toISOString(),
    status: "completed",
    blurhash: "LEHLk~WB2yk8pyo0adR*.7kCMdnj",
    variants: [
      "nature/mountain_sunrise_thumbnail.jpg",
      "nature/mountain_sunrise_preview.jpg",
      "nature/mountain_sunrise_web.jpg",
    ],
  },
  {
    image_id: "img-city-02",
    original_key: "architecture/tokyo_skyline.jpg",
    file_size: 3891400,
    content_type: "image/jpeg",
    upload_date: new Date(Date.now() - 3600000 * 12).toISOString(),
    status: "completed",
    blurhash: "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
    variants: [
      "architecture/tokyo_skyline_thumbnail.jpg",
      "architecture/tokyo_skyline_preview.jpg",
      "architecture/tokyo_skyline_web.jpg",
    ],
  },
  {
    image_id: "img-ocean-03",
    original_key: "wildlife/coastal_whale.png",
    file_size: 1980450,
    content_type: "image/png",
    upload_date: new Date(Date.now() - 3600000 * 24).toISOString(),
    status: "completed",
    blurhash: "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
    variants: [
      "wildlife/coastal_whale_thumbnail.jpg",
      "wildlife/coastal_whale_preview.jpg",
      "wildlife/coastal_whale_web.jpg",
    ],
  },
];

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  });
  res.end(JSON.stringify(data));
}

const server = http.createServer((req, res) => {
  const parsedUrl = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = parsedUrl.pathname;

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    });
    res.end();
    return;
  }

  // API Routes
  if (pathname === "/api/health" || pathname === "/health") {
    return sendJson(res, 200, {
      status: "ok",
      timestamp: new Date().toISOString(),
      service: "imageflow-mock-api",
      version: "1.0.0",
    });
  }

  if (pathname === "/api/images" || pathname === "/images") {
    if (req.method === "GET") {
      const limit = parseInt(parsedUrl.searchParams.get("limit") || "20", 10);
      return sendJson(res, 200, {
        images: mockImages.slice(0, limit),
        count: mockImages.length,
        next_cursor: null,
      });
    }

    if (req.method === "POST") {
      let body = "";
      req.on("data", (chunk) => (body += chunk));
      req.on("end", () => {
        try {
          const payload = body ? JSON.parse(body) : {};
          const filename = payload.filename || `upload-${Date.now()}.jpg`;
          const cleanName = filename.replace(/[^a-zA-Z0-9.-]/g, "_");
          const imageId = `img-${Date.now().toString(36)}`;
          const prefix = cleanName.includes(".")
            ? cleanName.substring(0, cleanName.lastIndexOf("."))
            : cleanName;

          const newImage = {
            image_id: imageId,
            original_key: `uploads/${cleanName}`,
            file_size: payload.size || 1024 * 512,
            content_type: payload.contentType || "image/jpeg",
            upload_date: new Date().toISOString(),
            status: "completed",
            blurhash: "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
            variants: [
              `processed/${prefix}_thumbnail.jpg`,
              `processed/${prefix}_preview.jpg`,
              `processed/${prefix}_web.jpg`,
            ],
          };

          mockImages.unshift(newImage);
          return sendJson(res, 201, {
            message: "Image processed successfully",
            item: newImage,
          });
        } catch (err) {
          return sendJson(res, 400, { error: "Invalid JSON request" });
        }
      });
      return;
    }
  }

  // Single image query: /api/images/:id
  const imageMatch = pathname.match(/^\/(?:api\/)?images\/([^/]+)$/);
  if (imageMatch && req.method === "GET") {
    const id = imageMatch[1];
    const found = mockImages.find((img) => img.image_id === id);
    if (!found) {
      return sendJson(res, 404, { error: "Image not found" });
    }
    return sendJson(res, 200, found);
  }

  // Static file serving for SPA
  let filePath = path.join(FRONTEND_DIR, pathname === "/" ? "index.html" : pathname);

  // Security: prevent path traversal out of FRONTEND_DIR
  if (!filePath.startsWith(FRONTEND_DIR)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // Fallback to index.html for SPA client-side routing
      filePath = path.join(FRONTEND_DIR, "index.html");
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || "application/octet-stream";

    fs.readFile(filePath, (readErr, content) => {
      if (readErr) {
        res.writeHead(500);
        res.end("Internal Server Error");
        return;
      }
      res.writeHead(200, { "Content-Type": contentType });
      res.end(content);
    });
  });
});

server.listen(PORT, () => {
  console.log("==================================================");
  console.log("  AWS Serverless ImageFlow - UI Mock Server");
  console.log(`  Preview running at: http://localhost:${PORT}`);
  console.log(`  API Health:         http://localhost:${PORT}/api/health`);
  console.log(`  API Images:         http://localhost:${PORT}/api/images`);
  console.log("==================================================");
});
