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
	int points;
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
				`points` int(11) NOT NULL
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
			mysql.query("insert into story (title, points) values (?, ?);", story.title, story.points);
		}
		else {
			mysql.query("update story set title=?, points=? where ID=?;", story.title, story.points, story.id);
		}
	}

	Story[] LoadBacklog() {
		Story[] stories;
		auto rows = mysql.query("select ID, title, points from story;");
		foreach (row; rows) {
			Story story;
			story.id = to!int(row["ID"]);
			story.title = row["title"];
			story.points = to!int(row["points"]);
			stories ~= story;
		}
    	return stories;
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
			Test1();
			storage.Reset();
			Test2();
			storage.Reset();
			Test3();
			storage.Reset();
		}
		catch(Exception e) {
			writeln(e);
		}

		storage.Dismantle();
	}

	void Test1() {
		assert(0 == storage.LoadBacklog().length);
	}

	void Test2() {
		Story story;
		storage.SaveStory(story);
		assert(1 == storage.LoadBacklog().length);
	}

	void Test3() {
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
};

unittest {
	StorageTest s = new StorageTest;
	s.Run();
}
