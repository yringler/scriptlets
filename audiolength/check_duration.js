const fs = require('fs');
const path = require('path');
const file = path.resolve(__dirname, 'duration.json');
const json = fs.readFileSync(file, {
    encoding: 'utf8'
});
const data = JSON.parse(json);
const missingDuration = data.filter(audio => audio.Duration > 1000).length;
console.log(`Total classes: ${data.length}`);
console.log(`Classes without duration: ${missingDuration}`);
console.log(`Hit percentage: ${(data.length - missingDuration) / data.length * 100}`);