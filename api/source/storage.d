module codept.storage;

import std.algorithm;
import std.stdio;
import std.file;
import std.conv;
import mysql.d;
import dauth;

import codept.data;

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

		mysql.query("
			CREATE TABLE `user` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				`name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
				`password` varchar(256) COLLATE utf8mb4_unicode_ci NOT NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `session` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				`userID` bigint(20) NOT NULL,
				`sessionid` varchar(256) COLLATE utf8mb4_unicode_ci NOT NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `product` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				`userID` bigint(20) NOT NULL,
				`title` varchar(256) COLLATE utf8mb4_unicode_ci NOT NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");
	}

	void Reset() {
		mysql.query("truncate story;");
		mysql.query("truncate user;");
		mysql.query("truncate session;");
		mysql.query("truncate product;");
	}

	void Dismantle() {
		mysql.query("drop table story;");
		mysql.query("drop table user;");
		mysql.query("drop table session;");
		mysql.query("drop table product;");
	}

	void SaveStory(Story story) {
		if(story.id == 0) {
			mysql.query("insert into story (title, cost, value) values (?, ?, ?);", story.title, story.cost, story.value);
		}
		else {
			mysql.query("update story set title=?, cost=?, value=? where ID=?;", story.title, story.cost, story.value, story.id);
		}
	}

	void SaveProduct(Product product) {
		mysql.query("insert into product (userid, title) values (?, ?);", product.userid, product.title);
	}

	Product[] ProductsByUser(int userid) {
		Product[] products;
		auto rows = mysql.query("
			select ID, userID, title
			from product
			where userID = ?
			order by title asc;", userid);
		foreach (row; rows) {
			Product product;
			product.id = to!int(row["ID"]);
			product.userid = to!int(row["userID"]);
			product.title = row["title"];
			products ~= product;
		}
		return products;
	}

	Story[] LoadBacklog() {
		Story[] stories;
		auto rows = mysql.query("
			select ID, title, cost, value
			from story
			where cancelled is NULL and done is NULL
			order by value-cost desc;");
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

	void CreateUser(User user) {
		string hashedPassword = makeHash(dupPassword(user.password)).toString();
		mysql.query("insert into user(name, password) values(?, ?);", user.name, hashedPassword);
	}

	User LoadUser(int id) {
		auto rows = mysql.query("select ID, name from user where ID=?;", id);
		User user;
		foreach(row; rows) {
			user.id = to!int(row["ID"]);
			user.name = row["name"];
			break;
		}
		return user;
	}

	User UserByName(string name) {
		auto rows = mysql.query("select ID, name from user where name=?;", name);
		User user;
		foreach(row; rows) {
			user.id = to!int(row["ID"]);
			user.name = row["name"];
			break;
		}
		return user;
	}

	string Login(User user) {
		auto rows = mysql.query("select ID, password from user where name=?;", user.name);
		foreach (row; rows) {
			string hashedPassword = row["password"];
			if(isSameHash(dupPassword(user.password), parseHash(hashedPassword))) {
				string sessionid = randomToken();
				mysql.query("insert into session(userid, sessionid) values(?, ?);", row["ID"], sessionid);
				return sessionid;
			}
			return "";
		}
		return "";
	}

	void Logout(string sessionid) {
		mysql.query("delete from session where sessionid=?", sessionid);
	}

	APISession LoadSession(string sessionid) {
		auto rows = mysql.query("select ID, userID, sessionid from session where sessionid=?;", sessionid);
		APISession session;
		foreach (row; rows) {
			session.id = to!int(row["ID"]);
			session.userid = to!int(row["userID"]);
			session.sessionid = row["sessionid"];
			return session;
		}
		return session;
	}
};


alias Test = void function(Storage);
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

		auto tests = PrepareTests();

		try {
			foreach(test; tests) {
				test(storage);
				storage.Reset();
			}
		}
		catch(Exception e) {
			writeln(e);
		}
		finally {
			writeln("Dismantling");
			storage.Dismantle();
		}
	}

	Test[string] PrepareTests() {
		Test[string] tests;
		tests["Backlog_empty_at_start"] = function(Storage storage) {
			assert(0 == storage.LoadBacklog().length);
		};

		tests["Saved_story_shows_up_in_backlog"] = function(Storage storage) {
			Story story;
			storage.SaveStory(story);
			assert(1 == storage.LoadBacklog().length);
		};

		tests["Story_can_be_updated"] = function(Storage storage) {
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
		};

		tests["Cancelled_story_is_removed_from_backlog"] = function(Storage storage) {
			Story story;
			storage.SaveStory(story);
			Story[] backlog = storage.LoadBacklog();
			storage.CancelStory(backlog[0].id);
			assert(0 == storage.LoadBacklog().length);
			assert(1 == storage.CancelledStories().length);
		};

		tests["Done_story_is_removed_from_backlog"] = function(Storage storage) {
			Story story;
			storage.SaveStory(story);
			Story[] backlog = storage.LoadBacklog();
			storage.DoneStory(backlog[0].id);
			assert(0 == storage.LoadBacklog().length);
			assert(1 == storage.DoneStories().length);
		};

		tests["Login to wrong account fails"] = function(Storage storage) {
			User user;
			user.name = "nobody";
			string sessionid = storage.Login(user);
			assert("" == sessionid);
		};

		tests["Login with correct name and password works"] = function(Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			string sessionid = storage.Login(user);
			assert("" != sessionid);
		};

		tests["Login with correct name but wrong password fails"] = function(Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			user.password = "wrongpassword";
			string sessionid = storage.Login(user);
			assert("" == sessionid);
		};

		tests["After login, session should contain correct user"] = function(Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			string sessionid = storage.Login(user);
			APISession session = storage.LoadSession(sessionid);
			User sessionuser = storage.LoadUser(session.userid);
			assert(user.name == sessionuser.name);
		};

		tests["Multiple logins should not get the same sessionid"] = function(Storage storage) {
			User user1;
			user1.name = "some1";
			user1.password = "password1";
			storage.CreateUser(user1);
			User user2;
			user2.name = "some2";
			user2.password = "password2";
			storage.CreateUser(user2);
			string sessionid1 = storage.Login(user1);
			string sessionid2 = storage.Login(user2);
			assert(sessionid1 != sessionid2);
		};

		tests["After logout, session should not contain a user"] = function(Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			string sessionid = storage.Login(user);
			APISession session = storage.LoadSession(sessionid);
			User sessionuser = storage.LoadUser(session.userid);
			assert(user.name == sessionuser.name);

			storage.Logout(sessionid);
			session = storage.LoadSession(sessionid);
			assert("" == session.sessionid);
			assert(0 == session.userid);
		};

		tests["Product can be created"] = function(Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			user = storage.UserByName(user.name);

			Product product;
			product.title = "some product";
			product.userid = user.id;
			storage.SaveProduct(product);

			Product[] products = storage.ProductsByUser(user.id);
			assert(1 == products.length);
		};

		return tests;
	}
};

unittest {
	StorageTest s = new StorageTest;
	s.Run();
}
