import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';

import App from './App';
import { migrateFlutterHash } from './lib/router';

import './styles.css'; 



if (window.location.pathname === "/admin") {
  window.location.replace("/admin/" + window.location.search + window.location.hash);
} else {
  migrateFlutterHash();
}

const root = document.getElementById('root');

if (!root) {
  throw new Error('TechZone root element not found');
}

// ============================================================
// RENDER REACT APPLICATION
// ============================================================

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>
);