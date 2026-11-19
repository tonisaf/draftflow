/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        accent: {
          DEFAULT: '#1A73E8',
          hover: '#1557B0',
          light: '#E8F0FE',
          dark: '#174EA6',
        },
        emerald: {
          500: '#22c55e',
          600: '#16a34a',
        },
        // 1:1 match with DraftFlow Flutter Skin design tokens
        df: {
          surface: {
            light: '#FFFFFF',
            dark: '#1F2023',
          },
          surfaceSubtle: {
            light: '#F7F8FA',
            dark: '#25272B',
          },
          sidebar: {
            light: '#F3F4F6',
            dark: '#26282C',
          },
          card: {
            light: '#FFFFFF',
            dark: '#2B2D31',
          },
          divider: {
            light: '#E7E9EC',
            dark: '#34373C',
          },
          text: {
            light: '#1D1F23',
            dark: '#E8EAED',
          },
          muted: {
            light: '#6B717B',
            dark: '#9AA0A6',
          },
          faint: {
            light: '#C4C8CE',
            dark: '#5F6368',
          },
        },
      },
      borderRadius: {
        modal: '20px',
        popover: '16px',
        panel: '14px',
        card: '12px',
        control: '8px',
        inner: '6px',
      },
      boxShadow: {
        card: '0 1px 3px rgba(0, 0, 0, 0.08), 0 1px 2px rgba(0, 0, 0, 0.04)',
        popover: '0 10px 25px -3px rgba(0, 0, 0, 0.3), 0 4px 6px -2px rgba(0, 0, 0, 0.15)',
        glow: '0 0 20px -3px rgba(26, 115, 232, 0.25)',
      },
    },
  },
  plugins: [],
};
