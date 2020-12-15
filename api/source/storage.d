module codept.storage;

import std.algorithm;
import std.stdio;
import std.file;
import std.conv;
import std.json;
import mysql.d;
import dauth;

import codept.data;

//TODO: Make UUID a virtual text uuid for selection, use ID to do joins...
//Code should only use UUID_TO_BIN on initial insert,
//after that code doesn't need to convert back and forth because the virtual column can be used.

class Storage {
	Mysql mysql;
public:
	this(MysqlParams params) {
		mysql = new Mysql(params.url, to!int(params.port), params.user, params.password, params.database);
		/*
		auto rows = mysql.query("select ID, name, password from user where UUID is NULL;");
		User user;
		foreach(row; rows) {
			auto uuid = Generate_UUID();

			user.id = to!int(row["ID"]);
			user.name = row["name"];
			string password = row["password"];

			JSONValue jj = [ "name": user.name ];
			jj.object["password"] = JSONValue(password);

			mysql.query("
				insert into event(typeID, UUID, data)
				select ID, ?, ? from event_type where name = 'CreateUser';",
				uuid,
				jj.toString
			);
			break;
		}*/
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
			INSERT INTO `event_type` (`ID`, `name`) VALUES (1, 'CreateUser');
		");

		mysql.query("
			CREATE TABLE `event` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  				`occurred` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
				`typeID` bigint(20) NOT NULL,
				`objectID` binary(16) NOT NULL,
				`objectUUID` varchar(36) COLLATE utf8mb4_unicode_ci GENERATED ALWAYS AS (bin_to_uuid(`objectID`)) VIRTUAL,
				`data` json DEFAULT NULL,
				CONSTRAINT `event_fk_type` FOREIGN KEY (`typeID`) REFERENCES `event_type` (`ID`) ON DELETE RESTRICT ON UPDATE RESTRICT
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `user` (
				`ID` binary(16) NOT NULL PRIMARY KEY,
				`UUID` varchar(36) COLLATE utf8mb4_unicode_ci GENERATED ALWAYS AS (bin_to_uuid(`ID`)) VIRTUAL,
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
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				`userID` binary(16) NOT NULL,
				`title` varchar(256) COLLATE utf8mb4_unicode_ci NOT NULL,
				CONSTRAINT `product_fk_user` FOREIGN KEY (`userID`) REFERENCES `user` (`ID`) ON DELETE RESTRICT ON UPDATE RESTRICT
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");

		mysql.query("
			CREATE TABLE `story` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				`productID` bigint(20) NOT NULL,
				`title` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
				`cost` int(11) NOT NULL,
				`value` int(11) NOT NULL,
				`cancelled` DATETIME,
				`done` DATETIME,
				CONSTRAINT `story_fk_product` FOREIGN KEY (`productID`)
				REFERENCES `product` (`id`) ON DELETE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		");
	}

	void Reset() {
		mysql.query("truncate story;");
		mysql.query("delete from product;");
		mysql.query("truncate session;");
		mysql.query("delete from user;");
		mysql.query("truncate event;");
		mysql.query("delete from event_type;");
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
		if(story.id == 0) {
			mysql.query(
				"insert into story (productID, title, cost, value) values (?, ?, ?, ?);",
				story.productid, story.title, story.cost, story.value
			);
		}
		else {
			mysql.query(
				"update story set productID=?, title=?, cost=?, value=? where ID=?;",
				story.productid, story.title, story.cost, story.value, story.id
			);
		}
	}

	void SaveProduct(Product product) {
		mysql.query("insert into product (userid, title) values (?, ?);", product.userid, product.title);
	}

	Product[] ProductsByUser(string userid) {
		Product[] products;
		auto rows = mysql.query("
			select ID, userID, title
			from product
			where userID = ?
			order by title asc;", userid);
		foreach (row; rows) {
			Product product;
			product.id = to!int(row["ID"]);
			product.userid = row["userID"];
			product.title = row["title"];
			products ~= product;
		}
		return products;
	}

	Story[] LoadBacklog() {
		Story[] stories;
		auto rows = mysql.query("
			select ID, productID, title, cost, value
			from story
			where cancelled is NULL and done is NULL
			order by value-cost desc;");
		foreach (row; rows) {
			Story story;
			story.id = to!int(row["ID"]);
			story.productid = to!int(row["productID"]);
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
			select ID, productID, title, cost, value
			from story
			where cancelled is NOT NULL;");
		foreach (row; rows) {
			Story story;
			story.id = to!int(row["ID"]);
			story.productid = to!int(row["productID"]);
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
			"select ID, productID, title, cost, value
			from story
			where done is NOT NULL;");
		foreach (row; rows) {
			Story story;
			story.id = to!int(row["ID"]);
			story.productid = to!int(row["productID"]);
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

	void StoreEvent(string uuid, string type, JSONValue data) {
		mysql.query("
			insert into event(typeID, objectID, data)
			select ID, UUID_TO_BIN(?, true), ? from event_type where name = ?;",
			uuid,
			data.toString,
			type
		);
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
		auto rows = mysql.query("select ID, name from user where ID=?;", id);
		User user;
		foreach(row; rows) {
			user.id = row["ID"];
			user.name = row["name"];
			break;
		}
		return user;
	}

	User UserByName(string name) {
		auto rows = mysql.query("select ID, name from user where name=?;", name);
		User user;
		foreach(row; rows) {
			user.id = row["ID"];
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

	int PrepareProduct() {
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
			int productid = storagetest.PrepareProduct();

			Story story;
			story.productid = productid;
			storage.SaveStory(story);
			assert(1 == storage.LoadBacklog().length);
		};

		tests["Story_can_be_updated"] = function(StorageTest storagetest, Storage storage) {
			int productid = storagetest.PrepareProduct();

			Story story;
			story.id = 0;
			story.productid = productid;
			storage.SaveStory(story);
			Story story2;
			story2.id = 0;
			story2.productid = productid;
			storage.SaveStory(story2);
			assert(1 == storage.LoadBacklog()[0].id);
			assert(2 == storage.LoadBacklog()[1].id);

			Story storyUpdate;
			storyUpdate.id = 1;
			storyUpdate.productid = productid;
			storyUpdate.title = "Updated";
			storage.SaveStory(storyUpdate);
			assert(2 == storage.LoadBacklog().length);
			assert("Updated" == storage.LoadBacklog()[0].title);
		};

		tests["Cancelled_story_is_removed_from_backlog"] = function(StorageTest storagetest, Storage storage) {
			int productid = storagetest.PrepareProduct();

			Story story;
			story.productid = productid;
			storage.SaveStory(story);
			Story[] backlog = storage.LoadBacklog();
			storage.CancelStory(backlog[0].id);
			assert(0 == storage.LoadBacklog().length);
			assert(1 == storage.CancelledStories().length);
		};

		tests["Done_story_is_removed_from_backlog"] = function(StorageTest storagetest, Storage storage) {
			int productid = storagetest.PrepareProduct();

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
