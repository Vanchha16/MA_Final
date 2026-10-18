/** Anime World Shop colours (same as the app): sky blue brand, solid buttons. */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        brand: { DEFAULT: '#0284C7', dark: '#0369A1', light: '#0EA5E9', tint: '#E0F2FE' },
        ink: '#0F172A',
        muted: '#64748B',
        line: '#E2E8F0',
        page: '#F4F8FC',
        coral: '#F43F5E',
        aqua: '#06B6D4',
      },
      fontFamily: { sans: ['Roboto', 'Arial', 'sans-serif'] },
      boxShadow: { card: '0 6px 18px rgba(2,132,199,.07)', drawer: '-10px 0 30px rgba(15,23,42,.15)' },
      borderRadius: { card: '18px' },
    },
  },
  plugins: [],
};
