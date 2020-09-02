module codept.storage;

struct Story {
	string title;
	int points;
};

class Storage {
	Story[] stories;
public:
	void SaveStory(Story story) {
		stories ~= story;
	}

	Story[] LoadBacklog() {
		return stories;
	}
};

unittest {
	Storage storage = new Storage;
	assert(0 == storage.LoadBacklog().length);
}

unittest {
	Storage storage = new Storage;
	Story story;
	storage.SaveStory(story);
	assert(1 == storage.LoadBacklog().length);
}