const express = require('express');
const favicon = require('express-favicon');
const path = require('path');

const port = process.env.PORT || 8080;
const app = express();

app.use(favicon(path.join(__dirname, '/build/favicon.ico')));
app.use(express.static(path.join(__dirname, 'build')));
app.get('/*', (req, res) =>
  res.sendFile(path.join(__dirname, 'build', 'index.html')),
);
app.listen(port, () => console.log(`Listening on port ${port}`));
