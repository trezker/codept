function apicall(url, data) {
	return fetch(url, {
		method: 'POST', // or 'PUT'
		headers: {
			'Content-Type': 'application/json',
		},
		body: JSON.stringify(data),
	})
	.then(response => response.json());
	/*
	.then(data => {
		console.log('Success:', data);

	})
	.catch((error) => {
		console.error('Error:', error);
	});*/
}

function Backend () {
	this.backlog = {
		stories: []
	};

	this.saveStory = function(story) {
		this.backlog.stories.push(story);
		return apicall('api/savestory', story);
	};

	this.loadBacklog = function(cb) {
		return apicall('api/loadbacklog', {});
	};
};

var backend = new Backend();