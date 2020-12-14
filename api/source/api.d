module codept.api;

import std.stdio;
import std.array;
import codept.storage;
import codept.data;

class API {
	Storage storage;
public:
	this() {
		MysqlParams params;
		auto file = File(".env");
		auto range = file.byLine();
		foreach (line; range)
		{
			auto keyval = line.split("=");
			if(keyval[0]=="DB_USER") {
				params.user = keyval[1].idup();
			}
			if(keyval[0]=="DB_CODEPT_PASSWORD") {
				params.password = keyval[1].idup();
			}
			if(keyval[0]=="DB_URL") {
				params.url = keyval[1].idup();
			}
			if(keyval[0]=="DB_DATABASE") {
				params.database = keyval[1].idup();
			}
			if(keyval[0]=="DB_PORT") {
				params.port = keyval[1].idup();
			}
		}

		storage = new Storage(params);
	}

	void SaveStory(Story story) {
		storage.SaveStory(story);
	}

	Story[] LoadBacklog() {
		return storage.LoadBacklog();
	}

	Story[] CancelledStories() {
		return storage.CancelledStories();
	}

	Story[] DoneStories() {
		return storage.DoneStories();
	}

	void CancelStory(int id) {
		storage.CancelStory(id);
	}

	void DoneStory(int id) {
		storage.DoneStory(id);
	}

	void CreateUser(User user) {
		storage.CreateUser(user);
	}

	string Login(User user) {
		return storage.Login(user);
	}

	void Logout(string sessionid) {
		storage.Logout(sessionid);
	}

	bool IsLoggedIn(string sessionid) {
		auto session = storage.LoadSession(sessionid);
		if(session.userid != "") {
			return true;
		}
		return false;
	}
};
