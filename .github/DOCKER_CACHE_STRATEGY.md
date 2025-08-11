# Docker Build Caching Strategy

This document outlines the optimized Docker build caching strategy implemented for the Resilience Atlas project.

## Overview

The project uses Docker buildx with multiple caching strategies to significantly speed up CI/CD builds:

1. **Content-based cache keys** for better cache reuse
2. **Multi-level cache fallback** strategies  
3. **GitHub Actions cache** for persistence across runners
4. **Registry-based caching** for shared layers
5. **Coordinated multi-service builds** using docker bake

## Cache Key Strategy

### Backend Caching
Cache keys are generated based on:
- `Dockerfile` content hash
- `Gemfile` and `Gemfile.lock` content hash
- Ruby version from `.ruby-version`
- Date for daily cache invalidation

### Frontend Caching  
Cache keys are generated based on:
- `Dockerfile` content hash
- `package.json` and `package-lock.json` content hash
- Node.js version from `.nvmrc`
- Date for daily cache invalidation

### Integration Testing
Uses combined cache keys from both backend and frontend, with fallback to individual service caches.

## Cache Types

### 1. Local Cache (`type=local`)
- Stored in `/tmp/.buildx-cache`
- Fastest access during build
- Shared between build stages

### 2. GitHub Actions Cache (`type=gha`)
- Persistent across workflow runs
- Automatically managed by GitHub
- 10GB limit per repository

### 3. Registry Cache (`type=registry`)
- Future enhancement for sharing between repositories
- Persistent and highly available
- Requires registry push permissions

## Build Optimizations

### Layer Ordering
Dockerfiles are optimized for maximum cache reuse:
1. System dependencies (rarely change)
2. Language runtime setup
3. Dependency files (`Gemfile`, `package.json`)
4. Dependency installation 
5. Application code (changes frequently)

### Multi-stage Builds
- `base`: Common system setup
- `deps`/`dev-deps`: Dependency installation
- `test`: Test-specific setup
- `production`: Production build

### Build Arguments
- `BUILDKIT_INLINE_CACHE=1`: Enables inline cache metadata
- Conditional Cypress installation via `CYPRESS_INSTALL_BINARY`
- Environment-specific build args

## Docker Bake Configuration

The `.github/docker-bake.hcl` file enables:
- Coordinated multi-service builds
- Shared cache layers between services
- Consistent build configuration
- Parallel build execution

### Usage

```bash
# Build all test services with coordinated caching
docker buildx bake --file .github/docker-bake.hcl default

# Build integration test services
docker buildx bake --file .github/docker-bake.hcl integration

# Print configuration
docker buildx bake --file .github/docker-bake.hcl --print
```

## Cache Performance Monitoring

Each workflow includes cache analytics:
- Cache size reporting
- Hit/miss ratio tracking
- Build time measurements
- Docker system resource usage

## Best Practices

### For Developers
1. **Minimize Dockerfile changes**: Only modify when necessary
2. **Update dependencies in batches**: Group related changes together  
3. **Use .dockerignore**: Exclude unnecessary files from build context
4. **Layer ordering**: Keep frequently changing files at the end

### For CI/CD
1. **Parallel builds**: Use matrix strategies when possible
2. **Cache warming**: Pre-pull base images
3. **Fallback strategies**: Always have multiple restore-keys
4. **Cache invalidation**: Include date in keys for daily refresh

## Troubleshooting

### Common Issues

**Cache miss despite no changes**
- Check if base image was updated
- Verify Dockerfile hasn't changed
- Look for dependency file modifications

**Build failures after cache restore**
- Corrupted cache can cause issues
- Try building without cache: `--no-cache`
- Check for network connectivity issues

**Large cache sizes**
- Use `--cache-to=mode=max` for better compression
- Regularly clean up old cache entries
- Monitor cache analytics output

### Debug Commands

```bash
# Check cache contents
docker buildx du

# Build without cache
docker buildx build --no-cache

# Inspect cache layers
docker buildx imagetools inspect --raw <image>
```

## Future Enhancements

1. **Registry caching**: Implement persistent registry-based cache
2. **Cross-repository sharing**: Share base image layers
3. **Smart invalidation**: More granular cache invalidation
4. **Build analytics**: Enhanced performance monitoring
5. **Cache warming workflows**: Dedicated cache preparation jobs

## References

- [Docker Buildx Documentation](https://docs.docker.com/buildx/)
- [GitHub Actions Cache](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [Docker Build Cache Best Practices](https://docs.docker.com/develop/dev-best-practices/)