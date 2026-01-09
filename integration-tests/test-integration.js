#!/usr/bin/env node

/**
 * Simple integration test to verify frontend-backend connectivity
 * This script tests that the frontend can successfully communicate with the backend API
 */

const axios = require('axios');
const fs = require('fs');
const path = require('path');

const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:3000';
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3001';

// Test results tracking
const testResults = {
  tests: [],
  totalTests: 0,
  failures: 0,
  startTime: new Date()
};

function addTestResult(name, passed, message = '', time = 0) {
  testResults.totalTests++;
  if (!passed) {
    testResults.failures++;
  }
  
  testResults.tests.push({
    name,
    passed,
    message,
    time,
    className: 'IntegrationConnectivityTests'
  });
}

function generateJUnitXML() {
  const endTime = new Date();
  const totalTime = (endTime - testResults.startTime) / 1000;
  
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += `<testsuite name="Integration Connectivity Tests" tests="${testResults.totalTests}" failures="${testResults.failures}" errors="0" time="${totalTime}">\n`;
  
  testResults.tests.forEach(test => {
    xml += `  <testcase classname="${test.className}" name="${test.name}" time="${test.time}">\n`;
    if (!test.passed) {
      xml += `    <failure message="${test.message}" type="TestFailure">\n`;
      xml += `      ${test.message}\n`;
      xml += `    </failure>\n`;
    }
    xml += `  </testcase>\n`;
  });
  
  xml += '</testsuite>\n';
  return xml;
}

function saveTestResults() {
  try {
    const resultsDir = path.join(__dirname, 'results');
    if (!fs.existsSync(resultsDir)) {
      fs.mkdirSync(resultsDir, { recursive: true });
    }
    
    const xmlContent = generateJUnitXML();
    const filePath = path.join(resultsDir, 'connectivity-tests.xml');
    fs.writeFileSync(filePath, xmlContent);
    console.log(`📊 Test results saved to ${filePath}`);
  } catch (error) {
    console.error('❌ Failed to save test results:', error.message);
  }
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForService(url, serviceName, maxAttempts = 30) {
  console.log(`⏳ Waiting for ${serviceName} at ${url}...`);
  const startTime = new Date();
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const response = await axios.get(url, { timeout: 5000 });
      if (response.status === 200) {
        console.log(`✅ ${serviceName} is ready!`);
        const endTime = new Date();
        const testTime = (endTime - startTime) / 1000;
        addTestResult(`${serviceName} Availability`, true, '', testTime);
        return true;
      }
    } catch (error) {
      console.log(`🔄 Attempt ${attempt}/${maxAttempts}: ${serviceName} not ready (${error.message})`);
      if (attempt === maxAttempts) {
        console.log(`❌ ${serviceName} failed to become ready after ${maxAttempts} attempts`);
        const endTime = new Date();
        const testTime = (endTime - startTime) / 1000;
        addTestResult(`${serviceName} Availability`, false, `Service failed to become ready: ${error.message}`, testTime);
        return false;
      }
      await sleep(2000);
    }
  }
  return false;
}

async function testApiEndpoint(url, endpoint) {
  const startTime = new Date();
  try {
    console.log(`🧪 Testing API endpoint: ${endpoint}`);
    const response = await axios.get(`${url}${endpoint}`, { timeout: 10000 });
    
    const endTime = new Date();
    const testTime = (endTime - startTime) / 1000;
    
    if (response.status === 200) {
      console.log(`✅ API endpoint ${endpoint} responded successfully`);
      addTestResult(`API Endpoint ${endpoint}`, true, '', testTime);
      return true;
    } else {
      console.log(`⚠️ API endpoint ${endpoint} returned status ${response.status}`);
      addTestResult(`API Endpoint ${endpoint}`, false, `Unexpected status code: ${response.status}`, testTime);
      return false;
    }
  } catch (error) {
    const endTime = new Date();
    const testTime = (endTime - startTime) / 1000;
    console.log(`❌ API endpoint ${endpoint} failed: ${error.message}`);
    addTestResult(`API Endpoint ${endpoint}`, false, `Request failed: ${error.message}`, testTime);
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
    const startTime = new Date();
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
      
      const endTime = new Date();
      const testTime = (endTime - startTime) / 1000;
      
      if (testApiCall.status === 200) {
        console.log('✅ Frontend-backend API integration test passed');
        addTestResult('Frontend-Backend API Integration', true, '', testTime);
      } else {
        console.log('⚠️ Frontend-backend API integration test returned non-200 status');
        addTestResult('Frontend-Backend API Integration', false, `Non-200 status: ${testApiCall.status}`, testTime);
        allTestsPassed = false;
      }
    } catch (error) {
      const endTime = new Date();
      const testTime = (endTime - startTime) / 1000;
      console.log(`❌ Frontend-backend API integration test failed: ${error.message}`);
      addTestResult('Frontend-Backend API Integration', false, `Integration test failed: ${error.message}`, testTime);
      allTestsPassed = false;
    }
  }
  
  // Save test results before exiting
  saveTestResults();
  
  console.log('\n📊 Integration Test Summary:');
  console.log(`Total tests: ${testResults.totalTests}`);
  console.log(`Failures: ${testResults.failures}`);
  console.log(`Success rate: ${((testResults.totalTests - testResults.failures) / testResults.totalTests * 100).toFixed(1)}%`);
  
  if (allTestsPassed) {
    console.log('✅ All integration tests passed!');
    process.exit(0);
  } else {
    console.log('❌ Some integration tests failed!');
    process.exit(1);
  }
}

// Handle signals and uncaught errors
process.on('SIGTERM', () => {
  console.error('❌ Process terminated with SIGTERM');
  addTestResult('Process Termination', false, 'Process was terminated before completion');
  saveTestResults();
  process.exit(1);
});

process.on('SIGINT', () => {
  console.error('❌ Process interrupted with SIGINT');
  addTestResult('Process Interruption', false, 'Process was interrupted before completion');
  saveTestResults();
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  addTestResult('Unhandled Promise Rejection', false, `Unhandled rejection: ${reason}`);
  saveTestResults();
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  addTestResult('Uncaught Exception', false, `Uncaught exception: ${error.message}`);
  saveTestResults();
  process.exit(1);
});

runIntegrationTests();