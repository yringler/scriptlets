const fs = require('fs');
const child_process = require('child_process');

const sources = JSON.parse(fs.readFileSync('data.json', {
	encoding: 'utf8'
}));
const durations = JSON.parse(fs.readFileSync('duration.json', {
	encoding: 'utf8'
}));

let sourceMap = {};

if (durations.length) {
	for (const duration in durations) {
		sourceMap[duration.Source] = duration.Duration;
	}
} else {
	sourceMap = durations;
}

for (const source of sources) {
	try {
		if (!sourceMap[source]) {
			sourceMap[source] = getDuration(source);
		}
	} catch {
		continue;
	}
}

fs.writeFileSync('duration.json', JSON.stringify(sourceMap));

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
		child_process.execSync(`curl -s ${rangeArguments} "${encodeURI(source)}" --output tmp.mp3 > null.json`);
		const durationCommand = `mediainfo --Output="Audio;%FileName% %Duration%" tmp.mp3`;
		const duration = child_process.execSync(durationCommand, {
			encoding: 'utf8'
		});
		return +duration.trim();
	} catch (ex) {
		return 0;
	}
}
