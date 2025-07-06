@echo off
REM Docker helper script for Resilience Atlas (Windows)

setlocal EnableDelayedExpansion

if "%1"=="" goto :help
if "%1"=="help" goto :help
if "%1"=="dev" goto :dev
if "%1"=="prod" goto :prod
if "%1"=="test" goto :test
if "%1"=="test-backend" goto :test-backend
if "%1"=="test-frontend" goto :test-frontend
if "%1"=="stop" goto :stop
if "%1"=="clean" goto :clean
if "%1"=="logs" goto :logs
if "%1"=="setup" goto :setup
goto :help

:help
echo Resilience Atlas Docker Helper
echo.
echo Usage: %0 [COMMAND]
echo.
echo Commands:
echo   dev                 Start development environment
echo   prod                Start production environment
echo   test                Run all tests
echo   test-backend        Run backend tests only
echo   test-frontend       Run frontend tests only
echo   stop                Stop all containers
echo   clean               Stop containers and remove volumes
echo   logs                Show logs for development environment
echo   setup               Initial setup (copy env files)
echo   help                Show this help message
echo.
goto :end

:dev
echo Starting development environment...
docker-compose -f docker-compose.dev.yml up --build
goto :end

:prod
echo Starting production environment...
docker-compose up --build
goto :end

:test
echo Running all tests...
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
goto :end

:test-backend
echo Running backend tests...
docker-compose -f docker-compose.test.yml run --rm backend-test
goto :end

:test-frontend
echo Running frontend tests...
docker-compose -f docker-compose.test.yml run --rm frontend-test
goto :end

:stop
echo Stopping all containers...
docker-compose -f docker-compose.dev.yml down
docker-compose down
docker-compose -f docker-compose.test.yml down
goto :end

:clean
echo Cleaning up containers and volumes...
docker-compose -f docker-compose.dev.yml down -v
docker-compose down -v
docker-compose -f docker-compose.test.yml down -v
goto :end

:logs
echo Showing logs for development environment...
docker-compose -f docker-compose.dev.yml logs -f
goto :end

:setup
echo Setting up environment files...

if not exist .env (
    copy .env.example .env
    echo Created .env from .env.example
    echo Please edit .env with your configuration values
) else (
    echo .env already exists
)

if not exist backend\.env (
    copy backend\.env.sample backend\.env
    echo Created backend\.env from backend\.env.sample
) else (
    echo backend\.env already exists
)

if not exist frontend\.env (
    copy frontend\.env.example frontend\.env
    echo Created frontend\.env from frontend\.env.example
) else (
    echo frontend\.env already exists
)
goto :end

:end
