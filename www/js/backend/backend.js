function apicall(url, data) {
	return fetch(url, {
		method: 'POST', // or 'PUT'
		headers: {
			'Content-Type': 'application/json',
		},
		body: JSON.stringify(data),
	})
	.then(response => response.json())
	.then(data => {
		if(data.loggedin == false) {
			window.location.href = '/login.html';
		} else {
			return data;
		}
	});
/*	.catch((error) => {
		console.error('Error:', error);
	});*/
}

function Backend () {
	this.saveStory = function(story) {
		return apicall('api/savestory', story);
	};

	this.loadBacklog = function(cb) {
		return apicall('api/loadbacklog', {});
	};

	this.cancelledStories = function(cb) {
		return apicall('api/cancelledstories', {});
	};

	this.doneStories = function(cb) {
		return apicall('api/donestories', {});
	};

	this.cancelStory = function(story) {
		return apicall('api/cancelstory', {"id": story.id});
	};

	this.doneStory = function(story) {
		return apicall('api/donestory', {"id": story.id});
	};
};

var backend = new Backend();