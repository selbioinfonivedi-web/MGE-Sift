/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'deep-teal': '#0F766E',
        'warm-white': '#FDFBF7',
        'dark-text': '#1F2937'
      }
    },
  },
  plugins: [],
}
