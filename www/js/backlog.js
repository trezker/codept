function BacklogViewModel() {
	this.backlog = ko.mapping.fromJS({
		stories: []
	});

	this.refreshBacklog = function() {
		backend.loadBacklog()
		.then(data => {
			ko.mapping.fromJS({stories: data.backlog}, this.backlog);
		});
	};
	this.refreshBacklog();

	this.story = {
		title: ko.observable(""),
		points: ko.observable(5)
	};

	this.summary = ko.computed(function() {
		return this.story.title() + ": " + this.story.points() + " points";
	}, this);

	this.save = function() {
		var story = ko.mapping.toJS(this.story);
		backend.saveStory(story)
		.then(data => {
			this.refreshBacklog();
		});
	};
}

ko.applyBindings(new BacklogViewModel());