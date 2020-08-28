function BacklogViewModel() {
	this.backlog = ko.mapping.fromJS(backend.loadBacklog());

	this.story = {
		title: ko.observable(""),
		points: ko.observable(5)
	};

	this.summary = ko.computed(function() {
		return this.story.title() + ": " + this.story.points() + " points";
	}, this);

	this.save = function() {
		var story = ko.mapping.toJS(this.story);
		backend.saveStory(story);
		ko.mapping.fromJS(backend.loadBacklog(), this.backlog);
	};
}

ko.applyBindings(new BacklogViewModel());