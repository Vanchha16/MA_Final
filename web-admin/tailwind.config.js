/** Anime World Shop colours (same as the app): sky blue brand, solid buttons. */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        // CSS variables (index.css) so the dark theme swaps them all at once
        brand: { DEFAULT: 'rgb(var(--brand) / <alpha-value>)', dark: 'rgb(var(--brand-dark) / <alpha-value>)', light: '#0EA5E9', tint: 'rgb(var(--brand-tint) / <alpha-value>)', on: 'rgb(var(--brand-on) / <alpha-value>)' },
        ink: 'rgb(var(--ink) / <alpha-value>)',
        muted: 'rgb(var(--muted) / <alpha-value>)',
        line: 'rgb(var(--line) / <alpha-value>)',
        page: 'rgb(var(--page) / <alpha-value>)',
        card: 'rgb(var(--card) / <alpha-value>)',
        soft: 'rgb(var(--soft) / <alpha-value>)',
        coral: '#F43F5E',
        aqua: '#06B6D4',
      },
      fontFamily: { sans: ['Roboto', 'Arial', 'sans-serif'] },
      boxShadow: { card: 'var(--shadow-card)', drawer: '-10px 0 30px rgba(2,6,23,.25)' },
      borderRadius: { card: '18px' },
    },
  },
  plugins: [],
};
