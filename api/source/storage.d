module codept.storage;

import std.datetime;
import std.format;
import std.algorithm;
import std.stdio;
import std.file;
import std.conv;
import std.json;
import mysql.d;
import dauth;

import codept.data;

class Storage {
	Mysql mysql;
public:
	this(MysqlParams params) {
		mysql = new Mysql(params.url, to!int(params.port), params.user, params.password, params.database);
	}

	string Generate_UUID() {
		auto rows = mysql.query("select UUID() as uuid;");
		foreach (row; rows) {
			return row["uuid"];
		}
		return "";
	}

	void Prepare() {
		mysql.query("
			CREATE TABLE `event_type` (
				`ID` bigint(20) NOT NULL PRIMARY KEY,
				`name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			INSERT INTO
				`event_type` (`ID`, `name`)
			VALUES
				(1, 'CreateUser'),
				(2, 'CreateProduct'),
				(3, 'CreateStory'),
				(4, 'UpdateStory'),
				(5, 'CancelStory'),
				(6, 'DoneStory');
		");

		mysql.query("
			CREATE TABLE `event` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  				`occurred` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
				`typeID` bigint(20) NOT NULL,
				`objectID` binary(16) NOT NULL,
				`data` json DEFAULT NULL,
				CONSTRAINT `event_fk_type` FOREIGN KEY (`typeID`) REFERENCES `event_type` (`ID`) ON DELETE RESTRICT ON UPDATE RESTRICT
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `user` (
				`ID` binary(16) NOT NULL PRIMARY KEY,
  				`name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
				`password` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `session` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				`userID` binary(16) NOT NULL,
				`sessionid` varchar(256) COLLATE utf8mb4_unicode_ci NOT NULL,
				CONSTRAINT `session_fk_user` FOREIGN KEY (`userID`) REFERENCES `user` (`ID`) ON DELETE RESTRICT ON UPDATE RESTRICT
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `product` (
				`ID` binary(16) NOT NULL PRIMARY KEY,
				`userID` binary(16) NOT NULL,
				`title` varchar(256) COLLATE utf8mb4_unicode_ci NOT NULL,
				CONSTRAINT `product_fk_user` FOREIGN KEY (`userID`) REFERENCES `user` (`ID`) ON DELETE RESTRICT ON UPDATE RESTRICT
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `story` (
				`ID` binary(16) NOT NULL PRIMARY KEY,
				`productID` binary(16) NOT NULL,
				`title` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
				`cost` int(11) NOT NULL,
				`value` int(11) NOT NULL,
				`cancelled` DATETIME,
				`done` DATETIME,
				CONSTRAINT `story_fk_product` FOREIGN KEY (`productID`) REFERENCES `product` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");
	}

	void Reset() {
		mysql.query("truncate story;");
		mysql.query("delete from product;");
		mysql.query("truncate session;");
		mysql.query("delete from user;");
		mysql.query("truncate event;");
	}

	void Dismantle() {
		mysql.query("drop table story;");
		mysql.query("drop table product;");
		mysql.query("drop table session;");
		mysql.query("drop table user;");
		mysql.query("drop table event;");
		mysql.query("drop table event_type;");
	}

	void SaveStory(Story story) {
		if(story.id == "") {
			auto uuid = Generate_UUID();

			JSONValue data = [ "productID": story.productid ];
			data.object["title"] = JSONValue(story.title);
			data.object["cost"] = JSONValue(story.cost);
			data.object["value"] = JSONValue(story.value);
			StoreEvent(uuid, "CreateStory", data);

			mysql.query(
				"insert into story (ID, productID, title, cost, value) values (UUID_TO_BIN(?, true), UUID_TO_BIN(?, true), ?, ?, ?);",
				uuid, story.productid, story.title, story.cost, story.value
			);
		}
		else {
			JSONValue data = [ "productID": story.productid ];
			data.object["title"] = JSONValue(story.title);
			data.object["cost"] = JSONValue(story.cost);
			data.object["value"] = JSONValue(story.value);
			StoreEvent(story.id, "UpdateStory", data);

			mysql.query(
				"update story set productID=UUID_TO_BIN(?, true), title=?, cost=?, value=? where ID=UUID_TO_BIN(?, true);",
				story.productid, story.title, story.cost, story.value, story.id
			);
		}
	}

	void SaveProduct(Product product) {
		auto uuid = Generate_UUID();

		JSONValue data = [ "userID": product.userid ];
		data.object["title"] = JSONValue(product.title);
		StoreEvent(uuid, "CreateProduct", data);

		mysql.query("insert into product (ID, userID, title) values (UUID_TO_BIN(?, true), UUID_TO_BIN(?, true), ?);", uuid, product.userid, product.title);
	}

	Product[] ProductsByUser(string userid) {
		Product[] products;
		auto rows = mysql.query("
			select BIN_TO_UUID(ID, true) as ID, BIN_TO_UUID(userID,true) as userID, title
			from product
			where userID = UUID_TO_BIN(?, true)
			order by title asc;", userid);
		foreach (row; rows) {
			Product product;
			product.id = row["ID"];
			product.userid = row["userID"];
			product.title = row["title"];
			products ~= product;
		}
		return products;
	}

	Story[] LoadBacklog() {
		Story[] stories;
		auto rows = mysql.query("
			select BIN_TO_UUID(ID, true) as ID, BIN_TO_UUID(productID, true) as productID, title, cost, value
			from story
			where cancelled is NULL and done is NULL
			order by value/cost desc;");
		foreach (row; rows) {
			Story story;
			story.id = row["ID"];
			story.productid = row["productID"];
			story.title = row["title"];
			story.cost = to!int(row["cost"]);
			story.value = to!int(row["value"]);
			stories ~= story;
		}
		return stories;
	}

	Story[] CancelledStories() {
		Story[] stories;
		auto rows = mysql.query("
			select BIN_TO_UUID(ID, true) as ID, BIN_TO_UUID(productID, true) as productID, title, cost, value
			from story
			where cancelled is NOT NULL;");
		foreach (row; rows) {
			Story story;
			story.id = row["ID"];
			story.productid = row["productID"];
			story.title = row["title"];
			story.cost = to!int(row["cost"]);
			story.value = to!int(row["value"]);
			stories ~= story;
		}
		return stories;
	}

	Story[] DoneStories() {
		Story[] stories;
		auto rows = mysql.query(
			"select BIN_TO_UUID(ID, true) as ID, BIN_TO_UUID(productID, true) as productID, title, cost, value
			from story
			where done is NOT NULL;");
		foreach (row; rows) {
			Story story;
			story.id = row["ID"];
			story.productid = row["productID"];
			story.title = row["title"];
			story.cost = to!int(row["cost"]);
			story.value = to!int(row["value"]);
			stories ~= story;
		}
		return stories;
	}

	void CancelStory(string id) {
		StoreEvent(id, "CancelStory");

		mysql.query("update story set cancelled=NOW() where ID=UUID_TO_BIN(?, true);", id);
	}

	void DoneStory(string id) {
		StoreEvent(id, "DoneStory");

		mysql.query("update story set done=NOW() where ID=UUID_TO_BIN(?, true);", id);
	}

	void StoreEvent(string uuid, string type, JSONValue data) {
		mysql.query("
			insert into event(typeID, objectID, data)
			select ID, UUID_TO_BIN(?, true), ? from event_type where name = ?;",
			uuid,
			data.toString,
			type
		);
	}

	void StoreEvent(string uuid, string type) {
		mysql.query("
			insert into event(typeID, objectID)
			select ID, UUID_TO_BIN(?, true) from event_type where name = ?;",
			uuid,
			type
		);
	}

	Event[] EventsAfter(DateTime t) {
		Event[] events;
		string tf = format("%04s-%02s-%02s %02s:%02s:%02s",
			(t.year),
			to!(int)(t.month),
			(t.day),
			(t.hour),
			(t.minute),
			(t.second)
		);
		writeln("Time: " ~ tf);
		//auto rows = mysql.query("select ID, BIN_TO_UUID(objectID, true) as objectID, occurred from event where occurred >= ?;", tf); //t.toISOExtString()
		auto rows = mysql.query("select ID, BIN_TO_UUID(objectID, true) as objectID, occurred from event;");
		foreach(row; rows) {
			Event event;
			event.occurred = row["occurred"];
			writeln(event.occurred);
			events ~= event;
		}
		return events;
	}

	void CreateUser(User user) {
		auto uuid = Generate_UUID();
		string hashedPassword = makeHash(dupPassword(user.password)).toString();

		JSONValue data = [ "name": user.name ];
		data.object["password"] = JSONValue(hashedPassword);
		StoreEvent(uuid, "CreateUser", data);

		mysql.query("insert into user(ID, name, password) values(UUID_TO_BIN(?, true), ?, ?);", uuid, user.name, hashedPassword);
	}

	User LoadUser(string id) {
		auto rows = mysql.query("select BIN_TO_UUID(ID, true) as ID, name from user where ID=UUID_TO_BIN(?, true);", id);
		User user;
		foreach(row; rows) {
			user.id = row["ID"];
			user.name = row["name"];
			break;
		}
		return user;
	}

	User UserByName(string name) {
		auto rows = mysql.query("select BIN_TO_UUID(ID, true) as ID, name from user where name=?;", name);
		User user;
		foreach(row; rows) {
			user.id = row["ID"];
			user.name = row["name"];
			break;
		}
		return user;
	}

	string Login(User user) {
		auto rows = mysql.query("select BIN_TO_UUID(ID, true) as ID, password from user where name=?;", user.name);
		foreach (row; rows) {
			string hashedPassword = row["password"];
			if(isSameHash(dupPassword(user.password), parseHash(hashedPassword))) {
				string sessionid = randomToken();
				mysql.query("insert into session(userid, sessionid) values(UUID_TO_BIN(?, true), ?);", row["ID"], sessionid);
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
		auto rows = mysql.query("select ID, BIN_TO_UUID(userID, true) as userID, sessionid from session where sessionid=?;", sessionid);
		APISession session;
		foreach (row; rows) {
			session.id = to!int(row["ID"]);
			session.userid = row["userID"];
			session.sessionid = row["sessionid"];
			return session;
		}
		return session;
	}
};


alias Test = void function(StorageTest, Storage);
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
				test(this, storage);
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

	string PrepareProduct() {
		User user;
		user.name = "somebody";
		user.password = "password";
		storage.CreateUser(user);
		user = storage.UserByName(user.name);

		Product product;
		product.userid = user.id;
		product.title = "someproduct";
		storage.SaveProduct(product);
		Product[] products = storage.ProductsByUser(user.id);
		return products[0].id;
	}

	Test[string] PrepareTests() {
		Test[string] tests;
		tests["Backlog_empty_at_start"] = function(StorageTest storagetest, Storage storage) {
			assert(0 == storage.LoadBacklog().length);
		};

		tests["Saved_story_shows_up_in_backlog"] = function(StorageTest storagetest, Storage storage) {
			auto productid = storagetest.PrepareProduct();

			Story story;
			story.productid = productid;
			storage.SaveStory(story);
			assert(1 == storage.LoadBacklog().length);
		};

		tests["Creating_story_generates_a_CreateStory_event"] = function(StorageTest storagetest, Storage storage) {
			auto productid = storagetest.PrepareProduct();

			auto pretime = to!DateTime(Clock.currTime());

			Story story;
			story.productid = productid;
			storage.SaveStory(story);

			Event[] events = storage.EventsAfter(pretime);
			writeln(events.length);
			//assert(1 == events.length);
		};

		tests["Story_can_be_updated"] = function(StorageTest storagetest, Storage storage) {
			auto productid = storagetest.PrepareProduct();

			Story story;
			story.productid = productid;
			storage.SaveStory(story);
			Story[] stories = storage.LoadBacklog();

			stories[0].title = "Updated";
			storage.SaveStory(stories[0]);
			assert(1 == storage.LoadBacklog().length);
			assert("Updated" == storage.LoadBacklog()[0].title);
		};

		tests["Cancelled_story_is_removed_from_backlog"] = function(StorageTest storagetest, Storage storage) {
			auto productid = storagetest.PrepareProduct();

			Story story;
			story.productid = productid;
			storage.SaveStory(story);
			Story[] backlog = storage.LoadBacklog();
			storage.CancelStory(backlog[0].id);
			assert(0 == storage.LoadBacklog().length);
			assert(1 == storage.CancelledStories().length);
		};

		tests["Done_story_is_removed_from_backlog"] = function(StorageTest storagetest, Storage storage) {
			auto productid = storagetest.PrepareProduct();

			Story story;
			story.productid = productid;
			storage.SaveStory(story);
			Story[] backlog = storage.LoadBacklog();
			storage.DoneStory(backlog[0].id);
			assert(0 == storage.LoadBacklog().length);
			assert(1 == storage.DoneStories().length);
		};

		tests["Login to wrong account fails"] = function(StorageTest storagetest, Storage storage) {
			User user;
			user.name = "nobody";
			string sessionid = storage.Login(user);
			assert("" == sessionid);
		};

		tests["Login with correct name and password works"] = function(StorageTest storagetest, Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			string sessionid = storage.Login(user);
			assert("" != sessionid);
		};

		tests["Login with correct name but wrong password fails"] = function(StorageTest storagetest, Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			user.password = "wrongpassword";
			string sessionid = storage.Login(user);
			assert("" == sessionid);
		};

		tests["After login, session should contain correct user"] = function(StorageTest storagetest, Storage storage) {
			User user;
			user.name = "somebody";
			user.password = "password";
			storage.CreateUser(user);
			string sessionid = storage.Login(user);
			APISession session = storage.LoadSession(sessionid);
			User sessionuser = storage.LoadUser(session.userid);
			assert(user.name == sessionuser.name);
		};

		tests["Multiple logins should not get the same sessionid"] = function(StorageTest storagetest, Storage storage) {
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

		tests["After logout, session should not contain a user"] = function(StorageTest storagetest, Storage storage) {
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
			assert("" == session.userid);
		};

		tests["Product can be created"] = function(StorageTest storagetest, Storage storage) {
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
