// Cognito Hosted UI integration

function renderLogin() {
  return `
    <div class="auth-container">
      <div class="auth-card">
        <h1>Serverless ImageFlow</h1>
        <p>Sign in to upload and manage your images</p>
        <button onclick="loginWithCognito()" class="btn-primary">
          Sign In with Cognito
        </button>
        <div class="auth-info">
          <p>Don't have an account? Sign up through the Cognito Hosted UI.</p>
        </div>
      </div>
    </div>
  `;
}

function loginWithCognito() {
  const clientId = CONFIG.clientId;
  const domain = CONFIG.cognitoDomain;
  const redirectUri = window.location.origin + "/";
  const state = Math.random().toString(36).substring(2, 15);
  const url = `https://${domain}/login?client_id=${clientId}&response_type=token&scope=email+openid+profile&redirect_uri=${encodeURIComponent(redirectUri)}&state=${state}`;
  window.location.href = url;
}

function logout() {
  localStorage.removeItem("imageflow_token");
  authToken = null;
  currentUser = null;

  const clientId = CONFIG.clientId;
  const domain = CONFIG.cognitoDomain;
  const logoutUri = window.location.origin + "/";
  const url = `https://${domain}/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(logoutUri)}`;
  window.location.href = url;
}

function getAuthHeaders() {
  return authToken
    ? { Authorization: `Bearer ${authToken}`, "Content-Type": "application/json" }
    : { "Content-Type": "application/json" };
}
