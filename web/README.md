# MGE-Sift Web User Interface

## Overview

Modern, responsive web interface for the MGE-Sift pipeline built with Vue.js 3, TypeScript, and Tailwind CSS.

## Features

- **Dashboard**: Real-time pipeline statistics and sample overview
- **Results Viewer**: Interactive filtering and visualization of detection results
- **Sample Reports**: Comprehensive analysis summaries with charts
- **Settings**: API configuration and application preferences
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Dark Theme**: Eye-friendly interface optimized for long sessions

## Technology Stack

| Technology | Purpose | Version |
|------------|---------|---------|
| Vue.js | Frontend framework | 3.3+ |
| TypeScript | Type-safe JavaScript | 5.3+ |
| Tailwind CSS | Styling | 3.3+ |
| Vite | Build tool | 5.0+ |
| Pinia | State management | 2.1+ |
| Axios | HTTP client | 1.6+ |
| Lucide Vue | Icons | 0.263+ |

## Quick Start

### Development

```bash
cd web
npm install
npm run dev
```

Visit `http://localhost:5173` in your browser.

### Build for Production

```bash
npm run build
npm run preview
```

### Docker

```bash
# Build image
docker build -f web/Dockerfile -t mge-sift-web:2.0.0 .

# Run with docker-compose (see docker-compose.yml)
docker-compose up web
```

## Project Structure

```
web/
├── src/
│   ├── components/           # Reusable Vue components
│   │   ├── StatCard.vue      # Statistics card component
│   │   └── ReportCard.vue    # Report card component
│   ├── pages/                # Page components
│   │   ├── Dashboard.vue     # Main dashboard
│   │   ├── Results.vue       # Results viewer
│   │   ├── Reports.vue       # Analysis reports
│   │   └── Settings.vue      # Settings page
│   ├── stores/               # Pinia stores
│   │   └── main.ts           # Main state store
│   ├── router/               # Vue Router
│   │   └── index.ts          # Route definitions
│   ├── api.ts                # API client & types
│   ├── App.vue               # Root component
│   ├── main.ts               # Application entry point
│   └── style.css             # Global styles
├── public/                   # Static assets
├── index.html                # HTML entry point
├── vite.config.ts            # Vite configuration
├── tsconfig.json             # TypeScript configuration
├── tailwind.config.js        # Tailwind configuration
├── package.json              # Dependencies
└── Dockerfile                # Docker image
```

## API Integration

The frontend communicates with the FastAPI backend via HTTP requests. All API calls are typed and centralized in `src/api.ts`:

```typescript
// Example API usage
import { api } from '@/api'

// Get statistics
const stats = await api.stats()

// List samples
const samples = await api.listSamples()

// Get results for a sample
const results = await api.getResults('sample_001')

// Export results
const data = await api.exportResults('csv', 'sample_001')
```

## State Management

Uses Pinia for centralized state management:

```typescript
import { useStore } from '@/stores/main'

const store = useStore()

// Access state
store.samples
store.results
store.stats

// Call actions
await store.fetchSamples()
await store.selectSample('sample_001')
await store.exportResults('json')
```

## Authentication

API key is stored in localStorage and sent with each request:

```typescript
// Set API key
store.setApiKey('your-api-key')

// Update endpoint
localStorage.setItem('api_endpoint', 'https://api.example.com')
```

## Component Usage

### StatCard
Display a statistic metric:
```vue
<StatCard 
  title="Total Samples" 
  :value="100" 
  icon="samples" 
/>
```

### ReportCard
Display a report metric:
```vue
<ReportCard 
  title="Acquired Elements" 
  :value="45" 
/>
```

## Styling

Built-in Tailwind CSS utility classes for consistent styling:

```vue
<div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
  <h3 class="text-lg font-bold text-white">Title</h3>
  <p class="text-slate-300">Content</p>
</div>
```

Custom classes in `src/style.css`:

```css
.card { /* Card component styling */ }
.glass { /* Glass morphism effect */ }
.gradient-primary { /* Primary gradient */ }
```

## Environment Variables

```env
# .env.local
VITE_API_URL=http://localhost:8000
VITE_APP_TITLE=MGE-Sift
```

## Performance Optimization

- Code splitting with Vite
- Tree-shaking for smaller bundle size
- Lazy-loaded routes
- Efficient component rendering with Vue 3 Composition API
- Optimized images and assets

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile browsers (iOS Safari 14+, Chrome Android)

## Development Workflow

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-page
   ```

2. **Develop & Test**
   ```bash
   npm run dev
   npm run type-check
   npm run lint
   ```

3. **Build & Preview**
   ```bash
   npm run build
   npm run preview
   ```

4. **Commit & Push**
   ```bash
   git add .
   git commit -m "feat: add new page"
   git push origin feature/new-page
   ```

## Troubleshooting

### API Connection Issues
- Check if backend is running: `curl http://localhost:8000/health`
- Verify API URL in Settings page
- Check browser console for CORS errors

### Build Errors
- Clear cache: `rm -rf dist node_modules && npm install`
- Check Node.js version: `node --version` (need 16+)

### Performance Issues
- Check DevTools Network tab for slow requests
- Use Lighthouse for performance audit
- Enable/disable auto-refresh in settings

## Testing

```bash
# Unit tests (when implemented)
npm run test

# Coverage
npm run test:coverage

# E2E tests (when implemented)
npm run test:e2e
```

## Deployment

### Vercel
```bash
npm install -g vercel
vercel
```

### Netlify
```bash
npm run build
netlify deploy --prod --dir dist
```

### Docker
See [DOCKER_SETUP.md](./DOCKER_SETUP.md) for Docker integration.

## Security

- API key stored in localStorage (consider sessionStorage for public machines)
- HTTPS recommended for production
- CSRF protection via FastAPI backend
- Input validation before API submission
- No sensitive data in console logs

## Contributing

1. Create feature branch
2. Follow Vue 3 Composition API style
3. Use TypeScript for type safety
4. Add Tailwind classes for styling
5. Test with multiple browsers
6. Submit pull request

## License

Same as MGE-Sift project

## Support

- Issues: GitHub Issues
- Discussions: GitHub Discussions
- Documentation: [Frontend Guide](../PRODUCTION_GUIDE.md)

---

**Version**: 2.0.0  
**Last Updated**: 2026-06-26  
**Status**: Production Ready
