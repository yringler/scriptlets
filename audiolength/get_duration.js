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
	let duration15 = getDurationFromPartial(source, 1500);
	let duration30 = getDurationFromPartial(source, 3000);

	if (duration15 && duration15 == duration30) {
		return duration30;
	}

	return getDurationFromPartial(source);
}

function getDurationFromPartial(source, bytes) {
	let rangeArguments = bytes ? `-r 0-${bytes}` : '';

	try {
		child_process.execSync(`curl -s ${rangeArguments} "${encodeURI(source)}" --output tmp.mp3 > null`);
		const durationCommand = `mediainfo --Output="Audio;%FileName% %Duration%" tmp.mp3`;
		const duration = child_process.execSync(durationCommand, {
			encoding: 'utf8'
		});
		return +duration.trim();
	} catch (ex){		
		return 0;
	}
}
