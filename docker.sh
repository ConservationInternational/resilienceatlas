#!/bin/bash

# Docker helper script for Resilience Atlas

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    echo "Resilience Atlas Docker Helper"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  dev                 Start development environment"
    echo "  prod                Start production environment"
    echo "  test                Run all tests"
    echo "  test-backend        Run backend tests only"
    echo "  test-frontend       Run frontend tests only"
    echo "  stop                Stop all containers"
    echo "  clean               Stop containers and remove volumes"
    echo "  logs                Show logs for development environment"
    echo "  setup               Initial setup (copy env files)"
    echo "  help                Show this help message"
    echo ""
}

setup_env() {
    echo "Setting up environment files..."
    
    if [ ! -f .env ]; then
        cp .env.example .env
        echo "Created .env from .env.example"
        echo "Please edit .env with your configuration values"
    else
        echo ".env already exists"
    fi
    
    if [ ! -f backend/.env ]; then
        cp backend/.env.sample backend/.env
        echo "Created backend/.env from backend/.env.sample"
    else
        echo "backend/.env already exists"
    fi
    
    if [ ! -f frontend/.env ]; then
        cp frontend/.env.example frontend/.env
        echo "Created frontend/.env from frontend/.env.example"
    else
        echo "frontend/.env already exists"
    fi
}

case "${1:-help}" in
    "dev")
        echo "Starting development environment..."
        docker-compose -f docker-compose.dev.yml up --build
        ;;
    "prod")
        echo "Starting production environment..."
        docker-compose up --build
        ;;
    "test")
        echo "Running all tests..."
        docker-compose -f docker-compose.test.yml up --abort-on-container-exit
        ;;
    "test-backend")
        echo "Running backend tests..."
        docker-compose -f docker-compose.test.yml run --rm backend-test
        ;;
    "test-frontend")
        echo "Running frontend tests..."
        docker-compose -f docker-compose.test.yml run --rm frontend-test
        ;;
    "stop")
        echo "Stopping all containers..."
        docker-compose -f docker-compose.dev.yml down
        docker-compose down
        docker-compose -f docker-compose.test.yml down
        ;;
    "clean")
        echo "Cleaning up containers and volumes..."
        docker-compose -f docker-compose.dev.yml down -v
        docker-compose down -v
        docker-compose -f docker-compose.test.yml down -v
        ;;
    "logs")
        echo "Showing logs for development environment..."
        docker-compose -f docker-compose.dev.yml logs -f
        ;;
    "setup")
        setup_env
        ;;
    "help"|*)
        show_help
        ;;
esac
