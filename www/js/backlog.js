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

	self.newStory = {
		id: 0,
		title: "",
		points: 5
	};

	self.story = ko.mapping.fromJS(self.newStory);

	self.save = function() {
		var story = ko.mapping.toJS(self.story);
		backend.saveStory(story)
		.then(data => {
			self.refreshBacklog();
			ko.mapping.fromJS(self.newStory, self.story);
		});
	};

	self.editStory = function(story) {
		var jsStory = ko.mapping.toJS(story);
		ko.mapping.fromJS(jsStory, self.story);
	};

	self.cancelStory = function(story) {
		var story = ko.mapping.toJS(story);
		backend.cancelStory(story)
		.then(data => {
			self.refreshBacklog();
		});
	};

	self.doneStory = function(story) {
		var story = ko.mapping.toJS(story);
		backend.doneStory(story)
		.then(data => {
			self.refreshBacklog();
		});
	};
}

ko.applyBindings(new BacklogViewModel());