function BacklogViewModel() {
	this.story = {
		title: ko.observable(""),
		points: ko.observable(5)
	};

	this.summary = ko.computed(function() {
		return this.story.title() + ": " + this.story.points() + " points";
	}, this);

	this.save = function() {
		var storydata = ko.mapping.toJS(this.story);
		console.log(storydata);
	};
}

ko.applyBindings(new BacklogViewModel());