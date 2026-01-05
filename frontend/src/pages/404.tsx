import React from 'react';
import { NextPage } from 'next';
import Head from 'next/head';

const Custom404: NextPage = () => {
  return (
    <>
      <Head>
        <title>404 - Page Not Found | Resilience Atlas</title>
        <meta name="description" content="The page you were looking for doesn't exist." />
      </Head>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: '100vh',
          textAlign: 'center',
          padding: '20px',
          fontFamily: 'Arial, sans-serif',
        }}
      >
        <h1 style={{ fontSize: '2rem', marginBottom: '1rem', color: '#333' }}>
          404 - This page could not be found
        </h1>
        <p style={{ fontSize: '1.1rem', color: '#666', marginBottom: '2rem' }}>
          The page you were looking for doesn't exist.
        </p>
        <a
          href="/"
          style={{
            padding: '10px 20px',
            backgroundColor: '#0070f3',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '5px',
            fontSize: '1rem',
          }}
          onMouseOver={(e) => {
            e.currentTarget.style.backgroundColor = '#0056b3';
          }}
          onMouseOut={(e) => {
            e.currentTarget.style.backgroundColor = '#0070f3';
          }}
        >
          Go back home
        </a>
      </div>
    </>
  );
};

export default Custom404;
