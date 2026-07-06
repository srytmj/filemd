# TODO

## CI/CD Pipeline

- [ ] GitHub Actions workflow, trigger on push to `main`
  - Backend job: `php artisan test` → `composer install --no-dev` → `artisan optimize` → SSH deploy to EC2
  - Frontend job: `npm ci` → `vite build` → rsync `dist/` to server
  - Gate: all tests must pass before any deploy step runs
