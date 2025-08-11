#!/usr/bin/env node

/**
 * Simple integration test to verify frontend-backend connectivity
 * This script tests that the frontend can successfully communicate with the backend API
 */

const axios = require('axios');

const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:3000';
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3001';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForService(url, serviceName, maxAttempts = 30) {
  console.log(`⏳ Waiting for ${serviceName} at ${url}...`);
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const response = await axios.get(url, { timeout: 5000 });
      if (response.status === 200) {
        console.log(`✅ ${serviceName} is ready!`);
        return true;
      }
    } catch (error) {
      console.log(`🔄 Attempt ${attempt}/${maxAttempts}: ${serviceName} not ready (${error.message})`);
      if (attempt === maxAttempts) {
        console.log(`❌ ${serviceName} failed to become ready after ${maxAttempts} attempts`);
        return false;
      }
      await sleep(2000);
    }
  }
  return false;
}

async function testApiEndpoint(url, endpoint) {
  try {
    console.log(`🧪 Testing API endpoint: ${endpoint}`);
    const response = await axios.get(`${url}${endpoint}`, { timeout: 10000 });
    
    if (response.status === 200) {
      console.log(`✅ API endpoint ${endpoint} responded successfully`);
      return true;
    } else {
      console.log(`⚠️ API endpoint ${endpoint} returned status ${response.status}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ API endpoint ${endpoint} failed: ${error.message}`);
    return false;
  }
}

async function runIntegrationTests() {
  console.log('🚀 Starting integration tests...\n');
  
  let allTestsPassed = true;
  
  // Test 1: Check if backend is accessible
  const backendReady = await waitForService(`${BACKEND_URL}/api/health`, 'Backend API');
  if (!backendReady) {
    allTestsPassed = false;
  }
  
  // Test 2: Check if frontend is accessible  
  const frontendReady = await waitForService(FRONTEND_URL, 'Frontend');
  if (!frontendReady) {
    allTestsPassed = false;
  }
  
  // Test 3: Test critical API endpoints
  if (backendReady) {
    const endpoints = [
      '/api/health',
      '/api/layers',
      '/api/indicators'
    ];
    
    for (const endpoint of endpoints) {
      const endpointWorking = await testApiEndpoint(BACKEND_URL, endpoint);
      if (!endpointWorking) {
        allTestsPassed = false;
      }
    }
  }
  
  // Test 4: Test that frontend can make API calls
  if (backendReady && frontendReady) {
    try {
      console.log('🧪 Testing frontend API integration...');
      // This would ideally use a headless browser to test the actual frontend making API calls
      // For now, we'll just verify the endpoints are accessible from the same network
      const testApiCall = await axios.get(`${BACKEND_URL}/api/layers`, {
        timeout: 10000,
        headers: {
          'Origin': FRONTEND_URL,
          'Referer': FRONTEND_URL
        }
      });
      
      if (testApiCall.status === 200) {
        console.log('✅ Frontend-backend API integration test passed');
      } else {
        console.log('⚠️ Frontend-backend API integration test returned non-200 status');
        allTestsPassed = false;
      }
    } catch (error) {
      console.log(`❌ Frontend-backend API integration test failed: ${error.message}`);
      allTestsPassed = false;
    }
  }
  
  console.log('\n📊 Integration Test Summary:');
  if (allTestsPassed) {
    console.log('✅ All integration tests passed!');
    process.exit(0);
  } else {
    console.log('❌ Some integration tests failed!');
    process.exit(1);
  }
}

// Handle uncaught errors
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

runIntegrationTests();