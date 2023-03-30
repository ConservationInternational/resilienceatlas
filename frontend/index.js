// https://infinum.com/handbook/frontend/react/recipes/passenger-setup
const path = require('path');

// define the path to the next bin (luck has it that it's a node script)
const nextPath = path.join(__dirname, 'node_modules', '.bin', 'next');

// strips away all arguments until it's at `node`
process.argv.length = 1;

// redefining the arguments so it's like we are running `next start`
process.argv.push(nextPath, 'start');

// start the script/bin
require(nextPath);
