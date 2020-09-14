function BacklogViewModel() {
	var self = this;

	self.storyTabs = ko.observableArray([
		{title: 'Backlog', value: 'backlog'},
		{title: 'Done', value: 'done'},
		{title: 'Cancelled', value: 'cancelled'}
	]);
	self.storyTab = ko.observable("backlog");

	self.selectStoryTab = function(tab) {
		self.storyTab(tab.value);
	};

	self.backlog = ko.mapping.fromJS({
		stories: []
	});

	self.cancelled = ko.mapping.fromJS({
		stories: []
	});

	self.done = ko.mapping.fromJS({
		stories: []
	});

	self.refreshBacklog = function() {
		backend.loadBacklog()
		.then(data => {
			ko.mapping.fromJS({stories: data.backlog}, self.backlog);
		});
	};
	self.refreshBacklog();

	self.refreshCancelled = function() {
		backend.cancelledStories()
		.then(data => {
			ko.mapping.fromJS({stories: data.stories}, self.cancelled);
		});
	};
	self.refreshCancelled();

	self.refreshDone = function() {
		backend.doneStories()
		.then(data => {
			ko.mapping.fromJS({stories: data.stories}, self.done);
		});
	};
	self.refreshDone();

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