import { defineConfig } from 'wxt';

// See https://wxt.dev/api/config.html
export default defineConfig({
  modules: ['@wxt-dev/module-react'],
  srcDir: 'src',
  outDir: 'dist',
  manifest: {
    name: 'DraftFlow Web Companion',
    description: 'Quick notes, web clipping, quotes and articles directly into your DraftFlow workspace.',
    version: '1.0.28',
    permissions: [
      'sidePanel',
      'contextMenus',
      'storage',
      'activeTab',
      'scripting',
    ],
    host_permissions: [
      '<all_urls>',
    ],
    web_accessible_resources: [
      {
        resources: ['icon-16.png', 'icon-32.png', 'icon-48.png', 'icon-128.png'],
        matches: ['<all_urls>'],
      },
    ],
    icons: {
      16: 'icon-16.png',
      32: 'icon-32.png',
      48: 'icon-48.png',
      128: 'icon-128.png',
    },
    action: {
      default_title: 'DraftFlow Clipper & Notes',
      default_icon: {
        16: 'icon-16.png',
        32: 'icon-32.png',
        48: 'icon-48.png',
        128: 'icon-128.png',
      },
    },
    side_panel: {
      default_path: 'sidepanel.html',
    },
    commands: {
      _execute_action: {
        suggested_key: {
          default: 'Alt+Shift+D',
          mac: 'Alt+Shift+D',
        },
        description: 'Open DraftFlow Clipper',
      },
      open_side_panel: {
        suggested_key: {
          default: 'Alt+Shift+S',
          mac: 'Alt+Shift+S',
        },
        description: 'Open DraftFlow Side Panel',
      },
    },
  },
});
