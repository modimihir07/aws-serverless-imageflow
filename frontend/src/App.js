/**
 * AWS Serverless ImageFlow - Frontend SPA Controller
 * Vanilla ES6, Zero Frameworks, Safe DOM Manipulation.
 */

const CONFIG = {
  // Uses relative paths when served by mock-server or API Gateway reverse proxy
  apiUrl: window.location.origin.includes("localhost")
    ? "/api"
    : "https://YOUR_API_GATEWAY_URL/dev",
  cdnUrl: window.location.origin.includes("localhost")
    ? window.location.origin
    : "https://YOUR_CLOUDFRONT_DOMAIN",
  region: "us-east-1",
};

function showToast(message, type = "info") {
  const container = document.getElementById("toastContainer");
  if (!container) return;

  const toast = document.createElement("div");
  toast.className = `toast toast-${type}`;
  toast.textContent = message;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = "0";
    toast.style.transform = "translateX(100%)";
    toast.style.transition = "all 0.3s ease";
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
    }, 300);
  }, 3500);
}

function navigateTo(route) {
  window.location.hash = `#/${route}`;
}

function updateNavButtons(currentRoute) {
  const navGallery = document.getElementById("navGallery");
  const navUpload = document.getElementById("navUpload");

  if (navGallery && navUpload) {
    if (currentRoute === "upload") {
      navGallery.classList.remove("active");
      navUpload.classList.add("active");
    } else {
      navGallery.classList.add("active");
      navUpload.classList.remove("active");
    }
  }
}

function renderApp() {
  const root = document.getElementById("root");
  if (!root) return;

  // Clear root safely
  while (root.firstChild) {
    root.removeChild(root.firstChild);
  }

  const hash = window.location.hash || "#/gallery";

  if (hash.startsWith("#/upload")) {
    updateNavButtons("upload");
    if (typeof renderUploadView === "function") {
      root.appendChild(renderUploadView());
    }
  } else {
    updateNavButtons("gallery");
    if (typeof renderGalleryView === "function") {
      root.appendChild(renderGalleryView());
    }
  }
}

window.addEventListener("hashchange", renderApp);
document.addEventListener("DOMContentLoaded", renderApp);
