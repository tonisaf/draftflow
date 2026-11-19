import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import '@/styles/globals.css';
import { getSettings, applyTheme } from '@/storage/draftStore';

getSettings().then((s) => applyTheme(s.theme));

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
