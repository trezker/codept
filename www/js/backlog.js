

function BacklogViewModel() {
	var self = this;

	self.story = new Story();
	self.products = ko.observableArray([
		{title: 'Cow'},
		{title: 'Pig'},
		{title: 'Hen'}
	]);

	self.logout = function() {
		backend.logout();
	};
}

ko.applyBindings(new BacklogViewModel());