const fs = require('fs');
const child_process = require ('child_process');

const json = fs.readFileSync('data.json', {
    encoding: 'utf8'
});

const data = JSON.parse(json);

lessonKeys = Object.getOwnPropertyNames(data.Lessons);
for (const lessonId of lessonKeys) {
	try {
		if (!data.Lessons[lessonId].Audio) {
			continue;
		}
		for (const media of data.Lessons[lessonId].Audio) {
			const duration = getDuration(media.Source);
			console.log(JSON.stringify({
				Source: media.Source,
				Duration: duration
			}) + ',');
		}
	} catch {
		continue;
	}
}

function getDuration(source) {
	try {
		child_process.execSync(`curl -s -r 0-1500 "${source}" --output tmp.mp3 > null`);
		const durationCommand = `mediainfo --Output="Audio;%FileName% %Duration%" tmp.mp3`;
		const duration = child_process.execSync(durationCommand, {
			encoding: 'utf8'
		});
		return +duration.trim();
	} catch {
		return 0;
	}
}
