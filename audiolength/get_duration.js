const fs = require('fs');
const child_process = require ('child_process');

const json = fs.readFileSync('data.json', {
    encoding: 'utf8'
});

const data = JSON.parse(json);

lessonKeys = Object.getOwnPropertyNames(data.Lessons);
for (const lessonId of lessonKeys) {
    for (const media of data.Lessons[lessonId].Audio) {
        const duration = getDuration(media.Source);
        console.log(JSON.stringify({
            Source: media.Source,
            Duration: duration
        }) + ',');
    }
}

function getDuration(source) {
    child_process.execSync(`curl -s -r 0-1500 "${source}" --output tmp.mp3 > /dev/null`);
    const durationCommand = `mediainfo --Output="Audio;%FileName% %Duration%" tmp.mp3`;
    const duration = child_process.execSync(durationCommand, {
        encoding: 'utf8'
    });
    return +duration.trim();
}
