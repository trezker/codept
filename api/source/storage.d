module codept.storage;

import std.algorithm;
import std.stdio;
import std.file;
import std.array;
import std.conv;
import mysql.d;

struct Story {
	int id;
	string title;
	int cost;
	int value;
};

struct MysqlParams {
	string url;
	string port;
	string user;
	string password;
	string database;
};

class Storage {
	Mysql mysql;
public:
	this(MysqlParams params) {
		mysql = new Mysql(params.url, to!int(params.port), params.user, params.password, params.database);
	}

	void Prepare() {
		mysql.query("
			CREATE TABLE `story` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				`title` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
				`cost` int(11) NOT NULL,
				`value` int(11) NOT NULL,
				`cancelled` DATETIME,
				`done` DATETIME
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");
	}

	void Reset() {
		mysql.query("truncate story;");
	}

	void Dismantle() {
		mysql.query("drop table story;");
	}

	void SaveStory(Story story) {
		if(story.id == 0) {
			mysql.query("insert into story (title, cost, value) values (?, ?, ?);", story.title, story.cost, story.value);
		}
		else {
			mysql.query("update story set title=?, cost=?, value=? where ID=?;", story.title, story.cost, story.value, story.id);
		}
	}

	Story[] LoadBacklog() {
		Story[] stories;
		auto rows = mysql.query("select ID, title, cost, value from story where cancelled is NULL and done is NULL;");
		foreach (row; rows) {
			Story story;
			story.id = to!int(row["ID"]);
			story.title = row["title"];
			story.cost = to!int(row["cost"]);
			story.value = to!int(row["value"]);
			stories ~= story;
		}
		return stories;
	}

	Story[] CancelledStories() {
		Story[] stories;
		auto rows = mysql.query("select ID, title, cost, value from story where cancelled is NOT NULL;");
		foreach (row; rows) {
			Story story;
			story.id = to!int(row["ID"]);
			story.title = row["title"];
			story.cost = to!int(row["cost"]);
			story.value = to!int(row["value"]);
			stories ~= story;
		}
		return stories;
	}

	Story[] DoneStories() {
		Story[] stories;
		auto rows = mysql.query("select ID, title, cost, value from story where done is NOT NULL;");
		foreach (row; rows) {
			Story story;
			story.id = to!int(row["ID"]);
			story.title = row["title"];
			story.cost = to!int(row["cost"]);
			story.value = to!int(row["value"]);
			stories ~= story;
		}
		return stories;
	}

	void CancelStory(int id) {
		mysql.query("update story set cancelled=NOW() where ID=?;", id);
	}

	void DoneStory(int id) {
		mysql.query("update story set done=NOW() where ID=?;", id);
	}
};

class StorageTest {
public:
	Storage storage;

	void Run() {
		MysqlParams params;
		params.url = "test.local";
		params.port = "3306";
		params.database = "codept_test";
		params.user = "codept_test";
		params.password="pQoMU4YcckuW23V5";

		storage =  new Storage(params);
		storage.Prepare();

		try {
			Backlog_empty_at_start();
			storage.Reset();
			Saved_story_shows_up_in_backlog();
			storage.Reset();
			Story_can_be_updated();
			storage.Reset();
			Cancelled_story_is_removed_from_backlog();
			storage.Reset();
			Done_story_is_removed_from_backlog();
			storage.Reset();
		}
		catch(Exception e) {
			writeln(e);
		}
		finally {
			storage.Dismantle();
		}
	}

	void Backlog_empty_at_start() {
		assert(0 == storage.LoadBacklog().length);
	}

	void Saved_story_shows_up_in_backlog() {
		Story story;
		storage.SaveStory(story);
		assert(1 == storage.LoadBacklog().length);
	}

	void Story_can_be_updated() {
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

	void Cancelled_story_is_removed_from_backlog() {
		Story story;
		storage.SaveStory(story);
		Story[] backlog = storage.LoadBacklog();
		storage.CancelStory(backlog[0].id);
		assert(0 == storage.LoadBacklog().length);
		assert(1 == storage.CancelledStories().length);
	}

	void Done_story_is_removed_from_backlog() {
		Story story;
		storage.SaveStory(story);
		Story[] backlog = storage.LoadBacklog();
		storage.DoneStory(backlog[0].id);
		assert(0 == storage.LoadBacklog().length);
		assert(1 == storage.DoneStories().length);
	}
};

unittest {
	StorageTest s = new StorageTest;
	s.Run();
}
