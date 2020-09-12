function BacklogViewModel() {
	var self = this;

	self.backlog = ko.mapping.fromJS({
		stories: []
	});

	self.refreshBacklog = function() {
		backend.loadBacklog()
		.then(data => {
			ko.mapping.fromJS({stories: data.backlog}, self.backlog);
		});
	};
	self.refreshBacklog();

	self.story = ko.mapping.fromJS({
		id: 0,
		title: "",
		points: 5
	});

	self.summary = ko.computed(function() {
		return self.story.title() + ": " + self.story.points() + " points";
	}, self);

	self.save = function() {
		var story = ko.mapping.toJS(self.story);
		backend.saveStory(story)
		.then(data => {
			self.refreshBacklog();
		});
	};

	self.editStory = function(story) {
		var jsStory = ko.mapping.toJS(story);
		ko.mapping.fromJS(jsStory, self.story);
	};

	self.cancelStory = function(story) {
		console.log("Cancel");
	};
}

ko.applyBindings(new BacklogViewModel());