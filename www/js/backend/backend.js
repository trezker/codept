function Backend () {
	this.backlog = {
		stories: []
	};

	this.saveStory = function(story) {
		this.backlog.stories.push(story);
	};

	this.loadBacklog = function() {
		return this.backlog;
	}
};

var backend = new Backend();