module codept.storage;
import std.algorithm;
import mysql.d;

struct Story {
	int id;
	string title;
	int points;
};

class Storage {
	Story[] stories;
	int maxid = 0;
public:
	void SaveStory(Story story) {
		if(story.id == 0) {
			story.id = ++maxid;
			stories ~= story;
		}
		else {
			foreach (ref n; stories) {
				if(n.id == story.id) {
					n.title = story.title;
					n.points = story.points;
					break;
				}
			}
		}
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

unittest {
	Storage storage = new Storage;
	Story story;
	story.id = 0;
	storage.SaveStory(story);
	Story story2;
	story2.id = 0;
	storage.SaveStory(story2);
	assert(1 == storage.LoadBacklog()[0].id);
	assert(2 == storage.LoadBacklog()[1].id);

	Story storyUpdate;
	storyUpdate.id = 1;
	storyUpdate.title = "Updated";
	storage.SaveStory(storyUpdate);
	assert(2 == storage.LoadBacklog().length);
	assert("Updated" == storage.LoadBacklog()[0].title);
}